import 'package:flutter/material.dart';

import 'btn.dart';

class TagView extends StatelessWidget {
  final void Function(String?) onTap;
  final String? tag;
  final String? initTag;
  final String all;

  const TagView({
    super.key,
    required this.onTap,
    this.tag,
    this.initTag,
    required this.all,
  });

  @override
  Widget build(BuildContext context) {
    return TagBtn(
      onTap: () => onTap(tag),
      isEnable: initTag == tag,
      content: tag == null ? all : '#$tag',
    );
  }
}
