part of 'tab.dart';

final class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  final ValueNotifier<Set<String>> tags;
  final void Function(String) onTagChanged;
  final String initTag;

  const _TopBar({
    required this.initTag,
    required this.onTagChanged,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () => DebugPage.route.go(
                context,
                args: const DebugPageArgs(title: 'Logs(${BuildData.build})'),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 7),
                child: Row(
                  children: [
                    Text(
                      BuildData.name,
                      style: TextStyle(fontSize: 20),
                      textAlign: TextAlign.center,
                    ),
                    Icon(
                      Icons.keyboard_arrow_right,
                      color: Colors.grey,
                      size: 17,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 30),
          TagSwitcher(
            tags: tags,
            onTagChanged: onTagChanged,
            initTag: initTag,
            singleLine: true,
            reversed: true,
          ).expanded(),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(TagSwitcher.kTagBtnHeight);
}
