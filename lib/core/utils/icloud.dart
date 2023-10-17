import 'dart:async';
import 'dart:io';

import 'package:icloud_storage/icloud_storage.dart';
import 'package:toolbox/data/res/logger.dart';

import '../../data/model/app/error.dart';
import '../../data/model/app/json.dart';
import '../../data/res/path.dart';

class SyncResult<T, E> {
  final List<T> up;
  final List<T> down;
  final Map<T, E> err;

  const SyncResult({
    required this.up,
    required this.down,
    required this.err,
  });

  @override
  String toString() {
    return 'SyncResult{up: $up, down: $down, err: $err}';
  }
}

class ICloud {
  static const _containerId = 'iCloud.tech.lolli.serverbox';

  const ICloud._();

  /// Upload file to iCloud
  ///
  /// - [relativePath] is the path relative to [docDir],
  /// must not starts with `/`
  /// - [localPath] has higher priority than [relativePath], but only apply
  /// to the local path instead of iCloud path
  ///
  /// Return `null` if upload success, `ICloudErr` otherwise
  static Future<ICloudErr?> upload({
    required String relativePath,
    String? localPath,
  }) async {
    final completer = Completer<ICloudErr?>();
    await ICloudStorage.upload(
      containerId: _containerId,
      filePath: localPath ?? '${await Paths.doc}/$relativePath',
      destinationRelativePath: relativePath,
      onProgress: (stream) {
        stream.listen(
          null,
          onDone: () => completer.complete(null),
          onError: (e) => completer.complete(
            ICloudErr(type: ICloudErrType.generic, message: '$e'),
          ),
        );
      },
    );
    return completer.future;
  }

  static Future<List<ICloudFile>> getAll() async {
    return await ICloudStorage.gather(
      containerId: _containerId,
    );
  }

  static Future<void> delete(String relativePath) async {
    await ICloudStorage.delete(
      containerId: _containerId,
      relativePath: relativePath,
    );
  }

  /// Download file from iCloud
  ///
  /// - [relativePath] is the path relative to [docDir],
  /// must not starts with `/`
  /// - [localPath] has higher priority than [relativePath], but only apply
  /// to the local path instead of iCloud path
  ///
  /// Return `null` if upload success, `ICloudErr` otherwise
  static Future<ICloudErr?> download({
    required String relativePath,
    String? localPath,
  }) async {
    final completer = Completer<ICloudErr?>();
    await ICloudStorage.download(
      containerId: _containerId,
      relativePath: relativePath,
      destinationFilePath: localPath ?? '${await Paths.doc}/$relativePath',
      onProgress: (stream) {
        stream.listen(
          null,
          onDone: () => completer.complete(null),
          onError: (e) => completer.complete(
            ICloudErr(type: ICloudErrType.generic, message: '$e'),
          ),
        );
      },
    );
    return completer.future;
  }

  /// Sync file between iCloud and local
  ///
  /// - [relativePath] is the path relative to [docDir],
  /// must not starts with `/`
  /// - [bakSuffix] is the suffix of backup file, default to [null].
  /// All files downloaded from cloud will be suffixed with [bakSuffix].
  ///
  /// Return `null` if upload success, `ICloudErr` otherwise
  ///
  /// TODO: consider merge strategy, use [SyncAble] and [JsonSerializable]
  static Future<SyncResult<String, ICloudErr>> sync({
    required Iterable<String> relativePaths,
    String? bakPrefix,
  }) async {
    final uploadFiles = <String>[];
    final downloadFiles = <String>[];

    try {
      final errs = <String, ICloudErr>{};

      final allFiles = await getAll();

      /// remove files not in relativePaths
      allFiles.removeWhere((e) => !relativePaths.contains(e.relativePath));

      final missions = <Future<void>>[];

      /// upload files not in iCloud
      final missed = relativePaths.where((e) {
        return !allFiles.any((f) => f.relativePath == e);
      });
      missions.addAll(missed.map((e) async {
        final err = await upload(relativePath: e);
        if (err != null) {
          errs[e] = err;
        }
      }));

      final docPath = await Paths.doc;

      /// compare files in iCloud and local
      missions.addAll(allFiles.map((file) async {
        final relativePath = file.relativePath;

        /// Check date
        final localFile = File('$docPath/$relativePath');
        if (!localFile.existsSync()) {
          /// Local file not found, download remote file
          final err = await download(relativePath: relativePath);
          if (err != null) {
            errs[relativePath] = err;
          }
          return;
        }
        final localDate = await localFile.lastModified();
        final remoteDate = file.contentChangeDate;

        /// Same date, skip
        if (remoteDate.difference(localDate) == Duration.zero) return;

        /// Local is newer than remote, so upload local file
        if (remoteDate.isBefore(localDate)) {
          await delete(relativePath);
          final err = await upload(relativePath: relativePath);
          if (err != null) {
            errs[relativePath] = err;
          }
          uploadFiles.add(relativePath);
          return;
        }

        /// Remote is newer than local, so download remote
        final localPath = '$docPath/${bakPrefix ?? ''}$relativePath';
        final err = await download(
          relativePath: relativePath,
          localPath: localPath,
        );
        if (err != null) {
          errs[relativePath] = err;
        }
        downloadFiles.add(relativePath);
      }));

      await Future.wait(missions);

      return SyncResult(up: uploadFiles, down: downloadFiles, err: errs);
    } catch (e, s) {
      Loggers.app.warning('iCloud sync: $relativePaths failed', e, s);
      return SyncResult(up: uploadFiles, down: downloadFiles, err: {
        'Generic': ICloudErr(type: ICloudErrType.generic, message: '$e')
      });
    } finally {
      Loggers.app.info('iCloud sync, up: $uploadFiles, down: $downloadFiles');
    }
  }
}
