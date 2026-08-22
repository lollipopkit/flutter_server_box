import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/systemd.dart';
import 'package:server_box/data/provider/systemd.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/view/page/ssh/page/page.dart';

final class SystemdPage extends ConsumerStatefulWidget {
  final SpiRequiredArgs args;

  const SystemdPage({super.key, required this.args});

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: SystemdPage.new,
    path: '/systemd',
  );

  @override
  ConsumerState<SystemdPage> createState() => _SystemdPageState();
}

final class _SystemdPageState extends ConsumerState<SystemdPage> {
  late final _pro = systemdProvider(widget.args.spi);

  late final _notifier = ref.read(_pro.notifier);

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        centerTitle: true,
        title: TwoLineText(up: l10n.systemd, down: widget.args.spi.name),
        actions: isDesktop
            ? [
                Btn.icon(text: libL10n.refresh, 
                  icon: const Icon(Icons.refresh),
                  onTap: _refresh,
                ),
              ]
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final isBusy = ref.watch(_pro.select((pro) => pro.isBusy));
    final failure = ref.watch(_pro.select((pro) => pro.failure));

    // Nothing to filter and nothing to list, so the page is the message. Still
    // inside a scroll view, since pull-to-refresh is how a phone retries.
    if (failure != null && failure.issue != SystemdIssue.noUserScope) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: isBusy ? UIs.centerLoading : _buildFailure(failure),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildScopeFilterChips(),
              if (failure != null) _buildUserScopeNote(),
              AnimatedContainer(
                duration: Durations.medium1,
                curve: Curves.fastEaseInToSlowEaseOut,
                height: isBusy ? SizedLoading.medium.size : 0,
                width: isBusy ? SizedLoading.medium.size : 0,
                child: isBusy ? SizedLoading.medium : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        _buildUnitList(),
      ],
    );
  }

  Widget _buildFailure(SystemdFailure failure) {
    final (title, explain) = switch (failure.issue) {
      SystemdIssue.noSystemd => (
        l10n.systemdMissing,
        [
          l10n.systemdMissingTip,
          if (failure.initSystem case final init?) l10n.initSystemFmt(init),
        ].join(' '),
      ),
      SystemdIssue.listFailed => (l10n.systemdListFailed, null),
      SystemdIssue.unreachable => (l10n.serverUnreachable, null),
      // Handled as a note above the list, not as the whole page.
      SystemdIssue.noUserScope => (
        l10n.systemdUserScopeMissing,
        l10n.systemdUserScopeMissingTip,
      ),
    };
    return PageIssueView(
      title: title,
      explain: explain,
      detail: failure.detail,
      icon: failure.issue == SystemdIssue.noSystemd
          ? Icons.help_outline
          : Icons.error_outline,
      onRetry: _refresh,
    );
  }

  /// The system units listed and the user ones did not, so the list is real
  /// and only incomplete — said above it rather than in place of it.
  Widget _buildUserScopeNote() {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 15),
        const SizedBox(width: 7),
        Expanded(
          child: TipText(
            l10n.systemdUserScopeMissing,
            l10n.systemdUserScopeMissingTip,
          ),
        ),
      ],
    ).paddingSymmetric(horizontal: 17, vertical: 4);
  }

  Widget _buildScopeFilterChips() {
    final currentFilter = ref.watch(_pro.select((p) => p.scopeFilter));
    return Wrap(
      spacing: 8,
      children: SystemdScopeFilter.values.map((filter) {
        final isSelected = filter == currentFilter;
        return FilterChip(
          selected: isSelected,
          label: Text(filter.displayName),
          onSelected: (_) => _notifier.setScopeFilter(filter),
        );
      }).toList(),
    ).paddingSymmetric(horizontal: 13, vertical: 8);
  }

  Widget _buildUnitList() {
    ref.watch(_pro.select((p) => (p.units, p.scopeFilter)));
    final filteredUnits = _notifier.filteredUnits;
    if (filteredUnits.isEmpty) {
      return SliverToBoxAdapter(
        child: CenterGreyTitle(libL10n.empty).paddingSymmetric(horizontal: 13),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final unit = filteredUnits[index];
        return ListTile(
          leading: _buildScopeTag(unit.scope),
          title: unit.description != null
              ? TipText(unit.name, unit.description!)
              : Text(unit.name),
          subtitle: Wrap(
            children: [_buildStateTag(unit.state), _buildTypeTag(unit.type)],
          ).paddingOnly(top: 7),
          trailing: _buildUnitFuncs(unit),
        ).cardx.paddingSymmetric(horizontal: 13);
      }, childCount: filteredUnits.length),
    );
  }

  Widget _buildUnitFuncs(SystemdUnit unit) {
    return PopupMenu(
      items: unit.availableFuncs.map(_buildUnitFuncBtn).toList(),
      onSelected: (val) => _handleUnitFuncSelected(unit, val),
    );
  }

  void _handleUnitFuncSelected(SystemdUnit unit, SystemdUnitFunc func) {
    final cmd = unit.getCmd(func: func, isRoot: widget.args.spi.isRoot);

    if (func == SystemdUnitFunc.stop || func == SystemdUnitFunc.restart) {
      _showConfirmDialog(cmd);
    } else {
      _navigateToSsh(cmd);
    }
  }

  Future<void> _showConfirmDialog(String cmd) async {
    final sure = await context.showRoundDialog(
      title: libL10n.attention,
      child: SimpleMarkdown(data: '```shell\n$cmd\n```'),
      actions: [
        Btn.cancel(),
        CountDownBtn(
          seconds: 3,
          onTap: () => context.popDialog(true),
          text: libL10n.ok,
          afterColor: Colors.red,
        ),
      ],
    );
    if (sure == true) _navigateToSsh(cmd);
  }

  void _navigateToSsh(String cmd) {
    final args = SshPageArgs(
      source: ServerSource(widget.args.spi),
      initCmd: cmd,
    );
    SSHPage.route.go(context, args);
  }

  PopupMenuEntry _buildUnitFuncBtn(SystemdUnitFunc func) {
    return PopupMenuItem<SystemdUnitFunc>(
      value: func,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Icon(func.icon, size: 19),
          const SizedBox(width: 10),
          Text(func.name.capitalize),
        ],
      ),
    );
  }

  Widget _buildScopeTag(SystemdUnitScope scope) {
    return _buildTag(scope.name.capitalize, scope.color, true);
  }

  Widget _buildStateTag(SystemdUnitState state) {
    return _buildTag(state.name.capitalize, state.color);
  }

  Widget _buildTypeTag(SystemdUnitType type) {
    return _buildTag(type.name.capitalize);
  }

  Widget _buildTag(String tag, [Color? color, bool noPad = false]) {
    return Container(
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.7) ?? UIs.halfAlpha,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        tag,
        style: UIs.text11,
      ).paddingSymmetric(horizontal: 5, vertical: 1),
    ).paddingOnly(right: noPad ? 0 : 5);
  }
}

extension _SystemdPageActions on _SystemdPageState {
  /// No snackbar: what went wrong is shown on the page, which is where the
  /// user is looking and where it stays until it is fixed.
  Future<void> _refresh() => _notifier.getUnits();
}
