import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/server/card/metric.dart';

/// How the server list is ordered.
///
/// [manual] is the arrangement the user made on the settings page, which is
/// what `serverOrder` already is — so it sorts nothing, and is the default for
/// that reason. Anything else here is a view over that list, remembered but
/// never written back to it.
///
/// An enum rather than the two loose values it is stored as. The stored form
/// is an int and a bool, which is what the terminal tab's own sort keeps, and
/// everything above the store deals in one value.
enum ServerSortField {
  manual,
  name,
  status,

  /// Busiest first. The one an operator reaches for: a list ordered by how
  /// hard each machine is working puts the question at the top of it.
  cpu,

  /// Whatever is past its threshold, first. See [kServerAlertPercent] — the
  /// same line the card's footer and the overview's count mean by "over".
  alert,

  /// Shortest first, which is the direction that answers something: a machine
  /// that has just come back is news, and one up for two hundred days is not.
  uptime;

  /// The field a stored value names.
  ///
  /// Stored by name; the `Enum.index` this used to be is still read, because a
  /// device on an older build syncs the setting in that shape. An index means
  /// whatever this build's [values] order says, which is exactly the problem
  /// with keeping one.
  static ServerSortField fromStored(Object? stored) => switch (stored) {
    final String name =>
      values.firstWhereOrNull((field) => field.name == name) ?? manual,
    final int index when index >= 0 && index < values.length => values[index],
    _ => manual,
  };

  /// Whether reversing this field means anything.
  ///
  /// [manual] *is* the arrangement, so a reversed one is a second arrangement
  /// nobody made — and the list already has a page for saying what the order
  /// should be. [alert] is not a comparison either: it is "what is wrong,
  /// first", and its reverse is "what is wrong, last", which nobody wants.
  /// The rest are comparisons and read both ways.
  bool get directional => this != manual && this != alert;

  /// Whether ordering by this asks the machines anything.
  ///
  /// [manual] and [name] are answered by the record alone, so a page sorting
  /// by one of them does not have to watch every server's readings — which is
  /// a rebuild of the whole list on every poll.
  bool get readsStatus => this != manual && this != name;

  /// Whether the list may be dragged into a new order while this is on.
  ///
  /// Only [manual], because only [manual] is the order: dragging under a
  /// comparison would move a card and have the comparison put it straight
  /// back, which reads as the drag having failed.
  bool get reorderable => this == manual;
}

/// Whether the list is cut into sections, and by what.
///
/// Orthogonal to [ServerSortOrder] rather than one of its cases: a grouped
/// list is still ordered, and the order runs inside each section. Offering it
/// as a sixth sort option would have made the two a single choice and put
/// "grouped" and "by CPU" in competition, which they are not.
///
/// An enum rather than a bool because what it names is what the sections are
/// cut *by*. A second answer — by status, by whether anything is over the line
/// — is then a value here rather than a second setting somewhere else.
enum ServerListGrouping {
  none,
  tag;

  /// How the list under [tag] is cut. The empty tag is "all".
  ///
  /// Remembered per tag alongside the density and the sort, though it only
  /// means anything for "all": inside `#prod` every machine is in `#prod`, so
  /// grouping by tag there is one section with a heading over it.
  static ServerListGrouping of(String tag) {
    final name = Stores.setting.serverListGroup.fetch()[tag];
    return values.firstWhereOrNull((e) => e.name == name) ?? none;
  }

  static void put(String tag, ServerListGrouping grouping) {
    final map = Map<String, String>.from(
      Stores.setting.serverListGroup.fetch(),
    );
    map[tag] = grouping.name;
    Stores.setting.serverListGroup.put(map);
  }
}

/// [order] with [chosen] gathered at one end of it.
///
/// The one edit anything makes to the manual arrangement other than a drag,
/// and the only one that can be made to several machines at once. Both ends
/// and nothing between them: a position to insert at is a number nobody has,
/// since the list on screen is the whole of what is known about where things
/// are.
///
/// The moved block keeps the order it was already in rather than the order the
/// machines were picked in — what moves is a run of the list, and a run that
/// arrives shuffled is a second change nobody asked for. Ids in [chosen] that
/// are not in [order] are ignored, which is what a machine deleted while it
/// was selected looks like.
List<String> moveInOrder(
  List<String> order,
  Set<String> chosen, {
  required bool toTop,
}) {
  final moved = [
    for (final id in order)
      if (chosen.contains(id)) id,
  ];
  if (moved.isEmpty) return order;
  final rest = [
    for (final id in order)
      if (!chosen.contains(id)) id,
  ];
  return toTop ? [...moved, ...rest] : [...rest, ...moved];
}

