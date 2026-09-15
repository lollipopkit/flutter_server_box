use std::io;
use std::marker::PhantomData;
use std::task::{Context, Poll};

use tokio::io::{AsyncRead, AsyncWrite, ReadBuf};

#[derive(Debug)]
pub struct TlsStream<S> {
    _marker: PhantomData<S>,
}

impl<S> AsyncRead for TlsStream<S> {
    fn poll_read(self: std::pin::Pin<&mut Self>, _: &mut Context<'_>, _: &mut ReadBuf<'_>) -> Poll<io::Result<()>> {
        Poll::Ready(Ok(()))
    }
}

impl<S> AsyncWrite for TlsStream<S> {
    fn poll_write(self: std::pin::Pin<&mut Self>, _: &mut Context<'_>, _: &[u8]) -> Poll<Result<usize, io::Error>> {
        Poll::Ready(Ok(0))
    }

    fn poll_flush(self: std::pin::Pin<&mut Self>, _: &mut Context<'_>) -> Poll<Result<(), io::Error>> {
        Poll::Ready(Ok(()))
    }

    fn poll_shutdown(self: std::pin::Pin<&mut Self>, _: &mut Context<'_>) -> Poll<Result<(), io::Error>> {
        Poll::Ready(Ok(()))
    }
}

pub async fn upgrade<S>(stream: S, server_name: &str) -> io::Result<(TlsStream<S>, x509_cert::Certificate)>
where
    S: Unpin + AsyncRead + AsyncWrite,
{
    // Do nothing and fail
    let _ = (stream, server_name);
    Err(io::Error::other("no TLS backend enabled for this build"))
}

pub async fn upgrade_with_identity<S>(
    stream: S,
    server_name: &str,
) -> io::Result<(TlsStream<S>, crate::TlsServerIdentity)>
where
    S: Unpin + AsyncRead + AsyncWrite,
{
    let _ = (stream, server_name);
    Err(io::Error::other("no TLS backend enabled for this build"))
}

/// The stub backend performs no handshake and reports nothing.
pub fn negotiated<S>(_stream: &TlsStream<S>) -> crate::NegotiatedTls {
    crate::NegotiatedTls::default()
}
