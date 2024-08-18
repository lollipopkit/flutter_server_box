part of 'home.dart';

final class _AppBar extends CustomAppBar {
  final ValueNotifier<int> selectIndex;
  final ValueNotifier<bool> landscape;

  const _AppBar({
    required this.selectIndex,
    required this.landscape,
    super.title,
    super.actions,
    super.centerTitle,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = SizedBox(
      height: CustomAppBar.barHeight ?? 0 + MediaQuery.of(context).padding.top,
    );
    return selectIndex.listenVal(
      (idx) {
        if (isDesktop) return super.build(context);

        if (idx == AppTab.ssh.index) {
          return placeholder;
        }

        return ValBuilder(
          listenable: landscape,
          builder: (ls) {
            if (ls) return placeholder;

            return super.build(context);
          },
        );
      },
    );
  }
}
