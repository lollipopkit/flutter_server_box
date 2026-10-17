//! Local inference: what this machine can run a language model with, and
//! which models fit it.
//!
//! Five engines: Ollama, llama.cpp, vLLM and SGLang run in containers on
//! Linux (the agent deploys them as stacks); MLX runs natively on Apple
//! Silicon. [`probe_command`] reads what decides between them (GPUs with their
//! memory and compute capability, the container runtime's GPU support),
//! [`engines`] orders them for the machine with a reason for each one that
//! cannot run, and llmfit (`github.com/AlexsJones/llmfit`, run as a pinned
//! release, [`LLMFIT_ASSETS`]) scores its model catalog against the hardware:
//! [`recommend_args`], [`parse_recommend`], then [`candidates`] keeps what an
//! engine can load and says how it names the model ([`ModelRef`]).
//!
//! llmfit labels a model with one runtime and lists every repository it
//! knows (GGUF, MLX and plain weights alike), so what an engine can load is
//! decided here from the repository and its sources, and vLLM's memory from
//! the weights' own format ([`vllm_memory_gib`]).

use serde::{Deserialize, Serialize};

/// An inference engine.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Engine {
    Ollama,
    #[serde(rename = "llamacpp")]
    LlamaCpp,
    Vllm,
    Sglang,
    Mlx,
}

impl Engine {
    pub const ALL: [Engine; 5] = [Engine::Ollama, Engine::LlamaCpp, Engine::Vllm, Engine::Sglang, Engine::Mlx];

    /// The catalog app that runs it (`store/apps/<id>`); MLX runs natively.
    pub fn app(self) -> Option<&'static str> {
        match self {
            Engine::Ollama => Some("ollama.ollama"),
            Engine::LlamaCpp => Some("ggml.llama_cpp"),
            Engine::Vllm => Some("vllm.vllm"),
            Engine::Sglang => Some("sglang.sglang"),
            Engine::Mlx => None,
        }
    }
}

/// What does the computing.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Backend {
    Cuda,
    Rocm,
    Vulkan,
    Metal,
    Cpu,
}

/// A GPU as the probe read it.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Gpu {
    /// `nvidia`, `amd`, `intel` or `apple`.
    pub vendor: String,
    pub name: String,
    /// Its own memory; for Apple Silicon, the unified memory.
    pub memory_mib: Option<u64>,
    /// NVIDIA's compute capability (`7.5`), as major × 10 + minor.
    pub compute: Option<u32>,
}

/// What decides which engine runs here.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Hardware {
    /// `uname -s` lowercased: `linux`, `darwin`, …
    pub os: String,
    /// `uname -m`: `x86_64`, `aarch64`, `arm64`.
    pub arch: String,
    pub memory_mib: u64,
    pub gpus: Vec<Gpu>,
    /// Docker answers.
    pub docker: bool,
    /// Docker can hand a container NVIDIA GPUs (the NVIDIA runtime or a CDI
    /// spec).
    pub nvidia_containers: bool,
    /// `/dev/kfd` and `/dev/dri`: ROCm devices to pass through.
    pub rocm_devices: bool,
    /// `/dev/dri`: a render node for Vulkan.
    pub dri: bool,
    /// A Python 3.11+ virtual environment can be made (`uv`, or `python3`
    /// new enough), which MLX needs.
    pub python: bool,
    /// Ollama's own install (`ollama` on the `PATH`): what runs it on a Mac.
    #[serde(default)]
    pub ollama: bool,
}

impl Hardware {
    pub fn apple_silicon(&self) -> bool {
        self.os == "darwin" && matches!(self.arch.as_str(), "arm64" | "aarch64")
    }

    fn nvidia(&self) -> Option<&Gpu> {
        self.gpus.iter().filter(|g| g.vendor == "nvidia").max_by_key(|g| g.memory_mib)
    }

    fn amd(&self) -> Option<&Gpu> {
        self.gpus.iter().filter(|g| g.vendor == "amd").max_by_key(|g| g.memory_mib)
    }

    /// The memory a model's weights may take on the best GPU (or in RAM).
    pub fn model_memory_mib(&self) -> u64 {
        if self.apple_silicon() {
            // Metal may wire about 70 % of unified memory by default.
            return self.memory_mib * 7 / 10;
        }
        self.gpus.iter().filter(|g| g.vendor != "intel").filter_map(|g| g.memory_mib).max().unwrap_or(self.memory_mib)
    }
}

/// Whether and how an engine runs on the machine.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EngineFit {
    pub engine: Engine,
    pub backend: Backend,
    /// `None` when it runs; otherwise why not, a code the client words:
    /// `needsLinux`, `needsAppleSilicon`, `needsDocker`, `needsGpu`,
    /// `needsPython` (MLX: `uv` or Python 3.11), `needsOllamaApp` (a Mac
    /// without Ollama's own install), `needsNvidia`,
    /// `needsGpuContainers` (Docker cannot hand it the GPU:
    /// the NVIDIA Container Toolkit), `gpuTooOld` (compute capability),
    /// `gpuTooSmall`.
    pub blocked: Option<String>,
    /// Why it runs without the GPU there is: `needsGpuContainers`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cpu_because: Option<String>,
}

/// vLLM and SGLang want a datacentre-class card: at least this much memory.
const SERVING_MIN_MIB: u64 = 8 * 1024;

/// Every engine, the ones that run first, in the order worth choosing them
/// for this machine.
/// The compute capability (major·10 + minor) SGLang's image has kernels for.
const SGLANG_MIN_COMPUTE: u32 = 80;

