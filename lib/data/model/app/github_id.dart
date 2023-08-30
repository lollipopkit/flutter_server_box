typedef GhId = String;

extension GhIdX on GhId {
  String get url => 'https://github.com/$this';
}
