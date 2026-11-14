//! An OpenSSH master connection (`ControlMaster`), asked for a stream the way
//! `ssh -W host:port` asks one: `MUX_C_NEW_STDIO_FWD` (PROTOCOL.mux). The
//! master opens `direct-tcpip` to the target and joins it to a socket handed
//! over with SCM_RIGHTS, which `dart:io` cannot send — hence Rust. The bytes
//! then flow over that socket without passing through here.

use flutter_rust_bridge::frb;

#[cfg(unix)]
use std::{
    io::{Read, Write},
    os::unix::{io::AsRawFd, net::UnixStream},
    sync::Mutex,
    time::Duration,
};

/// Why a master did not open the stream.
pub struct MuxError {
    /// No master to use: none answered at the control socket (none running,
    /// or one gone), or it declined (`ControlMaster ask`). The caller connects
    /// without it.
    pub unreachable: bool,
    pub message: String,
}

/// A stream a master opened, held open by its control connection: the master
/// ends the stream when this ends.
#[frb(opaque)]
pub struct MuxForward {
    #[cfg(unix)]
    control: Mutex<Option<UnixStream>>,
}

#[cfg(unix)]
mod wire {
    pub const HELLO: u32 = 0x0000_0001;
    pub const NEW_STDIO_FWD: u32 = 0x1000_0008;
    pub const PERMISSION_DENIED: u32 = 0x8000_0002;
    pub const FAILURE: u32 = 0x8000_0003;
    pub const SESSION_OPENED: u32 = 0x8000_0006;
    pub const VERSION: u32 = 4;
    /// A control message is a few strings; anything near this is not one.
    pub const MAX_PACKET: u32 = 256 * 1024;
}

impl MuxForward {
    /// Asks the master at [control_path] for a stream to [host]:[port], joined
    /// to a connection this makes to [stdio_path], where the caller listens.
    /// [token] is the first thing written there, before the master has it, so
    /// the caller knows which connection is this one.
    pub fn open(
        control_path: String,
        stdio_path: String,
        token: Vec<u8>,
        host: String,
        port: u16,
        timeout_ms: u32,
    ) -> Result<MuxForward, MuxError> {
        #[cfg(unix)]
        {
            let unreachable = |e: std::io::Error| MuxError {
                unreachable: true,
                message: e.to_string(),
            };
            let control = UnixStream::connect(&control_path).map_err(unreachable)?;
            let timeout = Some(Duration::from_millis(timeout_ms.max(1).into()));
            control.set_read_timeout(timeout).map_err(unreachable)?;
            control.set_write_timeout(timeout).map_err(unreachable)?;
            let mut control = control;
            // A socket file left by a master that has gone answers nothing
            // useful either: the hello is where that shows.
            hello(&mut control).map_err(|e| MuxError {
                unreachable: true,
                message: e,
            })?;

            let refused = |message: String| MuxError {
                unreachable: false,
                message,
            };
            let mut stdio = UnixStream::connect(&stdio_path)
                .map_err(|e| refused(format!("stdio socket: {e}")))?;
            stdio
                .write_all(&token)
                .map_err(|e| refused(format!("stdio socket: {e}")))?;
            stdio_forward(&mut control, &stdio, &host, port)?;
            // The master holds its own copies now; this one is not needed.
            drop(stdio);
            // Waited on for as long as the stream lasts. Refused on a socket
            // whose master has already gone (macOS answers EINVAL), and then
            // the stream ends on its own.
            let _ = control.set_read_timeout(None);
            Ok(MuxForward {
                control: Mutex::new(Some(control)),
            })
        }
        #[cfg(not(unix))]
        {
            let _ = (control_path, stdio_path, token, host, port, timeout_ms);
            Err(MuxError {
                unreachable: true,
                message: "no OpenSSH multiplexing on this platform".into(),
            })
        }
    }

    /// Ends the control connection, and with it the stream.
    pub fn close(&self) {
        #[cfg(unix)]
        if let Some(control) = self.control.lock().ok().and_then(|mut c| c.take()) {
            let _ = control.shutdown(std::net::Shutdown::Both);
        }
    }
}

