import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/comparator.dart';

void main() {
  group('ChainComparator Tests', () {
    test('thenCompareBy sorts correctly', () {
      final list = [('b', '2'), ('a', '3'), ('b', '1')];
      list.sort(
        ChainComparator.create()
            .thenCompareBy<String>((t) => t.$1)
            .thenCompareBy<String>((t) => t.$2, reversed: false)
            .call,
      );
      expect(list, equals([('a', '3'), ('b', '1'), ('b', '2')]));
    });

    test('thenCompareBy with reversed sorts correctly', () {
      final list = [('b', '2'), ('a', '3'), ('b', '1')];
      list.sort(
        ChainComparator.create()
            .thenCompareBy<String>((t) => t.$1)
            .thenCompareBy<String>((t) => t.$2, reversed: true)
            .call,
      );
      expect(list, equals([('a', '3'), ('b', '2'), ('b', '1')]));
    });

    test('thenWithComparator sorts correctly', () {
      final list = ['bb', 'c', 'aaa'];
      list.sort(
        ChainComparator.create()
            .thenWithComparator((a, b) => a.length.compareTo(b.length))
            .call,
      );
      expect(list, equals(['c', 'bb', 'aaa']));
    });

    test('thenTrueFirst sorts correctly', () {
      final list = [('a', false), ('b', true), ('c', false)];
      list.sort(
        ChainComparator.create()
            .thenTrueFirst((t) => t.$2)
            .thenWithComparator((a, b) => a.$1.compareTo(b.$1))
            .call,
      );
      expect(list, equals([('b', true), ('a', false), ('c', false)]));
    });
  });

  group('Comparators Tests', () {
    test('compareStringCaseInsensitive sorts correctly', () {
      final list = ['b', 'C', 'a'];
      list.sort(Comparators.compareStringCaseInsensitive());
      expect(list, equals(['a', 'b', 'C']));
    });

    test(
      'compareStringCaseInsensitive with uppercaseFirst sorts correctly',
      () {
        final list = ['b', 'C', 'a', 'B'];
        list.sort(
          Comparators.compareStringCaseInsensitive(uppercaseFirst: true),
        );
        expect(list, equals(['a', 'B', 'b', 'C']));
      },
    );
  });
}
