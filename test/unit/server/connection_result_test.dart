import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/connection_stat.dart';

void main() {
  test('a dial that ran out of time is a timeout, though it is a SocketException', () {
    expect(ConnectionResult.fromError(const SocketException('Connection timed out')), ConnectionResult.timeout);
    expect(ConnectionResult.fromError(TimeoutException('x')), ConnectionResult.timeout);
  });

  test('a refused or unreachable dial is a network error', () {
    expect(ConnectionResult.fromError(const SocketException('Connection refused')), ConnectionResult.networkError);
    expect(ConnectionResult.fromError(Exception('No route to host')), ConnectionResult.networkError);
  });

  test('a refused credential is an auth failure, anything else unknown', () {
    expect(ConnectionResult.fromError(Exception('Permission denied (publickey)')), ConnectionResult.authFailed);
    expect(ConnectionResult.fromError(StateError('odd')), ConnectionResult.unknownError);
  });
}
