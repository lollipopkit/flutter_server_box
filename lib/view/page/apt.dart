import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/apt/upgrade_pkg_info.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/provider/apt.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/res/url.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/widget/center_loading.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';
import 'package:toolbox/view/widget/two_line_text.dart';
import 'package:toolbox/view/widget/url_text.dart';

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
  final scrollControllerUpdate = ScrollController();
  final _aptProvider = locator<AptProvider>();
  late S s;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    s = S.of(context);
    _aptProvider.refreshInstalled();
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
      showSnackBar(context, Text(s.waitConnection));
      Navigator.of(context).pop();
      return;
    }

    // ignore: prefer_function_declarations_over_variables
    PwdRequestFunc onPwdRequest = (user) async {
      final textController = TextEditingController();
      await showRoundDialog(
          context,
          s.pwdForUser(user ?? s.unknown),
          TextField(
            controller: textController,
            decoration: InputDecoration(
              labelText: s.pwd,
            ),
          ),
          [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(s.cancel)),
            TextButton(
                onPressed: () {
                  if (textController.text == '') {
                    showRoundDialog(
                        context, s.attention, Text(s.fieldMustNotEmpty), [
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(s.ok)),
                    ]);
                    return;
                  }
                  Navigator.of(context).pop();
                },
                child: Text(
                  s.ok,
                  style: const TextStyle(color: Colors.red),
                )),
          ]);
      return textController.text.trim();
    };

    _aptProvider.init(
        si.client!,
        si.status.sysVer.dist,
        () =>
            scrollController.jumpTo(scrollController.position.maxScrollExtent),
        () => scrollControllerUpdate
            .jumpTo(scrollControllerUpdate.position.maxScrollExtent),
        onPwdRequest);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: TwoLineText(up: 'Apt', down: widget.spi.name),
      ),
      body: Consumer<AptProvider>(builder: (_, apt, __) {
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
              Text(
                apt.error!,
                textAlign: TextAlign.center,
              ),
            ],
          );
        }
        if (apt.updateLog == null && apt.upgradeable == null) {
          return centerLoading;
        }
        if (apt.updateLog != null && apt.upgradeable == null) {
          return SizedBox(
              height: _media.size.height * 0.7,
              child: ConstrainedBox(
                constraints: const BoxConstraints.expand(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  controller: scrollControllerUpdate,
                  child: Text(apt.updateLog!),
                ),
              ));
        }
        return ListView(
          padding: const EdgeInsets.all(13),
          children: [
            Padding(
              padding: const EdgeInsets.all(17),
              child: UrlText(
                text: '${s.experimentalFeature}\n${s.reportBugsOnGithubIssue(issueUrl)}',
                replace: 'Github Issue',
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
      return ListTile(
        title: Text(
          s.noUpdateAvailable,
          textAlign: TextAlign.center,
        ),
        subtitle: const Text('>_<', textAlign: TextAlign.center),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExpansionTile(
          title: Text(s.foundNUpdate(apt.upgradeable!.length)),
          subtitle: Text(
            apt.upgradeable!.map((e) => e.package).join(', '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: greyStyle,
          ),
          children: apt.upgradeLog == null
              ? [
                  TextButton(
                      child: Text(s.updateAll),
                      onPressed: () {
                        apt.upgrade();
                      }),
                  SizedBox(
                    height: _media.size.height * 0.73,
                    child: ListView(
                        controller: scrollController,
                        children: apt.upgradeable!
                            .map((e) => _buildUpdateItem(e, apt))
                            .toList()),
                  )
                ]
              : [
                  SizedBox(
                      height: _media.size.height * 0.7,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints.expand(),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(18),
                          controller: scrollController,
                          child: Text(apt.upgradeLog!),
                        ),
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
