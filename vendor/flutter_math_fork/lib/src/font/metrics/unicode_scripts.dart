class Script {
  final String name;
  final List<List<int>> blocks;
  const Script({
    required this.name,
    required this.blocks,
  });
}

const Map<String, List<List<int>>> scriptData = {
  // Latin characters beyond the Latin-1 characters we have metrics for.
  // Needed for Czech, Hungarian and Turkish text, for example.
  'latin': [
    [0x0100, 0x024f], // Latin Extended-A and Latin Extended-B
    [0x0300, 0x036f], // Combining Diacritical marks
  ],

  // The Cyrillic script used by Russian and related languages.
  // A Cyrillic subset used to be supported as explicitly defined
  // symbols in symbols.js
  'cyrillic': [
    [0x0400, 0x04ff]
  ],

  // The Brahmic scripts of South and Southeast Asia
  // Devanagari (0900–097F)
  // Bengali (0980–09FF)
  // Gurmukhi (0A00–0A7F)
  // Gujarati (0A80–0AFF)
  // Oriya (0B00–0B7F)
  // Tamil (0B80–0BFF)
  // Telugu (0C00–0C7F)
  // Kannada (0C80–0CFF)
  // Malayalam (0D00–0D7F)
  // Sinhala (0D80–0DFF)
  // Thai (0E00–0E7F)
  // Lao (0E80–0EFF)
  // Tibetan (0F00–0FFF)
  // Myanmar (1000–109F)
  'brahmic': [
    [0x0900, 0x109F]
  ],

  'georgian': [
    [0x10A0, 0x10ff]
  ],

  // Chinese and Japanese.
  // The "k" in cjk is for Korean, but we've separated Korean out
  'cjk': [
    [0x3000, 0x30FF], // CJK symbols and punctuation, Hiragana, Katakana
    [0x4E00, 0x9FAF], // CJK ideograms
    [0xFF00, 0xFF60], // Fullwidth punctuation
    // TODO: add halfwidth Katakana and Romanji glyphs
  ],

  // Korean
  'hangul': [
    [0xAC00, 0xD7AF]
  ],
};

final allBlocks =
    scriptData.entries.expand((entry) => entry.value).toList(growable: false);

bool supportedCodepoint(int codepoint) =>
    allBlocks.any((block) => codepoint >= block[0] && codepoint <= block[1]);