pub fn engines(hw: &Hardware) -> Vec<EngineFit> {
    let fit = |engine, backend, blocked: Option<&str>| EngineFit { engine, backend, blocked: blocked.map(str::to_owned), cpu_because: None };
    let linux = hw.os == "linux";
    // What a container gets on Linux.
    let container = |engine: Engine| -> EngineFit {
        if !linux {
            return fit(engine, Backend::Cpu, Some("needsLinux"));
        }
        if !hw.docker {
            return fit(engine, Backend::Cpu, Some("needsDocker"));
        }
        if hw.nvidia().is_some() {
            if hw.nvidia_containers {
                return fit(engine, Backend::Cuda, None);
            }
            // Docker cannot hand it the GPU: on the CPU, said why.
            return EngineFit { cpu_because: Some("needsGpuContainers".into()), ..fit(engine, Backend::Cpu, None) };
        }
        if hw.amd().is_some() && hw.rocm_devices {
            return fit(engine, Backend::Rocm, None);
        }
        fit(engine, Backend::Cpu, None)
    };
    // vLLM and SGLang: a GPU of their kind, big enough and new enough.
    // SGLang's release image has no kernels for Turing (flashinfer's
    // RMSNorm: "no kernel image is available" on a Tesla T10, 7.5), so
    // Ampere; vLLM's still serves Volta.
    let serving = |engine: Engine, min_compute: u32| -> EngineFit {
        let base = container(engine);
        if base.blocked.is_some() {
            return base;
        }
        if let Some(why) = &base.cpu_because {
            return fit(engine, Backend::Cuda, Some(why));
        }
        // The catalog's builds are CUDA's: ROCm's differ by GPU family.
        let gpu = match base.backend {
            Backend::Cuda => hw.nvidia().expect("CUDA from an NVIDIA GPU"),
            Backend::Rocm => return fit(engine, Backend::Rocm, Some("needsNvidia")),
            _ => return fit(engine, Backend::Cpu, Some("needsGpu")),
        };
        if gpu.compute.is_some_and(|c| c < min_compute) {
            return fit(engine, base.backend, Some("gpuTooOld"));
        }
        if gpu.memory_mib.is_some_and(|m| m < SERVING_MIN_MIB) {
            return fit(engine, base.backend, Some("gpuTooSmall"));
        }
        base
    };
    let ollama = || {
        if hw.os == "darwin" {
            // Ollama's own app, on the machine: found, not deployed.
            return fit(Engine::Ollama, Backend::Metal, (!hw.ollama).then_some("needsOllamaApp"));
        }
        container(Engine::Ollama)
    };
    let llama_cpp = || {
        let base = container(Engine::LlamaCpp);
        // An Intel or other GPU with a render node: Vulkan.
        if base.blocked.is_none() && base.backend == Backend::Cpu && hw.dri && hw.gpus.iter().any(|g| g.vendor == "intel") {
            return fit(Engine::LlamaCpp, Backend::Vulkan, None);
        }
        base
    };
    let mlx = || match (hw.apple_silicon(), hw.python) {
        (false, _) => fit(Engine::Mlx, Backend::Metal, Some("needsAppleSilicon")),
        (true, false) => fit(Engine::Mlx, Backend::Metal, Some("needsPython")),
        (true, true) => fit(Engine::Mlx, Backend::Metal, None),
    };
    let mut all = if hw.apple_silicon() {
        vec![mlx(), ollama(), llama_cpp(), serving(Engine::Vllm, 70), serving(Engine::Sglang, SGLANG_MIN_COMPUTE)]
    } else {
        let vllm = serving(Engine::Vllm, 70);
        if vllm.blocked.is_none() {
            vec![vllm, serving(Engine::Sglang, SGLANG_MIN_COMPUTE), llama_cpp(), ollama(), mlx()]
        } else {
            vec![llama_cpp(), ollama(), vllm, serving(Engine::Sglang, SGLANG_MIN_COMPUTE), mlx()]
        }
    };
    // Stable: the runnable ones first, each group in the order above.
    all.sort_by_key(|f| f.blocked.is_some());
    all
}

/// Reads what [`Hardware`] needs, one `key=value` line each. `sh`.
pub fn probe_command() -> &'static str {
    r#"echo "os=$(uname -s)"
echo "arch=$(uname -m)"
if [ -r /proc/meminfo ]; then awk '/^MemTotal:/ {print "memory_kib=" $2}' /proc/meminfo; fi
if [ "$(uname -s)" = Darwin ]; then
  echo "memory_bytes=$(sysctl -n hw.memsize 2>/dev/null)"
  echo "apple_chip=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
fi
command -v ollama >/dev/null 2>&1 && echo "ollama=1"
if command -v uv >/dev/null 2>&1 || python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>/dev/null; then
  echo "python=1"
fi
PATH="$PATH:/usr/lib/wsl/lib"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,memory.total,compute_cap --format=csv,noheader,nounits 2>/dev/null | sed 's/^/nvidia=/'
fi
if command -v rocm-smi >/dev/null 2>&1; then
  rocm-smi --showproductname --showmeminfo vram --json 2>/dev/null | tr -d '\n' | sed 's/^/rocm=/'; echo
fi
for d in /sys/class/drm/card[0-9]*/device; do
  [ -r "$d/vendor" ] || continue
  echo "drm=$(cat "$d/vendor") $(cat "$d/mem_info_vram_total" 2>/dev/null || echo 0)"
done
[ -e /dev/kfd ] && echo "kfd=1"
[ -e /dev/dri ] && echo "dri=1"
if docker info >/dev/null 2>&1; then
  echo "docker=1"
  docker info --format '{{json .Runtimes}}' 2>/dev/null | grep -q '"nvidia"' && echo "nvidia_runtime=1"
  for f in /etc/cdi/nvidia*.yaml /etc/cdi/nvidia*.json /var/run/cdi/nvidia*.yaml /var/run/cdi/nvidia*.json; do
    [ -e "$f" ] && echo "nvidia_cdi=1" && break
  done
fi
true"#
}

/// [`probe_command`]'s output as [`Hardware`].
pub fn parse_probe(out: &str) -> Hardware {
    let mut hw = Hardware::default();
    let mut apple_chip = None;
    let mut drm_amd: Vec<u64> = Vec::new();
    let mut drm_intel = false;
    let mut nvidia_runtime = false;
    for line in out.lines() {
        let Some((key, value)) = line.split_once('=') else { continue };
        let value = value.trim();
        match key {
            "os" => hw.os = value.to_ascii_lowercase(),
            "arch" => hw.arch = value.to_string(),
            "memory_kib" => hw.memory_mib = value.parse::<u64>().map(|k| k / 1024).unwrap_or(hw.memory_mib),
            "memory_bytes" => hw.memory_mib = value.parse::<u64>().map(|b| b / 1024 / 1024).unwrap_or(hw.memory_mib),
            "apple_chip" if !value.is_empty() => apple_chip = Some(value.to_string()),
            "nvidia" => {
                let parts: Vec<&str> = value.split(',').map(str::trim).collect();
                if let [name, memory, compute, ..] = parts.as_slice() {
                    hw.gpus.push(Gpu {
                        vendor: "nvidia".into(),
                        name: name.to_string(),
                        memory_mib: memory.parse().ok(),
                        compute: parse_compute(compute),
                    });
                }
            }
            "drm" => {
                let mut parts = value.split_whitespace();
                let vendor = parts.next().unwrap_or_default();
                let vram: u64 = parts.next().and_then(|v| v.parse().ok()).unwrap_or(0);
                match vendor {
                    "0x1002" => drm_amd.push(vram / 1024 / 1024),
                    "0x8086" => drm_intel = true,
                    _ => {}
                }
            }
            "kfd" => hw.rocm_devices = true,
            "dri" => hw.dri = true,
            "docker" => hw.docker = true,
            "python" => hw.python = true,
            "ollama" => hw.ollama = true,
            "nvidia_runtime" | "nvidia_cdi" => nvidia_runtime = true,
            _ => {}
        }
    }
    hw.nvidia_containers = nvidia_runtime;
    hw.rocm_devices &= hw.dri;
    for vram in drm_amd {
        hw.gpus.push(Gpu { vendor: "amd".into(), name: "AMD GPU".into(), memory_mib: (vram > 0).then_some(vram), compute: None });
    }
    if drm_intel {
        hw.gpus.push(Gpu { vendor: "intel".into(), name: "Intel GPU".into(), memory_mib: None, compute: None });
    }
    if hw.apple_silicon() {
        hw.gpus.push(Gpu {
            vendor: "apple".into(),
            name: apple_chip.unwrap_or_else(|| "Apple Silicon".into()),
            memory_mib: Some(hw.memory_mib),
            compute: None,
        });
    }
    hw
}

