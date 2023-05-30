import 'package:flutter/material.dart';

class Picker extends StatelessWidget {
  final List<Widget> items;
  final void Function(int idx) onSelected;
  final double height;

  const Picker({
    super.key,
    required this.items,
    required this.onSelected,
    this.height = 157,
  });

  @override
  Widget build(BuildContext context) {
    final pad = (height - 37) / 2;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned(
            top: pad,
            bottom: pad,
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
            diameterRatio: 2.7,
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
}
