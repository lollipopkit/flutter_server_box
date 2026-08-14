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

  test('name is the last component', () {
    expect(BrowsePath(root: '/home/me').name, 'me');
    expect(BrowsePath(root: '/').name, '/');
    expect(
      BrowsePath(root: '/home', initial: '/home/me/docs').name,
      'docs',
    );
  });
}
