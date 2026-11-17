/// Which notice a machine with nothing to show gets, where a plaintext
/// Monitor address is involved.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/view/page/server/card/notices.dart';

void main() {
  ServerState state(MonitorHttpCredential monitor, {Err? err}) {
    final status = InitStatus.status..err = err;
    return ServerState(
      spi: Spi(name: 'a', id: 'a', monitorHttp: monitor),
      status: status,
    );
  }

  const failed = MonitorHttpErr(type: MonitorHttpErrType.net, message: 'Connection refused');

  test('a plaintext address takes the page before anything is dialled', () {
    final notice = ServerNotice.of(
      state(const MonitorHttpCredential(addr: 'http://10.0.0.1:3770'), err: failed),
    );
    expect(notice.kind, ServerNoticeKind.plainHttp);
    expect(notice.mono, 'http://10.0.0.1:3770');
  });

  // The fallback is simply not used until allowed: what failed is the address
  // that was dialled, and that is what is said.
  test('a plaintext fallback leaves the address\'s own failure in front', () {
    final notice = ServerNotice.of(
      state(
        const MonitorHttpCredential(
          addr: 'https://a.example:3770',
          fallbackAddr: 'http://100.64.0.1:3770',
        ),
        err: failed,
      ),
    );
    expect(notice.kind, ServerNoticeKind.failed);
    expect(notice.mono, 'Connection refused');
    expect(notice.hint, '${l10n.plainHttpTitle}: http://100.64.0.1:3770');
  });
}
