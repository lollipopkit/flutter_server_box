import 'dart:io';

import 'package:fl_lib/fl_lib.dart';

/// What each server said its own address is, per server.
///
/// **Keyed by server id, and that is the whole reason this store exists.**
/// The host this answer belongs to is the private one the app connects at,
/// which `IpGeo.locateHost` refuses before doing anything — so an entry keyed
/// by it could be written and never read. Keying by the *public* address
/// instead loses the thing that matters: nothing would remember which server
/// that address belongs to, so the next launch would have to ask again to find
/// out which key to look under.
///
/// What has to be remembered is server → address. That is a property of the
/// server, not of a host string.
///
/// A miss is stored too, as a null address. A machine behind NAT has no public
/// address and will not grow one; without recording that, every launch would
/// re-read every LAN server's interfaces to reach the same answer.
///
/// **The address, deliberately, and not the coordinate.** This is the only
/// thing the globe remembers now: the store that held where each *host* was
/// went with the per-lookup network requests it existed for — see
/// `IpGeo.resolve`. What is kept here is the half that cannot be worked out
/// again, since only the machine knows which public address is assigned to one
/// of its interfaces. The coordinate is looked up fresh every time, so it
/// follows the installed month rather than outliving it.
///
/// Never counts as a user edit and is not synced: it is derived, device-local,
/// and rebuildable by asking again.
class SelfAddrStore extends SqliteStore {
  SelfAddrStore([super.storeName = 'self_addr'])
    : super(
        updateLastUpdateTsOnSet: false,
        updateLastUpdateTsOnRemove: false,
        updateLastUpdateTsOnClear: false,
      );

  static final instance = SelfAddrStore();

  /// How long an answer is trusted before the server is asked again.
  ///
  /// A machine's address changes when it moves or its lease does, which is
  /// rare and not urgent. After this interval, a later extended status poll
  /// can replace the record. Long enough that a laptop opening the app daily
  /// does not repeat the same collection every time.
  static const staleAfter = Duration(days: 7);

  /// The address recorded for [id], or null when there is none — whether
  /// because nothing has asked yet or because the answer was that it has none.
  /// Use [probedAt] to tell those apart.
  InternetAddress? addrOf(String id) {
    final raw = get<Map>(id);
    final text = raw?['addr'];
    if (text is! String || text.isEmpty) return null;
    // Parsed rather than trusted: this came off a server's stdout, and a build
    // that once stored something else should not become a crash now.
    return InternetAddress.tryParse(text);
  }

  /// When [id] was last asked, or null if it never was.
  DateTime? probedAt(String id) {
    final at = get<Map>(id)?['at'];
    if (at is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(at);
  }

  /// Whether [id] is worth asking, now.
  bool isStale(String id) {
    final at = probedAt(id);
    if (at == null) return true;
    return DateTime.now().difference(at) >= staleAfter;
  }

  /// Records what [id] answered. A null [addr] means it has no public address,
  /// which is an answer and is stored as one.
  bool put(String id, InternetAddress? addr) => set(id, {
    'addr': addr?.address,
    'at': DateTime.now().millisecondsSinceEpoch,
  });

  bool rename(String from, String to) {
    final raw = get<Map>(from);
    if (raw == null) return true;
    if (!set(to, raw)) return false;
    return remove(from);
  }

  void forget(String id) => remove(id);

  /// How many servers have been asked.
  int get count => keys().length;
}
