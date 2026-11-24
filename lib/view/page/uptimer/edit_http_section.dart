import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/view/page/uptimer/edit_validator.dart';
import 'package:server_box/view/widget/group_title.dart';

/// Optional HTTP request & response validation expandables for
/// [UptimerEditPage].
final class UptimerHttpOptionalSection extends StatelessWidget {
  final bool hydratedConfig;
  final bool expandHttpReq;
  final bool expandHttpRule;
  final ValueChanged<bool> onExpandHttpReqChanged;
  final ValueChanged<bool> onExpandHttpRuleChanged;
  final String httpMethod;
  final ValueChanged<String> onHttpMethodChanged;
  final bool followRedirects;
  final ValueChanged<bool> onFollowRedirectsChanged;
  final VoidCallback onToggleFollowRedirects;
  final Map<String, String> headers;
  final VoidCallback onEditHeaders;
  final TextEditingController bodyCtrl;
  final TextEditingController expectedStatusCtrl;
  final TextEditingController forbiddenStatusCtrl;
  final TextEditingController keywordCtrl;
  final String keywordMode;
  final ValueChanged<String> onKeywordModeChanged;
  final TextEditingController forbiddenKeywordCtrl;
  final String forbiddenKeywordMode;
  final ValueChanged<String> onForbiddenKeywordModeChanged;
  final VoidCallback onValidationChanged;

  const UptimerHttpOptionalSection({
    super.key,
    required this.hydratedConfig,
    required this.expandHttpReq,
    required this.expandHttpRule,
    required this.onExpandHttpReqChanged,
    required this.onExpandHttpRuleChanged,
    required this.httpMethod,
    required this.onHttpMethodChanged,
    required this.followRedirects,
    required this.onFollowRedirectsChanged,
    required this.onToggleFollowRedirects,
    required this.headers,
    required this.onEditHeaders,
    required this.bodyCtrl,
    required this.expectedStatusCtrl,
    required this.forbiddenStatusCtrl,
    required this.keywordCtrl,
    required this.keywordMode,
    required this.onKeywordModeChanged,
    required this.forbiddenKeywordCtrl,
    required this.forbiddenKeywordMode,
    required this.onForbiddenKeywordModeChanged,
    required this.onValidationChanged,
  });

  String _httpRequestSummary() {
    final parts = <String>[httpMethod];
    if (followRedirects) parts.add(l10n.uptimerFollowRedirects);
    if (headers.isNotEmpty) parts.add('${headers.length}');
    return parts.join(' · ');
  }

  String _httpValidationSummary() {
    final parts = <String>[];
    final exp = expectedStatusCtrl.text.trim();
    final forb = forbiddenStatusCtrl.text.trim();
    final kw = keywordCtrl.text.trim();
    final fkw = forbiddenKeywordCtrl.text.trim();
    if (exp.isNotEmpty) parts.add(exp);
    if (forb.isNotEmpty) parts.add('!$forb');
    if (kw.isNotEmpty || fkw.isNotEmpty) parts.add(l10n.uptimerKeyword);
    return parts.isEmpty ? libL10n.empty : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupTitle(l10n.optional),
        ExpandableTile(
          key: ValueKey('http_req_$hydratedConfig'),
          initiallyExpanded: expandHttpReq,
          onExpansionChanged: onExpandHttpReqChanged,
          leading: const Icon(Icons.tune),
          title: Text(l10n.uptimerHttpRequest),
          summary: Text(_httpRequestSummary()),
          children: [
            ListTile(
              leading: const Icon(Icons.http),
              title: Text(l10n.uptimerMethod),
              trailing: ContextMenuButton(
                actions: () => [
                  for (final m in kUptimerHttpMethods)
                    ContextMenuAction(
                      text: m,
                      checked: httpMethod == m,
                      onTap: () => onHttpMethodChanged(m),
                    ),
                ],
                child: ContextMenuButton.value(Text(httpMethod)),
              ),
            ).cardx,
            ListTile(
              leading: const Icon(Icons.redo),
              title: Text(l10n.uptimerFollowRedirects),
              trailing: SwitchX(
                value: followRedirects,
                onChanged: onFollowRedirectsChanged,
              ),
              onTap: onToggleFollowRedirects,
            ).cardx,
            ListTile(
              leading: const Icon(Icons.code),
              title: Text(l10n.uptimerHeaders),
              subtitle: Text(
                headers.isEmpty
                    ? libL10n.empty
                    : '${headers.length} ${libL10n.configured}',
                style: UIs.textGrey,
              ),
              trailing: const Icon(Icons.keyboard_arrow_right),
              onTap: onEditHeaders,
            ).cardx,
            if (httpMethod != 'GET' && httpMethod != 'HEAD')
              Input(
                controller: bodyCtrl,
                label: l10n.uptimerBody,
                icon: Icons.data_object,
                maxLines: 3,
                autoCorrect: false,
                suggestion: false,
              ),
          ],
        ),
        ExpandableTile(
          key: ValueKey('http_rule_$hydratedConfig'),
          initiallyExpanded: expandHttpRule,
          onExpansionChanged: onExpandHttpRuleChanged,
          leading: const Icon(Icons.fact_check_outlined),
          title: Text(l10n.uptimerResponseValidation),
          summary: Text(_httpValidationSummary()),
          children: [
            Input(
              controller: expectedStatusCtrl,
              label: l10n.uptimerExpectedStatus,
              hint: '200, 201-204',
              icon: Icons.check_circle_outline,
              autoCorrect: false,
              suggestion: false,
              onChanged: (_) => onValidationChanged(),
            ),
            Input(
              controller: forbiddenStatusCtrl,
              label: l10n.uptimerForbiddenStatus,
              hint: '500-599',
              icon: Icons.block_outlined,
              autoCorrect: false,
              suggestion: false,
              onChanged: (_) => onValidationChanged(),
            ),
            Input(
              controller: keywordCtrl,
              label: l10n.uptimerKeyword,
              icon: Icons.search,
              autoCorrect: false,
              suggestion: false,
              onChanged: (_) => onValidationChanged(),
              suffix: _buildMatchModeButton(
                value: keywordMode,
                onChanged: onKeywordModeChanged,
              ),
            ),
            Input(
              controller: forbiddenKeywordCtrl,
              label: l10n.uptimerForbiddenKeyword,
              icon: Icons.do_not_disturb_on_outlined,
              autoCorrect: false,
              suggestion: false,
              onChanged: (_) => onValidationChanged(),
              suffix: _buildMatchModeButton(
                value: forbiddenKeywordMode,
                onChanged: onForbiddenKeywordModeChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMatchModeButton({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final label = value == 'regex'
        ? l10n.uptimerMatchRegex
        : l10n.uptimerMatchContains;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 112),
      child: ContextMenuButton(
        actions: () => [
          ContextMenuAction(
            text: l10n.uptimerMatchContains,
            checked: value != 'regex',
            onTap: () => onChanged('contains'),
          ),
          ContextMenuAction(
            text: l10n.uptimerMatchRegex,
            checked: value == 'regex',
            onTap: () => onChanged('regex'),
          ),
        ],
        child: ContextMenuButton.value(
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}
