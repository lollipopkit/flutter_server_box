import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

final class LocalFilePageArgs {
  final bool? isPickFile;

  /// Returning a directory rather than browsing one, for "send to where?".
  final bool isPickDir;

  /// Where to open. Was the *root* until the browser told the two apart, which
  /// is why a tab reopened deep in a tree could not go up.
  final String? initDir;

  /// Where to put this page's toolbar, for a host that draws a bar of its own.
  final ValueNotifier<List<BarAction>>? actionsSink;

  /// Told which directory is being shown, as it changes.
  final void Function(String path)? onPathChanged;

  const LocalFilePageArgs({
    this.isPickFile,
    this.isPickDir = false,
    this.initDir,
    this.actionsSink,
    this.onPathChanged,
  });
}

final class SftpPageArgs {
  final Spi spi;

  /// Returning a directory rather than browsing one, for "upload to where?".
  final bool isSelect;

  final String? initPath;

  /// Where this page publishes its toolbar instead of drawing one.
  ///
  /// A host that already has a bar of its own — the file tab's strip of
  /// sessions — takes them so the screen does not carry two. Null means draw
  /// the usual app bar, which is what a pushed page does.
  final ValueNotifier<List<BarAction>>? actionsSink;

  /// Told where the browser has moved to, after each successful listing.
  ///
  /// For a host that outlives the page — the file tab, which remembers where
  /// each of its sessions was so a relaunch reopens them there rather than at
  /// the home directory.
  final void Function(String path)? onPathChanged;

  const SftpPageArgs({
    required this.spi,
    this.isSelect = false,
    this.initPath,
    this.onPathChanged,
    this.actionsSink,
  });
}
