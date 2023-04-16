import 'package:flutter/material.dart';

Widget buildPicker(List<Widget> items, Function(int idx) onSelected) {
  return SizedBox(
    height: 111,
    child: Stack(
      children: [
        Positioned(
          top: 36,
          bottom: 36,
          left: 0,
          right: 0,
          child: Container(
            height: 37,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(7)),
              color: Colors.black12,
            ),
          ),
        ),
        ListWheelScrollView.useDelegate(
          itemExtent: 37,
          diameterRatio: 1.2,
          controller: FixedExtentScrollController(initialItem: 0),
          onSelectedItemChanged: (idx) => onSelected(idx),
          physics: const FixedExtentScrollPhysics(),
          childDelegate: ListWheelChildBuilderDelegate(
            builder: (context, index) => Center(
              child: items[index],
            ),
            childCount: items.length,
          ),
        )
      ],
    ),
  );
}
