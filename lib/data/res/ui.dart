import 'package:flutter/material.dart';

/// Font style

const textSize11 = TextStyle(fontSize: 11);
const textSize12Grey = TextStyle(color: Colors.grey, fontSize: 11);
const textSize13 = TextStyle(fontSize: 13);
const textSize13Grey = TextStyle(color: Colors.grey, fontSize: 13);
const textSize15 = TextStyle(fontSize: 15);
const textSize18 = TextStyle(fontSize: 18);
const textSize27 = TextStyle(fontSize: 27);

const grey = TextStyle(color: Colors.grey);

/// Icon

final appIcon = Image.asset('assets/app_icon.png');

/// Padding

const roundRectCardPadding = EdgeInsets.symmetric(horizontal: 17, vertical: 13);

/// SizedBox

const placeholder = SizedBox.shrink();
const height13 = SizedBox(height: 13);
const width13 = SizedBox(width: 13);
const width7 = SizedBox(width: 7);

/// Misc

const popMenuChild = Padding(
  padding: EdgeInsets.only(left: 7),
  child: Icon(
    Icons.more_vert,
    size: 21,
  ),
);

const centerLoading = Center(child: CircularProgressIndicator());

const centerSizedLoading = SizedBox(
  width: 77,
  height: 77,
  child: Center(
    child: CircularProgressIndicator(),
  ),
);

const loadingIcon = IconButton(onPressed: null, icon: centerLoading);
