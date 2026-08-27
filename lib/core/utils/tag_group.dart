import 'dart:collection';

import 'package:server_box/core/extension/context/locale.dart';

/// One heading in a rail and the entries under it.
///
/// [label] is null for a group that gets no heading — see [groupByTag].
typedef TagGroup<T> = ({String? label, List<T> items});

/// Groups [items] by the tags [tagsOf] answers for each, in the order the
/// groups are drawn.
///
/// One tag is its own heading. More than one goes under "n tags" instead of
/// appearing under each of them: a rail is an index, and one that lists the
/// same entry three times is not one — and which of its tags would be the
/// right heading is not a question the entry answers.
///
/// Single tags first and in name order, then the multi-tag groups by how many,
/// then whatever carries no tag at all, under a heading of its own. So the
/// heading someone is looking for comes before the ones nobody looks for by
/// name, and nothing in the rail sits outside a group.
///
/// Within a group the order [items] came in is kept, which is the order the
/// list was already in — the server rail's is the user's own ordering.
List<TagGroup<T>> groupByTag<T>(
  Iterable<T> items,
  Iterable<String>? Function(T item) tagsOf,
) {
  final byTag = SplayTreeMap<String, List<T>>();
  final byCount = SplayTreeMap<int, List<T>>();
  final untagged = <T>[];

  for (final item in items) {
    final tags = tagsOf(item);
    switch (tags?.length ?? 0) {
      case 0:
        untagged.add(item);
      case 1:
        byTag.putIfAbsent(tags!.first, () => []).add(item);
      case final count:
        byCount.putIfAbsent(count, () => []).add(item);
    }
  }

  // Nothing is tagged, so there is one group holding everything. A heading
  // over the whole rail divides nothing and says only that tags exist, which
  // is not what someone reading an index is looking for. A lone *tag* group
  // keeps its heading — that one names something.
  if (byTag.isEmpty && byCount.isEmpty) {
    return untagged.isEmpty ? const [] : [(label: null, items: untagged)];
  }

  return [
    for (final entry in byTag.entries) (label: entry.key, items: entry.value),
    for (final entry in byCount.entries)
      (label: l10n.nTags(entry.key), items: entry.value),
    if (untagged.isNotEmpty) (label: l10n.ungrouped, items: untagged),
  ];
}
