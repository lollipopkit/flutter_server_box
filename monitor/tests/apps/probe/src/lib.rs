wit_bindgen::generate!({ path: ["../../../wit", "wit"], world: "test:probe/probe", generate_all });

use exports::test::probe::api::{self, Echoed, Shade, Shape};
use exports::test::probe::jobs;
use sbm::app::types::Error;
use sbm::app::{host, job};

struct Probe;

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
}

impl jobs::Guest for Probe {
    fn count(lines: u32) -> Result<u32, Error> {
        for i in 0..lines {
            job::line(&format!("line {i}"));
        }
        Ok(lines)
    }

    fn forever() -> Result<(), Error> {
        let mut i: u64 = 0;
        loop {
            i += 1;
            if i % 1_000_000 == 0 {
                job::line("still here");
            }
        }
    }
}

export!(Probe);
