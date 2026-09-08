import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/model/plugin/icons.dart';
import 'package:server_box/data/model/plugin/l10n.dart';
import 'package:server_box/data/model/plugin/node.dart';
import 'package:server_box/view/widget/plugin/surface.dart';

/// What a plugin's tree is drawn with. PLUGINS.md section 5.
///
/// Two rules run through all of it:
///
/// - **A bad node costs that node.** An unknown type, a property of the wrong
///   shape, a stub the app has nothing for — each draws a placeholder saying
///   so, and the rest of the surface is unaffected. A plugin is not trusted to
///   produce a tree this build understands, and the worst outcome of a wrong
///   one should be a visible gap.
/// - **The app's own widgets, never a plugin's colours.** `tone` is a name and
///   the theme decides what it looks like, so a plugin cannot ship something
///   unreadable in dark mode.
class PluginRenderer extends StatelessWidget {
  const PluginRenderer({
    super.key,
    required this.tree,
    required this.state,
    this.onEvent,
  });

  final PluginNode tree;

  /// What the surface remembers between frames: the widget cache, the bound
  /// slots' notifiers, and the plugin's translations.
  final PluginSurfaceState state;

  /// Called with the message the plugin attached, and the control's current
  /// value where it has one. The app never reads the message.
  final void Function(Object? msg, Object? value)? onEvent;

  @override
  Widget build(BuildContext context) {
    final built = _Builder(state, onEvent).build(context, tree);
    // Only after the tree is built: what is reachable is what was named.
    state.keepOnly(tree.revisions());
    return built;
  }
}

class _Builder {
  _Builder(this.state, this.onEvent);

  final PluginSurfaceState state;
  final void Function(Object? msg, Object? value)? onEvent;

  PluginL10n get l10n => state.l10n;

  /// [inFlex] is whether this node's parent lays its children out in a row or
  /// a column — which `expanded` and `spacer` need and cannot ask for.
  ///
  /// Flutter throws at layout time when an `Expanded` is not inside a `Flex`,
  /// and that throw takes the whole surface. A plugin can produce one by
  /// writing `expanded(...)` at the top of a card, so the parent's type is
  /// carried down and those two degrade to something harmless instead — which
  /// is the same rule as the rest of this file: a bad node costs that node.
  Widget build(BuildContext context, PluginNode node, {bool inFlex = false}) {
    // "You already have this subtree." Handing back the same instance is what
    // makes `Element.updateChild` return without walking into it.
    if (node.stub) {
      final rev = node.rev;
      final cached = rev == null ? null : state.widgetOf(rev);
      if (cached != null) return cached;
      // The plugin believed the app held a subtree it does not. Nothing here
      // can invent it — a stub carries no properties and no children — so it
      // is reported where it happened rather than drawn as an empty gap.
      return _problem('stale revision ${rev ?? '?'}');
    }

    final widget = _keyed(node, _tappable(context, node, _content(context, node, inFlex)));
    final rev = node.rev;
    if (rev != null) state.remember(rev, widget);
    return widget;
  }

