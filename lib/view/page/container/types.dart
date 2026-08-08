part of 'container.dart';

enum _ContainerTabs {
  ps,
  images,
  settings;

  String get i18n => switch (this) {
    _ContainerTabs.ps => libL10n.container,
    _ContainerTabs.images => l10n.image,
    _ContainerTabs.settings => libL10n.setting,
  };
}

enum _SettingsMenuItems { editContainerHost, switchProvider }

enum _PruneTypes {
  volumes,
  system;

  String get label => switch (this) {
    _PruneTypes.volumes => l10n.volume,
    _PruneTypes.system => libL10n.system,
  };

  String? get tip {
    return switch (this) {
      _PruneTypes.system =>
        'This will remove all unused data, including images, containers, volumes, and networks.',
      _ => null,
    };
  }
}