fn parse_compute(s: &str) -> Option<u32> {
    let (major, minor) = s.split_once('.')?;
    Some(major.parse::<u32>().ok()? * 10 + minor.parse::<u32>().ok()?)
}

// ---------------------------------------------------------------------------
// llmfit

/// The llmfit release the agent runs, and each platform's archive by its
/// SHA-256 (the release's own `.sha256` files).
pub const LLMFIT_VERSION: &str = "1.1.16";

pub struct LlmfitAsset {
    /// `uname -s`/`uname -m` as [`Hardware`] has them.
    pub os: &'static str,
    pub arch: &'static [&'static str],
    pub file: &'static str,
    pub sha256: &'static str,
}

pub const LLMFIT_ASSETS: &[LlmfitAsset] = &[
    LlmfitAsset {
        os: "linux",
        arch: &["x86_64", "amd64"],
        file: "llmfit-v1.1.16-x86_64-unknown-linux-musl.tar.gz",
        sha256: "9c974f97ac72371d61044eb22ddabff27e9393f681f1c141dbe467699fe3bc48",
    },
    LlmfitAsset {
        os: "linux",
        arch: &["aarch64", "arm64"],
        file: "llmfit-v1.1.16-aarch64-unknown-linux-musl.tar.gz",
        sha256: "36c8fdd82e329733633f6236e174961b51beaa3f9d2f4b5ada1d43a4a2dd93cc",
    },
    LlmfitAsset {
        os: "darwin",
        arch: &["arm64", "aarch64"],
        file: "llmfit-v1.1.16-aarch64-apple-darwin.tar.gz",
        sha256: "e5a558de2af332aa2a75547086c8983fc2f43c7c9a966fcc20d9ce4108ec6886",
    },
    LlmfitAsset {
        os: "darwin",
        arch: &["x86_64"],
        file: "llmfit-v1.1.16-x86_64-apple-darwin.tar.gz",
        sha256: "1face5fa683c84b65ecde3c9ba7cb8eb895ec31f0819a3d29861e33312467627",
    },
];

/// The archive for this platform.
pub fn llmfit_asset(os: &str, arch: &str) -> Option<&'static LlmfitAsset> {
    LLMFIT_ASSETS.iter().find(|a| a.os == os && a.arch.contains(&arch))
}

pub fn llmfit_url(asset: &LlmfitAsset) -> String {
    format!("https://github.com/AlexsJones/llmfit/releases/download/v{LLMFIT_VERSION}/{}", asset.file)
}

/// What to ask llmfit for.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RecommendQuery {
    /// `general`, `coding`, `reasoning`, `chat`, `multimodal`, `embedding`.
    #[serde(default)]
    pub use_case: Option<String>,
}

pub const USE_CASES: &[&str] = &["general", "coding", "reasoning", "chat", "multimodal", "embedding"];

/// How many models llmfit is asked for: the engines' filters keep a few of
/// them each.
const RECOMMEND_POOL: usize = 300;

/// `llmfit` arguments for [query] on [hw]. The GPU memory the probe read is
/// passed on (a global option, before the subcommand): llmfit's own
/// detection misses GPUs a container or WSL hides.
pub fn recommend_args(hw: &Hardware, query: &RecommendQuery) -> Result<Vec<String>, &'static str> {
    let mut args = Vec::new();
    if !hw.apple_silicon()
        && let Some(m) = hw.gpus.iter().filter(|g| matches!(g.vendor.as_str(), "nvidia" | "amd")).filter_map(|g| g.memory_mib).max()
    {
        args.extend(["--memory".into(), format!("{m}M")]);
    }
    args.extend(["recommend".to_string(), "--json".into(), "-n".into(), RECOMMEND_POOL.to_string()]);
    if let Some(u) = &query.use_case {
        if !USE_CASES.contains(&u.as_str()) {
            return Err("invalidUseCase");
        }
        args.extend(["--use-case".into(), u.clone()]);
    }
    Ok(args)
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
pub struct Recommend {
    pub models: Vec<LlmfitModel>,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
pub struct GgufSource {
    pub repo: String,
}

/// One model as llmfit scores it (the fields used here).
#[derive(Debug, Clone, PartialEq, Deserialize)]
pub struct LlmfitModel {
    /// The Hugging Face repository.
    pub name: String,
    #[serde(default)]
    pub params_b: Option<f64>,
    #[serde(default)]
    pub fit_level: Option<String>,
    #[serde(default)]
    pub run_mode: Option<String>,
    #[serde(default)]
    pub score: Option<f64>,
    #[serde(default)]
    pub estimated_tps: Option<f64>,
    #[serde(default)]
    pub memory_required_gb: Option<f64>,
    #[serde(default)]
    pub best_quant: Option<String>,
    #[serde(default)]
    pub context_length: Option<u64>,
    #[serde(default)]
    pub license: Option<String>,
    #[serde(default)]
    pub capability_ids: Vec<String>,
    #[serde(default)]
    pub category: Option<String>,
    #[serde(default)]
    pub use_case: Option<String>,
    #[serde(default)]
    pub is_moe: bool,
    #[serde(default)]
    pub gguf_sources: Vec<GgufSource>,
    #[serde(default)]
    pub ollama_name: Option<String>,
    #[serde(default)]
    pub release_date: Option<String>,
}

pub fn parse_recommend(json: &str) -> Result<Recommend, String> {
    serde_json::from_str(json).map_err(|e| e.to_string())
}

/// How an engine names the model it loads.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", tag = "kind")]
pub enum ModelRef {
    /// A Hugging Face repository the engine downloads (vLLM, SGLang, MLX).
    Hf { repo: String },
    /// A GGUF repository and the quantization in it (`-hf repo:Q4_K_M`).
    Gguf { repo: String, quant: String },
    /// Ollama's own name (`qwen3:8b`), or `hf.co/<gguf repo>:<quant>`.
    Ollama { name: String },
}

impl ModelRef {
    /// The one string the engine's model setting takes.
    pub fn setting(&self) -> String {
        match self {
            ModelRef::Hf { repo } => repo.clone(),
            ModelRef::Gguf { repo, quant } => format!("{repo}:{quant}"),
            ModelRef::Ollama { name } => name.clone(),
        }
    }
}

/// A model one engine can run here.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Candidate {
    pub engine: Engine,
    /// llmfit's name for it: the original repository.
    pub name: String,
    pub model: ModelRef,
    /// What the engine's model setting takes ([`ModelRef::setting`]).
    pub setting: String,
    /// `perfect`, `good`, `marginal`.
    pub fit: String,
    pub score: f64,
    pub params_b: Option<f64>,
    pub memory_gib: Option<f64>,
    /// llmfit's estimate; none for vLLM/SGLang, which it does not model.
    pub tokens_per_second: Option<f64>,
    pub context_length: Option<u64>,
    pub license: Option<String>,
    pub capabilities: Vec<String>,
    pub category: Option<String>,
    pub release_date: Option<String>,
}

