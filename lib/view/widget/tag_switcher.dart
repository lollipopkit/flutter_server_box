import 'package:flutter/material.dart';
import 'package:nil/nil.dart';

import '../../data/res/color.dart';

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
        itemBuilder: (context, index) => _buildTagItem(items[index]),
        itemCount: items.length,
      ),
    );
  }

  Widget _buildTagItem(String? tag) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 5, bottom: 9),
      child: GestureDetector(
        onTap: () => onTagChanged(tag),
        child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(20.0)),
              color: primaryColor.withAlpha(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 2.7),
            child: Center(
              child: Text(
                tag == null ? all : '#$tag',
                style: TextStyle(
                  color: initTag == tag ? null : Colors.grey,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )),
      ),
    );
  }
}
