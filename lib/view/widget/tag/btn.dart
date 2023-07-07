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
      child: GestureDetector(
        onTap: onTap,
        child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(20.0)),
              color: primaryColor.withAlpha(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 2.7),
            child: Center(
              child: Text(
                content,
                style: TextStyle(
                  color: isEnable ? null : Colors.grey,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )),
      ),
    );
  }
}
