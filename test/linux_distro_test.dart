import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/linux_distro.dart';

/// What a distribution has to answer, and what the marker on disk means.
///
/// The marker is the part worth locking. It gets one read per launch, it is
/// never rewritten, and a wrong answer is silent: a tree read as the wrong
/// distribution would have `apt` sources written into an Alpine, or an update
/// offered against a version that is not a version of what is installed.
///
/// Its older shapes are locked too, because they exist on devices. A release
/// that wrote a bare version string is what almost every install out there came
/// from, and the day a second distribution ships is the day misreading those
/// starts to matter.
void main() {
  group('a distribution', () {
    test('answers with a label, a version and a digest', () {
      for (final distro in LinuxDistro.values) {
        expect(distro.label, isNotEmpty, reason: '${distro.id} label');
        expect(distro.version, isNotEmpty, reason: '${distro.id} version');
        expect(
          distro.sha256,
          hasLength(64),
          reason: '${distro.id} has to pin a sha256 — the tarball is '
              'executable code, and the digest is what makes downloading it '
              'different from running whatever the connection returned',
        );
      }
    });

    test('has a default mirror that is a URL', () {
      for (final distro in LinuxDistro.values) {
        final url = Uri.tryParse(distro.defaultMirror);
        expect(url?.isScheme('https'), isTrue, reason: distro.id);
        expect(
          distro.defaultMirror.endsWith('/'),
          isFalse,
          reason: 'callers join a path onto this',
        );
      }
    });

    test('builds its tarball URL under the mirror it is given', () {
      for (final distro in LinuxDistro.values) {
        expect(
          distro.rootfsUrl('https://mirror.example/x'),
          startsWith('https://mirror.example/x/'),
          reason: '${distro.id} must honour a mirror, or the setting does '
              'nothing',
        );
      }
    });

    test('names a repositories file under etc, with something in it', () {
      for (final distro in LinuxDistro.values) {
        final repo = distro.repositories('https://mirror.example/x');
        expect(repo.path, startsWith('etc/'), reason: distro.id);
        expect(repo.path.startsWith('/'), isFalse, reason: 'joined to a root');
        expect(repo.content, contains('https://mirror.example/x'));
        expect(repo.content, endsWith('\n'));
      }
    });

    test("Alpine's is apk's, pinned to its branch", () {
      final repo = LinuxDistro.alpine.repositories('https://m');
      expect(repo.path, 'etc/apk/repositories');
      expect(repo.content, 'https://m/v3.22/main\nhttps://m/v3.22/community\n');
    });

    test('is read back by name', () {
      for (final distro in LinuxDistro.values) {
        expect(LinuxDistro.fromName(distro.id), distro);
      }
    });

    test('falls back to Alpine for a name no build knows', () {
      // A store or a marker written by a build that had more of them. Throwing
      // here would lose an installed system over a string.
      expect(LinuxDistro.fromName('plan9'), LinuxDistro.alpine);
      expect(LinuxDistro.fromName(null), LinuxDistro.alpine);
      expect(LinuxDistro.fromName(''), LinuxDistro.alpine);
    });
  });

  group('the marker', () {
    test('round-trips what was installed', () {
      const guest = InstalledGuest(LinuxDistro.alpine, '3.22.5');
      final read = InstalledGuest.decode(guest.encode());

      expect(read.distro, LinuxDistro.alpine);
      expect(read.version, '3.22.5');
    });

    test('reads a bare version as Alpine, which is what wrote it', () {
      // Every release before this one wrote the version alone, and Alpine was
      // the only thing installable.
      final read = InstalledGuest.decode('3.22.5\n');

      expect(read.distro, LinuxDistro.alpine);
      expect(read.version, '3.22.5');
    });

    test('reads an empty marker as Alpine of no version', () {
      // Older still: the marker was written empty, and its presence alone said
      // "installed". Android turns the empty version into `0` so that it reads
      // as outdated, which is what it is.
      final read = InstalledGuest.decode('');

      expect(read.distro, LinuxDistro.alpine);
      expect(read.version, isEmpty);
    });

    test('survives trailing whitespace either side of the newline', () {
      final read = InstalledGuest.decode('  alpine \n 3.22.5  \n\n');

      expect(read.distro, LinuxDistro.alpine);
      expect(read.version, '3.22.5');
    });
  });
}
