import 'package:material_ui/material_ui.dart';
import 'package:server_box/view/page/server/card/shared_hero.dart';

/// The chart a card draws in full, carried to the one at the top of the
/// detail page when opening the card pushes a page.
class ServerChartHero extends StatelessWidget {
  const ServerChartHero({
    super.key,
    required this.id,
    required this.enabled,
    required this.child,
  });

  final String id;
  final bool enabled;
  final Widget child;

  static Object tagOf(String id) => 'server_chart_$id';

  @override
  Widget build(BuildContext context) => SharedElementHero(
    tag: tagOf(id),
    enabled: enabled,
    child: child,
  );
}
