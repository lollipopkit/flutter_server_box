import 'package:flutter/material.dart';
import 'package:toolbox/data/model/ssh/terminal_color.dart';

const termDarkTheme = TerminalUITheme(
  cursor: Color.fromARGB(137, 174, 175, 173),
  selection: Color.fromARGB(147, 174, 175, 173),
  foreground: Color(0XFFCCCCCC),
  background: Colors.black,
  searchHitBackground: Color(0XFFFFFF2B),
  searchHitBackgroundCurrent: Color(0XFF31FF26),
  searchHitForeground: Color(0XFF000000),
);

const termLightTheme = TerminalUITheme(
  cursor: Color.fromARGB(153, 174, 175, 173),
  selection: Color.fromARGB(102, 174, 175, 173),
  foreground: Color(0XFF000000),
  background: Color(0XFFFFFFFF),
  searchHitBackground: Color(0XFFFFFF2B),
  searchHitBackgroundCurrent: Color(0XFF31FF26),
  searchHitForeground: Color(0XFF000000),
);

class MacOSTerminalColor extends TerminalColors {
  MacOSTerminalColor()
      : super(
          const Color.fromARGB(255, 194, 54, 33),
          const Color.fromARGB(255, 37, 188, 36),
          const Color.fromARGB(255, 173, 173, 39),
          const Color.fromARGB(255, 73, 46, 225),
          const Color.fromARGB(255, 211, 56, 211),
          const Color.fromARGB(255, 51, 187, 200),
          const Color.fromARGB(255, 203, 204, 205),
          const Color.fromARGB(255, 129, 131, 131),
          const Color.fromARGB(255, 252, 57, 31),
          const Color.fromARGB(255, 49, 231, 34),
          const Color.fromARGB(255, 234, 236, 35),
          const Color.fromARGB(255, 88, 51, 255),
          const Color.fromARGB(255, 249, 53, 248),
          const Color.fromARGB(255, 20, 240, 240),
          brightWhite: const Color.fromARGB(255, 233, 235, 235),
        );
}