#[cfg(unix)]
fn hello(control: &mut UnixStream) -> Result<(), String> {
    let mut body = Vec::new();
    put_u32(&mut body, wire::HELLO);
    put_u32(&mut body, wire::VERSION);
    write_packet(control, &body)?;
    let reply = read_packet(control)?;
    let mut r = Reader(&reply);
    let kind = r.u32()?;
    let version = r.u32()?;
    if kind != wire::HELLO {
        return Err(format!("expected a hello, got {kind:#x}"));
    }
    if version != wire::VERSION {
        return Err(format!("mux protocol {version}, not {}", wire::VERSION));
    }
    Ok(())
}

#[cfg(unix)]
fn stdio_forward(
    control: &mut UnixStream,
    stdio: &UnixStream,
    host: &str,
    port: u16,
) -> Result<(), MuxError> {
    let refused = |message: String| MuxError {
        unreachable: false,
        message,
    };
    const REQUEST: u32 = 1;
    let mut body = Vec::new();
    put_u32(&mut body, wire::NEW_STDIO_FWD);
    put_u32(&mut body, REQUEST);
    put_string(&mut body, b"");
    put_string(&mut body, host.as_bytes());
    put_u32(&mut body, port.into());
    write_packet(control, &body).map_err(refused)?;
    // The master's stdin, then its stdout: one socket for both, as a pipe
    // pair would be two.
    send_fd(control, stdio.as_raw_fd()).map_err(refused)?;
    send_fd(control, stdio.as_raw_fd()).map_err(refused)?;

    let reply = read_packet(control).map_err(refused)?;
    let mut r = Reader(&reply);
    let kind = r.u32().map_err(refused)?;
    let id = r.u32().map_err(refused)?;
    if id != REQUEST {
        return Err(refused(format!("a reply to request {id}")));
    }
    let reason = |r: &mut Reader| {
        r.string()
            .map(|s| String::from_utf8_lossy(s).into_owned())
            .unwrap_or_default()
    };
    match kind {
        wire::SESSION_OPENED => Ok(()),
        // The user said no to this master (`ControlMaster ask`), which is no
        // reason to fail a connection that can be made without it.
        wire::PERMISSION_DENIED => Err(MuxError {
            unreachable: true,
            message: reason(&mut r),
        }),
        wire::FAILURE => Err(refused(reason(&mut r))),
        other => Err(refused(format!("unexpected reply {other:#x}"))),
    }
}

#[cfg(unix)]
fn write_packet(control: &mut UnixStream, body: &[u8]) -> Result<(), String> {
    let mut packet = Vec::with_capacity(4 + body.len());
    put_u32(&mut packet, body.len() as u32);
    packet.extend_from_slice(body);
    control.write_all(&packet).map_err(|e| e.to_string())
}

#[cfg(unix)]
fn read_packet(control: &mut UnixStream) -> Result<Vec<u8>, String> {
    let mut len = [0u8; 4];
    control.read_exact(&mut len).map_err(|e| e.to_string())?;
    let len = u32::from_be_bytes(len);
    if len > wire::MAX_PACKET {
        return Err(format!("packet of {len} bytes"));
    }
    let mut body = vec![0u8; len as usize];
    control.read_exact(&mut body).map_err(|e| e.to_string())?;
    Ok(body)
}

/// One byte carrying [fd] as SCM_RIGHTS, as OpenSSH's `mm_send_fd` sends it.
#[cfg(unix)]
fn send_fd(control: &UnixStream, fd: libc::c_int) -> Result<(), String> {
    use std::mem::{size_of, zeroed};
    let mut byte = 0u8;
    let mut iov = libc::iovec {
        iov_base: (&mut byte as *mut u8).cast(),
        iov_len: 1,
    };
    // Sized and aligned for one descriptor's control message.
    let space = unsafe { libc::CMSG_SPACE(size_of::<libc::c_int>() as u32) } as usize;
    let mut cmsg_buf = vec![0u64; space.div_ceil(size_of::<u64>())];
    let sent = unsafe {
        let mut msg: libc::msghdr = zeroed();
        msg.msg_iov = &mut iov;
        msg.msg_iovlen = 1;
        msg.msg_control = cmsg_buf.as_mut_ptr().cast();
        msg.msg_controllen = space as _;
        let cmsg = libc::CMSG_FIRSTHDR(&msg);
        (*cmsg).cmsg_level = libc::SOL_SOCKET;
        (*cmsg).cmsg_type = libc::SCM_RIGHTS;
        (*cmsg).cmsg_len = libc::CMSG_LEN(size_of::<libc::c_int>() as u32) as _;
        libc::CMSG_DATA(cmsg).cast::<libc::c_int>().write_unaligned(fd);
        libc::sendmsg(control.as_raw_fd(), &msg, 0)
    };
    if sent == 1 {
        Ok(())
    } else {
        Err(format!("sending a descriptor: {}", std::io::Error::last_os_error()))
    }
}

