//! An SSH client, used by the browser terminal to reach the local sshd.
//!
//! The agent runs as whatever the service was started as — often root — so a
//! terminal that simply spawned a shell would hand out that privilege to
//! anyone holding the panel password. Going through sshd instead means a
//! session has exactly the rights of the SSH account the browser authenticated
//! as, and inherits sshd's own defences: its logs, its `AllowUsers`, its PAM
//! stack, its two-factor prompts.
//!
//! Credentials pass through this module and are wiped as soon as they have
//! been used. Nothing here writes them anywhere.

use std::sync::Arc;

use russh::client::{self, AuthResult, Handle, KeyboardInteractiveAuthResponse};
use russh::keys::ssh_key::PublicKey;
use russh::keys::{PrivateKeyWithHashAlg, decode_secret_key};
use russh::{Channel, ChannelMsg, ChannelReadHalf, Disconnect};
use sqlx::SqlitePool;
use zeroize::Zeroize;

use crate::ssh::known_hosts::{self, Verdict};

/// Why a connection or authentication attempt did not produce a session.
///
/// Mapped to a stable `code` on the wire so the panel can react — re-prompt
/// for credentials, or refuse to continue on a host key change — without
/// pattern-matching on English text.
#[derive(Debug)]
pub enum SshError {
    Connect(String),
    HostKeyMismatch { expected: String, actual: String },
    AuthFailed,
    /// The key material the browser sent could not be parsed or decrypted.
    BadKey(String),
    Protocol(String),
}

impl SshError {
    pub fn code(&self) -> &'static str {
        match self {
            SshError::Connect(_) => "connect_failed",
            SshError::HostKeyMismatch { .. } => "host_key_mismatch",
            SshError::AuthFailed => "auth_failed",
            SshError::BadKey(_) => "bad_key",
            SshError::Protocol(_) => "protocol_error",
        }
    }

    /// Text for the user. Deliberately vague for [`SshError::AuthFailed`]:
    /// naming which of user/password/key was wrong helps a guesser more than
    /// it helps the person who mistyped.
    pub fn message(&self) -> String {
        match self {
            SshError::Connect(e) => format!("Could not reach the SSH server: {e}"),
            SshError::HostKeyMismatch { expected, actual } => format!(
                "The SSH host key changed (expected {expected}, got {actual}). \
                 Refusing to connect; remove the pinned key only if this change was expected."
            ),
            SshError::AuthFailed => "Authentication failed".to_string(),
            SshError::BadKey(e) => format!("Could not read the private key: {e}"),
            SshError::Protocol(e) => format!("SSH error: {e}"),
        }
    }
}

impl From<russh::Error> for SshError {
    fn from(e: russh::Error) -> Self {
        SshError::Protocol(e.to_string())
    }
}

/// How the browser wants to authenticate.
///
/// Every variant is zeroized after use — see [`Credential::zeroize`].
pub enum Credential {
    Password(String),
    Key { pem: String, passphrase: Option<String> },
    /// Start a keyboard-interactive exchange; answers arrive later.
    KeyboardInteractive,
}

impl Credential {
    fn zeroize(&mut self) {
        match self {
            Credential::Password(p) => p.zeroize(),
            Credential::Key { pem, passphrase } => {
                pem.zeroize();
                if let Some(p) = passphrase {
                    p.zeroize();
                }
            }
            Credential::KeyboardInteractive => {}
        }
    }
}

impl Drop for Credential {
    fn drop(&mut self) {
        self.zeroize();
    }
}

/// One prompt in a keyboard-interactive round, forwarded to the browser.
#[derive(Debug, Clone, serde::Serialize)]
pub struct InteractivePrompt {
    pub prompt: String,
    /// Whether the answer may be shown while typing. False for passwords and
    /// for most one-time codes.
    pub echo: bool,
}

/// Where an authentication attempt got to.
pub enum AuthStep {
    Authenticated,
    /// The server wants answers before deciding.
    NeedsAnswers {
        instructions: String,
        prompts: Vec<InteractivePrompt>,
    },
    Failed,
}

/// Verifies the host key against the pinned record.
///
/// The verdict is computed inside russh's `check_server_key` callback, which
/// can only answer yes or no, so the reason for a "no" is stashed here for the
/// caller to turn into a useful message.
struct HostKeyChecker {
    pool: SqlitePool,
    addr: String,
    rejection: Arc<std::sync::Mutex<Option<SshError>>>,
}

