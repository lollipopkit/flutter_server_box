import 'package:flutter/widgets.dart';
import 'package:server_box/view/page/ssh/page/args.dart';
import 'package:server_box/view/page/storage/args.dart';

/// Peer-page navigation delegates registered at app startup (`installAppRoutes`).
///
/// Keeps mutual page transitions (`SFTP <-> SSH`, `TransferList -> LocalFile`,
/// `sendTo -> LocalFile/ServerFile`) acyclic without losing `AppRoute.go`
/// behavior or predictive-back transitions.
abstract final class AppRoutes {
  static Future<void> Function(BuildContext context, SshPageArgs args)?
  _openSsh;
  static Future<String?> Function(BuildContext context, LocalFilePageArgs args)?
  _openLocalFiles;
  static Future<String?> Function(BuildContext context, SftpPageArgs args)?
  _openServerFiles;

  static void register({
    required Future<void> Function(BuildContext context, SshPageArgs args)
    openSsh,
    required Future<String?> Function(
      BuildContext context,
      LocalFilePageArgs args,
    )
    openLocalFiles,
    required Future<String?> Function(BuildContext context, SftpPageArgs args)
    openServerFiles,
  }) {
    _openSsh = openSsh;
    _openLocalFiles = openLocalFiles;
    _openServerFiles = openServerFiles;
  }

  static Future<void> openSsh(BuildContext context, SshPageArgs args) {
    final fn = _openSsh;
    if (fn == null) {
      throw StateError('AppRoutes.openSsh used before installAppRoutes()');
    }
    return fn(context, args);
  }

  static Future<String?> openLocalFiles(
    BuildContext context,
    LocalFilePageArgs args,
  ) {
    final fn = _openLocalFiles;
    if (fn == null) {
      throw StateError(
        'AppRoutes.openLocalFiles used before installAppRoutes()',
      );
    }
    return fn(context, args);
  }

  static Future<String?> openServerFiles(
    BuildContext context,
    SftpPageArgs args,
  ) {
    final fn = _openServerFiles;
    if (fn == null) {
      throw StateError(
        'AppRoutes.openServerFiles used before installAppRoutes()',
      );
    }
    return fn(context, args);
  }
}
