//! Where an interactive shell is, asked from beside it.
//!
//! The terminal learns its shell's directory from OSC 7 when the shell prints
//! one. Plenty do not — bash as most distributions ship it never does — and
//! typing `pwd` into someone's terminal to find out is not an option. This is
//! the other way: a command on an exec channel of the *same* SSH connection,
//! which finds the shells that connection is running and reads their `cwd`
//! from `/proc`.
//!
//! sshd runs every channel of one connection as a child of one process (`sshd`,
//! or `sshd-session` from OpenSSH 9.8). The command climbs from itself to that
//! process, then lists its other children that hold a terminal — the shells of
//! this connection's terminals. Several terminals on one connection give
//! several; [`pick`] tells them apart by the size of their terminal, and gives
//! up rather than guess when that does not.
//!
//! A terminal multiplexer is passed over: under tmux or screen the process
//! sshd started is the multiplexer's client, whose directory says nothing about
//! the shell in the pane. Such a terminal gets no answer here, and follows only
//! what its shell prints.
//!
//! Linux only: elsewhere there is no `/proc` to read, and the command prints
//! nothing.

/// POSIX `sh`. One line per shell: pid, `stty size` (rows and columns, empty
/// where `stty -F` is missing), cwd — tab-separated, the cwd last so a tab in it
/// survives.
pub const SCRIPT: &str = r#"p=$$
while [ "$p" -gt 1 ]; do
  c=$(cat "/proc/$p/comm" 2>/dev/null) || exit 0
  case $c in sshd|sshd-session) break ;; esac
  s=$(cat "/proc/$p/stat" 2>/dev/null) || exit 0
  s=${s##*) }
  set -- $s
  p=$2
done
[ "$p" -gt 1 ] || exit 0
for d in /proc/[0-9]*; do
  s=$(cat "$d/stat" 2>/dev/null) || continue
  s=${s##*) }
  set -- $s
  [ "$2" = "$p" ] && [ "$5" != 0 ] || continue
  case $(cat "$d/comm" 2>/dev/null) in tmux*|screen) continue ;; esac
  cwd=$(readlink "$d/cwd" 2>/dev/null) || continue
  tty=$(readlink "$d/fd/0" 2>/dev/null)
  size=$(stty -F "$tty" size 2>/dev/null)
  printf '%s\t%s\t%s\n' "${d#/proc/}" "$size" "$cwd"
done
"#;

/// One shell [`SCRIPT`] found.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ShellCwd {
    pub pid: u32,
    /// The terminal's size as the kernel has it, `None` where it could not be
    /// read.
    pub rows: Option<u16>,
    pub cols: Option<u16>,
    pub cwd: String,
}

/// [`SCRIPT`]'s output. A line that does not read as a shell is skipped.
pub fn parse(raw: &str) -> Vec<ShellCwd> {
    raw.lines()
        .filter_map(|line| {
            let mut fields = line.splitn(3, '\t');
            let pid = fields.next()?.trim().parse().ok()?;
            let size = fields.next()?;
            let cwd = fields.next()?;
            if !cwd.starts_with('/') {
                return None;
            }
            let mut size = size.split_whitespace().map(|n| n.parse::<u16>().ok());
            let (rows, cols) = (size.next().flatten(), size.next().flatten());
            Some(ShellCwd {
                pid,
                rows,
                cols,
                cwd: cwd.to_owned(),
            })
        })
        .collect()
}

/// The directory of the shell behind a terminal of `cols` × `rows`.
///
/// The only shell, or the only one whose terminal is that size. Two the same
/// size are two answers, and `None` is said rather than one of them: following
/// the wrong terminal is worse than following none.
pub fn pick(shells: &[ShellCwd], cols: u16, rows: u16) -> Option<&str> {
    if let [only] = shells {
        return Some(&only.cwd);
    }
    let mut sized = shells
        .iter()
        .filter(|shell| shell.cols == Some(cols) && shell.rows == Some(rows));
    match (sized.next(), sized.next()) {
        (Some(shell), None) => Some(&shell.cwd),
        _ => None,
    }
}

/// `path` as one word for the command line of a terminal: as it is when
/// nothing in it means anything to a shell, single-quoted otherwise — which
/// fish reads the same way as `sh`.
pub fn shell_word(path: &str) -> String {
    let plain = !path.is_empty()
        && path
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || "_./~+@%:,=-".contains(c));
    // `~` only past the start: leading, it is the home directory.
    if plain && !path.starts_with('~') {
        return path.to_owned();
    }
    crate::script::shell_quote_unix(path)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn shell(pid: u32, size: Option<(u16, u16)>, cwd: &str) -> ShellCwd {
        ShellCwd {
            pid,
            rows: size.map(|s| s.0),
            cols: size.map(|s| s.1),
            cwd: cwd.to_owned(),
        }
    }

    #[test]
    fn a_word_on_the_command_line() {
        assert_eq!(shell_word("/var/log/nginx"), "/var/log/nginx");
        assert_eq!(shell_word("/srv/a b"), "'/srv/a b'");
        assert_eq!(shell_word("/srv/it's"), r"'/srv/it'\''s'");
        assert_eq!(shell_word("/x/$HOME;rm"), "'/x/$HOME;rm'");
        assert_eq!(shell_word("~user"), "'~user'");
        assert_eq!(shell_word(""), "''");
    }

    #[test]
    fn reads_each_shell() {
        let raw = "4121\t24 80\t/var/log\n4180\t\t/home/a b\n4190\t50 132\t/srv/x\ty\n";
        assert_eq!(
            parse(raw),
            vec![
                shell(4121, Some((24, 80)), "/var/log"),
                shell(4180, None, "/home/a b"),
                shell(4190, Some((50, 132)), "/srv/x\ty"),
            ]
        );
    }

    #[test]
    fn skips_what_is_not_a_shell() {
        assert!(parse("").is_empty());
        assert!(parse("x\t24 80\t/tmp\n12\t24 80\n13\t24 80\trelative\n").is_empty());
    }

    #[test]
    fn the_only_shell_whatever_its_size() {
        let shells = [shell(1, None, "/a")];
        assert_eq!(pick(&shells, 80, 24), Some("/a"));
    }

    #[test]
    fn several_are_told_apart_by_size() {
        let shells = [
            shell(1, Some((24, 80)), "/a"),
            shell(2, Some((50, 132)), "/b"),
        ];
        assert_eq!(pick(&shells, 132, 50), Some("/b"));
        assert_eq!(pick(&shells, 100, 30), None);
    }

    #[test]
    fn two_of_one_size_are_no_answer() {
        let shells = [
            shell(1, Some((24, 80)), "/a"),
            shell(2, Some((24, 80)), "/b"),
        ];
        assert_eq!(pick(&shells, 80, 24), None);
        assert_eq!(pick(&[], 80, 24), None);
    }
}
