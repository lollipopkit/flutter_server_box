/*
{
    "changelog": {
        "mac": "xxx",
        "ios": "xxx",
        "android": ""
    },
    "build": {
        "min": {
            "mac": 1,
            "ios": 1,
            "android": 1
        },
        "last": {
            "mac": 1,
            "ios": 1,
            "android": 1
        }
    },
    "url": {
        "mac": "https://apps.apple.com/app/id1586449703",
        "ios": "https://apps.apple.com/app/id1586449703",
        "android": "https://cdn3.cust.app/uploads/ServerBox_262_Arm64.apk"
    }
}
*/

import 'dart:convert';

import 'package:toolbox/core/utils/platform/base.dart';

class AppUpdate {
  const AppUpdate({
    required this.changelog,
    required this.build,
    required this.url,
  });

  final AppUpdatePlatformSpecific<String> changelog;
  final Build build;
  final AppUpdatePlatformSpecific<String> url;

  factory AppUpdate.fromRawJson(String str) =>
      AppUpdate.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory AppUpdate.fromJson(Map<String, dynamic> json) => AppUpdate(
        changelog: AppUpdatePlatformSpecific.fromJson(json["changelog"]),
        build: Build.fromJson(json["build"]),
        url: AppUpdatePlatformSpecific.fromJson(json["url"]),
      );

  Map<String, dynamic> toJson() => {
        "changelog": changelog.toJson(),
        "build": build.toJson(),
        "url": url.toJson(),
      };
}

class Build {
  Build({
    required this.min,
    required this.last,
  });

  final AppUpdatePlatformSpecific<int> min;
  final AppUpdatePlatformSpecific<int> last;

  factory Build.fromRawJson(String str) => Build.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Build.fromJson(Map<String, dynamic> json) => Build(
        min: AppUpdatePlatformSpecific.fromJson(json["min"]),
        last: AppUpdatePlatformSpecific.fromJson(json["last"]),
      );

  Map<String, dynamic> toJson() => {
        "min": min.toJson(),
        "last": last.toJson(),
      };
}

class AppUpdatePlatformSpecific<T> {
  AppUpdatePlatformSpecific({
    required this.mac,
    required this.ios,
    required this.android,
    required this.windows,
    required this.linux,
  });

  final T mac;
  final T ios;
  final T android;
  final T windows;
  final T linux;

  factory AppUpdatePlatformSpecific.fromRawJson(String str) =>
      AppUpdatePlatformSpecific.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory AppUpdatePlatformSpecific.fromJson(Map<String, dynamic> json) =>
      AppUpdatePlatformSpecific(
        mac: json["mac"],
        ios: json["ios"],
        android: json["android"],
        windows: json["windows"],
        linux: json["linux"],
      );

  Map<String, dynamic> toJson() => {
        "mac": mac,
        "ios": ios,
        "android": android,
        "windows": windows,
        "linux": linux,
      };

  T? get current {
    switch (OS.type) {
      case OS.macos:
        return mac;
      case OS.ios:
        return ios;
      case OS.android:
        return android;
      case OS.windows:
        return windows;
      case OS.linux:
        return linux;

      /// Not implemented yet.
      case OS.web || OS.fuchsia || OS.unknown:
        return null;
    }
  }
}
