import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/tag_group.dart';

/// Anything with tags. The helper is generic, so a record stands in for the
/// snippet the snippet rail groups and the server id the server rail does.
typedef _Item = ({String name, List<String>? tags});

List<TagGroup<_Item>> _group(List<_Item> items) =>
    groupByTag(items, (e) => e.tags);

List<String> _names(TagGroup<_Item> group) =>
    [for (final item in group.items) item.name];

void main() {
  test('one tag is its own heading, in name order', () {
    final groups = _group([
      (name: 'c', tags: ['prod']),
      (name: 'a', tags: ['dev']),
      (name: 'b', tags: ['prod']),
    ]);

    expect([for (final g in groups) g.label], ['dev', 'prod']);
    // Within a group, the order they came in — not sorted.
    expect(_names(groups[1]), ['c', 'b']);
  });

  test('more than one tag goes under "n tags", not under each of them', () {
    final groups = _group([
      (name: 'a', tags: ['prod']),
      (name: 'b', tags: ['prod', 'eu']),
      (name: 'c', tags: ['prod', 'eu', 'arm']),
    ]);

    expect([for (final g in groups) g.label], ['prod', '2 Tags', '3 Tags']);
    expect(_names(groups[1]), ['b']);
    expect(_names(groups[2]), ['c']);
  });

  test('untagged goes last, under a heading of its own', () {
    final groups = _group([
      (name: 'a', tags: null),
      (name: 'b', tags: ['prod']),
      (name: 'c', tags: const []),
    ]);

    expect([for (final g in groups) g.label], ['prod', 'Ungrouped']);
    expect(_names(groups[1]), ['a', 'c']);
  });

  test('nothing tagged still gets the heading that says why', () {
    // It divides nothing, and is drawn anyway: without it a rail of untagged
    // entries gave no sign that grouping is a thing that happens here.
    final groups = _group([
      (name: 'a', tags: null),
      (name: 'b', tags: const []),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.label, isNotNull);
    expect(_names(groups.single), ['a', 'b']);
  });

  test('a lone tag keeps its heading — that one names something', () {
    final groups = _group([
      (name: 'a', tags: ['prod']),
      (name: 'b', tags: ['prod']),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.label, 'prod');
  });

  test('nothing at all is no groups, not an empty heading', () {
    expect(_group([]), isEmpty);
  });
}
