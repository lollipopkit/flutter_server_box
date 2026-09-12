use std::io;

use tokio::io::{AsyncRead, AsyncWrite, AsyncWriteExt as _};

pub type TlsStream<S> = tokio_native_tls::TlsStream<S>;

pub async fn upgrade<S>(stream: S, server_name: &str) -> io::Result<(TlsStream<S>, x509_cert::Certificate)>
where
    S: Unpin + AsyncRead + AsyncWrite,
{
    let (stream, identity) = upgrade_with_identity(stream, server_name).await?;
    Ok((stream, identity.certificate))
}

pub async fn upgrade_with_identity<S>(
    stream: S,
    server_name: &str,
) -> io::Result<(TlsStream<S>, crate::TlsServerIdentity)>
where
    S: Unpin + AsyncRead + AsyncWrite,
{
    let mut tls_stream = {
        let connector = tokio_native_tls::native_tls::TlsConnector::builder()
            .danger_accept_invalid_certs(true)
            .use_sni(false)
            .build()
            .map(tokio_native_tls::TlsConnector::from)
            .map_err(io::Error::other)?;

        connector.connect(server_name, stream).await.map_err(io::Error::other)?
    };

    tls_stream.flush().await?;

    let tls_cert = {
        use x509_cert::der::Decode as _;

        let cert = tls_stream
            .get_ref()
            .peer_certificate()
            .map_err(io::Error::other)?
            .ok_or_else(|| io::Error::other("peer certificate is missing"))?;
        let cert = cert.to_der().map_err(io::Error::other)?;

        x509_cert::Certificate::from_der(&cert).map_err(io::Error::other)?
    };

    Ok((
        tls_stream,
        crate::TlsServerIdentity {
            certificate: tls_cert,
            system_trusted: false,
        },
    ))
}

/// The `native-tls` backend does not expose the negotiated version or cipher.
pub fn negotiated<S>(_stream: &TlsStream<S>) -> crate::NegotiatedTls {
    crate::NegotiatedTls::default()
}
