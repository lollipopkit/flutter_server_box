//! Email over SMTP (lettre). `security` is `starttls` (the default, port 587),
//! `tls` (implicit TLS, port 465) or `none` (port 25), the last refused with a
//! password unless the server is on this machine: it would send the password
//! across the network in clear. Certificates are checked by the platform
//! verifier, as for every HTTPS push.

use std::net::IpAddr;

use lettre::{
    AsyncSmtpTransport, AsyncTransport, Message, Tokio1Executor,
    message::{Mailbox, header::ContentType},
    transport::smtp::authentication::Credentials,
};
use tracing::info;

use super::{REQUEST_TIMEOUT, integer, list, push_error, render, text};
use crate::{
    core::config::{Config, PushConfig},
    utils::error::Result,
};

const DEFAULT_SUBJECT: &str = "ServerBox Monitor: {{name}}";

#[derive(Clone, Copy, PartialEq, Debug)]
enum Security {
    StartTls,
    Tls,
    None,
}

struct Settings<'a> {
    host: &'a str,
    port: u16,
    security: Security,
    credentials: Option<(&'a str, &'a str)>,
    from: Mailbox,
    to: Vec<Mailbox>,
}

fn settings(push: &PushConfig) -> std::result::Result<Settings<'_>, String> {
    let host = text(push, "host").ok_or("host is required")?.trim();
    let security = match text(push, "security").unwrap_or("starttls") {
        "starttls" => Security::StartTls,
        "tls" => Security::Tls,
        "none" => Security::None,
        _ => return Err("security must be starttls, tls or none".to_string()),
    };
    let port = match integer(push, "port") {
        Some(port) => u16::try_from(port).ok().filter(|port| *port > 0).ok_or("port must be 1 to 65535")?,
        None => match security {
            Security::StartTls => 587,
            Security::Tls => 465,
            Security::None => 25,
        },
    };
    let credentials = match (text(push, "username"), text(push, "password")) {
        (Some(username), Some(password)) => Some((username, password)),
        (None, None) => None,
        _ => return Err("username and password go together".to_string()),
    };
    if credentials.is_some() && security == Security::None && !is_loopback(host) {
        return Err("a password is sent only over TLS (security = starttls or tls) unless the server is this machine".to_string());
    }
    let from = text(push, "from")
        .ok_or("from is required")?
        .parse::<Mailbox>()
        .map_err(|error| format!("from is not an address: {error}"))?;
    let to = list(push, "to")
        .iter()
        .map(|address| address.parse::<Mailbox>().map_err(|error| format!("to has '{address}', not an address: {error}")))
        .collect::<std::result::Result<Vec<_>, _>>()?;
    if to.is_empty() {
        return Err("to needs at least one address".to_string());
    }
    Ok(Settings { host, port, security, credentials, from, to })
}

fn is_loopback(host: &str) -> bool {
    host.eq_ignore_ascii_case("localhost")
        || host
            .trim_start_matches('[')
            .trim_end_matches(']')
            .parse::<IpAddr>()
            .is_ok_and(|ip| ip.is_loopback())
}

pub(super) fn validate(push: &PushConfig) -> std::result::Result<(), String> {
    settings(push).map(|_| ())
}

