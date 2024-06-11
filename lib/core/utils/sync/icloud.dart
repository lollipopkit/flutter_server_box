import 'dart:async';
import 'dart:io';

import 'package:computer/computer.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:icloud_storage/icloud_storage.dart';
import 'package:logging/logging.dart';
import 'package:server_box/data/model/app/backup.dart';
import 'package:server_box/data/model/app/sync.dart';
import 'package:server_box/data/res/misc.dart';

import '../../../data/model/app/error.dart';

abstract final class ICloud {
  static const _containerId = 'iCloud.tech.lolli.serverbox';

  static final _logger = Logger('iCloud');

  /// Upload file to iCloud
  ///
  /// - [relativePath] is the path relative to [Paths.doc],
  /// must not starts with `/`
  /// - [localPath] has higher priority than [relativePath], but only apply
  /// to the local path instead of iCloud path
  ///
  /// Return [null] if upload success, [ICloudErr] otherwise
  static Future<ICloudErr?> upload({
    required String relativePath,
    String? localPath,
  }) async {
    final completer = Completer<ICloudErr?>();
    try {
      await ICloudStorage.upload(
        containerId: _containerId,
        filePath: localPath ?? '${Paths.doc}/$relativePath',
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
    } catch (e, s) {
      _logger.warning('Upload $relativePath failed', e, s);
      completer.complete(ICloudErr(type: ICloudErrType.generic, message: '$e'));
    }

    return completer.future;
  }

  static Future<List<ICloudFile>> getAll() async {
    return await ICloudStorage.gather(
      containerId: _containerId,
    );
  }

  static Future<void> delete(String relativePath) async {
    try {
      await ICloudStorage.delete(
        containerId: _containerId,
        relativePath: relativePath,
      );
    } catch (e, s) {
      _logger.warning('Delete $relativePath failed', e, s);
    }
  }

  /// Download file from iCloud
  ///
  /// - [relativePath] is the path relative to [Paths.doc],
  /// must not starts with `/`
  /// - [localPath] has higher priority than [relativePath], but only apply
  /// to the local path instead of iCloud path
  ///
  /// Return `null` if upload success, [ICloudErr] otherwise
  static Future<ICloudErr?> download({
    required String relativePath,
    String? localPath,
  }) async {
    final completer = Completer<ICloudErr?>();
    try {
      await ICloudStorage.download(
        containerId: _containerId,
        relativePath: relativePath,
        destinationFilePath: localPath ?? '${Paths.doc}/$relativePath',
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
    } catch (e, s) {
      _logger.warning('Download $relativePath failed', e, s);
      completer.complete(ICloudErr(type: ICloudErrType.generic, message: '$e'));
    }
    return completer.future;
  }

  /// Sync file between iCloud and local
  ///
  /// - [relativePaths] is the path relative to [Paths.doc],
  /// must not starts with `/`
  /// - [bakPrefix] is the suffix of backup file, default to [null].
  /// All files downloaded from cloud will be suffixed with [bakPrefix].
  ///
  /// Return `null` if upload success, [ICloudErr] otherwise
  static Future<SyncResult<String, ICloudErr>> syncFiles({
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

      final docPath = Paths.doc;

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
      _logger.warning('Sync: $relativePaths failed', e, s);
      return SyncResult(up: uploadFiles, down: downloadFiles, err: {
        'Generic': ICloudErr(type: ICloudErrType.generic, message: '$e')
      });
    } finally {
      _logger.info('Sync, up: $uploadFiles, down: $downloadFiles');
    }
  }

  static Future<void> sync() async {
    final result = await download(relativePath: Miscs.bakFileName);
    if (result != null) {
      await backup();
      return;
    }

    final dlFile = await File(Paths.bak).readAsString();
    final dlBak = await Computer.shared.start(Backup.fromJsonString, dlFile);
    await dlBak.restore();

    await backup();
  }

  static Future<void> backup() async {
    await Backup.backup();
    final uploadResult = await upload(relativePath: Miscs.bakFileName);
    if (uploadResult != null) {
      _logger.warning('Upload backup failed: $uploadResult');
    } else {
      _logger.info('Upload backup success');
    }
  }
}
