part of 'container.dart';

enum _SettingsMenuItems { editDockerHost, switchProvider }

enum _PruneTypes {
  images,
  containers,
  volumes,
  system;

  String? get tip {
    return switch (this) {
      _PruneTypes.system =>
        'This will remove all unused data, including images, containers, volumes, and networks.',
      _ => null,
    };
  }
}
