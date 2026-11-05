/// `VirtRust.error`: every `sbm_virt::error::Detail` is said in the app's
/// words, and the host's own words are kept where there is none.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/virt/virt_backup.dart';
import 'package:server_box/data/model/virt/virt_rust.dart';
import 'package:server_box/src/rust/api/pve.dart';
import 'package:server_box/src/rust/api/virt_model.dart';

PveError _err(Detail? detail) => PveError(
  kind: VirtFailure.actionFailed,
  message: 'host words',
  detail: detail,
);

void main() {
  final details = <Detail>[
    const Detail.noUser(),
    const Detail.passwordRequired(),
    const Detail.tokenIncomplete(),
    const Detail.otpRequired(),
    const Detail.otpEmpty(),
    const Detail.otpRejected(),
    const Detail.invalidBody(),
    const Detail.invalidData(),
    const Detail.missingTicket(),
    const Detail.noPrivileges(token: true, account: 'root@pam!t', command: 'pveum acl modify'),
    const Detail.notOffered(),
    Detail.taskStillRunning(node: 'pve', upid: 'UPID:pve:1', minutes: BigInt.from(5)),
    const Detail.certNotPresented(),
    const Detail.needsPrivilege(account: 'a', privilege: 'VM.Audit', path: '/vms', command: 'pveum'),
    const Detail.refused(issue: ResourceIssue.nameTaken),
    const Detail.createRefused(issue: CreateIssue.vmidTaken),
    const Detail.hardwareRefused(issue: HwIssue.diskShrink),
    const Detail.backupRefused(issue: BackupIssue.storage),
    const Detail.applyTouchesManagement(ifaces: ['vmbr0']),
    const Detail.applyUnreadable(),
  ];

  test('every detail is said, never as the host words', () {
    for (final d in details) {
      final said = VirtRust.error(_err(d)).message;
      expect(said, isNotEmpty, reason: '$d');
      expect(said, isNot('host words'), reason: '$d');
    }
  });

  test('the values a detail carries are in what it says', () {
    expect(VirtRust.error(_err(details[11])).message, allOf(contains('pve'), contains('5 min'), contains('UPID:pve:1')));
    expect(VirtRust.error(_err(details[18])).message, contains('vmbr0'));
    expect(VirtRust.error(_err(details[17])).message, virtBackupIssueText(BackupIssue.storage));
  });

  test('no detail keeps the host words', () {
    expect(VirtRust.error(_err(null)).message, 'host words');
  });
}
