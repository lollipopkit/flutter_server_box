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

enum _SettingsMenuItems {
  editContainerHost,
  switchProvider;

  IconData get icon => switch (this) {
    _SettingsMenuItems.editContainerHost => Icons.dns_outlined,
    _SettingsMenuItems.switchProvider => Icons.swap_horiz,
  };
}

enum _PruneTypes {
  volumes,
  unusedData;

  String get label => switch (this) {
    _PruneTypes.volumes => l10n.pruneVolumes,
    _PruneTypes.unusedData => l10n.pruneUnusedData,
  };

  IconData get icon => switch (this) {
    _PruneTypes.volumes => Icons.storage_outlined,
    _PruneTypes.unusedData => Icons.cleaning_services_outlined,
  };

  String? get tip {
    return switch (this) {
      _PruneTypes.unusedData => l10n.dockerPruneTip,
      _ => null,
    };
  }
}
