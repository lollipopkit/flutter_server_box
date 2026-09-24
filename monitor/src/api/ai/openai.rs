//! The one protocol the panel's Agent speaks: OpenAI's Chat Completions.
//!
//! The app can also talk to the `responses` API, and that branch is deliberately
//! not ported. A `responses` turn has to replay its previous reply's items
//! verbatim — reasoning items, tool items, the whole shape — because the
//! endpoint will not accept a transcript it cannot re-derive; chat/completions
//! is re-derivable from role and content alone. Every vendor implements
//! chat/completions and one implements `responses`, so the portable choice is
//! also the simpler one. That is a trade with a reason, not an unfinished one.
//!
//! Nothing here holds the API key: it arrives per call, is put in a header, and
//! is never logged, stored, or echoed — see [`UpstreamError`] for why not even
//! in an error.
//!
//! Everything above the network is pure and tested: the frame splitter, the
//! delta parser and the step assembler are functions over bytes and JSON, so
//! the fragmentation a real stream does — a frame split across two reads, tool
//! arguments arriving a few characters at a time, a multi-byte character
//! straddling a chunk boundary — is exercised without a server.

use std::sync::OnceLock;
use std::time::Duration;

use futures::StreamExt;
use futures::stream::BoxStream;
use serde_json::{Value, json};

/// How long the connection may take to come up, and nothing else.
///
/// There is deliberately no whole-request timeout: a turn is a model thinking,
/// which is minutes on a long answer with tools, and the thing that ends a turn
/// is the operator pressing Stop or the process going away. A client-wide
/// timeout would kill exactly the turns that are working.
const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);

/// The HTTP client, process-wide, for the same reasons `monitoring::push` has
/// one — and with one difference that matters: no request timeout, see
/// [`CONNECT_TIMEOUT`].
fn http_client() -> &'static reqwest::Client {
    static CLIENT: OnceLock<reqwest::Client> = OnceLock::new();
    CLIENT.get_or_init(|| {
        // reqwest is built without a crypto provider of its own, so the one the
        // rest of the agent uses has to be the process default before it builds
        // a TLS config — otherwise the first HTTPS turn panics inside rustls
        // rather than failing as an unreachable endpoint. `install_default`
        // answers Err when one is already installed, which is the outcome here
        // and what a second call in a test process does.
        let _ = rustls::crypto::ring::default_provider().install_default();

        let builder = reqwest::Client::builder()
            .connect_timeout(CONNECT_TIMEOUT)
            .pool_idle_timeout(Duration::from_secs(60));
        #[cfg(test)]
        let builder = builder.no_proxy();
        builder
            .build()
            .expect("valid AI HTTP client configuration")
    })
}

/// Why a turn could not talk to its endpoint.
///
/// A code, not a message, and every one of them is phrased by whichever client
/// draws it. The upstream body is never carried: a provider's own complaint
/// about a key is the one place a key is echoed back — `Incorrect API key
/// provided: sk-…` is a real 401 body — and a value that may appear in a log, an
/// audit row or a stored item is not a value this agent keeps.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UpstreamError {
    /// The connection never came up: DNS, TLS, no route.
    Unreachable,
    /// 401 or 403 — the stored key is wrong, or there is none.
    Auth,
    /// 404 — the path or the model does not exist at that endpoint.
    NotFound,
    /// 400 or 422 — the endpoint refused the request, which in practice means a
    /// model that will not take tools, or a name it does not have.
    Rejected,
    /// 429.
    RateLimited,
    /// 5xx, or an in-band `error` object on an otherwise successful response.
    Unavailable,
    /// A 2xx body that is not a chat completion: a frame that does not parse, a
    /// tool call with no id or no name, a turn that ended without saying so.
    Shape,
}

