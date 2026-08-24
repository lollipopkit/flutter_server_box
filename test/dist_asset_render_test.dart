/// That every shipped mark actually draws.
///
/// The files go in unmodified — required, since a modified CC BY-SA file is an
/// adaptation — so they are whatever each project publishes, not something
/// tidied to suit this renderer. flutter_svg silently draws nothing for what it
/// cannot handle: no throw, no log, an empty box the size you asked for. So
/// "the asset exists and the widget was built" proves nothing, and the earlier
/// tests asserted exactly that.
///
/// This compiles each one the way flutter_svg does and checks something came
/// out.
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bundled = {
    Dist.debian,
    Dist.gentoo,
    Dist.rocky,
    Dist.nixos,
    Dist.alpine,
  };

  for (final dist in bundled) {
    test('${dist.name} compiles to something with paths in it', () async {
      final path = dist.markAsset!;
      final svg = await rootBundle.loadString(path);
      final instructions = parseWithoutOptimizers(svg, key: path);

      expect(
        instructions.paths,
        isNotEmpty,
        reason: '$path parsed to no geometry — it would draw an empty box',
      );
      // A path with no paint is invisible. Some of these carry their fill in a
      // `style` attribute rather than `fill`, which is exactly the sort of
      // thing that parses and then draws nothing.
      expect(
        instructions.paints,
        isNotEmpty,
        reason: '$path has geometry but nothing to fill it with',
      );
    });
  }
}
