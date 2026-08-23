bool isSecureRemoteEndpoint(Uri uri, {bool allowInsecure = false}) {
  if (!uri.hasScheme || uri.host.isEmpty) return false;
  if (uri.scheme.toLowerCase() == 'https') return true;
  if (uri.scheme.toLowerCase() != 'http') return false;
  if (allowInsecure) return true;
  final host = uri.host.toLowerCase();
  return host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1';
}
