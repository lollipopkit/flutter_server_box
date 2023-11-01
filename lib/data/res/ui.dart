import 'package:flutter/material.dart';

class UIs {
  const UIs._();

  /// Font style

  static const textSize9Grey = TextStyle(color: Colors.grey, fontSize: 9);
  static const textSize11 = TextStyle(fontSize: 11);
  static const textSize11Bold = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );
  static const textSize11Grey = TextStyle(color: Colors.grey, fontSize: 11);
  static const textSize13 = TextStyle(fontSize: 13);
  static const textSize13Bold = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );
  static const textSize13Grey = TextStyle(color: Colors.grey, fontSize: 13);
  static const textSize15 = TextStyle(fontSize: 15);
  static const textSize18 = TextStyle(fontSize: 18);
  static const textSize27 = TextStyle(fontSize: 27);
  static const textGrey = TextStyle(color: Colors.grey);
  static const textRed = TextStyle(color: Colors.red);

  /// Icon

  static final appIcon = Image.asset('assets/app_icon.png');

  /// Padding

  static const roundRectCardPadding =
      EdgeInsets.symmetric(horizontal: 17, vertical: 13);

  /// SizedBox

  static const placeholder = SizedBox();
  static const height13 = SizedBox(height: 13);
  static const height77 = SizedBox(height: 77);
  static const width13 = SizedBox(width: 13);
  static const width7 = SizedBox(width: 7);

  /// Misc

  static const popMenuChild = Padding(
    padding: EdgeInsets.only(left: 7),
    child: Icon(
      Icons.more_vert,
      size: 21,
    ),
  );

  static const centerLoading = Center(child: CircularProgressIndicator());

  static const centerSizedLoadingSmall = SizedBox(
    width: 23,
    height: 23,
    child: Center(
      child: CircularProgressIndicator(),
    ),
  );

  static const centerSizedLoading = SizedBox(
    width: 77,
    height: 77,
    child: Center(
      child: CircularProgressIndicator(),
    ),
  );
}
