part of 'entry.dart';

/// Height of the floating tab bar, and the gap around it.
///
/// The gap is carried by the bar's own padding rather than by where it is
/// placed, so that its shadow falls inside the scroll view that clips it. The
/// two shadows are written to stay within this much — see where they are built.
const _kTabsHeight = 56.0;
const _kTabsMargin = 12.0;

/// Displacement springs past its mark and settles, as it does elsewhere.
/// Only the bar's own width: a size factor past 1 would be a gap.
const _kTabsCurve = Curves.easeOutBack;

/// The same tree as [_SettingsMenu], one level at a time.
///
/// A narrow window has no room for a column beside the content, and a drawer
/// hides where you are the moment you have gone there. This shows the level you
/// are on, floating over the foot of the content.
///
/// Only the level: the way back out is the title bar's own button, which is
/// where every other page in the app puts it. A second one here was the same
/// move twice on one screen.
final class _SettingsTabs extends StatelessWidget {
  /// The level being shown, which is the root or one branch's children.
  final List<SettingsNode> nodes;

  final String? selectedId;
  final void Function(SettingsNode node) onTap;

  const _SettingsTabs({
    super.key,
    required this.nodes,
    required this.selectedId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(_kTabsHeight / 2);

    final row = SizedBox(
      height: _kTabsHeight,
      child: Row(
        // As wide as what is on it. A level of two tabs is a short bar.
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 4),
          for (final node in nodes)
            _TabButton(
              icon: node.icon,
              label: node.title,
              // A branch counts as on while what is showing is inside it.
              selected: node.flattened.any((e) => e.id == selectedId),
              onTap: () => onTap(node),
            ),
          const SizedBox(width: 4),
        ],
      ),
    );

    // Translucent and blurring what goes behind it, because the content runs
    // the full height of the page and passes under here rather than stopping
    // above it. Opaque, the bar sat in a band of bare background and read as a
    // second bottom bar instead of as something over the page.
    //
    // The shadow is outside the clip: inside, the rounded rect that keeps the
    // blur in would cut it off.
    //
    // An elevation and not a single `BoxShadow`: one soft shadow at 16% is
    // visible over the content on a full page and invisible over the bare
    // background of a short one, which is where it was first noticed. What
    // Flutter draws for an elevation carries far enough to read either way.
    //
    // Low, because the bar only has to read as being over the page. At 8 and
    // a third of black it was a dark band under the bar, which on a light
    // theme is the most prominent thing on the screen.
    final bar = Material(
      color: Colors.transparent,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: radius,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            key: settingsTabsKey,
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.72),
            // Around the row rather than inside it, so the bar itself is what
            // springs between one level's width and the next. Inside, the
            // overshoot would be a gap opening at the end of a bar that had
            // already stopped growing.
            child: AnimatedSize(
              duration: Durations.medium2,
              curve: _kTabsCurve,
              alignment: Alignment.centerLeft,
              child: row,
            ),
          ),
        ),
      ),
    );

    // Centred while it fits and scrolled when it does not: the first level has
    // more tabs than a phone is wide, and the levels under it have three.
    //
    // The vertical padding is the room the shadow needs. A scroll view clips to
    // its viewport, and this one's viewport is as tall as the bar exactly — so
    // the shadow was cut off above and below while the sides, which have the
    // width of the page to spread into, kept theirs. Padding grows the viewport
    // instead of turning the clip off, which the horizontal axis still needs:
    // a level too wide for the phone has to scroll out of sight, not spill.
    //
    // It is padding here rather than an offset on the `Positioned` that places
    // this, so the bar sits where it always did — see [_kTabsMargin].
    //
    // A level wider than the window ends at the window's edge, and a tab cut
    // off square there reads as the last one rather than as one of several
    // more — hence [EdgeFadeScroll] around it, which says the bar carries on.
    return EdgeFadeScroll(
      builder: (context, controller) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(_kTabsMargin),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: math.max(0, constraints.maxWidth - _kTabsMargin * 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [bar],
            ),
          ),
        ),
      ),
    );
  }
}

