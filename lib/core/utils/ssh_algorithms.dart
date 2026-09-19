import 'package:dartssh2/dartssh2.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

/// The algorithm sets this app proposes to a server.
///
/// dartssh2's default is modern-only. RSA host keys are still offered, but only
/// under the RFC 8332 spellings (`rsa-sha2-256`, `rsa-sha2-512`); the SHA-1
/// `ssh-rsa` name it replaced, and the SHA-1 key exchanges, CBC ciphers and
/// SHA-1/MD5 MACs around it, are not in the list at all. That is the right
/// default for anything current, and it is what makes a server that predates
/// those names fail before it can authenticate:
///
/// ```text
/// SSHAuthAbortError(... reason: SSHInternalError(
///   Bad state: No matching host key algorithm))
/// ```
///
/// A router's dropbear, a managed switch, an old embedded appliance — the
/// machine in front of the user is the only place that answer can be known, and
/// it cannot be probed for without answering the second failure behind it, so
/// [SshCredential.allowLegacyAlgorithms] is a per-server choice.
///
/// The retired algorithms are appended *after* the modern ones rather than
/// replacing them, so even on an opted-in host a server that offers anything
/// current still negotiates it. What they cannot do is tell "this daemon has
/// nothing newer" from "an attacker removed everything newer from the list":
/// KEXINIT is unauthenticated, so enabling this gives up that much. That is why
/// it is opt-in, per host, and off everywhere else.
abstract final class SshAlgorithms {
  /// What to propose for [ssh].
  static SSHAlgorithms of(SshCredential ssh) =>
      ssh.allowLegacyAlgorithms ? legacy : const SSHAlgorithms();

  /// The defaults with the algorithms SSH has retired appended.
  ///
  /// Built from a default instance rather than a copied literal, so a change to
  /// the fork's list moves this with it and the two cannot drift apart — the
  /// only thing this adds is the tail, and the order of the tail is the order
  /// the fork itself last proposed these in.
  static final SSHAlgorithms legacy = _withLegacyAlgorithms();
}

SSHAlgorithms _withLegacyAlgorithms() {
  const modern = SSHAlgorithms();
  return SSHAlgorithms(
    kex: [
      ...modern.kex,
      // Group-exchange SHA-1 first: some old daemons offer it and not the fixed
      // groups, and having any group it accepts is what moves past the kex.
      SSHKexType.dhGexSha1,
      SSHKexType.dh14Sha1,
      SSHKexType.dh1Sha1,
    ],
    hostkey: [...modern.hostkey, SSHHostkeyType.rsaSha1],
    cipher: [
      ...modern.cipher,
      SSHCipherType.aes256cbc,
      SSHCipherType.aes128cbc,
    ],
    mac: [
      ...modern.mac,
      SSHMacType.hmacSha1,
      SSHMacType.hmacMd5,
      SSHMacType.hmacSha256_96,
      SSHMacType.hmacSha512_96,
    ],
  );
}
