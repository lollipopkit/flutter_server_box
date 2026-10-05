import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/container/image.dart';
import 'package:server_box/data/model/container/ps.dart';
import 'package:server_box/data/model/container/status.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/src/rust/api/container.dart' as ffi;
import 'package:server_box/view/page/container/resource_views.dart';

import '../helpers/rust_lib_helper.dart';

void main() {
  setUpAll(initRustLibForTest);

  Widget containerView(
    List<ContainerPs> items, {
    ContainerQuickActionHandler? onQuickAction,
  }) {
    return ContainerItemsView(
      items: items,
      onQuickAction: onQuickAction,
      trailingBuilder: (item) => SizedBox(
        key: ValueKey('container-trailing-${item.id}'),
        width: 32,
        height: 32,
        child: const Icon(Icons.more_vert),
      ),
    );
  }

  Widget imageView(List<ContainerImg> images) {
    return ContainerImagesView(
      images: images,
      trailingBuilder: (image) => SizedBox(
        key: ValueKey('image-trailing-${image.id}'),
        width: 32,
        height: 32,
        child: const Icon(Icons.more_vert),
      ),
    );
  }

  Widget imagePruneOptions({
    ContainerType type = ContainerType.docker,
    int danglingCount = 2,
    int? unusedTaggedCount = 1,
  }) {
    var allUnused = false;
    return StatefulBuilder(
      builder: (_, setState) {
        return ContainerImagePruneOptionsView(
          danglingCount: danglingCount,
          unusedTaggedCount: unusedTaggedCount,
          allUnused: allUnused,
          onAllUnusedChanged: (value) => setState(() => allUnused = value),
          commandPreview: ffi.containerImagePruneCommand(
            runtimeName: type.name,
            allUnused: allUnused,
          ),
        );
      },
    );
  }

  Widget systemPruneOptions({
    ContainerType type = ContainerType.docker,
  }) {
    var allUnusedImages = false;
    var includeVolumes = false;
    return StatefulBuilder(
      builder: (_, setState) {
        return ContainerSystemPruneOptionsView(
          allUnusedImages: allUnusedImages,
          includeVolumes: includeVolumes,
          onAllUnusedImagesChanged: (value) =>
              setState(() => allUnusedImages = value),
          onIncludeVolumesChanged: (value) =>
              setState(() => includeVolumes = value),
          commandPreview: ffi.containerSystemPruneCommand(
            runtimeName: type.name,
            allUnusedImages: allUnusedImages,
            includeVolumes: includeVolumes,
          ),
        );
      },
    );
  }

  testWidgets('390px renders a compact container row without overflow', (
    tester,
  ) async {
    const longName =
        'production-container-with-a-name-that-is-deliberately-long-for-mobile';
    const longImage =
        'registry.example.com/organization/team/an-extremely-long-image-name:latest';
    final item = ContainerPs(
      id: 'mobile-container',
      name: longName,
      image: longImage,
      rawStatus: 'Up 3 hours',
      status: ContainerStatus.running,
      cpu: '13.7%',
      mem: '640 MiB / 2 GiB',
      net: '12.4 MB / 8.1 MB',
      disk: '1.2 GB / 780 MB',
    );

    await _pumpAt(tester, width: 390, child: containerView([item]));

    expect(
      find.byKey(const ValueKey('container-row-mobile-container')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('container-table-row-mobile-container')),
      findsNothing,
    );
    // Narrow folds the four metrics into one line instead of giving each of
    // them a labelled cell, so there is no grid to measure here.
    expect(
      find.byKey(const ValueKey('container-metrics-mobile-container')),
      findsNothing,
    );
    final metrics = find.byKey(
      const ValueKey('container-metrics-line-mobile-container'),
    );
    expect(metrics, findsOneWidget);
    final metricsText = tester.widget<Text>(metrics).data!;
    expect(metricsText, contains('CPU 13.7%'));
    expect(metricsText, contains('Mem 31.3%'));
    expect(tester.widget<Text>(metrics).overflow, TextOverflow.ellipsis);

    expect(find.text(longName), findsOneWidget);
    expect(find.text(longImage), findsOneWidget);
    expect(find.text('3 h'), findsOneWidget);
    final status = find.byKey(
      const ValueKey('container-status-mobile-container'),
    );
    final trailing = find.byKey(
      const ValueKey('container-trailing-mobile-container'),
    );
    expect(
      tester.getCenter(status).dx,
      lessThan(tester.getCenter(trailing).dx),
    );
    expect(
      tester.widget<Text>(find.text(longName)).overflow,
      TextOverflow.ellipsis,
    );
    expect(
      tester.widget<Text>(find.text(longImage)).overflow,
      TextOverflow.ellipsis,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('stopped container shows the original status at 390px', (
    tester,
  ) async {
    final item = ContainerPs(
      id: 'stopped-container',
      name: 'alpine-test',
      image: 'docker.io/library/alpine:latest',
      rawStatus: 'Exited (0) 7 seconds ago',
      status: ContainerStatus.exited,
    );

    await _pumpAt(tester, width: 390, child: containerView([item]));

    // The lifecycle text is split: the time goes to the Uptime column and
    // what happened stays beside the name.
    final status = find.text('7 s ago');
    expect(status, findsOneWidget);
    expect(tester.widget<Text>(status).maxLines, 1);
    expect(
      tester.getCenter(status).dx,
      lessThan(
        tester.getCenter(
          find.byKey(
            const ValueKey('container-trailing-stopped-container'),
          ),
        ).dx,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown container state is not summarized as stopped', (
    tester,
  ) async {
    // Counted in the group header: the runtime-wide summary is built by the
    // page now, so this view only totals a compose project.
    final items = [
      ContainerPs(
        id: 'unknown-container',
        name: 'worker',
        rawStatus: 'Unexpected state',
        status: ContainerStatus.unknown,
        project: 'stack',
      ),
      ContainerPs(
        id: 'running-container',
        name: 'api',
        image: 'example/api:latest',
        rawStatus: 'Up 2 minutes',
        status: ContainerStatus.running,
        project: 'stack',
      ),
    ];

    await _pumpAt(tester, width: 390, child: containerView(items));

    expect(find.text('1 Running · 1 Unknown'), findsOneWidget);
    expect(find.textContaining('Stopped'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1280px renders the wide container resource card', (
    tester,
  ) async {
    final item = ContainerPs(
      id: 'desktop-container',
      name: 'api',
      image: 'example/api:stable',
      rawStatus: 'Up 12 minutes',
      status: ContainerStatus.running,
      cpu: '2.5%',
      mem: '128 MiB / 1 GiB',
      net: '4 MB / 2 MB',
      disk: '20 MB / 5 MB',
    );

    await _pumpAt(tester, width: 1280, child: containerView([item]));

    expect(
      find.byKey(const ValueKey('container-table-row-desktop-container')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('container-row-desktop-container')),
      findsNothing,
    );
    for (final label in ['CPU', 'Mem', 'Net ↓ / ↑', 'Disk R / W']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    expect(find.text('2.5%'), findsOneWidget);
    expect(find.text('12.5%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing or unparseable container stats are omitted', (
    tester,
  ) async {
    final item = ContainerPs(
      id: 'partial-stats',
      name: 'worker',
      image: 'example/worker:latest',
      rawStatus: 'Up 4 minutes',
      status: ContainerStatus.running,
      cpu: '4.2%',
      mem: 'not available',
      net: 'not available / garbage',
      disk: 'garbage / not available',
    );

    await _pumpAt(tester, width: 1280, child: containerView([item]));

    expect(find.text('4.2%'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('container-metric-partial-stats-memory')),
        matching: find.text('—'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('container-metric-partial-stats-disk')),
        matching: find.text('—'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('container-metric-partial-stats-network')),
        matching: find.text('—'),
      ),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('partial or trailing-garbage metrics are omitted', (
    tester,
  ) async {
    final item = ContainerPs(
      id: 'malformed-stats',
      name: 'worker',
      image: 'example/worker:latest',
      rawStatus: 'Up 4 minutes',
      status: ContainerStatus.running,
      cpu: '12.5% garbage',
      mem: '640 MiB junk / 2 GiB',
      net: '12 MB / garbage',
      disk: '1 GB / -2 MB',
    );

    await _pumpAt(tester, width: 1280, child: containerView([item]));

    expect(
      find.byKey(
        const ValueKey('container-metrics-malformed-stats'),
      ),
      findsNothing,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('provider-valid averaged CPU metrics remain visible', (
    tester,
  ) async {
    final item = ContainerPs(
      id: 'averaged-cpu',
      name: 'worker',
      rawStatus: 'Up 4 minutes',
      status: ContainerStatus.running,
      cpu: '12.5% / Avg 3.0%',
    );

    await _pumpAt(tester, width: 1280, child: containerView([item]));

    expect(
      find.byKey(
        const ValueKey('container-metric-averaged-cpu-cpu'),
      ),
      findsOneWidget,
    );
    expect(find.text('12.5%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('negative container stats are omitted', (tester) async {
    final cases = [
      (
        id: 'negative-cpu',
        cpu: '-5%',
        mem: '1 GiB / 2 GiB',
        net: '1 MiB / 2 MiB',
        disk: '3 MiB / 4 MiB',
        missingKey: 'container-metric-negative-cpu-cpu',
      ),
      (
        id: 'negative-memory',
        cpu: '5%',
        mem: '-1 GiB / 2 GiB',
        net: '1 MiB / 2 MiB',
        disk: '3 MiB / 4 MiB',
        missingKey: 'container-metric-negative-memory-memory',
      ),
      (
        id: 'negative-network',
        cpu: '5%',
        mem: '1 GiB / 2 GiB',
        net: '-1 MiB / 2 MiB',
        disk: '3 MiB / 4 MiB',
        missingKey: 'container-metric-negative-network-network',
      ),
      (
        id: 'negative-disk',
        cpu: '5%',
        mem: '1 GiB / 2 GiB',
        net: '1 MiB / 2 MiB',
        disk: '-3 MiB / 4 MiB',
        missingKey: 'container-metric-negative-disk-disk',
      ),
    ];

    for (final data in cases) {
      final item = ContainerPs(
        id: data.id,
        name: 'worker',
        image: 'example/worker:latest',
        rawStatus: 'Up 4 minutes',
        status: ContainerStatus.running,
        cpu: data.cpu,
        mem: data.mem,
        net: data.net,
        disk: data.disk,
      );

      await _pumpAt(tester, width: 1280, child: containerView([item]));

      // Every column is drawn; the unreadable one is a dash.
      for (final key in [
        'container-metric-${data.id}-cpu',
        'container-metric-${data.id}-memory',
        'container-metric-${data.id}-network',
        'container-metric-${data.id}-disk',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.text('—'),
          ),
          key == data.missingKey ? findsOneWidget : findsNothing,
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('resource percentages above 100 are clamped consistently', (
    tester,
  ) async {
    final item = ContainerPs(
      id: 'clamped-stats',
      name: 'worker',
      image: 'example/worker:latest',
      rawStatus: 'Up 4 minutes',
      status: ContainerStatus.running,
      cpu: '150%',
      mem: '3 GiB / 2 GiB',
    );

    await _pumpAt(tester, width: 1280, child: containerView([item]));

    expect(find.text('100.0%'), findsNWidgets(2));
    expect(find.text('150.0%'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('image rows switch from compact at 390px to wide at 900px', (
    tester,
  ) async {
    final image = ContainerImg(
      containers: 1,
      createdAt: '2026-08-08 09:30:00 +0800 CST',
      id: 'sha256:image-switch',
      repository: 'example/web',
      size: '86.4 MB',
      tag: 'latest',
    );

    await _pumpAt(tester, width: 390, child: imageView([image]));
    expect(
      find.byKey(
        const ValueKey('image-row-compact-0-sha256:image-switch'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('image-row-wide-0-sha256:image-switch')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('image-table-header')), findsNothing);
    // Narrow has no column for the age, so it folds onto the id's line.
    expect(find.textContaining(image.createdAt!), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpAt(tester, width: 900, child: imageView([image]));
    expect(
      find.byKey(const ValueKey('image-row-wide-0-sha256:image-switch')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('image-row-compact-0-sha256:image-switch'),
      ),
      findsNothing,
    );
    // Wide gives it a column of its own, under a header.
    expect(find.byKey(const ValueKey('image-table-header')), findsOneWidget);
    expect(find.text(image.createdAt!), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long image references are ellipsized on a compact row', (
    tester,
  ) async {
    const repository =
        'registry.example.com/a-very-long-organization/a-very-long-project/image';
    final image = ContainerImg(
      containers: 1,
      createdAt: '2026-08-08 09:30:00 +0800 CST',
      id: 'sha256:long-image',
      repository: repository,
      size: '1024.8 MB',
      tag: 'a-very-long-release-tag-for-the-mobile-layout',
    );
    const reference =
        '$repository:a-very-long-release-tag-for-the-mobile-layout';

    await _pumpAt(tester, width: 390, child: imageView([image]));

    expect(find.text(reference), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(reference)).overflow,
      TextOverflow.ellipsis,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('fallback row identifiers remain unique', (tester) async {
    await _pumpAt(
      tester,
      width: 390,
      child: imageView([
        ContainerImg(
  dangling: true,
  unused: true,
),
        ContainerImg(
  dangling: true,
  unused: true,
),
      ]),
    );

    expect(
      find.byKey(const ValueKey('image-row-compact-0-<none>')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('image-row-compact-1-<none>')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('large image lists build only visible rows', (tester) async {
    final images = List.generate(
      200,
      (index) => ContainerImg(
        containers: 1,
        createdAt: 'today',
        id: 'image-$index',
        repository: 'example/image-$index',
        size: '10 MB',
        tag: 'latest',
      ),
    );

    await _pumpAt(tester, width: 390, child: imageView(images));

    expect(find.byIcon(Icons.more_vert).evaluate().length, lessThan(200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compose groups are open by default and can be folded', (
    tester,
  ) async {
    final items = [
      ContainerPs(
        id: 'compose-web',
        name: 'web',
        image: 'example/web:latest',
        rawStatus: 'Up 8 minutes',
        status: ContainerStatus.running,
        project: 'production-stack',
      ),
      ContainerPs(
        id: 'compose-db',
        name: 'db',
        image: 'postgres:17',
        rawStatus: 'Exited (0) 2 minutes ago',
        status: ContainerStatus.exited,
        project: 'production-stack',
      ),
    ];

    await _pumpAt(tester, width: 900, child: containerView(items));

    expect(find.text('production-stack'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
    expect(find.text('1 Running · 1 Stopped'), findsOneWidget);
    expect(find.text('web'), findsOneWidget);
    expect(find.text('db'), findsOneWidget);

    final arrow = find.byKey(
      const ValueKey('container-group-arrow-production-stack'),
    );
    expect(arrow, findsOneWidget);
    expect(tester.widget<AnimatedRotation>(arrow).turns, 0);

    await tester.tap(
      find.byKey(
        const ValueKey('container-group-header-production-stack'),
      ),
    );
    await tester.pumpAndSettle();

    // The rows stay in the tree so the fold can animate in both directions;
    // what changes is the height they are given.
    final folded = find
        .ancestor(of: find.text('web'), matching: find.byType(ClipRect))
        .first;
    expect(tester.getSize(folded).height, 0);
    expect(tester.widget<AnimatedRotation>(arrow).turns, 0.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('standalone containers remain visible beside compose groups', (
    tester,
  ) async {
    final items = [
      ContainerPs(
        id: 'compose-web',
        name: 'web',
        image: 'example/web:latest',
        rawStatus: 'Up 8 minutes',
        status: ContainerStatus.running,
        project: 'production-stack',
      ),
      ContainerPs(
        id: 'standalone-worker',
        name: 'worker',
        image: 'example/worker:latest',
        rawStatus: 'Up 3 minutes',
        status: ContainerStatus.running,
      ),
    ];

    await _pumpAt(tester, width: 390, child: containerView(items));

    expect(find.text('web'), findsOneWidget);
    expect(find.text('worker'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('container-group-arrow-Other')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('containers keep deterministic ordering after input reordering', (
    tester,
  ) async {
    final alpha = ContainerPs(
      id: 'container-alpha',
      name: 'Alpha',
      image: 'example/alpha:latest',
      rawStatus: 'Up 3 minutes',
      status: ContainerStatus.running,
    );
    final zeta = ContainerPs(
      id: 'container-zeta',
      name: 'zeta',
      image: 'example/zeta:latest',
      rawStatus: 'Up 3 minutes',
      status: ContainerStatus.running,
    );

    for (final items in [
      [zeta, alpha],
      [alpha, zeta],
    ]) {
      await _pumpAt(tester, width: 390, child: containerView(items));

      expect(
        tester.getTopLeft(find.text('Alpha')).dy,
        lessThan(tester.getTopLeft(find.text('zeta')).dy),
      );
      expect(
        find.byKey(
          const ValueKey('container-row-container-alpha'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('dangling and unused image badges are both visible', (
    tester,
  ) async {
    final images = [
      ContainerImg(
        containers: 0,
        createdAt: '2026-08-01',
        id: 'sha256:dangling',
        repository: '<none>',
        size: '12 MB',
        tag: '<none>',
        dangling: true,
        unused: true,
      ),
      ContainerImg(
        containers: 0,
        createdAt: '2026-08-02',
        id: 'sha256:unused',
        repository: 'example/worker',
        size: '64 MB',
        tag: 'old',
        unused: true,
      ),
    ];

    await _pumpAt(tester, width: 900, child: imageView(images));

    // Per-image badges only. The unused total moved to the page's summary
    // card, which is above the tabs rather than inside this view.
    expect(find.text('Dangling'), findsOneWidget);
    expect(find.text('Unused'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the runtime header folds its totals instead of wrapping', (
    tester,
  ) async {
    Widget header() => ContainerRuntimeHeader(
      type: ContainerType.docker,
      version: '27.1.1',
      summary: '3 Running · 1 Stopped · 12 Image · 809 MB Reclaimable',
      compactSummary: '27.1.1 · 3 Running · 1 Stopped',
      selector: (expand) => Text('selector expand=$expand'),
    );

    await _pumpAt(tester, width: 1280, child: header());
    expect(find.text('Docker'), findsOneWidget);
    expect(find.text('27.1.1'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('container-runtime-summary')),
          )
          .data,
      '3 Running · 1 Stopped · 12 Image · 809 MB Reclaimable',
    );
    // Inline: the selector shares the line with the totals and sizes to its
    // own labels.
    expect(find.text('selector expand=false'), findsOneWidget);
    expect(
      tester.getTopLeft(find.textContaining('selector')).dy,
      closeTo(tester.getTopLeft(find.text('Docker')).dy, 6),
    );
    expect(tester.takeException(), isNull);

    await _pumpAt(tester, width: 390, child: header());
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('container-runtime-summary')),
          )
          .data,
      '27.1.1 · 3 Running · 1 Stopped',
    );
    // Folded: the selector drops to its own row and spreads across it.
    expect(find.text('selector expand=true'), findsOneWidget);
    expect(
      tester.getTopLeft(find.textContaining('selector')).dy,
      greaterThan(tester.getTopLeft(find.text('Docker')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('image prune options show counts and update command at 390px', (
    tester,
  ) async {
    await _pumpAt(
      tester,
      width: 390,
      child: SingleChildScrollView(child: imagePruneOptions()),
    );

    expect(find.text('Dangling: 2'), findsOneWidget);
    expect(find.text('Unused tagged: 1'), findsOneWidget);
    expect(find.text('docker image prune -f'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(
      tester.widget<ListTile>(
        find.descendant(
          of: find.byKey(const ValueKey('image-prune-dangling-option')),
          matching: find.byType(ListTile),
        ),
      ).selected,
      true,
    );

    await tester.tap(
      find.byKey(const ValueKey('image-prune-all-unused-option')),
    );
    await tester.pump();

    expect(find.text('docker image prune -a -f'), findsOneWidget);
    expect(
      tester.widget<ListTile>(
        find.descendant(
          of: find.byKey(const ValueKey('image-prune-all-unused-option')),
          matching: find.byType(ListTile),
        ),
      ).selected,
      true,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('image prune options show unknown usage count', (tester) async {
    await _pumpAt(
      tester,
      width: 390,
      child: SingleChildScrollView(
        child: imagePruneOptions(unusedTaggedCount: null),
      ),
    );

    expect(find.text('Unused tagged: Unknown'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long running command log is internally scrollable', (
    tester,
  ) async {
    final log = List.generate(
      80,
      (index) => 'Step ${index + 1}: processing container resources',
    ).join('\n');

    await _pumpAt(
      tester,
      width: 390,
      settle: false,
      child: Column(
        children: [
          ContainerRunLogView(log: log),
          const Expanded(child: SizedBox()),
        ],
      ),
    );

    final scroll = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('container-run-log-scroll')),
    );
    expect(scroll.reverse, true);
    final scrollSize = tester.getSize(
      find.byKey(const ValueKey('container-run-log-scroll')),
    );
    expect(
      scrollSize.height,
      lessThanOrEqualTo(160),
    );
    expect(
      tester.getSize(find.byType(ContainerRunLogView)).height,
      lessThan(250),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('system prune switches update a Podman command without overflow', (
    tester,
  ) async {
    await _pumpAt(
      tester,
      width: 390,
      child: SingleChildScrollView(
        child: systemPruneOptions(type: ContainerType.podman),
      ),
    );

    expect(find.text('podman system prune -f'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('system-prune-all-images-switch')),
    );
    await tester.pump();
    expect(find.text('podman system prune -a -f'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('system-prune-volumes-switch')),
    );
    await tester.pump();
    expect(
      find.text('podman system prune -a --volumes -f'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpAt(
  WidgetTester tester, {
  required double width,
  required Widget child,
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      builder: ResponsivePoints.builder,
      locale: const Locale('en'),
      localizationsDelegates: const [
        ...app_locale.appLocalizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          app_locale.l10n = AppLocalizations.of(context)!;
          context.setLibL10n();
          return Scaffold(body: child);
        },
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
