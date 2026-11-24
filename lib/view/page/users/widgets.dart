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

/// Identity header shared by user and group detail pages.
class UserIdentityHeader extends StatelessWidget {
  const UserIdentityHeader({
    super.key,
    required this.name,
    required this.subtitle,
    required this.isRoot,
  });

  final String name;
  final String subtitle;
  final bool isRoot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: isRoot
              ? scheme.errorContainer
              : scheme.primaryContainer,
          child: Text(
            name.isEmpty ? '?' : name[0].toUpperCase(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isRoot
                  ? scheme.onErrorContainer
                  : scheme.onPrimaryContainer,
            ),
          ),
        ),
        UIs.width13,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (isRoot) ...[
                    UIs.width7,
                    UserTag(
                      'root',
                      foreground: scheme.onErrorContainer,
                      background: scheme.errorContainer,
                    ),
                  ],
                ],
              ),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: UIs.text12Grey,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Overflow menu with a single destructive Delete action.
class DeleteOverflowButton extends StatelessWidget {
  const DeleteOverflowButton({super.key, required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ContextMenuButton(
      tooltip: libL10n.more,
      actions: () => [
        ContextMenuAction(
          text: libL10n.delete,
          icon: Icons.delete_outline,
          destructive: true,
          onTap: onDelete,
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(7),
        child: Icon(Icons.more_vert, size: 18),
      ),
    );
  }
}
