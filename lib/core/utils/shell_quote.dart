String shellSingleQuote(String value) {
  return "'${value.replaceAll("'", "'\\''")}'";
}
