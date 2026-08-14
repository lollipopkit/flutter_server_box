import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/model/file/browse_path.dart';
import 'package:server_box/data/model/file/file_backend.dart';

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
}

/// Everything a browser needs beyond the backend itself.
class FileBrowserArgs {
  const FileBrowserArgs({
    required this.backend,
    required this.root,
    this.initialPath,
    this.isPickFile = false,
    this.actionsSink,
    this.onPathChanged,
    this.extraActions,
    this.entryActions,
    this.labelOf,
    this.onOpenFile,
  });

  final FileBackend backend;

  /// The furthest up this browser goes.
  final String root;

  /// Where to open, within [root]. Anything outside lands at the root.
  final String? initialPath;

  /// Picking, not browsing: tapping a file confirms and returns its path.
  final bool isPickFile;

  /// Where to put the toolbar, for a host that draws a bar of its own.
  ///
  /// Given one, this draws no app bar: the file tab already has a strip across
  /// the top, and a page under it with its own bar is two rows of chrome where
  /// one would do.
  final ValueNotifier<List<Widget>>? actionsSink;

  /// Told which directory is shown, as it changes, for a host that outlives
  /// the page and reopens it where it was left.
  final void Function(String path)? onPathChanged;

  /// Toolbar buttons only this backend has.
  final List<Widget> Function(FileBrowserHandle)? extraActions;

  /// Menu entries only this backend has, for one item.
  final List<Widget> Function(
    FileBrowserHandle handle,
    FileEntry entry,
    String fullPath,
  )?
  entryActions;

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
/// in and out, renaming, deleting, making a directory. What is peculiar to a
/// backend arrives through [FileBrowserArgs] rather than a subclass, so there
/// is exactly one of these no matter how many kinds of storage there are.
class FileBrowserPage extends StatefulWidget {
  const FileBrowserPage({super.key, required this.args});

  final FileBrowserArgs args;

  @override
  State<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends State<FileBrowserPage>
    with AutomaticKeepAliveClientMixin
    implements FileBrowserHandle {
  late final _path = BrowsePath(
    root: widget.args.root,
    initial: widget.args.initialPath,
  );
  final _sort = _SortBy.name.vn;
  late Future<List<FileEntry>> _entries = _list();

  @override
  FileBackend get backend => widget.args.backend;

  @override
  String get path => _path.path;

  bool get _isPickFile => widget.args.isPickFile;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _sort.dispose();
    super.dispose();
  }

