// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:toolbox/data/model/server/disk.dart';

void main() {
  test('test parse disk', () {
    const raw = '''
Filesystem Size Used Available Use% Mounted on
none 400.0M 321.0M 79.0M 80% /
devtmpfs 7.7G 4.0K 7.7G 0% /dev
tmpfs 64.0M 1.5M 62.5M 2% /tmp
tmpfs 7.7G 144.0K 7.7G 0% /dev/shm
tmpfs 16.0M 0 16.0M 0% /share
/dev/mmcblk0p5 7.7M 46.0K 7.7M 1% /mnt/boot_config
tmpfs 16.0M 0 16.0M 0% /mnt/snapshot/export
/dev/md9 493.5M 169.3M 324.2M 34% /mnt/HDA_ROOT
cgroup_root 7.7G 0 7.7G 0% /sys/fs/cgroup
/dev/mapper/vg1-lv1312
                        352.1M 232.0K 351.9M 0% /mnt/pool1
/dev/mapper/cachedev1
                          3.0T 1.4T 1.6T 48% /share/CACHEDEV1_DATA
/dev/mapper/cachedev2
                        792.8G 823.3M 791.5G 0% /share/CACHEDEV2_DATA
/dev/md13 417.0M 387.1M 29.9M 93% /mnt/ext
tmpfs 32.0M 27.2M 4.8M 85% /samba_third_party
tmpfs 48.0M 36.0K 48.0M 0% /share/CACHEDEV1_DATA/.samba/lock/msg.lock
df: /mnt/ext/opt/samba/private/msg.sock: Permission denied
/dev/mapper/vg1-snap10001
                          3.0T 1.4T 1.6T 47% /mnt/snapshot/1/10001
/dev/mapper/vg1-snap10004
                          3.0T 1.1T 1.9T 36% /mnt/snapshot/1/10004
/dev/mapper/vg1-snap10007
                          3.0T 1.3T 1.7T 43% /mnt/snapshot/1/10007
/dev/mapper/vg1-snap10008
                          3.0T 1.4T 1.6T 48% /mnt/snapshot/1/10008
/dev/mapper/vg1-snap10009
                          3.0T 1.1T 1.9T 37% /mnt/snapshot/1/10009
/dev/mapper/vg1-snap10010
                          3.0T 1.4T 1.6T 46% /mnt/snapshot/1/10010
/dev/mapper/vg1-snap10011
                          3.0T 1.1T 1.9T 38% /mnt/snapshot/1/10011
/dev/mapper/vg1-snap10012
                          3.0T 1.4T 1.6T 48% /mnt/snapshot/1/10012
/dev/mapper/vg1-snap10013
                          3.0T 1.4T 1.6T 48% /mnt/snapshot/1/10013
/dev/mapper/vg1-snap10014
                          3.0T 1.2T 1.8T 39% /mnt/snapshot/1/10014
/dev/mapper/vg1-snap10015
                          3.0T 1.3T 1.7T 43% /mnt/snapshot/1/10015
/dev/mapper/vg1-snap10017
                          3.0T 1.4T 1.6T 46% /mnt/snapshot/1/10017
/dev/mapper/cachedev1
                          3.0T 1.4T 1.6T 48% /lib/modules/5.10.60-qnap/container-station
tmpfs 100.0K 0 100.0K 0% /share/CACHEDEV1_DATA/Container/container-station-data/lib/lxd/shmounts
tmpfs 100.0K 0 100.0K 0% /share/CACHEDEV1_DATA/Container/container-station-data/lib/lxd/devlxd
overlay 3.0T 1.4T 1.6T 48% /share/CACHEDEV1_DATA/Container/container-station-data/lib/docker/overlay2/a8b24fbc86efcced498db198044bcef8edc3d5d8d34854556d6def3435451092/merged
overlay 3.0T 1.4T 1.6T 48% /share/CACHEDEV1_DATA/Container/container-station-data/lib/docker/overlay2/e336c44a9bd40074eab29515da98f6fb5d4930e0d410994980d103678a46d19b/merg ed
overlay 3.0T 1.4T 1.6T 48% /share/CACHEDEV1_DATA/Container/container-station-data/lib/docker/overlay2/badd629737c8abc5e18272165d15eca9e307a885d8809224339bc93cc9b8bf13/merged
overlay 3.0T 1.4T 1.6T 48% /share/CACHEDEV1_DATA/Container/container-station-data/lib/docker/overlay2/d232b71046f5ecc218e812adc9309f6a95590b2b8ec788a54acec0d33b6a346c/merged
overlay 3.0T 1.4T 1.6T 48% /share/CACHEDEV1_DATA/Container/container-station-data/lib/docker/overlay2/de77097c9d1560270bb4e5ad617555f00443c28dd2b4553d38d2eac4db1ed4a5/merged
Overlay 3.0T 1.4T 1.6T 48%/Share/CacheDev1_data/Container/Container-SATA/LIB/DOCKER/OVERLAY2/9E943181C3130C5AD306786CC9F773 E7B698BF87A7549363502D0/Merged
overlay 3.0T 1.4T 1.6T 48% /share/CACHEDEV1_DATA/Container/container-station-data/lib/docker/overlay2/2d997d801b6cd2cf03b8760c8c01b111eec915ac5e57dc4b9d1c6c391e8f951f/merg ed
overlay 3.0T 1.4T 1.6T 48% /share/CACHEDEV1_DATA/Container/container-station-data/lib/docker/overlay2/2e73a7857f218c2867ebc7ec69f7764bd5787ea2f9bfdcbfe25cdd2f25d62cd3/merged
overlay 3.0T 1.4T 1.6T 48% /share/CACHEDEV1_DATA/Container/container-station-data/lib/docker/overlay2/41c1a6e22899d9d0f8c02f0e9f2683c93b2fd8b2c93d677e9f87552839a1686c/ merged
Overlay 3.0T 1.4T 1.6T 48%/Share/CacheDev1_data/Container/Container-SATA/LIB/DOCKER/OVERLAY2/B23ef7F05050550D2D2D956BBBBBBBBBBBBB D2377575738F3F27D86A0D2/MERGED
overlay 3.0T 1.4T 1.6T 48% /share/CACHEDEV1_DATA/Container/container-station-data/lib/docker/overlay2/6a105e8f5e740dceed8a96d16c3fcc95775974e6fbac382b5446b45bb611065b/merged
overlay 3.0T 1.4T 1.6T 48% /share/CACHEDEV1_DATA/Container/container-station-data/lib/docker/overlay2/4a25157fa48fcdfc89dcc46e6ff4acb685916a74f1ffbd541f99614dfc825645/merged
overlay 3.0T 1.4T 1.6T 48% /share/CACHEDEV1_DATA/Container/container-station-data/lib/docker/overlay2/6a10d2c42c3d2c3057f5c2e8816ddca2e384601666dfeecf19bd1c1d8d7e683b/merged
overlay 3.0T 1.4T 1.6T 48% /share/CACHEDEV1_DATA/Container/container-station-data/lib/docker/overlay2/d648e717655504c32365b5145df409c1754d0b20d438c7a156763972ded1bfe0/merg ed
overlay 3.0T 1.4T 1.6T 48% /share/CACHEDEV1_DATA/Container/container-station-data/lib/docker/overlay2/d78d05dca0b50f28e5dcc0846f8034839cc17beb94b16e79095ac4cc00afc6ed/merged
/dev/mapper/vg1-snap10002
                          3.0T 1.4T 1.6T 48% /mnt/snapshot/1/10002
/dev/mapper/vg1-snap10003
                          3.0T 1.4T 1.6T 48% /mnt/snapshot/1/10003
/dev/mapper/vg1-snap10005
                          3.0T 1.4T 1.6T 48% /mnt/snapshot/1/10005
/dev/mapper/vg1-snap10006
                          3.0T 1.4T 1.6T 48% /mnt/snapshot/1/10006
Overlay 3.0T 1.4t 1.6T 48%/Share/CacheDev1_data/Container/Container-SATA/LIB/DOCKER/Overlay2/67586B522723529842984249DDDDD5F 1A923759CA7ECF626555408/MERGED
/dev/mapper/vg1-snap10016
                          3.0T 1.4T 1.6T 48% /mnt/snapshot/1/10016
''';
    final disks = parseDisk(raw);
    print(disks.map((e) => '${e.mount} ${e.used}').join('\n'));
  });
}
