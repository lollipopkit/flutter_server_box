part of 'home.dart';

final class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final double paddingTop;

  const _AppBar(this.paddingTop);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: preferredSize.height,
      child: isIOS
          ? const Center(child: Text(BuildData.name, style: UIs.text15Bold))
          : null,
    );
  }

  @override
  Size get preferredSize {
    final height = switch (Pfs.type) {
      Pfs.macos => paddingTop + (CustomAppBar.sysStatusBarHeight ?? 0),
      _ => paddingTop,
    };
    return Size.fromHeight(height);
  }
}