/// Who publishes a repository worth offering by default: model makers and
/// the quantizers whose builds engines document.
const PUBLISHERS: &[&str] = &[
    "qwen", "meta-llama", "google", "mistralai", "microsoft", "deepseek-ai", "openai", "ibm-granite", "huggingfacetb",
    "nvidia", "zai-org", "thudm", "moonshotai", "allenai", "tiiuae", "coherelabs", "cohereforai", "liquidai", "baidu",
    "tencent", "internlm", "stepfun-ai", "minimaxai", "ai21labs", "swiss-ai", "ggml-org", "unsloth", "bartowski",
    "lmstudio-community", "mlx-community", "redhatai", "neuralmagic",
];

fn org(repo: &str) -> String {
    repo.split('/').next().unwrap_or_default().to_ascii_lowercase()
}

pub fn known_publisher(repo: &str) -> bool {
    PUBLISHERS.contains(&org(repo).as_str())
}

/// One model's builds alike: the repository's name without its publisher
/// and the build's own words (`-MLX-4bit`, `-GGUF`, `-AWQ`).
fn base_of(repo: &str) -> String {
    let name = repo.rsplit('/').next().unwrap_or(repo).to_ascii_lowercase();
    let words = ["mlx", "gguf", "awq", "gptq", "fp8", "bf16", "fp16", "int4", "int8", "dynamic", "3bit", "4bit", "5bit", "6bit", "8bit", "dwq", "qat"];
    name.split('-').filter(|w| !words.contains(w)).collect::<Vec<_>>().join("-")
}

fn is_gguf(repo: &str) -> bool {
    repo.to_ascii_lowercase().contains("gguf")
}

fn is_mlx(repo: &str) -> bool {
    let l = repo.to_ascii_lowercase();
    org(repo) == "mlx-community" || l.contains("-mlx") || l.contains("mlx-") || l.contains("/mlx")
}

/// Weights vLLM cannot load on CUDA as published: bitsandbytes and NVFP4
/// builds, GGUF and MLX.
fn vllm_loads(repo: &str, compute: Option<u32>) -> bool {
    let l = repo.to_ascii_lowercase();
    if is_gguf(repo) || is_mlx(repo) || l.contains("bnb") || l.contains("nvfp4") || l.contains("exl2") {
        return false;
    }
    // FP8 kernels need Ada (8.9) or newer.
    !(l.contains("fp8") && compute.is_some_and(|c| c < 89))
}

/// Bytes per parameter the repository's weights take.
fn weight_bytes(repo: &str) -> f64 {
    let l = repo.to_ascii_lowercase();
    if ["awq", "gptq", "int4", "w4a16", "4bit"].iter().any(|q| l.contains(q)) {
        0.55
    } else if ["fp8", "int8", "w8a8", "8bit"].iter().any(|q| l.contains(q)) {
        1.05
    } else {
        2.0
    }
}

/// GPU memory vLLM/SGLang need for [repo] at [params_b]: the weights as
/// published, a 4096-token KV cache and the runtime's own.
pub fn vllm_memory_gib(repo: &str, params_b: f64) -> f64 {
    params_b * weight_bytes(repo) * 1.07 + 1.5 + params_b * 0.06
}

/// llama.cpp's quantization from llmfit's choice; anything that is not a
/// GGUF type (`mlx-8bit`) falls back to `Q4_K_M`.
fn gguf_quant(best: Option<&str>) -> String {
    match best {
        Some(q) if (q.starts_with('Q') || q.starts_with("IQ")) && q.len() <= 8 => q.to_string(),
        _ => "Q4_K_M".into(),
    }
}

