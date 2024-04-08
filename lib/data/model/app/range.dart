final class Range<T extends num> {
  final T start;
  final T end;

  Range(this.start, this.end);

  bool contains(int value) => value >= start && value <= end;

  @override
  String toString() => 'Range($start, $end)';
}
