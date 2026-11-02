part of 'file_browser.dart';

/// Where the browser is, what it lists, and moving through it.
extension _Navigation on _FileBrowserPageState {
  Future<List<FileEntry>> _list() async {
    final listed = _path.path;
    final entries = _named(await backend.list(listed));
    // Here rather than at each move: this is where the browser learns the
    // directory really opened.
    //
    // Only while it is still the directory being shown. A slow listing that
    // lands after the user has moved on would otherwise announce where they
    // were, and this is what the file tab persists — a listing of `/slow`
    // finishing after a move to `/fast` reopened the tab at `/slow`.
    if (mounted && _path.path == listed) {
      widget.args.onPathChanged?.call(listed);
    }
    return entries;
  }

  /// Filtered and sorted for display, leaving the listing itself alone: both
  /// are local decisions and must not cost a round trip to the server.
  List<FileEntry> _sorted(List<FileEntry> entries, _SortOption option) {
    final foldersFirst = Stores.setting.sftpShowFoldersFirst.fetch();
    final hidden = Stores.setting.showHiddenFiles.fetch();

    final cached = _shownCache;
    // By identity: `_list()` hands out a new list for every listing, so the
    // same object means the same directory, unchanged.
    if (cached != null &&
        identical(_shownFor, entries) &&
        _shownBy == option &&
        _shownFoldersFirst == foldersFirst &&
        _shownHidden == hidden) {
      return cached;
    }

    final shown = [
      for (final entry in entries)
        if (hidden || !entry.name.startsWith('.')) entry,
    ]..sort((a, b) {
      if (foldersFirst && a.isDir != b.isDir) return a.isDir ? -1 : 1;
      final result = option.by.compare(a, b);
      return option.reversed ? -result : result;
    });

    _shownCache = shown;
    _shownFor = entries;
    _shownBy = option;
    _shownFoldersFirst = foldersFirst;
    _shownHidden = hidden;
    return shown;
  }

  /// Reloads when something a transfer was carrying arrives in this directory.
  ///
  /// Nothing told the browser before. A drop finished, the file was on disk,
  /// and the listing went on showing what it had read before the file existed
  /// — so the way to see it was to leave the directory and come back.
  ///
  /// Matched by asking whether this directory's own ref, with the arriving
  /// name on the end, *is* where the transfer was going. That answers "the
  /// same place" rather than "the same string": an [SshFileRef] carries the
  /// server it is on, so a file landing in `/tmp` on another host does not
  /// reload `/tmp` here.
  void _refreshOnArrival(FileTransferState transfers) {
    final refOf = widget.args.refOf;
    // A browser whose files cannot be one end of a transfer has nothing to
    // wait for, and no way to name where it is.
    if (refOf == null) return;

    final ids = {for (final t in transfers.transfers) t.id};
    _landed.retainWhere(ids.contains);

    final here = refOf(_path.path);
    var arrived = false;
    for (final transfer in transfers.transfers) {
      if (transfer.status != FileTransferStage.finished) continue;
      if (!_landed.add(transfer.id)) continue;
      if (here.child(transfer.job.to.name) == transfer.job.to) arrived = true;
    }
    if (arrived) refresh();
  }

  /// Puts the path back when the field is left.
  ///
  /// Half a path that nobody submitted is not where the browser is, and a bar
  /// that goes on showing it says the wrong thing about the directory
  /// underneath — which is the one thing this bar is for. Abandoning an edit
  /// leaves it as it was, as it does in every other address bar.
  ///
  /// Submitting unfocuses too, and this runs first: the field goes back to the
  /// old path and stays there until the listing of the new one succeeds, which
  /// is the truth for as long as that takes.
  void _onPathFocusChange() {
    if (_pathFocus.hasFocus) return;
    _syncPathField();
  }

  /// Puts the current path in the address bar, unless it is being typed in.
  void _syncPathField() {
    if (_pathFocus.hasFocus) return;
    final shown = _displayPath(_path.path);
    if (_pathCtrl.text == shown) return;
    _pathCtrl.text = shown;
  }

