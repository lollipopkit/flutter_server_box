import 'package:flutter/material.dart';
import 'package:nil/nil.dart';
import 'package:toolbox/view/widget/tag/view.dart';

class TagSwitcher extends StatelessWidget {
  final List<String> tags;
  final double width;
  final void Function(String?) onTagChanged;
  final String? initTag;
  final String all;

  const TagSwitcher({
    Key? key,
    required this.tags,
    required this.width,
    required this.onTagChanged,
    required this.all,
    this.initTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _buildTagsSwitcher(tags);
  }

  Widget _buildTagsSwitcher(List<String> tags) {
    if (tags.isEmpty) return nil;
    final items = <String?>[null, ...tags];
    return Container(
      height: 37,
      width: width,
      alignment: Alignment.center,
      color: Colors.transparent,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final item = items[index];
          return TagView(
            tag: item,
            initTag: initTag,
            all: all,
            onTap: onTagChanged,
          );
        },
        itemCount: items.length,
      ),
    );
  }
}
