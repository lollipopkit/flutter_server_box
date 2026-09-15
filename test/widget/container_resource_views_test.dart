import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/container/image.dart';
import 'package:server_box/data/model/container/ps.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/provider/container.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/container/resource_views.dart';
import 'package:server_box/view/widget/percent_circle.dart';

void main() {
  Widget containerView(
    List<ContainerPs> items, {
    VoidCallback? onPrune,
    VoidCallback? onRefresh,
  }) {
    return ContainerItemsView(
      items: items,
      type: ContainerType.docker,
      version: '27.1.1',
      summaryAction: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const ValueKey('test-prune-containers'),
            tooltip: 'Prune containers',
            onPressed: onPrune ?? () {},
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
          IconButton(
            key: const ValueKey('test-refresh-containers'),
            tooltip: 'Refresh containers',
            onPressed: onRefresh ?? () {},
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      trailingBuilder: (item) => SizedBox(
        key: ValueKey('container-trailing-${item.id}'),
        width: 32,
        height: 32,
        child: const Icon(Icons.more_vert),
      ),
      groupTrailingBuilder: (_) => null,
    );
  }

  Widget imageView(
    List<ContainerImg> images, {
    VoidCallback? onPrune,
    VoidCallback? onRefresh,
  }) {
    return ContainerImagesView(
      images: images,
      type: ContainerType.docker,
      version: '27.1.1',
      summaryAction: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const ValueKey('test-prune-images'),
            tooltip: 'Prune images',
            onPressed: onPrune ?? () {},
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
          IconButton(
            key: const ValueKey('test-refresh-images'),
            tooltip: 'Refresh images',
            onPressed: onRefresh ?? () {},
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
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
          commandPreview:
              '${type.name} '
              '${buildContainerImagePruneCmd(allUnused: allUnused)}',
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
          commandPreview:
              '${type.name} '
              '${buildContainerSystemPruneCmd(
                allUnusedImages: allUnusedImages,
                includeVolumes: includeVolumes,
              )}',
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
    final item = DockerPs(
      id: 'mobile-container',
      names: longName,
      image: longImage,
      state: 'Up 3 hours',
    )
      ..cpu = '13.7%'
      ..mem = '640 MiB / 2 GiB'
      ..net = '12.4 MB / 8.1 MB'
      ..disk = '1.2 GB / 780 MB';

    await _pumpAt(tester, width: 390, child: containerView([item]));

    expect(
      find.byKey(const ValueKey('container-row-compact-0-mobile-container')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('container-row-wide-0-mobile-container')),
      findsNothing,
    );
    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('MEM'), findsOneWidget);
    expect(find.byType(PercentCircle), findsNWidgets(2));
    expect(
      find.byKey(
        const ValueKey('container-resource-module-mobile-container-disk'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('container-resource-module-mobile-container-network'),
      ),
      findsOneWidget,
    );
    expect(find.text('31.3%'), findsOneWidget);

    final panelCenter = tester.getCenter(
      find.byKey(
        const ValueKey('container-resource-panel-mobile-container'),
      ),
    );
    final slotCenters = [
      'container-resource-circle-mobile-container-cpu',
      'container-resource-circle-mobile-container-memory',
      'container-resource-module-mobile-container-network',
      'container-resource-module-mobile-container-disk',
    ]
        .map((key) => tester.getCenter(find.byKey(ValueKey(key))))
        .toList(growable: false);
    final firstGap = slotCenters[1].dx - slotCenters[0].dx;
    expect(slotCenters[2].dx - slotCenters[1].dx, closeTo(firstGap, 0.1));
    expect(slotCenters[3].dx - slotCenters[2].dx, closeTo(firstGap, 0.1));
    expect(
      (slotCenters.first.dx + slotCenters.last.dx) / 2,
      closeTo(panelCenter.dx, 0.1),
    );

    final labelTop = tester.getTopLeft(find.text('CPU')).dy;
    for (final label in ['MEM', 'NET', 'DISK']) {
      expect(tester.getTopLeft(find.text(label)).dy, closeTo(labelTop, 0.1));
    }
    expect(find.text(longName), findsOneWidget);
    expect(find.text(longImage), findsOneWidget);
    expect(find.text('Up 3 hours'), findsOneWidget);
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
    final item = DockerPs(
      id: 'stopped-container',
      names: 'alpine-test',
      image: 'docker.io/library/alpine:latest',
      state: 'Exited (0) 7 seconds ago',
    );

    await _pumpAt(tester, width: 390, child: containerView([item]));

    final status = find.text('Exited (0) 7 seconds ago');
    expect(status, findsOneWidget);
    expect(tester.widget<Text>(status).maxLines, 2);
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
    final item = PodmanPs(
      id: 'unknown-container',
      names: ['worker'],
      rawStatus: 'Unexpected state',
    );

    await _pumpAt(tester, width: 390, child: containerView([item]));

    expect(find.text('1 Unknown'), findsOneWidget);
    expect(find.text('1 Stopped'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1280px renders the wide container resource card', (
    tester,
  ) async {
    final item = DockerPs(
      id: 'desktop-container',
      names: 'api',
      image: 'example/api:stable',
      state: 'Up 12 minutes',
    )
      ..cpu = '2.5%'
      ..mem = '128 MiB / 1 GiB'
      ..net = '4 MB / 2 MB'
      ..disk = '20 MB / 5 MB';

    await _pumpAt(tester, width: 1280, child: containerView([item]));

    expect(
      find.byKey(const ValueKey('container-row-wide-0-desktop-container')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('container-row-compact-0-desktop-container')),
      findsNothing,
    );
    for (final label in ['CPU', 'MEM', 'NET', 'DISK']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(PercentCircle), findsNWidgets(2));
    expect(find.text('2.5%'), findsOneWidget);
    expect(find.text('12.5%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing or unparseable container stats are omitted', (
    tester,
  ) async {
    final item = DockerPs(
      id: 'partial-stats',
      names: 'worker',
      image: 'example/worker:latest',
      state: 'Up 4 minutes',
    )
      ..cpu = '4.2%'
      ..mem = 'not available'
      ..net = 'not available / garbage'
      ..disk = 'garbage / not available';

    await _pumpAt(tester, width: 390, child: containerView([item]));

    expect(
      find.byKey(
        const ValueKey('container-resource-circle-partial-stats-cpu'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('container-resource-circle-partial-stats-memory'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('container-resource-module-partial-stats-disk'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('container-resource-module-partial-stats-network'),
      ),
      findsNothing,
    );
    expect(find.byType(PercentCircle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('partial or trailing-garbage metrics are omitted', (
    tester,
  ) async {
    final item = DockerPs(
      id: 'malformed-stats',
      names: 'worker',
      image: 'example/worker:latest',
      state: 'Up 4 minutes',
    )
      ..cpu = '12.5% garbage'
      ..mem = '640 MiB junk / 2 GiB'
      ..net = '12 MB / garbage'
      ..disk = '1 GB / -2 MB';

    await _pumpAt(tester, width: 390, child: containerView([item]));

    expect(
      find.byKey(
        const ValueKey('container-resource-panel-malformed-stats'),
      ),
      findsNothing,
    );
    expect(find.byType(PercentCircle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('provider-valid averaged CPU metrics remain visible', (
    tester,
  ) async {
    final item = PodmanPs(
      id: 'averaged-cpu',
      names: ['worker'],
      rawStatus: 'Up 4 minutes',
    )..cpu = '12.5% / Avg 3.0%';

    await _pumpAt(tester, width: 390, child: containerView([item]));

    expect(
      find.byKey(
        const ValueKey('container-resource-circle-averaged-cpu-cpu'),
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
        missingKey: 'container-resource-circle-negative-cpu-cpu',
      ),
      (
        id: 'negative-memory',
        cpu: '5%',
        mem: '-1 GiB / 2 GiB',
        net: '1 MiB / 2 MiB',
        disk: '3 MiB / 4 MiB',
        missingKey: 'container-resource-circle-negative-memory-memory',
      ),
      (
        id: 'negative-network',
        cpu: '5%',
        mem: '1 GiB / 2 GiB',
        net: '-1 MiB / 2 MiB',
        disk: '3 MiB / 4 MiB',
        missingKey: 'container-resource-module-negative-network-network',
      ),
      (
        id: 'negative-disk',
        cpu: '5%',
        mem: '1 GiB / 2 GiB',
        net: '1 MiB / 2 MiB',
        disk: '-3 MiB / 4 MiB',
        missingKey: 'container-resource-module-negative-disk-disk',
      ),
    ];

    for (final data in cases) {
      final item = DockerPs(
        id: data.id,
        names: 'worker',
        image: 'example/worker:latest',
        state: 'Up 4 minutes',
      )
        ..cpu = data.cpu
        ..mem = data.mem
        ..net = data.net
        ..disk = data.disk;

      await _pumpAt(tester, width: 390, child: containerView([item]));

      final metricKeys = [
        'container-resource-circle-${data.id}-cpu',
        'container-resource-circle-${data.id}-memory',
        'container-resource-module-${data.id}-network',
        'container-resource-module-${data.id}-disk',
      ];
      for (final key in metricKeys) {
        expect(
          find.byKey(ValueKey(key)),
          key == data.missingKey ? findsNothing : findsOneWidget,
        );
      }
      expect(
        find.byKey(ValueKey('container-resource-panel-${data.id}')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('resource percentages above 100 are clamped consistently', (
    tester,
  ) async {
    final item = DockerPs(
      id: 'clamped-stats',
      names: 'worker',
      image: 'example/worker:latest',
      state: 'Up 4 minutes',
    )
      ..cpu = '150%'
      ..mem = '3 GiB / 2 GiB';

    await _pumpAt(tester, width: 390, child: containerView([item]));

    expect(find.text('100.0%'), findsNWidgets(2));
    expect(find.text('150.0%'), findsNothing);
    expect(find.byType(PercentCircle), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('image rows switch from compact at 390px to wide at 900px', (
    tester,
  ) async {
    final image = DockerImg(
      containers: '1',
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
    expect(find.text(image.createdAt), findsOneWidget);
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
    expect(find.text(image.createdAt), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long image references are ellipsized on a compact row', (
    tester,
  ) async {
    const repository =
        'registry.example.com/a-very-long-organization/a-very-long-project/image';
    final image = DockerImg(
      containers: '1',
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
        PodmanImg(),
        PodmanImg(),
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
      (index) => DockerImg(
        containers: '1',
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

  testWidgets('compose groups are collapsed by default and can expand', (
    tester,
  ) async {
    final items = [
      DockerPs(
        id: 'compose-web',
        names: 'web',
        image: 'example/web:latest',
        state: 'Up 8 minutes',
        project: 'production-stack',
      ),
      DockerPs(
        id: 'compose-db',
        names: 'db',
        image: 'postgres:17',
        state: 'Exited (0) 2 minutes ago',
        project: 'production-stack',
      ),
    ];

    await _pumpAt(tester, width: 900, child: containerView(items));

    expect(find.text('production-stack'), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    expect(find.text('1 Running · 1 Stopped'), findsOneWidget);
    expect(find.text('web'), findsNothing);
    expect(find.text('db'), findsNothing);

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

    expect(find.text('web'), findsOneWidget);
    expect(find.text('db'), findsOneWidget);
    expect(tester.widget<AnimatedRotation>(arrow).turns, 0.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('standalone containers remain visible beside compose groups', (
    tester,
  ) async {
    final items = [
      DockerPs(
        id: 'compose-web',
        names: 'web',
        image: 'example/web:latest',
        state: 'Up 8 minutes',
        project: 'production-stack',
      ),
      DockerPs(
        id: 'standalone-worker',
        names: 'worker',
        image: 'example/worker:latest',
        state: 'Up 3 minutes',
      ),
    ];

    await _pumpAt(tester, width: 390, child: containerView(items));

    expect(find.text('web'), findsNothing);
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
    final alpha = DockerPs(
      id: 'container-alpha',
      names: 'Alpha',
      image: 'example/alpha:latest',
      state: 'Up 3 minutes',
    );
    final zeta = DockerPs(
      id: 'container-zeta',
      names: 'zeta',
      image: 'example/zeta:latest',
      state: 'Up 3 minutes',
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
          const ValueKey('container-row-compact-0-container-alpha'),
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
      DockerImg(
        containers: '0',
        createdAt: '2026-08-01',
        id: 'sha256:dangling',
        repository: '<none>',
        size: '12 MB',
        tag: '<none>',
      ),
      DockerImg(
        containers: '0',
        createdAt: '2026-08-02',
        id: 'sha256:unused',
        repository: 'example/worker',
        size: '64 MB',
        tag: 'old',
      ),
    ];

    await _pumpAt(tester, width: 900, child: imageView(images));

    expect(find.text('Dangling'), findsOneWidget);
    expect(find.text('Unused'), findsOneWidget);
    expect(find.text('2 Unused'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('summary refresh actions follow prune and are tappable', (
    tester,
  ) async {
    var containerPrunes = 0;
    var containerRefreshes = 0;
    await _pumpAt(
      tester,
      width: 390,
      child: containerView(
        const [],
        onPrune: () => containerPrunes++,
        onRefresh: () => containerRefreshes++,
      ),
    );

    final containerAction = find.byKey(
      const ValueKey('test-prune-containers'),
    );
    final containerRefresh = find.byKey(
      const ValueKey('test-refresh-containers'),
    );
    expect(containerAction, findsOneWidget);
    expect(
      tester.getCenter(containerRefresh).dx,
      greaterThan(tester.getCenter(containerAction).dx),
    );
    await tester.tap(containerAction);
    await tester.tap(containerRefresh);
    expect(containerPrunes, 1);
    expect(containerRefreshes, 1);
    expect(tester.takeException(), isNull);

    var imagePrunes = 0;
    var imageRefreshes = 0;
    await _pumpAt(
      tester,
      width: 900,
      child: imageView(
        const [],
        onPrune: () => imagePrunes++,
        onRefresh: () => imageRefreshes++,
      ),
    );

    final imageAction = find.byKey(const ValueKey('test-prune-images'));
    final imageRefresh = find.byKey(const ValueKey('test-refresh-images'));
    expect(imageAction, findsOneWidget);
    expect(
      tester.getCenter(imageRefresh).dx,
      greaterThan(tester.getCenter(imageAction).dx),
    );
    await tester.tap(imageAction);
    await tester.tap(imageRefresh);
    expect(imagePrunes, 1);
    expect(imageRefreshes, 1);
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
        LibLocalizations.delegate,
        ...AppLocalizations.localizationsDelegates,
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
