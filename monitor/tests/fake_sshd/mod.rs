//! A minimal in-process SSH server, so the terminal endpoint's SSH half can be
//! tested without an sshd on the machine running the tests.
//!
//! It implements just enough to be indistinguishable from a real server for
//! this purpose: password and keyboard-interactive authentication, a session
//! channel, a PTY request, and a "shell" that echoes what it is sent. That
//! covers the whole path the agent drives — connect, host key check,
//! authenticate, open a PTY, move bytes — which is what the tests are about.

use std::sync::Arc;

use russh::keys::PrivateKey;
use russh::keys::ssh_encoding::bytes::Bytes;
use russh::server::{self, Auth, ChannelOpenHandle, Handler, Msg, Server as _, Session};
use russh::{Channel, ChannelId, MethodKind, MethodSet, Pty};
use tokio::net::TcpListener;

/// System entropy, in the shape `ssh-key` wants for generating a host key.
///
/// Backed by `getrandom`, which this crate already depends on, rather than
/// adding `rand` for the sake of test fixtures. Failure aborts: a machine
/// whose RNG is unavailable can't run these tests meaningfully anyway.
struct RandomSource;

impl russh::keys::ssh_key::rand_core::TryRng for RandomSource {
    type Error = std::convert::Infallible;

    fn try_next_u32(&mut self) -> Result<u32, Self::Error> {
        let mut buf = [0u8; 4];
        self.try_fill_bytes(&mut buf)?;
        Ok(u32::from_le_bytes(buf))
    }

    fn try_next_u64(&mut self) -> Result<u64, Self::Error> {
        let mut buf = [0u8; 8];
        self.try_fill_bytes(&mut buf)?;
        Ok(u64::from_le_bytes(buf))
    }

    fn try_fill_bytes(&mut self, dst: &mut [u8]) -> Result<(), Self::Error> {
        getrandom::fill(dst).expect("system RNG must be available in tests");
        Ok(())
    }
}

// `CryptoRng` follows from this by blanket impl, given the `Infallible` error
impl russh::keys::ssh_key::rand_core::TryCryptoRng for RandomSource {}

/// The password the fake server accepts. Anything else is rejected, so the
/// failure path is testable too.
pub const PASSWORD: &str = "correct-horse";
pub const USER: &str = "ops";

/// Marker the fake shell prints once, right after the PTY opens, so a test can
/// tell "the shell started" from "some bytes arrived".
pub const BANNER: &[u8] = b"fake-shell ready\r\n";

#[derive(Clone)]
pub struct FakeSshd {
    /// Whether to demand a keyboard-interactive round before succeeding, which
    /// is the path a server with two-factor enabled would take.
    interactive: bool,
}

pub struct FakeHandler {
    interactive: bool,
    /// Set once the client has answered a keyboard-interactive prompt.
    answered: bool,
}

impl server::Server for FakeSshd {
    type Handler = FakeHandler;

    fn new_client(&mut self, _peer: Option<std::net::SocketAddr>) -> FakeHandler {
        FakeHandler {
            interactive: self.interactive,
            answered: false,
        }
    }
}

impl Handler for FakeHandler {
    type Error = russh::Error;

    async fn auth_password(&mut self, user: &str, password: &str) -> Result<Auth, Self::Error> {
        if self.interactive {
            // Force the client onto the interactive path, as a server with an
            // extra factor configured would
            return Ok(Auth::Reject {
                proceed_with_methods: Some(MethodSet::from(
                    &[MethodKind::KeyboardInteractive][..],
                )),
                partial_success: false,
            });
        }
        if user == USER && password == PASSWORD {
            Ok(Auth::Accept)
        } else {
            Ok(Auth::reject())
        }
    }

    async fn auth_keyboard_interactive(
        &mut self,
        user: &str,
        _submethods: &str,
        response: Option<server::Response<'_>>,
    ) -> Result<Auth, Self::Error> {
        if !self.answered {
            self.answered = true;
            return Ok(Auth::Partial {
                name: "Verification".into(),
                instructions: "Enter the code".into(),
                prompts: vec![("Code: ".into(), false)].into(),
            });
        }

        let accepted = response
            .and_then(|mut r| r.next())
            .is_some_and(|answer| answer == PASSWORD.as_bytes());
        if user == USER && accepted {
            Ok(Auth::Accept)
        } else {
            Ok(Auth::reject())
        }
    }

    async fn channel_open_session(
        &mut self,
        _channel: Channel<Msg>,
        reply: ChannelOpenHandle,
        _session: &mut Session,
    ) -> Result<(), Self::Error> {
        reply.accept().await;
        Ok(())
    }

    #[allow(clippy::too_many_arguments)]
    async fn pty_request(
        &mut self,
        channel: ChannelId,
        _term: &str,
        _col_width: u32,
        _row_height: u32,
        _pix_width: u32,
        _pix_height: u32,
        _modes: &[(Pty, u32)],
        session: &mut Session,
    ) -> Result<(), Self::Error> {
        session.channel_success(channel)?;
        Ok(())
    }

    async fn shell_request(
        &mut self,
        channel: ChannelId,
        session: &mut Session,
    ) -> Result<(), Self::Error> {
        session.channel_success(channel)?;
        session.data(channel, Bytes::from(BANNER.to_vec()))?;
        Ok(())
    }

    async fn window_change_request(
        &mut self,
        channel: ChannelId,
        _col_width: u32,
        _row_height: u32,
        _pix_width: u32,
        _pix_height: u32,
        session: &mut Session,
    ) -> Result<(), Self::Error> {
        session.channel_success(channel)?;
        Ok(())
    }

    async fn data(
        &mut self,
        channel: ChannelId,
        data: &[u8],
        session: &mut Session,
    ) -> Result<(), Self::Error> {
        // Echo, like a shell with terminal echo on
        session.data(channel, Bytes::from(data.to_vec()))?;
        Ok(())
    }
}

/// Starts a fake sshd on an ephemeral port and returns its address.
///
/// Each call generates a fresh host key, so tests that share a database still
/// pin different keys per address rather than colliding.
pub async fn start(interactive: bool) -> String {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap().to_string();

    let key = PrivateKey::random(
        &mut RandomSource,
        russh::keys::Algorithm::Ed25519,
    )
    .unwrap();
    let config = Arc::new(server::Config {
        keys: vec![key],
        ..Default::default()
    });

    let mut server = FakeSshd { interactive };
    ntex::rt::spawn(async move {
        let running = server.run_on_socket(config, &listener);
        let _ = running.await;
    });
    addr
}