  /// Makes any node carrying a `tap` event answer one.
  ///
  /// `sb.ui.onTap` is declared for **any** node and was honoured only by
  /// `btn`, so a plugin that wrapped a tag, a card or a row — which is what
  /// every action in a list is — drew something that looked like a control and
  /// did nothing. A page of rows you cannot open is the whole feature missing,
  /// and nothing said so: the tree was valid and the event was simply never
  /// read.
  ///
  /// Two types are skipped because they wire it themselves and would
  /// otherwise fire twice: `btn`, and `tile`, which hands it to `ListTile` so
  /// the ripple is the row rather than a rectangle inside it.
  Widget _tappable(BuildContext context, PluginNode node, Widget child) {
    if (node.type == 'btn' || node.type == 'tile') return child;
    final msg = node.events['tap'];
    if (msg == null || onEvent == null) return child;

    // Its own `Material`, because a plugin may put a tap on anything and
    // anywhere — an `InkWell` that only works under one particular ancestor
    // fails as a red screen rather than as a compile error.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => onEvent!(msg, null),
        borderRadius: BorderRadius.circular(7),
        child: child,
      ),
    );
  }

  Widget _keyed(PluginNode node, Widget child) {
    final k = node.key;
    if (k == null) return child;
    // `Widget.canUpdate` compares `runtimeType` and `key`. Without one, a
    // reordered set of children is matched positionally and every element —
    // with its focus, scroll offset and expanded state — is discarded.
    return KeyedSubtree(key: ValueKey(k), child: child);
  }

  Widget _content(BuildContext context, PluginNode node, bool inFlex) {
    return switch (node.type) {
      // ---- layout
      'column' => Column(
        // `min`, so a column is as tall as what is in it. The default is
        // `max`, which fills whatever height it is given — a settings page
        // whose whole content is one switch drew a card down the entire
        // window. A plugin that wants the remaining space says so with
        // `expanded`, and that still works here: a tight flex child takes the
        // free space and the column ends up filling after all.
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: _num(node, 'spacing')?.toDouble() ?? 0,
        children: _children(context, node, inFlex: true),
      ),
      'row' => Row(
        spacing: _num(node, 'spacing')?.toDouble() ?? 0,
        children: _children(context, node, inFlex: true),
      ),
      // Outside a row or a column there is nothing to take the remaining
      // space from, so the child is drawn as it is rather than throwing.
      'expanded' => inFlex
          ? Expanded(child: _onlyChild(context, node))
          : _onlyChild(context, node),
      'padding' => Padding(
        padding: EdgeInsets.all(_num(node, 'all')?.toDouble() ?? 0),
        child: _onlyChild(context, node),
      ),
      'sized' => SizedBox(
        width: _num(node, 'width')?.toDouble(),
        height: _num(node, 'height')?.toDouble(),
        child: _onlyChild(context, node),
      ),
      'scroll' => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _children(context, node),
        ),
      ),
      'list' => _list(context, node),
      'spacer' => inFlex ? const Spacer() : const SizedBox.shrink(),
      'divider' => const Divider(height: 1),

      // ---- content and controls
      // A boundary per card, so one card repainting does not repaint the page
      // it sits on.
      'card' => RepaintBoundary(
        child: CardX(
          child: Padding(
            // A card of rows insets its own rows — adding 13 more here would
            // put every title 26px from the edge and make a list look nested
            // inside its own card. Everything else gets the padding a block of
            // content needs.
            padding: node.children.every((c) => c.type == 'tile')
                ? const EdgeInsets.symmetric(vertical: 4)
                : const EdgeInsets.all(13),
            child: Column(
              // As tall as its rows. See the `column` case above.
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _children(context, node),
            ),
          ),
        ),
      ),
      'tile' => _tile(context, node),
      'summary' => _summary(context, node),
      'kv' => _kv(context, node),
      'expand' => _expand(context, node),
      'percent' => _percent(context, node),
      'progress' => _progress(context, node),
      'text' => _text(context, node),
      'tag' => _tag(context, node),
      'icon' => _icon(node),
      'btn' => _btn(context, node),
      'input' => _input(node),
      'toggle' => _toggle(context, node),
      'table' => _table(context, node),
      'line_chart' || 'bar_chart' => _chart(context, node),
      _ => _problem('unknown widget "${node.type}"'),
    };
  }

  List<Widget> _children(
    BuildContext context,
    PluginNode node, {
    bool inFlex = false,
  }) => [
    for (final child in node.children) build(context, child, inFlex: inFlex),
  ];

  Widget _onlyChild(BuildContext context, PluginNode node) {
    final children = node.children;
    if (children.isEmpty) return const SizedBox.shrink();
    return build(context, children.first);
  }

  // ------------------------------------------------------------- leaves

  /// A leaf whose look depends only on [signature], reused across frames.
  ///
  /// The same fast path revisions buy, for a node that carries none: a `text`
  /// showing the same string twice is one object, so `updateChild` returns
  /// without touching it. Skipped for a bound leaf, which is a
  /// [ValueListenableBuilder] whose identity has to stay tied to its slot.
  Widget _cachedLeaf(String signature, Widget Function() build) {
    final cached = state.leaf(signature);
    if (cached != null) return cached;
    final built = build();
    state.rememberLeaf(signature, built);
    return built;
  }

  Widget _text(BuildContext context, PluginNode node) {
    final tone = _tone(context, node);
    return _bound(node, 'value', (raw) {
      final value = l10n.resolve('${raw ?? ''}');
      return Text(value, style: TextStyle(color: tone));
    }, cacheKey: (raw) => 'text|$raw|${tone?.toARGB32()}');
  }

  /// One row of a list, drawn the way the app draws its own.
  ///
  /// The app's dense `ListTile`, so a plugin's list and the process, package
  /// and container lists beside it share one rhythm. Before this a plugin had
  /// to build a row out of `row` and `text` and put each one in its own card,
  /// which gave five facts a whole window and no two plugins the same spacing.
  Widget _tile(BuildContext context, PluginNode node) {
    final icon = PluginIcons.resolve('${node.props['icon'] ?? ''}');
    final subtitle = node.props['subtitle'];
    final trailing = node.children.isEmpty
        ? null
        : build(context, node.children.first);

    final msg = node.events['tap'];
    return _bound(node, 'title', (raw) {
      return ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13),
        onTap: msg == null || onEvent == null
            ? null
            : () => onEvent!(msg, null),
        leading: icon == null
            ? null
            : Icon(icon, size: 19, color: context.theme.hintColor),
        // `min` so a row with no subtitle is one line high rather than the
        // two a `ListTile` reserves by default.
        minLeadingWidth: icon == null ? 0 : null,
        title: Text(l10n.resolve('${raw ?? ''}'), style: UIs.text13),
        subtitle: subtitle == null
            ? null
            : Text(l10n.resolve('$subtitle'), style: UIs.text12Grey),
        trailing: trailing,
      );
      // The message is part of the identity: two rows that differ only in
      // where they lead are two rows.
    }, cacheKey: (raw) => 'tile|$raw|$subtitle|${node.props['icon']}|$msg');
  }

  /// What the page answers, in one reading, above the list that details it.
  ///
  /// The figure is set large and everything else is quiet around it, which is
  /// the whole of the hierarchy: without it a page is one flat stack where the
  /// count and the rows carry the same weight.
  Widget _summary(BuildContext context, PluginNode node) {
    final label = node.props['label'];
    final detail = node.props['detail'];
    final actions = _children(context, node);

    return _bound(node, 'value', (raw) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(17, 13, 13, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (label != null)
                    Text(
                      l10n.resolve('$label').toUpperCase(),
                      style: UIs.text11Grey.copyWith(letterSpacing: 0.8),
                    ),
                  Text(
                    l10n.resolve('${raw ?? ''}'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  if (detail != null)
                    Text(l10n.resolve('$detail'), style: UIs.text12Grey),
                ],
              ),
            ),
            if (actions.isNotEmpty) Row(spacing: 7, children: actions),
          ],
        ),
      );
    }, cacheKey: (raw) => 'summary|$raw|$label|$detail');
  }

  Widget _kv(BuildContext context, PluginNode node) {
    final label = l10n.resolve('${node.props['k'] ?? ''}');
    return _bound(node, 'v', (raw) {
      return KvRow(k: label, v: l10n.resolve('${raw ?? ''}'));
    }, cacheKey: (raw) => 'kv|$label|$raw');
  }

  Widget _tag(BuildContext context, PluginNode node) {
    final tone = _tone(context, node) ?? context.theme.colorScheme.primary;
    return _bound(node, 'label', (raw) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          l10n.resolve('${raw ?? ''}'),
          style: TextStyle(fontSize: 11, color: tone),
        ),
      );
    }, cacheKey: (raw) => 'tag|$raw|${tone.toARGB32()}');
  }

  /// A share of a whole, as a bar.
  ///
  /// A bar and not a ring. A ring at row height is a few pixels of arc, which
  /// reads as a spinner rather than as a proportion — and a column of them
  /// cannot be compared, which is the one thing a share is for. A bar has a
  /// baseline and a common left edge, so a list of them is a chart.
  Widget _percent(BuildContext context, PluginNode node) {
    final label = l10n.resolve('${node.props['label'] ?? ''}');
    return _bound(node, 'value', (raw) {
      final value = _asDouble(raw)?.clamp(0.0, 1.0) ?? 0.0;
      final bar = ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 5,
          backgroundColor: context.theme.hintColor.withValues(alpha: 0.15),
        ),
      );
      if (label.isEmpty) return bar;
      return Row(
        spacing: 9,
        children: [
          Expanded(child: bar),
          Text(label, style: UIs.text12Grey),
        ],
      );
    }, cacheKey: (raw) => 'percent|$label|$raw');
  }

  Widget _progress(BuildContext context, PluginNode node) {
    // Determinate when a value is given, spinning when it is not — which is
    // what a plugin says by leaving the property out.
    if (!node.props.containsKey('value')) {
      return _cachedLeaf('progress|', () => const LinearProgressIndicator());
    }
    return _bound(node, 'value', (raw) {
      return LinearProgressIndicator(value: _asDouble(raw)?.clamp(0.0, 1.0));
    }, cacheKey: (raw) => 'progress|$raw');
  }

  Widget _icon(PluginNode node) {
    final name = '${node.props['name'] ?? ''}';
    return _cachedLeaf('icon|$name', () {
      final data = PluginIcons.resolve(name);
      if (data == null) return _problem('unknown icon "$name"');
      return Icon(data, size: 17);
    });
  }

  // -------------------------------------------------------- interaction

  Widget _btn(BuildContext context, PluginNode node) {
    final label = l10n.resolve('${node.props['label'] ?? ''}');
    final msg = node.events['tap'];
    return Btn.text(
      text: label,
      onTap: onEvent == null ? null : () => onEvent!(msg, null),
    );
  }

  /// A setting that is on or off, drawn the way the app draws its own.
  ///
  /// The label leads and the control sits at the end, which is what makes a
  /// plugin's settings page read like the pages around it rather than like a
  /// form somebody embedded.
  Widget _toggle(BuildContext context, PluginNode node) {
    final label = l10n.resolve('${node.props['label'] ?? ''}');
    final hint = node.props['hint'];
    final msg = node.events['change'];
    return _bound(node, 'value', (raw) {
      return ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13),
        title: Text(label, style: UIs.text13),
        subtitle: hint == null
            ? null
            : Text(l10n.resolve('$hint'), style: UIs.text12Grey),
        trailing: Switch(
          value: raw == true,
          onChanged: onEvent == null
              ? null
              : (value) => onEvent!(msg, value),
        ),
      );
    }, cacheKey: (raw) => 'toggle|$label|$hint|$raw|$msg');
  }

  Widget _input(PluginNode node) {
    final msg = node.events['change'];
    return _PluginInput(
      initial: '${node.props['value'] ?? ''}',
      hint: node.props['hint'] is String
          ? l10n.resolve(node.props['hint'] as String)
          : null,
      secret: node.props['secret'] == true,
      onChanged: onEvent == null ? null : (value) => onEvent!(msg, value),
    );
  }

  // ------------------------------------------------------------ bigger

  Widget _expand(BuildContext context, PluginNode node) {
    // `title` is a node inside a property, which is the shape PLUGINS.md 5.1
    // records as unresolved: there is no way to say "this child is the header
    // and those are the body". Until the format grows named slots, a title
    // that is not a node falls back to the text it holds.
    final rawTitle = node.props['title'];
    final title = PluginNode.fromJson(rawTitle);
    return ExpandTile(
      title: title == null
          ? Text(l10n.resolve('${rawTitle ?? ''}'))
          : build(context, title),
      children: _children(context, node),
    );
  }

  Widget _table(BuildContext context, PluginNode node) {
    final header = _stringList(node.props['header']);
    final rows = node.props['rows'];
    if (rows is! List) return _problem('table needs rows');
    final style = UIs.text12Grey;
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: [
        if (header.isNotEmpty)
          TableRow(
            children: [
              for (final cell in header)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(l10n.resolve(cell), style: UIs.text12Bold),
                ),
            ],
          ),
        for (final row in rows)
          TableRow(
            children: [
              for (var i = 0; i < header.length; i++)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    l10n.resolve(_cell(row, i)),
                    style: style,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// A row shorter than the header is padded rather than refused: the cost of
  /// a ragged table should be a blank cell.
  String _cell(Object? row, int i) {
    if (row is! List || i >= row.length) return '';
    return '${row[i] ?? ''}';
  }

  Widget _chart(BuildContext context, PluginNode node) {
    // Deliberately not fl_chart yet: a chart is the one widget here with real
    // configuration behind it, and giving a plugin a shape it cannot change
    // later is worse than giving it none. The series are drawn as their
    // latest value so a plugin sending them shows something truthful.
    final series = node.props['series'];
    if (series is! List) return _problem('${node.type} needs series');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in series)
          if (s is Map)
            KvRow(
              k: l10n.resolve('${s['label'] ?? ''}'),
              v: '${_latest(s['values'])}${s['unit'] ?? ''}',
            ),
      ],
    );
  }

  String _latest(Object? values) {
    if (values is! List || values.isEmpty) return '-';
    final last = values.last;
    return last is num ? '${last.toStringAsFixed(1)} ' : '- ';
  }

  /// A long list, built lazily.
  ///
  /// `count` is how many rows there are and `from` the index of the first one
  /// carried, so a page of several hundred builds the dozen on screen rather
  /// than materialising all of them. A row outside the window is a placeholder
  /// until `listWindow` answers — which happens during a scroll, so it cannot
  /// be waited on.
  Widget _list(BuildContext context, PluginNode node) {
    final rows = node.children;
    final from = _num(node, 'from')?.toInt() ?? 0;
    final count = _num(node, 'count')?.toInt() ?? rows.length;
    if (count <= 0) return const SizedBox.shrink();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) {
        final at = index - from;
        // A boundary per row: a list that scrolls repaints rows, and a row
        // that has not changed should not repaint with them.
        return RepaintBoundary(
          child: at >= 0 && at < rows.length
              ? build(context, rows[at])
              : const _RowPlaceholder(),
        );
      },
    );
  }

  // ------------------------------------------------------------- values

  /// Builds a leaf that either holds a value or follows one.
  ///
  /// Following one is a [ValueListenableBuilder] over the surface's notifier:
  /// a refresh that answers `values` and no tree then rebuilds nothing above
  /// this leaf, walks no elements, and marks only its own render object dirty.
  Widget _bound(
    PluginNode node,
    String prop,
    Widget Function(Object? value) build, {
    required String Function(Object? raw) cacheKey,
  }) {
    final raw = node.props[prop];
    final slot = PluginNode.bindingOf(raw);
    if (slot == null) return _cachedLeaf(cacheKey(raw), () => build(raw));
    final notifier = state.slot(slot);
    return ValueListenableBuilder<Object?>(
      valueListenable: notifier,
      builder: (_, value, _) => build(value),
    );
  }

  // -------------------------------------------------------------- utils

  Color? _tone(BuildContext context, PluginNode node) {
    final name = node.props['tone'];
    if (name is! String) return null;
    final scheme = context.theme.colorScheme;
    return switch (name) {
      'muted' => scheme.outline,
      'success' => Colors.green,
      'warning' => Colors.orange,
      'danger' => scheme.error,
      // `normal`, and anything a newer plugin names: the default colour is
      // the readable answer either way.
      _ => null,
    };
  }

  num? _num(PluginNode node, String name) {
    final raw = node.props[name];
    return raw is num ? raw : null;
  }

  static double? _asDouble(Object? raw) => raw is num ? raw.toDouble() : null;

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return [for (final e in raw) '${e ?? ''}'];
  }

  /// What a node the app cannot draw looks like.
  ///
  /// Visible rather than blank, and per node rather than per surface: the
  /// question it has to answer is "which part of this card is missing and
  /// why", and an empty space answers neither.
  Widget _problem(String detail) => _PluginProblem(detail: detail);
}

