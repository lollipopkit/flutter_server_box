import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/file/browse_path.dart';
import 'package:server_box/data/model/file/file_backend.dart';
import 'package:server_box/data/model/file/file_issue.dart';
import 'package:server_box/data/model/file/file_ref.dart';
import 'package:server_box/data/model/file/transfer.dart';
import 'package:server_box/data/provider/file_transfer.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/storage/file_pane.dart';
import 'package:server_box/view/page/storage/send_to.dart';
import 'package:server_box/view/page/storage/transfer_announce.dart';
import 'package:server_box/view/widget/omit_start_text.dart';
import 'package:server_box/view/widget/unix_perm.dart';

/// What an injected action is allowed to do to the browser it sits in.
///
/// Handed to the callbacks in [FileBrowserArgs] so a backend's own buttons —
/// importing a file on this device, downloading one from a server — can act
/// and then say "look again", without any of them holding the page's state.
abstract interface class FileBrowserHandle {
  FileBackend get backend;

  /// The directory being shown.
  String get path;

  /// Re-lists and rebuilds.
  Future<void> refresh();

  /// Shows another directory. Refuses anything outside the browser's root.
  Future<void> goTo(String path);
}

/// Where a browser has been told to go before, for the goto dialog to suggest.
///
/// An interface rather than a store, because whether to remember anything at
/// all is a setting, and a browser should not be the thing that reads it.
abstract interface class BrowsePathHistory {
  List<String> get all;
  void add(String path);
}

/// Everything a browser needs beyond the backend itself.
class FileBrowserArgs {
  const FileBrowserArgs({
    required this.backend,
    required this.root,
    this.initialPath,
    this.homePath,
    this.isPickFile = false,
    this.isPickDir = false,
    this.actionsSink,
    this.onPathChanged,
    this.extraActions,
    this.createActions,
    this.entryActions,
    this.pathTrailing,
    this.pathHistory,
    this.refOf,
    this.labelOf,
    this.onOpenFile,
  });

  final FileBackend backend;

  /// The furthest up this browser goes.
  final String root;

  /// Where to open, within [root]. Anything outside lands at the root.
  final String? initialPath;

  /// Where the home button goes, or null for a backend with no such place.
  final String? homePath;

  /// Picking, not browsing: tapping a file confirms and returns its path.
  final bool isPickFile;

  /// Picking a directory: the bottom bar confirms whichever one is open.
  final bool isPickDir;

  /// Where to put the toolbar, for a host that draws a bar of its own.
  ///
  /// Given one, this draws no app bar: the file tab already has a strip across
  /// the top, and a page under it with its own bar is two rows of chrome where
  /// one would do.
  final ValueNotifier<List<Widget>>? actionsSink;

  /// Told which directory is shown, once a listing of it has succeeded.
  ///
  /// After the listing rather than at each move, because that is the moment
  /// the browser knows the directory is really there — a host that reopens
  /// where it was left should not be handed a path that failed to open.
  final void Function(String path)? onPathChanged;

  /// Toolbar buttons only this backend has.
  final List<Widget> Function(FileBrowserHandle)? extraActions;

  // `bottomActions` was here. The bottom is an address bar now and carries no
  // per-backend buttons; the only one ever passed was SFTP's upload, which
  // [createActions] already offers in the same menu the `+` opens.

  /// Menu entries for the directory itself — what can be *made* here, beside
  /// the browser's own new file and new folder. Shown by the add button and by
  /// a right-click on empty space.
  final List<ContextMenuAction> Function(FileBrowserHandle)? createActions;

  /// Menu entries only this backend has, for one item.
  ///
  /// Descriptions, not widgets: the browser draws the menu two ways and closes
  /// it before running an action, so an action here must not do either itself.
  final List<ContextMenuAction> Function(
    FileBrowserHandle handle,
    FileEntry entry,
    String fullPath,
  )?
  entryActions;

  /// Shown beside the path, for a backend with something to say about how it
  /// is reading it — SFTP's sudo mode.
  final Widget? pathTrailing;

  /// Suggestions for the goto dialog. Null offers none.
  final BrowsePathHistory? pathHistory;

  /// How to name a path here so that a transfer can find it again from an
  /// isolate. Null leaves "send to…" out, for a browser whose files cannot be
  /// the source of one.
  ///
  /// The browser holds a [FileBackend] — a connection somebody already has —
  /// and a transfer needs a description of how to get one. Only the page that
  /// built the backend can write that description, so it hands one over rather
  /// than the browser guessing from the runtime type.
  final FileRef Function(String path)? refOf;

  /// What to call an entry where its name on disk is not what to show — a
  /// directory named after a server id, shown under that server's name.
  final String? Function(FileEntry entry, String fullPath)? labelOf;

  /// Opening a file, where the backend can do better than the generic menu.
  /// Null falls back to the menu.
  final void Function(
    FileBrowserHandle handle,
    FileEntry entry,
    String fullPath,
  )?
  onOpenFile;
}

