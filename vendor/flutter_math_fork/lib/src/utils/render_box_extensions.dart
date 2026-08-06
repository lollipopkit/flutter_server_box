import 'package:collection/collection.dart';
import 'package:flutter/rendering.dart';

extension HittestExtension on RenderBox {
  T? hittestFindLowest<T>(Offset localOffset) {
    final result = BoxHitTestResult();
    this.hitTest(result, position: localOffset);
    final target = result.path
        .firstWhereOrNull((element) => element.target is T)
        ?.target as T?;
    return target;
  }
}