/// What [engine] can run of llmfit's [models] on [hw] with [backend] (from
/// [`engines`]), best first, at most [limit]. [all_publishers] keeps
/// repositories of anyone.
pub fn candidates(engine: Engine, backend: Backend, hw: &Hardware, models: &[LlmfitModel], all_publishers: bool, limit: usize) -> Vec<Candidate> {
    let budget_gib = hw.model_memory_mib() as f64 / 1024.0;
    // On the CPU (no GPU there, or none Docker can hand over), what fits is
    // RAM's to say, less what the system keeps; llmfit's speed was a GPU's.
    let on_cpu = backend == Backend::Cpu && !hw.gpus.is_empty();
    let ram_gib = (hw.memory_mib as f64 / 1024.0 - 2.0).max(0.0);
    let compute = hw.nvidia().and_then(|g| g.compute);
    let mut out: Vec<Candidate> = Vec::new();
    let mut seen = std::collections::HashSet::new();
    let mut bases = std::collections::HashSet::new();
    for m in models {
        if !all_publishers && !known_publisher(&m.name) {
            continue;
        }
        let fit = m.fit_level.as_deref().unwrap_or("").to_ascii_lowercase().replace(' ', "");
        let gguf = || {
            let repo = if is_gguf(&m.name) { Some(m.name.clone()) } else { m.gguf_sources.first().map(|s| s.repo.clone()) };
            repo.map(|repo| (repo, gguf_quant(m.best_quant.as_deref())))
        };
        let (model, memory_gib, tps, fit) = match engine {
            Engine::LlamaCpp => {
                let Some((repo, quant)) = gguf() else { continue };
                (ModelRef::Gguf { repo, quant }, m.memory_required_gb, m.estimated_tps, fit)
            }
            Engine::Ollama => {
                let model = match (&m.ollama_name, gguf()) {
                    (Some(name), _) => ModelRef::Ollama { name: name.clone() },
                    (None, Some((repo, quant))) => ModelRef::Ollama { name: format!("hf.co/{repo}:{quant}") },
                    _ => continue,
                };
                (model, m.memory_required_gb, m.estimated_tps, fit)
            }
            Engine::Mlx => {
                let l = m.name.to_ascii_lowercase();
                if is_gguf(&m.name) || ["bnb", "awq", "gptq", "nvfp4", "fp8", "exl2"].iter().any(|q| l.contains(q)) {
                    continue;
                }
                (ModelRef::Hf { repo: m.name.clone() }, m.memory_required_gb, m.estimated_tps, fit)
            }
            Engine::Vllm | Engine::Sglang => {
                if !vllm_loads(&m.name, compute) {
                    continue;
                }
                let Some(params) = m.params_b else { continue };
                let need = vllm_memory_gib(&m.name, params);
                // vLLM takes 90 % of the card.
                let room = budget_gib * 0.9;
                if need > room {
                    continue;
                }
                let fit = if need <= room * 0.7 { "perfect" } else { "good" };
                (ModelRef::Hf { repo: m.name.clone() }, Some((need * 100.0).round() / 100.0), None, fit.to_string())
            }
        };
        let (fit, tps) = match (on_cpu, memory_gib) {
            (true, Some(need)) if need <= ram_gib * 0.6 => ("good".to_string(), None),
            (true, Some(need)) if need <= ram_gib => ("marginal".to_string(), None),
            (true, _) => continue,
            (false, _) => (fit, tps),
        };
        if !matches!(fit.as_str(), "perfect" | "good" | "marginal") || !seen.insert(model.setting()) {
            continue;
        }
        // One build per model; MLX's own builds are sorted first below, so
        // keep them all until then.
        if engine != Engine::Mlx && !bases.insert(base_of(&m.name)) {
            continue;
        }
        out.push(Candidate {
            engine,
            name: m.name.clone(),
            setting: model.setting(),
            model,
            fit,
            score: m.score.unwrap_or_default(),
            params_b: m.params_b,
            memory_gib,
            tokens_per_second: tps,
            context_length: m.context_length,
            license: m.license.clone(),
            capabilities: m.capability_ids.clone(),
            category: m.category.clone(),
            release_date: m.release_date.clone(),
        });
    }
    // MLX loads its own builds faster and smaller than the original weights.
    if engine == Engine::Mlx {
        out.sort_by_key(|c| !is_mlx(&c.name));
        out.retain(|c| bases.insert(base_of(&c.name)));
    }
    out.truncate(limit);
    out
}

// ---------------------------------------------------------------------------
// MLX on macOS: mlx-lm's server in a virtual environment of the agent's,
// kept running by launchd as the agent's account.

/// The mlx-lm release installed (PyPI).
pub const MLX_LM_VERSION: &str = "0.32.0";
/// The launchd job's label, and its plist's name in `~/Library/LaunchAgents`.
pub const MLX_LABEL: &str = "dev.serverbox.mlx";

/// Makes the virtual environment in `<dir>/venv` with mlx-lm in it: `uv`
/// when there is one (it fetches a Python 3.12 if it must), else `python3`.
pub fn mlx_install_script(dir: &str) -> String {
    let dir = crate::script::shell_quote_unix(dir);
    format!(
        r#"set -e
mkdir -p {dir}
cd {dir}
if command -v uv >/dev/null 2>&1; then
  uv venv --allow-existing --python 3.12 venv
  uv pip install --python venv/bin/python 'mlx-lm=={MLX_LM_VERSION}'
else
  python3 -m venv venv
  venv/bin/pip install --disable-pip-version-check 'mlx-lm=={MLX_LM_VERSION}'
fi
venv/bin/python -c 'import mlx_lm; print("mlx-lm", mlx_lm.__version__)'"#
    )
}

fn xml(s: &str) -> String {
    s.replace('&', "&amp;").replace('<', "&lt;").replace('>', "&gt;").replace('"', "&quot;")
}

/// The launchd job serving [model] on loopback at [port], its models in
/// [hf_home], its output in `<dir>/server.log`.
pub fn mlx_plist(dir: &str, model: &str, port: u16, hf_home: &str) -> String {
    let arg = |a: &str| format!("    <string>{}</string>\n", xml(a));
    let mut args = String::new();
    for a in [&format!("{dir}/venv/bin/mlx_lm.server"), "--model", model, "--host", "127.0.0.1", "--port", &port.to_string()] {
        args.push_str(&arg(a));
    }
    format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>{MLX_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
{args}  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HF_HOME</key>
    <string>{hf}</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>{log}</string>
  <key>StandardErrorPath</key>
  <string>{log}</string>
</dict>
</plist>
"#,
        hf = xml(hf_home),
        log = xml(&format!("{dir}/server.log")),
    )
}

/// The launchd domain of the agent's account: its GUI session when it has
/// one, else its background one.
const LAUNCHD_DOMAIN: &str = r#"d="gui/$(id -u)"; launchctl print "$d" >/dev/null 2>&1 || d="user/$(id -u)""#;

/// Writes [plist] (from [`mlx_plist`]) as the job's and (re)starts it.
pub fn mlx_start_script(plist: &str) -> String {
    format!(
        r#"set -e
{LAUNCHD_DOMAIN}
p="$HOME/Library/LaunchAgents/{MLX_LABEL}.plist"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$p.part" <<'SBM_MLX_PLIST'
{plist}SBM_MLX_PLIST
mv "$p.part" "$p"
launchctl bootout "$d/{MLX_LABEL}" 2>/dev/null || true
launchctl bootstrap "$d" "$p""#
    )
}

/// Stops the job and removes it, so launchd does not start it again.
pub fn mlx_stop_script() -> String {
    format!(
        r#"{LAUNCHD_DOMAIN}
launchctl bootout "$d/{MLX_LABEL}" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/{MLX_LABEL}.plist"
true"#
    )
}

/// The job's plist and launchd's word on it, apart by a marker line.
pub fn mlx_status_command() -> String {
    format!(
        r#"{LAUNCHD_DOMAIN}
cat "$HOME/Library/LaunchAgents/{MLX_LABEL}.plist" 2>/dev/null
echo "{MLX_STATUS_MARK}"
launchctl print "$d/{MLX_LABEL}" 2>/dev/null | grep -E '^\s*(state|pid) ='
true"#
    )
}

const MLX_STATUS_MARK: &str = "--sbm-mlx-launchd--";

/// The MLX server as [mlx_status_command] found it.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MlxService {
    /// A job is set up: it has a model and a port.
    pub model: Option<String>,
    pub port: Option<u16>,
    pub running: bool,
    pub pid: Option<u32>,
}

