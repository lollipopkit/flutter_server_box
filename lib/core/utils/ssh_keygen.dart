import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:pinenacl/ed25519.dart' as ed25519;
import 'package:pointycastle/export.dart';

/// The algorithms this app will make a key with.
///
/// Not everything OpenSSH understands: DSA is long dead, and ECDSA P-384 and
/// P-521 are the same trade-off as P-256 with a longer key, which nobody needs
/// a phone to choose between. What is here is one modern default and the two
/// answers to "the server will not take that" — an older RSA-only sshd, and a
/// policy that requires NIST curves.
enum SshKeyAlgorithm {
  /// The default, and the right answer unless something refuses it: small
  /// keys, fast signatures, and no parameters to get wrong.
  ed25519,
  ecdsaP256,
  rsa2048,
  rsa4096;

  /// What the public key calls itself, which is also what goes at the start of
  /// an `authorized_keys` line.
  String get keyType => switch (this) {
    ed25519 => 'ssh-ed25519',
    ecdsaP256 => 'ecdsa-sha2-nistp256',
    rsa2048 || rsa4096 => 'ssh-rsa',
  };

  /// Roughly how long generating one takes, which is the only reason a person
  /// would want to know: RSA searches for primes and the others do not.
  bool get isSlow => this == rsa2048 || this == rsa4096;
}

/// A key pair that has just been made, in the two forms it is needed in.
@immutable
class GeneratedSshKey {
  const GeneratedSshKey({required this.privatePem, required this.publicLine});

  /// `OPENSSH PRIVATE KEY`, encrypted when a passphrase was given.
  final String privatePem;

  /// One `authorized_keys` line: `<type> <base64> <comment>`.
  final String publicLine;
}

/// Makes a key pair.
///
/// On another isolate, because RSA is a search for primes and takes long enough
/// to drop frames — about a second for 4096 bits on a desktop, and several on a
/// phone. The others are instant and go the same way rather than having two
/// paths.
Future<GeneratedSshKey> generateSshKey({
  required SshKeyAlgorithm algorithm,
  required String comment,
  String? passphrase,
}) async {
  final result = await compute(generateSshKeyPair, [
    algorithm.name,
    comment,
    passphrase ?? '',
  ]);
  return GeneratedSshKey(privatePem: result[0], publicLine: result[1]);
}

/// The isolate half of [generateSshKey].
///
/// Top-level and stringly-typed for the same reason `decryptPem` is: what goes
/// to another isolate is sent, not captured, so it has to be a plain value and
/// a plain function.
///
/// [args] : [algorithm name, comment, passphrase — empty for none]
/// Returns: [private PEM, public key line]
List<String> generateSshKeyPair(List<String> args) {
  final algorithm = SshKeyAlgorithm.values.byName(args[0]);
  final comment = args[1];
  final passphrase = args[2];

  final pair = switch (algorithm) {
    SshKeyAlgorithm.ed25519 => _ed25519(comment),
    SshKeyAlgorithm.ecdsaP256 => _ecdsaP256(comment),
    SshKeyAlgorithm.rsa2048 => _rsa(2048, comment),
    SshKeyAlgorithm.rsa4096 => _rsa(4096, comment),
  };

  return [
    pair.toPem(passphrase: passphrase.isEmpty ? null : passphrase),
    publicKeyLine(pair, comment),
  ];
}

/// One `authorized_keys` line for [pair].
///
/// The type is read back out of the encoded public key rather than taken from
/// the algorithm that was asked for, so the line cannot disagree with the bytes
/// beside it — and an RSA pair is the case that would: it signs as
/// `rsa-sha2-256` while its public key is still `ssh-rsa`.
///
/// Takes any [SSHKeyPair], not only the OpenSSH ones this file makes: the same
/// line is what a key imported in the older `RSA PRIVATE KEY` form needs, and
/// deriving it is the only way to see the public half of a key the app holds.
String publicKeyLine(SSHKeyPair pair, String comment) {
  final blob = pair.toPublicKey().encode();
  final line = '${SSHHostKey.getType(blob)} ${base64.encode(blob)}';
  final trimmed = comment.trim();
  return trimmed.isEmpty ? line : '$line $trimmed';
}

OpenSSHEd25519KeyPair _ed25519(String comment) {
  final signing = ed25519.SigningKey.generate();
  // 64 bytes — the seed followed by the public key — which is the form the
  // OpenSSH format stores and the form `sign` reads back.
  return OpenSSHEd25519KeyPair(
    Uint8List.fromList(signing.verifyKey.asTypedList),
    Uint8List.fromList(signing.asTypedList),
    comment,
  );
}

