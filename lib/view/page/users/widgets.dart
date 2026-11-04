import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';

/// The pieces the user and group pages share.

/// A small coloured label: a user's or group's role, shell, lock state.
class UserTag extends StatelessWidget {
  const UserTag(this.text, {super.key, required this.foreground, required this.background});

  final String text;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: foreground)),
    );
  }
}

/// A titled card of [DetailField]s.
class DetailCard extends StatelessWidget {
  const DetailCard(this.title, this.children, {super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CardX(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: UIs.text11Grey),
            UIs.height7,
            ...children,
          ],
        ),
      ),
    );
  }
}

/// One labelled value in a [DetailCard].
class DetailField extends StatelessWidget {
  const DetailField(this.label, this.value, {super.key, this.mono = false, this.grey = false});

  final String label;
  final String value;
  final bool mono;
  final bool grey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: UIs.text12Grey)),
          UIs.width13,
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: mono ? 'monospace' : null,
                color: grey ? UIs.textGrey.color : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Under root's own user or group: a change there affects the whole system.
class RootChangesWarning extends StatelessWidget {
  const RootChangesWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber, size: 15, color: UIs.textGrey.color),
        UIs.width7,
        Expanded(
          child: Text(context.l10n.userRootChangesWarning, style: UIs.text12Grey),
        ),
      ],
    );
  }
}