/// A field and a direction, with the label and icon that go with them.
///
/// A model rather than part of the server tab, which is where it started: the
/// picker sheet lists the same servers and has to list them in the same order.
/// A second sort of its own would be a second answer to a question the user has
/// already answered once.
class ServerSortOrder {
  const ServerSortOrder(this.field, {required this.ascending});

  final ServerSortField field;
  final bool ascending;

  /// How the list under [tag] is ordered. The empty tag is "all".
  ///
  /// Per tag for the reason the density is — see
  /// `SettingStore.serverListSort`. An install that chose before this was per
  /// tag has its one answer read as the answer for "all", which is the list it
  /// was looking at when it chose.
  static ServerSortOrder of(String tag) {
    final stored = Stores.setting.serverListSort.fetch()[tag];
    final (name, direction) = switch (stored?.split(':')) {
      [final name] => (name, null),
      [final name, final direction] => (name, direction),
      // TODO: the pair below is the pre-per-tag setting, kept only as the
      // default for "all". Delete it, and this branch, a few releases on.
      _ when tag.isEmpty => (
        Stores.setting.serverPageSortBy.fetch(),
        Stores.setting.serverPageSortAsc.fetch() ? 'asc' : 'desc',
      ),
      _ => (null, null),
    };

    final field = ServerSortField.fromStored(name);
    return ServerSortOrder(
      field,
      // Normalised, so a direction left behind by another field cannot make
      // the default look like something nothing in the sheet offers.
      ascending: field.directional ? direction != 'desc' : true,
    );
  }

  void save(String tag) {
    final map = Map<String, String>.from(Stores.setting.serverListSort.fetch());
    map[tag] = '${field.name}:${ascending ? 'asc' : 'desc'}';
    Stores.setting.serverListSort.put(map);
  }

  /// Every option the menu offers, in the order it offers them.
  static List<ServerSortOrder> get all => [
    for (final field in ServerSortField.values)
      if (field.directional)
        for (final ascending in [true, false])
          ServerSortOrder(field, ascending: ascending)
      else
        ServerSortOrder(field, ascending: true),
  ];

  IconData get icon => switch ((field, ascending)) {
    (ServerSortField.manual, _) => Icons.format_list_numbered,
    (ServerSortField.name, true) => Icons.sort_by_alpha,
    (ServerSortField.name, false) => Icons.sort,
    (ServerSortField.status, true) => Icons.arrow_upward,
    (ServerSortField.status, false) => Icons.arrow_downward,
    (ServerSortField.cpu, _) => Icons.speed,
    (ServerSortField.alert, _) => Icons.priority_high,
    (ServerSortField.uptime, _) => Icons.schedule,
  };

  String get label {
    final subject = switch (field) {
      ServerSortField.manual => libL10n.sequence,
      ServerSortField.name => libL10n.sortByName,
      ServerSortField.status => l10n.status,
      ServerSortField.cpu => 'CPU',
      ServerSortField.alert => l10n.alerts,
      ServerSortField.uptime => libL10n.uptime,
    };
    if (!field.directional) return subject;
    final direction = switch (field) {
      // Alphabetical order reads as A-Z, not as "ascending"
      ServerSortField.name => ascending ? '(A-Z)' : '(Z-A)',
      _ => '(${ascending ? libL10n.ascending : libL10n.descending})',
    };
    return '$subject $direction';
  }

  bool isCurrentFor(String tag) {
    final current = of(tag);
    if (current.field != field) return false;
    return !field.directional || current.ascending == ascending;
  }

  /// [order] is the arrangement from the settings, which is the whole of what
  /// [ServerSortField.manual] orders by — so that case is a copy or a reverse, not
  /// a comparison.
  ///
  /// [stateOf] answers what is known about a server right now. Read through a
  /// callback rather than from a provider here, because this runs inside a
  /// build and the caller is the one holding a `ref`.
  List<String> apply(
    List<String> order,
    Map<String, Spi> servers,
    ServerState Function(String id) stateOf,
  ) {
    switch (field) {
      case ServerSortField.manual:
        return order;
      case ServerSortField.name:
        final sorted = order.toList();
        sorted.sort((a, b) {
          // Case-folded, or the order is ASCII's rather than the alphabet's:
          // every capitalised name sorts above every lowercase one, so `Zeus`
          // comes before `alpha` under A-Z.
          final nameA = (servers[a]?.name ?? '').toLowerCase();
          final nameB = (servers[b]?.name ?? '').toLowerCase();
          return ascending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
        });
        return sorted;
      case ServerSortField.status:
        return _by(order, (id) => stateOf(id).conn.index.toDouble());
      case ServerSortField.cpu:
        // Busiest first by default, which is the direction the question is
        // asked in — so this one reverses what "ascending" means to it.
        return _by(order, (id) {
          final used = stateOf(id).status.cpu.usedPercent(coreIdx: 0);
          return used == null ? null : -used;
        });
      case ServerSortField.alert:
        // Not a comparison but a partition: over the line, then everything
        // else in the arrangement it was already in.
        return _by(
          order,
          (id) => serverCardReadings(stateOf(id)).all.any((m) => m.over)
              ? 0
              : 1,
        );
      case ServerSortField.uptime:
        // Ascending is shortest first, the direction the field's own doc
        // names. `_by` applies the direction itself, so the key is the plain
        // number of seconds and nothing here reads [ascending].
        //
        // A machine that has not said, or said something this cannot read,
        // has no key and goes last either way — see [_by].
        return _by(order, (id) {
          final raw = stateOf(id).status.more[StatusCmdType.uptime];
          return raw == null ? null : uptimeSeconds(raw)?.toDouble();
        });
    }
  }