OpenSSHEcdsaKeyPair _ecdsaP256(String comment) {
  final generator = ECKeyGenerator()
    ..init(
      ParametersWithRandom(
        ECKeyGeneratorParameters(ECCurve_secp256r1()),
        _seededRandom(),
      ),
    );
  final pair = generator.generateKeyPair();
  final public = pair.publicKey;
  final private = pair.privateKey;
  return OpenSSHEcdsaKeyPair(
    'nistp256',
    // Uncompressed: `0x04 || X || Y`, which is the only encoding the SSH wire
    // format uses for a point.
    public.Q!.getEncoded(false),
    private.d!,
    comment,
  );
}

OpenSSHRsaKeyPair _rsa(int bits, String comment) {
  final generator = RSAKeyGenerator()
    ..init(
      ParametersWithRandom(
        // 65537, and the 64 is the Miller-Rabin certainty pointycastle's own
        // examples use.
        RSAKeyGeneratorParameters(BigInt.from(65537), bits, 64),
        _seededRandom(),
      ),
    );
  final pair = generator.generateKeyPair();
  final public = pair.publicKey;
  final private = pair.privateKey;
  final p = private.p!;
  final q = private.q!;
  return OpenSSHRsaKeyPair(
    public.modulus!,
    public.publicExponent!,
    private.privateExponent!,
    // `iqmp` is q's inverse mod p, in that order. Swapping the two produces a
    // key that still round-trips through this app and that ssh-keygen rejects.
    q.modInverse(p),
    p,
    q,
    comment,
  );
}

/// A CSPRNG for pointycastle, seeded from the platform's.
///
/// Fortuna needs a seed and will happily take a predictable one, which for key
/// material is the whole game. [Random.secure] is the platform generator.
SecureRandom _seededRandom() {
  final secure = Random.secure();
  return FortunaRandom()
    ..seed(
      KeyParameter(
        Uint8List.fromList(List<int>.generate(32, (_) => secure.nextInt(256))),
      ),
    );
}

/// What a stored private key says about itself.
@immutable
class SshKeyDigest {
  const SshKeyDigest({this.keyType, this.fingerprint, this.comment});

  /// `ssh-ed25519`, `ssh-rsa`, … Taken from the public key rather than the PEM
  /// header, which only names the container it is in — every modern key says
  /// `OPENSSH` there whatever it holds.
  final String? keyType;

  /// `SHA256:…`, in the form `ssh-keygen -l` prints: the digest base64'd with
  /// its padding removed.
  final String? fingerprint;

  /// Null when the key is encrypted, and for the older PEM forms that have no
  /// such field. The comment lives inside the part that gets encrypted, while
  /// the public key does not — which is why a locked key can still be
  /// fingerprinted.
  final String? comment;

  bool get isEmpty => keyType == null && fingerprint == null && comment == null;
}

/// Reads [pem] for what can be shown about it in a list.
///
/// Never throws and never asks for a passphrase: this is for a subtitle, and a
/// key that cannot be read is one whose subtitle is empty, not an error.
SshKeyDigest describeSshKey(String pem) {
  try {
    final decoded = SSHPem.decode(pem);
    if (decoded.type == 'OPENSSH PRIVATE KEY') {
      final pairs = OpenSSHKeyPairs.decode(decoded.content);
      final blob = pairs.publicKeys.isEmpty ? null : pairs.publicKeys.first;
      // Read without opening anything: `publicKeys` sits outside the encrypted
      // blob, so this works for a key nobody has unlocked.
      return SshKeyDigest(
        keyType: blob == null ? null : SSHHostKey.getType(blob),
        fingerprint: blob == null ? null : sshKeyFingerprint(blob),
        comment: pairs.isEncrypted ? null : _commentOf(pairs.getPrivateKeys()),
      );
    }
    // The older forms keep no public key of their own, so there is nothing to
    // read without opening the key — which is not something a list may do.
    if (SSHKeyPair.isEncryptedPem(pem)) return const SshKeyDigest();
    final blob = SSHKeyPair.fromPem(pem).first.toPublicKey().encode();
    return SshKeyDigest(
      keyType: SSHHostKey.getType(blob),
      fingerprint: sshKeyFingerprint(blob),
    );
  } catch (_) {
    return const SshKeyDigest();
  }
}

/// The fingerprint of an encoded public key, as `ssh-keygen -l` prints it.
String sshKeyFingerprint(Uint8List publicKeyBlob) {
  final digest = sha256.convert(publicKeyBlob).bytes;
  // Unpadded, which is what OpenSSH prints — a trailing `=` would make the
  // string not match what the server's own tooling shows.
  final encoded = base64.encode(digest).replaceAll('=', '');
  return 'SHA256:$encoded';
}

String? _commentOf(List<SSHKeyPair> pairs) {
  if (pairs.isEmpty) return null;
  final comment = switch (pairs.first) {
    OpenSSHEd25519KeyPair(:final comment) => comment,
    OpenSSHRsaKeyPair(:final comment) => comment,
    OpenSSHEcdsaKeyPair(:final comment) => comment,
    _ => null,
  };
  return comment == null || comment.trim().isEmpty ? null : comment.trim();
}
