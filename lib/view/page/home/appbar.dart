part of 'home.dart';

final class _AppBar extends CustomAppBar {
  final ValueNotifier<int> selectIndex;

  const _AppBar({
    required this.selectIndex,
    super.title,
    super.actions,
    super.centerTitle,
  });

  @override
  Widget build(BuildContext context) {
    return ValBuilder(
      listenable: selectIndex,
      builder: (idx) {
        if (idx == AppTab.ssh.index) {
          return SizedBox(
            height: CustomAppBar.barHeight ??
                0 + MediaQuery.of(context).padding.top,
          );
        }
        return super.build(context);
      },
    );
  }
}
