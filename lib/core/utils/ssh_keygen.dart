import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:computer/computer.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:meta/meta.dart';
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
  final result = await Computer.shared.start(generateSshKeyPair, [
    algorithm.name,
    comment,
    passphrase ?? '',
  ]);
  return GeneratedSshKey(privatePem: result[0], publicLine: result[1]);
}

/// The isolate half of [generateSshKey].
///
/// Top-level and stringly-typed for the same reason `decryptPem` is: a
/// [Computer] task is a closure sent to another isolate, and what crosses has
/// to be a plain value.
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
@visibleForTesting
String publicKeyLine(OpenSSHKeyPair pair, String comment) {
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
