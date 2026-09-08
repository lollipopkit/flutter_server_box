/**
 * Putting a value into a command safely.
 *
 * Every plugin that builds a command out of anything it did not write itself
 * needs this, and the value almost always came *from the server* — a path out
 * of a listing, a unit name out of `systemctl`, a container id. A directory
 * called `; rm -rf ~` is a legal directory name, and a plugin that concatenates
 * it into a shell command has handed the machine to whoever created it.
 *
 * Here rather than left to each plugin because there is exactly one correct
 * answer and it is easy to write a wrong one that works on every input a test
 * author thinks of.
 */

/**
 * Wraps [value] so a POSIX shell reads it as one literal word.
 *
 * Single quotes, because they are the only quoting a shell does nothing
 * inside: no `$`, no backtick, no backslash, no history expansion. The one
 * character that cannot appear in them is the single quote itself, and the
 * usual dance closes the string, escapes one, and opens it again.
 *
 * ```ts
 * `du -sk ${shellQuote("/var/lib/it's")}`
 * // du -sk '/var/lib/it'\''s'
 * ```
 *
 * **Not for `$HOME`.** The point of this is that nothing expands, so a value
 * containing `$HOME` stays those five characters. A plugin that wants the
 * remote home directory has to leave that part unquoted itself — the app's own
 * script generator has the same split, for the same reason.
 */
export function shellQuote(value: string): string {
  return `'${value.replaceAll("'", `'\\''`)}'`;
}

/**
 * Whether [path] is one this plugin should put in a command at all.
 *
 * A weaker check than quoting and not a substitute for it: quoting makes a
 * value safe, and this rejects the ones that are safe but wrong. A path with a
 * newline in it cannot be read back out of a line-oriented command's output,
 * so a plugin that sends one gets an answer it will mis-parse rather than an
 * answer it cannot trust.
 */
export function isUsablePath(path: string): boolean {
  return path.length > 0 && !path.includes("\n") && !path.includes("\0");
}
