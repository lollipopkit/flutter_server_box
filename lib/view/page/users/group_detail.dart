import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/admin/user_manager.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system_user.dart';
import 'package:server_box/view/page/users/widgets.dart';

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
  final SystemGroup group;
  final UserCatalog catalog;

  /// Answers true when the group changed, which closes this page: what it
  /// is showing no longer describes anything.
  final Future<bool> Function(SystemGroup group) onEdit;
  final Future<bool> Function(SystemGroup group) onDelete;
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
  var _busy = false;

  SystemGroup get _group => widget.args.group;

  @override
  Widget build(BuildContext context) {
    final catalog = widget.args.catalog;
    return Scaffold(
      appBar: CustomAppBar(
        title: TwoLineText(up: _group.name, down: widget.args.spi.name),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedLoading.small,
            )
          else ...[
            if (_group.local)
              Btn.icon(
                text: libL10n.edit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => _run(widget.args.onEdit),
              ),
            if (UserManager.groupDeletable(_group))
              DeleteOverflowButton(onDelete: () => _run(widget.args.onDelete)),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(13, 13, 13, 40),
        children: [
          UserIdentityHeader(
            name: _group.name,
            subtitle: [
              if (_group.isSystem(catalog.gidMin) && !_group.isRoot)
                libL10n.system,
              '${l10n.userGid} ${_group.gid}',
            ].join(' · '),
            isRoot: _group.isRoot,
          ),
          UIs.height13,
          _buildGroupCard(),
          if (_group.isRoot) ...[UIs.height13, const RootChangesWarning()],
        ],
      ),
    );
  }

  Widget _buildGroupCard() {
    final primary = _group.primaryMembers;
    return DetailCard(l10n.systemGroups, [
      DetailField(l10n.userGid, '${_group.gid}', mono: true),
      if (primary.isNotEmpty)
        DetailField(l10n.userPrimaryMembers, primary.join(' · '), mono: true),
      DetailField(
        l10n.userGroupMembers,
        _group.members.isEmpty ? '—' : _group.members.join(' · '),
        mono: true,
      ),
    ]);
  }

  Future<void> _run(Future<bool> Function(SystemGroup group) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    var popped = false;
    try {
      final changed = await action(_group);
      if (changed && mounted) {
        popped = true;
        context.pop();
      }
    } finally {
      if (!popped && mounted) setState(() => _busy = false);
    }
  }
}
