import 'package:flutter/material.dart';

import '../../../data/res/color.dart';

class TagBtn extends StatelessWidget {
  final String content;
  final void Function() onTap;
  final bool isEnable;

  const TagBtn({
    super.key,
    required this.onTap,
    required this.isEnable,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 5, bottom: 9),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(20.0)),
        child: Material(
          color: primaryColor.withAlpha(20),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 2.7),
              child: Text(
                content,
                style: TextStyle(
                  color: isEnable ? null : Colors.grey,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
