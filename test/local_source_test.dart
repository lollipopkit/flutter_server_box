import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/ssh/terminal_source.dart';

/// What a saved terminal tab names, now that there can be several Linux
/// systems installed at once.
///
/// The id is what survives a relaunch and what a backup carries between
/// devices, so its shape is a contract with data already written. Two terminals
/// in two systems differ in nothing else — same device, same kind of source —
/// which is why the profile has to be in here.
void main() {
  group('the id of a system terminal', () {
    test('names the profile it was opened in', () {
      const source = LocalSource(rootfs: true, profileId: 'alpine-2');

      expect(LocalSource.profileIdOf(source.id), 'alpine-2');
    });

    test('tells two systems apart', () {
      // The whole point: without this they would restore as one tab, and a
      // second system would be unreachable from a restored set.
      const a = LocalSource(rootfs: true, profileId: 'alpine');
      const b = LocalSource(rootfs: true, profileId: 'alpine-2');

      expect(a.id, isNot(b.id));
    });

    test('is not the device\'s own', () {
      expect(const LocalSource(rootfs: true).id, isNot(const LocalSource().id));
    });
  });

  group('a set saved before profiles existed', () {
    test('reads as "whichever is selected"', () {
      // Exactly the string an earlier build wrote. It meant the one system
      // there was, and the one system there is is the selected one.
      expect(LocalSource.profileIdOf(LocalSource.rootfsId), isNull);
    });

    test('so does one that names no profile', () {
      const source = LocalSource(rootfs: true);

      expect(LocalSource.profileIdOf(source.id), isNull);
    });
  });

  group('an id that is something else', () {
    test('names no profile', () {
      expect(LocalSource.profileIdOf(const LocalSource().id), isNull);
      expect(LocalSource.profileIdOf('some-server-id'), isNull);
      // A server whose id happens to start with the device's would still not
      // be a system terminal, and must not be read as one.
      expect(LocalSource.profileIdOf('${LocalSource.rootfsId}x'), isNull);
    });
  });
}
