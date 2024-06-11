import 'package:server_box/data/model/container/image.dart';
import 'package:server_box/data/model/container/ps.dart';

enum ContainerType {
  docker,
  podman,
  ;

  ContainerPs Function(String str) get ps => switch (this) {
        ContainerType.docker => DockerPs.parse,
        ContainerType.podman => PodmanPs.fromRawJson,
      };

  ContainerImg Function(String str) get img => switch (this) {
        ContainerType.docker => DockerImg.fromRawJson,
        ContainerType.podman => PodmanImg.fromRawJson,
      };
}
