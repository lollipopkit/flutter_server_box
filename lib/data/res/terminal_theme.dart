import 'package:flutter/material.dart';

import '../model/ssh/terminal_color.dart';

const termDarkTheme = TerminalUITheme(
  cursor: Color(0XAAAEAFAD),
  selection: Color(0XAAAEAFAD),
  foreground: Color(0XFFCCCCCC),
  background: Colors.black,
  searchHitBackground: Color(0XFFFFFF2B),
  searchHitBackgroundCurrent: Color(0XFF31FF26),
  searchHitForeground: Color(0XFF000000),
);

const termLightTheme = TerminalUITheme(
  cursor: Color(0XFFAEAFAD),
  selection: Color.fromARGB(102, 174, 175, 173),
  foreground: Color(0XFF000000),
  background: Color(0XFFFFFFFF),
  searchHitBackground: Color(0XFFFFFF2B),
  searchHitBackgroundCurrent: Color(0XFF31FF26),
  searchHitForeground: Color(0XFF000000),
);
