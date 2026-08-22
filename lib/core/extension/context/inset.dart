import 'package:flutter/widgets.dart';

extension BottomInsetX on BuildContext {
  /// [base] with whatever has to be kept clear of the foot of the window added
  /// to its bottom.
  ///
  /// A scrollable's padding rather than a strip taken out of the page's box:
  /// the settings tabs float over the content and the content passes under
  /// them, which only reads as floating if the list can still bring its last
  /// row above the bar. A page shown on its own gets the home indicator here
  /// and nothing else, so one padding covers both.
  EdgeInsets padBottom(EdgeInsets base) =>
      base.copyWith(bottom: base.bottom + MediaQuery.paddingOf(this).bottom);
}
