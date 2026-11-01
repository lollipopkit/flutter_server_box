import 'package:dartssh2/dartssh2.dart' show SSHChannelOpenError;
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/generated/l10n/l10n_en.dart';

void main() {
  final en = AppLocalizationsEn();

  ServerTcpErr dial(Object cause) => ServerTcpErr(
    type: ServerTcpErrType.dial,
    transport: ServerTransport.ssh,
    cause: cause,
  );

  // The reason an sshd gives for a direct-tcpip it will not open: before,
  // a remote desktop showed only `SSHChannelOpenError(1: ...)`.
  test('an SSH channel refused for a reason says what to change', () {
    expect(
      dial(SSHChannelOpenError(1, 'open failed')).solution,
      en.sshTcpForwardingProhibited,
    );
    expect(
      dial(SSHChannelOpenError(2, 'Connection refused')).solution,
      en.tcpTargetUnreachable,
    );
    expect(dial(SSHChannelOpenError(4, 'resource shortage')).solution, isNull);
  });

  test("the Monitor's connect_failed reads the same as sshd's", () {
    expect(
      ServerTcpErr(
        type: ServerTcpErrType.dial,
        transport: ServerTransport.monitorHttp,
        cause: const MonitorHttpErr(
          type: MonitorHttpErrType.targetUnreachable,
        ),
      ).solution,
      en.tcpTargetUnreachable,
    );
  });

  // A Monitor refusing an address is a refused relay, as before, but says
  // which setting to look at rather than that the Monitor relays nothing.
  test('a relay the Monitor refused names its role', () {
    final refused = ServerTcpErr(
      type: ServerTcpErrType.relayNotGranted,
      transport: ServerTransport.monitorHttp,
      cause: const MonitorHttpErr(type: MonitorHttpErrType.relayForbidden),
    );
    expect(refused.solution, en.monitorRelayForbidden);
    expect(refused.retryable, isFalse);
    expect(
      const ServerTcpErr(
        type: ServerTcpErrType.relayNotGranted,
        transport: ServerTransport.monitorHttp,
      ).solution,
      en.monitorNoRemoteAccess,
    );
  });

  test('only a target that may start listening is retried', () {
    expect(dial(SSHChannelOpenError(2, 'Connection refused')).retryable, isTrue);
    expect(dial(SSHChannelOpenError(1, 'open failed')).retryable, isFalse);
  });
}
