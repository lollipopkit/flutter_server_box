import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:server_box/data/provider/app.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server.dart';
import 'package:server_box/data/provider/sftp.dart';
import 'package:server_box/data/provider/snippet.dart';

/// !library;
/// ref.useNotifier, ref.readProvider, ref.watchProvider
/// 
/// Usage:
/// - `providers.read.server` -> `ref.read(serversNotifierProvider)`
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
  ServerState get server => ref.read(serverNotifierProvider);
  SnippetState get snippet => ref.read(snippetNotifierProvider);
  AppState get app => ref.read(appStatesProvider);
  PrivateKeyState get privateKey => ref.read(privateKeyNotifierProvider);
  SftpState get sftp => ref.read(sftpNotifierProvider);
}

final class WatchMyProvider {
  final WidgetRef ref;
  const WatchMyProvider(this.ref);

  T call<T>(ProviderBase<T> provider) => ref.watch(provider);
  
  // Specific provider getters
  ServerState get server => ref.watch(serverNotifierProvider);
  SnippetState get snippet => ref.watch(snippetNotifierProvider);
  AppState get app => ref.watch(appStatesProvider);
  PrivateKeyState get privateKey => ref.watch(privateKeyNotifierProvider);
  SftpState get sftp => ref.watch(sftpNotifierProvider);
}

final class UseNotifierMyProvider {
  final WidgetRef ref;
  const UseNotifierMyProvider(this.ref);

  T call<T extends Notifier<Object?>>(NotifierProvider<T, Object?> provider) =>
      ref.read(provider.notifier);
  
  // Specific provider notifier getters
  ServerNotifier get server => ref.read(serverNotifierProvider.notifier);
  SnippetNotifier get snippet => ref.read(snippetNotifierProvider.notifier);
  AppStates get app => ref.read(appStatesProvider.notifier);
  PrivateKeyNotifier get privateKey => ref.read(privateKeyNotifierProvider.notifier);
  SftpNotifier get sftp => ref.read(sftpNotifierProvider.notifier);
}