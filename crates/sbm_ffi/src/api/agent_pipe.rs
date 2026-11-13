//! An ssh-agent's Windows named pipe (`\\.\pipe\openssh-ssh-agent`), which
//! `dart:io` cannot open: bytes in and out, the agent protocol stays in Dart
//! (dartssh2's `SSHAgentClient`).

use flutter_rust_bridge::frb;

#[cfg(windows)]
use std::{
    sync::atomic::{AtomicBool, Ordering},
    time::Duration,
};

#[cfg(windows)]
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt, ReadHalf, WriteHalf},
    net::windows::named_pipe::{ClientOptions, NamedPipeClient},
    sync::{Mutex, Notify},
};

/// One connection to an agent's pipe. Opaque whatever the platform: the
/// fields exist only on Windows, and codegen runs anywhere.
#[frb(opaque)]
pub struct AgentPipe {
    #[cfg(windows)]
    reader: Mutex<Option<ReadHalf<NamedPipeClient>>>,
    #[cfg(windows)]
    writer: Mutex<Option<WriteHalf<NamedPipeClient>>>,
    #[cfg(windows)]
    closed: AtomicBool,
    #[cfg(windows)]
    close: Notify,
}

/// Win32's `ERROR_PIPE_BUSY`: every instance of the pipe is serving a client.
#[cfg(windows)]
const ERROR_PIPE_BUSY: i32 = 231;

impl AgentPipe {
    /// Opens the pipe at [path], waiting up to [timeout_ms] while every
    /// instance of it is busy.
    pub async fn connect(path: String, timeout_ms: u32) -> Result<AgentPipe, String> {
        #[cfg(windows)]
        {
            let deadline = tokio::time::Instant::now() + Duration::from_millis(timeout_ms.into());
            let client = loop {
                match ClientOptions::new().open(&path) {
                    Ok(client) => break client,
                    Err(e)
                        if e.raw_os_error() == Some(ERROR_PIPE_BUSY)
                            && tokio::time::Instant::now() < deadline =>
                    {
                        tokio::time::sleep(Duration::from_millis(50)).await;
                    }
                    Err(e) => return Err(e.to_string()),
                }
            };
            let (reader, writer) = tokio::io::split(client);
            Ok(AgentPipe {
                reader: Mutex::new(Some(reader)),
                writer: Mutex::new(Some(writer)),
                closed: AtomicBool::new(false),
                close: Notify::new(),
            })
        }
        #[cfg(not(windows))]
        {
            let _ = (path, timeout_ms);
            Err("named pipes are Windows-only".into())
        }
    }

    /// The next bytes the agent sent; none once the pipe is closed, from
    /// either end.
    pub async fn read(&self) -> Result<Option<Vec<u8>>, String> {
        #[cfg(windows)]
        {
            let closed = self.close.notified();
            if self.closed.load(Ordering::Acquire) {
                return Ok(None);
            }
            let mut reader = self.reader.lock().await;
            let Some(reader) = reader.as_mut() else {
                return Ok(None);
            };
            // Agent replies are a few hundred bytes; a longer one takes reads.
            let mut buf = vec![0u8; 4 * 1024];
            tokio::select! {
                read = reader.read(&mut buf) => match read {
                    Ok(0) => Ok(None),
                    Ok(n) => {
                        buf.truncate(n);
                        Ok(Some(buf))
                    }
                    Err(e) => Err(e.to_string()),
                },
                _ = closed => Ok(None),
            }
        }
        #[cfg(not(windows))]
        Ok(None)
    }

    pub async fn write(&self, data: Vec<u8>) -> Result<(), String> {
        #[cfg(windows)]
        {
            // As [read]: an agent that stops reading leaves a write pending
            // once the pipe's buffer is full, and [close] needs this lock.
            let closed = self.close.notified();
            if self.closed.load(Ordering::Acquire) {
                return Err("closed".into());
            }
            let mut writer = self.writer.lock().await;
            let writer = writer.as_mut().ok_or("closed")?;
            tokio::select! {
                written = writer.write_all(&data) => written.map_err(|e| e.to_string()),
                _ = closed => Err("closed".into()),
            }
        }
        #[cfg(not(windows))]
        {
            let _ = data;
            Err("closed".into())
        }
    }

