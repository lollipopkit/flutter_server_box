import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/apt/upgrade_pkg_info.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/provider/apt.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/widget/center_loading.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';
import 'package:toolbox/view/widget/two_line_text.dart';

class AptManagePage extends StatefulWidget {
  const AptManagePage(this.spi, {Key? key}) : super(key: key);

  final ServerPrivateInfo spi;

  @override
  _AptManagePageState createState() => _AptManagePageState();
}

class _AptManagePageState extends State<AptManagePage>
    with SingleTickerProviderStateMixin {
  late MediaQueryData _media;
  final greyStyle = const TextStyle(color: Colors.grey);
  final scrollController = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
  }

  @override
  void dispose() {
    super.dispose();
    locator<AptProvider>().clear();
  }

  @override
  void initState() {
    super.initState();
    final si = locator<ServerProvider>()
        .servers
        .firstWhere((e) => e.info == widget.spi);
    if (si.client == null) {
      showSnackBar(context, const Text('Plz wait for ssh connection'));
      Navigator.of(context).pop();
      return;
    }
    locator<AptProvider>().init(
        si.client!,
        si.status.sysVer.dist,
        () =>
            scrollController.jumpTo(scrollController.position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: TwoLineText(up: 'Apt', down: widget.spi.name),
      ),
      body: Consumer<AptProvider>(builder: (_, apt, __) {
        if (apt.upgradeable == null) {
          apt.refreshInstalled();
          return centerLoading;
        }
        return ListView(
          padding: const EdgeInsets.all(13),
          children: [
            const Padding(
              padding: EdgeInsets.all(17),
              child: Text(
                'Experimental features.\nPlease report bugs on Github Issue.',
                textAlign: TextAlign.center,
              ),
            ),
            _buildUpdatePanel(apt)
          ].map((e) => RoundRectCard(e)).toList(),
        );
      }),
    );
  }

  Widget _buildUpdatePanel(AptProvider apt) {
    if (apt.upgradeable!.isEmpty) {
      return const ListTile(
        title: Text(
          'No update available',
          textAlign: TextAlign.center,
        ),
        subtitle: Text('>_<', textAlign: TextAlign.center),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExpansionTile(
          title: Text('Found ${apt.upgradeable!.length} update'),
          subtitle: Text(
            apt.upgradeable!.map((e) => e.package).join(', '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: greyStyle,
          ),
          children: apt.updateLog == null
              ? [
                  TextButton(
                      child: const Text('Update all'),
                      onPressed: () {
                        apt.upgrade();
                      }),
                  SizedBox(
                    height: _media.size.height * 0.73,
                    child: ListView(
                        children: apt.upgradeable!
                            .map((e) => _buildUpdateItem(e, apt))
                            .toList()),
                  )
                ]
              : [
                  SizedBox(
                      height: _media.size.height * 0.7,
                      child: ListView(
                        padding: const EdgeInsets.all(18),
                        controller: scrollController,
                        children: [Text(apt.updateLog!)],
                      ))
                ],
        )
      ],
    );
  }

  Widget _buildUpdateItem(UpgradePkgInfo info, AptProvider apt) {
    return ListTile(
      title: Text(info.package),
      subtitle: Text(
        '${info.nowVersion} -> ${info.newVersion}',
        style: greyStyle,
      ),
    );
  }
}
