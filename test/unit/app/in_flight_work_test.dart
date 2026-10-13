import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/in_flight_work.dart';

void main() {
  test('a release counts once, however often it is called', () {
    final base = InFlightWork.holds;
    final a = InFlightWork.hold();
    final b = InFlightWork.hold();
    expect(InFlightWork.holds, base + 2);

    a();
    a();
    expect(InFlightWork.holds, base + 1);

    b();
    expect(InFlightWork.holds, base);
  });
}
