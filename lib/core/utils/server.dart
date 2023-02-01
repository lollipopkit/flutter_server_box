import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import '../../data/model/server/server_private_info.dart';
import '../../data/store/private_key.dart';
import '../../locator.dart';

/// Must put this func out of any Class.
/// Because of this function is called by [compute] in [ServerProvider.genClient].
/// https://stackoverflow.com/questions/51998995/invalid-arguments-illegal-argument-in-isolate-message-object-is-a-closure
List<SSHKeyPair> loadIndentity(String key) {
  return SSHKeyPair.fromPem(key);
}

Future<SSHClient> genClient(ServerPrivateInfo spi) async {
  final socket = await SSHSocket.connect(spi.ip, spi.port);
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
