//! Local inference's backend (`sbm_parser::inference`): the machine read by
//! the probe; which engine runs here; llmfit's models for it (its release
//! fetched into the app's own folder, checked by the SHA-256 compiled in);
//! MLX installed there and served by a launchd job of the account; Ollama's
//! models through its API on loopback. The container engines are the
//! agent's stacks: their state is read from it.

wit_bindgen::generate!({ path: ["../../wit", "wit"], world: "serverbox:inference/inference", generate_all });

use exports::serverbox::inference::api::{
    self, Candidate, Deployed, EngineFit, Gpu, Hardware, Mlx, MlxService, Ollama, OllamaModel, Overview, Recommendation,
};
use exports::serverbox::inference::jobs;
use sbm::app::http::{self, Request};
use sbm::app::types::Error;
use sbm::app::{agent, host, job};
use sbm_parser::inference::{self as model};
use sbm_parser::script::shell_quote_unix as quote;
use serde_json::{Value, json};
use serverbox::inference::types::Engine;

struct App;

/// The deployed Ollama engine's stack.
const OLLAMA_STACK: &str = "ollama.ollama";
/// Where Ollama's own install listens.
const NATIVE: &str = "http://127.0.0.1:11434";
/// How many models each engine is offered.
const LIMIT: usize = 12;

fn engine(e: model::Engine) -> Engine {
    match e {
        model::Engine::Ollama => Engine::Ollama,
        model::Engine::LlamaCpp => Engine::Llamacpp,
        model::Engine::Vllm => Engine::Vllm,
        model::Engine::Sglang => Engine::Sglang,
        model::Engine::Mlx => Engine::Mlx,
    }
}

fn name<T: serde::Serialize>(v: T) -> String {
    serde_json::to_value(v).ok().and_then(|v| v.as_str().map(str::to_string)).unwrap_or_default()
}

fn text(b: &[u8]) -> String {
    String::from_utf8_lossy(b).into_owned()
}

fn hardware() -> Result<model::Hardware, Error> {
    let out = host::exec(model::probe_command(), None)?;
    Ok(model::parse_probe(&text(&out.stdout)))
}

/// The app's own folder for [part] (`mlx`, `llmfit-<version>`).
fn own(part: &str) -> Result<String, Error> {
    Ok(format!("{}/{part}", host::data_dir()?))
}

fn mlx_dir() -> Result<String, Error> {
    own("mlx")
}

fn llmfit_dir() -> Result<String, Error> {
    own(&format!("llmfit-{}", model::LLMFIT_VERSION))
}

/// A JSON request to [url] on loopback; its JSON answer.
fn call(method: &str, url: &str, body: Option<Value>, timeout_secs: u32) -> Result<Value, Error> {
    let r = http::fetch(&Request {
        method: method.into(),
        url: url.into(),
        headers: vec![("content-type".into(), "application/json".into())],
        body: body.map(|b| b.to_string().into_bytes()),
        timeout_secs,
    })?;
    match r.status {
        200..=299 => Ok(serde_json::from_slice(&r.body).unwrap_or(Value::Null)),
        404 => Err(Error::NotFound("notFound".into())),
        s => Err(Error::Unavailable(format!("HTTP {s}"))),
    }
}

fn ollama_version(base: &str) -> Option<String> {
    call("GET", &format!("{base}/api/version"), None, 5).ok()?["version"].as_str().map(str::to_string)
}

/// The deployed engine's address, when it is set up.
fn deployed_ollama(stacks: &[agent::StackState]) -> Option<String> {
    let s = stacks.iter().find(|s| s.id == OLLAMA_STACK && s.state == "installed")?;
    Some(format!("http://127.0.0.1:{}", s.llm_port?))
}

/// Every Ollama answering here: the deployed one, and the machine's own on
/// its default port when that is another.
fn ollamas(stacks: &[agent::StackState]) -> Vec<Ollama> {
    let mut out = Vec::new();
    let deployed = deployed_ollama(stacks);
    if let Some(url) = &deployed {
        out.push(Ollama { id: OLLAMA_STACK.into(), url: url.clone(), version: ollama_version(url) });
    }
    if deployed.as_deref() != Some(NATIVE)
        && let Some(version) = ollama_version(NATIVE)
    {
        out.push(Ollama { id: "native".into(), url: NATIVE.into(), version: Some(version) });
    }
    out
}

fn base_of(instance: &str) -> Result<String, Error> {
    ollamas(&agent::stacks())
        .into_iter()
        .find(|o| o.id == instance)
        .map(|o| o.url)
        .ok_or_else(|| Error::NotFound("unknownInstance".into()))
}

