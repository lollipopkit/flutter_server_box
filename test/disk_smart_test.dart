import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/disk_smart.dart';

const _raw = '''
{
  "json_format_version": [
    1,
    0
  ],
  "smartctl": {
    "version": [
      7,
      4
    ],
    "pre_release": false,
    "svn_revision": "5530",
    "platform_info": "x86_64-linux-6.6.58-rt45-intel-ese-standard-lts-rt",
    "build_info": "(local build)",
    "argv": [
      "smartctl",
      "-A",
      "-j",
      "/dev/sda"
    ],
    "drive_database_version": {
      "string": "7.3/5528"
    },
    "exit_status": 0
  },
  "local_time": {
    "time_t": 1749074092,
    "asctime": "Thu Jun  5 05:54:52 2025 CST"
  },
  "device": {
    "name": "/dev/sda",
    "info_name": "/dev/sda [SAT]",
    "type": "sat",
    "protocol": "ATA"
  },
  "ata_smart_attributes": {
    "revision": 16,
    "table": [
      {
        "id": 9,
        "name": "Power_On_Hours",
        "value": 100,
        "worst": 100,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 18,
          "string": "-O--C- ",
          "prefailure": false,
          "updated_online": true,
          "performance": false,
          "error_rate": false,
          "event_count": true,
          "auto_keep": false
        },
        "raw": {
          "value": 17472,
          "string": "17472"
        }
      },
      {
        "id": 12,
        "name": "Power_Cycle_Count",
        "value": 100,
        "worst": 100,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 18,
          "string": "-O--C- ",
          "prefailure": false,
          "updated_online": true,
          "performance": false,
          "error_rate": false,
          "event_count": true,
          "auto_keep": false
        },
        "raw": {
          "value": 1948,
          "string": "1948"
        }
      },
      {
        "id": 167,
        "name": "Write_Protect_Mode",
        "value": 100,
        "worst": 100,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 34,
          "string": "-O---K ",
          "prefailure": false,
          "updated_online": true,
          "performance": false,
          "error_rate": false,
          "event_count": false,
          "auto_keep": true
        },
        "raw": {
          "value": 0,
          "string": "0"
        }
      },
      {
        "id": 168,
        "name": "SATA_Phy_Error_Count",
        "value": 100,
        "worst": 100,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 18,
          "string": "-O--C- ",
          "prefailure": false,
          "updated_online": true,
          "performance": false,
          "error_rate": false,
          "event_count": true,
          "auto_keep": false
        },
        "raw": {
          "value": 0,
          "string": "0"
        }
      },
      {
        "id": 172,
        "name": "Erase_Fail_Count",
        "value": 100,
        "worst": 100,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 50,
          "string": "-O--CK ",
          "prefailure": false,
          "updated_online": true,
          "performance": false,
          "error_rate": false,
          "event_count": true,
          "auto_keep": true
        },
        "raw": {
          "value": 0,
          "string": "0"
        }
      },
      {
        "id": 173,
        "name": "MaxAvgErase_Ct",
        "value": 100,
        "worst": 100,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 0,
          "string": "------ ",
          "prefailure": false,
          "updated_online": false,
          "performance": false,
          "error_rate": false,
          "event_count": false,
          "auto_keep": false
        },
        "raw": {
          "value": 8257696,
          "string": "160 (Average 126)"
        }
      },
      {
        "id": 181,
        "name": "Program_Fail_Count",
        "value": 100,
        "worst": 100,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 18,
          "string": "-O--C- ",
          "prefailure": false,
          "updated_online": true,
          "performance": false,
          "error_rate": false,
          "event_count": true,
          "auto_keep": false
        },
        "raw": {
          "value": 0,
          "string": "0"
        }
      },
      {
        "id": 187,
        "name": "Reported_Uncorrect",
        "value": 100,
        "worst": 100,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 50,
          "string": "-O--CK ",
          "prefailure": false,
          "updated_online": true,
          "performance": false,
          "error_rate": false,
          "event_count": true,
          "auto_keep": true
        },
        "raw": {
          "value": 0,
          "string": "0"
        }
      },
      {
        "id": 192,
        "name": "Unsafe_Shutdown_Count",
        "value": 100,
        "worst": 100,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 18,
          "string": "-O--C- ",
          "prefailure": false,
          "updated_online": true,
          "performance": false,
          "error_rate": false,
          "event_count": true,
          "auto_keep": false
        },
        "raw": {
          "value": 141,
          "string": "141"
        }
      },
      {
        "id": 194,
        "name": "Temperature_Celsius",
        "value": 65,
        "worst": 39,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 35,
          "string": "PO---K ",
          "prefailure": true,
          "updated_online": true,
          "performance": false,
          "error_rate": false,
          "event_count": false,
          "auto_keep": true
        },
        "raw": {
          "value": 261993922595,
          "string": "35 (Min/Max 14/61)"
        }
      },
      {
        "id": 196,
        "name": "Reallocated_Event_Count",
        "value": 100,
        "worst": 100,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 0,
          "string": "------ ",
          "prefailure": false,
          "updated_online": false,
          "performance": false,
          "error_rate": false,
          "event_count": false,
          "auto_keep": false
        },
        "raw": {
          "value": 0,
          "string": "0"
        }
      },
      {
        "id": 218,
        "name": "CRC_Error_Count",
        "value": 100,
        "worst": 100,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 0,
          "string": "------ ",
          "prefailure": false,
          "updated_online": false,
          "performance": false,
          "error_rate": false,
          "event_count": false,
          "auto_keep": false
        },
        "raw": {
          "value": 0,
          "string": "0"
        }
      },
      {
        "id": 231,
        "name": "SSD_Life_Left",
        "value": 100,
        "worst": 100,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 19,
          "string": "PO--C- ",
          "prefailure": true,
          "updated_online": true,
          "performance": false,
          "error_rate": false,
          "event_count": true,
          "auto_keep": false
        },
        "raw": {
          "value": 93,
          "string": "93"
        }
      },
      {
        "id": 233,
        "name": "Flash_Writes_GiB",
        "value": 100,
        "worst": 100,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 19,
          "string": "PO--C- ",
          "prefailure": true,
          "updated_online": true,
          "performance": false,
          "error_rate": false,
          "event_count": true,
          "auto_keep": false
        },
        "raw": {
          "value": 17618,
          "string": "17618"
        }
      },
      {
        "id": 241,
        "name": "Lifetime_Writes_GiB",
        "value": 100,
        "worst": 100,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 18,
          "string": "-O--C- ",
          "prefailure": false,
          "updated_online": true,
          "performance": false,
          "error_rate": false,
          "event_count": true,
          "auto_keep": false
        },
        "raw": {
          "value": 11520,
          "string": "11520"
        }
      },
      {
        "id": 242,
        "name": "Lifetime_Reads_GiB",
        "value": 100,
        "worst": 100,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 18,
          "string": "-O--C- ",
          "prefailure": false,
          "updated_online": true,
          "performance": false,
          "error_rate": false,
          "event_count": true,
          "auto_keep": false
        },
        "raw": {
          "value": 12361,
          "string": "12361"
        }
      },
      {
        "id": 244,
        "name": "Average_Erase_Count",
        "value": 100,
        "worst": 100,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 0,
          "string": "------ ",
          "prefailure": false,
          "updated_online": false,
          "performance": false,
          "error_rate": false,
          "event_count": false,
          "auto_keep": false
        },
        "raw": {
          "value": 126,
          "string": "126"
        }
      },
      {
        "id": 245,
        "name": "Max_Erase_Count",
        "value": 100,
        "worst": 100,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 0,
          "string": "------ ",
          "prefailure": false,
          "updated_online": false,
          "performance": false,
          "error_rate": false,
          "event_count": false,
          "auto_keep": false
        },
        "raw": {
          "value": 160,
          "string": "160"
        }
      },
      {
        "id": 246,
        "name": "Total_Erase_Count",
        "value": 100,
        "worst": 100,
        "thresh": 0,
        "when_failed": "",
        "flags": {
          "value": 0,
          "string": "------ ",
          "prefailure": false,
          "updated_online": false,
          "performance": false,
          "error_rate": false,
          "event_count": false,
          "auto_keep": false
        },
        "raw": {
          "value": 2749648,
          "string": "2749648"
        }
      }
    ]
  },
  "power_on_time": {
    "hours": 17472
  },
  "power_cycle_count": 1948,
  "temperature": {
    "current": 35
  }
}''';

