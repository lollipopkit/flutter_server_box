import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/monitor/http.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';

void main() {
  const credA = MonitorHttpCredential(addr: 'http://127.0.0.1:41001', pwd: 'p1');
  const credB = MonitorHttpCredential(addr: 'http://127.0.0.1:41002', pwd: 'p2');

  test('shares one MonitorHttpClient across leases with equal credentials', () {
    final first = MonitorClientLease(credA);
    final second = MonitorClientLease(credA);
    addTearDown(() {
      first.release();
      second.release();
    });

    expect(identical(first.client, second.client), isTrue);
  });

  test('keeps distinct clients for different credentials', () {
    final leaseA = MonitorClientLease(credA);
    final leaseB = MonitorClientLease(credB);
    addTearDown(() {
      leaseA.release();
      leaseB.release();
    });

    expect(identical(leaseA.client, leaseB.client), isFalse);
  });

  test('release is idempotent and recreates client only after last release', () {
    final first = MonitorClientLease(credA);
    final second = MonitorClientLease(credA);
    final original = first.client;

    // Releasing the first lease twice must not decrement the second's refcount.
    first.release();
    first.release();

    final third = MonitorClientLease(credA);
    expect(identical(third.client, original), isTrue);

    second.release();
    third.release();

    final fresh = MonitorClientLease(credA);
    addTearDown(fresh.release);
    expect(identical(fresh.client, original), isFalse);
  });
}
