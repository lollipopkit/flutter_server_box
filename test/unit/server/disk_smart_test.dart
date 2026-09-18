import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/disk_smart.dart';

/// What a drive is judged on beyond SMART's own verdict.
///
/// `healthy` stays true until a drive is nearly gone: one that has already
/// reallocated sectors answers PASSED, and that is the drive to replace. A
/// card reading `healthy` alone calls it fine.
void main() {
  DiskSmart drive(Map<String, int> attributes, {bool? healthy}) => DiskSmart(
    device: 'sda',
    healthy: healthy,
    rawData: const {},
    smartAttributes: {
      for (final e in attributes.entries)
        e.key: SmartAttribute(
          name: e.key,
          rawValue: e.value,
          flags: const SmartAttributeFlags(),
        ),
    },
  );

  test('a count above zero is a fault, named as smartctl names it', () {
    final smart = drive(const {'Reallocated_Sector_Ct': 2}, healthy: true);

    expect(smart.faults, {'reallocated': 2});
  });

  test('a count of zero is not a fault', () {
    final smart = drive(const {
      'Reallocated_Sector_Ct': 0,
      'Current_Pending_Sector': 0,
    }, healthy: true);

    expect(smart.faults, isEmpty);
  });

  test('faults come back worst first, in the order they are declared', () {
    final smart = drive(const {
      'UDMA_CRC_Error_Count': 7,
      'Current_Pending_Sector': 1,
      'Reallocated_Sector_Ct': 2,
    }, healthy: true);

    expect(smart.faults.keys.toList(), ['reallocated', 'pending', 'CRC errors']);
  });

  test('a raw value that arrived as a string still counts', () {
    // smartctl's raw values are whatever the vendor put there: the same
    // attribute is an int on one drive and a string on the next.
    final smart = DiskSmart(
      device: 'sdb',
      healthy: true,
      rawData: const {},
      smartAttributes: {
        'Reallocated_Sector_Ct': const SmartAttribute(
          name: 'Reallocated_Sector_Ct',
          rawValue: '3',
          flags: SmartAttributeFlags(),
        ),
      },
    );

    expect(smart.faults, {'reallocated': 3});
  });

  test('a device with no SMART data at all is not a device with a problem', () {
    final smart = drive(const {});

    expect(smart.notApplicable, isTrue);
    expect(smart.faults, isEmpty);
  });

  test('a device that answered attributes but no verdict is not "no data"', () {
    final smart = drive(const {'Power_On_Hours': 100});

    expect(smart.notApplicable, isFalse);
  });
}
