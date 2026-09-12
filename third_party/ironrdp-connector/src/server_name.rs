#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ServerName(String);

impl ServerName {
    pub fn new(name: impl Into<String>) -> Self {
        Self(sanitize_server_name(name.into()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }

    pub fn into_inner(self) -> String {
        self.0
    }
}

impl From<String> for ServerName {
    fn from(value: String) -> Self {
        Self::new(value)
    }
}

impl From<&String> for ServerName {
    fn from(value: &String) -> Self {
        Self::new(value)
    }
}

impl From<&str> for ServerName {
    fn from(value: &str) -> Self {
        Self::new(value)
    }
}

fn sanitize_server_name(name: String) -> String {
    if let Some(addr_split) = name.rsplit_once(':') {
        if let Ok(sock_addr) = name.parse::<core::net::SocketAddr>() {
            // A socket address, including a port
            sock_addr.ip().to_string()
        } else if name.parse::<core::net::Ipv6Addr>().is_ok() {
            // An IPv6 address with no port, do not include a port, already sane
            name
        } else {
            // An IPv4 address or server hostname including a port after the `:` token
            addr_split.0.to_owned()
        }
    } else {
        // An IPv4 address or server hostname which does not include a port, already sane
        name
    }
}
