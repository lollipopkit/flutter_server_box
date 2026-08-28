import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/provider/services.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/view/page/ssh/page/page.dart';

final class ServicesPage extends ConsumerStatefulWidget {
  const ServicesPage({super.key, required this.args});

  final SpiRequiredArgs args;

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: ServicesPage.new,
    path: '/services',
  );

  @override
  ConsumerState<ServicesPage> createState() => _ServicesPageState();
}

final class _ServicesPageState extends ConsumerState<ServicesPage> {
  late final _pro = servicesProvider(widget.args.spi);
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
        title: TwoLineText(up: l10n.services, down: widget.args.spi.name),
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
    if (failure != null) {
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

    final manager = ref.watch(_pro.select((pro) => pro.manager));
    final notice = ref.watch(
      _pro.select((pro) => (pro.notice, pro.noticeDetail)),
    );
    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Column(
            children: [
              if (manager != null) _buildManagerTag(manager),
              if (manager?.supportsUserScope == true) _buildScopeFilterChips(),
              if (notice.$1 case final value?)
                _buildNotice(value, notice.$2),
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
        _buildUnitList(manager),
      ],
    );
  }

  Widget _buildFailure(ServiceFailure failure) {
    final (title, explain) = switch (failure.issue) {
      ServiceIssue.unsupported => (
        l10n.serviceManagerUnsupported,
        [
          l10n.serviceManagerUnsupportedTip,
          if (failure.detectedManager case final manager?)
            l10n.serviceManagerFmt(manager),
        ].join(' '),
      ),
      ServiceIssue.listFailed => (l10n.serviceListFailed, null),
      ServiceIssue.unreachable => (l10n.serverUnreachable, null),
    };
    return PageIssueView(
      title: title,
      explain: explain,
      detail: failure.detail,
      icon: failure.issue == ServiceIssue.unsupported
          ? Icons.help_outline
          : Icons.error_outline,
      onRetry: _refresh,
    );
  }

  Widget _buildManagerTag(ServiceManagerType manager) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: const Icon(Icons.settings_suggest, size: 17),
        label: Text(l10n.serviceManagerFmt(manager.displayName)),
      ),
    ).paddingSymmetric(horizontal: 13, vertical: 8);
  }

  Widget _buildNotice(ServiceListingNotice notice, String? detail) {
    final (title, explain) = switch (notice) {
      ServiceListingNotice.userScopeUnavailable => (
        l10n.systemdUserScopeMissing,
        l10n.systemdUserScopeMissingTip,
      ),
      ServiceListingNotice.detailsUnavailable => (
        l10n.serviceDetailsUnavailable,
        l10n.serviceDetailsUnavailableTip,
      ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 15),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TipText(title, explain),
              if (detail != null && detail.isNotEmpty)
                Text(detail, style: UIs.text11Grey),
            ],
          ),
        ),
      ],
    ).paddingSymmetric(horizontal: 17, vertical: 4);
  }

  Widget _buildScopeFilterChips() {
    final currentFilter = ref.watch(_pro.select((p) => p.scopeFilter));
    return Wrap(
      spacing: 8,
      children: ServiceScopeFilter.values.map((filter) {
        return FilterChip(
          selected: filter == currentFilter,
          label: Text(filter.displayName),
          onSelected: (_) => _notifier.setScopeFilter(filter),
        );
      }).toList(),
    ).paddingSymmetric(horizontal: 13, vertical: 8);
  }

  Widget _buildUnitList(ServiceManagerType? manager) {
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
          leading: manager?.supportsUserScope == true
              ? _buildTag(unit.scope.name.capitalize, unit.scope.color, true)
              : const Icon(Icons.miscellaneous_services),
          title: unit.description != null
              ? TipText(unit.name, unit.description!)
              : Text(unit.name),
          subtitle: Wrap(
            children: [
              _buildTag(unit.state.displayName, unit.state.color),
              if (unit.type != ServiceUnitType.service ||
                  manager == ServiceManagerType.systemd)
                _buildTag(unit.type.name.capitalize),
              if (unit.enabled case final enabled?)
                _buildTag(
                  enabled ? l10n.serviceEnabled : libL10n.disabled,
                  enabled ? Colors.green : null,
                ),
            ],
          ).paddingOnly(top: 7),
          trailing: _buildUnitActions(unit),
        ).cardx.paddingSymmetric(horizontal: 13);
      }, childCount: filteredUnits.length),
    );
  }

  Widget _buildUnitActions(ServiceUnit unit) {
    return PopupMenu(
      items: unit.actions.map(_buildUnitActionButton).toList(),
      onSelected: (val) => _handleUnitActionSelected(unit, val),
    );
  }

  void _handleUnitActionSelected(ServiceUnit unit, ServiceAction action) {
    final command = _notifier.commandFor(unit, action);
    if (command == null) return;
    if (action == ServiceAction.stop ||
        action == ServiceAction.restart ||
        action == ServiceAction.disable) {
      _showConfirmDialog(command);
    } else {
      _navigateToSsh(command);
    }
  }

  Future<void> _showConfirmDialog(String command) async {
    final sure = await context.showRoundDialog(
      title: libL10n.attention,
      child: SimpleMarkdown(data: '```shell\n$command\n```'),
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
    if (sure == true) _navigateToSsh(command);
  }

  void _navigateToSsh(String command) {
    final args = SshPageArgs(
      source: ServerSource(widget.args.spi),
      initCmd: command,
    );
    SSHPage.route.go(context, args);
  }

  PopupMenuEntry _buildUnitActionButton(ServiceAction action) {
    return PopupMenuItem<ServiceAction>(
      value: action,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Icon(action.icon, size: 19),
          const SizedBox(width: 10),
          Text(action.displayName),
        ],
      ),
    );
  }

  Widget _buildTag(String tag, [Color? color, bool noPad = false]) {
    return Container(
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.7) ?? UIs.halfAlpha,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(tag, style: UIs.text11)
          .paddingSymmetric(horizontal: 5, vertical: 1),
    ).paddingOnly(right: noPad ? 0 : 5);
  }
}

extension _ServicesPageActions on _ServicesPageState {
  Future<void> _refresh() => _notifier.getServices();
}
