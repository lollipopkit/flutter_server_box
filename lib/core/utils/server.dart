import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:toolbox/data/model/app/error.dart';

import '../../data/model/server/server_private_info.dart';
import '../../data/store/private_key.dart';
import '../../locator.dart';

/// Must put this func out of any Class.
///
/// Because of this function is called by [compute].
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

enum GenSSHClientStatus {
  socket,
  key,
  pwd,
}

Future<SSHClient> genClient(
  ServerPrivateInfo spi, {
  void Function(GenSSHClientStatus)? onStatus,
}) async {
  onStatus?.call(GenSSHClientStatus.socket);
  late SSHSocket socket;
  try {
    socket = await SSHSocket.connect(
      spi.ip,
      spi.port,
      timeout: const Duration(seconds: 5),
    );
  } catch (e) {
    try {
      socket = await SSHSocket.connect(
        spi.alterHost!,
        spi.port,
        timeout: const Duration(seconds: 5),
      );
    } catch (e) {
      throw SSHErr(
        type: SSHErrType.connect,
        message: e.toString(),
      );
    }
  }

  if (spi.pubKeyId == null) {
    onStatus?.call(GenSSHClientStatus.pwd);
    return SSHClient(
      socket,
      username: spi.user,
      onPasswordRequest: () => spi.pwd,
    );
  }
  final key = locator<PrivateKeyStore>().get(spi.pubKeyId!);
  if (key == null) {
    throw SSHErr(
      type: SSHErrType.noPrivateKey,
      message: 'key [${spi.pubKeyId}] not found',
    );
  }
  onStatus?.call(GenSSHClientStatus.key);
  return SSHClient(
    socket,
    username: spi.user,
    identities: await compute(loadIndentity, key.privateKey),
  );
}