/// One browser over one [FileBackend].
///
/// Everything here is written against the interface: listing, sorting, going
/// in and out, renaming, deleting, making a directory or a file, changing
/// permissions, searching. What is peculiar to a backend arrives through
/// [FileBrowserArgs] rather than a subclass, so there is exactly one of these
/// no matter how many kinds of storage there are.
class FileBrowserPage extends ConsumerStatefulWidget {
  const FileBrowserPage({super.key, required this.args});

  final FileBrowserArgs args;

  @override
  ConsumerState<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends ConsumerState<FileBrowserPage>
    with AutomaticKeepAliveClientMixin
    implements FileBrowserHandle {
  late final _path = BrowsePath(
    root: widget.args.root,
    initial: widget.args.initialPath,
  );
  final _sort = const _SortOption().vn;

  /// Redrawn when it changes rather than by [setState], so a long delete does
  /// not rebuild the listing under it.
  final _busy = false.vn;

  /// Whether something from the system is being dragged over the listing.
  final _dropping = false.vn;

  /// The entries picked out, by name — names rather than paths because a
  /// selection does not survive leaving the directory it was made in.
  final _selected = <String>{};

  /// Where the keyboard is, as an index into the shown list. Null until an
  /// arrow key is pressed, so a browser nobody has typed at draws no cursor.
  int? _cursor;

  /// The last entry the pointer picked, for shift-click to extend from.
  int? _anchor;

  /// What the shown list was, so the keyboard and shift-click can index it.
  /// Written where it is built, which is the only place that knows the order.
  List<FileEntry> _shown = const [];

  final _listFocus = FocusNode(debugLabel: 'file browser');

  /// Whether anything *still in the listing* is selected.
  ///
  /// Not `_selected.isNotEmpty`. That set holds names, and a name outlives the
  /// entry: deleted from another session, removed by a failed batch, or
  /// filtered out by toggling hidden files. Everything that acts on a selection
  /// goes through [_selectedEntries], which is the listing filtered by that
  /// set — so the two disagreed, and the bar stayed open over a selection with
  /// nothing in it, its delete button raising a confirmation for zero files.
  bool get _selecting => _shown.any((e) => _selected.contains(e.name));

  late Future<List<FileEntry>> _entries = _list();

  @override
  FileBackend get backend => widget.args.backend;

  @override
  String get path => _path.path;

  @override
  bool get wantKeepAlive => true;

  bool get _isPicking => widget.args.isPickFile || widget.args.isPickDir;

  @override
  void dispose() {
    _sort.dispose();
    _busy.dispose();
    _dropping.dispose();
    _listFocus.dispose();
    super.dispose();
  }

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

  /// The last arrangement, and what produced it.
  ///
  /// A `ValueListenableBuilder` rebuilds for reasons that have nothing to do
  /// with the listing — a keyboard opening, a theme change — and each one was
  /// copying and re-sorting every entry in the directory.
  List<FileEntry>? _shownCache;
  List<FileEntry>? _shownFor;
  _SortOption? _shownBy;
  bool? _shownFoldersFirst;
  bool? _shownHidden;

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

  /// Finished transfers this listing has already reacted to.
  ///
  /// A transfer keeps notifying after it finishes — the row stays until it is
  /// cleared — so without this the listing would reload on every one of those.
  final _landed = <int>{};

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

  @override
  Future<void> refresh() async {
    final listing = _list();
    // A block, not an arrow: `() => _entries = listing` returns the future it
    // assigned, and `setState` asserts against a callback that returns one —
    // so the assert threw and the rebuild never happened, which is what made
    // tapping a directory do nothing.
    setStateSafe(() {
      _entries = listing;
    });
    // Awaited so a caller can sequence on it, but its failure is not raised
    // here: the list itself shows what went wrong, and the callers that do not
    // await this would leave the error with nobody to catch it.
    await listing.then((_) {}, onError: (Object _) {});
  }

  @override
  Future<void> goTo(String target) async {
    if (!_path.goTo(target)) {
      Toast.error(libL10n.fail, body: target);
      return;
    }
    await refresh();
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

  /// Where the keyboard is, or null when it is nowhere and when the listing
  /// has changed under it.
  ///
  /// `elementAtOrNull` will not take a negative index, and "no cursor" is the
  /// ordinary state — so this is a guard rather than a default of -1.
  FileEntry? get _cursorEntry {
    final index = _cursor;
    if (index == null || index < 0 || index >= _shown.length) return null;
    return _shown[index];
  }

  /// The entries a batch action applies to, in the order they are shown.
  List<FileEntry> get _selectedEntries => [
    for (final entry in _shown)
      if (_selected.contains(entry.name)) entry,
  ];

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

  /// What a single-target key acts on: what is picked out if exactly one is,
  /// else where the keyboard is. Two selected and F2 is ambiguous, so it does
  /// nothing rather than renaming whichever came first.
  FileEntry? get _cursorOrOnlySelected {
    if (_selected.length == 1) return _selectedEntries.firstOrNull;
    if (_selected.isNotEmpty) return null;
    return _cursorEntry;
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

  // ------------------------------------------------------------------ actions

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

  /// Deletes several, asking once.
  ///
  /// One question for the batch rather than one per file: a confirmation the
  /// user has to answer ten times is a confirmation they stop reading.
  Future<void> _deleteAll(List<FileEntry> entries) async {
    if (entries.length == 1) return _delete(entries.first);

    // Read once, like the single delete below: whether there is a choice to
    // make must not change while the question is being answered.
    final alwaysRecursive = Stores.setting.sftpRmrDir.fetch();
    var recursive = alwaysRecursive;
    final hasDir = entries.any((e) => e.isDir);
    final confirmed = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: StatefulBuilder(
        builder: (_, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(
                libL10n.askContinue(
                  '${libL10n.delete} ${l10n.selected(entries.length)}',
                ),
              ),
              subtitle: Text(
                entries.map((e) => e.name).join('\n'),
                style: UIs.text11Grey,
              ),
            ),
            if (hasDir && !alwaysRecursive)
              CheckboxListTile(
                // Not `sftpRmrDirSummary`: that says "use `rm -r` in SFTP",
                // which is the reason SFTP needs the choice and not a sentence
                // to show somebody deleting a folder on their own device. The
                // choice itself is real everywhere — `Directory.delete` throws
                // on a non-empty directory too.
                title: Text(l10n.deleteDirRecursive),
                value: recursive,
                onChanged: (value) =>
                    setState(() => recursive = value ?? false),
              ),
          ],
        ),
      ),
      actions: Btnx.okReds,
    );
    if (confirmed != true) return;

    // Not `_run`: it treats a failure as "nothing happened" and skips the
    // reload, which is right for one operation and wrong for a batch. A refusal
    // part way through leaves the earlier ones deleted, so the listing is stale
    // either way — and clearing the selection wholesale after that took away
    // the only record of which ones were left.
    _busy.value = true;
    final removed = <String>{};
    Object? failure;
    try {
      for (final entry in entries) {
        await backend.remove(
          _fullPath(entry),
          recursive: entry.isDir && recursive,
        );
        removed.add(entry.name);
      }
    } catch (e) {
      failure = e;
    } finally {
      _busy.value = false;
    }

    if (mounted) {
      setStateSafe(() {
        // What is gone stops being selected; what is still there stays, so the
        // user can see what the failure left behind and retry it.
        _selected.removeAll(removed);
        if (_selected.isEmpty) {
          _cursor = null;
          _anchor = null;
        }
      });
      if (failure != null) Toast.error(libL10n.fail, body: '$failure');
    }
    await refresh();
  }

