import 'package:fl_lib/fl_lib.dart';

class Memory {
  final int total;
  final int free;
  final int avail;

  const Memory({required this.total, required this.free, required this.avail});

  double get availPercent {
    if (avail == 0) {
      return free / total;
    }
    return avail / total;
  }

  double get usedPercent => 1 - availPercent;

  static Memory parse(String raw) {
    final items = raw.split('\n').map((e) => memItemReg.firstMatch(e)).toList();

    final total = int.tryParse(
            items.firstWhereOrNull((e) => e?.group(1) == 'MemTotal:')
                ?.group(2) ?? '1') ?? 1;
    final free = int.tryParse(
            items.firstWhereOrNull((e) => e?.group(1) == 'MemFree:')
                ?.group(2) ?? '0') ?? 0;
    final available = int.tryParse(
            items.firstWhereOrNull((e) => e?.group(1) == 'MemAvailable:')
                ?.group(2) ?? '0') ?? 0;

    return Memory(total: total, free: free, avail: available);
  }
}

final memItemReg = RegExp(r'([A-Z].+:)\s+([0-9]+) kB');

/// Parse BSD/macOS memory from top output
/// 
/// Supports formats like:
/// - macOS: "PhysMem: 32G used (1536M wired), 64G unused."
/// - FreeBSD: "Mem: 456M Active, 2918M Inact, 1127M Wired, 187M Cache, 829M Buf, 3535M Free"
Memory parseBsdMemory(String raw) {
  // Try macOS format first: "PhysMem: 32G used (1536M wired), 64G unused."
  final macMemReg = RegExp(
      r'PhysMem:\s*([\d.]+)([KMGT])\s*used.*?,\s*([\d.]+)([KMGT])\s*unused');
  final macMatch = macMemReg.firstMatch(raw);
  
  if (macMatch != null) {
    final usedAmount = double.parse(macMatch.group(1)!);
    final usedUnit = macMatch.group(2)!;
    final freeAmount = double.parse(macMatch.group(3)!);
    final freeUnit = macMatch.group(4)!;
    
    final usedKB = _convertToKB(usedAmount, usedUnit);
    final freeKB = _convertToKB(freeAmount, freeUnit);
    final totalKB = usedKB + freeKB;
    
    return Memory(total: totalKB, free: freeKB, avail: freeKB);
  }
  
  // Try FreeBSD format: "Mem: 456M Active, 2918M Inact, 1127M Wired, 187M Cache, 829M Buf, 3535M Free"
  final freebsdMemReg = RegExp(r'Mem:.*?([\d.]+)([KMGT])\s*Free');
  final freebsdMatch = freebsdMemReg.firstMatch(raw);
  
  if (freebsdMatch != null) {
    final freeAmount = double.parse(freebsdMatch.group(1)!);
    final freeUnit = freebsdMatch.group(2)!;
    final freeKB = _convertToKB(freeAmount, freeUnit);
    
    // Extract other components for total calculation
    final components = RegExp(
            r'([\d.]+)([KMGT])\s*(?:Active|Inact|Wired|Cache|Buf|Free)')
        .allMatches(raw)
        .map((m) => _convertToKB(double.parse(m.group(1)!), m.group(2)!))
        .toList();
    
    final totalKB = components.isNotEmpty 
        ? components.reduce((a, b) => a + b) 
        : freeKB;
    
    return Memory(total: totalKB, free: freeKB, avail: freeKB);
  }
  
  // Fallback: try to extract numbers and assume they're in some unit
  // This is a best-effort attempt and may not be accurate for all BSD systems
  final numberMatches = RegExp(r'(\d+(?:\.\d+)?)\s*([KMGT]?)')
      .allMatches(raw)
      .toList();
  if (numberMatches.length >= 2) {
    try {
      final total = _convertToKB(
          double.parse(numberMatches[0].group(1)!), 
          numberMatches[0].group(2) ?? '');
      final free = _convertToKB(
          double.parse(numberMatches[1].group(1)!), 
          numberMatches[1].group(2) ?? '');
      
      // Validate that total >= free to ensure reasonable values
      if (total >= free && total > 0) {
        return Memory(total: total, free: free, avail: free);
      } else {
        Loggers.app.warning('BSD memory fallback parsing produced invalid values: total=$total, free=$free for input: $raw');
      }
    } catch (e) {
      Loggers.app.warning('BSD memory fallback parsing failed: $e for input: $raw');
    }
  } else {
    Loggers.app.warning('BSD memory fallback could not find enough numbers in input: $raw');
  }
  
  // Return minimal valid memory info if parsing fails
  return const Memory(total: 1, free: 0, avail: 0);
}

/// Convert memory size to KB based on unit
int _convertToKB(double amount, String unit) {
  switch (unit.toUpperCase()) {
    case 'T':
      return (amount * 1024 * 1024 * 1024).round();
    case 'G':
      return (amount * 1024 * 1024).round();
    case 'M':
      return (amount * 1024).round();
    case 'K':
    case '':
      return amount.round();
    default:
      return amount.round();
  }
}

class Swap {
  final int total;
  final int free;
  final int cached;

  const Swap({required this.total, required this.free, required this.cached});

  double get usedPercent => total == 0 ? 0.0 : 1 - free / total;

  double get freePercent => total == 0 ? 0.0 : free / total;

  @override
  String toString() {
    return 'Swap{total: $total, free: $free, cached: $cached}';
  }

  static Swap parse(String raw) {
    final items = raw.split('\n').map((e) => memItemReg.firstMatch(e)).toList();

    final total = int.tryParse(
            items.firstWhereOrNull((e) => e?.group(1) == 'SwapTotal:')
                ?.group(2) ?? '1') ?? 0;
    final free = int.tryParse(
            items.firstWhereOrNull((e) => e?.group(1) == 'SwapFree:')
                ?.group(2) ?? '1') ?? 0;
    final cached = int.tryParse(
            items.firstWhereOrNull((e) => e?.group(1) == 'SwapCached:')
                ?.group(2) ?? '0') ?? 0;

    return Swap(total: total, free: free, cached: cached);
  }
}
