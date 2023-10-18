import 'package:hive_flutter/hive_flutter.dart';

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

  const Snippet({
    required this.name,
    required this.script,
    this.tags,
    this.note,
  });

  Snippet.fromJson(Map<String, dynamic> json)
      : name = json['name'].toString(),
        script = json['script'].toString(),
        tags = json['tags']?.cast<String>(),
        note = json['note']?.toString();

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['name'] = name;
    data['script'] = script;
    data['tags'] = tags;
    data['note'] = note;
    return data;
  }

  @override
  bool containsTag(String tag) {
    return tags?.contains(tag) ?? false;
  }

  @override
  String get tagName => name;
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