  Future<void> _delete(FileEntry entry) async {
    // Most people do not know that SFTP cannot delete a directory with
    // anything in it, so the choice is offered rather than the failure.
    //
    // Read once: it decides whether there is a choice to make at all, and a
    // dialog that re-read it would be asking a question that could change
    // shape underneath the answer.
    final alwaysRecursive = Stores.setting.sftpRmrDir.fetch();
    var recursive = alwaysRecursive;
    final confirmed = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: StatefulBuilder(
        builder: (_, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(
                libL10n.askContinue(
                  '${libL10n.delete} ${entry.name}'
                  // Only where the checkbox is absent. Said in both places it
                  // read as a warning that appeared and vanished as the box
                  // was ticked, and the question a dialog is asking should not
                  // move while it is being answered. Depends on the setting,
                  // which cannot change while this is open — not on `recursive`,
                  // which is exactly what the box changes.
                  '${entry.isDir && alwaysRecursive ? '\n${l10n.deleteDirRecursive}' : ''}',
                ),
              ),
            ),
            if (entry.isDir && !alwaysRecursive)
              CheckboxListTile(
                title: Text(l10n.deleteDirRecursive),
                value: recursive,
                onChanged: (value) =>
                    setState(() => recursive = value ?? false),
              ),
          ],
        ),
      ),
      actions: Btnx.okReds,
    );
    if (confirmed != true) return;
    await _run(
      () => backend.remove(_fullPath(entry), recursive: entry.isDir && recursive),
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

  Future<void> _goto() async {
    final history = widget.args.pathHistory;
    final target = await context.showRoundDialog<String>(
      title: l10n.goto,
      child: history == null
          ? Input(
              autoFocus: true,
              icon: Icons.abc,
              label: libL10n.path,
              suggestion: true,
              onSubmitted: (value) => context.popDialog(value),
            )
          : Autocomplete<String>(
              optionsBuilder: (value) =>
                  history.all.where((e) => e.contains(value.text)),
              fieldViewBuilder: (_, controller, node, _) => Input(
                autoFocus: true,
                icon: Icons.abc,
                label: libL10n.path,
                node: node,
                controller: controller,
                suggestion: true,
                onSubmitted: (value) => context.popDialog(value),
              ),
            ),
    );
    if (target == null || target.isEmpty || !mounted) return;

    final before = _path.path;
    await goTo(target);
    if (_path.path != before) history?.add(target);
  }

  Future<List<FileEntry>> _matching(String query) async {
    final entries = await _entries;
    final needle = query.toLowerCase();
    // The same visibility rule the listing uses. Searching the raw listing
    // meant a query could surface — and open — the dotfiles the user had
    // asked not to see, which is a filter that only holds until someone types.
    final hidden = Stores.setting.showHiddenFiles.fetch();
    return [
      for (final entry in entries)
        if (hidden || !entry.name.startsWith('.'))
          if (entry.name.toLowerCase().contains(needle)) entry,
    ];
  }

  void _showSearch() {
    // In the column beside the rail where there is one. `showSearch` is a
    // route, so it covers the rail as well as the listing — and what is being
    // searched is one directory in one session, which the rail is what names.
    final pane = FilePaneHost.of(context);
    if (pane != null) {
      pane.open(
        (_) => _InlineSearch(
          search: _matching,
          onClose: pane.close,
          itemBuilder: (entry) => _buildEntry(entry, beforeTap: pane.close),
        ),
      );
      return;
    }

    showSearch(
      context: context,
      delegate: SearchPage<FileEntry>(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        future: _matching,
        builder: (ctx, entry) => _buildEntry(entry, beforeTap: ctx.pop),
      ),
    );
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Listened rather than watched: an arriving file changes what is on disk,
    // not what this widget renders, so the answer is to go and read the
    // directory again — not to rebuild on every progress tick.
    ref.listen(fileTransferProvider, (_, next) => _refreshOnArrival(next));

    final actions = <Widget>[
      ...?widget.args.extraActions?.call(this),
      // The same menu a right-click on the directory gives — new folder, new
      // file, and bringing one in from outside — where it can be seen. It was
      // reachable only by secondary tap, which a phone does not have, so on
      // every mobile build the one visible `+` in this tab belonged to the
      // *server* list and adding a file had no button at all.
      if (!widget.args.isPickFile && !widget.args.isPickDir)
        Btn.icon(
          text: libL10n.add,
          icon: const Icon(Icons.add),
          onTap: () => showContextMenu(context, _createActions),
        ),
      _buildViewBtn(),
      Btn.icon(text: libL10n.search, icon: const Icon(Icons.search), onTap: _showSearch),
      if (isDesktop)
        Btn.icon(text: libL10n.refresh, icon: const Icon(Icons.refresh), onTap: refresh),
    ];

    final body = Column(
      children: [
        _busy.listenVal(
          (busy) => busy
              ? const LinearProgressIndicator(minHeight: 2)
              : const SizedBox(height: 2),
        ),
        Expanded(
          child: Focus(
            focusNode: _listFocus,
            onKeyEvent: _onKey,
            child: Listener(
              // A `Listener`, not a `GestureDetector`: this only wants to know
              // that a pointer went down, and a tap recogniser here would
              // compete in the arena with the row's own — losing it, and with
              // it the focus that makes the arrow keys work.
              onPointerDown: (_) => _listFocus.requestFocus(),
              child: _wrapDropTarget(
            (isMobile
                    ? RefreshIndicator(onRefresh: refresh, child: _buildList())
                    : _buildList())
                  // Right-click anywhere in the list, including past the last
                  // entry. An entry's own menu sits in front of this one and
                  // wins, so this is what is left: the directory itself.
                .onSecondary(
                  widget.args.isPickFile || widget.args.isPickDir
                      ? null
                      : (at) => showContextMenu(
                          context,
                          _createActions,
                          at: at,
                        ),
                  ),
              ),
            ),
          ),
        ),
      ],
    );

    final sink = widget.args.actionsSink;
    if (sink == null) {
      final title = _path.name;
      return Scaffold(
        appBar: CustomAppBar(
          title: AnimatedSwitcher(
            duration: Durations.short3,
            child: Text(title, key: ValueKey(title)),
          ),
          actions: actions,
        ),
        body: body,
        bottomNavigationBar: _buildBottom(),
      );
    }

    // Handed over after the frame, not during it: a notifier written while
    // building tells its listeners to rebuild in the middle of a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) sink.value = actions;
    });
    return Scaffold(body: body, bottomNavigationBar: _buildBottom());
  }

  /// The address bar, and the whole of the bottom.
  ///
  /// It used to be a path with a row of buttons under it — back, home, add,
  /// go-to, upload — most of which said what the toolbar already said: `add`
  /// is the `+` in the app bar and the right-click menu, and the only `upload`
  /// any backend put here is in that same menu. Go-to was a button for typing
  /// a path, next to the path, which is where a browser puts the same thing
  /// without needing a button at all.
  ///
  /// So the path became the control. Back and home stay beside it because they
  /// are what an address bar carries — they name where to go, which is what
  /// the bar is about — and neither has anywhere else to be: the app bar is
  /// full on a phone, and a history that can only be walked with the backspace
  /// key is no history on a touchscreen.
  Widget _buildBottom() {
    if (_selecting) return _buildSelectionBar();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 7, 11, 11),
        child: Row(
          children: [
            if (!widget.args.isPickDir) ...[
              Btn.icon(
                text: l10n.back,
                onTap: () {
                  if (_path.goBack()) refresh();
                },
                icon: const Icon(Icons.arrow_back),
              ),
              if (widget.args.homePath case final home?)
                Btn.icon(
                  text: l10n.homeDir,
                  onTap: () => goTo(home),
                  icon: const Icon(Icons.home),
                ),
            ],
            Expanded(child: _buildPathBar()),
            // Picking ends here and nowhere else: the caller asked for a path
            // back, and this is the only thing that returns one.
            if (widget.args.isPickDir)
              IconButton(
                tooltip: libL10n.ok,
                onPressed: () => context.pop(_path.path),
                icon: const Icon(Icons.done),
              ),
          ],
        ),
      ),
    );
  }

  /// The path, and a tap to type a different one.
  ///
  /// The pencil is what says so. A path is text that looks like a label, and
  /// nothing about it suggests it can be tapped — which is why the go-to it
  /// replaces needed a button of its own.
  Widget _buildPathBar() {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: _goto,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(child: OmitStartText(_path.path)),
            if (widget.args.pathTrailing case final trailing?) ...[
              UIs.width7,
              trailing,
            ],
            UIs.width7,
            Icon(Icons.edit_outlined, size: 15, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  /// What can be made here, rather than done to something.
  ///
  /// The same list behind the add button and behind a right-click on empty
  /// space — which is where a desktop user looks for it, and where the bottom
  /// bar's button is not.
  List<ContextMenuAction> get _createActions => [
    ContextMenuAction(
      icon: Icons.folder,
      text: libL10n.folder,
      onTap: _mkdir,
    ),
    ContextMenuAction(
      icon: Icons.insert_drive_file,
      text: libL10n.file,
      onTap: _newFile,
    ),
    ...?widget.args.createActions?.call(this),
  ];

  /// What replaces the bottom row while entries are picked out.
  ///
  /// In place of it rather than beside it: nothing in the ordinary row acts on
  /// a selection, and leaving them both on screen would put "new folder" next
  /// to "delete 9 files".
  Widget _buildSelectionBar() {
    final entries = _selectedEntries;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 7, 11, 11),
        child: Row(
          children: [
            IconButton(
              tooltip: libL10n.cancel,
              onPressed: _clearSelection,
              icon: const Icon(Icons.close),
            ),
            UIs.width7,
            Expanded(child: Text(l10n.selected(entries.length))),
            if (widget.args.refOf case final refOf?)
              IconButton(
                tooltip: l10n.sendTo,
                onPressed: () => _sendAll(entries, refOf),
                icon: const Icon(Icons.drive_file_move_outline),
              ),
            IconButton(
              tooltip: libL10n.delete,
              onPressed: () => _deleteAll(entries),
              icon: Icon(Icons.delete, color: UIs.textRed.color),
            ),
          ],
        ),
      ),
    );
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

  /// Dropping files from the system onto the listing.
  ///
  /// The gesture a desktop file manager is for. It arrives as native paths, so
  /// the source is always this device — which is exactly a `LocalFileRef`, and
  /// so an ordinary transfer rather than a second kind of copy.
  ///
  /// Only where the browser can say what a path here is called: without
  /// [FileBrowserArgs.refOf] there is no destination to name.
  Widget _wrapDropTarget(Widget child) {
    if (widget.args.refOf == null || _isPicking) return child;
    return DropTarget(
      onDragDone: (details) => _onDropped(details.files),
      onDragEntered: (_) => _dropping.value = true,
      onDragExited: (_) => _dropping.value = false,
      child: _dropping.listenVal(
        (active) => !active
            ? child
            : DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: Border.all(color: UIs.primaryColor, width: 2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: child,
              ),
      ),
    );
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

  Widget _buildList() {
    return FutureWidget(
      future: _entries,
      loading: UIs.placeholder,
      error: (e, _) => _buildError(e),
      success: (entries) => _sort.listenVal(
        (option) => _buildListView(_sorted(entries ?? const [], option)),
      ),
    );
  }

  /// What a directory that would not open says.
  ///
  /// The same shape the container page uses for a runtime it could not reach:
  /// a heading someone can act on, the machine's own words underneath, and a
  /// way to try again. A raw exception centred on the page told the user the
  /// path they were already looking at.
  ///
  /// No second button for the folder that is gone: the bottom bar is still on
  /// screen, and back, home and goto are all there.
  Widget _buildError(Object? error) {
    final issue = classifyFileError(error);
    return PageIssueView(
      title: switch (issue) {
        FileIssue.notFound => l10n.fileDirGone,
        FileIssue.denied => libL10n.permissionDenied,
        FileIssue.timeout => libL10n.timeout,
        FileIssue.unknown => libL10n.fail,
      },
      explain: switch (issue) {
        FileIssue.notFound => l10n.fileDirGoneTip,
        // Where there is a way past a refusal, name the button that offers it.
        FileIssue.denied when backend.traits.sudoFallback => l10n.trySudo,
        _ => null,
      },
      detail: '$error',
      icon: switch (issue) {
        FileIssue.notFound => Icons.folder_off_outlined,
        FileIssue.denied => Icons.lock_outline,
        FileIssue.timeout => Icons.timer_off_outlined,
        FileIssue.unknown => Icons.error_outline,
      },
      // A refusal is the one failure that going somewhere else can fix, and
      // where a path is out of bounds rather than unreadable, retrying is a
      // button that can only produce the same refusal again.
      suggestion: issue == FileIssue.denied ? _reachableRoots : null,
      onRetry: refresh,
    );
  }

  /// Somewhere the far side will actually serve, offered where it just refused.
  ///
  /// A `monitor` agent serves the directories its operator named and nothing
  /// else. A tab restored onto a path outside them — or opened at `/`, which is
  /// outside them whenever the roots are narrower than the machine — lands on a
  /// refusal, and without this the only way on is to type a path blind.
  ///
  /// Asked of the backend rather than of the transport, so the two that have a
  /// whole filesystem behind them answer with an empty list and this draws
  /// nothing. Empty is "no such limit", never "nowhere to go".
  Widget get _reachableRoots {
    return FutureBuilder<List<String>>(
      future: backend.reachableRoots(),
      builder: (_, snapshot) {
        final roots = snapshot.data;
        // Also the error case: an agent that will not say where its roots are
        // is one this can add nothing to, so it leaves the refusal as it is.
        if (roots == null || roots.isEmpty) return UIs.placeholder;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.goto, style: UIs.textGrey),
            UIs.height7,
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final root in roots)
                    ActionChip(
                      avatar: const Icon(Icons.folder_open, size: 15),
                      label: Text(root),
                      onPressed: () => goTo(root),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListView(List<FileEntry> items) {
    // The order the keyboard walks and shift-click extends along. Assigned
    // here because this is the only place that knows it.
    _shown = items;
    final up = _path.canGoUp ? 1 : 0;
    // Asked once per listing rather than once per row. `MediaQuery.sizeOf`
    // registers an inherited-widget dependency, and doing that inside
    // `itemBuilder` did it for every visible entry, every rebuild.
    final narrow = MediaQuery.sizeOf(context).width < 350;
    const padding = EdgeInsets.symmetric(vertical: 10, horizontal: 13);

    Widget upTile() => ListTile(
      leading: const Icon(Icons.arrow_upward),
      title: const Text('..'),
      onTap: () => _go(_path.goUp),
    ).cardx;

    // An empty directory still has to say so, and still has to be leavable.
    //
    // The mark this tab uses for an empty surface, not a word. The row above
    // says where you are and how to leave; a sentence here would be describing
    // what the reader is already looking at.
    //
    // The failed *search* below keeps its words: "nothing matched" and "this
    // place is empty" are different things, and only one of them is a state of
    // the directory.
    //
    // `SliverFillRemaining` and not another list item: as an item it took the
    // height of the icon and sat at the top of the list, which reads as the
    // first entry of a directory that has none. This centres it in whatever is
    // left under the `..` row.
    if (items.isEmpty) {
      return FadeIn(
        key: ValueKey(_path.path),
        child: CustomScrollView(
          slivers: [
            if (up == 1)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(13, 10, 13, 0),
                sliver: SliverToBoxAdapter(child: upTile()),
              ),
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: EmptyMark(icon: Icons.folder_open)),
            ),
          ],
        ),
      );
    }

    return FadeIn(
      key: ValueKey(_path.path),
      child: ListView.builder(
        itemCount: items.length + up,
        padding: padding,
        itemBuilder: (context, index) {
          if (up == 1 && index == 0) return upTile();
          return _buildEntry(items[index - up], narrow: narrow);
        },
      ),
    );
  }

  Widget _buildEntry(
    FileEntry entry, {
    VoidCallback? beforeTap,
    bool? narrow,
  }) {
    final full = _fullPath(entry);
    final label = widget.args.labelOf?.call(entry, full);
    final icon = Icon(switch (entry.kind) {
      FileKind.dir => Icons.folder_open,
      FileKind.link => Icons.link,
      _ => Icons.insert_drive_file,
    });

    /// A click that carries a modifier, or lands while a selection is open,
    /// picks rather than opens.
    ///
    /// Single click still *opens*, on both kinds of pointer. Reversing that —
    /// click selects, double-click opens, as a desktop file manager does —
    /// would make entering a folder take two clicks on a touch screen, and
    /// this browser has to be the same browser on both.
    ///
    /// And so there is no double-click handler. Declaring one puts a
    /// double-tap recogniser in the arena, which delays *every* single click
    /// by the double-tap timeout — paid on every open, to gain a gesture that
    /// would do what the first click already did.
    void onTap() {
      beforeTap?.call();
      final keys = HardwareKeyboard.instance;
      if (keys.isShiftPressed) {
        _extendTo(entry);
        return;
      }
      // Not while picking: a selection is the beginning of acting on several
      // entries, and a picker returns exactly one thing.
      if (!_isPicking &&
          (keys.isControlPressed || keys.isMetaPressed || _selecting)) {
        _toggle(entry);
        return;
      }
      _open(entry, full);
    }

    void onLongPress() {
      beforeTap?.call();
      _showEntryMenu(entry);
    }

    void onSecondaryTap(Offset at) {
      beforeTap?.call();
      _showEntryMenu(entry, at: at);
    }

    // Under this, a name and a right-hand column do not both fit, so
    // everything the entry knows goes below the name instead. The search
    // results build one at a time and have no listing to have asked for.
    final isNarrow = narrow ?? MediaQuery.sizeOf(context).width < 350;
    final details = [
      // The real name, where the title is showing something friendlier.
      if (label != null) entry.name,
      if (entry.size case final size? when !entry.isDir) size.bytes2Str,
      if (isNarrow) ...[
        if (entry.modified case final at?) at.ymdhms(),
        ?entry.modeStr,
      ],
    ];

    return CardX(
      child: ListTile(
        leading: icon,
        title: Text(label ?? entry.name),
        subtitle: details.isEmpty
            ? null
            : Text(details.join('\n'), style: UIs.textGrey),
        trailing: isNarrow ? null : _buildEntryTrailing(entry),
        onTap: onTap,
        onLongPress: onLongPress,
        selected: _selected.contains(entry.name),
        selectedTileColor: Theme.of(
          context,
        ).colorScheme.secondaryContainer.withValues(alpha: 0.55),
        // Where the keyboard is, which is not the same as what is picked out.
        shape: _cursorEntry?.name == entry.name
            ? RoundedRectangleBorder(
                side: BorderSide(color: UIs.primaryColor, width: 1.5),
                borderRadius: BorderRadius.circular(13),
              )
            : null,
      ).onSecondary(onSecondaryTap),
    );
  }

  Widget? _buildEntryTrailing(FileEntry entry) {
    final lines = [
      if (entry.modified case final at?) at.ymdhms(),
      ?entry.modeStr,
    ];
    if (lines.isEmpty) return null;
    return Text(
      lines.join('\n'),
      style: UIs.textGrey,
      textAlign: TextAlign.right,
    );
  }

  /// How this list is shown: what it is ordered by, and whether it hides the
  /// dotfiles. One menu, because both are the same kind of decision and the
  /// toolbar has no room for a button each.
  Widget _buildViewBtn() {
    return _sort.listenVal((value) {
      final hidden = Stores.setting.showHiddenFiles.fetch();
      return PopupMenuButton<Object>(
        icon: const Icon(Icons.sort),
        itemBuilder: (_) => [
          for (final by in _SortBy.values)
            PopupMenuItem(
              value: by,
              child: Text(
                // The direction, on the one that is doing the sorting. Tapping
                // it again is what flips it, so it has to be visible there.
                by == value.by
                    ? '${by.i18n} (${value.reversed ? '-' : '+'})'
                    : by.i18n,
                style: TextStyle(
                  color: by == value.by ? UIs.primaryColor : null,
                  fontWeight: by == value.by ? FontWeight.bold : null,
                ),
              ),
            ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _kToggleHidden,
            child: Row(
              spacing: 7,
              children: [
                Icon(
                  hidden ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                ),
                // Expanded, because this label is a translation: 17 characters
                // in English and 28 in French and Indonesian, in a menu whose
                // width is decided by the longest of the three sort names
                // above it. Unwrapped, the longer locales run off the right.
                Expanded(child: Text(l10n.showHiddenFiles)),
              ],
            ),
          ),
        ],
        onSelected: (selected) {
          if (selected == _kToggleHidden) {
            Stores.setting.showHiddenFiles.put(!hidden);
            // The setting is read while sorting, so the list has to be asked
            // to sort again — nothing about the listing itself changed.
            _sort.notify();
            return;
          }
          final by = selected as _SortBy;
          final old = _sort.value;
          _sort.value = by == old.by
              ? _SortOption(by: old.by, reversed: !old.reversed)
              : _SortOption(by: by, reversed: old.reversed);
        },
      );
    });
  }
}

