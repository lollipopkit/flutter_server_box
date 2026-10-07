//! The backend of an example desk app (`kind: wasm`, docs/dev/desk-sys.md):
//! `status` answers the machine's name, uptime and CPU use from the agent's
//! sample,
//! `who` runs `who` as the calling account (needs `exec` and the shell).

use serde_json::{Value, json};

#[link(wasm_import_module = "sbm")]
unsafe extern "C" {
    fn host(ptr: *const u8, len: usize) -> u64;
}

/// Memory the agent writes a request or an answer into; never freed (one
/// instance per call).
#[unsafe(no_mangle)]
pub extern "C" fn sbm_alloc(len: usize) -> *mut u8 {
    let mut buf = Vec::<u8>::with_capacity(len);
    let ptr = buf.as_mut_ptr();
    std::mem::forget(buf);
    ptr
}

fn give(value: &Value) -> u64 {
    let bytes = serde_json::to_vec(value).unwrap_or_default().into_boxed_slice();
    let len = bytes.len() as u64;
    let ptr = Box::into_raw(bytes) as *mut u8 as u64;
    (ptr << 32) | len
}

unsafe fn take(packed: u64) -> Value {
    let (ptr, len) = ((packed >> 32) as usize as *const u8, (packed & 0xffff_ffff) as usize);
    let bytes = unsafe { std::slice::from_raw_parts(ptr, len) };
    serde_json::from_slice(bytes).unwrap_or(Value::Null)
}

fn call_host(name: &str, args: Value) -> Result<Value, String> {
    let request = serde_json::to_vec(&json!({ "fn": name, "args": args })).unwrap_or_default();
    let reply = unsafe { take(host(request.as_ptr(), request.len())) };
    match reply.get("error") {
        Some(e) => Err(e.as_str().unwrap_or("failed").to_string()),
        None => Ok(reply.get("ok").cloned().unwrap_or(Value::Null)),
    }
}

fn handle(request: &Value) -> Result<Value, String> {
    match request["method"].as_str() {
        Some("status") => {
            let m = call_host("status", Value::Null)?;
            Ok(json!({ "uptime": m.get("uptime"), "cpu": m.get("cpu_usage"), "host": m.get("server_name") }))
        }
        Some("who") => {
            let out = call_host("exec", json!({ "cmd": "who" }))?;
            Ok(json!({ "who": out["stdout"] }))
        }
        _ => Err("unknownMethod".into()),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn sbm_call(ptr: *const u8, len: usize) -> u64 {
    let bytes = unsafe { std::slice::from_raw_parts(ptr, len) };
    let request: Value = serde_json::from_slice(bytes).unwrap_or(Value::Null);
    give(&match handle(&request) {
        Ok(v) => json!({ "ok": v }),
        Err(e) => json!({ "error": e }),
    })
}
