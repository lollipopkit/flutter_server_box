import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../data/model/pkg/upgrade_info.dart';
import '../../data/model/server/dist.dart';
import '../../data/model/server/server_private_info.dart';
import '../../data/provider/pkg.dart';
import '../../data/provider/server.dart';
import '../../data/res/ui.dart';
import '../../locator.dart';
import '../widget/custom_appbar.dart';
import '../widget/round_rect_card.dart';
import '../widget/two_line_text.dart';

class PkgPage extends StatefulWidget {
  const PkgPage({Key? key, required this.spi}) : super(key: key);

  final ServerPrivateInfo spi;

  @override
  _PkgManagePageState createState() => _PkgManagePageState();
}

class _PkgManagePageState extends State<PkgPage>
    with SingleTickerProviderStateMixin {
  late MediaQueryData _media;
  final _scrollController = ScrollController();
  final _scrollControllerUpdate = ScrollController();
  final _textController = TextEditingController();
  final _pkgProvider = locator<PkgProvider>();
  late S _s;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _s = S.of(context)!;
  }

  @override
  void dispose() {
    super.dispose();
    _pkgProvider.clear();
    _textController.dispose();
    _scrollController.dispose();
    _scrollControllerUpdate.dispose();
  }

  @override
  void initState() {
    super.initState();
    final si = locator<ServerProvider>().servers[widget.spi.id];

    if (si == null) return;
    _pkgProvider.init(
      si.client!,
      si.status.sysVer.dist,
      () =>
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent),
      () => _scrollControllerUpdate
          .jumpTo(_scrollController.position.maxScrollExtent),
      widget.spi.user,
      context,
    );
    _pkgProvider.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PkgProvider>(builder: (_, pkg, __) {
      return Scaffold(
        appBar: CustomAppBar(
          centerTitle: true,
          title: TwoLineText(up: _s.pkg, down: widget.spi.name),
        ),
        body: _buildBody(pkg),
        floatingActionButton: _buildFAB(pkg),
      );
    });
  }

  Widget? _buildFAB(PkgProvider pkg) {
    if (pkg.upgradeable?.isEmpty ?? true) {
      return null;
    }
    return FloatingActionButton(
      onPressed: () {
        pkg.upgrade();
      },
      child: const Icon(Icons.upgrade),
    );
  }

  Widget _buildBody(PkgProvider pkg) {
    if (pkg.error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error,
            color: Colors.redAccent,
            size: 37,
          ),
          const SizedBox(
            height: 37,
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: _media.size.height * 0.3,
                minWidth: _media.size.width),
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: RoundRectCard(
                SingleChildScrollView(
                  padding: const EdgeInsets.all(17),
                  child: Text(
                    pkg.error!,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (pkg.upgradeable == null) {
      if (pkg.updateLog == null) {
        return centerLoading;
      }
      return SizedBox(
        height: _media.size.height - _media.padding.top - _media.padding.bottom,
        child: ConstrainedBox(
          constraints: const BoxConstraints.expand(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            controller: _scrollControllerUpdate,
            child: Text(pkg.updateLog!),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(13),
      children: _buildUpdatePanel(pkg).map((e) => RoundRectCard(e)).toList(),
    );
  }

  List<Widget> _buildUpdatePanel(PkgProvider apt) {
    final children = <Widget>[];
    if (apt.upgradeable!.isEmpty) {
      children.add(ListTile(
        title: Text(
          _s.noUpdateAvailable,
          textAlign: TextAlign.center,
        ),
        subtitle: const Text('>_<', textAlign: TextAlign.center),
      ));
      return children;
    }

    if (apt.upgradeLog == null) {
      children.addAll(
        apt.upgradeable?.map((e) => _buildUpdateItem(e, apt)).toList() ?? [],
      );
    } else {
      children.add(SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        controller: _scrollController,
        child: Text(apt.upgradeLog ?? ''),
      ));
    }

    return children;
  }

  Widget _buildUpdateItem(UpgradePkgInfo info, PkgProvider apt) {
    final t = () {
      if (info.nowVersion.isNotEmpty && info.newVersion.isNotEmpty) {
        return '${info.nowVersion} -> ${info.newVersion}';
      }
      return info.newVersion;
    }();
    return ListTile(
      title: Text(info.package),
      subtitle: Text(t, style: grey),
    );
  }
}