  /// The seconds [raw] says the machine has been up, or null if it cannot be
  /// read.
  ///
  /// [raw] is `StatusCmdType.uptime`'s value, which is a *formatted* string,
  /// not a number: what the Rust parser's `common::parse_uptime` keeps of the
  /// line `uptime(1)` prints, or the same shape from the monitor agent's
  /// `format_uptime`. An optional day count, then a duration:
  ///
  /// ```
  /// 61 days, 18:16   61 days, 18 hours and 16 minutes
  /// 1 day, 2:34      one day, singular
  /// 5 days, 10 min   a zero hour prints a unit instead of H:MM
  /// 5 days           days alone
  /// 2:34             under a day — hours:minutes
  /// 34 min           procps and busybox, with a zero hour
  /// 3 hrs            BSD and macOS `w.c`: hr[s] with a zero minute,
  /// 14 mins          min[s] with a zero hour,
  /// 30 secs          sec[s] under a minute
  /// ```
  ///
  /// Null for anything else, including the formats `parse_uptime` itself
  /// rejects. The caller decides where an unknown goes; this does not guess a
  /// number for something it did not understand.
  ///
  /// Public so a test can pin the shapes without building a server.
  static int? uptimeSeconds(String raw) {
    var rest = raw.trim();
    var seconds = 0;

    final days = RegExp(r'^(\d+)\s+days?(?:,\s*|$)').firstMatch(rest);
    if (days != null) {
      seconds = int.parse(days.group(1)!) * Duration.secondsPerDay;
      rest = rest.substring(days.end);
      if (rest.isEmpty) return seconds;
    }

    final clock = RegExp(r'^(\d+):(\d{2})$').firstMatch(rest);
    if (clock != null) {
      return seconds +
          int.parse(clock.group(1)!) * Duration.secondsPerHour +
          int.parse(clock.group(2)!) * Duration.secondsPerMinute;
    }

    final unit = RegExp(r'^(\d+)\s*(hr|min|sec)s?$').firstMatch(rest);
    if (unit != null) {
      final per = switch (unit.group(2)!) {
        'hr' => Duration.secondsPerHour,
        'min' => Duration.secondsPerMinute,
        _ => 1,
      };
      return seconds + int.parse(unit.group(1)!) * per;
    }

    return null;
  }

  /// Sorts by one number per server, keeping the arrangement as the tie.
  ///
  /// Read once per server rather than inside the comparator, which runs
  /// O(n log n) times: [stateOf] reaches a provider. And the tie is broken
  /// explicitly, because `sort` is not stable — without it two servers with
  /// the same reading swap places between rebuilds.
  ///
  /// A null key is a server with no reading, and goes last in *either*
  /// direction: a list sorted by a magnitude must not be led by the ones it
  /// has no magnitude for. A sentinel number cannot say that — whichever end
  /// it sits at, reversing the order puts it at the front.
  List<String> _by(List<String> order, double? Function(String id) keyOf) {
    final keys = {for (final id in order) id: keyOf(id)};
    final rank = {for (var i = 0; i < order.length; i++) order[i]: i};
    final sorted = order.toList();
    sorted.sort((a, b) {
      final keyA = keys[a];
      final keyB = keys[b];
      if (keyA != null && keyB != null) {
        final byKey = keyA.compareTo(keyB);
        if (byKey != 0) return ascending ? byKey : -byKey;
      } else if (keyA != keyB) {
        return keyA == null ? 1 : -1;
      }
      return rank[a]!.compareTo(rank[b]!);
    });
    return sorted;
  }
}

