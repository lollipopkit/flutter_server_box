class ChainComparator<T> {
  final ChainComparator<T>? _parent;
  final Comparator<T> _comparator;

  ChainComparator._create(this._parent, this._comparator);
  ChainComparator.empty() : this._create(null, (a, b) => 0);
  ChainComparator.create() : this._create(null, (a, b) => 0);

  static ChainComparator<T> comparing<T, F extends Comparable<F>>(
      F Function(T) extractor) {
    return ChainComparator._create(
        null, (a, b) => extractor(a).compareTo(extractor(b)));
  }

  int compare(T a, T b) {
    final parent = _parent;
    if (parent != null) {
      final int result = parent.compare(a, b);
      if (result != 0) return result;
    }
    return _comparator(a, b);
  }

  int call(T a, T b) {
    return compare(a, b);
  }

  ChainComparator<T> thenCompareBy<F extends Comparable<F>>(
      F Function(T) extractor,
      {bool reversed = false}) {
    return ChainComparator._create(
      this,
      reversed
          ? (a, b) => extractor(b).compareTo(extractor(a))
          : (a, b) => extractor(a).compareTo(extractor(b)),
    );
  }

  ChainComparator<T> thenWithComparator(Comparator<T> comparator,
      {bool reversed = false}) {
    return ChainComparator._create(
      this,
      !reversed ? comparator : (a, b) => comparator(b, a),
    );
  }

  ChainComparator<T> thenCompareByReversed<F extends Comparable<F>>(
      F Function(T) extractor) {
    return ChainComparator._create(
        this, (a, b) => -extractor(a).compareTo(extractor(b)));
  }

  ChainComparator<T> thenTrueFirst(bool Function(T) f) {
    return ChainComparator._create(this, (a, b) {
      final fa = f(a), fb = f(b);
      return fa == fb ? 0 : (fa ? -1 : 1);
    });
  }

  ChainComparator<T> reversed() {
    return ChainComparator._create(null, (a, b) => this.compare(b, a));
  }
}

class Comparators {
  static Comparator<String> compareStringCaseInsensitive(
      {bool uppercaseFirst = false}) {
    return (String a, String b) {
      final r = a.toLowerCase().compareTo(b.toLowerCase());
      if (r != 0) return r;
      return uppercaseFirst ? a.compareTo(b) : b.compareTo(a);
    };
  }
}

/*

Comparator.comparing<Type1, Type2>(Type1::getType2)
.thenCompare<Type3>(Type1::getType3)
.thenCompare<Type4>(Type1::getType4)
.thenCompareReversed<Type5>(Type1::getType5)

 */
