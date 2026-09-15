use std::io;
use std::sync::{Arc, Mutex};

use tokio::io::{AsyncRead, AsyncWrite, AsyncWriteExt as _};
use tokio_rustls::rustls;
use tokio_rustls::rustls::pki_types::ServerName;

pub type TlsStream<S> = tokio_rustls::client::TlsStream<S>;

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
    let verification = Arc::new(Mutex::new(None));
    let verifier = danger::RecordingCertificateVerifier::new(verification.clone())?;
    let mut tls_stream = {
        let mut config = rustls::client::ClientConfig::builder()
            .dangerous()
            .with_custom_certificate_verifier(Arc::new(verifier))
            .with_no_client_auth();

        // This adds support for the SSLKEYLOGFILE env variable (https://wiki.wireshark.org/TLS#using-the-pre-master-secret)
        config.key_log = Arc::new(rustls::KeyLogFile::new());

        // Disable TLS resumption because it’s not supported by some services such as CredSSP.
        //
        // > The CredSSP Protocol does not extend the TLS wire protocol. TLS session resumption is not supported.
        //
        // source: https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-cssp/385a7489-d46b-464c-b224-f7340e308a5c
        config.resumption = rustls::client::Resumption::disabled();

        let config = Arc::new(config);

        let domain = ServerName::try_from(server_name.to_owned()).map_err(io::Error::other)?;

        tokio_rustls::TlsConnector::from(config).connect(domain, stream).await?
    };

    tls_stream.flush().await?;

    let tls_cert = {
        use x509_cert::der::Decode as _;

        let cert = tls_stream
            .get_ref()
            .1
            .peer_certificates()
            .and_then(|certificates| certificates.first())
            .ok_or_else(|| io::Error::other("peer certificate is missing"))?;

        x509_cert::Certificate::from_der(cert).map_err(io::Error::other)?
    };

    let system_trusted = verification
        .lock()
        .map_err(|_| io::Error::other("certificate verifier state is poisoned"))?
        .unwrap_or(false);

    Ok((
        tls_stream,
        crate::TlsServerIdentity {
            certificate: tls_cert,
            system_trusted,
        },
    ))
}

/// Report the TLS version and cipher suite negotiated for `stream`.
pub fn negotiated<S>(stream: &TlsStream<S>) -> crate::NegotiatedTls {
    let (_, connection) = stream.get_ref();
    crate::NegotiatedTls {
        version: connection.protocol_version().map(|version| format!("{version:?}")),
        cipher_suite: connection
            .negotiated_cipher_suite()
            .map(|suite| format!("{:?}", suite.suite())),
    }
}

mod danger {
    use std::io;
    use std::sync::{Arc, Mutex};

    use tokio_rustls::rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
    use tokio_rustls::rustls::client::WebPkiServerVerifier;
    use tokio_rustls::rustls::{DigitallySignedStruct, Error, SignatureScheme, pki_types};

    #[derive(Debug)]
    pub(super) struct RecordingCertificateVerifier {
        inner: Arc<WebPkiServerVerifier>,
        result: Arc<Mutex<Option<bool>>>,
    }

    impl RecordingCertificateVerifier {
        pub(super) fn new(result: Arc<Mutex<Option<bool>>>) -> io::Result<Self> {
            let mut roots = tokio_rustls::rustls::RootCertStore::empty();
            let native = rustls_native_certs::load_native_certs();
            for certificate in native.certs {
                let _ = roots.add(certificate);
            }
            let inner = WebPkiServerVerifier::builder(Arc::new(roots))
                .build()
                .map_err(io::Error::other)?;
            Ok(Self { inner, result })
        }
    }

    impl ServerCertVerifier for RecordingCertificateVerifier {
        fn verify_server_cert(
            &self,
            end_entity: &pki_types::CertificateDer<'_>,
            intermediates: &[pki_types::CertificateDer<'_>],
            server_name: &pki_types::ServerName<'_>,
            ocsp_response: &[u8],
            now: pki_types::UnixTime,
        ) -> Result<ServerCertVerified, Error> {
            let verified = self
                .inner
                .verify_server_cert(end_entity, intermediates, server_name, ocsp_response, now)
                .is_ok();
            if let Ok(mut result) = self.result.lock() {
                *result = Some(verified);
            }
            Ok(ServerCertVerified::assertion())
        }

        fn verify_tls12_signature(
            &self,
            message: &[u8],
            certificate: &pki_types::CertificateDer<'_>,
            signature: &DigitallySignedStruct,
        ) -> Result<HandshakeSignatureValid, Error> {
            self.inner.verify_tls12_signature(message, certificate, signature)
        }

        fn verify_tls13_signature(
            &self,
            message: &[u8],
            certificate: &pki_types::CertificateDer<'_>,
            signature: &DigitallySignedStruct,
        ) -> Result<HandshakeSignatureValid, Error> {
            self.inner.verify_tls13_signature(message, certificate, signature)
        }

        fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
            self.inner.supported_verify_schemes()
        }
    }
}
