/// An agent address with surrounding space and trailing slashes removed, so
/// two spellings of one endpoint compare equal.
String normalizeAgentEndpoint(String value) =>
    value.trim().replaceFirst(RegExp(r'/+$'), '');
