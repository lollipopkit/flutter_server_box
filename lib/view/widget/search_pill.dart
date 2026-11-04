import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';

/// The filter field over an admin list (processes, services, scheduled tasks),
/// styled by the theme's `ComponentStyles.search` as the settings search is.
class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;

  /// Also called with `''` when the field is cleared.
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = ComponentStyles.of(context).search;
    final iconColor = style.iconColor ?? UIs.textGrey.color;
    final text = TextStyle(fontSize: 13, color: style.textColor);

    return Container(
      height: style.height ?? 36,
      padding: style.padding ?? const EdgeInsets.only(left: 11, right: 4),
      decoration: ShapeDecoration(
        shape: style.shape(const StadiumBorder()),
        color: style.backgroundColor ?? scheme.surfaceContainer,
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 17, color: iconColor),
          UIs.width7,
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: text,
              decoration: bareInputDecoration(
                isCollapsed: true,
                hintText: hint,
                hintStyle: text.copyWith(color: style.hintColor ?? UIs.textGrey.color),
              ),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (_, value, _) => value.text.isEmpty
                ? UIs.placeholder
                : Btn.icon(
                    text: libL10n.clear,
                    icon: Icon(Icons.close, size: 16, color: iconColor),
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
