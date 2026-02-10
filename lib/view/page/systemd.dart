import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/systemd.dart';
import 'package:server_box/data/provider/ai/ask_ai.dart';
import 'package:server_box/data/provider/systemd.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/widget/ai/ai_assist_sheet.dart';

final class SystemdPage extends ConsumerStatefulWidget {
  final SpiRequiredArgs args;

  const SystemdPage({super.key, required this.args});

  static const route = AppRouteArg<void, SpiRequiredArgs>(page: SystemdPage.new, path: '/systemd');

  @override
  ConsumerState<SystemdPage> createState() => _SystemdPageState();
}

final class _SystemdPageState extends ConsumerState<SystemdPage> {
  late final _pro = systemdProvider(widget.args.spi);

  late final _notifier = ref.read(_pro.notifier);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: const Text('Systemd'),
        actions: [
          if (isDesktop) Btn.icon(icon: const Icon(Icons.refresh), onTap: _notifier.getUnits),
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            tooltip: context.l10n.askAi,
            onPressed: () {
              final blocks = <String>[
                '[Systemd]\nscopeFilter: ${ref.read(_pro).scopeFilter.displayName}\nitems: ${_notifier.filteredUnits.length}',
              ];
              showAiAssistSheet(
                context,
                AiAssistArgs(
                  title: context.l10n.askAi,
                  contextBlocks: blocks,
                  scenario: AskAiScenario.systemd,
                  applyLabel: libL10n.ok,
                  applyBehavior: AiApplyBehavior.openSsh,
                  onOpenSsh: _navigateToSsh,
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _notifier.getUnits, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final isBusy = ref.watch(_pro.select((pro) => pro.isBusy));
    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildScopeFilterChips(),
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
      return SliverToBoxAdapter(child: CenterGreyTitle(libL10n.empty).paddingSymmetric(horizontal: 13));
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final unit = filteredUnits[index];
        return ListTile(
          leading: _buildScopeTag(unit.scope),
          title: unit.description != null ? TipText(unit.name, unit.description!) : Text(unit.name),
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

  void _showConfirmDialog(String cmd) async {
    final sure = await context.showRoundDialog(
      title: libL10n.attention,
      child: SimpleMarkdown(data: '```shell\n$cmd\n```'),
      actions: [
        Btn.cancel(),
        CountDownBtn(
          seconds: 3,
          onTap: () => context.pop(true),
          text: libL10n.ok,
          afterColor: Colors.red,
        ),
      ],
    );
    if (sure == true) _navigateToSsh(cmd);
  }

  void _navigateToSsh(String cmd) {
    final args = SshPageArgs(spi: widget.args.spi, initCmd: cmd);
    SSHPage.route.go(context, args);
  }

  PopupMenuEntry _buildUnitFuncBtn(SystemdUnitFunc func) {
    return PopupMenuItem<SystemdUnitFunc>(
      value: func,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [Icon(func.icon, size: 19), const SizedBox(width: 10), Text(func.name.capitalize)],
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
      child: Text(tag, style: UIs.text11).paddingSymmetric(horizontal: 5, vertical: 1),
    ).paddingOnly(right: noPad ? 0 : 5);
  }
}
