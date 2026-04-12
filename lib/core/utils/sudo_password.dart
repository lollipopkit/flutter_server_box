import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/store.dart';

abstract final class SudoPassword {
  static SecureProp secureProp(String serverId) {
    return SecureProp('sudo_pwd_$serverId');
  }

  static Future<String?> readOverride(String serverId) async {
    final value = await secureProp(serverId).read();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static Future<bool> hasOverride(String serverId) async {
    return await readOverride(serverId) != null;
  }

  static Future<void> writeOverride(String serverId, String value) async {
    if (value.isEmpty) {
      await clearOverride(serverId);
      return;
    }
    await secureProp(serverId).write(value);
  }

  static Future<void> clearOverride(String serverId) {
    return secureProp(serverId).write(null);
  }

  static Future<String?> resolveForTerminal(Spi spi) async {
    final override = await readOverride(spi.id);
    if (override != null) return override;

    final pwd = spi.pwd;
    if (pwd == null || pwd.isEmpty) return null;
    return pwd;
  }

  static Future<bool> authenticateIfNeeded() async {
    if (!Stores.setting.useBioAuth.fetch()) return true;
    return await LocalAuth.goWithResult() == AuthResult.success;
  }
}
