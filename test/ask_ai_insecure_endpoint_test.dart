/// A model served over plain `http` on someone's own network (#1447).
///
/// `https://` was always accepted and `http://localhost` always was too;
/// everything between was refused as `invalidUrl`. That is the wrong thing to
/// say about an address that is reachable and spelled correctly — an Ollama or
/// vLLM box on the LAN — and it left the feature unusable for exactly the
/// setups that have no certificate to offer.
///
/// So it is a switch, not a widening: the request carries the API key and
/// whatever terminal output was gathered as context, and whether that network
/// is one to send them over in the clear is not something this app can work
/// out. Same shape as `MonitorHttpCredential.allowInsecure`.
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/provider/ai/ask_ai.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    Stores.setting.askAiModel.put('local-model');
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  /// The first thing `ask` throws for [baseUrl], or null if it got as far as
  /// producing an event.
  ///
  /// The adapter refuses every request, so an address that is *accepted* fails
  /// as a network error — which is the assertion: reaching the adapter at all
  /// means the check let it through.
  Future<Object?> errorFor(String baseUrl, {bool allowInsecure = false}) async {
    Stores.setting.askAiBaseUrl.put(baseUrl);
    Stores.setting.askAiAllowInsecure.put(allowInsecure);
    final repo = AskAiRepository(
      dio: Dio()..httpClientAdapter = _RefusingAdapter(),
    );
    try {
      await repo.ask(terminalContext: '', serverName: 'srv').first;
      return null;
    } catch (e) {
      return e;
    }
  }

  test('plaintext away from loopback is refused, and says why', () async {
    for (final addr in [
      'http://192.168.1.10:11434',
      'http://ollama.lan:11434',
      'http://10.0.0.2:8000/v1',
    ]) {
      final err = await errorFor(addr);
      expect(err, isA<AskAiConfigException>(), reason: addr);
      err as AskAiConfigException;
      expect(
        err.insecureScheme,
        isTrue,
        reason: '$addr reads as a typo rather than as a setting',
      );
      expect(err.invalidBaseUrl, addr);
    }
  });

  test('the switch is what changes that', () async {
    final err = await errorFor(
      'http://192.168.1.10:11434',
      allowInsecure: true,
    );
    // Past the check and into the request, which is the whole assertion.
    expect(err, isA<AskAiNetworkException>());
  });

  test('loopback needs no switch, since nothing leaves the device', () async {
    for (final addr in [
      'http://localhost:11434',
      'http://127.0.0.1:11434',
      'http://[::1]:11434',
    ]) {
      expect(await errorFor(addr), isA<AskAiNetworkException>(), reason: addr);
    }
  });

  test('https needs no switch either, and the switch does not widen it', () async {
    expect(
      await errorFor('https://api.openai.com'),
      isA<AskAiNetworkException>(),
    );
    // An address that parses to no host is still refused with the switch on,
    // and is not reported as a scheme problem — there is nothing to turn on.
    final err = await errorFor('not a url', allowInsecure: true);
    expect(err, isA<AskAiConfigException>());
    expect((err! as AskAiConfigException).insecureScheme, isFalse);
  });
}

/// Fails every request without opening a socket.
///
/// A real connection to `192.168.1.10` would sit for the twenty-second connect
/// timeout, and to `127.0.0.1` would depend on what happens to be listening.
class _RefusingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'refused by the test adapter',
    );
  }
}
