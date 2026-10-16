import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';

/// A virtual key as a screen reader sees it: a button named after the key,
/// whether a modifier is armed, and what a shortcut opens.
///
/// [child] is the key's tap target. What it draws goes inside an
/// [ExcludeSemantics]: the label already says it, and merged in it would be
/// read twice.
final class VirtKeySemantics extends StatelessWidget {
  const VirtKeySemantics({
    super.key,
    required this.item,
    required this.armed,
    required this.child,
    this.enabled = true,
  });

  final VirtKey item;
  final bool armed;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: item.semanticLabel,
        hint: item.help,
        toggled: item.toggleable ? armed : null,
        child: child,
      ),
    );
  }
}
