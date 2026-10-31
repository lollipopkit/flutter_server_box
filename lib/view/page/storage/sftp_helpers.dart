part of 'sftp.dart';

String _normalizeSftpPath(String path) => path.replaceAll(RegExp(r'/+'), '/');

/// The command that unpacks [filename] where it is, from
/// `sbm_parser::files`; null for a file it does not know how to unpack.
String? _getDecompressCmd(String filename) =>
    files.filesExtractCommand(path: filename);

bool _canDecompress(String filename) => _getDecompressCmd(filename) != null;
