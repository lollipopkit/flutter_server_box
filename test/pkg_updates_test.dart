/// Pending package updates, from the shared parser to what the app draws.
///
/// The parsing itself is `crates/sbm_parser/tests/pkg_test.rs`, one manager at
/// a time. What is here is the join: that the FFI carries the shape the Dart
/// model expects, and that the two things a wrong answer would cost — an
/// upgrade command with a yes flag in it, a security count invented out of a
/// manager that cannot tell — are what they should be.
///
/// Build the native library first: cargo build -p sbm_ffi
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/pkg_updates.dart';
import 'package:server_box/src/rust/api/parser.dart';

import 'rust_lib_helper.dart';

/// Real `apt-get -s upgrade` output, with the header the command prints in
/// front of it.
const _aptRaw = '''
mgr=apt
age=93600
NOTE: This is only a simulation!
Reading package lists...
Inst base-files [12.4+deb12u5] (12.4+deb12u6 Debian:12.6/stable [amd64])
Conf base-files (12.4+deb12u6 Debian:12.6/stable [amd64])
Inst libssl3 [3.0.11-1~deb12u2] (3.0.13-1~deb12u1 Debian-Security:12/stable-security [amd64])
Inst linux-image-6.1.0-18-amd64 (6.1.76-1 Debian:12.6/stable [amd64])
''';

void main() {
  setUpAll(initRustLibForTest);

  Future<PkgUpdates> viaFfi(String raw) async {
    final json = await parseStatusJson(
      system: 'linux',
      raw: {'pkg': raw},
      tempDivisor: 1000.0,
    );
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return PkgUpdates.fromJson(decoded['pkg'] as Map<String, dynamic>);
  }

  group('across the FFI', () {
    test('the reading arrives whole', () async {
      final pkg = await viaFfi(_aptRaw);

      expect(pkg.manager, 'apt');
      expect(pkg.supported, isTrue);
      expect(pkg.total, 3);
      expect(pkg.security, 1);
      expect(pkg.indexAge, const Duration(seconds: 93600));

      final ssl = pkg.items.firstWhere((i) => i.name == 'libssl3');
      expect(ssl.from, '3.0.11-1~deb12u2');
      expect(ssl.to, '3.0.13-1~deb12u1');
      expect(ssl.security, isTrue);
      expect(ssl.repo, 'Debian-Security:12/stable-security');

      // apt prints no installed version for a package arriving as a new
      // dependency, and the card draws that as the new version alone rather
      // than an arrow with a blank on one side.
      final kernel = pkg.items.firstWhere((i) => i.name.startsWith('linux-'));
      expect(kernel.from, isNull);
    });

    /// A server with no manager this build can read is a different state from
    /// one with nothing to upgrade, and the card draws them differently — one
    /// is absent, the other says "up to date".
    test('no manager is unsupported, not up to date', () async {
      final pkg = await viaFfi('mgr=none\n');

      expect(pkg.supported, isFalse);
      expect(pkg.total, 0);
      expect(pkg.security, isNull);
    });

    test('a segment that never arrived is unsupported', () async {
      final json = await parseStatusJson(
        system: 'linux',
        raw: const {},
        tempDivisor: 1000.0,
      );
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final pkg = PkgUpdates.fromJson(decoded['pkg'] as Map<String, dynamic>);

      expect(pkg.supported, isFalse);
    });

    /// Saying "0 security updates" on a manager that cannot tell would be a
    /// reassurance nothing checked. Null all the way through the FFI.
    test('dnf does not claim a security count', () async {
      final pkg = await viaFfi(
        'mgr=dnf\nage=60\nopenssl.x86_64   1:3.0.7-27.el9   baseos\n',
      );

      expect(pkg.total, 1);
      expect(pkg.security, isNull);
    });
  });

  group('the upgrade command', () {
    /// A yes flag here would remove the last place a person can look at the
    /// plan, on a command that is about to change a system they are not
    /// sitting in front of.
    test('never assumes yes', () {
      for (final manager in [
        'apt',
        'dnf',
        'yum',
        'zypper',
        'pacman',
        'apk',
        'pkg',
        'brew',
      ]) {
        final cmd = PkgUpdates(manager: manager).upgradeCommand;
        expect(cmd, isNotNull, reason: manager);
        expect(
          cmd,
          isNot(anyOf(contains(' -y'), contains('--yes'), contains(' -f'))),
          reason: manager,
        );
      }
    });

    /// Partial upgrades are unsupported on Arch: `-Su` without the `y` is how
    /// an install ends up with a mismatched libc.
    test('pacman refreshes and upgrades together', () {
      expect(const PkgUpdates(manager: 'pacman').upgradeCommand, 'sudo pacman -Syu');
    });

    /// Homebrew refuses to run as root, so this is the one without sudo.
    test('brew does not use sudo', () {
      expect(const PkgUpdates(manager: 'brew').upgradeCommand, 'brew upgrade');
      for (final manager in ['apt', 'dnf', 'pacman', 'apk', 'pkg']) {
        expect(
          PkgUpdates(manager: manager).upgradeCommand,
          startsWith('sudo '),
          reason: manager,
        );
      }
    });

    test('a manager this build has none for offers nothing', () {
      expect(const PkgUpdates(manager: 'nix').upgradeCommand, isNull);
      expect(const PkgUpdates().upgradeCommand, isNull);
    });
  });

  group('staleness', () {
    /// The answer that matters most: "0 updates" off a cache nobody has
    /// refreshed since March is true about what apt knows and false about the
    /// machine.
    test('a week is where a count stops meaning much', () {
      expect(
        const PkgUpdates(manager: 'apt', indexAge: Duration(days: 6)).stale,
        isFalse,
      );
      expect(
        const PkgUpdates(manager: 'apt', indexAge: Duration(days: 8)).stale,
        isTrue,
      );
    });

    /// An unknown age must not read as a fresh one — the card would then say
    /// nothing where it has nothing to say, rather than implying the index was
    /// just refreshed.
    test('an unknown age is not stale and not fresh', () {
      expect(const PkgUpdates(manager: 'apt').stale, isFalse);
      expect(const PkgUpdates(manager: 'apt').indexAge, isNull);
    });
  });
}