impl client::Handler for HostKeyChecker {
    type Error = russh::Error;

    async fn check_server_key(
        &mut self,
        server_public_key: &PublicKey,
    ) -> Result<bool, Self::Error> {
        match known_hosts::verify(&self.pool, &self.addr, server_public_key).await {
            Ok(Verdict::Known | Verdict::Pinned) => Ok(true),
            Ok(Verdict::Mismatch { expected, actual }) => {
                tracing::warn!(
                    "Refusing SSH connection to {}: host key changed from {expected} to {actual}",
                    self.addr
                );
                *self.rejection.lock().unwrap_or_else(|e| e.into_inner()) =
                    Some(SshError::HostKeyMismatch { expected, actual });
                Ok(false)
            }
            Err(e) => {
                tracing::error!("Host key check for {} failed: {e}", self.addr);
                *self.rejection.lock().unwrap_or_else(|e| e.into_inner()) =
                    Some(SshError::Connect(format!("host key check failed: {e}")));
                Ok(false)
            }
        }
    }
}

/// A connected, not-yet-authenticated SSH session.
pub struct SshSession {
    handle: Handle<HostKeyChecker>,
}

impl SshSession {
    pub async fn connect(pool: SqlitePool, addr: &str) -> Result<Self, SshError> {
        let rejection = Arc::new(std::sync::Mutex::new(None));
        let handler = HostKeyChecker {
            pool,
            addr: addr.to_string(),
            rejection: rejection.clone(),
        };

        let config = Arc::new(client::Config {
            // The session is interactive; a keystroke should not wait on Nagle
            nodelay: true,
            ..Default::default()
        });

        match client::connect(config, addr, handler).await {
            Ok(handle) => Ok(Self { handle }),
            Err(e) => {
                // A host key rejection surfaces as a generic connection error;
                // the checker recorded what actually happened.
                if let Some(reason) = rejection.lock().unwrap_or_else(|e| e.into_inner()).take() {
                    return Err(reason);
                }
                Err(SshError::Connect(e.to_string()))
            }
        }
    }

    pub async fn authenticate(
        &mut self,
        user: &str,
        mut credential: Credential,
    ) -> Result<AuthStep, SshError> {
        let step = self.try_authenticate(user, &credential).await;
        credential.zeroize();
        step
    }

    async fn try_authenticate(
        &mut self,
        user: &str,
        credential: &Credential,
    ) -> Result<AuthStep, SshError> {
        match credential {
            Credential::Password(password) => {
                let result = self.handle.authenticate_password(user, password.clone()).await?;
                Ok(auth_step(result))
            }
            Credential::Key { pem, passphrase } => {
                let key = decode_secret_key(pem, passphrase.as_deref())
                    .map_err(|e| SshError::BadKey(e.to_string()))?;
                // Lets the server pick rsa-sha2-* over the legacy ssh-rsa,
                // which modern sshd refuses by default
                let hash_alg = self.handle.best_supported_rsa_hash().await?.flatten();
                let result = self
                    .handle
                    .authenticate_publickey(
                        user,
                        PrivateKeyWithHashAlg::new(Arc::new(key), hash_alg),
                    )
                    .await?;
                Ok(auth_step(result))
            }
            Credential::KeyboardInteractive => {
                let response = self
                    .handle
                    .authenticate_keyboard_interactive_start(user, None)
                    .await?;
                Ok(interactive_step(response))
            }
        }
    }

    /// Answers the prompts from the previous [`AuthStep::NeedsAnswers`].
    pub async fn answer_prompts(
        &mut self,
        mut answers: Vec<String>,
    ) -> Result<AuthStep, SshError> {
        let response = self
            .handle
            .authenticate_keyboard_interactive_respond(answers.clone())
            .await;
        for answer in &mut answers {
            answer.zeroize();
        }
        Ok(interactive_step(response?))
    }

    /// Opens a shell on a PTY of the given size.
    pub async fn open_shell(
        &mut self,
        term: &str,
        cols: u16,
        rows: u16,
    ) -> Result<Channel<client::Msg>, SshError> {
        let channel = self.handle.channel_open_session().await?;
        channel
            .request_pty(true, term, cols as u32, rows as u32, 0, 0, &[])
            .await?;
        channel.request_shell(true).await?;
        Ok(channel)
    }

