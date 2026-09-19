import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/server_sort.dart';

/// Moving several machines at once in the manual arrangement.
///
/// The arrangement is the one thing on this page the user built by hand, and
/// this is the only edit to it that touches more than one record — so what it
/// must never do is reorder anything it was not asked to move.
void main() {
  const order = ['a', 'b', 'c', 'd', 'e'];

  test('the chosen go to the top, everything else keeps its order', () {
    expect(moveInOrder(order, {'b', 'd'}, toTop: true), [
      'b', 'd', // in the order they were in, not the order they were picked
      'a', 'c', 'e',
    ]);
  });

  test('and to the bottom the same way', () {
    expect(moveInOrder(order, {'b', 'd'}, toTop: false), [
      'a', 'c', 'e',
      'b', 'd',
    ]);
  });

  test('the block keeps its own order whichever way the set is written', () {
    // A `Set` has no order of its own worth relying on, and the one the user
    // tapped them in is not the one they are read in.
    expect(
      moveInOrder(order, {'e', 'a', 'c'}, toTop: true),
      moveInOrder(order, {'c', 'e', 'a'}, toTop: true),
    );
    expect(moveInOrder(order, {'e', 'a', 'c'}, toTop: true), [
      'a', 'c', 'e',
      'b', 'd',
    ]);
  });

  test('moving all of them changes nothing', () {
    expect(moveInOrder(order, order.toSet(), toTop: true), order);
    expect(moveInOrder(order, order.toSet(), toTop: false), order);
  });

  test('an id that is no longer in the list is ignored', () {
    // What a machine deleted while it was selected looks like.
    expect(moveInOrder(order, {'b', 'gone'}, toTop: true), [
      'b', 'a', 'c', 'd', 'e',
    ]);
  });

  test('nothing chosen is answered with the list itself', () {
    expect(moveInOrder(order, const {}, toTop: true), same(order));
  });

  test('no machine is lost or duplicated', () {
    for (final toTop in [true, false]) {
      for (final chosen in [
        {'a'},
        {'a', 'e'},
        {'b', 'c', 'd'},
        {'a', 'b', 'c', 'd', 'e'},
      ]) {
        final got = moveInOrder(order, chosen, toTop: toTop);
        expect(got.toSet(), order.toSet());
        expect(got, hasLength(order.length));
      }
    }
  });
}
