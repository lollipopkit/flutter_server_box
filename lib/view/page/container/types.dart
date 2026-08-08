part of 'container.dart';

enum _SettingsMenuItems { editContainerHost, switchProvider }

enum _PruneTypes {
  images,
  containers,
  volumes,
  system;

  String get label => switch (this) {
    _PruneTypes.images => l10n.image,
    _PruneTypes.containers => libL10n.container,
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