/// Not a [_SortBy], so the menu can carry one entry that is not a sort order.
const _kToggleHidden = 'toggle-hidden';

@immutable
class _SortOption {
  const _SortOption({this.by = _SortBy.name, this.reversed = false});

  final _SortBy by;
  final bool reversed;

  @override
  bool operator ==(Object other) =>
      other is _SortOption && other.by == by && other.reversed == reversed;

  @override
  int get hashCode => Object.hash(by, reversed);
}

enum _SortBy {
  name,
  size,
  time;

  /// Ascending, always, so that the `+` and `-` the menu shows mean the same
  /// thing whichever of the three is chosen.
  int compare(FileEntry a, FileEntry b) => switch (this) {
    name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    // Unknown sizes and times sort last rather than as zero: a backend that
    // did not say is not the same as a file of no size.
    size => _nullsLast(a.size, b.size, (x, y) => x.compareTo(y)),
    time => _nullsLast(a.modified, b.modified, (x, y) => x.compareTo(y)),
  };

  static int _nullsLast<T>(T? a, T? b, int Function(T, T) compare) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return compare(a, b);
  }

  String get i18n => switch (this) {
    name => libL10n.name,
    size => libL10n.size,
    time => libL10n.time,
  };
}

/// The one field the name dialogs are made of, owning its own controller.
///
/// The controller has to outlive the `await` that opened the dialog. Created
/// beside it and disposed in a `finally`, it was torn out from under a field
/// that is still mounted: `showRoundDialog` returns when the route is popped,
/// not when it has finished going away, and `autoFocus` leaves an implicit
/// animation running in the decoration for another 167ms. Rebuilding that
/// against a disposed controller is "Tried to build dirty widget in the wrong
/// build scope", full screen and red.
///
/// A widget's own `dispose` runs when Flutter has finished with the element,
/// which is exactly the moment wanted — so the lifetime belongs here rather
/// than at the call site.
class _NameField extends StatefulWidget {
  const _NameField({required this.icon, this.initial});

