import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/apt/upgrade_pkg_info.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/provider/apt.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/locator.dart';
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
    locator<AptProvider>().init(si.client!, si.status.sysVer.dist);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TwoLineText(up: 'Apt', down: widget.spi.ip),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              locator<AptProvider>().refreshInstalled();
            },
          ),
        ],
      ),
      body: Consumer<AptProvider>(builder: (_, apt, __) {
        if (apt.upgradeable == null) {
          apt.refreshInstalled();
        }
        return ListView(
          padding: const EdgeInsets.all(13),
          children: [_buildUpdatePanel(apt)],
        );
      }),
    );
  }

  Widget _buildUpdatePanel(AptProvider apt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RoundRectCard(ExpansionTile(
          title: Text(!apt.isReady
              ? 'Loading...'
              : 'Found ${apt.upgradeable!.length} update'),
          subtitle: !apt.isReady
              ? null
              : Text(
                  apt.upgradeable!.map((e) => e.package).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: greyStyle,
                ),
          children: [
            // TextButton(
            //     child: Text('Update all'),
            //     onPressed: () {
            //       apt.upgrade();
            //     }),
            !apt.isReady
                ? const SizedBox()
                : SizedBox(
                    height: _media.size.height * 0.23,
                    child: ListView(
                        children: apt.upgradeable!
                            .map((e) => _buildUpdateItem(e, apt))
                            .toList()),
                  )
          ],
        ))
      ],
    );
  }

  Widget _buildUpdateItem(AptUpgradePkgInfo info, AptProvider apt) {
    return ListTile(
      title: Text(info.package),
      subtitle: Text(
        '${info.nowVersion} -> ${info.newVersion}',
        style: greyStyle,
      ),
    );
  }
}
