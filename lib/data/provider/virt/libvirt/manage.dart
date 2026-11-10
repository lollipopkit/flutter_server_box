part of '../libvirt_backend.dart';

/// Managing storage and networks, and uploading images.
mixin _Manage on _LibvirtCore, _Storage {
  /// Checked against what the host lists now, then made
  /// (`sbm_virt::libvirt::host::resource_script`): an existing network's
  /// edit is its own script (`sbm_virt::libvirt::net`), which rewrites the
  /// definition and, when told to, restarts the network on it, with the
  /// rollback that keeps it up.
  @override
  Future<void> manage(VirtResourceChange change) async {
    try {
      final network = change.scope == 'nets' || change.scope.startsWith('net:');
      final pools = network ? const <VirtStoragePool>[] : await storagePools();
      final pool = switch (change) {
        VirtPoolSetActive(:final pool) ||
        VirtPoolDelete(:final pool) ||
        VirtVolumeCreate(:final pool) ||
        VirtVolumeDelete(:final pool) ||
        VirtVolumeResize(:final pool) ||
        VirtVolumeClone(:final pool) => pools.firstWhereOrNull((p) => p.id == pool.id),
        _ => null,
      };
      final volumes = pool == null ? const <VirtVolume>[] : await this.volumes(pool);
      final networks = network ? await this.networks() : const <VirtNetwork>[];
      final res.VirtResourceScript script;
      try {
        script = res.virtLibvirtResourceScript(
          change: change.ffi,
          pools: [for (final p in pools) p.ffi],
          networks: [for (final n in networks) n.ffi],
          volumes: [for (final v in volumes) v.ffi],
        );
      } on PveError catch (e) {
        throw e.virt;
      }
      await _run(
        script.script,
        script.net ? _parseNetChange : _parseResource,
        action: true,
      );
    } on VirtErr catch (e) {
      throw _existsOr(e);
    } finally {
      // What a pool holds, and which, is listed again.
      _storage = null;
    }
  }

  /// libvirt applies every change as it is made.
  @override
  Future<List<VirtNetworkChanges>> networkChanges() async => const [];

  /// A raw volume of the file's size, then the file into it with
  /// `vol-upload` over a channel that carries bytes (see
  /// `sbm_virt::libvirt::manage::vol_upload_command`): through sudo when
  /// libvirt needs it, the password ahead of the file on the same stdin. A
  /// failed or cancelled upload deletes the volume, which holds part of a
  /// file at best.
  @override
  Future<bool> upload(
    VirtUpload upload, {
    void Function(int sent)? onProgress,
    Future<void>? cancel,
  }) async {
    final open = _byteExec;
    if (open == null || !(_canStream?.call() ?? false)) {
      throw const VirtErr(type: VirtErrType.unsupported);
    }
    final pool = upload.pool.id;
    Future<void> op(vl.VirtResourceOp o) => _run(
      _script(() => ffi.virtResourceScript(op: o)),
      _parseResource,
      action: true,
    );
    try {
      await op(
        vl.VirtResourceOp.volCreate(pool: pool, name: upload.name, bytes: BigInt.from(upload.size), format: 'raw'),
      );
    } on VirtErr catch (e) {
      throw _existsOr(e);
    }
    var done = false;
    try {
      final exec = await open().catchError(
        (Object e) => throw _unreachable(e),
      );
      // Decided by the volume just made: it went through sudo if libvirt
      // needed it.
      var entry = !_viaSudo
          ? SudoEntry.direct
          : _sudoPassword != null
          ? SudoEntry.sudoPassword
          : SudoEntry.sudoNoPassword;
      var result = await _stream(
        exec,
        upload,
        entry,
        onProgress: onProgress,
        cancel: cancel,
      );
      // sudo did not ask for the password it was given (cached, or
      // NOPASSWD): nothing was written; once more without it.
      if (result == _Streamed.notStarted &&
          entry == SudoEntry.sudoPassword) {
        entry = SudoEntry.sudoNoPassword;
        result = await _stream(
          exec,
          upload,
          entry,
          onProgress: onProgress,
          cancel: cancel,
        );
      }
      switch (result) {
        case _Streamed.done:
          done = true;
          return true;
        case _Streamed.cancelled:
          return false;
        case _Streamed.notStarted:
          throw const VirtErr(
            type: VirtErrType.actionFailed,
            message: 'The upload did not start',
          );
      }
    } finally {
      _storage = null;
      if (!done) {
        try {
          await op(vl.VirtResourceOp.volDelete(pool: pool, name: upload.name));
        } catch (e, s) {
          Loggers.app.warning('Deleting the unfinished upload ${upload.name}', e, s);
        }
      }
    }
  }

  /// One attempt: the preamble, the go line, and — once the host says it is
  /// ready — the file.
  Future<_Streamed> _stream(
    CommandByteExec exec,
    VirtUpload upload,
    SudoEntry entry, {
    void Function(int sent)? onProgress,
    Future<void>? cancel,
  }) async {
    final command = _script(
      () => ffi.virtVolUploadCommand(
        pool: upload.pool.id,
        name: upload.name,
        entry: entry,
      ),
    );
    final ExecSession session;
    try {
      session = await exec.start(command);
    } catch (e) {
      throw _unreachable(e);
    }
    final marker = ffi.virtUploadReadyMarker();
    final out = StringBuffer();
    final err = StringBuffer();
    final ready = Completer<bool>();
    final outDone = Completer<void>();
    final errDone = Completer<void>();
    final outSub = session.stdout.listen(
      (chunk) {
        out.write(chunk);
        if (!ready.isCompleted && out.toString().contains(marker)) {
          ready.complete(true);
        }
      },
      onDone: outDone.complete,
      onError: (Object _) => outDone.complete(),
    );
    var rejected = false;
    final errSub = session.stderr.listen(
      (chunk) {
        err.write(chunk);
        // A refused password: sudo asks again on the same stdin, and the go
        // line would be its next guess. Nothing more is sent.
        if (entry == SudoEntry.sudoPassword &&
            !rejected &&
            script_ffi.sudoPasswordRejected(stderr: err.toString())) {
          rejected = true;
          if (!ready.isCompleted) ready.complete(false);
          session.kill();
        }
      },
      onDone: errDone.complete,
      onError: (Object _) => errDone.complete(),
    );
    var cancelled = false;
    // Completed on cancel, so a read of the file that waits for its next
    // chunk ends too rather than holding the upload until one arrives.
    final stopped = Completer<bool>();
    unawaited(
      cancel?.then((_) {
        cancelled = true;
        if (!ready.isCompleted) ready.complete(false);
        if (!stopped.isCompleted) stopped.complete(false);
        session.kill();
      }),
    );
    final exited = session.done;
    unawaited(exited.then((_) {
      if (!ready.isCompleted) ready.complete(false);
    }, onError: (Object _) {
      if (!ready.isCompleted) ready.complete(false);
    }));
    int? code;
    // No ready line within [uploadReadyTimeout]: what it printed by then is
    // no answer, and reading it as one would report a refusal.
    var stalled = false;
    try {
      final password = _sudoPassword;
      try {
        if (entry == SudoEntry.sudoPassword &&
            password != null) {
          await session.write(utf8.encode('$password\n'));
        }
        await session.write(utf8.encode('${ffi.virtUploadGoLine()}\n'));
      } catch (_) {
        // The command ended before it read them — the script turning the
        // password away as its go line, sudo refusing: its output says
        // which, and no file follows.
      }
      final go = await ready.future.timeout(
        uploadReadyTimeout,
        onTimeout: () {
          stalled = true;
          return false;
        },
      );
      if (go && !cancelled) {
        var sent = 0;
        final chunks = StreamIterator(upload.open());
        try {
          while (await Future.any([chunks.moveNext(), stopped.future]) &&
              !cancelled) {
            final chunk = chunks.current;
            await session.write(chunk);
            sent += chunk.length;
            onProgress?.call(sent);
          }
        } finally {
          // Not awaited: a source stalled mid-read may take its time to let
          // go, and the upload has already ended.
          unawaited(chunks.cancel().catchError((Object _) => null));
        }
      }
      if (!go && !cancelled) {
        // Whatever holds it up, it gets no file: ended here.
        session.kill();
      } else if (!cancelled) {
        await session.closeStdin();
      }
      code = await exited;
    } catch (e) {
      if (cancelled) return _Streamed.cancelled;
      throw _unreachable(e);
    } finally {
      await Future.wait([
        outDone.future,
        errDone.future,
      ]).timeout(const Duration(seconds: 5), onTimeout: () => const []);
      await outSub.cancel();
      await errSub.cancel();
      session.kill();
    }
    if (cancelled) return _Streamed.cancelled;
    final stderr = err.toString();
    if (rejected) {
      _forgetSudoPassword();
      throw const VirtErr(
        type: VirtErrType.sudoPasswordRejected,
        message: 'sudo rejected the password',
      );
    }
    if (stalled) {
      throw VirtErr(
        type: VirtErrType.actionFailed,
        message: 'The upload command was not ready within $uploadReadyTimeout',
      );
    }
    try {
      final uploaded = ffi.parseVirtVolUpload(raw: '$out$stderr');
      return uploaded ? _Streamed.done : _Streamed.notStarted;
    } on ffi.VirtFfiError catch (e) {
      if (e.kind == ffi.VirtErrorKind.malformed) {
        // Nothing of the script's: the shell or sudo itself refused.
        throw VirtErr(
          type: entry == SudoEntry.direct
              ? VirtErrType.actionFailed
              : VirtErrType.permissionDenied,
          message: [stderr.trim(), 'exit $code'].where((m) => m.isNotEmpty).join('\n'),
          cause: e,
        );
      }
      throw _toErr(e, action: true);
    }
  }

  @override
  Future<List<VirtStats>?> history(
    VirtGuest guest, {
    VirtHistoryWindow window = VirtHistoryWindow.hour,
  }) async => null;

  @override
  Future<void> reset() async {
    _rates.clear();
    _storage = null;
  }

  @override
  Future<void> close() async {
    _sudoPassword = null;
    _rates.clear();
    _storage = null;
  }
}

Future<String> _parseNetChange({required String raw}) async {
  await ffi.parseVirtNetChange(raw: raw);
  return '';
}
