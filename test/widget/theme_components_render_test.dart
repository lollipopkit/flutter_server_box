import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/theme_components.dart';
import 'package:server_box/view/widget/nav_rail.dart';

void main() {
  testWidgets('shared widgets render component colors, borders and spacing', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final config = ThemeComponents.parse(<String, dynamic>{
      'card': {
        'radius': 19,
        'borderColor': 0xff123456,
        'borderWidth': 2,
        'elevation': 5,
      },
      'input': {
        'radius': 8,
        'borderColor': 'primary',
        'padding': [8, 9, 10, 11],
      },
      'tile': {
        'selectedTileColor': 0xff334455,
        'selectedColor': 0xffabcdef,
        'borderColor': 0xff123456,
        'borderWidth': 2,
      },
      'button': {
        'radius': 9,
        'padding': [8, 9, 10, 11],
        'borderWidth': 2,
        'borderColor': 0xff123456,
      },
      'sheet': {'dragHandleColor': 0xff334455},
    });
    Widget app(Brightness brightness) => MaterialApp(
      theme: config.apply(ThemeData(brightness: brightness)),
      home: Scaffold(
        body: Column(
          children: [
            const CardX(key: ValueKey('card'), child: Text('Card')),
            Input(controller: controller, suggestion: false),
            const SideBarTile(title: 'Selected', selected: true),
            const Btn.elevated(text: 'Button'),
            const Flexible(child: RowsSheet(children: [Text('Sheet')])),
          ],
        ),
      ),
    );
    await tester.pumpWidget(app(Brightness.light));
    final card = tester.widget<Card>(
      find.descendant(
        of: find.byKey(const ValueKey('card')),
        matching: find.byType(Card),
      ),
    );
    expect(card.elevation, 5);
    expect(
      (card.shape! as RoundedRectangleBorder).side,
      const BorderSide(color: Color(0xff123456), width: 2),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(
      field.decoration!.contentPadding,
      const EdgeInsets.fromLTRB(8, 9, 10, 11),
    );
    expect(field.decoration!.border, isA<OutlineInputBorder>());
    final tile = tester.widget<AnimatedContainer>(
      find
          .descendant(
            of: find.byType(SideBarTile),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect((tile.decoration! as BoxDecoration).color, const Color(0xff334455));
    expect((tile.decoration! as BoxDecoration).border!.top.width, 2);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(
      button.style!.padding!.resolve({}),
      const EdgeInsets.fromLTRB(8, 9, 10, 11),
    );
    expect(
      (button.style!.shape!.resolve({})! as RoundedRectangleBorder).side.width,
      2,
    );
    final handle = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(RowsSheet),
            matching: find.byType(Container),
          ),
        )
        .firstWhere((widget) => widget.decoration is BoxDecoration);
    expect(
      (handle.decoration! as BoxDecoration).color,
      const Color(0xff334455),
    );
    await tester.pumpWidget(app(Brightness.dark));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom navigation rail reads component indicator styles', (
    tester,
  ) async {
    final theme = ThemeComponents.parse(<String, dynamic>{
      'navigation': {
        'backgroundColor': 0xff112233,
        'indicatorColor': 0xff334455,
        'indicatorRadius': 7,
        'selectedIconColor': 0xffabcdef,
      },
    }).apply(ThemeData());
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: AppNavRail(
            items: [
              NavRailItem(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
            ],
            selectedIndex: 0,
            onSelected: _ignore,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final decoration = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(AppNavRail),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((widget) => widget.decoration)
        .whereType<ShapeDecoration>()
        .first;
    expect(decoration.color, const Color(0xff334455));
    expect(
      (decoration.shape as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(7),
    );
    final iconContext = tester.element(find.byIcon(Icons.home));
    expect(IconTheme.of(iconContext).color, const Color(0xffabcdef));
  });
}

void _ignore(int _) {}
