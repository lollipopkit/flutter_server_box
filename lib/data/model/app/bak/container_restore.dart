import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/res/store.dart';

const _containerProviderConfigKey = 'providerConfig';

Future<void> restoreContainerFromMap(
  Map<String, Object?> container, {
  bool Function(String key)? shouldSkipKey,
}) async {
  await Stores.container.clear();
  for (final entry in container.entries) {
    final key = entry.key;
    if (shouldSkipKey?.call(key) ?? false) continue;
    final value = entry.value;
    if (value == null) continue;

    if (key.startsWith(_containerProviderConfigKey)) {
      final id = key.substring(_containerProviderConfigKey.length);
      if (id.isEmpty) {
        Loggers.app.warning(
          'Skip restoring container provider config with empty id (key=`$key`)',
        );
        continue;
      }
      final raw = value.toString();
      final type = _resolveContainerType(raw);
      if (type != null) {
        await Stores.container.setType(type, id);
      } else {
        Loggers.app.warning(
          'Skip restoring unknown container provider type '
          '(key=`$key`, id=`$id`, raw=`$raw`)',
        );
      }
      continue;
    }

    await Stores.container.put(key, value.toString());
  }
}

ContainerType? _resolveContainerType(String raw) {
  try {
    return ContainerType.values.byName(raw);
  } catch (_) {
    // Fallback for legacy serialized enum strings like `ContainerType.docker`.
    for (final type in ContainerType.values) {
      if (type.toString() == raw) {
        return type;
      }
    }
    return null;
  }
}
