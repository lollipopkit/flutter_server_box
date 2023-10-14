import 'package:flutter/material.dart';

const _shape = Border();

class ExpandTile extends ExpansionTile {
  const ExpandTile({
    super.key,
    required super.title,
    super.children,
    super.subtitle,
  }) : super(shape: _shape, collapsedShape: _shape);
}
