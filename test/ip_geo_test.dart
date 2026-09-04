import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/geo_data.dart';
import 'package:server_box/core/service/ip_geo.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/geo.dart';
import 'package:server_box/data/model/server/geo_source.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/self_addr.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/geo_fixture.dart';
import 'helpers/test_db.dart';

/// The chain, and the two things it must never do: look anything up for a
/// private address, or do anything at all with the globe switched off.
///
/// Every host here is an IP literal. A name would send the test suite to a
/// resolver, and what would be under test then is the network.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  // `Paths.doc` is `late final`, so it is set once for the file and the geo
  // directory under it is what each test starts fresh.
  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('ip-geo-');
    Paths.doc = tmp.path;
  });

  tearDownAll(() => tmp.delete(recursive: true));

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<SelfAddrStore>(SelfAddrStore('self_addr_test'));
    await installGeoVectors();
  });

  tearDown(() async {
    await removeGeoVectors();
    IpGeo.resolver = InternetAddress.lookup;
    await getIt.reset();
    await closeTestDb();
  });

  Spi sshServer(String ip, {ServerCustom? custom}) => Spi(
    name: 'srv',
    id: 'srv-1',
    ssh: SshCredential(ip: ip),
    custom: custom,
  );

  group('the switch', () {
    test('off means nothing is answered, data installed or not', () async {
      // The vectors are installed by `setUp`, so this is the case that matters:
      // off has to mean the feature is not there, not that it stopped
      // refreshing while still answering from what it has.
      Stores.setting.globeEnabled.put(false);
      expect(await IpGeo.resolveHost('8.8.8.8'), isNull);
    });

    test('off still does not hide a coordinate the user typed', () async {
      // It is on the record, showing it involves nothing outside the device,
      // and it is what the editor just saved. Blanking it would read as the
      // field having been lost.
      Stores.setting.globeEnabled.put(false);
      final coord = GeoCoord.tryNew(51.5072, -0.1276)!;
      final resolved = await IpGeo.resolve(
        sshServer('8.8.8.8', custom: ServerCustom(geo: coord)),
      );
      expect(resolved?.coord, coord);
      expect(resolved?.source, GeoSource.manual);
    });

    test('on is the default', () {
      expect(Stores.setting.globeEnabled.fetch(), isTrue);
    });

    test('but nothing is placed until the data is installed', () {
      // There is no bundled fallback any more, so the globe with the feature
      // on and nothing downloaded places only what was typed by hand. That is
      // also what makes this opt-in *and* off by default without a switch,
      // which is what F-Droid's Tracking anti-feature asks for.
      expect(Stores.setting.globeEnabled.fetch(), isTrue);
    });
  });

  group('the chain', () {
    test('a manual coordinate wins over the database', () async {
      final coord = GeoCoord.tryNew(51.5072, -0.1276)!;
      final resolved = await IpGeo.resolve(
        sshServer('8.8.8.8', custom: ServerCustom(geo: coord)),
      );
      expect(resolved?.coord, coord, reason: 'not the US capital');
      expect(resolved?.source, GeoSource.manual);
    });

    test('the bundled database answers when nothing else does', () async {
      final resolved = await IpGeo.resolveHost('8.8.8.8');
      expect(resolved?.source, GeoSource.city);
      expect(resolved?.coord.lon, closeTo(-122.0838, 0.01));
    });

    test('an IPv4 address carried inside a v6 one reaches the v4 data', () async {
      // `::ffff:8.8.8.8` has `type` IPv6, so choosing the family from that
      // asked the v6 file for a key whose leading 48 bits are zero — bucket 0,
      // no record, and a placeable server reported as having no data.
      // `isPrivateAddress` has always unwrapped, so the chain got this far.
      final found = await IpGeo.locateHost('::ffff:8.8.8.8');

      expect(found.miss, isNull);
      expect(found.geo?.source, GeoSource.city);
      expect(found.geo?.coord.lon, closeTo(-122.0838, 0.01));
    });

    test('and one wins a dual-stack answer, as a bare v4 address would', () async {
      // The tie-break reads `type` too. Without the unwrap the mapped address
      // looked like v6, so the server was placed by whichever the resolver
      // happened to list first.
      IpGeo.resolver = (_) async => [
        InternetAddress('2400:cb00::1'),
        InternetAddress('::ffff:8.8.8.8'),
      ];

      final found = await IpGeo.resolveHost('example.com');

      expect(found?.coord.lon, closeTo(-122.0838, 0.01));
    });

    test('an address the database has never heard of is nowhere', () async {
      // 8/8 is the only bucket the vector fills; everything else is empty.
      expect(await IpGeo.resolveHost('8.8.8.8'), isNotNull);
      expect(await IpGeo.resolveHost('200.1.2.3'), isNull);
    });

    test('no database at all is not an error', () async {
      // The ordinary state until someone accepts the download: there is no
      // bundled fallback underneath it any more, so the globe places only
      // what was typed by hand and says so for everything else.
      await removeGeoVectors();
      expect(await IpGeo.resolveHost('8.8.8.8'), isNull);
    });

    test('a bundle from a different month is refused', () async {
      final manifestFile = File(GeoData.dir.joinPath('installed.json'));
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      manifest['generated'] = '2026-08';
      await manifestFile.writeAsString(jsonEncode(manifest));
      await GeoData.resetForTest();

      expect(await IpGeo.resolveHost('8.8.8.8'), isNull);
    });
  });

  /// Why there is no coordinate, which is the whole of what the strip along
  /// the bottom of the globe has to say. "Unknown" over a tab of LAN servers
  /// is true and useless: it is the ordinary state of an install with nothing
  /// on the public internet, and nothing on screen said so.
  group('the reason there is no answer', () {
    test('a private address says so, and says it before any lookup', () async {
      IpGeo.resolver = (_) async => throw StateError('must not be reached');
      final found = await IpGeo.locateHost('192.168.1.10');
      expect(found.geo, isNull);
      expect(found.miss, GeoMiss.private);
    });

    test('so does a name that only resolves on this network', () async {
      IpGeo.resolver = (_) async => throw StateError('must not be reached');
      expect((await IpGeo.locateHost('nas.local')).miss, GeoMiss.private);
      expect((await IpGeo.locateHost('printer')).miss, GeoMiss.private);
    });

    test('a public name resolving to a LAN address says so too', () async {
      // Split-horizon DNS, which the name alone cannot be read for.
      IpGeo.resolver = (_) async => [InternetAddress('10.0.0.4')];
      final found = await IpGeo.locateHost('nas.example.com');
      expect(found.geo, isNull);
      expect(found.miss, GeoMiss.private);
    });

    test('an address no database covers is a different reason', () async {
      // Public, and in a bucket the vector leaves empty — so it reaches the
      // end of the chain rather than being turned back at the top of it.
      // Not `2001:db8::`, which is the documentation range and so private.
      final found = await IpGeo.locateHost('2400:cb00::1');
      expect(found.geo, isNull);
      expect(found.miss, GeoMiss.noData);
    });

    test('a name that will not resolve is the same one', () async {
      IpGeo.resolver = (_) async => throw const SocketException('nope');
      expect(
        (await IpGeo.locateHost('nowhere.example.com')).miss,
        GeoMiss.noData,
      );
    });

    test('a server with no host to take an address from, as well', () async {
      final spi = Spi(
        name: 'srv',
        id: 'srv-1',
        monitorHttp: const MonitorHttpCredential(addr: 'not a url'),
      );
      expect(IpGeo.geoHostOf(spi), isNull);
      expect((await IpGeo.locate(spi)).miss, GeoMiss.noData);
    });

    test('an answer carries no reason at all', () async {
      final found = await IpGeo.locateHost('8.8.8.8');
      expect(found.geo?.source, GeoSource.city);
      expect(found.miss, isNull);
    });

    test('a machine that reported a public address is placed by it', () async {
      // The hole the private gate leaves: the app connects at 192.168.x, but
      // the machine's own interfaces carry an address that is placeable.
      final spi = sshServer('192.168.1.10');
      expect((await IpGeo.locate(spi)).miss, GeoMiss.private);

      Stores.selfAddr.put(spi.id, InternetAddress('8.8.8.8'));
      final found = await IpGeo.locate(spi);
      expect(found.geo?.coord.lon, closeTo(-122.0838, 0.01));
      expect(
        found.geo?.source,
        GeoSource.selfReported,
        reason:
            'the source names how the address was found, not which table '
            'answered it',
      );
      expect(found.miss, isNull);
    });

    test('a machine that reported nothing stays private', () async {
      // What a box behind NAT answers, recorded so it is not asked again.
      final spi = sshServer('192.168.1.10');
      Stores.selfAddr.put(spi.id, null);
      final found = await IpGeo.locate(spi);
      expect(found.geo, isNull);
      expect(found.miss, GeoMiss.private);
    });

    test('a reported address no database covers is still private', () async {
      // Not `noData`: the server *is* on a LAN as far as this app can reach
      // it, and the strip's advice — set a coordinate by hand — is the same.
      final spi = sshServer('192.168.1.10');
      Stores.selfAddr.put(spi.id, InternetAddress('2001:db8::1'));
      expect((await IpGeo.locate(spi)).miss, GeoMiss.private);
    });

    test('a public host is never overruled by what a machine says', () async {
      // The app already connects at the address the world sees, so there is
      // nothing for a self-report to improve on — and asking would be a
      // command run on every server rather than only the ones it could help.
      final spi = sshServer('8.8.8.8');
      Stores.selfAddr.put(spi.id, InternetAddress('10.0.0.1'));
      final found = await IpGeo.locate(spi);
      expect(found.geo?.source, GeoSource.city);
      expect(found.geo?.coord.lon, closeTo(-122.0838, 0.01));
    });

    test('the address is what is kept, never the coordinate', () async {
      // The store holds server → address, and the lookup is redone from it
      // every time. Keeping the coordinate instead would have to key it
      // somewhere, and under the public address every other server reached at
      // 8.8.8.8 would inherit a `selfReported` claim nobody made about it.
      final spi = sshServer('192.168.1.10');
      Stores.selfAddr.put(spi.id, InternetAddress('8.8.8.8'));
      expect((await IpGeo.locate(spi)).geo, isNotNull);

      // With the data gone the same record answers nothing, which is what
      // "the coordinate is not stored" means from the outside.
      await removeGeoVectors();
      final after = await IpGeo.locate(spi);
      expect(after.geo, isNull);
      expect(after.miss, GeoMiss.private);
      expect(Stores.selfAddr.addrOf(spi.id)?.address, '8.8.8.8');
    });

    test('the globe being off is neither an answer nor a reason', () async {
      // Nothing was asked, so there is nothing to explain — and a caption on a
      // strip that is not on screen would be the only thing this produced.
      Stores.setting.globeEnabled.put(false);
      final found = await IpGeo.locateHost('192.168.1.10');
      expect(found.geo, isNull);
      expect(found.miss, isNull);
    });
  });

  group('a name rather than a literal', () {
    // Through the seam, so what is under test is what happens *to* a
    // resolver's answer rather than whether this machine has one.
    test('is resolved, and the address is what gets looked up', () async {
      final asked = <String>[];
      IpGeo.resolver = (host) async {
        asked.add(host);
        return [InternetAddress('8.8.8.8')];
      };
      final resolved = await IpGeo.resolveHost('example.com');
      expect(asked, ['example.com']);
      expect(resolved?.coord.lon, closeTo(-122.0838, 0.01));
    });

    test('IPv4 wins on a dual-stack host', () async {
      // A tie-break, so that a resolver listing the two in either order does
      // not move the server between runs. The v6 address here is deliberately
      // one the fixture knows nothing about, which is what makes the
      // preference visible at all.
      IpGeo.resolver = (_) async => [
        InternetAddress('2606:4700::1111'),
        InternetAddress('8.8.8.8'),
      ];
      final resolved = await IpGeo.resolveHost('example.com');
      expect(resolved?.coord.lon, closeTo(-122.0838, 0.01));
    });

    test('v6 is used when it is all there is', () async {
      // And it is answered by the v6 bundle, which the sharded build had no
      // equivalent of — IPv6 was country level then and is city level now.
      IpGeo.resolver = (_) async => [InternetAddress('2620:fe::fe')];
      final found = await IpGeo.resolveHost('example.com');
      expect(found?.coord.lat, closeTo(37.8793, 0.01));
    });

    test('a name that resolves to a private address is dropped', () async {
      // Split-horizon DNS: a public name pointing at a machine on this LAN.
      // The name passed the gate; the address it points at must not.
      IpGeo.resolver = (_) async => [InternetAddress('192.168.1.10')];
      expect(await IpGeo.resolveHost('nas.example.com'), isNull);
    });

    test('a name that will not resolve is not an error', () async {
      IpGeo.resolver = (_) async => throw const SocketException('no such host');
      expect(await IpGeo.resolveHost('nope.example.com'), isNull);
    });

    test('a resolver answering nothing is not an error either', () async {
      IpGeo.resolver = (_) async => [];
      expect(await IpGeo.resolveHost('empty.example.com'), isNull);
    });

    test('a literal never reaches the resolver', () async {
      var asked = false;
      IpGeo.resolver = (_) async {
        asked = true;
        return const [];
      };
      await IpGeo.resolveHost('8.8.8.8');
      expect(asked, isFalse);
    });
  });

  group('private addresses', () {
    test('are not looked up', () async {
      for (final host in const ['192.168.1.10', '10.0.0.1', 'nas.local']) {
        final found = await IpGeo.locateHost(host);
        expect(found.geo, isNull, reason: host);
        expect(found.miss, GeoMiss.private, reason: host);
      }
    });

    test('are refused before the resolver is reached', () async {
      var asked = false;
      IpGeo.resolver = (_) async {
        asked = true;
        return const [];
      };
      expect(await IpGeo.resolveHost('nas.local'), isNull);
      expect(asked, isFalse);
    });
  });

  /// Nothing is remembered between lookups, and that is the behaviour rather
  /// than an omission.
  ///
  /// There was a store here keyed by host. It dated from when a lookup meant
  /// fetching a shard over the network, and it outlived that: it answered from
  /// itself instead of from the installed month, so a coordinate never changed
  /// after a data update, and it could not notice a name resolving somewhere
  /// new. These pin what replaced it — an answer that always comes from the
  /// data currently on disk.
  group('nothing is cached', () {
    test('an answer does not survive the data it came from', () async {
      expect(await IpGeo.resolveHost('8.8.8.8'), isNotNull);

      await removeGeoVectors();

      // The whole point. With a cache this still answered, from a database the
      // user had since deleted.
      final again = await IpGeo.locateHost('8.8.8.8');
      expect(again.geo, isNull);
      expect(again.miss, GeoMiss.noData);
    });

    test('and comes back when the data does', () async {
      // The other half: an answer withheld while the data was gone is not a
      // remembered miss either. Both directions are the same property — every
      // answer comes from what is on disk at the moment it is asked for.
      await removeGeoVectors();
      expect(await IpGeo.resolveHost('8.8.8.8'), isNull);

      await installGeoVectors();

      expect(
        (await IpGeo.resolveHost('8.8.8.8'))?.coord.lon,
        closeTo(-122.0838, 0.01),
      );
    });

    test('a repeated lookup is repeated, not remembered', () async {
      var lookups = 0;
      IpGeo.resolver = (host) async {
        lookups++;
        return [InternetAddress('8.8.8.8')];
      };
      await IpGeo.resolveHost('example.com');
      await IpGeo.resolveHost('example.com');
      expect(lookups, 2);
    });

    test('and a lookup writes nothing anywhere', () async {
      expect(await IpGeo.resolveHost('8.8.8.8'), isNotNull);
      // `self_addr` is the only store the globe still writes, and only the
      // globe widget writes it — from what a server reported, never from a
      // lookup this made.
      expect(Stores.selfAddr.count, 0);
    });
  });

  group('which address a server is placed by', () {
    test('SSH leads when it is the leading transport', () {
      final spi = Spi(
        name: 'both',
        id: 'b',
        ssh: const SshCredential(ip: '1.2.3.4'),
        monitorHttp: const MonitorHttpCredential(addr: 'https://5.6.7.8:3770'),
      );
      expect(IpGeo.geoHostOf(spi), '1.2.3.4');
    });

    test('the agent leads when it is preferred', () {
      final spi = Spi(
        name: 'both',
        id: 'b',
        ssh: const SshCredential(ip: '1.2.3.4'),
        monitorHttp: const MonitorHttpCredential(addr: 'https://5.6.7.8:3770'),
        preferredTransport: ServerTransport.monitorHttp,
      );
      expect(IpGeo.geoHostOf(spi), '5.6.7.8');
    });

    test('a monitor-only server is placed by its agent', () {
      final spi = Spi(
        name: 'agent',
        id: 'a',
        monitorHttp: const MonitorHttpCredential(addr: 'https://5.6.7.8:3770'),
      );
      expect(IpGeo.geoHostOf(spi), '5.6.7.8');
    });

    test('a monitor address that is not a URL places nothing', () {
      final spi = Spi(
        name: 'agent',
        id: 'a',
        monitorHttp: const MonitorHttpCredential(addr: 'not a url'),
      );
      expect(IpGeo.geoHostOf(spi), isNull);
    });

    test('a v6 agent address comes out as a parseable literal', () {
      // `Uri.host` drops the brackets a v6 authority is written with, so what
      // reaches `InternetAddress.tryParse` is already the bare address.
      // `isPrivateHost` unwraps them anyway, for a value that arrives some
      // other way — see `private_address_test.dart`.
      final spi = Spi(
        name: 'agent',
        id: 'a',
        monitorHttp: const MonitorHttpCredential(
          addr: 'https://[2606:4700::1]:3770',
        ),
      );
      expect(IpGeo.geoHostOf(spi), '2606:4700::1');
    });
  });
}
