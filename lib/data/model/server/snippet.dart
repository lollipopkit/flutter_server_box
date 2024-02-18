import 'package:hive_flutter/hive_flutter.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';

import '../app/tag_pickable.dart';

part 'snippet.g.dart';

@HiveType(typeId: 2)
class Snippet implements TagPickable {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final String script;
  @HiveField(2)
  final List<String>? tags;
  @HiveField(3)
  final String? note;

  /// List of server id that this snippet should be auto run on
  @HiveField(4)
  final List<String>? autoRunOn;

  const Snippet({
    required this.name,
    required this.script,
    this.tags,
    this.note,
    this.autoRunOn,
  });

  Snippet.fromJson(Map<String, dynamic> json)
      : name = json['name'].toString(),
        script = json['script'].toString(),
        tags = json['tags']?.cast<String>(),
        note = json['note']?.toString(),
        autoRunOn = json['autoRunOn']?.cast<String>();

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['name'] = name;
    data['script'] = script;
    data['tags'] = tags;
    data['note'] = note;
    data['autoRunOn'] = autoRunOn;
    return data;
  }

  @override
  bool containsTag(String tag) {
    return tags?.contains(tag) ?? false;
  }

  @override
  String get tagName => name;

  String fmtWith(ServerPrivateInfo spi) {
    final fmted = script.replaceAllMapped(
      RegExp(r'\${.+?}'),
      (match) {
        final key = match.group(0);
        final func = fmtArgs[key];
        if (func == null) {
          return key!;
        }
        return func(spi);
      },
    );
    return fmted;
  }

  static final fmtArgs = {
    r'${host}': (ServerPrivateInfo spi) => spi.ip,
    r'${port}': (ServerPrivateInfo spi) => spi.port.toString(),
    r'${user}': (ServerPrivateInfo spi) => spi.user,
    r'${pwd}': (ServerPrivateInfo spi) => spi.pwd ?? '',
    r'${id}': (ServerPrivateInfo spi) => spi.id,
    r'${name}': (ServerPrivateInfo spi) => spi.name,
  };
}

class SnippetResult {
  final String? dest;
  final String result;
  final Duration time;

  SnippetResult({
    required this.dest,
    required this.result,
    required this.time,
  });
}
