import 'dart:convert';

/// One node of a plugin's widget tree. PLUGINS.md section 5.1.
///
/// A plugin answers with a tree and the app draws it. The shape is permanent
/// in the way the host interface is: a published plugin draws through these
/// names, so adding one is free and changing one is a card that silently stops
/// showing a value.
///
/// Parsed rather than read out of a map at each use, so a malformed tree fails
/// in one place with one message instead of throwing somewhere inside a build.
class PluginNode {
  const PluginNode({
    required this.type,
    this.rev,
    this.key,
    this.props = const {},
    this.children = const [],
    this.events = const {},
    this.stub = false,
  });

  /// The widget type, as the vocabulary spells it — `column`, `kv`, `btn`.
  ///
  /// Not an enum: a tree written by a newer plugin may name one this build has
  /// nothing for, and that has to reach the renderer as a name it can report
  /// rather than as a parse failure that costs the whole surface.
  final String type;

  /// The revision of this subtree, assigned by the SDK's `frame()`.
  ///
  /// Unique across a tree — it comes from one counter that only ever rises —
  /// so the app can cache the widget it built under this number alone.
  final int? rev;

  /// Mapped to a Flutter `ValueKey`.
  ///
  /// Load-bearing rather than a nicety: `Widget.canUpdate` compares
  /// `runtimeType` and `key`, so a set of unkeyed children that gets reordered
  /// is matched positionally and every element — with its focus, its scroll
  /// offset and its expanded state — is thrown away.
  final String? key;

  final Map<String, Object?> props;
  final List<PluginNode> children;

  /// Event name to the message handed back to `onEvent` unchanged. The app
  /// never reads the message, which is what lets a plugin tag it and switch.
  final Map<String, Object?> events;

  /// Whether this arrived as `{t, k, v, s: 1}` — "you already have this
  /// subtree".
  ///
  /// Read from the marker, never inferred from the node being empty. A
  /// `spacer` carries no properties and no children either, so `{t, v}` would
  /// mean both "a spacer" and "reuse what you have" — and the app, told to
  /// reuse a revision it has never seen, would report that instead of drawing
  /// the spacer. The SDK draws the same distinction one layer up, in
  /// `Walked.changed`, for the same reason.
  final bool stub;

  static PluginNode? parse(String json) {
    try {
      final decoded = jsonDecode(json);
      return fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// The one place a node crosses from JSON.
  ///
  /// Kept to one function because it is also the seam PLUGINS.md 5.2 wants
  /// removed: decoding a whole tree on the isolate drawing frames is work
  /// nothing needs, and the alternative is for the FFI to answer typed objects
  /// directly. Whether flutter_rust_bridge carries a recursive struct is still
  /// unverified, so this stays and stays alone.
  static PluginNode? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final type = raw['t'];
    if (type is! String || type.isEmpty) return null;

    final props = raw['p'];
    final events = raw['on'];
    final children = raw['c'];
    final parsed = <PluginNode>[];
    if (children is List) {
      for (final child in children) {
        final node = fromJson(child);
        // A child that will not parse is dropped rather than failing the tree:
        // the cost of one bad node should be one missing row.
        if (node != null) parsed.add(node);
      }
    }

    return PluginNode(
      type: type,
      rev: raw['v'] is int ? raw['v'] as int : null,
      key: raw['k'] is String ? raw['k'] as String : null,
      props: props is Map ? _stringKeyed(props) : const {},
      children: parsed,
      events: events is Map ? _stringKeyed(events) : const {},
      // The marker the SDK writes for "unchanged", and a revision to resolve
      // it against — without one there is nothing to look up.
      stub: raw['s'] == 1 && raw['v'] is int,
    );
  }

  static Map<String, Object?> _stringKeyed(Map raw) => {
    for (final e in raw.entries)
      if (e.key is String) e.key as String: e.value,
  };

  /// The value of [name], following a binding if it is one.
  ///
  /// [slots] is what a bound property reads from. Null resolves a binding to
  /// null, which is what a renderer wants when it is deciding *whether* to
  /// build a listening leaf rather than reading a value.
  Object? prop(String name, {Map<String, Object?>? slots}) {
    final raw = props[name];
    final slot = bindingOf(raw);
    if (slot == null) return raw;
    return slots?[slot];
  }

  /// The slot a property follows, or null when it holds a value.
  ///
  /// `{"$": "cpu"}` — the app builds such a leaf as a `ValueListenableBuilder`
  /// so a refresh that answers only `values` rebuilds nothing above it.
  static String? bindingOf(Object? raw) {
    if (raw is! Map) return null;
    final slot = raw[r'$'];
    return slot is String && slot.isNotEmpty ? slot : null;
  }

  /// Every slot any property in this subtree follows.
  Set<String> boundSlots() {
    final out = <String>{};
    void walk(PluginNode n) {
      for (final value in n.props.values) {
        final slot = bindingOf(value);
        if (slot != null) out.add(slot);
      }
      for (final child in n.children) {
        walk(child);
      }
    }

    walk(this);
    return out;
  }

  /// Every revision in this subtree, which is what a cache may keep.
  ///
  /// A revision absent from the current tree can never be named again: the
  /// plugin's own `previous` no longer holds it either.
  Set<int> revisions() {
    final out = <int>{};
    void walk(PluginNode n) {
      final rev = n.rev;
      if (rev != null) out.add(rev);
      for (final child in n.children) {
        walk(child);
      }
    }

    walk(this);
    return out;
  }

  @override
  String toString() => 'PluginNode($type${key == null ? '' : '#$key'}'
      '${rev == null ? '' : '@$rev'}${stub ? ' stub' : ''})';
}
