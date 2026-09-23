import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:server_box/core/utils/plugin/assets.dart';
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
    // And whoever was waiting for one — a pull-to-refresh — is done.
    state.drew();
    return built;
  }
}

class _Builder {
  _Builder(this.state, this.onEvent);

  final PluginSurfaceState state;
  final void Function(Object? msg, Object? value)? onEvent;

  PluginL10n get l10n => state.l10n;

  /// [parent] is the type of the node this one sits in — which three node
  /// types need and cannot ask for: `expanded`, `flexible` and `spacer` are
  /// only legal inside a row or a column, and `positioned` only inside a
  /// stack.
  ///
  /// Flutter throws at layout time for each of those in the wrong place, and
  /// that throw takes the whole surface. A plugin can produce one by writing
  /// `expanded(...)` at the top of a card, so the parent's type is carried down
  /// and they degrade to something harmless instead — the same rule as the rest
  /// of this file: a bad node costs that node.
  Widget build(BuildContext context, PluginNode node, {String? parent}) {
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

    final widget = _keyed(node, _tappable(context, node, _content(context, node, parent)));
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
    if (node.type == 'btn' || node.type == 'tile' || node.type == 'chip') {
      return child;
    }
    final msg = node.events['tap'];
    final long = node.events['long_press'];
    if ((msg == null && long == null) || onEvent == null) return child;

    // Its own `Material`, because a plugin may put a tap on anything and
    // anywhere — an `InkWell` that only works under one particular ancestor
    // fails as a red screen rather than as a compile error.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: msg == null ? null : () => onEvent!(msg, null),
        // The second gesture a list row has, and the one the app itself uses
        // for "what else can I do with this".
        onLongPress: long == null ? null : () => onEvent!(long, null),
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

  Widget _content(BuildContext context, PluginNode node, String? parent) {
    final inFlex = parent == 'row' || parent == 'column';
    return switch (node.type) {
      // ---- layout
      'column' => Column(
        // `min`, so a column is as tall as what is in it. The default is
        // `max`, which fills whatever height it is given — a settings page
        // whose whole content is one switch drew a card down the entire
        // window. A plugin that wants the remaining space says so with
        // `expanded`, and that still works here: a tight flex child takes the
        // free space and the column ends up filling after all.
        //
        // A named alignment overrules that: `main` only means anything with
        // room to distribute, so asking for one is asking to fill.
        mainAxisSize: _main(node) == null ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: _main(node) ?? MainAxisAlignment.start,
        crossAxisAlignment: _cross(node) ?? CrossAxisAlignment.start,
        spacing: _num(node, 'spacing')?.toDouble() ?? 0,
        children: _children(context, node),
      ),
      'row' => Row(
        mainAxisAlignment: _main(node) ?? MainAxisAlignment.start,
        crossAxisAlignment: _cross(node) ?? CrossAxisAlignment.center,
        spacing: _num(node, 'spacing')?.toDouble() ?? 0,
        children: _children(context, node),
      ),
      // Only inside a flex, like `expanded` — and the difference from it is
      // the whole reason both exist: `flexible` takes at most its share,
      // `expanded` takes exactly it.
      'flexible' => inFlex
          ? Flexible(
              flex: _num(node, 'flex')?.toInt() ?? 1,
              child: _onlyChild(context, node),
            )
          : _onlyChild(context, node),
      'align' => Align(
        alignment: _at(node),
        child: _onlyChild(context, node),
      ),
      'wrap' => Wrap(
        spacing: _num(node, 'spacing')?.toDouble() ?? 0,
        runSpacing: _num(node, 'run')?.toDouble() ?? 0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: _children(context, node),
      ),
      // As tall and as wide as its first child, which is what makes a badge on
      // a corner size itself against the thing it marks.
      'stack' => Stack(
        alignment: AlignmentDirectional.topStart,
        children: _children(context, node),
      ),
      'positioned' => parent == 'stack'
          ? Positioned.directional(
              textDirection: Directionality.of(context),
              start: _num(node, 'l')?.toDouble(),
              top: _num(node, 't')?.toDouble(),
              end: _num(node, 'r')?.toDouble(),
              bottom: _num(node, 'b')?.toDouble(),
              width: _num(node, 'width')?.toDouble(),
              height: _num(node, 'height')?.toDouble(),
              child: _onlyChild(context, node),
            )
          : _onlyChild(context, node),
      // Outside a row or a column there is nothing to take the remaining
      // space from, so the child is drawn as it is rather than throwing.
      'expanded' => inFlex
          ? Expanded(child: _onlyChild(context, node))
          : _onlyChild(context, node),
      'padding' => Padding(
        padding: _edges(node),
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
      'refresh' => _refresh(context, node),
      'grid' => _grid(context, node),
      'reorder' => _reorder(context, node),
      'container' => _container(context, node),
      'aspect' => AspectRatio(
        aspectRatio: _num(node, 'ratio')?.toDouble() ?? 1,
        child: _onlyChild(context, node),
      ),
      'constrained' => ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: _num(node, 'minWidth')?.toDouble() ?? 0,
          maxWidth: _num(node, 'maxWidth')?.toDouble() ?? double.infinity,
          minHeight: _num(node, 'minHeight')?.toDouble() ?? 0,
          maxHeight: _num(node, 'maxHeight')?.toDouble() ?? double.infinity,
        ),
        child: _onlyChild(context, node),
      ),
      // Clamped rather than refused: a plugin computing an opacity from a
      // reading can produce 1.4, and Flutter asserts on it.
      'opacity' => Opacity(
        opacity: (_asDouble(node.props['value']) ?? 1).clamp(0.0, 1.0),
        child: _onlyChild(context, node),
      ),
      'clip' => node.props['shape'] == 'oval'
          ? ClipOval(child: _onlyChild(context, node))
          : ClipRRect(
              borderRadius: BorderRadius.circular(
                _num(node, 'radius')?.toDouble() ?? 11,
              ),
              child: _onlyChild(context, node),
            ),
      'rich' => _rich(context, node),
      'image' => _image(context, node),
      'dismiss' => _dismiss(context, node),
      'tabs' => _tabs(context, node),

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
      'checkbox' => _checkbox(context, node),
      'segmented' => _segmented(context, node),
      'dropdown' => _dropdown(context, node),
      'slider' => _slider(context, node),
      'chip' => _chip(context, node),
      'menu' => _menu(context, node),
      'banner' => _banner(context, node),
      'badge' => _badge(context, node),
      'tooltip' => _tooltip(context, node),
      'skeleton' => _skeleton(context, node),
      'pie_chart' => _pie(context, node),
      'table' => _table(context, node),
      'line_chart' || 'bar_chart' => _chart(context, node),
      _ => _problem('unknown widget "${node.type}"'),
    };
  }

