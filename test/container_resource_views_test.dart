import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/container/image.dart';
import 'package:server_box/data/model/container/ps.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/container/resource_views.dart';

void main() {
  Widget containerView(List<ContainerPs> items) {
    return ContainerItemsView(
      items: items,
      type: ContainerType.docker,
      version: '27.1.1',
      trailingBuilder: (item) => SizedBox(
        key: ValueKey('container-trailing-${item.id}'),
        width: 32,
        height: 32,
        child: const Icon(Icons.more_vert),
      ),
      groupTrailingBuilder: (_) => null,
    );
  }

  Widget imageView(List<ContainerImg> images) {
    return ContainerImagesView(
      images: images,
      type: ContainerType.docker,
      version: '27.1.1',
      trailingBuilder: (image) => SizedBox(
        key: ValueKey('image-trailing-${image.id}'),
        width: 32,
        height: 32,
        child: const Icon(Icons.more_vert),
      ),
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
      find.byKey(const ValueKey('container-row-compact-mobile-container')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('container-row-wide-mobile-container')),
      findsNothing,
    );
    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('MEM'), findsOneWidget);
    expect(find.text(longName), findsOneWidget);
    expect(find.text(longImage), findsOneWidget);
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

  testWidgets('1280px renders the wide container metrics row', (tester) async {
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
      find.byKey(const ValueKey('container-row-wide-desktop-container')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('container-row-compact-desktop-container')),
      findsNothing,
    );
    for (final label in ['CPU', 'MEM', 'NET', 'DISK']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('2.5%'), findsOneWidget);
    expect(find.text('128 MiB / 1 GiB'), findsOneWidget);
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
        const ValueKey('image-row-compact-sha256:image-switch'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('image-row-wide-sha256:image-switch')),
      findsNothing,
    );
    expect(find.text(image.createdAt), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpAt(tester, width: 900, child: imageView([image]));
    expect(
      find.byKey(const ValueKey('image-row-wide-sha256:image-switch')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('image-row-compact-sha256:image-switch'),
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

  testWidgets('compose containers are grouped under their project title', (
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
    expect(find.text('web'), findsOneWidget);
    expect(find.text('db'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
}

Future<void> _pumpAt(
  WidgetTester tester, {
  required double width,
  required Widget child,
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
  await tester.pumpAndSettle();
}
