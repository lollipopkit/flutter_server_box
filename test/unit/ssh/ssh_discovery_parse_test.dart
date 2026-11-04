import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/ssh_discovery_parse.dart';

Set<String> _ips(Iterable<InternetAddress> a) => {for (final e in a) e.address};

void main() {
  test('ip neigh: the leading address, of the family asked for', () {
    const out = '''
192.168.1.1 dev wlan0 lladdr 00:11:22:33:44:55 REACHABLE
192.168.1.20 dev wlan0  FAILED
fe80::1 dev wlan0 lladdr 00:11:22:33:44:55 router STALE

''';
    expect(_ips(DiscoveryParse.ipNeigh(out, InternetAddressType.IPv4)), {'192.168.1.1', '192.168.1.20'});
    expect(_ips(DiscoveryParse.ipNeigh(out, InternetAddressType.IPv6)), {'fe80::1'});
  });

  test('arp -an: the address in parentheses', () {
    const out = '''
? (192.168.1.1) at 0:11:22:33:44:55 on en0 ifscope [ethernet]
? (192.168.1.255) at ff:ff:ff:ff:ff:ff on en0 ifscope [ethernet]
? (224.0.0.251) at 1:0:5e:0:0:fb on en0 ifscope permanent [ethernet]
''';
    expect(_ips(DiscoveryParse.arp(out)), {'192.168.1.1', '192.168.1.255', '224.0.0.251'});
  });

  test('ndp -a: addresses under the header', () {
    const out = '''
Neighbor                        Linklayer Address  Netif Expire    St Flgs Prbs
fe80::1%en0                     0:11:22:33:44:55     en0 23h59m58s S  R
2001:db8::5                     0:11:22:33:44:66     en0 23h59m58s S
''';
    // The header is not an address. A scoped one is, and `discover` drops it
    // with every other link-local one.
    expect(_ips(DiscoveryParse.ndp(out)), {'fe80::1%en0', '2001:db8::5'});
  });

  test('ip -o -4 addr: each network, with its bounds', () {
    const out = '''
2: eth0    inet 10.0.0.5/24 brd 10.0.0.255 scope global eth0\\       valid_lft forever preferred_lft forever
3: wg0    inet 10.8.0.2/32 scope global wg0\\       valid_lft forever preferred_lft forever
4: p2p    inet 172.16.0.0/31 scope global p2p\\       valid_lft forever preferred_lft forever
''';
    final cidrs = DiscoveryParse.ipAddr(out);
    expect(cidrs.map((c) => '$c'), ['10.0.0.0/24', '10.8.0.2/32', '172.16.0.0/31']);
    expect(cidrs[0].broadcast.address, '10.0.0.255');
    expect(cidrs[0].hosts().length, 254);
    expect(cidrs[0].hosts(limit: 3).map((e) => e.address), ['10.0.0.1', '10.0.0.2', '10.0.0.3']);
    // Neither has a host range between its network and broadcast addresses.
    expect(cidrs[1].hosts(), isEmpty);
    expect(cidrs[2].hosts(), isEmpty);
  });

  test('ifconfig: a hex netmask, the broadcast it states or the one it implies', () {
    const out = '''
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
	inet 127.0.0.1 netmask 0xff000000
en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
	inet 192.168.1.23 netmask 0xffffff00 broadcast 192.168.1.255
utun3: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 1380
	inet 10.7.0.2 netmask 0xfffffffc
bridge0: flags=8863<UP> mtu 1500
	inet 10.9.0.1 --> 10.9.0.2 netmask 0xffffff00
''';
    final cidrs = DiscoveryParse.ifconfig(out);
    expect(cidrs.map((c) => '$c'), ['192.168.1.0/24', '10.7.0.0/30']);
    expect(cidrs[0].broadcast.address, '192.168.1.255');
    expect(cidrs[1].broadcast.address, '10.7.0.3');
    expect(cidrs[1].hosts().map((e) => e.address), ['10.7.0.1', '10.7.0.2']);
  });

  test('dns-sd: service names from a browse, addresses from a lookup', () {
    const browse = [
      'Browsing for _ssh._tcp',
      'DATE: ---Mon 04 Nov 2026---',
      'Timestamp     A/R    Flags  if Domain               Service Type         Instance Name',
      '10:00:00.000  Add        3   4 local.               _ssh._tcp.           nas',
    ];
    expect(DiscoveryParse.dnsSdServices([
      ...browse,
      '10:00:00.001  Add        2   4 local.               _ssh._tcp.           Office Mac mini',
    ]), ['nas', 'Office Mac mini']);
    const lookup = '''
Lookup nas._ssh._tcp.local.
10:00:00.100  nas._ssh._tcp.local. can be reached at nas.local.:22 (interface 4)
 Address = 192.168.1.40
 Address=fe80::2
''';
    expect(_ips(DiscoveryParse.dnsSdAddresses(lookup)), {'192.168.1.40', 'fe80::2'});
  });

  test('avahi-browse: resolved addresses, the empty one skipped', () {
    const out = '''
+ wlan0 IPv4 nas                                   SSH Remote Terminal  local
= wlan0 IPv4 nas                                   SSH Remote Terminal  local
   hostname = [nas.local]
   address = [192.168.1.40]
   port = [22]
= wlan0 IPv6 nas                                   SSH Remote Terminal  local
   address = []
''';
    expect(_ips(DiscoveryParse.avahiAddresses(out)), {'192.168.1.40'});
  });
}
