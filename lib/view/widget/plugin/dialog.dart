/// A dialog whose body is a plugin's own tree. PLUGINS.md section 5.3.
///
/// `sb.ui.prompt` used to be a title and a list of text boxes, which is enough
/// for a password and for nothing else: the scheduled plugin's editor wants a
/// schedule beside a command, the disk plugin's wants a path and a depth, and
/// neither can be a row of `TextField`s. So the body is a node tree, drawn by
/// the same renderer as every other surface — a plugin's dialog is built out of
/// the same controls as its page, and looks like the app's own either way.
///
/// **The plugin is blocked while this is up**, waiting for the answer, so it
/// cannot process events meanwhile. That decides the whole shape: the *host*
/// holds what the controls say, keyed by the message each control carries, and
/// hands the map back when the dialog is confirmed. A control with no `change`
/// message is a control whose value nobody asked for.
library;

import 'package:flutter/material.dart';
import 'package:server_box/data/model/plugin/l10n.dart';
import 'package:server_box/data/model/plugin/node.dart';
import 'package:server_box/view/widget/plugin/render.dart';
import 'package:server_box/view/widget/plugin/surface.dart';

class PluginNodeDialog extends StatefulWidget {
  const PluginNodeDialog({
    super.key,
    required this.node,
    required this.strings,
  });

  final PluginNode node;
  final PluginL10n strings;

  /// What the controls in [node] start out saying.
  ///
  /// Read from the tree rather than started empty: a dialog that opens with a
  /// path already in it must answer with that path when the user changes only
  /// the field beside it. Anything a plugin did not attach a `change` message
  /// to is not a field — it is a label, a divider, a row of text.
  static Map<String, String> seed(PluginNode node) {
    final out = <String, String>{};
    void walk(PluginNode n) {
      final msg = n.events['change'];
      if (msg is String && msg.isNotEmpty) {
        final value = n.props['value'];
        if (value != null) out[msg] = '$value';
      }
      for (final child in n.children) {
        walk(child);
      }
    }

    walk(node);
    return out;
  }

  @override
  State<PluginNodeDialog> createState() => PluginNodeDialogState();
}

class PluginNodeDialogState extends State<PluginNodeDialog> {
  late final _values = PluginNodeDialog.seed(widget.node);
  late final _surface = PluginSurfaceState(l10n: widget.strings);

  /// What the controls say now. The caller reads this when the dialog is
  /// confirmed, and drops it when it is not.
  Map<String, String> get values => Map.unmodifiable(_values);

  @override
  void dispose() {
    _surface.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scrollable and bounded, because how tall this is belongs to the plugin:
    // a form of eight fields is taller than a phone, and an `AlertDialog` whose
    // content does not scroll answers that with a striped bar over the last
    // one.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: SingleChildScrollView(
        child: PluginRenderer(
          tree: widget.node,
          state: _surface,
          // Every control's message is the field it stands for. A plugin that
          // attaches an object rather than a name gets no value back, which is
          // the same thing as not asking for one.
          onEvent: (msg, value) {
            if (msg is! String || msg.isEmpty) return;
            _values[msg] = '${value ?? ''}';
          },
        ),
      ),
    );
  }
}
