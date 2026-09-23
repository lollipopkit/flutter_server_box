import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:server_box/data/model/plugin/l10n.dart';
import 'package:server_box/data/model/plugin/node.dart';

/// What one plugin surface holds between frames. PLUGINS.md section 5.2.
///
/// Two caches and a set of notifiers, and each of the three exists to keep
/// Flutter from doing work:
///
/// - [widgetOf] hands back the *same* Widget instance for a subtree the plugin
///   said has not changed. `Element.updateChild` returns without calling
///   `update()` when the new widget is identical to the old one, so the whole
///   subtree is skipped — no rebuild, no layout, no paint. A tree rebuilt from
///   JSON never hits that path on its own: every widget is a new object.
/// - [slot] is one notifier per bound value, so a refresh that answers
///   `values` and no tree rebuilds nothing above the bound leaves.
/// - [leaf] returns one instance for identical leaves, which hits the same
///   fast path for a node that carries no revision at all.
///
/// One of these per surface, living as long as the surface does — which is
/// also as long as the plugin instance behind it, since the SDK's `frame()`
/// keeps exactly one previous tree.
class PluginSurfaceState {
  PluginSurfaceState({this.l10n = PluginL10n.empty, this.assetDir});

  PluginL10n l10n;

  /// The plugin's own directory, where an `image` node's file is looked up.
  ///
  /// A path rather than the bytes: a package may carry a few hundred kilobytes
  /// of images and every installed plugin is read at launch, so holding them
  /// would be memory spent on pictures nothing is showing. Null for a plugin
  /// with no directory, which is what a test and a not-yet-installed package
  /// look like.
  String? assetDir;

  /// Widgets by the revision they were built for.
  ///
  /// Keyed by revision alone, which is sound because the SDK assigns them from
  /// a counter that only rises: two nodes never share one within a tree.
  final Map<int, Widget> _byRev = {};

  /// One notifier per bound slot, kept across frames so the leaf listening to
  /// it is not rebuilt when the value moves.
  final Map<String, ValueNotifier<Object?>> _slots = {};

  /// Identical leaves, so `text('idle')` in two frames is one object.
  final Map<String, Widget> _leaves = {};

  /// How many leaves to remember.
  ///
  /// A cap rather than a lifetime: the point of this one is a value that
  /// alternates between a few strings, and an unbounded map would instead
  /// remember every number a counter ever showed.
  static const leafCacheSize = 256;

  /// The widget last built for [rev], or null when this surface has never had
  /// one — which is a plugin claiming the app holds something it does not.
  Widget? widgetOf(int rev) => _byRev[rev];

  void remember(int rev, Widget widget) => _byRev[rev] = widget;

  /// Drops every revision the current tree does not mention.
  ///
  /// Safe because a revision absent from it can never be named again: the
  /// plugin's own previous tree no longer holds it either. Without this a
  /// surface open for an hour remembers every widget it ever built.
  void keepOnly(Set<int> live) {
    _byRev.removeWhere((rev, _) => !live.contains(rev));
  }

  Widget? leaf(String signature) => _leaves[signature];

  void rememberLeaf(String signature, Widget widget) {
    if (_leaves.length >= leafCacheSize) _leaves.clear();
    _leaves[signature] = widget;
  }

  /// The notifier for [name], created on first use.
  ValueNotifier<Object?> slot(String name) =>
      _slots.putIfAbsent(name, () => ValueNotifier<Object?>(null));

  /// Applies what a `values`-only answer carried.
  ///
  /// Sets the notifiers and nothing else: no widget is rebuilt, no element is
  /// walked, and only the bound leaves' render objects are marked dirty. A
  /// name no leaf follows is kept anyway — a plugin may send a value for a
  /// slot whose leaf is about to appear.
  void applyValues(Map<String, Object?> values) {
    for (final e in values.entries) {
      slot(e.key).value = e.value;
    }
  }

  /// Seeds the notifiers a tree binds, so a bound leaf's first frame shows the
  /// value the tree carried rather than a blank.
  void seedSlots(PluginNode tree) {
    for (final name in tree.boundSlots()) {
      slot(name);
    }
  }

  /// Forgets everything the previous instance built.
  ///
  /// Called when a surface swaps its instance for one compiled from newer
  /// source. Revisions are the new plugin's to assign from 1 again, and
  /// `_byRev` is keyed by nothing else — so a tree that reused a number would
  /// be handed the *old* plugin's widget for it. The leaf cache is keyed by
  /// content and would be harmless, but a reload is a clean start and half a
  /// clean start is the kind of thing that goes wrong once and is never
  /// reproduced.
  ///
  /// The slot notifiers are emptied rather than disposed: the previous tree is
  /// still mounted at this point and its `ValueListenableBuilder`s are still
  /// listening, so disposing one throws when it detaches. They are dropped
  /// with the state itself in [dispose].
  void reset() {
    _byRev.clear();
    _leaves.clear();
    for (final notifier in _slots.values) {
      notifier.value = null;
    }
  }

  /// Rebuilds the current tree with new presentation inputs.
  ///
  /// Locale and asset directory changes do not require a new QuickJS instance:
  /// neither is plugin state. Cached widgets do need to go, though, because
  /// they may already contain translated text or an image resolved below the
  /// previous directory. Bound values stay intact so changing the app locale
  /// does not blank live readings until the next tick.
  void refreshPresentation() {
    _byRev.clear();
    _leaves.clear();
  }

  /// Whoever is waiting for the plugin to answer with a new tree.
  ///
  /// One at a time: the only thing that waits is a pull-to-refresh, and a
  /// second pull while the first is turning is the same question.
  Completer<void>? _waiting;

  /// Completes when this surface next draws a tree.
  ///
  /// What a `RefreshIndicator` needs and cannot get otherwise: the plugin's
  /// work happens in another isolate, over a network, and a future completed
  /// straight away would flash the spinner and say nothing.
  ///
  /// **Capped**, because a plugin may answer with values and no tree, or with
  /// nothing at all — and a spinner that turns forever is worse than one that
  /// gives up.
  Future<void> nextTree({Duration timeout = const Duration(seconds: 20)}) {
    final waiting = _waiting;
    if (waiting != null && !waiting.isCompleted) return waiting.future;
    final next = Completer<void>();
    _waiting = next;
    return next.future.timeout(timeout, onTimeout: () {});
  }

  /// Called by the renderer once a tree has been built.
  void drew() {
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }

  void dispose() {
    for (final notifier in _slots.values) {
      notifier.dispose();
    }
    _slots.clear();
    _byRev.clear();
    _leaves.clear();
    drew();
  }
}