  /// The directories under what has been typed so far.
  ///
  /// Real ones, read from the machine — not the paths this browser has been to
  /// before, which is what the dialog this replaced could offer. Directories
  /// only: a path leads somewhere to open, and a file is not that.
  ///
  /// The last component is matched anywhere in a name, not just at its front —
  /// see below.
  ///
  /// Through [FileBackend.list] and nothing more particular, so this is the
  /// same feature over SFTP, over a `monitor` agent's file API, and over this
  /// device's own disk.
  Future<Iterable<String>> _pathOptions(TextEditingValue value) async {
    // Only while it is being typed in. `RawAutocomplete` asks whenever the
    // text changes, and it also changes when a move rewrites the field — so
    // opening a directory listed it a second time, to complete a path nobody
    // was typing.
    if (!_pathFocus.hasFocus) return const [];

    final typed = value.text;
    // Nothing to complete against a name with no separator in it: what would
    // be listed is the current directory, whose contents are already on
    // screen underneath.
    final cut = typed.lastIndexOf('/');
    if (cut < 0) return const [];

    final shownDir = cut == 0 ? '/' : typed.substring(0, cut);
    final prefix = typed.substring(cut + 1).toLowerCase();
    // Only what the browser would go to. Outside the root there is nothing to
    // offer — picking it would be refused — and on a sandboxed platform the
    // root is the container, so `/../..` is both typeable and none of this
    // app's business to list.
    final dir = _path.resolve(_absolutePath(shownDir));
    if (dir == null) return const [];

    if (_completionDir != dir) {
      // Read before the await and checked after it: a listing that was already
      // on its way when the directory changed describes what was there before,
      // and caching it would undo the invalidation in [refresh]. Nothing is
      // offered for this keystroke — the next one lists again.
      final revision = _completionRevision;
      try {
        final listed = _named(await backend.list(dir));
        if (!mounted || revision != _completionRevision) return const [];
        _completionDir = dir;
        _completionEntries = listed;
      } catch (_) {
        // A directory that cannot be read completes to nothing, which is what
        // it has to offer. Not reported: this runs on every keystroke, and a
        // half-typed path naming nowhere is the ordinary case.
        if (revision != _completionRevision) return const [];
        _completionDir = dir;
        _completionEntries = const [];
      }
    }

    final hidden = Stores.setting.showHiddenFiles.fetch();
    // Anywhere in the name, as this tab's own search matches: a directory is
    // remembered by a word in it as often as by what it starts with, and
    // `logs-2026` is not something anyone types from the left.
    final matches = <({String folded, FileEntry entry})>[];
    for (final entry in _completionEntries ?? const <FileEntry>[]) {
      if (!entry.isDir) continue;
      if (!hidden && entry.name.startsWith('.')) continue;
      final folded = entry.name.toLowerCase();
      if (!folded.contains(prefix)) continue;
      matches.add((folded: folded, entry: entry));
    }

    // What was typed from the start first, then the rest, each by name. A
    // listing arrives in whatever order the far side keeps it in, which is no
    // order at all to read — and a substring match widens the list enough that
    // the one being typed has to stay at the top of it.
    matches.sort((a, b) {
      final aStarts = a.folded.startsWith(prefix);
      if (aStarts != b.folded.startsWith(prefix)) return aStarts ? -1 : 1;
      return a.folded.compareTo(b.folded);
    });

    return [
      for (final match in matches)
        _displayPath(BrowsePath.join(dir, match.entry.name)),
    ];
  }

  /// A path as the address bar shows it.
  ///
  /// Everything above the browser's root is dropped. On a phone that prefix is
  /// the app's container — a UUID under `/var/mobile/Containers` or
  /// `/data/user/0` — which is most of the width, none of the meaning, and
  /// somewhere the user can neither reach nor type. A server's root is `/`,
  /// where this changes nothing.
  String _displayPath(String absolute) {
    final root = _path.root;
    if (root == '/') return absolute;
    if (absolute == root) return '/';
    if (absolute.startsWith('$root/')) return absolute.substring(root.length);
    return absolute;
  }

  /// The inverse, for what was typed into it.
  ///
  /// A relative path is taken from where the browser is, which is what a bare
  /// name means anywhere else a path is typed.
  String _absolutePath(String shown) {
    final root = _path.root;
    if (!shown.startsWith('/')) return BrowsePath.join(_path.path, shown);
    if (root == '/') return shown;
    // Already rooted, so left alone: a path pasted from somewhere else, or one
    // this app itself showed before the prefix was stripped. Re-rooting it
    // would name `<root><root>/…`, which is nowhere.
    if (shown == root || shown.startsWith('$root/')) return shown;
    return shown == '/' ? root : '$root$shown';
  }

  /// Puts a completion in the field without going there.
  ///
  /// With a separator on the end, which is what makes it worth having: the
  /// next completion is then of that directory's contents, so a path is walked
  /// down one press per level. It is also what a shell's own completion does
  /// with a directory.
  ///
  /// The cursor goes to the end and the field keeps focus — completions are
  /// offered only while it has some, and this is the middle of typing.
  void _fillPath(String option) {
    final text = option.endsWith('/') ? option : '$option/';
    _pathCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    if (!_pathFocus.hasFocus) _pathFocus.requestFocus();
  }

  /// A path typed into the bar. Empty means the field was cleared and left,
  /// which is not a request to go anywhere.
  Future<void> _gotoTyped(String value) async {
    final typed = value.trim();
    _pathFocus.unfocus();
    final target = typed.isEmpty ? '' : _absolutePath(typed);
    if (target.isEmpty || target == _path.path) {
      _syncPathField();
      return;
    }
    final before = _path.path;
    await goTo(target);
    if (_path.path != before) widget.args.pathHistory?.add(target);
    // A refusal leaves the old path in place, so the field has to be told —
    // otherwise it keeps showing somewhere the browser is not.
    _syncPathField();
  }

