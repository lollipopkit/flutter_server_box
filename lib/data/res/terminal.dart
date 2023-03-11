import 'package:flutter/material.dart';
import 'package:toolbox/data/model/ssh/terminal_color.dart';

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

class VGATerminalColor extends TerminalColors {
  VGATerminalColor()
      : super(
          TerminalColorsPlatform.vga,
          const Color.fromARGB(255, 170, 0, 0),
          const Color.fromARGB(255, 0, 170, 0),
          const Color.fromARGB(255, 170, 85, 0),
          const Color.fromARGB(255, 0, 0, 170),
          const Color.fromARGB(255, 170, 0, 170),
          const Color.fromARGB(255, 0, 170, 170),
          const Color.fromARGB(255, 170, 170, 170),
          const Color.fromARGB(255, 85, 85, 85),
          const Color.fromARGB(255, 255, 85, 85),
          const Color.fromARGB(255, 85, 255, 85),
          const Color.fromARGB(255, 255, 255, 85),
          const Color.fromARGB(255, 85, 85, 255),
          const Color.fromARGB(255, 255, 85, 255),
          const Color.fromARGB(255, 85, 255, 255),
        );
}

class CMDTerminalColor extends TerminalColors {
  CMDTerminalColor()
      : super(
          TerminalColorsPlatform.cmd,
          const Color.fromARGB(255, 128, 0, 0),
          const Color.fromARGB(255, 0, 128, 0),
          const Color.fromARGB(255, 128, 128, 0),
          const Color.fromARGB(255, 0, 0, 128),
          const Color.fromARGB(255, 128, 0, 128),
          const Color.fromARGB(255, 0, 128, 128),
          const Color.fromARGB(255, 192, 192, 192),
          const Color.fromARGB(255, 128, 128, 128),
          const Color.fromARGB(255, 255, 0, 0),
          const Color.fromARGB(255, 0, 255, 0),
          const Color.fromARGB(255, 255, 255, 0),
          const Color.fromARGB(255, 0, 0, 255),
          const Color.fromARGB(255, 255, 0, 255),
          const Color.fromARGB(255, 0, 255, 255),
        );
}

class MacOSTerminalColor extends TerminalColors {
  MacOSTerminalColor()
      : super(
            TerminalColorsPlatform.macOS,
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
            brightWhite: const Color.fromARGB(255, 233, 235, 235));
}

class PuttyTerminalColor extends TerminalColors {
  PuttyTerminalColor()
      : super(
          TerminalColorsPlatform.putty,
          const Color.fromARGB(255, 187, 0, 0),
          const Color.fromARGB(255, 0, 187, 0),
          const Color.fromARGB(255, 187, 187, 0),
          const Color.fromARGB(255, 0, 0, 187),
          const Color.fromARGB(255, 187, 0, 187),
          const Color.fromARGB(255, 0, 187, 187),
          const Color.fromARGB(255, 187, 187, 187),
          const Color.fromARGB(255, 85, 85, 85),
          const Color.fromARGB(255, 255, 85, 85),
          const Color.fromARGB(255, 85, 255, 85),
          const Color.fromARGB(255, 255, 255, 85),
          const Color.fromARGB(255, 85, 85, 255),
          const Color.fromARGB(255, 255, 85, 255),
          const Color.fromARGB(255, 85, 255, 255),
        );
}

class XTermTerminalColor extends TerminalColors {
  XTermTerminalColor()
      : super(
          TerminalColorsPlatform.xterm,
          const Color.fromARGB(255, 205, 0, 0),
          const Color.fromARGB(255, 0, 205, 0),
          const Color.fromARGB(255, 205, 205, 0),
          const Color.fromARGB(255, 0, 0, 238),
          const Color.fromARGB(255, 205, 0, 205),
          const Color.fromARGB(255, 0, 205, 205),
          const Color.fromARGB(255, 229, 229, 229),
          const Color.fromARGB(255, 127, 127, 127),
          const Color.fromARGB(255, 255, 0, 0),
          const Color.fromARGB(255, 0, 255, 0),
          const Color.fromARGB(255, 255, 255, 0),
          const Color.fromARGB(255, 92, 92, 255),
          const Color.fromARGB(255, 255, 0, 255),
          const Color.fromARGB(255, 0, 255, 255),
        );
}

class UbuntuTerminalColor extends TerminalColors {
  UbuntuTerminalColor()
      : super(
          TerminalColorsPlatform.ubuntu,
          const Color.fromARGB(255, 222, 56, 43),
          const Color.fromARGB(255, 57, 181, 74),
          const Color.fromARGB(255, 255, 199, 6),
          const Color.fromARGB(255, 0, 111, 184),
          const Color.fromARGB(255, 118, 38, 113),
          const Color.fromARGB(255, 44, 181, 233),
          const Color.fromARGB(255, 204, 204, 204),
          const Color.fromARGB(255, 128, 128, 128),
          const Color.fromARGB(255, 255, 0, 0),
          const Color.fromARGB(255, 0, 255, 0),
          const Color.fromARGB(255, 255, 255, 0),
          const Color.fromARGB(255, 0, 0, 255),
          const Color.fromARGB(255, 255, 0, 255),
          const Color.fromARGB(255, 0, 255, 255),
        );
}