impl UpstreamError {
    /// The spelling a client reads and phrases.
    pub const fn as_str(self) -> &'static str {
        match self {
            UpstreamError::Unreachable => "unreachable",
            UpstreamError::Auth => "auth",
            UpstreamError::NotFound => "not_found",
            UpstreamError::Rejected => "rejected",
            UpstreamError::RateLimited => "rate_limited",
            UpstreamError::Unavailable => "unavailable",
            UpstreamError::Shape => "shape",
        }
    }

    fn from_status(status: u16) -> Self {
        match status {
            401 | 403 => UpstreamError::Auth,
            404 => UpstreamError::NotFound,
            400 | 422 => UpstreamError::Rejected,
            429 => UpstreamError::RateLimited,
            s if s >= 500 => UpstreamError::Unavailable,
            // Any other non-success status. There is no specific code for "the
            // endpoint said something else", and inventing one per number would
            // be a vocabulary no client can phrase; the request was refused.
            _ => UpstreamError::Rejected,
        }
    }
}

impl std::fmt::Display for UpstreamError {
    /// For a log line, where a person is reading. The wire carries
    /// [`UpstreamError::as_str`].
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let text = match self {
            UpstreamError::Unreachable => "the endpoint could not be reached",
            UpstreamError::Auth => "the endpoint refused the credentials",
            UpstreamError::NotFound => "the endpoint or model was not found",
            UpstreamError::Rejected => "the endpoint refused the request",
            UpstreamError::RateLimited => "the endpoint is rate limiting",
            UpstreamError::Unavailable => "the endpoint is unavailable",
            UpstreamError::Shape => "the endpoint's answer was not a chat completion",
        };
        f.write_str(text)
    }
}

impl std::error::Error for UpstreamError {}

/// One parsed piece of an upstream stream.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Chunk {
    /// Assistant text.
    Content(String),
    /// The provider's reasoning side channel — `reasoning_content`, which
    /// DeepSeek and several compatible endpoints send. Drawn, never sent back.
    Reasoning(String),
    /// A fragment of a tool call. `id` and `name` arrive with the first
    /// fragment of an index and the arguments arrive as a run of fragments, so
    /// only [`Step`] can say what the call ended up being.
    ToolCall {
        index: usize,
        id: Option<String>,
        name: Option<String>,
        arguments: String,
    },
    /// Tokens the endpoint reported. Sent last, with no choices.
    Usage {
        prompt: u64,
        completion: u64,
    },
}

/// A tool call as the endpoint assembled it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PendingCall {
    pub id: String,
    pub name: String,
    /// The JSON object the model produced, verbatim. Never re-serialised from
    /// the fields parsed out of it: what the reviewer approves and what the tool
    /// is handed have to be the same bytes.
    pub arguments: String,
}

/// One assistant step: what the model said, what it thought, and what it asked
/// for.
#[derive(Debug, Default, Clone, PartialEq, Eq)]
pub struct Step {
    pub content: String,
    pub reasoning: String,
    pub calls: Vec<PendingCall>,
    pub usage: Option<(u64, u64)>,
}

impl Step {
    /// Folds one chunk in. Answers whether it changed anything, which is what
    /// tells the caller whether there is a delta worth streaming onward.
    pub fn absorb(&mut self, chunk: Chunk) -> bool {
        match chunk {
            Chunk::Content(text) => {
                self.content.push_str(&text);
                true
            }
            Chunk::Reasoning(text) => {
                self.reasoning.push_str(&text);
                true
            }
            Chunk::ToolCall {
                index,
                id,
                name,
                arguments,
            } => {
                // Grown rather than inserted at `index`: a stream that skipped
                // an index would otherwise be stored as a reordered list. A gap
                // leaves an empty call, which `resolve` refuses — the protocol
                // broke, and a call with no id cannot be answered anyway.
                while self.calls.len() <= index {
                    self.calls.push(PendingCall {
                        id: String::new(),
                        name: String::new(),
                        arguments: String::new(),
                    });
                }
                let call = &mut self.calls[index];
                if let Some(id) = id {
                    call.id = id;
                }
                if let Some(name) = name {
                    call.name = name;
                }
                call.arguments.push_str(&arguments);
                true
            }
            Chunk::Usage { prompt, completion } => {
                self.usage = Some((prompt, completion));
                false
            }
        }
    }

    /// Whether the step asked for anything to be run.
    pub fn wants_calls(&self) -> bool {
        !self.calls.is_empty()
    }

