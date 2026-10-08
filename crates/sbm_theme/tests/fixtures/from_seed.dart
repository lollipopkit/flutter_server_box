import 'dart:convert';
import 'package:material_color_utilities/material_color_utilities.dart';

final roles = <String, DynamicColor>{
  'primary': MaterialDynamicColors.primary, 'onPrimary': MaterialDynamicColors.onPrimary,
  'primaryContainer': MaterialDynamicColors.primaryContainer, 'onPrimaryContainer': MaterialDynamicColors.onPrimaryContainer,
  'primaryFixed': MaterialDynamicColors.primaryFixed, 'primaryFixedDim': MaterialDynamicColors.primaryFixedDim,
  'onPrimaryFixed': MaterialDynamicColors.onPrimaryFixed, 'onPrimaryFixedVariant': MaterialDynamicColors.onPrimaryFixedVariant,
  'secondary': MaterialDynamicColors.secondary, 'onSecondary': MaterialDynamicColors.onSecondary,
  'secondaryContainer': MaterialDynamicColors.secondaryContainer, 'onSecondaryContainer': MaterialDynamicColors.onSecondaryContainer,
  'secondaryFixed': MaterialDynamicColors.secondaryFixed, 'secondaryFixedDim': MaterialDynamicColors.secondaryFixedDim,
  'onSecondaryFixed': MaterialDynamicColors.onSecondaryFixed, 'onSecondaryFixedVariant': MaterialDynamicColors.onSecondaryFixedVariant,
  'tertiary': MaterialDynamicColors.tertiary, 'onTertiary': MaterialDynamicColors.onTertiary,
  'tertiaryContainer': MaterialDynamicColors.tertiaryContainer, 'onTertiaryContainer': MaterialDynamicColors.onTertiaryContainer,
  'tertiaryFixed': MaterialDynamicColors.tertiaryFixed, 'tertiaryFixedDim': MaterialDynamicColors.tertiaryFixedDim,
  'onTertiaryFixed': MaterialDynamicColors.onTertiaryFixed, 'onTertiaryFixedVariant': MaterialDynamicColors.onTertiaryFixedVariant,
  'error': MaterialDynamicColors.error, 'onError': MaterialDynamicColors.onError,
  'errorContainer': MaterialDynamicColors.errorContainer, 'onErrorContainer': MaterialDynamicColors.onErrorContainer,
  'surface': MaterialDynamicColors.surface, 'onSurface': MaterialDynamicColors.onSurface,
  'surfaceDim': MaterialDynamicColors.surfaceDim, 'surfaceBright': MaterialDynamicColors.surfaceBright,
  'surfaceContainerLowest': MaterialDynamicColors.surfaceContainerLowest, 'surfaceContainerLow': MaterialDynamicColors.surfaceContainerLow,
  'surfaceContainer': MaterialDynamicColors.surfaceContainer, 'surfaceContainerHigh': MaterialDynamicColors.surfaceContainerHigh,
  'surfaceContainerHighest': MaterialDynamicColors.surfaceContainerHighest, 'onSurfaceVariant': MaterialDynamicColors.onSurfaceVariant,
  'outline': MaterialDynamicColors.outline, 'outlineVariant': MaterialDynamicColors.outlineVariant,
  'shadow': MaterialDynamicColors.shadow, 'scrim': MaterialDynamicColors.scrim,
  'inverseSurface': MaterialDynamicColors.inverseSurface, 'onInverseSurface': MaterialDynamicColors.inverseOnSurface,
  'inversePrimary': MaterialDynamicColors.inversePrimary, 'surfaceTint': MaterialDynamicColors.surfaceTint,
};

void main() {
  final out = <String, dynamic>{};
  for (final seed in [0xFF880E4F, 0xFF61AFEF, 0xFF2FA85A, 0xFFFFC107, 0xFF000000, 0xFFFFFFFF, 0xFF730C37]) {
    for (final dark in [false, true]) {
      final s = SchemeTonalSpot(sourceColorHct: Hct.fromInt(seed), isDark: dark, contrastLevel: 0.0);
      out['${seed.toRadixString(16)}-${dark ? 'dark' : 'light'}'] = {
        for (final e in roles.entries) e.key: e.value.getArgb(s),
      };
    }
  }
  print(jsonEncode(out));
}