  final IconData icon;
  final String? initial;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Answers with the trimmed name, from the field's own context — the dialog
  /// is on the root navigator, and this is inside it.
  void _submit() => context.popDialog(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Input(
          autoFocus: true,
          icon: widget.icon,
          label: libL10n.name,
          controller: _controller,
          suggestion: true,
          onSubmitted: (_) => _submit(),
        ),
        // Here rather than in `actions:`, so the button and the field it reads
        // are in one place and one lifetime.
        Align(
          alignment: Alignment.centerRight,
          child: Btn.ok(onTap: _submit),
        ),
      ],
    );
  }
}

/// A search that lives where it was opened, rather than over everything.
///
/// `showSearch` pushes a route, which is right for a page and wrong for a
/// column: it covers the rail beside it, and the rail is what says which
/// session and which directory is being searched.
///
/// Owns its controller, and disposes it when the widget goes — not when the
/// caller stops waiting, which is what put a red screen on the name dialogs.
class _InlineSearch extends StatefulWidget {
  const _InlineSearch({
    required this.search,
    required this.itemBuilder,
    required this.onClose,
  });

  final Future<List<FileEntry>> Function(String query) search;
  final Widget Function(FileEntry entry) itemBuilder;
  final VoidCallback onClose;

  @override
  State<_InlineSearch> createState() => _InlineSearchState();
}

