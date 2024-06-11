// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/disk.dart';

void main() {
  test('parse disk', () {
    for (final raw in _raws) {
      print('---' * 10);
      final disks = Disk.parse(raw);
      print(disks.join('\n'));
      print('\n');
    }
  });
}

const _raws = [
//   '''
// Filesystem     1K-blocks     Used Available Use% Mounted on
// udev              864088        0    864088   0% /dev
// tmpfs             176724      688    176036   1% /run
// /dev/vda3       40910528 18067948  20951380  47% /
// tmpfs             883612        0    883612   0% /dev/shm
// tmpfs               5120        0      5120   0% /run/lock
// /dev/vda2         192559    11807    180752   7% /boot/efi
// tmpfs             176720      104    176616   1% /run/user/1000
// ''',
  '''
Filesystem                                                   1K-blocks        Used   Available Use% Mounted on
udev                                                          16181648           0    16181648   0% /dev
tmpfs                                                          3270528       37268     3233260   2% /run
boot-pool/ROOT/23.10.2                                       467090304     3083008   464007296   1% /
tmpfs                                                         16352624         112    16352512   1% /dev/shm
tmpfs                                                           102400           0      102400   0% /run/lock
tmpfs                                                         16352624          12    16352612   1% /tmp
boot-pool/grub                                               464015744        8448   464007296   1% /boot/grub
v2000pro                                                    1906569472         128  1906569344   1% /mnt/v2000pro
v2000pro/local-app                                          1921857408    15288064  1906569344   1% /mnt/v2000pro/local-app
v2000pro/ix-applications                                    1906569472         128  1906569344   1% /mnt/v2000pro/ix-applications
v2000pro/sdd                                                1906569472         128  1906569344   1% /mnt/v2000pro/sdd
v2000pro/ix-applications/catalogs                           1907647744     1078400  1906569344   1% /mnt/v2000pro/ix-applications/catalogs
v2000pro/ix-applications/k3s                                1907116416      547072  1906569344   1% /mnt/v2000pro/ix-applications/k3s
v2000pro/ix-applications/releases                           1906569472         128  1906569344   1% /mnt/v2000pro/ix-applications/releases
v2000pro/ix-applications/default_volumes                    1906569472         128  1906569344   1% /mnt/v2000pro/ix-applications/default_volumes
wd16-raidz                                                 19217443072         256 19217442816   1% /mnt/wd16-raidz
wd16-raidz/games                                           19386510592   169067776 19217442816   1% /mnt/wd16-raidz/games
wd16-raidz/store                                           20526360832  1308918016 19217442816   7% /mnt/wd16-raidz/store
wd16-raidz/share                                              62914560    24397312    38517248  39% /mnt/wd16-raidz/share
wd16-raidz/media                                           60509795968 41292353152 19217442816  69% /mnt/wd16-raidz/media
boot-pool/.system                                            464007424         128   464007296   1% /var/db/system
boot-pool/.system/cores                                        1048576         128     1048448   1% /var/db/system/cores
boot-pool/.system/samba4                                     464007680         384   464007296   1% /var/db/system/samba4
boot-pool/.system/rrd-ae32c386e13840b2bf9c0083275e7941       464007424         128   464007296   1% /var/db/system/rrd-ae32c386e13840b2bf9c0083275e7941
boot-pool/.system/configs-ae32c386e13840b2bf9c0083275e7941   464010368        3072   464007296   1% /var/db/system/configs-ae32c386e13840b2bf9c0083275e7941
boot-pool/.system/webui                                      464007424         128   464007296   1% /var/db/system/webui
boot-pool/.system/services                                   464007424         128   464007296   1% /var/db/system/services
boot-pool/.system/glusterd                                   464007424         128   464007296   1% /var/db/system/glusterd
boot-pool/.system/ctdb_shared_vol                            464007424         128   464007296   1% /var/db/system/ctdb_shared_vol
boot-pool/.system/netdata-ae32c386e13840b2bf9c0083275e7941   464239744      232448   464007296   1% /var/db/system/netdata-ae32c386e13840b2bf9c0083275e7941
v2000pro/ix-applications/k3s/kubelet                        1906569728         384  1906569344   1% /var/lib/kubelet
tmpfs                                                           512000          12      511988   1% /var/lib/kubelet/pods/26ae1c0e-18cf-4b75-b29d-8ce9636a7da3/volumes/kubernetes.io~projected/kube-api-access-9q9bx
shm                                                              65536           0       65536   0% /run/k3s/containerd/io.containerd.grpc.v1.cri/sandboxes/c66db36fb35c6c881949ceb69b6c9da9b3ad92e305783ea3b77e65de791f61ba/shm
tmpfs                                                           409600          12      409588   1% /var/lib/kubelet/pods/df8fac94-f5c1-4d3a-8f45-8e455510a2c8/volumes/kubernetes.io~projected/kube-api-access-4vzjm
overlay                                                     1907116416      547072  1906569344   1% /run/k3s/containerd/io.containerd.runtime.v2.task/k8s.io/c66db36fb35c6c881949ceb69b6c9da9b3ad92e305783ea3b77e65de791f61ba/rootfs
shm                                                              65536           0       65536   0% /run/k3s/containerd/io.containerd.grpc.v1.cri/sandboxes/6f49cc72b9702e2713b67128235c9dd5837b41861022a021c9d315426cc352c4/shm
overlay                                                     1907116416      547072  1906569344   1% /run/k3s/containerd/io.containerd.runtime.v2.task/k8s.io/6f49cc72b9702e2713b67128235c9dd5837b41861022a021c9d315426cc352c4/rootfs
tmpfs                                                           174080          12      174068   1% /var/lib/kubelet/pods/4d744e5b-1b98-41bd-8742-8d987f17c4af/volumes/kubernetes.io~projected/kube-api-access-jrzpb
shm                                                              65536           0       65536   0% /run/k3s/containerd/io.containerd.grpc.v1.cri/sandboxes/ed0264ba5e5beebb1614da00b9fc9ce2f4241173b4ba8f52f83ffb068dc97034/shm
tmpfs                                                           307200          12      307188   1% /var/lib/kubelet/pods/9423f3b8-712e-4539-b473-fb6e4b44481e/volumes/kubernetes.io~projected/kube-api-access-frxkj
overlay                                                     1907116416      547072  1906569344   1% /run/k3s/containerd/io.containerd.runtime.v2.task/k8s.io/ed0264ba5e5beebb1614da00b9fc9ce2f4241173b4ba8f52f83ffb068dc97034/rootfs
tmpfs                                                           921600          12      921588   1% /var/lib/kubelet/pods/b6e2f566-3d64-4533-835f-1acf24293db8/volumes/kubernetes.io~projected/kube-api-access-v5rql
shm                                                              65536           0       65536   0% /run/k3s/containerd/io.containerd.grpc.v1.cri/sandboxes/d6a11b1f80e1406ca31c260b4eadf9c7c0e9db17a98eac5d62cbcaf7ea0a013b/shm
shm                                                              65536           0       65536   0% /run/k3s/containerd/io.containerd.grpc.v1.cri/sandboxes/76401fc48a79755d503ddac81d37ac2e00e0cccbcbd0de5527e3c132a3d93709/shm
overlay                                                     1907116416      547072  1906569344   1% /run/k3s/containerd/io.containerd.runtime.v2.task/k8s.io/d6a11b1f80e1406ca31c260b4eadf9c7c0e9db17a98eac5d62cbcaf7ea0a013b/rootfs
tmpfs                                                           614400          12      614388   1% /var/lib/kubelet/pods/5676e37b-d0a4-4910-b3fd-cf7ec25f201f/volumes/kubernetes.io~projected/kube-api-access-jrm62
overlay                                                     1907116416      547072  1906569344   1% /run/k3s/containerd/io.containerd.runtime.v2.task/k8s.io/76401fc48a79755d503ddac81d37ac2e00e0cccbcbd0de5527e3c132a3d93709/rootfs
shm                                                              65536           0       65536   0% /run/k3s/containerd/io.containerd.grpc.v1.cri/sandboxes/22f66d268f14cedc9d16ff0c31a4babdb4a082e7444f72a745b8f0e6ccc7cec7/shm
tmpfs                                                           307200          12      307188   1% /var/lib/kubelet/pods/b528d0cb-cf84-4f25-8d5d-eae89f6c853e/volumes/kubernetes.io~projected/kube-api-access-5bgtp
overlay                                                     1907116416      547072  1906569344   1% /run/k3s/containerd/io.containerd.runtime.v2.task/k8s.io/22f66d268f14cedc9d16ff0c31a4babdb4a082e7444f72a745b8f0e6ccc7cec7/rootfs
tmpfs                                                         32705248          12    32705236   1% /var/lib/kubelet/pods/c2070b60-ec0a-4107-97ad-f1eb475ebac3/volumes/kubernetes.io~projected/kube-api-access-scxv6
shm                                                              65536           0       65536   0% /run/k3s/containerd/io.containerd.grpc.v1.cri/sandboxes/ceb3da406b1d6f38dfab42cc314b69a510947e42867afae6b33d0d8e10e705b5/shm
tmpfs                                                         32705248          12    32705236   1% /var/lib/kubelet/pods/593d00aa-16bb-4d18-906d-37731ba3f8bf/volumes/kubernetes.io~projected/kube-api-access-x54qh
shm                                                              65536           0       65536   0% /run/k3s/containerd/io.containerd.grpc.v1.cri/sandboxes/26547c6bfd920ed69d0d95c48a3d890695b0238420e4c54ee56075dc43e03ea5/shm
overlay                                                     1907116416      547072  1906569344   1% /run/k3s/containerd/io.containerd.runtime.v2.task/k8s.io/ceb3da406b1d6f38dfab42cc314b69a510947e42867afae6b33d0d8e10e705b5/rootfs
overlay                                                     1907116416      547072  1906569344   1% /run/k3s/containerd/io.containerd.runtime.v2.task/k8s.io/2119c0e105c80619f630691263450234456349d3ddce64b77a184491bda56dd2/rootfs
overlay                                                     1907116416      547072  1906569344   1% /run/k3s/containerd/io.containerd.runtime.v2.task/k8s.io/26547c6bfd920ed69d0d95c48a3d890695b0238420e4c54ee56075dc43e03ea5/rootfs
tmpfs                                                         32705248          12    32705236   1% /var/lib/kubelet/pods/eccfba54-48aa-4950-b3b8-e18ad155e16d/volumes/kubernetes.io~projected/kube-api-access-lc9gs
shm                                                              65536           0       65536   0% /run/k3s/containerd/io.containerd.grpc.v1.cri/sandboxes/dda821508458f2207ebfb53485b33932724c5ede375efebbfc002b511daef1f3/shm
overlay                                                     1907116416      547072  1906569344   1% /run/k3s/containerd/io.containerd.runtime.v2.task/k8s.io/dda821508458f2207ebfb53485b33932724c5ede375efebbfc002b511daef1f3/rootfs
shm                                                              65536           0       65536   0% /run/k3s/containerd/io.containerd.grpc.v1.cri/sandboxes/510d5900ec9d403ba57689325b5560f713704d69c784487d9c3be127316e1db8/shm
overlay                                                     1907116416      547072  1906569344   1% /run/k3s/containerd/io.containerd.runtime.v2.task/k8s.io/510d5900ec9d403ba57689325b5560f713704d69c784487d9c3be127316e1db8/rootfs
overlay                                                     1907116416      547072  1906569344   1% /run/k3s/containerd/io.containerd.runtime.v2.task/k8s.io/a873561950eb40a58a6dfa3dd7e74a171a31b598cd3edacd930d09a8fede9ea1/rootfs
overlay                                                     1907116416      547072  1906569344   1% /run/k3s/containerd/io.containerd.runtime.v2.task/k8s.io/fa65821375d894f5039a763315734ed51befdafaa5215e30d2f8f889e351c1a3/rootfs
overlay                                                     1907116416      547072  1906569344   1% /run/k3s/containerd/io.containerd.runtime.v2.task/k8s.io/3e463fd96ee1e2ddba7aca7e8cb161b59f33b0a778e5f7d8c1a5939a72a6f4a5/rootfs
v2000pro/pve                                                1906694784      125440  1906569344   1% /mnt/v2000pro/pve
v2000pro/download                                           1906569472         128  1906569344   1% /mnt/v2000pro/download''',
];
