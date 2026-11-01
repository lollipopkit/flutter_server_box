part of 'viewer.dart';

extension on ffi.RemoteDesktopFailure {
  String get text => switch (this) {
    ffi.RemoteDesktopFailure.standardRdpSecurityOnly =>
      l10n.remoteDesktopFailStandardRdpSecurityOnly,
    ffi.RemoteDesktopFailure.serverCertificateMissing =>
      l10n.remoteDesktopFailServerCertificateMissing,
    ffi.RemoteDesktopFailure.clientCertificateRequired =>
      l10n.remoteDesktopFailClientCertificateRequired,
    ffi.RemoteDesktopFailure.wrongCredentials =>
      l10n.remoteDesktopFailWrongCredentials,
    ffi.RemoteDesktopFailure.accountLockedOut =>
      l10n.remoteDesktopFailAccountLockedOut,
    ffi.RemoteDesktopFailure.accountDisabled =>
      l10n.remoteDesktopFailAccountDisabled,
    ffi.RemoteDesktopFailure.accountExpired =>
      l10n.remoteDesktopFailAccountExpired,
    ffi.RemoteDesktopFailure.passwordExpired =>
      l10n.remoteDesktopFailPasswordExpired,
    ffi.RemoteDesktopFailure.logonRestricted =>
      l10n.remoteDesktopFailLogonRestricted,
    ffi.RemoteDesktopFailure.remoteLogonDenied =>
      l10n.remoteDesktopFailRemoteLogonDenied,
    ffi.RemoteDesktopFailure.freshCredentialsRequired =>
      l10n.remoteDesktopFailFreshCredentialsRequired,
    ffi.RemoteDesktopFailure.idleTimeout => l10n.remoteDesktopFailIdleTimeout,
    ffi.RemoteDesktopFailure.sessionTimeLimit =>
      l10n.remoteDesktopFailSessionTimeLimit,
    ffi.RemoteDesktopFailure.replacedByOtherConnection =>
      l10n.remoteDesktopFailReplacedByOtherConnection,
    ffi.RemoteDesktopFailure.disconnectedOnServer =>
      l10n.remoteDesktopFailDisconnectedOnServer,
    ffi.RemoteDesktopFailure.loggedOffByAdministrator =>
      l10n.remoteDesktopFailLoggedOffByAdministrator,
    ffi.RemoteDesktopFailure.loggedOff => l10n.remoteDesktopFailLoggedOff,
    ffi.RemoteDesktopFailure.serverShutdown =>
      l10n.remoteDesktopFailServerShutdown,
    ffi.RemoteDesktopFailure.serverReboot => l10n.remoteDesktopFailServerReboot,
    ffi.RemoteDesktopFailure.serverDeniedConnection =>
      l10n.remoteDesktopFailServerDeniedConnection,
    ffi.RemoteDesktopFailure.licensingFailed =>
      l10n.remoteDesktopFailLicensingFailed,
    ffi.RemoteDesktopFailure.vncSecurityUnsupported =>
      l10n.remoteDesktopFailVncSecurityUnsupported,
    ffi.RemoteDesktopFailure.passwordRequired =>
      l10n.remoteDesktopFailPasswordRequired,
  };
}