  void _go(void Function() move) {
    _clearSelection();
    move();
    refresh();
  }

  void _clearSelection() {
    if (_selected.isEmpty && _cursor == null) return;
    setStateSafe(() {
      _selected.clear();
      _cursor = null;
      _anchor = null;
    });
  }

  /// Opens what a plain click means for this entry: enter it, pick it, or
  /// hand it to the backend's own opener.
  void _open(FileEntry entry, String full) {
    if (entry.isDir) {
      _go(() => _path.enter(entry.name));
      return;
    }
    if (widget.args.isPickFile) {
      _pick(entry);
      return;
    }
    // Picking a directory: a file is not something to act on here. Falling
    // through opened the entry menu — edit, delete, download — in a browser the
    // caller put up only to choose a folder.
    if (widget.args.isPickDir) return;
    final open = widget.args.onOpenFile;
    if (open == null) {
      _showEntryMenu(entry);
      return;
    }
    open(this, entry, full);
  }

  void _toggle(FileEntry entry) {
    setStateSafe(() {
      if (!_selected.remove(entry.name)) _selected.add(entry.name);
      final index = _shown.indexWhere((e) => e.name == entry.name);
      _anchor = index < 0 ? null : index;
      _cursor = _anchor;
    });
  }

  /// Everything between the last pick and this one, which is what shift means
  /// in every list a desktop user has met.
  void _extendTo(FileEntry entry) {
    final to = _shown.indexWhere((e) => e.name == entry.name);
    if (to < 0) return;
    final from = _anchor ?? to;
    setStateSafe(() {
      for (var i = from < to ? from : to; i <= (from < to ? to : from); i++) {
        _selected.add(_shown[i].name);
      }
      _cursor = to;
    });
  }

  /// The keys a desktop file manager answers to.
  ///
  /// On the list rather than on the page, so typing in a rename dialog does
  /// not delete what is behind it.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    final modified = keys.isControlPressed || keys.isMetaPressed;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _moveCursor(1, extend: keys.isShiftPressed);
      case LogicalKeyboardKey.arrowUp:
        _moveCursor(-1, extend: keys.isShiftPressed);
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        final entry = _cursorEntry;
        if (entry == null) return KeyEventResult.ignored;
        _open(entry, _fullPath(entry));
      case LogicalKeyboardKey.backspace:
        if (!_path.canGoUp) return KeyEventResult.ignored;
        _go(_path.goUp);
      case LogicalKeyboardKey.escape:
        if (!_selecting && _cursor == null) return KeyEventResult.ignored;
        _clearSelection();
      // The three that mutate or select are guarded rather than the whole
      // handler: moving the cursor, entering a directory, going up and
      // clearing are what a picker is *for*, and stay.
      case LogicalKeyboardKey.f2 when !_isPicking:
        final entry = _cursorOrOnlySelected;
        if (entry == null) return KeyEventResult.ignored;
        _rename(entry);
      case LogicalKeyboardKey.delete when !_isPicking:
        final targets = _selecting
            ? _selectedEntries
            : [?_cursorEntry];
        if (targets.isEmpty) return KeyEventResult.ignored;
        _deleteAll(targets);
      case LogicalKeyboardKey.keyA when modified && !_isPicking:
        _selectAll();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _moveCursor(int by, {required bool extend}) {
    if (_shown.isEmpty) return;
    final next = ((_cursor ?? -1) + by).clamp(0, _shown.length - 1);
    setStateSafe(() {
      _cursor = next;
      if (extend) {
        _anchor ??= next;
        _selected.add(_shown[next].name);
      }
    });
  }

  void _selectAll() {
    setStateSafe(() {
      _selected
        ..clear()
        ..addAll(_shown.map((e) => e.name));
    });
  }

  String _fullPath(FileEntry entry) => BrowsePath.join(_path.path, entry.name);

  /// The entries whose names are names, dropping any that are paths.
  ///
  /// `FileEntry.name` is documented as the last component and never a path, and
  /// every backend the app ships honours that. This is the boundary where that
  /// stops being a convention and starts being enforced, because everything
  /// downstream joins the name onto the directory being shown: an entry called
  /// `../outside` would make rename, delete, chmod and send-to act above the
  /// root the browser is confined to, which `BrowsePath` guards only for
  /// *navigation*. A listing is the far side's answer, and the far side is not
  /// always the far side one meant to be talking to.
  List<FileEntry> _named(List<FileEntry> entries) {
    final safe = <FileEntry>[];
    for (final entry in entries) {
      final name = entry.name;
      if (name.isEmpty ||
          name == '.' ||
          name == '..' ||
          name.contains('/') ||
          name.contains(r'\')) {
        Loggers.app.warning('Dropping a listing entry that is a path: $name');
        continue;
      }
      safe.add(entry);
    }
    return safe;
  }
}
