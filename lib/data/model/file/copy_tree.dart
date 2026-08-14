import 'dart:async';

import 'package:server_box/data/model/file/file_backend.dart';

/// One file, resolved during a walk: where it is and where it goes.
class CopyItem {
  const CopyItem({required this.from, required this.to, this.size});

  final String from;
  final String to;

  /// Null where the backend did not say, which makes the total a lower bound.
  final int? size;
}

/// What a walk found: the files to copy, the directories to create first, and
/// how many bytes it all is.
class CopyPlan {
  const CopyPlan({
    required this.items,
    required this.dirs,
    required this.totalBytes,
  });

  final List<CopyItem> items;

  /// Every directory that has to exist at the destination, parents first.
  final List<String> dirs;

  /// The sum of the sizes that were known. A lower bound, not a promise: a
  /// backend may decline to size something, and progress past 100% is worse
  /// than progress that arrives early.
  final int totalBytes;
}

/// Walks [from] and says what copying it involves.
///
/// A pass of its own rather than copying as it goes, so that progress has a
/// denominator from the first byte. Listing a tree is cheap next to moving it.
Future<CopyPlan> planCopy(
  FileBackend source,
  String from,
  String to, {
  required bool isDir,
}) async {
  if (!isDir) {
    final stat = await source.stat(from);
    return CopyPlan(
      items: [CopyItem(from: from, to: to, size: stat?.size)],
      dirs: const [],
      totalBytes: stat?.size ?? 0,
    );
  }

  final items = <CopyItem>[];
  final dirs = <String>[to];
  var total = 0;

  Future<void> walk(String sourceDir, String destDir) async {
    for (final entry in await source.list(sourceDir)) {
      final childFrom = _join(sourceDir, entry.name);
      final childTo = _join(destDir, entry.name);
      if (entry.isDir) {
        dirs.add(childTo);
        await walk(childFrom, childTo);
        continue;
      }
      // Links are copied as what they point at, which is what every other
      // file-moving tool this app talks to does by default. Recreating one
      // needs a target that means the same thing on the far side, and it
      // usually does not.
      items.add(CopyItem(from: childFrom, to: childTo, size: entry.size));
      total += entry.size ?? 0;
    }
  }

  await walk(from, to);
  return CopyPlan(items: items, dirs: dirs, totalBytes: total);
}

/// Thrown out of [runCopy] when [runCopy]'s `cancelled` says to stop.
///
/// A distinct type so a caller can tell "the user closed this" from "it broke"
/// — one of those deserves an error on screen and the other does not.
class CopyCancelled implements Exception {
  const CopyCancelled();

  @override
  String toString() => 'Transfer cancelled';
}

/// Copies everything [plan] found, reporting bytes as they land.
///
/// [onProgress] is called with the running total, not with each chunk: the
/// caller decides how often that is worth publishing.
///
/// [cancelled] is asked between files and at every chunk. Throwing from inside
/// the stream rather than checking after each file is what stops a large one
/// partway — and it throws through `write`, whose own cleanup then removes the
/// staged copy.
Future<void> runCopy(
  CopyPlan plan,
  FileBackend source,
  FileBackend dest, {
  required void Function(int transferred) onProgress,
  bool Function()? cancelled,
  void Function(String path)? onStaging,
}) async {
  void checkCancelled() {
    if (cancelled?.call() ?? false) throw const CopyCancelled();
  }

  for (final dir in plan.dirs) {
    checkCancelled();
    // Already there is not a failure: a destination may well contain a
    // directory of the same name, and the point is that the path exists.
    try {
      await dest.mkdir(dir);
    } catch (_) {}
  }

  var transferred = 0;
  for (final item in plan.items) {
    checkCancelled();
    // Told before the write starts, so a caller whose process is about to be
    // killed mid-file knows what to clean up. `write` removes its own staging
    // on a normal failure; being killed is not one.
    onStaging?.call(item.to);
    final counted = source.read(item.from).map((chunk) {
      checkCancelled();
      transferred += chunk.length;
      onProgress(transferred);
      return chunk;
    });
    // `write` stages beside the destination and renames, so a file that dies
    // halfway leaves no half-file under the name something else opens.
    await dest.write(item.to, counted, size: item.size);
  }
}

String _join(String dir, String name) =>
    dir.endsWith('/') ? '$dir$name' : '$dir/$name';