    /// The step's calls, or a refusal when the endpoint sent one it cannot
    /// answer — no id, no name, arguments that are not an object.
    pub fn resolve(&self) -> Result<&[PendingCall], UpstreamError> {
        for call in &self.calls {
            if call.id.trim().is_empty() || call.name.trim().is_empty() {
                return Err(UpstreamError::Shape);
            }
            if !call.arguments.trim().is_empty() {
                let parsed: Value = serde_json::from_str(&call.arguments).map_err(|_| {
                    // An empty arguments field is how a no-argument call is
                    // sent, and `{}` is how it is usually sent; anything else
                    // that is not an object is a model producing something the
                    // tool cannot be handed.
                    UpstreamError::Shape
                })?;
                if !parsed.is_object() {
                    return Err(UpstreamError::Shape);
                }
            }
        }
        Ok(&self.calls)
    }
}

/// Reassembles server-sent events out of a byte stream.
///
/// Bytes rather than text: a chunk boundary can fall inside a multi-byte
/// character, and decoding each chunk on its own would replace it. A frame is
/// decoded once its terminating blank line has arrived, which is a boundary
/// that always falls between characters because it is ASCII.
#[derive(Default)]
pub struct SseBuffer {
    buf: Vec<u8>,
}

impl SseBuffer {
    /// Feeds one network chunk and answers with every complete frame it held.
    pub fn feed(&mut self, bytes: &[u8]) -> Result<Vec<Chunk>, UpstreamError> {
        self.buf.extend_from_slice(bytes);
        let mut chunks = Vec::new();
        while let Some(end) = frame_end(&self.buf) {
            let frame: Vec<u8> = self.buf.drain(..end).collect();
            let text = String::from_utf8(frame).map_err(|_| UpstreamError::Shape)?;
            chunks.extend(parse_frame(&text)?);
        }
        Ok(chunks)
    }

    /// Whether a partial frame is still held, i.e. the stream ended mid-frame.
    pub fn has_partial(&self) -> bool {
        !self.buf.is_empty()
    }
}

/// Where the first complete frame ends, terminator included.
///
/// A blank line ends a frame; `\r\n` is accepted as the line ending because a
/// proxy may rewrite them. Only the first blank line of a run ends a frame —
/// the rest belongs to the next one and is skipped by the same rule on the next
/// call.
fn frame_end(buf: &[u8]) -> Option<usize> {
    let mut line_start = 0usize;
    for (i, byte) in buf.iter().enumerate() {
        if *byte != b'\n' {
            continue;
        }
        let line = &buf[line_start..i];
        let line = line.strip_suffix(b"\r").unwrap_or(line);
        if line.is_empty() {
            return Some(i + 1);
        }
        line_start = i + 1;
    }
    None
}

/// The chunks one frame carries.
///
/// A frame with no `data` line is a comment or an `event:` line and carries
/// nothing. Several `data:` lines are joined with a newline, which is what SSE
/// specifies and what a JSON payload split by a proxy would arrive as.
fn parse_frame(frame: &str) -> Result<Vec<Chunk>, UpstreamError> {
    let mut payload = String::new();
    for line in frame.lines() {
        let Some(rest) = line.strip_prefix("data:") else {
            continue;
        };
        if !payload.is_empty() {
            payload.push('\n');
        }
        payload.push_str(rest.strip_prefix(' ').unwrap_or(rest));
    }
    if payload.is_empty() {
        return Ok(Vec::new());
    }
    if payload.trim() == "[DONE]" {
        return Ok(Vec::new());
    }

    let parsed: Value = serde_json::from_str(payload.trim()).map_err(|_| UpstreamError::Shape)?;

    // An in-band failure on a 200 response. The object is read for the fact
    // that it is one, and dropped: it is the provider's complaint, which is
    // where a key gets echoed.
    if parsed.get("error").is_some_and(|e| !e.is_null()) {
        return Err(UpstreamError::Unavailable);
    }

    let mut chunks = Vec::new();
    if let Some(usage) = parsed.get("usage").filter(|u| !u.is_null()) {
        let count = |key: &str| usage.get(key).and_then(Value::as_u64).unwrap_or(0);
        chunks.push(Chunk::Usage {
            prompt: count("prompt_tokens"),
            completion: count("completion_tokens"),
        });
    }

    let Some(choices) = parsed.get("choices").and_then(Value::as_array) else {
        // Either a usage-only frame, which the spec sends last, or a shape this
        // build does not know. The finish_reason every turn ends on is checked
        // by the caller, so a choice-less frame here is only odd, not fatal.
        return Ok(chunks);
    };
    for choice in choices {
        let Some(delta) = choice.get("delta") else {
            continue;
        };
        if let Some(text) = delta.get("content").and_then(Value::as_str)
            && !text.is_empty()
        {
            chunks.push(Chunk::Content(text.to_string()));
        }
        if let Some(text) = delta.get("reasoning_content").and_then(Value::as_str)
            && !text.is_empty()
        {
            chunks.push(Chunk::Reasoning(text.to_string()));
        }
        let Some(calls) = delta.get("tool_calls").and_then(Value::as_array) else {
            continue;
        };
        for call in calls {
            let index = call.get("index").and_then(Value::as_u64).unwrap_or(0) as usize;
            let function = call.get("function");
            chunks.push(Chunk::ToolCall {
                index,
                id: call.get("id").and_then(Value::as_str).map(str::to_string),
                name: function
                    .and_then(|f| f.get("name"))
                    .and_then(Value::as_str)
                    .map(str::to_string),
                arguments: function
                    .and_then(|f| f.get("arguments"))
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_string(),
            });
        }
    }
    Ok(chunks)
}

