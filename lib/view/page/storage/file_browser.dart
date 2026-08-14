import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/file/browse_path.dart';
import 'package:server_box/data/model/file/file_backend.dart';
import 'package:server_box/data/model/file/file_issue.dart';
import 'package:server_box/data/model/file/file_ref.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/storage/send_to.dart';
import 'package:server_box/view/widget/omit_start_text.dart';
import 'package:server_box/view/widget/page_issue.dart';
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
    this.bottomActions,
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

  /// Bottom-bar buttons only this backend has, beside the ones every browser
  /// gets — uploading, which needs somewhere to upload to.
  final List<Widget> Function(FileBrowserHandle)? bottomActions;

  /// Menu entries only this backend has, for one item.
  final List<Widget> Function(
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

  late Future<List<FileEntry>> _entries = _list();

  @override
  FileBackend get backend => widget.args.backend;

  @override
  String get path => _path.path;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _sort.dispose();
    _busy.dispose();
    super.dispose();
  }

  Future<List<FileEntry>> _list() async {
    final listed = _path.path;
    final entries = await backend.list(listed);
    // Here rather than at each move: this is where the browser learns the
    // directory really opened.
    if (mounted) widget.args.onPathChanged?.call(listed);
    return entries;
  }

  /// Filtered and sorted for display, leaving the listing itself alone: both
  /// are local decisions and must not cost a round trip to the server.
  List<FileEntry> _sorted(List<FileEntry> entries, _SortOption option) {
    final foldersFirst = Stores.setting.sftpShowFoldersFirst.fetch();
    final hidden = Stores.setting.showHiddenFiles.fetch();
    return [
      for (final entry in entries)
        if (hidden || !entry.name.startsWith('.')) entry,
    ]
      ..sort((a, b) {
        if (foldersFirst && a.isDir != b.isDir) return a.isDir ? -1 : 1;
        final result = option.by.compare(a, b);
        return option.reversed ? -result : result;
      });
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
      context.showSnackBar('${libL10n.fail}: $target');
      return;
    }
    await refresh();
  }

  void _go(void Function() move) {
    move();
    refresh();
  }

  String _fullPath(FileEntry entry) => BrowsePath.join(_path.path, entry.name);

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

  Future<void> _delete(FileEntry entry) async {
    // Most people do not know that SFTP cannot delete a directory with
    // anything in it, so the choice is offered rather than the failure.
    var recursive = Stores.setting.sftpRmrDir.fetch();
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
                  '${entry.isDir && recursive ? '\n${l10n.sftpRmrDirSummary}' : ''}',
                ),
              ),
            ),
            if (entry.isDir && !Stores.setting.sftpRmrDir.fetch())
              CheckboxListTile(
                title: Text(l10n.sftpRmrDirSummary),
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
    final perm = UnixPerm.fromValue(entry.mode ?? 0);
    var next = perm;
    final ok = await context.showRoundDialog<bool>(
      child: UnixPermEditor(perm: perm, onChanged: (value) => next = value),
      actions: Btnx.okReds,
    );
    if (ok != true || next.value == perm.value) return;
    await _run(() => backend.chmod(_fullPath(entry), next.value));
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
    final controller = TextEditingController(text: initial);
    try {
      final name = await context.showRoundDialog<String>(
        title: title,
        child: Input(
          autoFocus: true,
          icon: icon,
          label: libL10n.name,
          controller: controller,
          suggestion: true,
          onSubmitted: (value) => context.popDialog(value.trim()),
        ),
        actions: Btn.ok(
          onTap: () => context.popDialog(controller.text.trim()),
        ).toList,
      );
      if (name == null || name.isEmpty || !mounted) return null;
      return name;
    } finally {
      controller.dispose();
    }
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
      if (mounted) context.showSnackBar('${libL10n.fail}:\n$e');
      return;
    } finally {
      _busy.value = false;
    }
    await refresh();
  }

  Future<void> _showEntryMenu(FileEntry entry) async {
    final full = _fullPath(entry);
    await context.showRoundDialog(
      title: entry.name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Btn.tile(
            icon: const Icon(Icons.abc),
            text: libL10n.rename,
            onTap: () {
              context.popDialog();
              _rename(entry);
            },
          ),
          Btn.tile(
            icon: const Icon(Icons.delete),
            text: libL10n.delete,
            onTap: () {
              context.popDialog();
              _delete(entry);
            },
          ),
          Btn.tile(
            icon: const Icon(MingCute.copy_line),
            text: l10n.copyPath,
            onTap: () {
              context.popDialog();
              Pfs.copy(full);
              context.showSnackBar(libL10n.success);
            },
          ),
          if (backend.traits.permissions)
            Btn.tile(
              icon: const Icon(Icons.security),
              text: libL10n.permission,
              onTap: () {
                context.popDialog();
                _chmod(entry);
              },
            ),
          // Moving something is the same act wherever it is, so it is offered
          // wherever it can be done rather than as "upload" on one page and
          // "download" on the other.
          if (widget.args.refOf case final refOf?)
            Btn.tile(
              icon: const Icon(Icons.drive_file_move_outline),
              text: l10n.sendTo,
              onTap: () {
                context.popDialog();
                sendTo(
                  context,
                  ref,
                  source: refOf(full),
                  isDir: entry.isDir,
                );
              },
            ),
          ...?widget.args.entryActions?.call(this, entry, full),
        ],
      ),
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

  void _showSearch() {
    showSearch(
      context: context,
      delegate: SearchPage<FileEntry>(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        future: (query) async {
          final entries = await _entries;
          final needle = query.toLowerCase();
          return [
            for (final entry in entries)
              if (entry.name.toLowerCase().contains(needle)) entry,
          ];
        },
        builder: (ctx, entry) => _buildEntry(entry, beforeTap: ctx.pop),
      ),
    );
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final actions = <Widget>[
      ...?widget.args.extraActions?.call(this),
      _buildViewBtn(),
      Btn.icon(icon: const Icon(Icons.search), onTap: _showSearch),
      if (isDesktop)
        Btn.icon(icon: const Icon(Icons.refresh), onTap: refresh),
    ];

    final body = Column(
      children: [
        _busy.listenVal(
          (busy) => busy
              ? const LinearProgressIndicator(minHeight: 2)
              : const SizedBox(height: 2),
        ),
        Expanded(
          child: isMobile
              ? RefreshIndicator(onRefresh: refresh, child: _buildList())
              : _buildList(),
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

  Widget _buildBottom() {
    final children = widget.args.isPickDir
        ? [
            IconButton(
              onPressed: () => context.pop(_path.path),
              icon: const Icon(Icons.done),
            ),
          ]
        : [
            Btn.icon(
              onTap: () {
                if (_path.goBack()) refresh();
              },
              icon: const Icon(Icons.arrow_back),
            ),
            if (widget.args.homePath case final home?)
              Btn.icon(
                onTap: () => goTo(home),
                icon: const Icon(Icons.home),
              ),
            if (!widget.args.isPickFile) _buildAddBtn(),
            Btn.icon(onTap: _goto, icon: const Icon(Icons.gps_fixed)),
            ...?widget.args.bottomActions?.call(this),
          ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 7, 11, 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: OmitStartText(_path.path)),
                if (widget.args.pathTrailing case final trailing?) ...[
                  UIs.width7,
                  trailing,
                ],
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: children,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddBtn() {
    return Btn.icon(
      icon: const Icon(Icons.add),
      onTap: () => context.showRoundDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Btn.tile(
              icon: const Icon(Icons.folder),
              text: libL10n.folder,
              onTap: () {
                context.popDialog();
                _mkdir();
              },
            ),
            Btn.tile(
              icon: const Icon(Icons.insert_drive_file),
              text: libL10n.file,
              onTap: () {
                context.popDialog();
                _newFile();
              },
            ),
          ],
        ),
      ),
    );
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
      onRetry: refresh,
    );
  }

  Widget _buildListView(List<FileEntry> items) {
    final up = _path.canGoUp ? 1 : 0;
    return FadeIn(
      key: ValueKey(_path.path),
      child: ListView.builder(
        // One more than there is, when there is nothing: an empty directory
        // still has to say so, and still has to be leavable.
        itemCount: items.isEmpty ? up + 1 : items.length + up,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 13),
        itemBuilder: (context, index) {
          if (up == 1 && index == 0) {
            return ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: const Text('..'),
              onTap: () => _go(_path.goUp),
            ).cardx;
          }
          if (items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text(libL10n.empty, style: UIs.textGrey)),
            );
          }
          return _buildEntry(items[index - up]);
        },
      ),
    );
  }

  Widget _buildEntry(FileEntry entry, {VoidCallback? beforeTap}) {
    final full = _fullPath(entry);
    final label = widget.args.labelOf?.call(entry, full);
    final icon = Icon(switch (entry.kind) {
      FileKind.dir => Icons.folder_open,
      FileKind.link => Icons.link,
      _ => Icons.insert_drive_file,
    });

    void onTap() {
      beforeTap?.call();
      if (entry.isDir) {
        _go(() => _path.enter(entry.name));
        return;
      }
      if (widget.args.isPickFile) {
        _pick(entry);
        return;
      }
      final open = widget.args.onOpenFile;
      if (open == null) {
        _showEntryMenu(entry);
        return;
      }
      open(this, entry, full);
    }

    void onLongPress() {
      beforeTap?.call();
      _showEntryMenu(entry);
    }

    // Under this, a name and a right-hand column do not both fit, so
    // everything the entry knows goes below the name instead.
    final narrow = MediaQuery.sizeOf(context).width < 350;
    final details = [
      // The real name, where the title is showing something friendlier.
      if (label != null) entry.name,
      if (entry.size case final size? when !entry.isDir) size.bytes2Str,
      if (narrow) ...[
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
        trailing: narrow ? null : _buildEntryTrailing(entry),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
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
                Text(l10n.showHiddenFiles),
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
