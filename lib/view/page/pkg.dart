import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/model/pkg/upgrade_info.dart';
import '../../data/model/server/dist.dart';
import '../../core/utils/ui.dart';
import '../../data/model/server/server_private_info.dart';
import '../../data/provider/pkg.dart';
import '../../data/provider/server.dart';
import '../../data/res/font_style.dart';
import '../../generated/l10n.dart';
import '../../locator.dart';
import '../widget/center_loading.dart';
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
  final _aptProvider = locator<PkgProvider>();
  late S _s;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _s = S.of(context);
  }

  @override
  void dispose() {
    super.dispose();
    locator<PkgProvider>().clear();
  }

  @override
  void initState() {
    super.initState();
    final si = locator<ServerProvider>()
        .servers
        .firstWhere((e) => e.spi == widget.spi);
    if (si.client == null) {
      showSnackBar(context, Text(_s.waitConnection));
      Navigator.of(context).pop();
      return;
    }

    _aptProvider.init(
      si.client!,
      si.status.sysVer.dist,
      () =>
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent),
      () => _scrollControllerUpdate
          .jumpTo(_scrollController.position.maxScrollExtent),
      onPwdRequest,
      widget.spi.user,
    );
    _aptProvider.refresh();
  }

  void onSubmitted() {
    if (_textController.text == '') {
      showRoundDialog(
        context,
        _s.attention,
        Text(_s.fieldMustNotEmpty),
        [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_s.ok),
          ),
        ],
      );
      return;
    }
    Navigator.of(context).pop();
  }

  Future<String> onPwdRequest() async {
    if (!mounted) return '';
    await showRoundDialog(
      context,
      widget.spi.user,
      TextField(
        controller: _textController,
        keyboardType: TextInputType.visiblePassword,
        obscureText: true,
        onSubmitted: (_) => onSubmitted(),
        decoration: InputDecoration(
          labelText: _s.pwd,
        ),
      ),
      [
        TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: TwoLineText(up: 'Apt', down: widget.spi.name),
      ),
      body: Consumer<PkgProvider>(builder: (_, apt, __) {
        if (apt.error != null) {
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
              SizedBox(
                height: _media.size.height * 0.4,
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: RoundRectCard(
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(17),
                      child: Text(
                        apt.error!,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        if (apt.updateLog == null && apt.upgradeable == null) {
          return centerLoading;
        }
        if (apt.updateLog != null && apt.upgradeable == null) {
          return SizedBox(
            height:
                _media.size.height - _media.padding.top - _media.padding.bottom,
            child: ConstrainedBox(
              constraints: const BoxConstraints.expand(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                controller: _scrollControllerUpdate,
                child: Text(apt.updateLog!),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(13),
          children:
              [_buildUpdatePanel(apt)].map((e) => RoundRectCard(e)).toList(),
        );
      }),
    );
  }

  Widget _buildUpdatePanel(PkgProvider apt) {
    if (apt.upgradeable!.isEmpty) {
      return ListTile(
        title: Text(
          _s.noUpdateAvailable,
          textAlign: TextAlign.center,
        ),
        subtitle: const Text('>_<', textAlign: TextAlign.center),
      );
    }
    return ExpansionTile(
      title: Text(_s.foundNUpdate(apt.upgradeable!.length)),
      subtitle: Text(
        apt.upgradeable!.map((e) => e.package).join(', '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: grey,
      ),
      children: apt.upgradeLog == null
          ? [
              TextButton(
                child: Text(_s.updateAll),
                onPressed: () {
                  apt.upgrade();
                },
              ),
              ...apt.upgradeable!.map((e) => _buildUpdateItem(e, apt)).toList()
            ]
          : [
              SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                controller: _scrollController,
                child: Text(apt.upgradeLog!),
              )
            ],
    );
  }

  Widget _buildUpdateItem(UpgradePkgInfo info, PkgProvider apt) {
    return ListTile(
      title: Text(info.package),
      subtitle: Text(
        '${info.nowVersion} -> ${info.newVersion}',
        style: grey,
      ),
    );
  }
}
