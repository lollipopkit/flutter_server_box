import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/app_link.dart';
import 'package:server_box/data/model/app/keybinding.dart';
import 'package:server_box/data/model/file/transfer.dart';
import 'package:server_box/data/model/file/transfer_status.dart';
import 'package:server_box/data/provider/app/keybindings.dart';
import 'package:server_box/data/provider/file_transfer.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/session_manager.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/setting/entries/keybindings.dart';

/// Android system surfaces fed from the app's state: the launcher's server
/// shortcuts, the transfer Live Update, the system keyboard shortcut list
/// and the per-app language.
///
/// Held by the home page, which outlives every page that changes them.
final class AndroidSystemSync {
  AndroidSystemSync(this._ref);

  final WidgetRef _ref;
  final _subs = <ProviderSubscription<Object?>>[];
  String? _lastShortcuts;
  String? _lastTransfers;
  Timer? _transferTimer;

  /// The language last agreed with the system, as a [Locale.code]; see
  /// [_adoptSystemLocale].
  String? _agreedLocale;

  /// Launcher shortcuts: the first servers in the user's order. The launcher
  /// shows four or five; more would only be cut.
  static const maxShortcuts = 4;

  void attach() {
    if (!isAndroid) return;
    _subs
      ..add(
        _ref.listenManual(
          serversProvider,
          (_, _) => _publishShortcuts(),
          fireImmediately: true,
        ),
      )
      ..add(
        _ref.listenManual(
          fileTransferProvider,
          (_, _) => _scheduleTransfers(),
          fireImmediately: true,
        ),
      )
      ..add(
        _ref.listenManual(
          keybindingsProvider,
          (_, _) => publishKeyboardShortcuts(),
          fireImmediately: true,
        ),
      );
    Stores.setting.locale.listenable().addListener(_pushAppLocale);
    unawaited(_initAppLocale());
  }

  void dispose() {
    for (final sub in _subs) {
      sub.close();
    }
    _subs.clear();
    _transferTimer?.cancel();
    if (isAndroid) {
      Stores.setting.locale.listenable().removeListener(_pushAppLocale);
    }
  }

  /// Back in front: the language may have been changed in system settings,
  /// and the shortcut labels follow the language.
  Future<void> onResumed() async {
    if (!isAndroid) return;
    await _adoptSystemLocale();
    publishKeyboardShortcuts();
  }

  void _publishShortcuts() {
    final state = _ref.read(serversProvider);
    final payload = jsonEncode([
      for (final id in state.serverOrder.take(maxShortcuts))
        if (state.servers[id] case final spi?)
          {'id': spi.id, 'label': spi.name, 'uri': ServerLink(spi.id).toString()},
    ]);
    if (payload == _lastShortcuts) return;
    _lastShortcuts = payload;
    unawaited(MethodChans.setShortcuts(payload));
  }

  /// At most once a second: progress arrives far more often than a
  /// notification should be reposted, and the system drops updates past its
  /// rate limit anyway.
  void _scheduleTransfers() {
    if (_transferTimer?.isActive ?? false) return;
    _publishTransfers();
    _transferTimer = Timer(const Duration(seconds: 1), _publishTransfers);
  }

  void _publishTransfers() {
    final active = [
      for (final t in _ref.read(fileTransferProvider).transfers)
        if (t.error == null && t.status != FileTransferStage.finished) t,
    ];
    TermSessionManager.setTransferring(active.isNotEmpty);
    final payload = active.isEmpty ? null : jsonEncode(transferPayload(active));
    if (payload == _lastTransfers) return;
    _lastTransfers = payload;
    unawaited(MethodChans.updateTransfers(payload));
  }

  /// What the notification says about [active], which is not empty.
  static Map<String, Object> transferPayload(List<FileTransferStatus> active) {
    var done = 0;
    var total = 0;
    var sized = true;
    for (final t in active) {
      final size = t.size;
      if (size == null || size <= 0) {
        sized = false;
        continue;
      }
      total += size;
      done += (t.transferredBytes ?? 0).clamp(0, size);
    }
    final progress = sized && total > 0 ? (done * 100 ~/ total) : -1;
    final speed = active.fold<double>(
      0,
      (sum, t) => sum + (t.speedBytesPerSecond ?? 0),
    );
    return {
      'title': active.length == 1
          ? active.single.fileName
          : l10n.transfersActive(active.length),
      'text': [
        if (sized && total > 0) '${done.bytes2Str} / ${total.bytes2Str}',
        if (speed > 0) '${speed.toInt().bytes2Str}/s',
      ].join(' · '),
      'progress': progress,
      'chip': progress < 0 ? '' : '$progress%',
    };
  }

  /// The chords as bound now, under the names the shortcuts page uses.
  void publishKeyboardShortcuts() {
    if (!isAndroid) return;
    final kb = _ref.read(keybindingsProvider);
    final groups = [
      for (final scope in KbScope.values)
        {
          'label': scope.label,
          'items': [
            for (final c in KbCommand.values)
              if (c.scope == scope)
                {
                  'label': c.title,
                  // A range names no one key; its first one stands for it.
                  'chord': c.fixed
                      ? kb.chordOf(c).replaceFirst('1…9', '1')
                      : kb.chordOf(c),
                },
          ],
        },
    ];
    unawaited(MethodChans.setKeyboardShortcuts(jsonEncode(groups)));
  }

  /// At launch the app's own setting wins, so a restored backup's language
  /// is what the system is told.
  Future<void> _initAppLocale() async {
    final system = await MethodChans.appLocale();
    if (system == null) return;
    final stored = Stores.setting.locale.fetch();
    if (localeTagToCode(system) != stored) {
      await MethodChans.setAppLocale(localeCodeToTag(stored));
    }
    _agreedLocale = stored;
  }

  /// A change made in system settings since: adopted as the app's own.
  Future<void> _adoptSystemLocale() async {
    final agreed = _agreedLocale;
    if (agreed == null) return;
    final system = await MethodChans.appLocale();
    if (system == null) return;
    final code = localeTagToCode(system);
    if (code == agreed) return;
    _agreedLocale = code;
    Stores.setting.locale.put(code);
    unawaited(RNodes.app.notify());
  }

  void _pushAppLocale() {
    final code = Stores.setting.locale.fetch();
    if (_agreedLocale == null || code == _agreedLocale) return;
    _agreedLocale = code;
    unawaited(MethodChans.setAppLocale(localeCodeToTag(code)));
  }
}

/// A [Locale.code] as the tag `locales_config.xml` lists it; empty, the
/// system's language, stays empty.
String localeCodeToTag(String code) => switch (code) {
  'zh' => 'zh-CN',
  _ => code.replaceAll('_', '-'),
};

/// The first of the system's tags as the app's language it is closest to;
/// empty for none, which follows the system.
String localeTagToCode(String tags) {
  final first = tags.split(',').first.trim();
  if (first.isEmpty) return '';
  final parts = first.split('-');
  final lang = parts.first.toLowerCase();
  final script = parts.skip(1).firstWhereOrNull((p) => p.length == 4);
  final region = parts
      .skip(1)
      .firstWhereOrNull((p) => p.length == 2)
      ?.toUpperCase();
  if (lang == 'zh' &&
      (script == 'Hant' || const {'TW', 'HK', 'MO'}.contains(region))) {
    return 'zh_TW';
  }
  final supported = AppLocalizations.supportedLocales;
  if (region != null && supported.contains(Locale(lang, region))) {
    return '${lang}_$region';
  }
  return supported.contains(Locale(lang)) ? lang : '';
}
