part of 'file_browser.dart';

/// The browser's bars, list and drop target.
extension _Widgets on _FileBrowserPageState {
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

  /// An editable path field styled as a card to make the interaction clear.
  Widget _buildPathBar() {
    return CardX(
      child: RawAutocomplete<String>(
        textEditingController: _pathCtrl,
        focusNode: _pathFocus,
        optionsBuilder: _pathOptions,
        // Upwards, because this bar is the foot of the page. The default is
        // down, and the space below the bar is the home indicator: the
        // framework sizes the list to what is there, which came to
        // `kMinInteractiveDimension` of it drawn over the field itself. That
        // is why nothing appeared to open at all.
        //
        // Not `mostSpace` — that measures, and the answer here is known: there
        // is never room below a bar that sits on the bottom edge, and a
        // measured choice would put the list below the field on the one screen
        // where the measurement went the other way.
        optionsViewOpenDirection: OptionsViewOpenDirection.up,
        // Picking one goes there. A completion of a path is a directory that
        // exists, so there is nothing else to do with it — and stopping to
        // press return afterwards would be a second answer to a question
        // already answered.
        onSelected: _gotoTyped,
        fieldViewBuilder: (context, controller, node, onSubmit) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
          child: Row(
            children: [
              Expanded(
                // Drawn with no label, since the path in it says what it is;
                // a screen reader was told only the path. Merged, so the name
                // is on the field's own node.
                child: MergeSemantics(
                  child: Semantics(
                    label: libL10n.path,
                    child: TextField(
                      // Named, because it is a text field that is always on
                      // screen: a test looking for "the field a dialog just
                      // opened" would otherwise find two.
                      key: FileBrowserPage.pathFieldKey,
                      controller: controller,
                      focusNode: node,
                      // The path is one line, however long it is, and a soft
                      // keyboard should offer a key that acts rather than one
                      // that wraps.
                      maxLines: 1,
                      textInputAction: TextInputAction.go,
                      onSubmitted: _gotoTyped,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: bareInputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.args.pathTrailing case final trailing?) ...[
                UIs.width7,
                trailing,
              ],
            ],
          ),
        ),
        optionsViewBuilder: (context, onSelected, options) =>
            _buildPathOptions(context, onSelected, options),
      ),
    );
  }

  /// The completions, above the bar and over whatever is behind it.
  ///
  /// Where it goes is settled outside this: the field is the anchor, and the
  /// framework hands this builder a box as wide as the field and as tall as
  /// the space in the chosen direction, with the keyboard already taken off.
  /// So this only has to say what a row looks like, and how much of that space
  /// to take — a list that could grow to the top of the window would cover the
  /// directory it is completing against.
  ///
  /// Its own rather than the Material default, which is a flat rectangle: this
  /// sits over a rounded card, and a corner is the cheapest way to say the two
  /// belong together.
  Widget _buildPathOptions(
    BuildContext context,
    void Function(String) onSelected,
    Iterable<String> options,
  ) {
    final shown = options.toList();
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: shown.length,
          itemBuilder: (_, index) {
            final option = shown[index];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.folder_outlined, size: 18),
              title: Text(option, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => onSelected(option),
              // The other half of picking one: put it in the field and stay
              // there. Tapping the row goes to that directory, which is what
              // is wanted when it is the destination — and is not, when it is
              // one level of a path still being typed.
              trailing: IconButton(
                tooltip: libL10n.edit,
                // Points back at the field, which is where the text goes.
                icon: const Icon(Icons.north_west, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: () => _fillPath(option),
              ),
            );
          },
        ),
      ),
    );
  }

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
      onDragEntered: (_) {
        _dropping.value = true;
        DropZones.enter(this);
      },
      onDragExited: (_) {
        _dropping.value = false;
        DropZones.leave(this);
      },
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

  Widget _buildList() {
    return FutureWidget(
      future: _entries,
      // Nothing for a directory that answers at once, a spinner for one that
      // does not: a slow listing was a blank pane until it arrived, which read
      // as an empty directory.
      loading: const DelayedLoading(),
      error: (e, _) => _buildError(e),
      success: (entries) => ListenBuilder(
        listenable: Listenable.merge([_sort, _search]),
        builder: () {
          final sorted = _sorted(entries ?? const [], _sort.value);
          final needle = _search.needle;
          if (needle.isEmpty) return _buildListView(sorted);

          // The same visibility rule the listing uses. Searching the raw
          // listing meant a query could surface — and open — the dotfiles the
          // user had asked not to see, which is a filter that only holds until
          // someone types.
          final hidden = Stores.setting.showHiddenFiles.fetch();
          final found = [
            for (final entry in sorted)
              if (hidden || !entry.name.startsWith('.'))
                if (entry.name.toLowerCase().contains(needle)) entry,
          ];
          if (found.isEmpty) {
            return EmptyMark(icon: Icons.search_off, label: needle);
          }
          return _buildListView(found);
        },
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
    final icon = _iconOf(entry);

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

  /// The icon pack's or theme's `file.<ext>` glyph when either has one, else
  /// an alias such as `file.css` for `.scss`, else `file.default`, else the
  /// built-in glyph.
  Widget _iconOf(FileEntry entry) {
    final key = ThemeFileIcon.keyOf(
      name: entry.name,
      isDir: entry.isDir,
      isLink: entry.kind == FileKind.link,
    );
    final built = ThemeFileIcon.builtIn(key);
    final material = Icon(built.$1, color: built.$2);
    if (key == ThemeFileIcon.dir || key == ThemeFileIcon.link) {
      return ThemeIconAsset(keyName: key, fallback: material);
    }
    final generic = ThemeIconAsset(
      keyName: ThemeFileIcon.fallback,
      fallback: material,
    );
    if (key == ThemeFileIcon.fallback) return generic;
    final aliased = ThemeFileIcon.aliasOf(key);
    final next = aliased == null
        ? generic
        : ThemeIconAsset(keyName: aliased, fallback: generic);
    return ThemeIconAsset(keyName: key, fallback: next);
  }
}