class _PluginProblem extends StatelessWidget {
  const _PluginProblem({required this.detail});

  final String detail;

  @override
  Widget build(BuildContext context) {
    final color = context.theme.colorScheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          Icon(Icons.error_outline, size: 15, color: color),
          Flexible(
            child: Text(
              detail,
              style: TextStyle(fontSize: 11, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A row a windowed list has not been given yet.
class _RowPlaceholder extends StatelessWidget {
  const _RowPlaceholder();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 37);
}

/// An input that keeps what the user typed.
///
/// Stateful because the tree is rebuilt on every tick and a fresh
/// `TextEditingController` each time would reset the caret — the node's `k` is
/// what keeps *this* element alive across those rebuilds, and this is what
/// makes surviving worth anything.
class _PluginInput extends StatefulWidget {
  const _PluginInput({
    required this.initial,
    this.hint,
    this.secret = false,
    this.onChanged,
  });

  final String initial;
  final String? hint;
  final bool secret;
  final void Function(String value)? onChanged;

  @override
  State<_PluginInput> createState() => _PluginInputState();
}

class _PluginInputState extends State<_PluginInput> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void didUpdateWidget(covariant _PluginInput old) {
    super.didUpdateWidget(old);
    // Only when the plugin actually changed it. Assigning on every rebuild
    // would move the caret to the end while the user is typing in the middle.
    if (widget.initial != old.initial && widget.initial != _controller.text) {
      _controller.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Input(
    controller: _controller,
    hint: widget.hint,
    obscureText: widget.secret,
    onChanged: widget.onChanged,
  );
}
