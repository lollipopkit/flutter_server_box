import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'package:server_box/data/provider/app.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/sftp.dart';
import 'package:server_box/data/provider/snippet.dart';

/// !library;
/// ref.useNotifier, ref.readProvider, ref.watchProvider
/// 
/// Usage:
/// - `providers.read.server` -> `ref.read(serversProvider)`
/// - `providers.use.snippet` -> `ref.read(snippetsNotifierProvider.notifier)`

extension RiverpodNotifiers on ConsumerState {
  T useNotifier<T extends Notifier<Object?>>(NotifierProvider<T, Object?> provider) {
    return ref.read(provider.notifier);
  }

  T readProvider<T>(ProviderBase<T> provider) {
    return ref.read(provider);
  }

  T watchProvider<T>(ProviderBase<T> provider) {
    return ref.watch(provider);
  }

  MyProviders get providers => MyProviders(ref);
}

final class MyProviders {
  final WidgetRef ref;
  const MyProviders(this.ref);

  ReadMyProvider get read => ReadMyProvider(ref);
  WatchMyProvider get watch => WatchMyProvider(ref);
  UseNotifierMyProvider get use => UseNotifierMyProvider(ref);
}

final class ReadMyProvider {
  final WidgetRef ref;
  const ReadMyProvider(this.ref);

  T call<T>(ProviderBase<T> provider) => ref.read(provider);
  
  // Specific provider getters
  ServersState get server => ref.read(serversProvider);
  SnippetState get snippet => ref.read(snippetProvider);
  AppState get app => ref.read(appStatesProvider);
  PrivateKeyState get privateKey => ref.read(privateKeyProvider);
  SftpState get sftp => ref.read(sftpProvider);
}

final class WatchMyProvider {
  final WidgetRef ref;
  const WatchMyProvider(this.ref);

  T call<T>(ProviderBase<T> provider) => ref.watch(provider);
  
  // Specific provider getters
  ServersState get server => ref.watch(serversProvider);
  SnippetState get snippet => ref.watch(snippetProvider);
  AppState get app => ref.watch(appStatesProvider);
  PrivateKeyState get privateKey => ref.watch(privateKeyProvider);
  SftpState get sftp => ref.watch(sftpProvider);
}

final class UseNotifierMyProvider {
  final WidgetRef ref;
  const UseNotifierMyProvider(this.ref);

  T call<T extends Notifier<Object?>>(NotifierProvider<T, Object?> provider) =>
      ref.read(provider.notifier);
  
  // Specific provider notifier getters
  ServersNotifier get server => ref.read(serversProvider.notifier);
  SnippetNotifier get snippet => ref.read(snippetProvider.notifier);
  AppStates get app => ref.read(appStatesProvider.notifier);
  PrivateKeyNotifier get privateKey => ref.read(privateKeyProvider.notifier);
  SftpNotifier get sftp => ref.read(sftpProvider.notifier);
}