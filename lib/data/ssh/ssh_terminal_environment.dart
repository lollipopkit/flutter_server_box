Map<String, String>? buildSshTerminalEnvironment(Map<String, String>? envs) {
  if (envs == null || envs.isEmpty) {
    return null;
  }
  return Map<String, String>.unmodifiable(envs);
}

String? resolveTmuxLang(Map<String, String>? envs) {
  final lcAll = envs?['LC_ALL']?.trim();
  if (lcAll != null && lcAll.isNotEmpty) {
    return lcAll;
  }

  final lcCtype = envs?['LC_CTYPE']?.trim();
  if (lcCtype != null && lcCtype.isNotEmpty) {
    return lcCtype;
  }

  final lang = envs?['LANG']?.trim();
  if (lang != null && lang.isNotEmpty) {
    return lang;
  }

  return null;
}