    pub async fn disconnect(&self) {
        let _ = self
            .handle
            .disconnect(Disconnect::ByApplication, "", "en")
            .await;
    }
}

fn auth_step(result: AuthResult) -> AuthStep {
    if result.success() {
        AuthStep::Authenticated
    } else {
        AuthStep::Failed
    }
}

fn interactive_step(response: KeyboardInteractiveAuthResponse) -> AuthStep {
    match response {
        KeyboardInteractiveAuthResponse::Success => AuthStep::Authenticated,
        KeyboardInteractiveAuthResponse::Failure { .. } => AuthStep::Failed,
        KeyboardInteractiveAuthResponse::InfoRequest {
            instructions,
            prompts,
            ..
        } => AuthStep::NeedsAnswers {
            instructions,
            prompts: prompts
                .into_iter()
                .map(|p| InteractivePrompt {
                    prompt: p.prompt,
                    echo: p.echo,
                })
                .collect(),
        },
    }
}

/// PTY output, or the reason there won't be any more.
pub enum ShellEvent {
    Data(Vec<u8>),
    Exit(Option<u32>),
}

/// Turns channel messages into the two things a terminal cares about.
///
/// `ExtendedData` (stderr) is folded into `Data`: a PTY session merges the two
/// streams anyway, and a terminal has nowhere separate to put stderr.
pub async fn next_shell_event(channel: &mut ChannelReadHalf) -> Option<ShellEvent> {
    loop {
        match channel.wait().await? {
            ChannelMsg::Data { data } => return Some(ShellEvent::Data(data.to_vec())),
            ChannelMsg::ExtendedData { data, .. } => {
                return Some(ShellEvent::Data(data.to_vec()));
            }
            ChannelMsg::ExitStatus { exit_status } => {
                return Some(ShellEvent::Exit(Some(exit_status)));
            }
            ChannelMsg::Eof | ChannelMsg::Close => return Some(ShellEvent::Exit(None)),
            // Window adjustments, signals, replies — nothing to show
            _ => continue,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn error_codes_are_stable_and_distinct() {
        // The panel branches on these, so they are part of the wire contract
        let codes = [
            SshError::Connect(String::new()).code(),
            SshError::HostKeyMismatch {
                expected: String::new(),
                actual: String::new(),
            }
            .code(),
            SshError::AuthFailed.code(),
            SshError::BadKey(String::new()).code(),
            SshError::Protocol(String::new()).code(),
        ];
        let unique: std::collections::HashSet<_> = codes.iter().collect();
        assert_eq!(unique.len(), codes.len());
    }

    #[test]
    fn an_auth_failure_says_nothing_about_which_part_was_wrong() {
        let message = SshError::AuthFailed.message();
        for leak in ["password", "user", "key"] {
            assert!(
                !message.to_lowercase().contains(leak),
                "auth failures must not narrow the search for a guesser: {message}"
            );
        }
    }

    #[test]
    fn a_host_key_mismatch_names_both_fingerprints() {
        let message = SshError::HostKeyMismatch {
            expected: "SHA256:aaa".to_string(),
            actual: "SHA256:bbb".to_string(),
        }
        .message();
        assert!(message.contains("SHA256:aaa") && message.contains("SHA256:bbb"));
    }

    #[test]
    fn credentials_are_wiped_when_dropped() {
        // Reaching into the buffer after the drop would be UB, so this checks
        // the observable half: zeroize() empties the fields in place.
        let mut credential = Credential::Password("hunter2".to_string());
        credential.zeroize();
        match &credential {
            Credential::Password(p) => assert!(p.bytes().all(|b| b == 0)),
            _ => unreachable!(),
        }

        let mut key = Credential::Key {
            pem: "-----BEGIN-----".to_string(),
            passphrase: Some("secret".to_string()),
        };
        key.zeroize();
        match &key {
            Credential::Key { pem, passphrase } => {
                assert!(pem.bytes().all(|b| b == 0));
                assert!(passphrase.as_ref().unwrap().bytes().all(|b| b == 0));
            }
            _ => unreachable!(),
        }
    }
}
