import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/cpu.dart';

void main() {
  test('no brand, no label', () => expect(Cpus().brandLabel, isNull));

  test('one kind of core is its name alone', () {
    final cpus = Cpus()..brand['Neoverse-N1'] = 4;
    expect(cpus.brandLabel, 'Neoverse-N1');
  });

  test('every kind of a big.LITTLE CPU, each with its count', () {
    final cpus = Cpus()
      ..brand['Cortex-A55'] = 4
      ..brand['Cortex-A76'] = 4;
    expect(cpus.brandLabel, 'Cortex-A55 ×4, Cortex-A76 ×4');
  });
}