fn mlx_service() -> Result<model::MlxService, Error> {
    let out = host::exec(&model::mlx_status_command(), None)?;
    Ok(model::parse_mlx_status(&text(&out.stdout)))
}

fn mlx_installed() -> Result<bool, Error> {
    Ok(host::exec(&format!("test -x {}/venv/bin/mlx_lm.server", quote(&mlx_dir()?)), None)?.status == 0)
}

/// llmfit's models for [hw]: its release fetched and unpacked first when it
/// is not there.
fn llmfit(hw: &model::Hardware, query: &model::RecommendQuery) -> Result<Vec<model::LlmfitModel>, Error> {
    let args = model::recommend_args(hw, query).map_err(|e| Error::InvalidArgument(e.into()))?;
    let dir = llmfit_dir()?;
    if host::exec(&format!("test -x {}/llmfit", quote(&dir)), None)?.status != 0 {
        let asset = model::llmfit_asset(&hw.os, &hw.arch).ok_or_else(|| Error::Unavailable(format!("llmfit\nno release for {} {}", hw.os, hw.arch)))?;
        let archive = http::download(&model::llmfit_url(asset), asset.sha256, &format!("llmfit-{}.tar.gz", model::LLMFIT_VERSION))?;
        let out = host::exec(&model::llmfit_unpack_script(&archive, &dir), None)?;
        if out.status != 0 {
            return Err(Error::Unavailable(format!("llmfit\n{}", text(&out.stderr).trim())));
        }
    }
    let out = host::exec(&model::llmfit_command(&dir, &args), None)?;
    if out.status != 0 {
        return Err(Error::Unavailable(format!("llmfit\nexited with {}: {}", out.status, text(&out.stderr).trim())));
    }
    model::parse_recommend(&text(&out.stdout)).map(|r| r.models).map_err(|e| Error::Unavailable(format!("llmfit\n{e}")))
}

impl api::Guest for App {
    fn view() -> Result<Overview, Error> {
        let hw = hardware()?;
        let stacks = agent::stacks();
        let engines = model::engines(&hw)
            .into_iter()
            .map(|f| {
                let stack = f.engine.app().map(str::to_string);
                let deployed = stack.as_deref().and_then(|id| stacks.iter().find(|s| s.id == id)).map(|s| Deployed {
                    state: s.state.clone(),
                    stopped: s.stopped,
                    health: s.health.clone(),
                });
                EngineFit { engine: engine(f.engine), backend: name(f.backend), blocked: f.blocked, cpu_because: f.cpu_because, stack, deployed }
            })
            .collect();
        let mlx = if hw.os == "darwin" {
            let svc = mlx_service()?;
            Some(Mlx {
                installed: mlx_installed()?,
                version: model::MLX_LM_VERSION.into(),
                service: MlxService { model: svc.model, port: svc.port, running: svc.running },
            })
        } else {
            None
        };
        Ok(Overview {
            hardware: Hardware {
                os: hw.os.clone(),
                arch: hw.arch.clone(),
                memory_mib: hw.memory_mib,
                gpus: hw.gpus.iter().map(|g| Gpu { vendor: g.vendor.clone(), name: g.name.clone(), memory_mib: g.memory_mib, compute: g.compute }).collect(),
                docker: hw.docker,
                nvidia_containers: hw.nvidia_containers,
            },
            engines,
            mlx,
            ollama: ollamas(&stacks),
            llmfit_version: model::LLMFIT_VERSION.into(),
        })
    }

    fn recommend(use_case: Option<String>, all_publishers: bool) -> Result<Recommendation, Error> {
        let hw = hardware()?;
        let models = llmfit(&hw, &model::RecommendQuery { use_case })?;
        let mut engines = Vec::new();
        let mut candidates = Vec::new();
        for f in model::engines(&hw).into_iter().filter(|f| f.blocked.is_none()) {
            engines.push(engine(f.engine));
            for c in model::candidates(f.engine, f.backend, &hw, &models, all_publishers, LIMIT) {
                candidates.push(Candidate {
                    engine: engine(c.engine),
                    name: c.name,
                    setting: c.setting,
                    fit: c.fit,
                    score: c.score,
                    params_b: c.params_b,
                    memory_gib: c.memory_gib,
                    tokens_per_second: c.tokens_per_second,
                    context_length: c.context_length,
                    license: c.license,
                });
            }
        }
        Ok(Recommendation { engines, candidates })
    }