  /// Every child, told what they are sitting in.
  List<Widget> _children(BuildContext context, PluginNode node) => [
    for (final child in node.children) build(context, child, parent: node.type),
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

  /// A run of text, with the few knobs a page actually needs.
  ///
  /// **Named sizes and weights, never numbers**, for `tone`'s reason: the app
  /// owns what its text looks like, and a plugin that could name a point size
  /// would be shipping a page that does not scale with the rest of the app.
  /// What a plugin gets to say is what the text *is* — a heading, a reading, a
  /// note under one — and `mono` for the one case a face is the meaning: a
  /// command, a path, a hash, where a proportional font makes two things that
  /// differ look alike.
  Widget _text(BuildContext context, PluginNode node) {
    final tone = _tone(context, node);
    final style = _textStyle(node, tone);
    final max = _num(node, 'max')?.toInt();
    final align = switch (node.props['align']) {
      'center' => TextAlign.center,
      'end' => TextAlign.end,
      'start' => TextAlign.start,
      _ => null,
    };
    // Selectable is a different widget, not a property: `SelectableText` has
    // its own gesture handling, so a plugin asking for one gets one.
    final selectable = node.props['select'] == true;
    return _bound(node, 'value', (raw) {
      final value = l10n.resolve('${raw ?? ''}');
      if (selectable) {
        return SelectableText(value, style: style, textAlign: align, maxLines: max);
      }
      return Text(
        value,
        style: style,
        textAlign: align,
        maxLines: max,
        overflow: max == null ? null : TextOverflow.ellipsis,
      );
    }, cacheKey: (raw) => 'text|$raw|${tone?.toARGB32()}|'
        '${node.props['size']}|${node.props['weight']}|${node.props['mono']}|'
        '${node.props['align']}|$max|$selectable');
  }

  /// The named text scale, mapped to what the app uses elsewhere.
  TextStyle _textStyle(PluginNode node, Color? tone) {
    final size = switch (node.props['size']) {
      'xs' => 11.0,
      'sm' => 12.0,
      'lg' => 15.0,
      // The figure in a `summary`, so a plugin building its own heading lands
      // on the same size as the one the app draws.
      'xl' => 22.0,
      _ => 13.0,
    };
    final weight = switch (node.props['weight']) {
      'medium' => FontWeight.w500,
      'bold' => FontWeight.w600,
      _ => null,
    };
    return TextStyle(
      color: tone,
      fontSize: size,
      fontWeight: weight,
      // The same family the app's own crash report and log views use.
      fontFamily: node.props['mono'] == true ? 'monospace' : null,
    );
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
    final longPress = node.events['long_press'];
    // `ListTile`'s own selected state, which is what the app's own lists use
    // (`pkg/tab.dart`) — so a plugin's chosen row is tinted the same way the
    // app tints one, rather than each plugin inventing a mark. A selection a
    // plugin could only express by swapping one grey icon for another is a
    // selection nobody sees.
    final selected = node.props['selected'] == true;
    return _bound(node, 'title', (raw) {
      return ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13),
        selected: selected,
        onTap: msg == null || onEvent == null
            ? null
            : () => onEvent!(msg, null),
        onLongPress: longPress == null || onEvent == null
            ? null
            : () => onEvent!(longPress, null),
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
    }, cacheKey: (raw) =>
        'tile|$raw|$subtitle|${node.props['icon']}|$msg|$longPress|$selected');
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

  /// A button, in one of the two weights the app itself uses.
  ///
  /// `text` is the default and what most things should be; `filled` is for the
  /// one action a page is *for*. There is no outline or tonal variant on
  /// purpose — three weights is a decision every plugin author would have to
  /// make on every button, and the app does not use them either.
  ///
  /// `busy` replaces the label with a spinner **and** drops the callback, so a
  /// plugin that shows one cannot also be tapped again meanwhile.
  Widget _btn(BuildContext context, PluginNode node) {
    final label = l10n.resolve('${node.props['label'] ?? ''}');
    final msg = node.events['tap'];
    final busy = node.props['busy'] == true;
    final tone = _tone(context, node);
    final icon = PluginIcons.resolve('${node.props['icon'] ?? ''}');
    final onTap = onEvent == null || busy
        ? null
        : () => onEvent!(msg, null);

    final child = busy
        ? const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 5,
            children: [
              if (icon != null) Icon(icon, size: 17),
              Text(label, style: TextStyle(color: tone)),
            ],
          );

    if (node.props['variant'] == 'filled') {
      return FilledButton(onPressed: onTap, child: child);
    }
    return TextButton(onPressed: onTap, child: child);
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

  /// On or off, drawn as the app draws one — the label leads, the box sits at
  /// the end. The sibling of [_toggle]: a switch is a setting that takes effect
  /// as you touch it, a checkbox is one of several things being chosen.
  Widget _checkbox(BuildContext context, PluginNode node) {
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
        trailing: Checkbox(
          value: raw == true,
          onChanged: onEvent == null ? null : (value) => onEvent!(msg, value),
        ),
      );
    }, cacheKey: (raw) => 'checkbox|$label|$hint|$raw|$msg');
  }

  /// One of a few, all of them visible.
  ///
  /// Material's answer for a small exclusive choice, which is why there is no
  /// `radio` node: a column of radio buttons costs a row each and says the same
  /// thing. Past five options it stops fitting, and that is what [_dropdown]
  /// is for.
  Widget _segmented(BuildContext context, PluginNode node) {
    final options = _options(node);
    if (options.isEmpty) return _problem('segmented with no options');
    final msg = node.events['change'];
    return _bound(node, 'value', (raw) {
      final value = '${raw ?? ''}';
      return SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [
          for (final o in options)
            ButtonSegment(value: o.value, label: Text(o.label)),
        ],
        // A value none of the options carries would throw, so an unknown one
        // selects nothing rather than taking the surface down.
        selected: options.any((o) => o.value == value) ? {value} : const {},
        emptySelectionAllowed: true,
        onSelectionChanged: onEvent == null
            ? null
            : (set) => onEvent!(msg, set.firstOrNull),
      );
    }, cacheKey: (raw) => 'segmented|$raw|$msg|${options.map((o) => o.value).join(',')}');
  }

  /// One of many, in a menu — the same shape as [_toggle], so a settings page
  /// made of both reads as one page.
  Widget _dropdown(BuildContext context, PluginNode node) {
    final options = _options(node);
    final label = node.props['label'];
    final msg = node.events['change'];
    return _bound(node, 'value', (raw) {
      final value = '${raw ?? ''}';
      final menu = DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.any((o) => o.value == value) ? value : null,
          hint: node.props['hint'] is String
              ? Text(l10n.resolve(node.props['hint'] as String), style: UIs.text13)
              : null,
          isDense: true,
          items: [
            for (final o in options)
              DropdownMenuItem(
                value: o.value,
                child: Text(o.label, style: UIs.text13),
              ),
          ],
          onChanged: onEvent == null ? null : (v) => onEvent!(msg, v),
        ),
      );
      if (label == null) return menu;
      return ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13),
        title: Text(l10n.resolve('$label'), style: UIs.text13),
        trailing: menu,
      );
    }, cacheKey: (raw) =>
        'dropdown|$raw|$label|$msg|${options.map((o) => o.value).join(',')}');
  }

  /// A number in a range, where the range is the point.
  ///
  /// The value is shown beside the label rather than in a tooltip only: a
  /// slider whose current number is invisible until you touch it cannot be read
  /// at a glance, which is the one thing a settings page is for.
  Widget _slider(BuildContext context, PluginNode node) {
    final label = node.props['label'];
    final min = _num(node, 'min')?.toDouble() ?? 0;
    final max = _num(node, 'max')?.toDouble() ?? 1;
    final divisions = _num(node, 'divisions')?.toInt();
    final msg = node.events['change'];
    return _bound(node, 'value', (raw) {
      final value = (_asDouble(raw) ?? min).clamp(min, max);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.resolve('$label'), style: UIs.text13),
                  Text(_sliderValue(value, divisions), style: UIs.text12Grey),
                ],
              ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onEvent == null ? null : (v) => onEvent!(msg, v),
            ),
          ],
        ),
      );
    }, cacheKey: (raw) => 'slider|$raw|$label|$min|$max|$divisions|$msg');
  }

  /// Whole where the steps are whole, so a slider over 1..10 does not read
  /// `7.000000001`.
  static String _sliderValue(double value, int? divisions) =>
      divisions == null || value != value.roundToDouble()
          ? value.toStringAsFixed(2)
          : value.toInt().toString();

  /// A chip, which in Material is a *choice*: put a row of them in a `wrap`
  /// and it is a filter bar.
  Widget _chip(BuildContext context, PluginNode node) {
    final msg = node.events['tap'];
    final icon = PluginIcons.resolve('${node.props['icon'] ?? ''}');
    return _bound(node, 'label', (raw) {
      return FilterChip(
        label: Text(l10n.resolve('${raw ?? ''}'), style: UIs.text13),
        avatar: icon == null ? null : Icon(icon, size: 15),
        selected: node.props['selected'] == true,
        onSelected: onEvent == null ? null : (_) => onEvent!(msg, null),
      );
    }, cacheKey: (raw) =>
        'chip|$raw|${node.props['selected']}|${node.props['icon']}|$msg');
  }

  /// The actions that do not fit on a row, behind one button.
  ///
  /// A plugin with five things to do to a row has nowhere to put them — a row
  /// of five buttons is not a row, it is a toolbar per line. Each item carries
  /// its own message, so the plugin reads one event rather than an index.
  Widget _menu(BuildContext context, PluginNode node) {
    final items = _options(node);
    if (items.isEmpty) return _problem('menu with no items');
    final icon = PluginIcons.resolve('${node.props['icon'] ?? ''}');
    return PopupMenuButton<int>(
      icon: Icon(icon ?? Icons.more_vert, size: 19),
      tooltip: '',
      itemBuilder: (_) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem(
            value: i,
            height: 40,
            child: Row(
              spacing: 9,
              children: [
                if (PluginIcons.resolve(items[i].icon) case final data?)
                  Icon(data, size: 17),
                Text(items[i].label, style: UIs.text13),
              ],
            ),
          ),
      ],
      onSelected: onEvent == null
          ? null
          : (i) => onEvent!(items[i].msg ?? items[i].value, null),
    );
  }

  /// Pull to refresh, around whatever scrolls.
  ///
  /// The spinner stays until the plugin's **next tree**, which is the honest
  /// answer to "is it done": a future completed straight away would flash, and
  /// the plugin's work happens in another isolate over a network. Capped, so a
  /// plugin that answers with nothing does not leave a spinner turning forever.
  Widget _refresh(BuildContext context, PluginNode node) {
    final msg = node.events['refresh'];
    final child = _onlyChild(context, node);
    if (msg == null || onEvent == null) return child;
    return RefreshIndicator(
      onRefresh: () {
        onEvent!(msg, null);
        return state.nextTree();
      },
      child: child,
    );
  }

  /// A row that answers a swipe.
  ///
  /// **The row is never removed here.** Flutter's `Dismissible` expects the
  /// list to lose the row, and a tree that still carries it throws — but the
  /// tree belongs to the plugin and arrives later, over a network. So the swipe
  /// is refused and the message is sent: the row springs back, and the
  /// plugin's next tree is what makes it disappear.
  Widget _dismiss(BuildContext context, PluginNode node) {
    final msg = node.events['dismiss'];
    final child = _onlyChild(context, node);
    if (msg == null || onEvent == null || node.key == null) return child;
    return Dismissible(
      key: ValueKey('dismiss:${node.key}'),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: context.theme.colorScheme.errorContainer,
        child: const Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 17),
            child: Icon(Icons.delete_outline, size: 19),
          ),
        ),
      ),
      confirmDismiss: (_) async {
        onEvent!(msg, null);
        return false;
      },
      child: child,
    );
  }

  /// Sections of one surface, with the app's own tab bar.
  ///
  /// **The index is the app's**, not the plugin's: switching a tab is a frame,
  /// where a round trip to a JavaScript instance would be a visible pause on
  /// something that should feel like part of the app. The plugin is told, so it
  /// can load what a tab needs, but it is not asked first.
  Widget _tabs(BuildContext context, PluginNode node) {
    final labels = _stringList(node.props['labels']);
    final views = _children(context, node);
    if (labels.isEmpty || views.isEmpty) return _problem('tabs with no views');
    return _PluginTabs(
      labels: [for (final label in labels) l10n.resolve(label)],
      views: views,
      onChanged: onEvent == null || node.events['change'] == null
          ? null
          : (i) => onEvent!(node.events['change'], i),
    );
  }

  /// Something the page has to say about itself: a warning, an error, a note.
  ///
  /// A block rather than a toast, because it is a *state* — the connection has
  /// no `cron`, the directory could not be read — and a toast is gone in three
  /// seconds. Every plugin needs one, and hand-built out of a row and an icon
  /// each of them looked different.
  Widget _banner(BuildContext context, PluginNode node) {
    final tone = _tone(context, node) ?? context.theme.colorScheme.primary;
    final icon = PluginIcons.resolve('${node.props['icon'] ?? ''}');
    final action = node.children.isEmpty
        ? null
        : build(context, node.children.first);
    return _bound(node, 'text', (raw) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          spacing: 9,
          children: [
            Icon(icon ?? Icons.info_outline, size: 17, color: tone),
            Expanded(
              child: Text(
                l10n.resolve('${raw ?? ''}'),
                style: TextStyle(fontSize: 12, color: tone),
              ),
            ),
            ?action,
          ],
        ),
      );
    }, cacheKey: (raw) => 'banner|$raw|${tone.toARGB32()}|${node.props['icon']}');
  }

  /// A count or a dot on the corner of something.
  Widget _badge(BuildContext context, PluginNode node) {
    final label = node.props['label'];
    return Badge(
      label: label == null ? null : Text(l10n.resolve('$label')),
      isLabelVisible: label != null || node.props['dot'] == true,
      backgroundColor: _tone(context, node),
      child: _onlyChild(context, node),
    );
  }

  /// What a control is for, in words, for the ones an icon cannot say.
  Widget _tooltip(BuildContext context, PluginNode node) => Tooltip(
    message: l10n.resolve('${node.props['message'] ?? ''}'),
    // Long press on a touch screen, where there is no pointer to hover.
    triggerMode: TooltipTriggerMode.longPress,
    child: _onlyChild(context, node),
  );

  /// The shape of what is coming, while it is being fetched.
  ///
  /// A page that shows a spinner in the middle and then jumps to a full list
  /// moves everything the eye had settled on. Bars in the shape of the rows
  /// keep the layout still, which is what Material's own loading guidance
  /// asks for.
  Widget _skeleton(BuildContext context, PluginNode node) {
    final rows = _num(node, 'rows')?.toInt() ?? 3;
    final color = context.theme.hintColor.withValues(alpha: 0.12);
    return _cachedLeaf('skeleton|$rows|${color.toARGB32()}', () {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.clamp(1, 20); i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 5,
                children: [
                  _bar(color, 0.45, 11),
                  _bar(color, 0.8, 9),
                ],
              ),
            ),
        ],
      );
    });
  }

  static Widget _bar(Color color, double widthFactor, double height) =>
      FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );

  /// Parts of one whole, which is the question a bar chart cannot answer.
  ///
  /// Slices are `{label, value}` and the values are taken as given: what a
  /// share is *of* is the plugin's business, and normalising here would draw a
  /// full circle for a disk that is half empty.
  Widget _pie(BuildContext context, PluginNode node) {
    final raw = node.props['slices'];
    if (raw is! List || raw.isEmpty) return _problem('pie_chart with no slices');
    final slices = <({String label, double value})>[];
    for (final one in raw) {
      if (one is! Map) continue;
      final value = _asDouble(one['value']);
      if (value == null || value <= 0) continue;
      slices.add((label: l10n.resolve('${one['label'] ?? ''}'), value: value));
    }
    if (slices.isEmpty) return _problem('pie_chart with no slices');

    final palette = _palette(context);
    return SizedBox(
      height: 137,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 27,
                sections: [
                  for (var i = 0; i < slices.length; i++)
                    PieChartSectionData(
                      value: slices[i].value,
                      color: palette[i % palette.length],
                      radius: 27,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 5,
              children: [
                for (var i = 0; i < slices.length && i < 6; i++)
                  Row(
                    spacing: 7,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: palette[i % palette.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          slices[i].label,
                          style: UIs.text12Grey,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A box with a background, a border and a corner — the one primitive a
  /// plugin cannot build out of anything else.
  ///
  /// **Colours are still names.** `bg` and the border take a [Tone] or `card`,
  /// and what those look like is the theme's; a radius and a width are shapes
  /// and are numbers. A plugin that could name a colour would ship something
  /// unreadable in the other brightness, which is the whole of why `tone`
  /// exists.
  Widget _container(BuildContext context, PluginNode node) {
    final bg = _surfaceColor(context, node.props['bg']);
    final borderTone = _surfaceColor(context, node.props['border'], solid: true);
    final radius = _num(node, 'radius')?.toDouble();
    return Container(
      padding: _hasEdges(node) ? _edges(node) : null,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius == null ? null : BorderRadius.circular(radius),
        border: borderTone == null
            ? null
            : Border.all(
                color: borderTone,
                width: _num(node, 'borderWidth')?.toDouble() ?? 1,
              ),
      ),
      child: _onlyChild(context, node),
    );
  }

  bool _hasEdges(PluginNode node) =>
      node.props.containsKey('all') ||
      node.props.containsKey('l') ||
      node.props.containsKey('t') ||
      node.props.containsKey('r') ||
      node.props.containsKey('b');

  /// A named surface or tone as a colour.
  ///
  /// A tone as a *background* is drawn faint, the way a `tag` and a `banner`
  /// draw theirs: a plugin asking for "danger" wants a danger-coloured block,
  /// not a solid red rectangle with unreadable text on it. [solid] is for a
  /// border, where the line is the point.
  Color? _surfaceColor(BuildContext context, Object? name, {bool solid = false}) {
    if (name is! String) return null;
    final scheme = context.theme.colorScheme;
    final color = switch (name) {
      'card' => scheme.surfaceContainer,
      'surface' => scheme.surface,
      'muted' => scheme.outline,
      'success' => Colors.green,
      'warning' => Colors.orange,
      'danger' => scheme.error,
      'normal' => scheme.primary,
      _ => null,
    };
    if (color == null) return null;
    if (solid || name == 'card' || name == 'surface') return color;
    return color.withValues(alpha: 0.12);
  }

  /// A paragraph with more than one style in it, and links inside it.
  ///
  /// Children are `span` nodes carrying the same named knobs as `text`. A
  /// span with a `tap` is a link — which is why this is a node and not a
  /// convention: a tappable *word* cannot be expressed by a row of texts, and
  /// a row of texts does not wrap as a sentence either.
  Widget _rich(BuildContext context, PluginNode node) {
    final spans = <({String text, TextStyle style, Object? tap})>[];
    for (final child in node.children) {
      if (child.type != 'span') continue;
      final tone = _tone(context, child);
      spans.add((
        text: l10n.resolve('${child.props['value'] ?? ''}'),
        style: _textStyle(child, tone ?? (child.events['tap'] != null
            ? context.theme.colorScheme.primary
            : null)),
        tap: child.events['tap'],
      ));
    }
    if (spans.isEmpty) return _problem('rich with no spans');
    return _PluginRichText(
      spans: spans,
      onTap: onEvent == null ? null : (msg) => onEvent!(msg, null),
    );
  }

  /// A file the plugin shipped in its package.
  ///
  /// **Only that.** No URL: an image fetched at draw time is a request to
  /// somewhere on every frame a card is on screen, which is a tracking pixel
  /// with extra steps and would need `net.http` to be honest about it. The
  /// name is resolved under the plugin's own `assets/`, and anything trying to
  /// leave that directory draws the problem node instead.
  Widget _image(BuildContext context, PluginNode node) {
    final dir = state.assetDir;
    final name = '${node.props['asset'] ?? ''}';
    final path = PluginAssets.pathOf(dir, name);
    if (path == null) return _problem('no such asset "$name"');
    final width = _num(node, 'width')?.toDouble();
    final height = _num(node, 'height')?.toDouble();
    final fit = switch (node.props['fit']) {
      'fill' => BoxFit.fill,
      'cover' => BoxFit.cover,
      'none' => BoxFit.none,
      _ => BoxFit.contain,
    };
    return _cachedLeaf('image|$path|$width|$height|$fit', () {
      if (name.toLowerCase().endsWith('.svg')) {
        return SvgPicture.file(
          File(path),
          width: width,
          height: height,
          fit: fit,
        );
      }
      return Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        // A file that is not an image, or one the install truncated: a gap
        // rather than a red box over the whole surface.
        errorBuilder: (_, _, _) => _problem('cannot read "$name"'),
      );
    });
  }

  /// A list the user can put in order.
  ///
  /// **The move is applied here first.** `ReorderableListView` hands back an
  /// index pair and expects the list to have moved by the next frame, and the
  /// plugin's tree arrives later — so the app holds the move until a new tree
  /// replaces it. Without that the row springs back under the finger and the
  /// list looks broken while it is in fact working.
  Widget _reorder(BuildContext context, PluginNode node) {
    final msg = node.events['reorder'];
    final rows = node.children;
    if (msg == null || onEvent == null || rows.isEmpty) {
      return Column(children: _children(context, node));
    }
    return _PluginReorder(
      // The tree itself, so a new one from the plugin drops the local move.
      signature: [for (final row in rows) row.key ?? row.rev ?? ''].join('|'),
      rows: [for (final row in rows) build(context, row, parent: node.type)],
      onReorder: (from, to) => onEvent!(msg, {'from': from, 'to': to}),
    );
  }

  /// The theme's own colours, cycled.
  ///
  /// A plugin naming a colour is the thing `tone` exists to prevent, and a
  /// chart is where it would be most tempting — so the series are numbered and
  /// the app decides what number three looks like.
  static List<Color> _palette(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return [
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.error,
      scheme.primaryContainer,
      scheme.tertiaryContainer,
    ];
  }

  /// A grid of the same thing, where a list would waste a wide window.
  Widget _grid(BuildContext context, PluginNode node) {
    final columns = (_num(node, 'columns')?.toInt() ?? 2).clamp(1, 6);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: columns,
      childAspectRatio: _num(node, 'ratio')?.toDouble() ?? 1.6,
      mainAxisSpacing: _num(node, 'spacing')?.toDouble() ?? 7,
      crossAxisSpacing: _num(node, 'spacing')?.toDouble() ?? 7,
      children: _children(context, node),
    );
  }

  /// The `options` a choice offers: `{value, label, icon?, msg?}` each.
  ///
  /// A label that is missing falls back to the value, which is a machine name
  /// — readable, and better than a blank row in a menu.
  List<({String value, String label, String? icon, Object? msg})> _options(
    PluginNode node,
  ) {
    final raw = node.props['options'];
    if (raw is! List) return const [];
    return [
      for (final one in raw)
        if (one is Map)
          (
            value: '${one['value'] ?? ''}',
            label: l10n.resolve('${one['label'] ?? one['value'] ?? ''}'),
            icon: one['icon'] is String ? one['icon'] as String : null,
            msg: one['msg'],
          ),
    ];
  }

  Widget _input(PluginNode node) {
    final msg = node.events['change'];
    final submit = node.events['submit'];
    return _PluginInput(
      initial: '${node.props['value'] ?? ''}',
      hint: node.props['hint'] is String
          ? l10n.resolve(node.props['hint'] as String)
          : null,
      secret: node.props['secret'] == true,
      icon: PluginIcons.resolve('${node.props['icon'] ?? ''}'),
      // `lines` is the box's height and `multiline` is what the keyboard's
      // return key does — a phone's, where the two are separate questions.
      lines: _num(node, 'lines')?.toInt(),
      keyboard: switch (node.props['keyboard']) {
        'number' => TextInputType.number,
        'url' => TextInputType.url,
        'email' => TextInputType.emailAddress,
        'multiline' => TextInputType.multiline,
        _ => null,
      },
      onChanged: onEvent == null ? null : (value) => onEvent!(msg, value),
      onSubmitted: onEvent == null || submit == null
          ? null
          : (value) => onEvent!(submit, value),
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

  /// A line or a set of bars, drawn the way the app draws its own history.
  ///
  /// **The node shape is v1's and has not moved**: `series` of `{label, values,
  /// unit}`. What moved is that it is a chart now — it used to be a column of
  /// `label: latest value` rows, on the reasoning that a chart has real
  /// configuration behind it and a shape a plugin cannot change later is worse
  /// than none. That reasoning was about the *shape*, and drawing what the
  /// shape already declares needs no new field.
  ///
  /// No x axis: a plugin's values are a series with no labels for it, and an
  /// axis of indices says nothing. The legend is what names the lines, and the
  /// tooltip is what reads one off.
  Widget _chart(BuildContext context, PluginNode node) {
    final raw = node.props['series'];
    if (raw is! List) return _problem('${node.type} needs series');
    final series = <({String label, List<double> values, String unit})>[];
    for (final one in raw) {
      if (one is! Map) continue;
      final values = [
        for (final v in (one['values'] is List ? one['values'] as List : []))
          ?_asDouble(v),
      ];
      if (values.isEmpty) continue;
      series.add((
        label: l10n.resolve('${one['label'] ?? ''}'),
        values: values,
        unit: '${one['unit'] ?? ''}',
      ));
    }
    // fl_chart throws a `LateInitializationError` on a bar with no spots, so
    // an empty set is a placeholder rather than a crash — which is the same
    // guard the app's own history chart carries.
    if (series.isEmpty) return _problem('${node.type} has no values');

    final palette = _palette(context);
    final peak = series
        .expand((s) => s.values)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final unit = series.first.unit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 7,
      children: [
        SizedBox(
          height: _num(node, 'height')?.toDouble() ?? 137,
          child: node.type == 'bar_chart'
              ? _bars(context, series, palette, peak, unit)
              : _lines(context, series, palette, peak, unit),
        ),
        if (series.length > 1)
          Wrap(
            spacing: 13,
            runSpacing: 5,
            children: [
              for (var i = 0; i < series.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 5,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: palette[i % palette.length],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(series[i].label, style: UIs.text12Grey),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  Widget _lines(
    BuildContext context,
    List<({String label, List<double> values, String unit})> series,
    List<Color> palette,
    double peak,
    String unit,
  ) => LineChart(
    LineChartData(
      minY: 0,
      maxY: peak <= 0 ? 1 : peak * 1.1,
      gridData: _chartGrid(context),
      titlesData: _axis(unit, peak),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => [
            for (final spot in spots)
              LineTooltipItem(
                '${spot.barIndex < series.length ? series[spot.barIndex].label : ''} '
                '${_trim(spot.y)}$unit',
                const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
      lineBarsData: [
        for (var i = 0; i < series.length; i++)
          LineChartBarData(
            spots: [
              for (var x = 0; x < series[i].values.length; x++)
                FlSpot(x.toDouble(), series[i].values[x]),
            ],
            color: palette[i % palette.length],
            barWidth: 2,
            isCurved: false,
            dotData: const FlDotData(show: false),
          ),
      ],
    ),
  );

  /// Grouped by index, so three machines' readings for the same thing stand
  /// beside each other rather than in three charts.
  Widget _bars(
    BuildContext context,
    List<({String label, List<double> values, String unit})> series,
    List<Color> palette,
    double peak,
    String unit,
  ) {
    final length = series
        .map((s) => s.values.length)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        maxY: peak <= 0 ? 1 : peak * 1.1,
        gridData: _chartGrid(context),
        titlesData: _axis(unit, peak),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, i) => BarTooltipItem(
              '${i < series.length ? series[i].label : ''} ${_trim(rod.toY)}$unit',
              const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        barGroups: [
          for (var x = 0; x < length; x++)
            BarChartGroupData(
              x: x,
              barRods: [
                for (var i = 0; i < series.length; i++)
                  BarChartRodData(
                    toY: x < series[i].values.length ? series[i].values[x] : 0,
                    color: palette[i % palette.length],
                    width: 7,
                    borderRadius: BorderRadius.circular(2),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  FlGridData _chartGrid(BuildContext context) => FlGridData(
    drawVerticalLine: false,
    getDrawingHorizontalLine: (_) =>
        FlLine(color: context.theme.hintColor.withValues(alpha: 0.17), strokeWidth: 1),
  );

  /// The left axis and nothing else. A plugin's x is a series of readings with
  /// no labels for them, and an axis of indices is noise.
  FlTitlesData _axis(String unit, double peak) => FlTitlesData(
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 41,
        // Without an explicit interval fl_chart draws a label per pixel step
        // and they smear into each other — the app's own chart says the same.
        interval: peak <= 0 ? 1 : peak / 2,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: Text('${_trim(value)}$unit', style: UIs.text12Grey, maxLines: 1),
        ),
      ),
    ),
  );

  /// `42` rather than `42.0`, and two places for anything else.
  static String _trim(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

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
    if (slot == null) {
      // **A node with children is not a leaf.** `summary` builds its actions
      // and `tile` its trailing out of `c`, closes over them, and neither is
      // in the signature — so the cache answered "you have this already" for a
      // row whose buttons had changed. That is what a dead control looks like:
      // tapping the plugin's "select" sent the message, the plugin answered
      // with a bar of two different buttons, and the screen kept the first
      // one. Nothing to see in a log, and the widget was correct — for the
      // tree before it.
      //
      // Covering the children in the key instead would mean stringifying a
      // subtree on every build to save one; the revision mechanism above is
      // the fast path for anything larger than a leaf.
      if (node.children.isNotEmpty) return build(raw);
      return _cachedLeaf(cacheKey(raw), () => build(raw));
    }
    final notifier = state.slot(slot);
    return ValueListenableBuilder<Object?>(
      valueListenable: notifier,
      builder: (_, value, _) => build(value),
    );
  }

  // -------------------------------------------------------------- utils

  /// The named alignments. A name rather than a number, like `tone`: what a
  /// plugin says is *what it wants*, and the app decides what that looks like.
  ///
  /// Null for absent or unknown, so a newer plugin naming one this build has
  /// never heard of gets the default rather than a broken row.
  MainAxisAlignment? _main(PluginNode node) => switch (node.props['main']) {
    'start' => MainAxisAlignment.start,
    'center' => MainAxisAlignment.center,
    'end' => MainAxisAlignment.end,
    'between' => MainAxisAlignment.spaceBetween,
    'around' => MainAxisAlignment.spaceAround,
    'evenly' => MainAxisAlignment.spaceEvenly,
    _ => null,
  };

  CrossAxisAlignment? _cross(PluginNode node) => switch (node.props['cross']) {
    'start' => CrossAxisAlignment.start,
    'center' => CrossAxisAlignment.center,
    'end' => CrossAxisAlignment.end,
    'stretch' => CrossAxisAlignment.stretch,
    _ => null,
  };

  /// **Directional**, so a plugin that puts something "at the start" has it on
  /// the right in an Arabic locale without knowing that locales differ.
  AlignmentGeometry _at(PluginNode node) => switch (node.props['at']) {
    'topStart' => AlignmentDirectional.topStart,
    'top' => AlignmentDirectional.topCenter,
    'topEnd' => AlignmentDirectional.topEnd,
    'start' => AlignmentDirectional.centerStart,
    'end' => AlignmentDirectional.centerEnd,
    'bottomStart' => AlignmentDirectional.bottomStart,
    'bottom' => AlignmentDirectional.bottomCenter,
    'bottomEnd' => AlignmentDirectional.bottomEnd,
    _ => AlignmentDirectional.center,
  };

  /// `all`, or any of the four sides. Both may be given; a side wins over
  /// `all`, which is how `padding(all: 13, {b: 0})` reads.
  EdgeInsetsGeometry _edges(PluginNode node) {
    final all = _num(node, 'all')?.toDouble() ?? 0;
    return EdgeInsetsDirectional.only(
      start: _num(node, 'l')?.toDouble() ?? all,
      top: _num(node, 't')?.toDouble() ?? all,
      end: _num(node, 'r')?.toDouble() ?? all,
      bottom: _num(node, 'b')?.toDouble() ?? all,
    );
  }

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
/// Sections of one surface, with the app's own tab bar.
///
/// The index lives here rather than in the plugin, so switching is a frame.
/// Kept across rebuilds by the element the tree's key gives this widget — a
/// tick that redraws the page does not send the user back to the first tab.
class _PluginTabs extends StatefulWidget {
  const _PluginTabs({
    required this.labels,
    required this.views,
    this.onChanged,
  });

  final List<String> labels;
  final List<Widget> views;
  final void Function(int index)? onChanged;

  @override
  State<_PluginTabs> createState() => _PluginTabsState();
}

class _PluginTabsState extends State<_PluginTabs>
    with SingleTickerProviderStateMixin {
  late TabController _controller = _makeController();

  TabController _makeController() {
    final controller = TabController(length: _count, vsync: this);
    controller.addListener(() {
      if (controller.indexIsChanging) return;
      widget.onChanged?.call(controller.index);
    });
    return controller;
  }

  int get _count => widget.labels.length < widget.views.length
      ? widget.labels.length
      : widget.views.length;

  @override
  void didUpdateWidget(covariant _PluginTabs old) {
    super.didUpdateWidget(old);
    // A plugin that added or removed a section needs a controller of the new
    // length — reusing one throws. The index is kept where it still exists,
    // since the alternative is being thrown back to the first tab whenever a
    // plugin's sections move.
    if (_count == _controller.length) return;
    final at = _controller.index;
    _controller.dispose();
    _controller = _makeController();
    if (at < _count) _controller.index = at;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final views = TabBarView(
      controller: _controller,
      children: widget.views.take(_count).toList(),
    );
    // **A `TabBarView` needs a height and a plugin can put this anywhere.**
    // Inside a page there is one to take; inside a card or a `scroll` there is
    // not, and `Expanded` against an unbounded height throws at layout time and
    // takes the surface with it. So the height is measured: taken where there
    // is one, and given a screenful where there is not — the same rule as
    // `expanded` outside a flex.
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            controller: _controller,
            isScrollable: _count > 3,
            tabAlignment: _count > 3 ? TabAlignment.start : null,
            tabs: [
              for (var i = 0; i < _count; i++)
                Tab(height: 37, child: Text(widget.labels[i], style: UIs.text13)),
            ],
          ),
          if (constraints.maxHeight.isFinite)
            Expanded(child: views)
          else
            SizedBox(height: 320, child: views),
        ],
      ),
    );
  }
}

/// A paragraph with several styles in it, and links inside it.
///
/// Stateful because a tappable span needs a `TapGestureRecognizer`, and a
/// recognizer is a listener that has to be disposed — built inline it would
/// leak one per span per frame.
class _PluginRichText extends StatefulWidget {
  const _PluginRichText({required this.spans, this.onTap});

  final List<({String text, TextStyle style, Object? tap})> spans;
  final void Function(Object? msg)? onTap;

  @override
  State<_PluginRichText> createState() => _PluginRichTextState();
}

class _PluginRichTextState extends State<_PluginRichText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    return Text.rich(
      TextSpan(
        children: [
          for (final span in widget.spans)
            TextSpan(
              text: span.text,
              style: span.style,
              recognizer: span.tap == null || widget.onTap == null
                  ? null
                  : (_recognizers..add(
                      TapGestureRecognizer()
                        ..onTap = () => widget.onTap!(span.tap),
                    )).last,
            ),
        ],
      ),
    );
  }
}

/// A list the user can put in order, holding the move until the plugin's tree
/// catches up. See `_Builder._reorder`.
class _PluginReorder extends StatefulWidget {
  const _PluginReorder({
    required this.signature,
    required this.rows,
    required this.onReorder,
  });

  /// What the plugin sent. A new one drops whatever move is being held.
  final String signature;
  final List<Widget> rows;
  final void Function(int from, int to) onReorder;

  @override
  State<_PluginReorder> createState() => _PluginReorderState();
}

class _PluginReorderState extends State<_PluginReorder> {
  /// The order being shown, as indices into `widget.rows`. Empty is "as given".
  List<int> _order = const [];

  @override
  void didUpdateWidget(covariant _PluginReorder old) {
    super.didUpdateWidget(old);
    // The plugin answered, so what it says is the order now. Kept otherwise:
    // a tick that redraws the same list must not undo a move the user made a
    // moment ago and the plugin has not answered yet.
    if (widget.signature != old.signature) _order = const [];
  }

  @override
  Widget build(BuildContext context) {
    final order = _order.length == widget.rows.length
        ? _order
        : [for (var i = 0; i < widget.rows.length; i++) i];
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: true,
      itemCount: order.length,
      itemBuilder: (_, i) => KeyedSubtree(
        key: ValueKey('reorder:${order[i]}'),
        child: widget.rows[order[i]],
      ),
      // `onReorderItem` rather than `onReorder`: the older callback hands back
      // an index that still counts the row being moved, and every caller had
      // to subtract one — which is exactly the off-by-one this replaces.
      onReorderItem: (from, to) {
        setState(() {
          final next = [...order];
          next.insert(to, next.removeAt(from));
          _order = next;
        });
        widget.onReorder(from, to);
      },
    );
  }
}

class _PluginInput extends StatefulWidget {
  const _PluginInput({
    required this.initial,
    this.hint,
    this.secret = false,
    this.icon,
    this.lines,
    this.keyboard,
    this.onChanged,
    this.onSubmitted,
  });

  final String initial;
  final String? hint;
  final bool secret;
  final IconData? icon;

  /// How tall the box is. More than one makes it grow with what is typed
  /// rather than scroll a single line, which is what a command or a note needs.
  final int? lines;

  final TextInputType? keyboard;
  final void Function(String value)? onChanged;
  final void Function(String value)? onSubmitted;

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
    icon: widget.icon,
    maxLines: widget.secret ? 1 : (widget.lines ?? 1),
    type: widget.keyboard,
    onChanged: widget.onChanged,
    onSubmitted: widget.onSubmitted,
  );
}
