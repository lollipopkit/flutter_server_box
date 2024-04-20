import 'package:flutter/material.dart';
import 'package:toolbox/view/widget/cardx.dart';

extension WidgetX on Widget {
  Widget get card {
    return CardX(child: this);
  }
}