  Future<List<FileEntry>> _list() async {
    final entries = await backend.list(_path.path);
    // Directories first, then by whatever is chosen. A listing sorted by size
    // that scatters folders through it is not a listing anybody reads.
    entries.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      return _sort.value.compare(a, b);
    });
    return entries;
  }

  @override
  Future<void> refresh() async {
    setStateSafe(() => _entries = _list());
    await _entries;
  }

  void _go(void Function() move) {
    move();
    refresh();
  }

  String _fullPath(FileEntry entry) => BrowsePath.join(_path.path, entry.name);

  // ------------------------------------------------------------------ actions

  Future<void> _rename(FileEntry entry) async {
    final controller = TextEditingController(text: entry.name);
    try {
      final name = await context.showRoundDialog<String>(
        title: libL10n.rename,
        child: Input(
          autoFocus: true,
          icon: Icons.abc,
          label: libL10n.name,
          controller: controller,
          suggestion: true,
          onSubmitted: (value) => context.pop(value.trim()),
        ),
        actions: Btn.ok(onTap: () => context.pop(controller.text.trim())).toList,
      );
      if (name == null || name.isEmpty || name == entry.name || !mounted) {
        return;
      }
      await _run(
        () => backend.rename(
          _fullPath(entry),
          BrowsePath.join(_path.path, name),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _delete(FileEntry entry) async {
    final confirmed = await context.showRoundDialog<bool>(
      title: libL10n.delete,
      child: Text(libL10n.askContinue('${libL10n.delete} ${entry.name}')),
      actions: Btn.ok(onTap: () => context.pop(true)).toList,
    );
    if (confirmed != true || !mounted) return;
    // A directory is emptied first. Only the backend knows whether its
    // protocol can do that in one call — SFTP cannot.
    await _run(() => backend.remove(_fullPath(entry), recursive: entry.isDir));
  }

  Future<void> _mkdir() async {
    final controller = TextEditingController();
    try {
      final name = await context.showRoundDialog<String>(
        title: libL10n.folder,
        child: Input(
          autoFocus: true,
          icon: Icons.folder,
          label: libL10n.name,
          controller: controller,
          onSubmitted: (value) => context.pop(value.trim()),
        ),
        actions: Btn.ok(onTap: () => context.pop(controller.text.trim())).toList,
      );
      if (name == null || name.isEmpty || !mounted) return;
      await _run(() => backend.mkdir(BrowsePath.join(_path.path, name)));
    } finally {
      controller.dispose();
    }
  }

  /// Runs something that changes the listing, and says so when it fails.
  ///
  /// Every mutating action ends the same way — do it, show what went wrong,
  /// look again — and writing that out five times is how one of them ends up
  /// silently swallowing its error.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) context.showSnackBar('${libL10n.fail}:\n$e');
      return;
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
          ...?widget.args.entryActions?.call(this, entry, full),
        ],
      ),
    );
  }

  Future<void> _pick(FileEntry entry) async {
    final picked = await context.showRoundDialog<bool>(
      title: libL10n.file,
      child: Text(entry.name),
      actions: Btn.ok(onTap: () => context.pop(true)).toList,
    );
    if (picked != true || !mounted) return;
    context.pop(_fullPath(entry));
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final actions = <Widget>[
      ...?widget.args.extraActions?.call(this),
      if (!_isPickFile)
        IconButton(
          onPressed: _mkdir,
          tooltip: libL10n.folder,
          icon: const Icon(Icons.create_new_folder_outlined),
        ),
      if (!isMobile)
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: MaterialLocalizations.of(
            context,
          ).refreshIndicatorSemanticLabel,
          onPressed: refresh,
        ),
      _buildSortBtn(),
    ];

    final body = isMobile
        ? RefreshIndicator(onRefresh: refresh, child: _sort.listen(_buildList))
        : _sort.listen(_buildList);

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
      );
    }

    // Handed over after the frame, not during it: a notifier written while
    // building tells its listeners to rebuild in the middle of a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      sink.value = actions;
      widget.args.onPathChanged?.call(_path.path);
    });
    return Scaffold(body: body);
  }

  Widget _buildList() {
    return FutureWidget(
      future: _entries,
      loading: UIs.placeholder,
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('${libL10n.fail}:\n$e', textAlign: TextAlign.center),
        ),
      ),
      success: (entries) {
        final items = entries ?? const <FileEntry>[];
        final up = _path.canGoUp ? 1 : 0;
        return ListView.builder(
          itemCount: items.length + up,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 13),
          itemBuilder: (context, index) {
            if (up == 1 && index == 0) {
              return ListTile(
                leading: const Icon(Icons.arrow_back),
                title: const Text('..'),
                onTap: () => _go(_path.goUp),
              ).cardx;
            }
            return _buildEntry(items[index - up]);
          },
        );
      },
    );
  }

  Widget _buildEntry(FileEntry entry) {
    final full = _fullPath(entry);
    final label = widget.args.labelOf?.call(entry, full);
    return CardX(
      child: ListTile(
        leading: Icon(switch (entry.kind) {
          FileKind.dir => Icons.folder_open,
          FileKind.link => Icons.link,
          _ => Icons.insert_drive_file,
        }),
        title: Text(label ?? entry.name),
        subtitle: switch ((label, entry.size)) {
          // The real name, where the title is showing something friendlier.
          (final String _, _) => Text(entry.name, style: UIs.textGrey),
          (_, final int size) => Text(size.bytes2Str, style: UIs.textGrey),
          _ => null,
        },
        trailing: entry.modified == null
            ? null
            : Text(entry.modified!.ymdhms(), style: UIs.textGrey),
        onLongPress: () => _showEntryMenu(entry),
        onTap: () {
          if (entry.isDir) {
            _go(() => _path.enter(entry.name));
            return;
          }
          if (_isPickFile) {
            _pick(entry);
            return;
          }
          final open = widget.args.onOpenFile;
          if (open == null) {
            _showEntryMenu(entry);
            return;
          }
          open(this, entry, full);
        },
      ),
    );
  }

  Widget _buildSortBtn() {
    return _sort.listenVal((value) {
      return PopupMenuButton<_SortBy>(
        icon: const Icon(Icons.sort),
        initialValue: value,
        itemBuilder: (_) => _SortBy.values.map((e) => e.menuItem).toList(),
        onSelected: (selected) {
          _sort.value = selected;
          refresh();
        },
      );
    });
  }
}

enum _SortBy {
  name,
  size,
  time;

  int compare(FileEntry a, FileEntry b) => switch (this) {
    name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    // Unknown sizes and times sort last rather than as zero: a backend that
    // did not say is not the same as a file of no size.
    size => _nullsLast(a.size, b.size, (x, y) => y.compareTo(x)),
    time => _nullsLast(a.modified, b.modified, (x, y) => y.compareTo(x)),
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

  IconData get icon => switch (this) {
    name => Icons.sort_by_alpha,
    size => Icons.sort,
    time => Icons.access_time,
  };

  PopupMenuItem<_SortBy> get menuItem => PopupMenuItem(
    value: this,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [Icon(icon), Text(i18n)],
    ),
  );
}
