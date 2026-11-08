import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/store/sync_recorder.dart';
import 'package:webdav_client_plus/webdav_client_plus.dart';

/// The WebDAV and the gist the backup syncs to, kept in `Stores.syncRemote`
/// and synced with the secrets: set up on one device, set up on every one.
/// Which one syncs stays each device's own (`PrefProps.webdavSync`,
/// `PrefProps.gistSync`).
abstract final class SyncRemotes {
  static const _url = 'webdavUrl';
  static const _user = 'webdavUser';
  static const _pwd = 'webdavPwd';
  static const _gistId = 'gistId';
  static const _token = 'githubToken';

  static String? _get(String key) {
    final v = Stores.syncRemote.get<String>(key);
    return v == null || v.isEmpty ? null : v;
  }

  static void _set(String key, String? value) {
    if (value == null || value.isEmpty) {
      Stores.syncRemote.remove(key);
    } else if (_get(key) != value) {
      Stores.syncRemote.set(key, value);
    }
  }

  static String? get webdavUrl => _get(_url);
  static String? get webdavUser => _get(_user);
  static String? get webdavPwd => _get(_pwd);
  static String? get gistId => _get(_gistId);
  static String? get githubToken => _get(_token);

  static void setWebdav({required String url, required String user, required String pwd}) {
    _set(_url, url);
    _set(_user, user);
    _set(_pwd, pwd);
  }

  static void setGist({required String token, required String? id}) {
    _set(_token, token);
    _set(_gistId, id);
  }

  static Webdav? _webdav;
  static (String?, String?, String?)? _webdavOf;

  /// A new one when the settings changed (another device's, through sync):
  /// one already in use keeps the server it began with. Its client is null
  /// until an address is set.
  static Webdav get webdav {
    final of = (webdavUrl, webdavUser, webdavPwd);
    if (_webdav case final w? when of == _webdavOf) return w;
    _webdavOf = of;
    final (url, user, pwd) = of;
    return _webdav = Webdav(
      client: url == null ? null : WebdavClient.basicAuth(url: url, user: user ?? '', pwd: pwd ?? ''),
    );
  }

  static GistRs? _gist;
  static (String?, String?)? _gistOf;

  /// As [webdav]. A gist the first upload creates is kept here.
  static GistRs get gist {
    final of = (gistId, githubToken);
    if (_gist case final g? when of == _gistOf) return g;
    _gistOf = of;
    return _gist = GistRs(
      gistId: of.$1,
      token: of.$2,
      onCreated: (id) async => _set(_gistId, id),
    );
  }

  /// Moves what builds before kept in the preferences and the keychain into
  /// the store, and removes it there; once, or again at the next launch for
  /// what the keychain did not give. As no device's edit
  /// ([SyncRecorder.adopt]): one made on any device wins over it.
  /// TODO: remove with [_adopted] once no install can still hold them.
  static Future<void> adopt() async {
    if (_adopted.get()) return;
    var done = true;
    Future<String?> secret(SecureProp prop, PrefProp<String> legacy) async {
      try {
        // ignore: deprecated_member_use
        return await prop.read() ?? legacy.get();
      } catch (e, s) {
        done = false;
        Loggers.app.warning('Read ${prop.key} to move it into the store', e, s);
        return null;
      }
    }

    final values = [
      (_url, PrefProps.webdavUrl.get()),
      (_user, PrefProps.webdavUser.get()),
      (_gistId, PrefProps.gistId.get()),
      // ignore: deprecated_member_use
      (_pwd, await secret(SecureStoreProps.webdavPwd, PrefProps.webdavPwd)),
      // ignore: deprecated_member_use
      (_token, await secret(SecureStoreProps.githubToken, PrefProps.githubToken)),
    ];
    SqliteStore.transact(() {
      for (final (key, value) in values) {
        if (_get(key) == null && value != null && value.isNotEmpty) SyncRecorder.adopt(Stores.syncRemote, key, value);
      }
    });
    for (final prop in [PrefProps.webdavUrl, PrefProps.webdavUser, PrefProps.gistId]) {
      await prop.remove();
    }
    if (!done) return;
    try {
      await SecureStoreProps.webdavPwd.write(null);
      await SecureStoreProps.githubToken.write(null);
      // ignore: deprecated_member_use
      await PrefProps.webdavPwd.remove();
      // ignore: deprecated_member_use
      await PrefProps.githubToken.remove();
      await _adopted.set(true);
    } catch (e, s) {
      Loggers.app.warning('Remove the WebDAV password and GitHub token from the keychain', e, s);
    }
  }

  static const _adopted = PrefPropDefault('sync_remote_adopted', false, updateLastUpdateTsOnSetProp: false);
}
