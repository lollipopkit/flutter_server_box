part of 'entry.dart';

final class _AppAboutPage extends StatefulWidget {
  const _AppAboutPage();

  @override
  State<_AppAboutPage> createState() => _AppAboutPageState();
}

final class _AppAboutPageState extends State<_AppAboutPage>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(13),
      children: [
        UIs.height13,
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 47, maxWidth: 47),
          child: UIs.appIcon,
        ),
        const Text(
          '${BuildData.name}\nv${BuildData.build}',
          textAlign: TextAlign.center,
          style: UIs.text15,
        ),
        UIs.height13,
        SizedBox(
          height: 77,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 7),
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              Btn.elevated(
                icon: const Icon(Icons.edit_document),
                text: 'Wiki',
                onTap: Urls.appWiki.launchUrl,
              ),
              Btn.elevated(
                icon: const Icon(Icons.feedback),
                text: libL10n.feedback,
                onTap: Urls.appHelp.launchUrl,
              ),
              Btn.elevated(
                icon: const Icon(MingCute.question_fill),
                text: l10n.license,
                onTap: () => showLicensePage(context: context),
              ),
            ].joinWith(UIs.width13),
          ),
        ),
        UIs.height13,
        SimpleMarkdown(
          data: '''
#### Contributors
${GithubIds.contributors.map((e) => '[$e](${e.url})').join(' ')}

#### Participants
${GithubIds.participants.map((e) => '[$e](${e.url})').join(' ')}

#### My other apps
[GPT Box](https://github.com/lollipopkit/flutter_gpt_box)

${l10n.madeWithLove('[lollipopkit](${Urls.myGithub})')}
''',
        ).paddingAll(13).cardx,
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