#[cfg(unix)]
fn put_u32(out: &mut Vec<u8>, value: u32) {
    out.extend_from_slice(&value.to_be_bytes());
}

#[cfg(unix)]
fn put_string(out: &mut Vec<u8>, value: &[u8]) {
    put_u32(out, value.len() as u32);
    out.extend_from_slice(value);
}

#[cfg(unix)]
struct Reader<'a>(&'a [u8]);

#[cfg(unix)]
impl<'a> Reader<'a> {
    fn take(&mut self, n: usize) -> Result<&'a [u8], String> {
        if self.0.len() < n {
            return Err("short packet".into());
        }
        let (head, rest) = self.0.split_at(n);
        self.0 = rest;
        Ok(head)
    }

    fn u32(&mut self) -> Result<u32, String> {
        let b = self.take(4)?;
        Ok(u32::from_be_bytes([b[0], b[1], b[2], b[3]]))
    }

    fn string(&mut self) -> Result<&'a [u8], String> {
        let len = self.u32()? as usize;
        self.take(len)
    }
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;
    use std::{
        os::unix::{
            io::{FromRawFd, RawFd},
            net::UnixListener,
        },
        path::PathBuf,
        thread,
    };

    /// A directory of its own under /tmp: socket paths have a short limit.
    fn scratch(tag: &str) -> PathBuf {
        let dir = PathBuf::from(format!("/tmp/sbmux-{tag}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir(&dir).unwrap();
        dir
    }

    fn recv_fd(control: &UnixStream) -> RawFd {
        use std::mem::{size_of, zeroed};
        let mut byte = 0u8;
        let mut iov = libc::iovec {
            iov_base: (&mut byte as *mut u8).cast(),
            iov_len: 1,
        };
        let space = unsafe { libc::CMSG_SPACE(size_of::<libc::c_int>() as u32) } as usize;
        let mut buf = vec![0u64; space.div_ceil(8)];
        unsafe {
            let mut msg: libc::msghdr = zeroed();
            msg.msg_iov = &mut iov;
            msg.msg_iovlen = 1;
            msg.msg_control = buf.as_mut_ptr().cast();
            msg.msg_controllen = space as _;
            assert_eq!(libc::recvmsg(control.as_raw_fd(), &mut msg, 0), 1);
            let cmsg = libc::CMSG_FIRSTHDR(&msg);
            assert_eq!((*cmsg).cmsg_type, libc::SCM_RIGHTS);
            libc::CMSG_DATA(cmsg).cast::<libc::c_int>().read_unaligned()
        }
    }

    /// A master that answers [reply] to a stdio forward, after echoing one
    /// line through the descriptors it was handed.
    fn fake_master(control: PathBuf, reply: u32) -> thread::JoinHandle<(String, u32)> {
        let listener = UnixListener::bind(&control).unwrap();
        thread::spawn(move || {
            let (mut c, _) = listener.accept().unwrap();
            let theirs = read_packet(&mut c).unwrap();
            assert_eq!(Reader(&theirs).u32().unwrap(), wire::HELLO);
            let mut hello = Vec::new();
            put_u32(&mut hello, wire::HELLO);
            put_u32(&mut hello, wire::VERSION);
            write_packet(&mut c, &hello).unwrap();

            let request = read_packet(&mut c).unwrap();
            let mut r = Reader(&request);
            assert_eq!(r.u32().unwrap(), wire::NEW_STDIO_FWD);
            let id = r.u32().unwrap();
            assert!(r.string().unwrap().is_empty());
            let host = String::from_utf8(r.string().unwrap().to_vec()).unwrap();
            let port = r.u32().unwrap();

            let stdin = recv_fd(&c);
            let stdout = recv_fd(&c);
            let mut out = unsafe { UnixStream::from_raw_fd(stdout) };
            out.write_all(b"from-master\n").unwrap();
            unsafe { libc::close(stdin) };

            let mut answer = Vec::new();
            put_u32(&mut answer, reply);
            put_u32(&mut answer, id);
            if reply == wire::SESSION_OPENED {
                put_u32(&mut answer, 7);
            } else {
                put_string(&mut answer, b"connect failed");
            }
            write_packet(&mut c, &answer).unwrap();
            (host, port)
        })
    }

    #[test]
    fn a_stream_reaches_the_target_through_the_master() {
        let dir = scratch("ok");
        let control = dir.join("cm");
        let stdio = dir.join("s");
        let master = fake_master(control.clone(), wire::SESSION_OPENED);
        let listener = UnixListener::bind(&stdio).unwrap();

        let forward = MuxForward::open(
            control.to_string_lossy().into(),
            stdio.to_string_lossy().into(),
            b"token".to_vec(),
            "target.example".into(),
            2200,
            2000,
        )
        .unwrap_or_else(|e| panic!("{}", e.message));
        let (mut ours, _) = listener.accept().unwrap();
        let mut first = [0u8; 5 + 12];
        ours.read_exact(&mut first).unwrap();

        // The token, then what the master wrote.
        assert_eq!(&first, b"tokenfrom-master\n");
        assert_eq!(master.join().unwrap(), ("target.example".into(), 2200));
        forward.close();
        let _ = std::fs::remove_dir_all(dir);
    }

    #[test]
    fn a_master_declined_is_one_not_to_use() {
        let dir = scratch("denied");
        let control = dir.join("cm");
        let stdio = dir.join("s");
        let master = fake_master(control.clone(), wire::PERMISSION_DENIED);
        let _listener = UnixListener::bind(&stdio).unwrap();

        let error = MuxForward::open(
            control.to_string_lossy().into(),
            stdio.to_string_lossy().into(),
            Vec::new(),
            "target".into(),
            22,
            2000,
        )
        .err()
        .unwrap();

        assert!(error.unreachable);
        master.join().unwrap();
        let _ = std::fs::remove_dir_all(dir);
    }

    #[test]
    fn a_refusal_is_the_masters_reason() {
        let dir = scratch("refused");
        let control = dir.join("cm");
        let stdio = dir.join("s");
        let master = fake_master(control.clone(), wire::FAILURE);
        let _listener = UnixListener::bind(&stdio).unwrap();

        let error = MuxForward::open(
            control.to_string_lossy().into(),
            stdio.to_string_lossy().into(),
            Vec::new(),
            "target".into(),
            22,
            2000,
        )
        .err()
        .unwrap();

        assert!(!error.unreachable);
        assert_eq!(error.message, "connect failed");
        master.join().unwrap();
        let _ = std::fs::remove_dir_all(dir);
    }

    #[test]
    fn no_master_is_unreachable() {
        let dir = scratch("none");
        let error = MuxForward::open(
            dir.join("cm").to_string_lossy().into(),
            dir.join("s").to_string_lossy().into(),
            Vec::new(),
            "target".into(),
            22,
            200,
        )
        .err()
        .unwrap();

        assert!(error.unreachable);
        let _ = std::fs::remove_dir_all(dir);
    }

    #[test]
    fn a_socket_nobody_answers_on_is_unreachable() {
        let dir = scratch("silent");
        let control = dir.join("cm");
        // Accepts, never says hello: a master hung, or not a master.
        let listener = UnixListener::bind(&control).unwrap();
        let held = thread::spawn(move || listener.accept().map(|(c, _)| c));

        let error = MuxForward::open(
            control.to_string_lossy().into(),
            dir.join("s").to_string_lossy().into(),
            Vec::new(),
            "target".into(),
            22,
            200,
        )
        .err()
        .unwrap();

        assert!(error.unreachable);
        drop(held.join());
        let _ = std::fs::remove_dir_all(dir);
    }
}
