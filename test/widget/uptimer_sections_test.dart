import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/uptimer/uptimer.dart';
import 'package:server_box/data/provider/uptimer/detail.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/uptimer/detail_latency.dart';
import 'package:server_box/view/page/uptimer/detail_sections.dart';
import 'package:server_box/view/page/uptimer/detail_status.dart';
import 'package:server_box/view/page/uptimer/detail_uptime.dart';
import 'package:server_box/view/page/uptimer/edit_http_section.dart';
import 'package:server_box/view/page/uptimer/edit_sections.dart';
import 'package:server_box/view/page/uptimer/edit_validator.dart';

void main() {
  const monitor = UptimerMonitorCard(
    id: 11,
    name: 'API Gateway',
    type: UptimerMonitorType.http,
    status: UptimerMonitorStatus.up,
    displayUrl: 'https://api.example.com',
    lastLatencyMs: 42,
    uptime30d: UptimerTotals(uptimePct: 99.95, downtimeSec: 30),
    heartbeats: [
      UptimerHeartbeat(checkedAt: 1700000000, status: 'up', latencyMs: 42),
      UptimerHeartbeat(checkedAt: 1700000060, status: 'down'),
    ],
    uptimeDays: [
      UptimerDay(
        dayStartAt: 1700000000,
        totals: UptimerTotals(uptimePct: 100, downtimeSec: 0),
      ),
    ],
  );

  const config = UptimerMonitorConfig(
    id: 11,
    name: 'API Gateway',
    type: UptimerMonitorType.http,
    target: 'https://api.example.com/health',
    intervalSec: 60,
    timeoutMs: 10000,
    groupName: 'CORE',
    showOnStatusPage: true,
    httpMethod: 'GET',
  );

  const detail = UptimerDetailState(
    range: UptimerRange.d30,
    uptimeByRange: {
      UptimerRange.d30: UptimerTotals(uptimePct: 99.95, downtimeSec: 30),
    },
    latency: UptimerLatencyData(
      rangeStartAt: 1700000000,
      rangeEndAt: 1700000120,
      avgLatencyMs: 45,
      p95LatencyMs: 88,
      points: [
        UptimerHeartbeat(checkedAt: 1700000000, status: 'up', latencyMs: 42),
        UptimerHeartbeat(checkedAt: 1700000060, status: 'down'),
        UptimerHeartbeat(checkedAt: 1700000120, status: 'up', latencyMs: 50),
      ],
    ),
    outages: [
      UptimerOutage(
        id: 1,
        monitorId: 11,
        startedAt: 1700000060,
        endedAt: 1700000120,
        lastError: '502 Bad Gateway',
      ),
    ],
    lastTest: UptimerTestResult(status: 'up', latencyMs: 39, httpStatus: 200),
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: app_locale.appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            app_locale.l10n = AppLocalizations.of(context)!;
            context.setLibL10n();
            return Scaffold(body: SingleChildScrollView(child: child));
          },
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Uptimer detail section cards render status, uptime, latency, outages, config', (
    tester,
  ) async {
    expect(UptimerLatencyCard.shouldShow(monitor, detail), isTrue);

    await pump(
      tester,
      Column(
        children: [
          UptimerStatusCard(
            monitor: monitor,
            config: config,
            detail: detail,
            busy: false,
            incidents: const [],
            activeMaint: const [],
            upcomingMaint: const [],
            onTest: () {},
            onTogglePause: () {},
            onRotatePushToken: () {},
          ),
          UptimerUptimeCard(
            monitor: monitor,
            detail: detail,
            bare: true,
            onRangeSelected: (_) {},
            onRetry: () {},
          ),
          UptimerLatencyCard(
            monitor: monitor,
            detail: detail,
            onRetry: () {},
          ),
          UptimerOutagesCard(
            detail: detail,
            onRetry: () {},
            onLoadMore: () {},
          ),
          const UptimerConfigCard(cfg: config),
        ],
      ),
    );

    expect(find.text('HTTP 200', findRichText: true), findsNothing);
    expect(find.textContaining('HTTP 200'), findsOneWidget);
    expect(find.text('502 Bad Gateway'), findsOneWidget);
    expect(find.text('https://api.example.com/health'), findsWidgets);
    expect(find.textContaining('avg 45 ms'), findsOneWidget);
  });

  testWidgets('Uptimer edit sections render target, schedule, behaviour, and HTTP optional groups', (
    tester,
  ) async {
    final ctrls = UptimerEditControllers();
    addTearDown(ctrls.dispose);
    ctrls.applyConfig(config);

    await pump(
      tester,
      Column(
        children: [
          UptimerTargetSection(
            isEditing: false,
            saving: false,
            type: UptimerMonitorType.http,
            targetCtrl: ctrls.target,
            onTypeChanged: (_) {},
            onRotatePushUrl: () {},
          ),
          UptimerScheduleSection(
            type: UptimerMonitorType.http,
            minInterval: 60,
            customInterval: false,
            intervalCtrl: ctrls.interval,
            graceCtrl: ctrls.grace,
            timeoutCtrl: ctrls.timeout,
            onPresetSelected: (_) {},
            onCustomSelected: () {},
            onCustomIntervalChanged: () {},
            onFieldChanged: () {},
          ),
          UptimerBehaviourSection(
            isEditing: true,
            saving: false,
            showOnStatusPage: true,
            onShowOnStatusPageChanged: (_) {},
            isActive: true,
            onActiveChanged: (_) {},
            displayUrlCtrl: ctrls.displayUrl,
          ),
          UptimerHttpOptionalSection(
            hydratedConfig: true,
            expandHttpReq: false,
            expandHttpRule: false,
            onExpandHttpReqChanged: (_) {},
            onExpandHttpRuleChanged: (_) {},
            httpMethod: 'GET',
            onHttpMethodChanged: (_) {},
            followRedirects: true,
            onFollowRedirectsChanged: (_) {},
            headers: const {},
            onEditHeaders: () {},
            bodyCtrl: ctrls.body,
            expectedStatusCtrl: ctrls.expectedStatus,
            forbiddenStatusCtrl: ctrls.forbiddenStatus,
            keywordCtrl: ctrls.keyword,
            keywordMode: 'contains',
            onKeywordModeChanged: (_) {},
            forbiddenKeywordCtrl: ctrls.forbiddenKeyword,
            forbiddenKeywordMode: 'contains',
            onForbiddenKeywordModeChanged: (_) {},
            onValidationChanged: () {},
          ),
        ],
      ),
    );

    expect(find.text(app_locale.l10n.uptimerInterval), findsOneWidget);
    expect(find.text(app_locale.l10n.uptimerPublic), findsOneWidget);
    expect(find.text(app_locale.l10n.uptimerActive), findsOneWidget);
    expect(find.text(app_locale.l10n.uptimerHttpRequest), findsOneWidget);
  });
}
