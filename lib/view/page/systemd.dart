import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/systemd.dart';
import 'package:server_box/data/provider/systemd.dart';

final class SystemdPageArgs {
  final Spi spi;

  const SystemdPageArgs({
    required this.spi,
  });
}

final class SystemdPage extends StatefulWidget {
  final SystemdPageArgs args;

  const SystemdPage({
    super.key,
    required this.args,
  });

  static const route = AppRouteArg<void, SystemdPageArgs>(
    page: SystemdPage.new,
    path: '/systemd',
  );

  @override
  State<SystemdPage> createState() => _SystemdPageState();
}

final class _SystemdPageState extends State<SystemdPage> {
  late final _pro = SystemdProvider.init(widget.args.spi);

  @override
  void dispose() {
    super.dispose();
    _pro.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: const Text('Systemd'),
        actions: isDesktop
            ? [Btn.icon(icon: const Icon(Icons.refresh), onTap: _pro.getUnits)]
            : null,
      ),
      body: RefreshIndicator(onRefresh: _pro.getUnits, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _pro.isBusy.listenVal(
            (isBusy) => AnimatedContainer(
              duration: Durations.medium1,
              curve: Curves.fastEaseInToSlowEaseOut,
              height: isBusy ? 30 : 0,
              child: isBusy
                  ? SizedLoading.small.paddingOnly(bottom: 7)
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        _buildUnitList(_pro.units),
      ],
    );
  }

  Widget _buildUnitList(VNode<List<SystemdUnit>> units) {
    return units.listenVal(
      (units) {
        if (units.isEmpty) {
          return SliverToBoxAdapter(
            child:
                CenterGreyTitle(libL10n.empty).paddingSymmetric(horizontal: 13),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final unit = units[index];
              return ListTile(
                leading: _buildScopeTag(unit.scope),
                title: unit.description != null
                    ? TipText(unit.name, unit.description!)
                    : Text(unit.name),
                subtitle: Wrap(children: [
                  _buildStateTag(unit.state),
                  _buildTypeTag(unit.type),
                ]).paddingOnly(top: 7),
                trailing: _buildUnitFuncs(unit),
              ).cardx.paddingSymmetric(horizontal: 13);
            },
            childCount: units.length,
          ),
        );
      },
    );
  }

  Widget _buildUnitFuncs(SystemdUnit unit) {
    return PopupMenu(
      items: unit.availableFuncs.map(_buildUnitFuncBtn).toList(),
      onSelected: (val) async {
        final cmd = unit.getCmd(func: val, isRoot: widget.args.spi.isRoot);
        final sure = await context.showRoundDialog(
          title: libL10n.attention,
          child: SimpleMarkdown(data: '```shell\n$cmd\n```'),
          actions: [
            CountDownBtn(
              seconds: 1,
              onTap: () => context.pop(true),
              text: libL10n.ok,
              afterColor: Colors.red,
            ),
          ],
        );
        if (sure != true) return;

        AppRoutes.ssh(spi: widget.args.spi, initCmd: cmd).go(context);
      },
    );
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
          Text(func.name.upperFirst),
        ],
      ),
    );
  }

  Widget _buildScopeTag(SystemdUnitScope scope) {
    return _buildTag(scope.name.upperFirst, scope.color, true);
  }

  Widget _buildStateTag(SystemdUnitState state) {
    return _buildTag(state.name.upperFirst, state.color);
  }

  Widget _buildTypeTag(SystemdUnitType type) {
    return _buildTag(type.name.upperFirst);
  }

  Widget _buildTag(String tag, [Color? color, bool noPad = false]) {
    return Container(
      decoration: BoxDecoration(
        color: color?.withOpacity(0.7) ?? UIs.halfAlpha,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(tag, style: UIs.text11)
          .paddingSymmetric(horizontal: 5, vertical: 1),
    ).paddingOnly(right: noPad ? 0 : 5);
  }
}