    fn ollama_models(instance: String) -> Result<Vec<OllamaModel>, Error> {
        let base = base_of(&instance)?;
        let tags = call("GET", &format!("{base}/api/tags"), None, 10)?;
        let ps = call("GET", &format!("{base}/api/ps"), None, 10).unwrap_or(Value::Null);
        let loaded: Vec<&str> = ps["models"].as_array().into_iter().flatten().filter_map(|m| m["name"].as_str()).collect();
        Ok(tags["models"]
            .as_array()
            .into_iter()
            .flatten()
            .filter_map(|m| {
                let name = m["name"].as_str()?.to_string();
                Some(OllamaModel {
                    loaded: loaded.contains(&name.as_str()),
                    size: m["size"].as_u64().unwrap_or(0),
                    parameter_size: m["details"]["parameter_size"].as_str().map(str::to_string),
                    quantization: m["details"]["quantization_level"].as_str().map(str::to_string),
                    name,
                })
            })
            .collect())
    }

    fn ollama_delete(instance: String, model_name: String) -> Result<(), Error> {
        if !model::valid_model(&model_name) {
            return Err(Error::InvalidArgument("invalidModel".into()));
        }
        let base = base_of(&instance)?;
        call("DELETE", &format!("{base}/api/delete"), Some(json!({ "model": model_name })), 30).map(|_| ())
    }

    fn mlx_start(model_ref: String, port: u16) -> Result<(), Error> {
        if !model::valid_model(&model_ref) || model_ref.contains(':') {
            return Err(Error::InvalidArgument("invalidModel".into()));
        }
        if port < 1024 {
            return Err(Error::InvalidArgument("invalidPort".into()));
        }
        if !mlx_installed()? {
            return Err(Error::FailedPrecondition("notInstalled".into()));
        }
        // The models' folder: the Hugging Face cache vLLM and SGLang share.
        let hf_home = format!("{}/models/huggingface", agent::shared_dir());
        host::exec(&format!("mkdir -p {}", quote(&hf_home)), None)?;
        let plist = model::mlx_plist(&mlx_dir()?, &model_ref, port, &hf_home);
        let out = host::exec(&model::mlx_start_script(&plist), None)?;
        if out.status != 0 {
            return Err(Error::Unavailable(format!("launchctl\n{}", text(&out.stderr).trim())));
        }
        agent::models_changed();
        Ok(())
    }

    fn mlx_stop() -> Result<(), Error> {
        host::exec(&model::mlx_stop_script(), None)?;
        agent::models_changed();
        Ok(())
    }
}

impl jobs::Guest for App {
    fn mlx_install() -> Result<(), Error> {
        if !hardware()?.apple_silicon() {
            return Err(Error::FailedPrecondition("needsAppleSilicon".into()));
        }
        match job::run(&model::mlx_install_script(&mlx_dir()?))? {
            0 => Ok(()),
            n => Err(Error::Internal(format!("exited with {n}"))),
        }
    }

    fn ollama_pull(instance: String, model_name: String) -> Result<(), Error> {
        if !model::valid_model(&model_name) {
            return Err(Error::InvalidArgument("invalidModel".into()));
        }
        let base = base_of(&instance)?;
        let (status, lines) = http::fetch_lines(&Request {
            method: "POST".into(),
            url: format!("{base}/api/pull"),
            headers: vec![("content-type".into(), "application/json".into())],
            body: Some(json!({ "model": model_name, "stream": true }).to_string().into_bytes()),
            timeout_secs: 0,
        })?;
        if !(200..300).contains(&status) {
            return Err(Error::Unavailable(format!("HTTP {status}")));
        }
        // One line per step, and per tenth of a download.
        let (mut said, mut last) = (String::new(), String::new());
        while let Some(line) = lines.next()? {
            let Ok(v) = serde_json::from_str::<Value>(&line) else { continue };
            if let Some(e) = v["error"].as_str() {
                return Err(Error::Unavailable(e.into()));
            }
            let status = v["status"].as_str().unwrap_or_default().to_string();
            let tenth = match (v["completed"].as_u64(), v["total"].as_u64()) {
                (Some(c), Some(t)) if t > 0 => format!(" {}%", c * 100 / t / 10 * 10),
                _ => String::new(),
            };
            let now = format!("{status}{tenth}");
            if now != said {
                job::line(&now);
                said = now;
            }
            last = status;
        }
        if last == "success" { Ok(()) } else { Err(Error::Unavailable(format!("ended at: {last}"))) }
    }
}

export!(App);
