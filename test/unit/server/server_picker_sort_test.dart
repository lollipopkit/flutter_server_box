import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/view/widget/server_picker_sort.dart';

Spi _spi(String id, String name) =>
    Spi(id: id, name: name, ssh: const SshCredential(ip: '10.0.0.1'));

void main() {
  final servers = {
    '1': _spi('1', 'beta'),
    '2': _spi('2', 'Alpha'),
    '3': _spi('3', 'gamma'),
  };
  const order = ['1', '2', '3'];

  test('name sort compares case-insensitively in both directions', () {
    const asc = ServerPickerSortOrder(
      ServerPickerSortField.name,
      ascending: true,
    );
    const desc = ServerPickerSortOrder(
      ServerPickerSortField.name,
      ascending: false,
    );

    expect(asc.apply(order, servers), ['2', '1', '3']);
    expect(desc.apply(order, servers), ['3', '1', '2']);
  });

  test('added sort preserves or reverses join order', () {
    const asc = ServerPickerSortOrder(
      ServerPickerSortField.added,
      ascending: true,
    );
    const desc = ServerPickerSortOrder(
      ServerPickerSortField.added,
      ascending: false,
    );

    expect(asc.apply(order, servers), ['1', '2', '3']);
    expect(desc.apply(order, servers), ['3', '2', '1']);
  });

  test('fromStored falls back to name for out-of-range indices', () {
    expect(ServerPickerSortField.fromStored(-1), ServerPickerSortField.name);
    expect(ServerPickerSortField.fromStored(99), ServerPickerSortField.name);
    expect(ServerPickerSortField.fromStored(1), ServerPickerSortField.added);
  });
}
