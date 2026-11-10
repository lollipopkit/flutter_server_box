/// The app's virtualization enums and the `sbm_virt` ones the FFI mirrors
/// are mapped by name (the `ffi`/`virt` extensions): a variant one side gains and the other
/// does not fails here rather than at run time.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_manage.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/src/rust/api/virt_model.dart' as vm;
import 'package:server_box/src/rust/api/virt_view.dart' as vv;

List<String> _names(List<Enum> values) => [for (final v in values) v.name];

void main() {
  final pairs = <String, (List<Enum>, List<Enum>)>{
    'GuestState': (VirtGuestState.values, vv.GuestState.values),
    'GuestKind': (VirtGuestKind.values, vv.GuestKind.values),
    'PowerAction': (VirtPowerAction.values, vv.PowerAction.values),
    'DiffGroup': (VirtSnapDiffGroup.values, vv.DiffGroup.values),
    'DiskKind': (VirtHwDiskKind.values, vm.DiskKind.values),
    'DeviceKind': (VirtHwDeviceKind.values, vm.DeviceKind.values),
    'UsbNaming': (VirtUsbNaming.values, vm.UsbNaming.values),
    'HwIssue': (VirtHwIssue.values, vm.HwIssue.values),
    'ResourceIssue': (VirtResIssue.values, vm.ResourceIssue.values),
    'CreateIssue': (VirtCreateIssue.values, vm.CreateIssue.values),
  };
  for (final MapEntry(key: name, value: (app, ffi)) in pairs.entries) {
    test('$name: the same variants on both sides', () {
      expect(_names(app), _names(ffi));
    });
  }
}
