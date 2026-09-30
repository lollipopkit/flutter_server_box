Map<String, String>? buildSshTerminalEnvironment(Map<String, String>? envs) {
  if (envs == null || envs.isEmpty) {
    return null;
  }
  return Map<String, String>.unmodifiable(envs);
}
