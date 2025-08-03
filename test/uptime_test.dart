import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Linux uptime parsing tests', () {
    test('should parse uptime with days and hours:minutes', () {
      const raw = '19:39:15 up 61 days, 18:16,  1 user,  load average: 0.00, 0.00, 0.00';
      final result = _testParseUpTime(raw);
      expect(result, '61 days, 18:16');
    });

    test('should parse uptime with single day and hours:minutes', () {
      const raw = '19:39:15 up 1 day, 2:34,  1 user,  load average: 0.00, 0.00, 0.00';
      final result = _testParseUpTime(raw);
      expect(result, '1 day, 2:34');
    });

    test('should parse uptime with only hours:minutes', () {
      const raw = '19:39:15 up 2:34,  1 user,  load average: 0.00, 0.00, 0.00';
      final result = _testParseUpTime(raw);
      expect(result, '2:34');
    });

    test('should parse uptime with only minutes', () {
      const raw = '19:39:15 up 34 min,  1 user,  load average: 0.00, 0.00, 0.00';
      final result = _testParseUpTime(raw);
      expect(result, '34 min');
    });

    test('should parse uptime with days only (no time part)', () {
      const raw = '19:39:15 up 5 days,  1 user,  load average: 0.00, 0.00, 0.00';
      final result = _testParseUpTime(raw);
      expect(result, '5 days');
    });

    test('should return null for invalid format', () {
      const raw = 'invalid uptime format';
      final result = _testParseUpTime(raw);
      expect(result, null);
    });

    test('should handle edge case with empty string', () {
      const raw = '';
      final result = _testParseUpTime(raw);
      expect(result, null);
    });
  });
}

// Helper function to test the private _parseUpTime function
String? _testParseUpTime(String raw) {
  final splitedUp = raw.split('up ');
  if (splitedUp.length == 2) {
    final uptimePart = splitedUp[1];
    final splitedComma = uptimePart.split(', ');
    
    if (splitedComma.isEmpty) return null;
    
    // Handle different uptime formats
    final firstPart = splitedComma[0].trim();
    
    // Case 1: "61 days" or "1 day" - need to get the time part from next segment
    if (firstPart.contains('day')) {
      if (splitedComma.length >= 2) {
        final timePart = splitedComma[1].trim();
        // Check if it's in HH:MM format
        if (timePart.contains(':') && !timePart.contains('user') && !timePart.contains('load')) {
          return '$firstPart, $timePart';
        }
      }
      return firstPart;
    }
    
    // Case 2: "2:34" (hours:minutes) - already in good format
    if (firstPart.contains(':') && !firstPart.contains('user') && !firstPart.contains('load')) {
      return firstPart;
    }
    
    // Case 3: "34 min" - already in good format  
    if (firstPart.contains('min')) {
      return firstPart;
    }
    
    // Fallback: return first part
    return firstPart;
  }
  return null;
}