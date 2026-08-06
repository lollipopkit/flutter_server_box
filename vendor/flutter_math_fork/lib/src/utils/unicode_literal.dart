String fixedHex(int number, int length) {
  var str = number.toRadixString(16).toUpperCase();
  str = str.padLeft(length, '0');
  return str;
}

/* Creates a unicode literal based on the string */
String unicodeLiteral(String str, {bool escape = false}) =>
    str.split('').map((e) {
      if (e.codeUnitAt(0) > 126 || e.codeUnitAt(0) < 32) {
        return '\\u${fixedHex(e.codeUnitAt(0), 4)}';
      } else if (escape && (e == '\'' || e == '\$')) {
        return '\\$e';
      } else {
        return e;
      }
    }).join();