    /// Ends the connection: a [read] waiting answers none, a [write] waiting
    /// fails, and the handle is released here, not when Dart drops this.
    pub async fn close(&self) {
        #[cfg(windows)]
        {
            self.closed.store(true, Ordering::Release);
            self.close.notify_waiters();
            // Both halves dropped is the handle closed; the reader's lock is
            // free once the read the notification ended has returned.
            drop(self.writer.lock().await.take());
            drop(self.reader.lock().await.take());
        }
    }
}

#[cfg(all(test, windows))]
mod tests {
    use super::*;
    use tokio::net::windows::named_pipe::ServerOptions;

    fn pipe_name(tag: &str) -> String {
        format!(r"\\.\pipe\sbm-agent-pipe-test-{tag}-{}", std::process::id())
    }

    #[tokio::test]
    async fn bytes_go_both_ways() {
        let name = pipe_name("echo");
        let server = ServerOptions::new().first_pipe_instance(true).create(&name).unwrap();
        let echo = tokio::spawn(async move {
            server.connect().await.unwrap();
            let mut server = server;
            let mut buf = [0u8; 64];
            let n = server.read(&mut buf).await.unwrap();
            server.write_all(&buf[..n]).await.unwrap();
        });

        let pipe = AgentPipe::connect(name, 1000).await.unwrap();
        pipe.write(b"hello".to_vec()).await.unwrap();
        assert_eq!(pipe.read().await.unwrap().as_deref(), Some(&b"hello"[..]));
        echo.await.unwrap();
        // The server is gone: the end of the pipe, not an error.
        assert_eq!(pipe.read().await.unwrap(), None);
    }

    #[tokio::test]
    async fn close_ends_a_waiting_read() {
        let name = pipe_name("close");
        let server = ServerOptions::new().first_pipe_instance(true).create(&name).unwrap();
        let held = tokio::spawn(async move {
            server.connect().await.unwrap();
            let mut server = server;
            let mut buf = [0u8; 1];
            // The client's close is the server's end of file.
            assert_eq!(server.read(&mut buf).await.unwrap(), 0);
        });

        let pipe = std::sync::Arc::new(AgentPipe::connect(name, 1000).await.unwrap());
        let reading = tokio::spawn({
            let pipe = pipe.clone();
            async move { pipe.read().await }
        });
        tokio::time::sleep(Duration::from_millis(50)).await;
        pipe.close().await;

        let read = tokio::time::timeout(Duration::from_secs(1), reading).await;
        assert_eq!(read.unwrap().unwrap().unwrap(), None);
        assert!(pipe.write(b"x".to_vec()).await.is_err());
        tokio::time::timeout(Duration::from_secs(1), held).await.unwrap().unwrap();
    }

    #[tokio::test]
    async fn close_ends_a_write_the_agent_never_reads() {
        let name = pipe_name("full");
        let server = ServerOptions::new()
            .first_pipe_instance(true)
            .in_buffer_size(1024)
            .create(&name)
            .unwrap();
        let held = tokio::spawn(async move {
            server.connect().await.unwrap();
            // Connected, never read from, until the test is over.
            tokio::time::sleep(Duration::from_secs(10)).await;
            drop(server);
        });

        let pipe = std::sync::Arc::new(AgentPipe::connect(name, 1000).await.unwrap());
        let writing = tokio::spawn({
            let pipe = pipe.clone();
            // Until the agent's side is full: Windows grows a pipe's buffer
            // past what it was created with, so no one size is enough.
            async move {
                loop {
                    pipe.write(vec![0u8; 1 << 16]).await?;
                }
                #[allow(unreachable_code)]
                Ok::<(), String>(())
            }
        });
        tokio::time::sleep(Duration::from_millis(100)).await;
        assert!(!writing.is_finished(), "the write should be waiting on the agent");

        tokio::time::timeout(Duration::from_secs(1), pipe.close()).await.unwrap();
        let written = tokio::time::timeout(Duration::from_secs(1), writing).await;
        assert!(written.unwrap().unwrap().is_err());
        held.abort();
    }

    #[tokio::test]
    async fn a_pipe_that_is_not_there_is_an_error() {
        assert!(AgentPipe::connect(pipe_name("missing"), 100).await.is_err());
    }
}
