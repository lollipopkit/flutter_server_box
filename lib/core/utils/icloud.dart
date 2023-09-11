import 'dart:async';
import 'dart:io';

import 'package:icloud_storage/icloud_storage.dart';
import 'package:logging/logging.dart';

import '../../data/model/app/error.dart';
import '../../data/model/app/json.dart';
import '../../data/res/path.dart';

final _logger = Logger('iCloud');

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
      filePath: localPath ?? '${await docDir}/$relativePath',
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
      destinationFilePath: localPath ?? '${await docDir}/$relativePath',
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
  ///
  /// Return `null` if upload success, `ICloudErr` otherwise
  ///
  /// TODO: consider merge strategy, use [SyncAble] and [JsonSerializable]
  static Future<Iterable<ICloudErr>?> sync({
    required Iterable<String> relativePaths,
  }) async {
    try {
      final errs = <ICloudErr>[];

      final allFiles = await getAll();
      /// remove files not in relativePaths
      allFiles.removeWhere((e) => !relativePaths.contains(e.relativePath));

      final mission = <Future<void>>[];

      /// upload files not in iCloud
      final missed = relativePaths.where((e) {
        return !allFiles.any((f) => f.relativePath == e);
      });
      mission.addAll(missed.map((e) async {
        final err = await upload(relativePath: e);
        if (err != null) {
          errs.add(err);
        }
        //_logger.info('upload missed: $e');
      }));

      final docPath = await docDir;
      /// compare files in iCloud and local
      mission.addAll(allFiles.map((file) async {
        final relativePath = file.relativePath;

        /// Check date
        final localFile = File('$docPath/$relativePath');
        if (!localFile.existsSync()) {
          /// Local file not found, download remote file
          final err = await download(relativePath: relativePath);
          if (err != null) {
            errs.add(err);
          }
          //_logger.info('local not found: $relativePath');
          return;
        }
        final localDate = await localFile.lastModified();
        final remoteDate = file.contentChangeDate;

        /// Same date, skip
        if (remoteDate.difference(localDate) == Duration.zero) return;

        /// Local is newer than remote, so upload local file
        if (remoteDate.isBefore(localDate)) {
          final err = await upload(relativePath: relativePath);
          if (err != null) {
            errs.add(err);
          }
          //_logger.info('local newer: $relativePath');
          return;
        }

        /// Remote is newer than local, so download remote
        final err = await download(relativePath: relativePath);
        if (err != null) {
          errs.add(err);
        }
        //_logger.info('remote newer: $relativePath');
      }));

      await Future.wait(mission);

      return errs.isEmpty ? null : errs;
    } catch (e, s) {
      _logger.warning('Sync failed: $relativePaths', e, s);
      return [ICloudErr(type: ICloudErrType.generic, message: '$e')];
    } finally {
      _logger.info('Sync finished.');
    }
  }
}
