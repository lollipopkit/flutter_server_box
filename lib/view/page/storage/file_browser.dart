import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/file/browse_path.dart';
import 'package:server_box/data/model/file/file_backend.dart';
import 'package:server_box/data/model/file/file_issue.dart';
import 'package:server_box/data/model/file/file_ref.dart';
import 'package:server_box/data/model/file/transfer.dart';
import 'package:server_box/data/provider/file_transfer.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/storage/send_to.dart';
import 'package:server_box/view/page/storage/transfer_announce.dart';
import 'package:server_box/view/widget/delayed_loading.dart';
import 'package:server_box/view/widget/unix_perm.dart';

part 'file_browser_actions.dart';
part 'file_browser_widgets.dart';
part 'file_browser_navigation.dart';

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
  final ValueNotifier<List<BarAction>>? actionsSink;

  /// Told which directory is shown, once a listing of it has succeeded.
  ///
  /// After the listing rather than at each move, because that is the moment
  /// the browser knows the directory is really there — a host that reopens
  /// where it was left should not be handed a path that failed to open.
  final void Function(String path)? onPathChanged;

  /// Toolbar buttons only this backend has.
  final List<BarAction> Function(FileBrowserHandle)? extraActions;

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

  /// The address bar's field.
  ///
  /// Public so a test can tell it from a field that has just been opened —
  /// this one is always on screen, being the path itself.
  static const pathFieldKey = ValueKey('file-browser-path');

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

  /// The bar's search: what is typed, and whether the bar is a field at all.
  final _search = InlineSearchController();

  /// The address bar, which is a field rather than a label that opens one.
  ///
  /// Kept in step with [_path] by [refresh], which every move goes through —
  /// and only there, because writing it during a build would notify the field
  /// mid-frame. While it has focus it is the user's: a listing arriving under
  /// a half-typed path must not retype it.
  /// Seeded rather than filled by the first [refresh]: the opening listing
  /// comes from the field initialiser below, not from a move, so nothing would
  /// have put the starting path in it.
  ///
  /// Through [_displayPath], like every other write to it. Seeded with the raw
  /// path the bar opened showing the container prefix — until the first move,
  /// which is what made it look like the stripping worked — and anything typed
  /// from there was read back as root-relative and re-rooted, naming
  /// `<root><root>/…`. Nothing exists there, so no path ever completed.
  late final _pathCtrl = TextEditingController(text: _displayPath(_path.path));

  /// Leaving the field puts the current path back — see [_onPathFocusChange].
  late final _pathFocus = FocusNode()..addListener(_onPathFocusChange);

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
    _search.dispose();
    _pathFocus.removeListener(_onPathFocusChange);
    _pathFocus.dispose();
    _pathCtrl.dispose();
    _busy.dispose();
    _dropping.dispose();
    _listFocus.dispose();
    super.dispose();
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

  /// Finished transfers this listing has already reacted to.
  ///
  /// A transfer keeps notifying after it finishes — the row stays until it is
  /// cleared — so without this the listing would reload on every one of those.
  final _landed = <int>{};

  @override
  Future<void> refresh() async {
    _syncPathField();
    // Every mutation ends here, so this is where what a completion remembers
    // stops being true: a folder just made would not be offered, and one just
    // deleted would be. Dropped rather than reloaded — the next keystroke in
    // the address bar reads the directory again, and until there is one there
    // is nothing to be stale.
    _completionDir = null;
    _completionEntries = null;
    _completionRevision++;
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

  /// What the last completion listed, and for which directory.
  ///
  /// One directory's worth, because that is what a completion needs: every
  /// keystroke past the last `/` narrows the same listing. Without it each one
  /// was a round trip to the server.
  String? _completionDir;
  List<FileEntry>? _completionEntries;

  /// Which generation of the directory the cache belongs to.
  ///
  /// Bumped wherever the cache is dropped, so that a listing already in flight
  /// cannot put back what it was carrying — see [_pathOptions].
  int _completionRevision = 0;

  @override
  Future<void> goTo(String target) async {
    if (!_path.goTo(target)) {
      Toast.error(libL10n.fail, body: target);
      return;
    }
    await refresh();
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

  /// What a single-target key acts on: what is picked out if exactly one is,
  /// else where the keyboard is. Two selected and F2 is ambiguous, so it does
  /// nothing rather than renaming whichever came first.
  FileEntry? get _cursorOrOnlySelected {
    if (_selected.length == 1) return _selectedEntries.firstOrNull;
    if (_selected.isNotEmpty) return null;
    return _cursorEntry;
  }

  // ------------------------------------------------------------------ actions

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

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Listened rather than watched: an arriving file changes what is on disk,
    // not what this widget renders, so the answer is to go and read the
    // directory again — not to rebuild on every progress tick.
    ref.listen(fileTransferProvider, (_, next) => _refreshOnArrival(next));

    final actions = <BarAction>[
      ...?widget.args.extraActions?.call(this),
      // The same menu a right-click on the directory gives — new folder, new
      // file, and bringing one in from outside — where it can be seen. It was
      // reachable only by secondary tap, which a phone does not have, so on
      // every mobile build the one visible `+` in this tab belonged to the
      // *server* list and adding a file had no button at all.
      if (!widget.args.isPickFile && !widget.args.isPickDir)
        // A menu that drops from this button rather than a dialog in the
        // middle of the page.
        BarAction.menu(
          icon: Icons.add,
          label: libL10n.add,
          menu: () => _createActions,
        ),
      _viewAction,
      BarAction(
        icon: Icons.search,
        label: libL10n.search,
        onTap: _search.start,
      ),
      if (isDesktop)
        BarAction(icon: Icons.refresh, label: libL10n.refresh, onTap: refresh),
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
      // Listened to, not read: the bar is a field or a title depending on it.
      return ListenableBuilder(
        listenable: _search,
        builder: (_, _) => Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: WindowControlsInset(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                // In place of the title and its buttons, as on every other page
                // that searches in this app.
                child: InlineSearchBar(
                  controller: _search,
                  child: CustomAppBar(
                    title: AnimatedSwitcher(
                      duration: Durations.short3,
                      child: Text(title, key: ValueKey(title)),
                    ),
                    actions: [
                      for (final action in actions) action.button(),
                      const SizedBox(width: 7),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: body,
        bottomNavigationBar: _buildBottom(),
      ),
      );
    }

    // Handed over after the frame, not during it: a notifier written while
    // building tells its listeners to rebuild in the middle of a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) sink.value = actions;
    });
    // The bar here is the host's — this page only hands it a list of actions —
    // so the field cannot take its place. It goes at the head of the listing
    // instead, which is the thing being searched.
    return ListenableBuilder(
      listenable: _search,
      builder: (_, _) => Scaffold(
        body: Column(
          children: [
            // The same swap every other bar makes, against nothing: there is
            // no row here when no search is on, so `AnimatedSize` gives the
            // opening and closing a height to animate.
            AnimatedSize(
              duration: context.motion(Durations.short4),
              alignment: Alignment.topCenter,
              child: InlineSearchBar(
                controller: _search,
                child: const SizedBox(width: double.infinity),
              ),
            ),
            Expanded(child: body),
          ],
        ),
        bottomNavigationBar: _buildBottom(),
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

  /// How this list is shown: what it is ordered by, and whether it hides the
  /// dotfiles. One menu, because both are the same kind of decision and the
  /// toolbar has no room for a button each.
  BarAction get _viewAction => BarAction.listen(
    listenable: _sort,
    build: (_) {
      final value = _sort.value;
      final hidden = Stores.setting.showHiddenFiles.fetch();
      return BarAction.menu(
        icon: Icons.sort,
        label: libL10n.sort,
        menu: () => [
          for (final by in _SortBy.values)
            ContextMenuAction(
              text: by.i18n,
              // The direction, on the one that is doing the sorting. Tapping
              // it again is what flips it, so it has to be visible there.
              note: by == value.by ? (value.reversed ? '↓' : '↑') : null,
              checked: by == value.by,
              onTap: () => _sort.value = by == value.by
                  ? _SortOption(by: by, reversed: !value.reversed)
                  : _SortOption(by: by, reversed: value.reversed),
            ),
          ContextMenuAction(
            text: l10n.showHiddenFiles,
            icon: hidden ? Icons.check_box : Icons.check_box_outline_blank,
            onTap: () {
              Stores.setting.showHiddenFiles.put(!hidden);
              // The setting is read while sorting, so the list has to be
              // asked to sort again — nothing about the listing changed.
              _sort.notify();
            },
          ),
        ],
      );
    },
  );

}

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

  /// Ascending, always, so that the arrow the menu shows means the same
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