void main() {
  group('DiskSmart', () {
    late DiskSmart diskSmart;

    setUp(() {
      final parsedResults = DiskSmart.parse(_raw);
      expect(parsedResults.length, 1, reason: 'Should parse one disk entry');
      diskSmart = parsedResults.first;
    });

    test('parses basic device info correctly', () {
      expect(diskSmart.device, '/dev/sda');
      expect(diskSmart.temperature, 35);
      expect(diskSmart.powerOnHours, 17472);
      expect(diskSmart.powerCycleCount, 1948);
    });

    test('has correct SMART attributes', () {
      expect(diskSmart.smartAttributes.length, isNot(0));
      final tempAttr = diskSmart.getAttribute('Temperature_Celsius');
      expect(tempAttr, isNotNull);
      expect(tempAttr?.value, 65);
      expect(tempAttr?.worst, 39);
      expect(tempAttr?.rawString, '35 (Min/Max 14/61)');

      final powerOnAttr = diskSmart.getAttribute('Power_On_Hours');
      expect(powerOnAttr?.rawValue, 17472);

      // Test non-existent attribute
      expect(diskSmart.getAttribute('NonExistent'), isNull);
    });

    test('extracts attribute flags correctly', () {
      final tempAttr = diskSmart.getAttribute('Temperature_Celsius');
      expect(tempAttr?.flags.prefailure, isTrue);
      expect(tempAttr?.flags.updatedOnline, isTrue);
      expect(tempAttr?.flags.performance, isFalse);

      final lifeLeftAttr = diskSmart.getAttribute('SSD_Life_Left');
      expect(lifeLeftAttr?.flags.prefailure, isTrue);
      expect(lifeLeftAttr?.flags.eventCount, isTrue);
    });

    test('calculates SSD health metrics correctly', () {
      expect(diskSmart.ssdLifeLeft, 93);
      expect(diskSmart.lifetimeWritesGiB, 11520);
      expect(diskSmart.lifetimeReadsGiB, 12361);
      expect(diskSmart.unsafeShutdownCount, 141);
      expect(diskSmart.averageEraseCount, 126);
      expect(diskSmart.maxEraseCount, 160);
    });

    test('toMap() converts all important data', () {
      final map = diskSmart.toJson();
      expect(map['device'], '/dev/sda');
      expect(map['temperature'], 35);
      expect(map['powerOnHours'], 17472);
      expect(map['powerCycleCount'], 1948);
      expect(map['smartAttributes'], isA<Map>());
    });
  });

  group('DiskSmart parsing edge cases', () {
    test('handles empty input', () {
      final results = DiskSmart.parse('');
      expect(results, isEmpty);
    });

    test('handles malformed JSON gracefully', () {
      final results = DiskSmart.parse('{not valid json}');
      expect(results, isEmpty);
    });

    test('handles multiple disk data', () {
      final results = DiskSmart.parse('$_raw\n\n$_raw');
      expect(results.length, 2);
    });
  });
}
