import 'package:dartssh2/dartssh2.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/sftp/absolute_path.dart';

class SFTPSideViewStatus {
  bool leftSelected = false;
  bool rightSelected = false;
  ServerPrivateInfo? leftSpi;
  ServerPrivateInfo? rightSpi;
  List<SftpName>? leftFiles;
  List<SftpName>? rightFiles;
  AbsolutePath? leftPath;
  AbsolutePath? rightPath;
  SftpClient? leftClient;
  SftpClient? rightClient;

  SFTPSideViewStatus();

  ServerPrivateInfo? spi(bool left) => left ? leftSpi : rightSpi;
  void setSpi(bool left, ServerPrivateInfo nSpi) =>
      left ? leftSpi = nSpi : rightSpi = nSpi;

  /// Whether the Left/Right Destination is selected.
  bool selected(bool left) => left ? leftSelected : rightSelected;
  void setSelect(bool left, bool nSelect) =>
      left ? leftSelected = nSelect : rightSelected = nSelect;

  List<SftpName>? files(bool left) => left ? leftFiles : rightFiles;
  void setFiles(bool left, List<SftpName>? nFiles) =>
      left ? leftFiles = nFiles : rightFiles = nFiles;

  AbsolutePath? path(bool left) => left ? leftPath : rightPath;
  void setPath(bool left, AbsolutePath? nPath) =>
      left ? leftPath = nPath : rightPath = nPath;

  SftpClient? client(bool left) => left ? leftClient : rightClient;
  void setClient(bool left, SftpClient? nClient) =>
      left ? leftClient = nClient : rightClient = nClient;
}