/// One endpoint as one turn needs it: where to post, what model, and the key.
pub struct Client {
    pub url: String,
    pub model: String,
    /// `None` is sent as no `Authorization` header at all, which is what a
    /// local endpoint — Ollama, vLLM, a gateway that authenticates itself —
    /// expects. It is not an error: an endpoint that wants a key answers 401,
    /// and that is [`UpstreamError::Auth`].
    pub api_key: Option<String>,
}

/// The chunks of one upstream turn.
///
/// A wrapper rather than a bare stream so that the request has already been
/// made and its status checked by the time a caller has one: an authentication
/// failure is a returned error, not the first item of a stream a caller has to
/// remember to read.
pub struct Chunks {
    inner: BoxStream<'static, Result<Chunk, UpstreamError>>,
}

impl Chunks {
    pub async fn next(&mut self) -> Option<Result<Chunk, UpstreamError>> {
        self.inner.next().await
    }
}

impl Client {
    /// What the endpoint is sent, as the object it is sent as. Kept out of
    /// [`Client::stream`] so a test can assert the flags rather than a body.
    pub fn body(&self, messages: &[Value], tools: &[Value]) -> Value {
        json!({
            "model": self.model,
            "messages": messages,
            "tools": tools,
            // The model picks; a call the classifier calls read-only may run
            // unreviewed, everything else waits for a person. `"auto"` says the
            // model may also answer without calling anything, which is what a
            // question wants.
            "tool_choice": "auto",
            // One call at a time. A turn is a sequence of reviewed steps, and
            // parallel calls would arrive as several approvals for one
            // paragraph — the app fixes this for the same reason.
            "parallel_tool_calls": false,
            "stream": true,
            // An OpenAI extension; a compatible endpoint that does not know it
            // either ignores it or refuses the request, and the refusal is
            // reported as `rejected`. It is what makes the token counts in
            // `ai_conversation` possible.
            "stream_options": { "include_usage": true },
        })
    }

