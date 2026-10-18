import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system_user.dart';
import 'package:server_box/data/service/user_manager.dart';

/// Everything the detail page needs, including the two flows the list already
/// owns. Duplicating the editor here would mean two dialogs to keep in step.
final class GroupDetailPageArgs {
  const GroupDetailPageArgs({
    required this.spi,
    required this.group,
    required this.catalog,
    required this.onEdit,
    required this.onDelete,
  });

  final Spi spi;
  final ServerGroup group;
  final ServerUserCatalog catalog;

  /// Answers true when the group changed, which closes this page: what it
  /// is showing no longer describes anything.
  final Future<bool> Function(ServerGroup group) onEdit;
  final Future<bool> Function(ServerGroup group) onDelete;
}

final class GroupDetailPage extends ConsumerStatefulWidget {
  const GroupDetailPage({super.key, required this.args});

  final GroupDetailPageArgs args;

  static const route = AppRouteArg<void, GroupDetailPageArgs>(
    page: GroupDetailPage.new,
    path: '/group_detail',
  );

  @override
  ConsumerState<GroupDetailPage> createState() => _GroupDetailPageState();
}

final class _GroupDetailPageState extends ConsumerState<GroupDetailPage> {
  ServerGroup get _group => widget.args.group;

  @override
  Widget build(BuildContext context) {
    final catalog = widget.args.catalog;
    return Scaffold(
      appBar: CustomAppBar(
        title: TwoLineText(up: _group.name, down: widget.args.spi.name),
        actions: [
          if (_group.local)
            Btn.icon(
              text: libL10n.edit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              onTap: () => _run(widget.args.onEdit),
            ),
          if (UserManager.groupDeletable(_group))
            ContextMenuButton(
              tooltip: libL10n.more,
              actions: () => [
                ContextMenuAction(
                  text: libL10n.delete,
                  icon: Icons.delete_outline,
                  destructive: true,
                  onTap: () => _run(widget.args.onDelete),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.all(7),
                child: Icon(Icons.more_vert, size: 18),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(13, 13, 13, 40),
        children: [
          _buildIdentity(catalog),
          UIs.height13,
          _buildGroupCard(),
          if (_group.isRoot) ...[UIs.height13, _buildRootWarning()],
        ],
      ),
    );
  }

  Widget _buildIdentity(ServerUserCatalog catalog) {
    final scheme = Theme.of(context).colorScheme;
    final root = _group.isRoot;
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: root
              ? scheme.errorContainer
              : scheme.primaryContainer,
          child: Text(
            _group.name.isEmpty ? '?' : _group.name[0].toUpperCase(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: root ? scheme.onErrorContainer : scheme.onPrimaryContainer,
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
                      _group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (root) ...[
                    UIs.width7,
                    _tag('root', scheme.onErrorContainer, scheme.errorContainer),
                  ],
                ],
              ),
              Text(
                [
                  if (_group.isSystem(catalog.gidMin) && !root) libL10n.system,
                  '${l10n.userGid} ${_group.gid}',
                ].join(' · '),
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

  Widget _buildGroupCard() {
    final primary = _group.primaryMembers;
    return _card(l10n.systemGroups, [
      _field(l10n.userGid, '${_group.gid}', mono: true),
      if (primary.isNotEmpty)
        _field(l10n.userPrimaryMembers, primary.join(' · '), mono: true),
      _field(
        l10n.userGroupMembers,
        _group.members.isEmpty ? '—' : _group.members.join(' · '),
        mono: true,
      ),
    ]);
  }

  Widget _buildRootWarning() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber, size: 15, color: UIs.textGrey.color),
        UIs.width7,
        Expanded(
          child: Text(l10n.userRootChangesWarning, style: UIs.text12Grey),
        ),
      ],
    );
  }

  Widget _card(String title, List<Widget> children) {
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

  Widget _field(String label, String value, {bool mono = false}) {
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
              style: TextStyle(fontFamily: mono ? 'monospace' : null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color foreground, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: foreground)),
    );
  }

  Future<void> _run(Future<bool> Function(ServerGroup group) action) async {
    final changed = await action(_group);
    if (changed && mounted) context.pop();
  }
}
