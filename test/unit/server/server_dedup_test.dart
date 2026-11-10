import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/server_dedup.dart';

import '../../helpers/spi_fixture.dart';

void main() {
  test('a taken name gets the first free suffix, across the batch too', () {
    final resolved = ServerDeduplication.resolveNameConflicts(
      [
        spiFixture(id: 'a', name: 'web'),
        spiFixture(id: 'b', name: 'web'),
        spiFixture(id: 'c', name: 'db'),
      ],
      existingServers: [
        spiFixture(id: 'x', name: 'web'),
        spiFixture(id: 'y', name: 'web (1)'),
      ],
    );
    expect(resolved.map((e) => (e.id, e.name)), [
      ('a', 'web (2)'),
      ('b', 'web (3)'),
      ('c', 'db'),
    ]);
  });

  test('uniqueName keeps a free name', () {
    expect(ServerDeduplication.uniqueName('nas', taken: (_) => false), 'nas');
  });
}
