part of 'file_browser.dart';

/// What the browser does to entries: rename, delete, chmod, create, open, send.
extension _Actions on _FileBrowserPageState {
  Future<void> _rename(FileEntry entry) async {
    final name = await _askName(
      title: libL10n.rename,
      icon: Icons.abc,
      initial: entry.name,
    );
    if (name == null || name == entry.name) return;
    await _run(
      () => backend.rename(
        _fullPath(entry),
        BrowsePath.join(_path.path, name),
      ),
    );
  }

  Future<void> _chmod(FileEntry entry) async {
    final original = entry.mode ?? 0;
    final perm = UnixPerm.fromValue(original);
    var next = perm;
    final ok = await context.showRoundDialog<bool>(
      child: UnixPermEditor(perm: perm, onChanged: (value) => next = value),
      actions: Btnx.okReds,
    );
    if (ok != true || next.value == perm.value) return;
    // The bits above the nine this editor shows are carried over, not zeroed:
    // it cannot show setuid, setgid or sticky, so it must not clear them.
    await _run(() => backend.chmod(_fullPath(entry), next.valueWith(original)));
  }

  Future<void> _mkdir() async {
    final name = await _askName(title: libL10n.folder, icon: Icons.folder);
    if (name == null) return;
    await _run(() => backend.mkdir(BrowsePath.join(_path.path, name)));
  }

  Future<void> _newFile() async {
    final name = await _askName(
      title: libL10n.file,
      icon: Icons.insert_drive_file,
    );
    if (name == null) return;
    // An empty write, rather than a `touch` that only a backend with a shell
    // behind it could run.
    //
    // TODO: this is the one operation sudo no longer rescues. Escalating a
    // write means getting the bytes to the far side first, and the backend has
    // nowhere to put them — which is why an upload does that dance at the page
    // level. Creating an *empty* file has no bytes and could escalate, but only
    // through a method of its own.
    await _run(
      () => backend.write(
        BrowsePath.join(_path.path, name),
        const Stream<List<int>>.empty(),
        size: 0,
      ),
    );
  }

  /// One name, trimmed, or null for "nothing to do".
  Future<String?> _askName({
    required String title,
    required IconData icon,
    String? initial,
  }) async {
    final name = await context.showRoundDialog<String>(
      title: title,
      child: _NameField(icon: icon, initial: initial),
    );
    if (name == null || name.isEmpty || !mounted) return null;
    // A name, not a path. Every caller joins this onto the directory being
    // shown and hands the result to the backend, so a separator or a dot
    // segment here renames or creates somewhere else — `../outside` in a
    // browser rooted at `/home/me` resolves to `/home/outside`. `BrowsePath`
    // guards where the browser *goes*, and never sees these.
    if (name.contains('/') || name.contains(r'\') || name == '.' || name == '..') {
      Toast.error(libL10n.invalid);
      return null;
    }
    return name;
  }

  /// Runs something that changes the listing, and says so when it fails.
  ///
  /// Every mutating action ends the same way — do it, show what went wrong,
  /// look again — and writing that out five times is how one of them ends up
  /// silently swallowing its error.
  ///
  /// Deliberately not a modal loading dialog, which is what the SFTP page used
  /// to put here: an operation may now stop halfway to ask for a sudo
  /// password, and a barrier of its own would be sitting over that question.
  Future<void> _run(Future<void> Function() action) async {
    _busy.value = true;
    try {
      await action();
    } catch (e) {
      if (mounted) Toast.error(libL10n.fail, body: '$e');
      return;
    } finally {
      _busy.value = false;
    }
    await refresh();
  }

  /// What this entry offers, as descriptions rather than widgets.
  ///
  /// Descriptions because the same menu is drawn two ways — a centred dialog
  /// for a finger, a popup at the pointer for a mouse — and because closing
  /// the menu becomes the menu's job. Every one of these used to begin with a
  /// `popDialog` the author had to remember.
  List<ContextMenuAction> _entryActions(FileEntry entry, String full) => [
    ContextMenuAction(
      icon: Icons.checklist,
      text: libL10n.select,
      onTap: () => _toggle(entry),
    ),
    ContextMenuAction(
      icon: Icons.abc,
      text: libL10n.rename,
      onTap: () => _rename(entry),
    ),
    ContextMenuAction(
      icon: Icons.delete,
      text: libL10n.delete,
      destructive: true,
      onTap: () => _delete(entry),
    ),
    ContextMenuAction(
      icon: MingCute.copy_line,
      text: l10n.copyPath,
      onTap: () {
        Pfs.copy(full);
        Toast.success(libL10n.success);
      },
    ),
    if (backend.traits.permissions)
      ContextMenuAction(
        icon: Icons.security,
        text: libL10n.permission,
        onTap: () => _chmod(entry),
      ),
    // Moving something is the same act wherever it is, so it is offered
    // wherever it can be done rather than as "upload" on one page and
    // "download" on the other.
    if (widget.args.refOf case final refOf?)
      ContextMenuAction(
        icon: Icons.drive_file_move_outline,
        text: l10n.sendTo,
        onTap: () => sendTo(
          context,
          ref,
          source: refOf(full),
          isDir: entry.isDir,
        ),
      ),
    ...?widget.args.entryActions?.call(this, entry, full),
  ];

  /// [at] is where the pointer was, for a right-click. Null for a long press.
  Future<void> _showEntryMenu(FileEntry entry, {Offset? at}) {
    // Picking: the caller asked for a path back, not a file manager. Every
    // action on this menu either changes the entry or downloads it — none of
    // them is what the browser was opened to do, and on SFTP that put delete
    // one long press away from a dialog that only wanted a folder.
    if (_isPicking) return Future.value();
    final full = _fullPath(entry);
    return showContextMenu(
      context,
      _entryActions(entry, full),
      title: entry.name,
      at: at,
    );
  }

  Future<void> _pick(FileEntry entry) async {
    final picked = await context.showRoundDialog<bool>(
      title: libL10n.file,
      child: Text(entry.name),
      actions: Btn.ok(onTap: () => context.popDialog(true)).toList,
    );
    if (picked != true || !mounted) return;
    context.pop(_fullPath(entry));
  }

  /// Sends several to one destination, asking once where.
  Future<void> _sendAll(
    List<FileEntry> entries,
    FileRef Function(String) refOf,
  ) async {
    for (final entry in entries) {
      if (!mounted) return;
      await sendTo(
        context,
        ref,
        source: refOf(_fullPath(entry)),
        isDir: entry.isDir,
        // Asked for the first, reused for the rest: picking a destination ten
        // times to move ten files is not a batch action.
        reuseDestination: entry != entries.first,
      );
    }
    _clearSelection();
  }

  Future<void> _onDropped(List<XFile> files) async {
    _dropping.value = false;
    final refOf = widget.args.refOf;
    if (refOf == null || files.isEmpty) return;

    final queue = ref.read(fileTransferProvider.notifier);
    final queued = <int>[];
    for (final file in files) {
      final source = LocalFileRef(file.path.replaceAll(r'\', '/'));
      final destination = refOf(BrowsePath.join(_path.path, source.name));
      if (destination == source) continue;
      queued.add(
        queue.add(
          FileTransfer(
            from: source,
            to: destination,
            isDir: await FileSystemEntity.isDirectory(file.path),
          ),
        ),
      );
    }
    if (!mounted) return;
    await announceQueued(context, ref, queued);
  }
}
