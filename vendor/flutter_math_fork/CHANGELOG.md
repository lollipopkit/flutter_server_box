## 0.7.2

* Fix: add missing import to gesture_detector_builder_selectable.dart (#87)
* Fix: simple null pointer exception (#82)
* Fix: function node children update (#58)

## 0.7.1

* Update `flutter_svg` dependency
* Make expressions inside a root selectable

## 0.7.0

* Support for Dart version `3.0.0`.
* Code cleanups.

## 0.6.3+1

* Updated example app flutter_tex dependency.

## 0.6.3

* Removed unnecessary null-aware operators. Bumped min Flutter version to `3.0.0` and Dart to `2.17.0`.

## 0.6.2

* Added CursorNode

## 0.6.1

* Fixed text selection (`SelectableMath`).

## 0.6.0

* Upgraded `flutter_svg` dependency to `1.0.0` release.

## 0.5.0

* Upgraded `flutter_svg` dependency.

## 0.4.2+2

* Fixed `\sqrt` child positioning.

## 0.4.2+1

* Fixed `aligned` environment.

## 0.4.2

* Added dry layout support.

## 0.4.1

* Fixed styling of umlauts in text mode.

## 0.4.0+1

* Fixed missing implementations compile-time error on `master`.

## 0.4.0

* Bumped `provider` to `^6.0.0`.

## 0.3.3+1

* Fixed breaking change in `TextSelectionControls.buildHandle`.

## 0.3.3

* Fixed all SVG-related bugs on web (`\sqrt`, stretchies, etc.) as `flutter_svg`
  is now supported using both CanvasKit and the HTML renderer.

## 0.3.2+1

* Fixed `\sqrt` not displaying in CanvasKit by forcing platform views for sqrt.

## 0.3.2

* Fixed WebGL crashing by using `flutter_svg` on web when CanvasKit is enabled.

## 0.3.1+1

* Exposed `MacroExpansion` in `package:flutter_math/tex.dart`.

## 0.3.1

* Added support for custom macros by exposing `defineMacro` in `package:flutter_math/tex.dart`.

## 0.3.0+3

* Bump `flutter_svg`.

## 0.3.0+2

* Added missing `userUpdateTextEditingValue` implementation
  to `InternalSelectableMathState`.

## 0.3.0+1

* Fixed font references.

## 0.3.0

* Migrated to Flutter 2.0.

## 0.3.0-nullsafety.0

* Migrate to dart null safety
* Migrate to new selection theme api

## 0.2.1

* Fix overflow in `cases` environment
* Fix errors caused by null text colors in `Math` widget.

## 0.2.0+2

* Add support for `TextStyle.color` in widget constructors.

## 0.2.0+1

* Fix `Math.tex` constructor's wrong default value for `MathOptions`.

## 0.2.0

* A new `SelectableMath` widget that supports selection and copy-to-clipboard.
* A TeX encoder.
* Various performance boosts.
* fix a bug where some math functions' lower bound get dropped
* **Breaking change**: major overhaul on class names.
* **Breaking change**: `baseSizeMultiplier` is removed.
* **Breaking change**: parse errors and build errors now have correct types instead of `dynamic`. 
  `onErrorFallback`'s signature has changed as a result.
* **Breaking change**: exports are grouped into `widgets`, `ast`, `tex`.

For detailed information, please see [0.2.0 migration guide](doc/migration.0.2.0.md).

## 0.1.9

* With all 0.2.0 improvements, but excluding those breaking changes.

## 0.1.8+1

* More documentations.

## 0.1.8

* Add support for text-mode accent and unicode accents. (e.g. `ä` and `\text{\v{a}}`)
* Fix underflow issues of accents and sqrts when their child has too little height.

## 0.1.7

* Remove need for specifying fonts in package Pubspec.

## 0.1.6

* Add support for Flutter Web (DomCanvas backend)

## 0.1.5

* Fix breakings caused by [dart/#40674](https://github.com/dart-lang/sdk/issues/40674)
* Support Flutter 1.20.

## 0.1.4

* Fix incorrect color for lines in \frac, \overline, \underline, and \rule

## 0.1.3

* Dashed matrix separator will now be rendered correctly

## 0.1.2

* Add support for composite symbols, i.e. \notin \not\lt
* Add API to indicate font size
* Fix a problem where some exceptions will not be caught

## 0.1.1

* Add `onErrorFallback` functions for `FlutterMath` widget

## 0.1.0

Fix minor crashes

## 0.0.1+1
 
* Temporarily fix the problem that pana and dartfmt will crash on this package causing zero pub score

## 0.0.1 

Initial release.
