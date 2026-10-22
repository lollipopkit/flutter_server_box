wit_bindgen::generate!({ path: ["../../../wit", "wit"], world: "test:probe/probe", generate_all });

use exports::test::probe::api::{self, Echoed, Shade, Shape};
use exports::test::probe::jobs;
use sbm::app::types::Error;
use sbm::app::{agent, host, http, job};

struct Probe;

fn get(url: String) -> http::Request {
    http::Request { method: "GET".into(), url, headers: vec![], body: None, timeout_secs: 0 }
}

impl api::Guest for Probe {
    fn echo(text: String, count: u32, tags: Vec<String>, maybe_note: Option<String>, shade: Shade, shape: Shape) -> Result<Echoed, Error> {
        Ok(Echoed { text, count, tags, maybe_note, shade, shape })
    }

    fn refuse() -> Result<(), Error> {
        Err(Error::FailedPrecondition("notScanned".into()))
    }

    fn spin() -> Result<(), Error> {
        let mut n: u64 = 0;
        loop {
            n = std::hint::black_box(n.wrapping_add(1));
        }
    }

    fn grow() -> Result<u32, Error> {
        let mut v: Vec<Vec<u8>> = Vec::new();
        loop {
            v.push(vec![1u8; 8 << 20]);
            std::hint::black_box(&v);
        }
    }

    fn run(script: String) -> Result<String, Error> {
        let out = host::exec(&script, None)?;
        Ok(String::from_utf8_lossy(&out.stdout).into_owned())
    }

    fn as_root(script: String) -> Result<String, Error> {
        let out = host::exec_root(&script)?;
        Ok(String::from_utf8_lossy(&out.stdout).into_owned())
    }

    fn put(key: String, value: String) -> Result<(), Error> {
        host::kv_set(&key, &value)
    }

    fn get(key: String) -> Result<Option<String>, Error> {
        Ok(host::kv_get(&key))
    }

    fn line_outside() -> Result<(), Error> {
        job::line("nobody reads this");
        job::run_root("true").map(|_| ())
    }

    fn providers() -> Result<(Vec<String>, Option<String>), Error> {
        let all = agent::providers()?;
        let key = match all.first() {
            Some(p) => agent::endpoint(&p.id)?.and_then(|e| e.key),
            None => None,
        };
        Ok((all.into_iter().map(|p| p.id).collect(), key))
    }

    fn fetch_text(url: String) -> Result<(u16, String), Error> {
        let r = http::fetch(&get(url))?;
        Ok((r.status, String::from_utf8_lossy(&r.body).into_owned()))
    }

    fn count_lines(url: String) -> Result<u32, Error> {
        let (_, lines) = http::fetch_lines(&get(url))?;
        let mut n = 0;
        while lines.next()?.is_some() {
            n += 1;
        }
        Ok(n)
    }

    fn save(url: String, sha256: String, name: String) -> Result<String, Error> {
        http::download(&url, &sha256, &name)
    }

    fn own_dir() -> Result<String, Error> {
        host::data_dir()
    }
}

impl jobs::Guest for Probe {
    fn count(lines: u32) -> Result<u32, Error> {
        for i in 0..lines {
            job::line(&format!("line {i}"));
        }
        Ok(lines)
    }

    fn shell(script: String) -> Result<i32, Error> {
        job::run(&script)
    }

    // Waiting rather than spinning (`spin` is the CPU bound's): a sleep is a
    // host call, so it runs until cancelled however slow the machine is.
    fn forever() -> Result<(), Error> {
        loop {
            job::line("still here");
            std::thread::sleep(std::time::Duration::from_millis(100));
        }
    }
}

export!(Probe);
