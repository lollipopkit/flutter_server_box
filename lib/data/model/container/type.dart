import 'package:toolbox/data/model/container/image.dart';
import 'package:toolbox/data/model/container/ps.dart';

enum ContainerType {
  docker,
  podman,
  ;

  ContainerPs Function(String str) get ps => switch (this) {
        ContainerType.docker => DockerPs.fromRawJson,
        ContainerType.podman => PodmanPs.fromRawJson,
      };

  ContainerImg Function(String str) get img => switch (this) {
        ContainerType.docker => DockerImg.fromRawJson,
        ContainerType.podman => PodmanImg.fromRawJson,
      };
}
