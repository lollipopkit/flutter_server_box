import 'package:flutter/material.dart';

extension LocaleX on Locale {
  String get name {
    if (countryCode == null) {
      return languageCode;
    }
    return '${languageCode}_$countryCode';
  }
}

extension String2Locale on String {
  Locale get toLocale {
    final parts = split('_');
    if (parts.length == 1) {
      return Locale(parts[0]);
    }
    return Locale(parts[0], parts[1]);
  }
}