pub fn parse_mlx_status(out: &str) -> MlxService {
    let (plist, launchd) = out.split_once(MLX_STATUS_MARK).unwrap_or((out, ""));
    let args: Vec<String> = plist
        .split("<array>")
        .nth(1)
        .and_then(|a| a.split("</array>").next())
        .map(|a| {
            a.split("<string>")
                .skip(1)
                .filter_map(|s| s.split("</string>").next())
                .map(|s| s.replace("&quot;", "\"").replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&"))
                .collect()
        })
        .unwrap_or_default();
    let after = |flag: &str| args.iter().position(|a| a == flag).and_then(|i| args.get(i + 1)).cloned();
    let mut svc = MlxService { model: after("--model"), port: after("--port").and_then(|p| p.parse().ok()), ..Default::default() };
    // The job's own lines come first; nested sections repeat the keys.
    let mut state = None;
    for line in launchd.lines() {
        let Some((k, v)) = line.split_once('=') else { continue };
        match k.trim() {
            "state" if state.is_none() => state = Some(v.trim() == "running"),
            "pid" if svc.pid.is_none() => svc.pid = v.trim().parse().ok(),
            _ => {}
        }
    }
    svc.running = state.unwrap_or(false);
    svc
}

/// A model setting a client sends: a Hugging Face repository, optionally
/// `:QUANT` for GGUF, or an Ollama name. No spaces, quotes or shell syntax,
/// so it can sit in an env file and on a command line.
pub fn valid_model(s: &str) -> bool {
    (1..=200).contains(&s.len())
        && !s.starts_with(['-', '/', '.'])
        && !s.contains("..")
        && s.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'/' | b'-' | b'_' | b'.' | b':'))
}

