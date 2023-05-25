import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/view/widget/input_field.dart';

import '../../data/model/pkg/upgrade_info.dart';
import '../../data/model/server/dist.dart';
import '../../core/utils/ui.dart';
import '../../data/model/server/server_private_info.dart';
import '../../data/provider/pkg.dart';
import '../../data/provider/server.dart';
import '../../data/res/ui.dart';
import '../../locator.dart';
import '../widget/round_rect_card.dart';
import '../widget/two_line_text.dart';

class PkgManagePage extends StatefulWidget {
  const PkgManagePage(this.spi, {Key? key}) : super(key: key);

  final ServerPrivateInfo spi;

  @override
  _PkgManagePageState createState() => _PkgManagePageState();
}

class _PkgManagePageState extends State<PkgManagePage>
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
  }

  @override
  void initState() {
    super.initState();
    final si = locator<ServerProvider>().servers[widget.spi.id];
    if (si == null || si.client == null) {
      showSnackBar(context, Text(_s.waitConnection));
      context.pop();
      return;
    }

    _pkgProvider.init(
      si.client!,
      si.status.sysVer.dist,
      () =>
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent),
      () => _scrollControllerUpdate
          .jumpTo(_scrollController.position.maxScrollExtent),
      onPwdRequest,
      widget.spi.user,
    );
    _pkgProvider.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PkgProvider>(builder: (_, pkg, __) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: TwoLineText(up: _s.pkg, down: widget.spi.name),
        ),
        body: _buildBody(pkg),
        floatingActionButton: _buildFAB(pkg),
      );
    });
  }

  void onSubmitted() {
    if (_textController.text == '') {
      showRoundDialog(
        context: context,
        child: Text(_s.fieldMustNotEmpty),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(_s.ok),
          ),
        ],
      );
      return;
    }
    context.pop();
  }

  Future<String> onPwdRequest() async {
    if (!mounted) return '';
    await showRoundDialog(
      context: context,
      title: Text(widget.spi.user),
      child: Input(
        controller: _textController,
        type: TextInputType.visiblePassword,
        obscureText: true,
        onSubmitted: (_) => onSubmitted(),
        label: _s.pwd,
      ),
      actions: [
        TextButton(
            onPressed: () {
              context.pop();
              context.pop();
            },
            child: Text(_s.cancel)),
        TextButton(
          onPressed: () => onSubmitted(),
          child: Text(
            _s.ok,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
    return _textController.text.trim();
  }

  Widget _buildFAB(PkgProvider pkg) {
    if (pkg.isBusy || (pkg.upgradeable?.isEmpty ?? true)) {
      return placeholder;
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