final class _TabButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool selected;
  final VoidCallback? onTap;

  const _TabButton({
    required this.icon,
    this.label,
    this.selected = false,
    this.onTap,
  });

  /// The pill behind the icon, at the measurements `NavigationBar` uses.
  ///
  /// It sizes the icon's background and nothing else. The label below is left
  /// to its own width, so a tab is as wide as its name — the pill only sets
  /// how narrow a short one can get.
  static const _indicator = Size(56, 30);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;

    // Which tab is on is a colour and a pill, neither of which a screen reader
    // has any way to read. `TabBar` says it for its own tabs; this bar is not
    // one, so it says it here.
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // Wider than it was. The label used to sit in a fixed box and centre
          // itself in it, which left a gap either side whatever it said; now it
          // reaches the edges of its tab, and two of them need keeping apart.
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Around the icon and not the label, the way the rail on the home
              // page marks its own destination.
              AnimatedContainer(
                duration: Durations.short3,
                curve: Curves.easeOut,
                width: _indicator.width,
                height: _indicator.height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? scheme.secondaryContainer : null,
                  borderRadius: BorderRadius.circular(_indicator.height / 2),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              if (label != null) ...[
                const SizedBox(height: 3),
                // Unconstrained: a tab is as wide as its own name. Held to the
                // pill's width these ellipsed — they are section names, not the
                // one or two words a bottom bar carries, and several languages
                // spell them longer still. The bar already scrolls sideways
                // when a level does not fit across the window, so the room is
                // there to be taken.
                Text(
                  label!,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.1,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The subject over the content, and the pages inside it.
///
/// One row, the way the menu beside it is one column: which subject is being
/// read is the title, and which of its pages is on screen is the lit tab.
final class _SettingsContentHeader extends StatelessWidget {
  const _SettingsContentHeader({
    required this.title,
    required this.nodes,
    required this.selectedId,
    required this.onTap,
    required this.actions,
  });

  final String title;

  /// The pages inside [title]. One of them — a subject that is a page — gets
  /// no tabs: a row with one tab on it says what the title just said.
  final List<SettingsNode> nodes;

  final String? selectedId;
  final void Function(SettingsNode node) onTap;

  /// What acts on the settings as a whole, at the far end of the row.
  ///
  /// Here and not in the bar above, on a wide window: that bar spans the menu
  /// column too, and it is this pane these act on.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: settingsHeaderKey,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Hairline.color(context),
            width: Hairline.thickness,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          UIs.width13,
          // Scrolled rather than wrapped: a subject with five pages in a
          // language that spells them long is wider than the pane, and a
          // header that grew a second line would move the content under it.
          Expanded(
            child: nodes.length < 2
                ? const SizedBox.shrink()
                : EdgeFadeScroll(
                    builder: (context, controller) => SingleChildScrollView(
                      controller: controller,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 3,
                        children: [
                          for (final node in nodes)
                            _SettingsPill(
                              label: node.title,
                              selected: node.id == selectedId,
                              onTap: () => onTap(node),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

final class _SettingsPill extends StatelessWidget {
  const _SettingsPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: selected ? scheme.secondaryContainer : Colors.transparent,
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: selected ? scheme.onSecondaryContainer : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One level's leaves, side by side.
///
/// A [PageView] rather than one page swapped for another: the tabs under it are
/// siblings, so moving between them is moving along a row, and it should look
/// like it. Dragging the content does the same thing as tapping a tab, which is
/// what having them side by side promises.
final class _SettingsPages extends StatefulWidget {
  final List<SettingsNode> leaves;
  final String selectedId;
  final void Function(SettingsNode node) onChanged;

  const _SettingsPages({
    super.key,
    required this.leaves,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  State<_SettingsPages> createState() => _SettingsPagesState();
}

class _SettingsPagesState extends State<_SettingsPages> {
  late final PageController _controller = PageController(initialPage: _indexOf(widget.selectedId));

  /// Where a tap is currently being animated to, and null the rest of the time.
  ///
  /// `animateToPage` scrolls through every page between here and there, and
  /// `PageView` reports each one it passes. Without this, tapping the fourth
  /// tab announced the second and the third on the way, which named them in
  /// the title bar and wrote each to the settings navigator.
  int? _animatingTo;

  /// Which animation [_animatingTo] belongs to.
  ///
  /// A second tap mid-flight starts a second animation, and the first one's
  /// completion still arrives. Without a generation it would clear the guard
  /// that the animation still running had just set.
  int _animation = 0;

  int _indexOf(String id) {
    final index = widget.leaves.indexWhere((e) => e.id == id);
    return index < 0 ? 0 : index;
  }

  @override
  void didUpdateWidget(_SettingsPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId == oldWidget.selectedId) return;
    final target = _indexOf(widget.selectedId);
    if (!_controller.hasClients || _controller.page?.round() == target) return;

    final animation = ++_animation;
    _animatingTo = target;
    _controller
        .animateToPage(
          target,
          duration: Durations.medium2,
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (!mounted || animation != _animation) return;
          _animatingTo = null;
          // A drag can interrupt the animation, and where it came to rest is a
          // choice like any other — reported now rather than dropped, or the
          // tabs would keep pointing at a page nobody is on.
          final landed = _controller.page?.round();
          if (landed != null && landed != target && landed < widget.leaves.length) {
            widget.onChanged(widget.leaves[landed]);
          }
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      // Told rather than inferred: a drag that lands on another page has picked
      // it, and the tabs have to say so. Pages passed through on the way to a
      // tapped one are not landings — see [_animatingTo].
      onPageChanged: (index) {
        if (_animatingTo != null && index != _animatingTo) return;
        widget.onChanged(widget.leaves[index]);
      },
      itemCount: widget.leaves.length,
      // Built as it is reached. Every page change rebuilds this widget — that
      // is how the tabs hear about a swipe — and a `children` list builds all
      // of a group's pages again each time, including the ones no drag can
      // reach without passing through the neighbour first.
      itemBuilder: (_, index) => widget.leaves[index].builder!(),
    );
  }
}
