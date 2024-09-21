part of 'home.dart';

final class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final double paddingTop;

  const _AppBar(this.paddingTop);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: paddingTop,
      child: isIOS
          ? const Center(child: Text(BuildData.name, style: UIs.text15Bold))
          : null,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(paddingTop);
}
