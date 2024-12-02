part of 'home.dart';

final class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final double paddingTop;

  const _AppBar(this.paddingTop);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: preferredSize.height,
      child: isIOS ? Center(child: _buildLogo()) : null,
    );
  }

  Widget _buildLogo() {
    final text = Text(
      BuildData.name,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: UIs.primaryColor.isBrightColor ? Colors.black : Colors.white,
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: UIs.primaryColor,
        borderRadius: BorderRadius.circular(11),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      child: text,
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
