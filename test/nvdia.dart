import 'package:flutter_test/flutter_test.dart';

const _raw = '''
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 455.23       Driver Version: 455.23       CUDA Version: 11.1     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|                               |                      |               MIG M. |
|===============================+======================+======================|
|   0  GeForce RTX 3090    Off  | 00000000:01:00.0 Off |                  N/A |
| 30%   40C    P8    30W / 350W |    240MiB / 24268MiB |      5%      Default |
+-------------------------------+----------------------+----------------------+
|   1  GeForce RTX 2080    Off  | 00000000:02:00.0  On |                  N/A |
| 30%   51C    P2    70W / 225W |   1080MiB /  8192MiB |     27%      Default |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|    0   N/A  N/A      1456      G   /usr/lib/xorg/Xorg                40MiB |
|    0   N/A  N/A      1589      G   /usr/bin/gnome-shell              70MiB |
|    1   N/A  N/A      1456      G   /usr/lib/xorg/Xorg               400MiB |
|    1   N/A  N/A      1589      G   /usr/bin/gnome-shell             300MiB |
|    1   N/A  N/A      2112      G   ...AAAAAAAAA= --shared-files     200MiB |
+-----------------------------------------------------------------------------+
''';

/// [
///   {
///     "name": "GeForce RTX 3090",
///     "temp": 40,
///     "power": "30W / 350W",
///     "memory": {
///       "total": 24268,
///       "used": 240,
///       "unit": "MiB",
///       "processes": [
///         {
///           "pid": 1456,
///           "name": "/usr/lib/xorg/Xorg",
///           "memory": 40
///         },
///       ]
///     },
///   }
/// ]

void main() {
  test('nvdia-smi', () {
    
  });
}