    /// Starts one turn and answers its chunks.
    pub async fn stream(
        &self,
        messages: &[Value],
        tools: &[Value],
    ) -> Result<Chunks, UpstreamError> {
        let mut request = http_client().post(&self.url).json(&self.body(messages, tools));
        if let Some(key) = &self.api_key {
            request = request.bearer_auth(key);
        }
        let response = request.send().await.map_err(|e| {
            // The URL and the error kind, never the request: the header carries
            // the key and reqwest's own Display can quote a URL, which is
            // user-supplied (see the module's note on what is kept).
            tracing::debug!("AI endpoint request failed: {e}");
            UpstreamError::Unreachable
        })?;

        let status = response.status();
        if !status.is_success() {
            // Read and dropped. See `UpstreamError`.
            let _ = response.bytes().await;
            return Err(UpstreamError::from_status(status.as_u16()));
        }

        let mut bytes = response.bytes_stream();
        let stream = async_stream::stream! {
            let mut buffer = SseBuffer::default();
            while let Some(chunk) = bytes.next().await {
                let chunk = match chunk {
                    Ok(chunk) => chunk,
                    Err(e) => {
                        tracing::debug!("AI endpoint stream broke: {e}");
                        yield Err(UpstreamError::Unreachable);
                        return;
                    }
                };
                match buffer.feed(&chunk) {
                    Ok(chunks) => {
                        for chunk in chunks {
                            yield Ok(chunk);
                        }
                    }
                    Err(e) => {
                        yield Err(e);
                        return;
                    }
                }
            }
            // A connection that ended between frames is a truncated answer, not
            // a short one: the finish_reason that says the step is over never
            // arrived, so nothing may be treated as complete.
            if buffer.has_partial() {
                yield Err(UpstreamError::Shape);
            }
        };
        Ok(Chunks {
            inner: Box::pin(stream),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A recorded turn: a reasoning delta, two content deltas, a tool call whose
    /// arguments arrive in three fragments, and a usage frame. Written as the
    /// bytes a server sends, `\n\n`-terminated.
    const RECORDED: &str = concat!(
        "data: {\"choices\":[{\"index\":0,\"delta\":{\"reasoning_content\":\"Let me check\"}}]}\n\n",
        "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"The disk \"}}]}\n\n",
        "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"is full.\"}}]}\n\n",
        "data: {\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":0,\"id\":\"call_1\",\"function\":{\"name\":\"run_shell_command\",\"arguments\":\"\"}}]}}]}\n\n",
        "data: {\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"arguments\":\"{\\\"comm\"}}]}}]}\n\n",
        "data: {\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"arguments\":\"and\\\":\\\"df -h\"}}]}}]}\n\n",
        "data: {\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"arguments\":\"\\\"}\"}}]},\"finish_reason\":\"tool_calls\"}]}\n\n",
        "data: {\"choices\":[],\"usage\":{\"prompt_tokens\":120,\"completion_tokens\":34}}\n\n",
        "data: [DONE]\n\n",
    );

    fn step_of(body: &str, chunk_size: usize) -> Step {
        let mut buffer = SseBuffer::default();
        let mut step = Step::default();
        for piece in body.as_bytes().chunks(chunk_size) {
            for chunk in buffer.feed(piece).expect("a recorded stream parses") {
                step.absorb(chunk);
            }
        }
        assert!(!buffer.has_partial(), "the recorded stream ends on a frame");
        step
    }

    #[test]
    fn a_fragmented_tool_call_is_assembled_into_one_call() {
        let step = step_of(RECORDED, RECORDED.len());
        assert_eq!(step.content, "The disk is full.");
        assert_eq!(step.reasoning, "Let me check");
        assert_eq!(step.usage, Some((120, 34)));
        let calls = step.resolve().expect("a complete call");
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].id, "call_1");
        assert_eq!(calls[0].name, "run_shell_command");
        assert_eq!(calls[0].arguments, r#"{"command":"df -h"}"#);
    }

    /// The bug this parser exists to not have: a frame arriving in pieces. Read
    /// one byte at a time, which splits frames, keys and the multi-byte
    /// character below wherever it likes, and the assembled step has to be the
    /// same one.
    #[test]
    fn a_frame_split_across_reads_is_assembled_the_same_way() {
        let whole = step_of(RECORDED, RECORDED.len());
        for size in [1, 2, 3, 7, 64, RECORDED.len() - 1] {
            assert_eq!(step_of(RECORDED, size), whole, "chunk size {size}");
        }
    }

    #[test]
    fn a_multibyte_character_split_across_reads_survives() {
        let body = "data: {\"choices\":[{\"delta\":{\"content\":\"磁盘已满\"}}]}\n\n";
        let mut buffer = SseBuffer::default();
        let mut step = Step::default();
        for byte in body.as_bytes() {
            for chunk in buffer.feed(std::slice::from_ref(byte)).unwrap() {
                step.absorb(chunk);
            }
        }
        assert_eq!(step.content, "磁盘已满");
    }

    #[test]
    fn a_carriage_return_line_ending_is_accepted() {
        let body = "data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\r\n\r\n";
        let mut buffer = SseBuffer::default();
        let chunks = buffer.feed(body.as_bytes()).unwrap();
        assert_eq!(chunks, vec![Chunk::Content("hi".into())]);
    }

    #[test]
    fn a_comment_or_done_frame_carries_nothing() {
        let mut buffer = SseBuffer::default();
        let chunks = buffer
            .feed(b": keep-alive\n\ndata: [DONE]\n\ndata:{\"choices\":[]}\n\n")
            .unwrap();
        assert!(chunks.is_empty());
        assert!(!buffer.has_partial());
    }

    #[test]
    fn a_stream_that_ended_mid_frame_is_not_a_completed_step() {
        let mut buffer = SseBuffer::default();
        buffer.feed(b"data: {\"choices\":[{\"delta\":{\"cont").unwrap();
        assert!(buffer.has_partial());
    }

    /// The reason no upstream body is ever kept. This one is a real 401 body,
    /// and it is what must not reach a log, an audit row or an item.
    #[test]
    fn a_refusal_carries_a_code_and_never_the_endpoint_body() {
        let e = UpstreamError::from_status(401);
        assert_eq!(e.as_str(), "auth");
        let echoed = "Incorrect API key provided: sk-live-abcdef. You can find your API key at…";
        assert!(!e.to_string().contains("sk-live"));
        assert!(!format!("{e:?}").contains(echoed));
        assert_eq!(UpstreamError::from_status(404).as_str(), "not_found");
        assert_eq!(UpstreamError::from_status(429).as_str(), "rate_limited");
        assert_eq!(UpstreamError::from_status(522).as_str(), "unavailable");
    }

    #[test]
    fn an_in_band_error_is_unavailable_rather_than_a_parsed_choice() {
        let mut buffer = SseBuffer::default();
        let err = buffer
            .feed(b"data: {\"error\":{\"message\":\"sk-live-abcdef is not valid\"}}\n\n")
            .expect_err("an in-band error ends the stream");
        assert_eq!(err.as_str(), "unavailable");
    }

    #[test]
    fn a_call_with_no_id_or_no_name_is_refused() {
        let mut step = Step::default();
        step.absorb(Chunk::ToolCall {
            index: 0,
            id: None,
            name: Some("read_file".into()),
            arguments: "{}".into(),
        });
        assert_eq!(step.resolve(), Err(UpstreamError::Shape));

        let mut step = Step::default();
        step.absorb(Chunk::ToolCall {
            index: 0,
            id: Some("call_1".into()),
            name: Some("read_file".into()),
            arguments: "not json".into(),
        });
        assert_eq!(step.resolve(), Err(UpstreamError::Shape));
    }

    /// An index the stream skipped leaves a hole, and a hole is refused rather
    /// than quietly dropped or reordered.
    #[test]
    fn a_skipped_tool_call_index_is_refused() {
        let mut step = Step::default();
        step.absorb(Chunk::ToolCall {
            index: 1,
            id: Some("call_2".into()),
            name: Some("read_file".into()),
            arguments: "{}".into(),
        });
        assert_eq!(step.calls.len(), 2);
        assert_eq!(step.resolve(), Err(UpstreamError::Shape));
    }

    #[test]
    fn a_call_with_no_arguments_is_an_object_not_a_missing_field() {
        let mut step = Step::default();
        step.absorb(Chunk::ToolCall {
            index: 0,
            id: Some("call_1".into()),
            name: Some("read_file".into()),
            arguments: String::new(),
        });
        assert!(step.resolve().is_ok());
    }

    #[test]
    fn the_request_says_one_call_at_a_time_and_asks_for_usage() {
        let client = Client {
            url: "http://127.0.0.1:11434/v1/chat/completions".into(),
            model: "qwen3".into(),
            api_key: None,
        };
        let body = client.body(&[json!({"role": "user", "content": "hi"})], &[]);
        assert_eq!(body["parallel_tool_calls"], json!(false));
        assert_eq!(body["tool_choice"], json!("auto"));
        assert_eq!(body["stream"], json!(true));
        assert_eq!(body["stream_options"]["include_usage"], json!(true));
        assert_eq!(body["model"], json!("qwen3"));
    }
}
