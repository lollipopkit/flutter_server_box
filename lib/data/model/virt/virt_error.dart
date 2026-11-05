import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/virt/virt_backup.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_manage.dart';
import 'package:server_box/src/rust/api/pve.dart';
import 'package:server_box/src/rust/api/virt_model.dart' as vm;

extension PveErrorVirt on PveError {
  /// `sbm_virt::error::Error` as this app phrases it. What `sbm_virt` leaves
  /// to the caller ([PveError.detail]) is said in the user's language; the
  /// host's own words otherwise.
  VirtErr get virt {
    final type = switch (kind) {
      VirtFailure.unreachable => VirtErrType.unreachable,
      VirtFailure.notConfigured => VirtErrType.notConfigured,
      VirtFailure.authFailed => VirtErrType.authFailed,
      VirtFailure.needTfa => VirtErrType.needTfa,
      VirtFailure.certUnconfirmed => VirtErrType.certUnconfirmed,
      VirtFailure.certChanged => VirtErrType.certChanged,
      VirtFailure.permissionDenied => VirtErrType.permissionDenied,
      VirtFailure.invalidResponse => VirtErrType.invalidResponse,
      VirtFailure.actionFailed => VirtErrType.actionFailed,
      VirtFailure.unsupported => VirtErrType.unsupported,
      VirtFailure.exists => VirtErrType.exists,
      VirtFailure.conflict => VirtErrType.conflict,
      VirtFailure.notInstalled => VirtErrType.notInstalled,
      VirtFailure.sudoPasswordRequired => VirtErrType.sudoPasswordRequired,
      VirtFailure.sudoPasswordRejected => VirtErrType.sudoPasswordRejected,
      VirtFailure.closed || VirtFailure.unknown => VirtErrType.unknown,
    };
    final text = switch (detail) {
      null => message,
      vm.Detail_NoUser() => 'No user to log in to PVE as. Use an API token.',
      vm.Detail_PasswordRequired() => l10n.pvePasswordRequired,
      vm.Detail_TokenIncomplete() => 'The PVE API token is incomplete',
      vm.Detail_OtpRequired() => l10n.pveOtpRequired,
      vm.Detail_OtpEmpty() => l10n.pveOtpCodeRequired,
      vm.Detail_OtpRejected() => l10n.pveOtpVerificationFailed,
      vm.Detail_InvalidBody() => l10n.pveInvalidResponseBody,
      vm.Detail_InvalidData() => l10n.pveInvalidResponseData,
      vm.Detail_MissingTicket() => l10n.pveMissingAuthTicket,
      vm.Detail_NoPrivileges(:final token, :final account, :final command) =>
        token
            ? l10n.pveTokenNoPrivileges(account, command)
            : l10n.pveUserNoPrivileges(account, command),
      vm.Detail_TaskStillRunning(:final node, :final upid, :final minutes) =>
        'Still running on $node after $minutes min; '
            'its task log on the host says how it ends: $upid',
      vm.Detail_NeedsPrivilege(:final account, :final privilege, :final path, :final command) =>
        l10n.pveNeedsPrivilege(account, privilege, path, command),
      vm.Detail_Refused(:final issue) => virtResIssueText(VirtResIssue.of(issue)),
      vm.Detail_CreateRefused(:final issue) => virtCreateIssueText(VirtCreateIssue.of(issue)),
      vm.Detail_HardwareRefused(:final issue) => virtHwIssueText(VirtHwIssue.of(issue)),
      vm.Detail_BackupRefused(:final issue) => virtBackupIssueText(issue),
      vm.Detail_ApplyTouchesManagement(:final ifaces) =>
        'The pending configuration changes ${ifaces.join(', ')}, which '
            "carries the host's management traffic: apply it from the "
            "host's console or PVE's own interface",
      vm.Detail_ApplyUnreadable() =>
        'Which interfaces the pending configuration changes cannot be told '
            "from its diff: apply it from the host's console or PVE's own "
            'interface',
      vm.Detail_CertNotPresented() => 'That certificate was not presented by this server',
      vm.Detail_NotOffered() => 'Not offered for this guest',
    };
    final cert = this.cert;
    return VirtErr(
      type: type,
      message:
          (type == VirtErrType.certUnconfirmed ||
                  type == VirtErrType.certChanged) &&
              cert != null
          ? cert.prettyFingerprint
          : text,
      cert: cert,
      previousFingerprint: previousFingerprint,
      cause: this,
    );
  }
}
