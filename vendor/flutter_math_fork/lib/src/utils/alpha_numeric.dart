final _code0 = '0'.codeUnitAt(0);

final _code9 = '9'.codeUnitAt(0);

final _codeA = 'A'.codeUnitAt(0);

final _codeZ = 'Z'.codeUnitAt(0);

final _codea = 'a'.codeUnitAt(0);

final _codez = 'z'.codeUnitAt(0);

bool isAlphaNumericUnit(String symbol) {
  assert(symbol.length == 1);
  final code = symbol.codeUnitAt(0);
  return (code >= _code0 && code <= _code9) ||
      (code >= _codeA && code <= _codeZ) ||
      (code >= _codea && code <= _codez);
}