class _InlineSearchState extends State<_InlineSearch> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A `Scaffold` for its background, not its bar. Without one the column is
    // transparent and the browser underneath — which stays mounted, so that
    // this can be built from its state — shows through it.
    return Scaffold(
      body: Column(
        children: [
        // A row of our own rather than the field inside an `AppBar`: a bar has
        // a fixed height, which squashed the field and squared off its
        // corners. No label and no icon either — a search box beside a back
        // arrow, with the cursor already in it, is not ambiguous.
        Padding(
          // No `sysStatusBarHeight` here. `CustomAppBar` does not add it
          // either — it is a plain `AppBar` with a shorter toolbar — so
          // whatever gives the window caption its room is above both, and
          // adding it here was 32 logical pixels nothing else spends.
          padding: const EdgeInsets.only(left: 3, right: 11, top: 3, bottom: 3),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: libL10n.close,
                onPressed: widget.onClose,
              ),
              Expanded(
                // `noWrap`, wrapped here: `Input`'s own card adds vertical
                // padding on top of the field's own, which is most of a row
                // again in something that is only ever one line.
                child: CardX(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    child: Input(
                      noWrap: true,
                      controller: _query,
                      autoFocus: true,
                      suggestion: false,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureWidget(
            // Rebuilt per query, which is what re-reads the listing: the
            // directory can change under a search that is left open.
            future: widget.search(_query.text),
            loading: UIs.centerLoading,
            error: (e, _) => Center(child: Text('$e', style: UIs.textGrey)),
            success: (entries) {
              final found = entries ?? const <FileEntry>[];
              if (found.isEmpty) {
                return Center(child: Text(libL10n.empty, style: UIs.textGrey));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                itemCount: found.length,
                itemBuilder: (_, i) => widget.itemBuilder(found[i]),
              );
            },
          ),
        ),
        ],
      ),
    );
  }
}
