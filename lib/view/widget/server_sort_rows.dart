import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/provider/server/sort.dart';

/// Every order the list under [tag] can take, as a sheet's rows. Picking one
/// saves it, closes the sheet and calls [onPicked].
List<Widget> serverSortRows(BuildContext sheetContext, String tag, VoidCallback onPicked) => [
  for (final order in ServerSortOrder.all)
    SheetChoiceTile(
      icon: order.icon,
      title: order.label,
      selected: order.isCurrentFor(tag),
      onTap: () {
        order.save(tag);
        Navigator.of(sheetContext).pop();
        onPicked();
      },
    ),
];
