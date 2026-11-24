import 'package:material_ui/material_ui.dart';
import 'package:server_box/view/page/server/card/shared_hero.dart';

/// A server's name, carried from its card to the detail page's bar when
/// opening the card pushes a page.
class ServerNameHero extends StatelessWidget {
  const ServerNameHero({
    super.key,
    required this.id,
    required this.enabled,
    required this.child,
  });

  final String id;
  final bool enabled;
  final Widget child;

  static Object tagOf(String id) => 'server_name_$id';

  @override
  Widget build(BuildContext context) => SharedElementHero(
    tag: tagOf(id),
    enabled: enabled,
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    preserveTextStyle: true,
    child: child,
  );
}
