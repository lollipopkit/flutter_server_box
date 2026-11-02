import 'dart:typed_data';

import 'package:archive/archive.dart';

/// A theme package (`.fsbt`) holding only a minimal manifest for theme [id].
Uint8List fsbtOf(String id, String name) => Uint8List.fromList(
  ZipEncoder().encodeBytes(
    Archive()..add(ArchiveFile.string('manifest.toml', '''
format = 1
id = "$id"
name = "$name"
modes = ["light", "dark"]

[schema]
min = 1
max = 1

[colors]
mode = 0
seed = 4287106639
systemColor = false

[icons]
style = "classic"

[background]
type = "gradient"
opacity = 0.18
blur = 8

[shapes]
card = 13
tile = 9
button = 30
''')),
  ),
);