/// The tool-call parser [engine] needs to answer tool calls (Agent mode's
/// commands) with [model], a Hugging Face repository: by the model's
/// family, in each engine's own names (vLLM `--tool-call-parser` with
/// `--enable-auto-tool-choice`, SGLang `--tool-call-parser`). `None` for an
/// engine that needs none, or a family neither knows: such a model chats
/// but cannot run a task.
pub fn tool_parser(engine: Engine, model: &str) -> Option<&'static str> {
    let m = model.rsplit('/').next().unwrap_or(model).to_ascii_lowercase();
    let has = |p: &str| m.contains(p);
    // (vLLM, SGLang); the more specific family first.
    let (vllm, sglang) = if has("qwen3-coder") || has("qwen3coder") {
        ("qwen3_coder", "qwen3_coder")
    } else if has("qwen") || has("qwq") || has("hermes") {
        ("hermes", if has("hermes") { "hermes" } else { "qwen" })
    } else if has("llama-4") || has("llama4") {
        ("llama4_pythonic", "pythonic")
    } else if has("llama-3") || has("llama3") {
        ("llama3_json", "llama3")
    } else if ["mistral", "ministral", "devstral", "magistral"].iter().any(|f| has(f)) {
        ("mistral", "mistral")
    } else if has("gpt-oss") {
        ("openai", "gpt-oss")
    } else if has("deepseek-v3.1") {
        ("deepseek_v31", "deepseekv31")
    } else if has("deepseek-v3") {
        ("deepseek_v3", "deepseekv3")
    } else if has("glm-4.7") {
        ("glm47", "glm47")
    } else if has("glm-4.5") || has("glm-4.6") {
        ("glm45", "glm45")
    } else if has("kimi-k2") {
        ("kimi_k2", "kimi_k2")
    } else if has("gemma-4") || has("gemma4") {
        ("gemma4", "gemma4")
    } else if has("minimax-m2") {
        ("minimax_m2", "minimax-m2")
    } else {
        return None;
    };
    match engine {
        Engine::Vllm => Some(vllm),
        Engine::Sglang => Some(sglang),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn picks_the_tool_call_parser_by_family() {
        assert_eq!(tool_parser(Engine::Vllm, "Qwen/Qwen3-0.6B"), Some("hermes"));
        assert_eq!(tool_parser(Engine::Sglang, "Qwen/Qwen3-0.6B"), Some("qwen"));
        assert_eq!(tool_parser(Engine::Vllm, "Qwen/Qwen3-Coder-30B-A3B-Instruct"), Some("qwen3_coder"));
        assert_eq!(tool_parser(Engine::Vllm, "meta-llama/Llama-3.1-8B-Instruct"), Some("llama3_json"));
        assert_eq!(tool_parser(Engine::Sglang, "meta-llama/Llama-3.1-8B-Instruct"), Some("llama3"));
        assert_eq!(tool_parser(Engine::Sglang, "openai/gpt-oss-20b"), Some("gpt-oss"));
        assert_eq!(tool_parser(Engine::Vllm, "deepseek-ai/DeepSeek-V3.1"), Some("deepseek_v31"));
        assert_eq!(tool_parser(Engine::Vllm, "google/gemma-3-4b-it"), None);
        assert_eq!(tool_parser(Engine::Ollama, "Qwen/Qwen3-0.6B"), None);
    }

    fn nvidia(memory: u64, compute: u32, containers: bool) -> Hardware {
        Hardware {
            os: "linux".into(),
            arch: "x86_64".into(),
            memory_mib: 32 * 1024,
            gpus: vec![Gpu { vendor: "nvidia".into(), name: "Tesla T10".into(), memory_mib: Some(memory), compute: Some(compute) }],
            docker: true,
            nvidia_containers: containers,
            rocm_devices: false,
            dri: false,
            python: false,
            ollama: false,
        }
    }

    fn order(hw: &Hardware) -> Vec<(Engine, Option<String>)> {
        engines(hw).into_iter().map(|f| (f.engine, f.blocked)).collect()
    }

    #[test]
    fn a_big_nvidia_card_serves_with_vllm_first() {
        let o = order(&nvidia(16384, 86, true));
        assert_eq!(o[0], (Engine::Vllm, None));
        assert_eq!(o[1], (Engine::Sglang, None));
        assert_eq!(o[2], (Engine::LlamaCpp, None));
        assert_eq!(o[4], (Engine::Mlx, Some("needsAppleSilicon".into())));
        assert_eq!(engines(&nvidia(16384, 86, true))[2].backend, Backend::Cuda);
        // A Tesla T10 (Turing): vLLM, not SGLang.
        let o = order(&nvidia(16384, 75, true));
        assert_eq!(o[0], (Engine::Vllm, None));
        assert!(o.contains(&(Engine::Sglang, Some("gpuTooOld".into()))));
    }

    #[test]
    fn without_the_container_toolkit_the_gpu_is_left_out() {
        let f = engines(&nvidia(16384, 75, false));
        assert_eq!((f[0].engine, f[0].backend, f[0].cpu_because.as_deref()), (Engine::LlamaCpp, Backend::Cpu, Some("needsGpuContainers")));
        assert_eq!((f[1].engine, f[1].blocked.as_deref()), (Engine::Ollama, None));
        assert!(f.iter().any(|f| f.engine == Engine::Vllm && f.blocked.as_deref() == Some("needsGpuContainers")));
    }

    #[test]
    fn small_or_old_cards_leave_vllm_out() {
        let o = order(&nvidia(6144, 86, true));
        assert_eq!(o[0].0, Engine::LlamaCpp);
        assert!(o.contains(&(Engine::Vllm, Some("gpuTooSmall".into()))));
        let o = order(&nvidia(16384, 61, true));
        assert!(o.contains(&(Engine::Vllm, Some("gpuTooOld".into()))));
        // SGLang needs Ampere; vLLM Volta.
        let o = order(&nvidia(32768, 70, true));
        assert!(o.contains(&(Engine::Vllm, None)));
        assert!(o.contains(&(Engine::Sglang, Some("gpuTooOld".into()))));
    }

    #[test]
    fn apple_silicon_runs_mlx_then_ollama() {
        let hw = parse_probe("os=Darwin\narch=arm64\nmemory_bytes=68719476736\napple_chip=Apple M5 Pro\npython=1\nollama=1\n");
        assert!(hw.apple_silicon());
        assert_eq!(hw.gpus[0].name, "Apple M5 Pro");
        assert_eq!(hw.model_memory_mib(), 65536 * 7 / 10);
        let o = order(&hw);
        assert_eq!(o[0], (Engine::Mlx, None));
        assert_eq!(o[1], (Engine::Ollama, None));
        assert!(o.contains(&(Engine::Vllm, Some("needsLinux".into()))));
        let hw = Hardware { python: false, ollama: false, ..hw };
        assert!(order(&hw).contains(&(Engine::Mlx, Some("needsPython".into()))));
        assert!(order(&hw).contains(&(Engine::Ollama, Some("needsOllamaApp".into()))));
    }

    #[test]
    fn no_gpu_runs_llama_cpp_on_the_cpu() {
        let hw = Hardware { os: "linux".into(), arch: "x86_64".into(), memory_mib: 8192, docker: true, ..Default::default() };
        let f = engines(&hw);
        assert_eq!((f[0].engine, f[0].backend, f[0].blocked.as_deref()), (Engine::LlamaCpp, Backend::Cpu, None));
        assert!(f.iter().any(|f| f.engine == Engine::Vllm && f.blocked.as_deref() == Some("needsGpu")));
        let hw = Hardware { docker: false, ..hw };
        assert_eq!(engines(&hw)[0].blocked.as_deref(), Some("needsDocker"));
    }

    #[test]
    fn reads_the_probe_on_wsl_with_a_tesla() {
        let out = "os=Linux\narch=x86_64\nmemory_kib=41072000\nnvidia=Tesla T10, 16384, 7.5\ndri=1\ndocker=1\nnvidia_runtime=1\n";
        let hw = parse_probe(out);
        assert_eq!(hw.memory_mib, 41072000 / 1024);
        assert_eq!(hw.gpus, vec![Gpu { vendor: "nvidia".into(), name: "Tesla T10".into(), memory_mib: Some(16384), compute: Some(75) }]);
        assert!(hw.docker && hw.nvidia_containers);
        assert_eq!(recommend_args(&hw, &RecommendQuery::default()).unwrap()[..3], ["--memory".to_string(), "16384M".into(), "recommend".into()]);
    }

    #[test]
    fn reads_amd_and_intel_from_drm() {
        let out = "os=Linux\narch=x86_64\nmemory_kib=16000000\ndrm=0x1002 17163091968\ndrm=0x8086 0\nkfd=1\ndri=1\ndocker=1\n";
        let hw = parse_probe(out);
        assert_eq!(hw.gpus[0].vendor, "amd");
        assert_eq!(hw.gpus[0].memory_mib, Some(16368));
        assert!(hw.rocm_devices);
        let f = engines(&hw);
        assert_eq!((f[0].engine, f[0].backend), (Engine::LlamaCpp, Backend::Rocm));
        assert!(f.iter().any(|f| f.engine == Engine::Vllm && f.blocked.as_deref() == Some("needsNvidia")));
    }

    #[test]
    fn use_cases_are_checked() {
        let hw = nvidia(16384, 75, true);
        assert_eq!(recommend_args(&hw, &RecommendQuery { use_case: Some("--x".into()) }), Err("invalidUseCase"));
        let args = recommend_args(&hw, &RecommendQuery { use_case: Some("coding".into()) }).unwrap();
        assert!(args.windows(2).any(|w| w == ["--use-case", "coding"]));
    }

    #[test]
    fn assets_are_pinned_per_platform() {
        assert_eq!(llmfit_asset("linux", "x86_64").unwrap().sha256.len(), 64);
        assert!(llmfit_asset("darwin", "arm64").unwrap().file.contains("aarch64-apple-darwin"));
        assert!(llmfit_asset("freebsd", "x86_64").is_none());
        assert!(llmfit_url(llmfit_asset("linux", "aarch64").unwrap()).ends_with("aarch64-unknown-linux-musl.tar.gz"));
    }

    fn model(name: &str, params: f64, gguf: &[&str], ollama: Option<&str>) -> LlmfitModel {
        LlmfitModel {
            name: name.into(),
            params_b: Some(params),
            fit_level: Some("Perfect".into()),
            run_mode: Some("GPU".into()),
            score: Some(90.0),
            estimated_tps: Some(25.0),
            memory_required_gb: Some(params * 1.1),
            best_quant: Some("Q8_0".into()),
            context_length: Some(32768),
            license: Some("apache-2.0".into()),
            capability_ids: vec![],
            category: None,
            use_case: None,
            is_moe: false,
            gguf_sources: gguf.iter().map(|r| GgufSource { repo: r.to_string() }).collect(),
            ollama_name: ollama.map(str::to_owned),
            release_date: None,
        }
    }

    #[test]
    fn each_engine_keeps_what_it_loads() {
        let models = vec![
            model("Alexzander85/Qwen3.5-9B-Distilled-NVFP4", 9.0, &[], None),
            model("mlx-community/Qwen3-8B-4bit", 8.0, &[], None),
            model("unsloth/Qwen3-8B-bnb-4bit", 8.0, &[], None),
            model("Qwen/Qwen3-8B", 8.2, &["unsloth/Qwen3-8B-GGUF"], Some("qwen3:8b")),
            model("Qwen/Qwen3-4B-AWQ", 4.0, &[], None),
            model("Qwen/Qwen3-32B", 32.0, &["unsloth/Qwen3-32B-GGUF"], None),
        ];
        let hw = nvidia(16384, 75, true);
        let names = |e| candidates(e, Backend::Cuda, &hw, &models, false, 10).into_iter().map(|c| c.model.setting()).collect::<Vec<_>>();
        // Unknown publishers are left out by default; vLLM loads 16-bit or AWQ
        // weights that fit 90 % of 16 GiB.
        assert_eq!(names(Engine::Vllm), ["Qwen/Qwen3-4B-AWQ"]);
        assert_eq!(names(Engine::LlamaCpp), ["unsloth/Qwen3-8B-GGUF:Q8_0", "unsloth/Qwen3-32B-GGUF:Q8_0"]);
        assert_eq!(names(Engine::Ollama), ["qwen3:8b", "hf.co/unsloth/Qwen3-32B-GGUF:Q8_0"]);
        // MLX's own build first, one per model.
        assert_eq!(names(Engine::Mlx), ["mlx-community/Qwen3-8B-4bit", "Qwen/Qwen3-32B"]);
        assert_eq!(candidates(Engine::Mlx, Backend::Metal, &hw, &models[3..], false, 1)[0].name, "Qwen/Qwen3-8B");
        let all = candidates(Engine::Vllm, Backend::Cuda, &hw, &models, true, 10);
        // On the CPU beside a GPU Docker cannot use: RAM decides, no speed.
        let cpu = candidates(Engine::LlamaCpp, Backend::Cpu, &hw, &models, false, 10);
        // 8B in 32 GiB of RAM; 32B (35 GiB) does not fit.
        assert_eq!(cpu.iter().map(|c| (c.name.as_str(), c.fit.as_str())).collect::<Vec<_>>(), [("Qwen/Qwen3-8B", "good")]);
        assert!(cpu.iter().all(|c| c.tokens_per_second.is_none()));
        assert!(all.iter().all(|c| !c.name.contains("NVFP4") && !c.name.contains("bnb")));
    }

    #[test]
    fn one_build_per_model() {
        assert_eq!(base_of("lmstudio-community/DeepSeek-R1-0528-Qwen3-8B-MLX-4bit"), "deepseek-r1-0528-qwen3-8b");
        assert_eq!(base_of("mlx-community/DeepSeek-R1-0528-Qwen3-8B-4bit"), "deepseek-r1-0528-qwen3-8b");
        assert_eq!(base_of("Qwen/Qwen3-4B-AWQ"), base_of("Qwen/Qwen3-4B"));
        let models = vec![
            model("lmstudio-community/Qwen3-8B-MLX-4bit", 8.0, &[], None),
            model("lmstudio-community/Qwen3-8B-MLX-8bit", 8.0, &[], None),
            model("Qwen/Qwen3-8B", 8.0, &[], None),
            model("Qwen/Qwen3-4B", 4.0, &[], None),
        ];
        let hw = Hardware { os: "darwin".into(), arch: "arm64".into(), memory_mib: 65536, ..Default::default() };
        let names: Vec<String> = candidates(Engine::Mlx, Backend::Metal, &hw, &models, false, 10).into_iter().map(|c| c.name).collect();
        assert_eq!(names, ["lmstudio-community/Qwen3-8B-MLX-4bit", "Qwen/Qwen3-4B"]);
    }

    #[test]
    fn vllm_memory_follows_the_weights() {
        assert!((vllm_memory_gib("Qwen/Qwen3-8B", 8.0) - (8.0 * 2.0 * 1.07 + 1.5 + 0.48)).abs() < 1e-9);
        assert!(vllm_memory_gib("Qwen/Qwen3-8B-AWQ", 8.0) < vllm_memory_gib("Qwen/Qwen3-8B-FP8", 8.0));
        assert!(!vllm_loads("RedHatAI/Qwen3-8B-FP8-dynamic", Some(75)));
        assert!(vllm_loads("RedHatAI/Qwen3-8B-FP8-dynamic", Some(89)));
    }

    #[test]
    fn model_settings_are_plain() {
        assert!(valid_model("Qwen/Qwen3-0.6B"));
        assert!(valid_model("unsloth/Qwen3-8B-GGUF:Q4_K_M"));
        assert!(valid_model("hf.co/unsloth/Qwen3-8B-GGUF:Q4_K_M"));
        assert!(valid_model("qwen3:0.6b"));
        for bad in ["", "-x", "/etc/passwd", "a b", "a;b", "a'b", "../x", "a$(b)"] {
            assert!(!valid_model(bad), "{bad}");
        }
    }

    #[test]
    fn the_mlx_job_round_trips() {
        let plist = mlx_plist("/Users/a/sbm/inference/mlx", "mlx-community/Qwen3-0.6B-4bit", 8585, "/Users/a/shared/models/huggingface");
        assert!(plist.contains("<string>/Users/a/sbm/inference/mlx/venv/bin/mlx_lm.server</string>"));
        assert!(plist.contains("<string>127.0.0.1</string>"));
        let out = format!("{plist}{MLX_STATUS_MARK}\n\tstate = running\n\tpid = 4242\n");
        assert_eq!(
            parse_mlx_status(&out),
            MlxService { model: Some("mlx-community/Qwen3-0.6B-4bit".into()), port: Some(8585), running: true, pid: Some(4242) }
        );
        assert_eq!(parse_mlx_status(&format!("{MLX_STATUS_MARK}\n")), MlxService::default());
        assert!(mlx_install_script("/a b").contains("cd '/a b'"));
        assert!(mlx_plist("/d", "a&b", 1, "/h").contains("a&amp;b"));
        // The plist is a quoted heredoc: nothing in it is expanded.
        let start = mlx_start_script(&mlx_plist("/d", "m", 1, "/h"));
        assert!(start.contains("<<'SBM_MLX_PLIST'\n<?xml") && start.contains("</plist>\nSBM_MLX_PLIST\n"));
    }

    #[test]
    fn parses_llmfit_output() {
        let json = r#"{"system":{"backend":"CUDA"},"models":[{"name":"Qwen/Qwen3-8B","params_b":8.19,"fit_level":"Good",
            "run_mode":"GPU","score":88.1,"estimated_tps":23.6,"memory_required_gb":10.2,"best_quant":"Q8_0",
            "context_length":131072,"license":"apache-2.0","capability_ids":["tool_use"],"is_moe":false,
            "gguf_sources":[{"provider":"unsloth","repo":"unsloth/Qwen3-8B-GGUF"}],"ollama_name":"qwen3:8b","extra":1}]}"#;
        let r = parse_recommend(json).unwrap();
        assert_eq!(r.models[0].ollama_name.as_deref(), Some("qwen3:8b"));
        assert_eq!(r.models[0].gguf_sources[0].repo, "unsloth/Qwen3-8B-GGUF");
    }
}
