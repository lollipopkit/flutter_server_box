import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/file/browse_path.dart';

void main() {
  test('starts at the root when nothing else is asked for', () {
    final path = BrowsePath(root: '/home/me');

    expect(path.path, '/home/me');
    expect(path.canGoUp, isFalse);
  });

  test('reopens where it was left, and can still go up', () {
    // The bug this separation exists for: the local page took one string as
    // both root and current directory, so a tab restored deep in a tree made
    // that directory the top of the world.
    final path = BrowsePath(root: '/home/me', initial: '/home/me/logs/2026');

    expect(path.path, '/home/me/logs/2026');
    expect(path.canGoUp, isTrue);

    path.goUp();
    expect(path.path, '/home/me/logs');
    path.goUp();
    expect(path.path, '/home/me');
    expect(path.canGoUp, isFalse);
  });

  test('going up at the root does nothing', () {
    final path = BrowsePath(root: '/home/me');

    path.goUp();

    expect(path.path, '/home/me');
  });

  test('a saved path from outside the root lands at the root', () {
    // A session saved when the root was somewhere else, or on another device.
    final path = BrowsePath(root: '/home/me', initial: '/etc');

    expect(path.path, '/home/me');
  });

  test('a sibling with a shared prefix is not inside the root', () {
    // `/var/logs` must not read as being under `/var/log`.
    final path = BrowsePath(root: '/var/log', initial: '/var/logs');

    expect(path.path, '/var/log');
  });

  test('refuses to jump outside, and says so', () {
    final path = BrowsePath(root: '/home/me');

    expect(path.goTo('/etc/passwd'), isFalse);
    expect(path.path, '/home/me');
    expect(path.goTo('/home/me/docs'), isTrue);
    expect(path.path, '/home/me/docs');
  });

  test('a Windows root becomes something splittable', () {
    final path = BrowsePath(root: r'C:\Users\me\Documents');

    expect(path.path, 'C:/Users/me/Documents');
    path.enter('logs');
    expect(path.path, 'C:/Users/me/Documents/logs');
    expect(path.canGoUp, isTrue);
  });

  test('trailing slashes do not create a root nothing is inside of', () {
    final path = BrowsePath(root: '/home/me/', initial: '/home/me/docs/');

    expect(path.root, '/home/me');
    expect(path.path, '/home/me/docs');
    expect(path.canGoUp, isTrue);
  });

  test('the filesystem root is a root like any other', () {
    final path = BrowsePath(root: '/', initial: '/etc');

    expect(path.canGoUp, isTrue);
    path.goUp();
    expect(path.path, '/');
    expect(path.canGoUp, isFalse);
  });

  group('going back', () {
    test('is not the same as going up', () {
      // The distinction the browser needs both of: up walks the tree, back
      // retraces the browsing.
      final path = BrowsePath(root: '/', initial: '/var/log');
      path.goTo('/etc/ssh');

      path.goUp();
      expect(path.path, '/etc');

      expect(path.goBack(), isTrue);
      expect(path.path, '/etc/ssh');
      expect(path.goBack(), isTrue);
      expect(path.path, '/var/log');
    });

    test('does nothing, and says so, where there is nothing behind', () {
      final path = BrowsePath(root: '/home/me');

      expect(path.canGoBack, isFalse);
      expect(path.goBack(), isFalse);
      expect(path.path, '/home/me');
    });

    test('a jump that went nowhere is not a step to come back from', () {
      final path = BrowsePath(root: '/home/me');

      expect(path.goTo('/home/me'), isTrue);

      expect(path.canGoBack, isFalse);
    });

    test('a refused jump leaves no trace', () {
      final path = BrowsePath(root: '/home/me', initial: '/home/me/docs');

      expect(path.goTo('/etc'), isFalse);

      expect(path.canGoBack, isFalse);
      expect(path.path, '/home/me/docs');
    });

    test('a long browse does not become an unbounded list', () {
      final path = BrowsePath(root: '/');
      for (var i = 0; i < 200; i++) {
        path.goTo('/dir$i');
      }

      // Still walks back, and the oldest steps are the ones dropped.
      var steps = 0;
      while (path.goBack()) {
        steps++;
      }
      expect(steps, 64);
    });
  });

  test('name is the last component', () {
    expect(BrowsePath(root: '/home/me').name, 'me');
    expect(BrowsePath(root: '/').name, '/');
    expect(
      BrowsePath(root: '/home', initial: '/home/me/docs').name,
      'docs',
    );
  });

  group('dot segments cannot walk out of the root', () {
    // Containment is a string prefix, so before these resolved, every one of
    // the paths below passed that test while naming somewhere else — the
    // backend is what resolves them, and it answered outside the root.

    test('a target that climbs back out is refused', () {
      final path = BrowsePath(root: '/home/me');

      expect(path.goTo('/home/me/../outside'), isFalse);
      expect(path.path, '/home/me');

      expect(path.goTo('/home/me/../../etc'), isFalse);
      expect(path.path, '/home/me');
    });

    test('a target that comes back inside is allowed, and is resolved', () {
      final path = BrowsePath(root: '/home/me');

      expect(path.goTo('/home/me/logs/../docs'), isTrue);
      expect(path.path, '/home/me/docs');
    });

    test('. is dropped rather than kept as a component', () {
      final path = BrowsePath(root: '/home/me');

      expect(path.goTo('/home/me/./docs/.'), isTrue);
      expect(path.path, '/home/me/docs');
    });

    test('an initial path that resolves outside lands at the root', () {
      final path = BrowsePath(root: '/home/me', initial: '/home/me/../etc');

      expect(path.path, '/home/me');
    });

    test('a root of its own is resolved too', () {
      expect(BrowsePath(root: '/home/me/../me').root, '/home/me');
    });

    test('.. at the top stays at the top instead of escaping', () {
      expect(BrowsePath(root: '/..').root, '/');
      expect(BrowsePath(root: '/../../etc').root, '/etc');
    });

    test('entering a listed name is checked like any other move', () {
      // A listing is not a trusted source of names: a server is free to answer
      // with `..`, and this used to move there without asking.
      final path = BrowsePath(root: '/home/me');

      path.enter('..');
      expect(path.path, '/home/me');

      path.enter('docs');
      expect(path.path, '/home/me/docs');

      path.enter('..');
      expect(path.path, '/home/me');
    });

    test('a windows root keeps its shape', () {
      final path = BrowsePath(root: r'C:\Users\me');

      expect(path.root, 'C:/Users/me');
      expect(path.goTo('C:/Users/me/../../Windows'), isFalse);
      expect(path.goTo('C:/Users/me/Documents'), isTrue);
      expect(path.path, 'C:/Users/me/Documents');
    });
  });
}
