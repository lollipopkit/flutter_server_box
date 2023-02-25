import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import '../../data/model/server/server_private_info.dart';
import '../../data/store/private_key.dart';
import '../../locator.dart';

/// Must put this func out of any Class.
///
/// Because of this function is called by [compute] in [ServerProvider.genClient].
///
/// https://stackoverflow.com/questions/51998995/invalid-arguments-illegal-argument-in-isolate-message-object-is-a-closure
List<SSHKeyPair> loadIndentity(String key) {
  return SSHKeyPair.fromPem(key);
}

/// [args] : [key, pwd]
String decyptPem(List<String> args) {
  /// skip when the key is not encrypted, or will throw exception
  if (!SSHKeyPair.isEncryptedPem(args[0])) return args[0];
  final sshKey = SSHKeyPair.fromPem(args[0], args[1]);
  return sshKey.first.toPem();
}

Future<SSHClient> genClient(ServerPrivateInfo spi) async {
  final socket = await SSHSocket.connect(
    spi.ip,
    spi.port,
    timeout: const Duration(seconds: 5),
  );
  if (spi.pubKeyId == null) {
    return SSHClient(
      socket,
      username: spi.user,
      onPasswordRequest: () => spi.pwd,
    );
  }
  final key = locator<PrivateKeyStore>().get(spi.pubKeyId!);
  return SSHClient(
    socket,
    username: spi.user,
    identities: await compute(loadIndentity, key.privateKey),
  );
}