pub(super) async fn send(config: &Config, push: &PushConfig, message: &str) -> Result<()> {
    let settings = settings(push).map_err(push_error)?;
    let name = config.get_server_name();
    let subject = render(text(push, "subject").unwrap_or(DEFAULT_SUBJECT), message, &name, str::to_string);
    let body = render(text(push, "body").unwrap_or("{{message}}"), message, &name, str::to_string);

    let mut email = Message::builder().from(settings.from).subject(subject);
    for to in settings.to {
        email = email.to(to);
    }
    let email = email
        .header(ContentType::TEXT_PLAIN)
        .body(body)
        .map_err(|error| push_error(format!("Could not build the email: {error}")))?;

    let builder = match settings.security {
        Security::StartTls => AsyncSmtpTransport::<Tokio1Executor>::starttls_relay(settings.host),
        Security::Tls => AsyncSmtpTransport::<Tokio1Executor>::relay(settings.host),
        Security::None => Ok(AsyncSmtpTransport::<Tokio1Executor>::builder_dangerous(settings.host)),
    }
    .map_err(|error| push_error(format!("SMTP: {error}")))?;
    let mut builder = builder.port(settings.port).timeout(Some(REQUEST_TIMEOUT));
    if let Some((username, password)) = settings.credentials {
        builder = builder.credentials(Credentials::new(username.to_string(), password.to_string()));
    }

    builder
        .build()
        .send(email)
        .await
        .map_err(|error| push_error(format!("SMTP: {error}")))?;
    info!("Email notification sent successfully to {}", push.name);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::monitoring::push::tests::config;
    use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
    use tokio::net::TcpListener;

    fn smtp(extra: &str) -> PushConfig {
        PushConfig {
            name: "mail".to_string(),
            push_type: "smtp".to_string(),
            config: toml::from_str(extra).unwrap(),
        }
    }

    /// Enough of an SMTP server to take one message, answering what it got.
    async fn fake_smtp() -> (u16, tokio::task::JoinHandle<String>) {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let port = listener.local_addr().unwrap().port();
        let session = tokio::spawn(async move {
            let (socket, _) = listener.accept().await.unwrap();
            let (read, mut write) = socket.into_split();
            let mut lines = BufReader::new(read).lines();
            let mut transcript = String::new();
            write.write_all(b"220 fake ESMTP\r\n").await.unwrap();
            let mut in_data = false;
            while let Some(line) = lines.next_line().await.unwrap() {
                transcript.push_str(&line);
                transcript.push('\n');
                let reply: &[u8] = if in_data {
                    if line != "." {
                        continue;
                    }
                    in_data = false;
                    b"250 queued\r\n"
                } else if line.starts_with("EHLO") {
                    b"250-fake\r\n250 8BITMIME\r\n"
                } else if line == "DATA" {
                    in_data = true;
                    b"354 go on\r\n"
                } else if line == "QUIT" {
                    write.write_all(b"221 bye\r\n").await.unwrap();
                    break;
                } else {
                    b"250 ok\r\n"
                };
                write.write_all(reply).await.unwrap();
            }
            transcript
        });
        (port, session)
    }

    #[tokio::test]
    async fn a_message_reaches_every_recipient() {
        let (port, session) = fake_smtp().await;
        let push = smtp(&format!(
            "host = \"127.0.0.1\"\nport = {port}\nsecurity = \"none\"\nfrom = \"SBM <sbm@example.invalid>\"\nto = \"a@example.invalid, b@example.invalid\""
        ));
        send(&config("host-a"), &push, "disk 95%").await.unwrap();
        let transcript = session.await.unwrap();
        assert!(transcript.contains("MAIL FROM:<sbm@example.invalid>"), "{transcript}");
        assert!(transcript.contains("RCPT TO:<a@example.invalid>"), "{transcript}");
        assert!(transcript.contains("RCPT TO:<b@example.invalid>"), "{transcript}");
        assert!(transcript.contains("Subject: ServerBox Monitor: host-a"), "{transcript}");
        assert!(transcript.contains("disk 95%"), "{transcript}");
    }

    #[test]
    fn a_password_in_clear_to_another_machine_is_refused() {
        let push = smtp("host = \"mail.example.invalid\"\nsecurity = \"none\"\nusername = \"u\"\npassword = \"p\"\nfrom = \"a@example.invalid\"\nto = \"b@example.invalid\"");
        assert!(validate(&push).unwrap_err().contains("only over TLS"));
        let local = smtp("host = \"localhost\"\nsecurity = \"none\"\nusername = \"u\"\npassword = \"p\"\nfrom = \"a@example.invalid\"\nto = \"b@example.invalid\"");
        assert!(validate(&local).is_ok());
    }

    #[test]
    fn an_address_that_does_not_parse_is_refused() {
        let push = smtp("host = \"mail.example.invalid\"\nfrom = \"a@example.invalid\"\nto = [\"not an address\"]");
        assert!(validate(&push).unwrap_err().contains("not an address"));
    }
}
