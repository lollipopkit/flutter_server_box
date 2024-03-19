import 'package:flutter/material.dart';
import 'package:toolbox/data/res/ui.dart';

final class KvRow extends StatelessWidget {
  final String k;
  final String v;
  final void Function()? onTap;

  const KvRow({
    super.key,
    required this.k,
    required this.v,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: UIs.text12),
            UIs.width7,
            Text(
              v,
              style: UIs.text11Grey,
              overflow: TextOverflow.ellipsis,
            ),
            if (onTap != null) UIs.width7,
            if (onTap != null) const Icon(Icons.keyboard_arrow_right, size: 16),
          ],
        ),
      ),
    );
  }
}
