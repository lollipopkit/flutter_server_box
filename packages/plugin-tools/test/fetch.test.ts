/**
 * Turning an address into a tarball, and reading one.
 *
 * The address table here is **the same table** as the one in the app's
 * `test/plugin_repo_test.dart`: the rule is implemented twice, in two languages,
 * and a client that derives a different URL from the same address is a client
 * that reads a different repository.
 */
import { describe, expect, test } from "bun:test";
import { gzipSync } from "node:zlib";

import { archiveUrlOf, isRepoAddress } from "../src/fetch.ts";
import { readTar, readTarGz, stripTopDirectory } from "../src/tar.ts";

describe("the archive url", () => {
  test.each([
    // A repository address, GitHub-shaped. `HEAD` rather than a branch name:
    // which branch is default is not this tool's to guess, and the server
    // resolves it.
    [
      "https://github.com/lollipopkit/serverbox-plugins",
      "https://github.com/lollipopkit/serverbox-plugins/archive/HEAD.tar.gz",
    ],
    [
      "https://github.com/lollipopkit/serverbox-plugins/",
      "https://github.com/lollipopkit/serverbox-plugins/archive/HEAD.tar.gz",
    ],
    [
      "https://github.com/lollipopkit/serverbox-plugins.git",
      "https://github.com/lollipopkit/serverbox-plugins/archive/HEAD.tar.gz",
    ],
    // Gitea and Forgejo answer the same path, so nothing here is GitHub-only.
    [
      "https://codeberg.org/someone/plugins",
      "https://codeberg.org/someone/plugins/archive/HEAD.tar.gz",
    ],
    // Already an archive: taken as it is, so a repository served from anywhere
    // can be used by pointing straight at the tarball.
    ["https://example.com/plugins.tar.gz", "https://example.com/plugins.tar.gz"],
    ["https://example.com/plugins.tgz", "https://example.com/plugins.tgz"],
  ])("%s", (address, expected) => {
    expect(archiveUrlOf(address as string)).toBe(expected);
  });

  test("only an http(s) address is one", () => {
    expect(isRepoAddress("https://github.com/a/b")).toBeTrue();
    expect(isRepoAddress("../serverbox-plugins")).toBeFalse();
    expect(isRepoAddress("/tmp/plugins")).toBeFalse();
  });
});

/** A tar of [files], written by hand the way `git archive` does. */
function tar(files: Record<string, string>, { longNames = false } = {}): Uint8Array {
  const blocks: Uint8Array[] = [];
  const encoder = new TextEncoder();

  const header = (name: string, size: number, type: string) => {
    const block = new Uint8Array(512);
    block.set(encoder.encode(name.slice(0, 100)), 0);
    block.set(encoder.encode("000644 "), 100);
    block.set(encoder.encode(`${size.toString(8).padStart(11, "0")} `), 124);
    block.set(encoder.encode(`${(0).toString(8).padStart(11, "0")} `), 136);
    block[156] = type.charCodeAt(0);
    block.set(encoder.encode("ustar  "), 257);
    return block;
  };
  const body = (bytes: Uint8Array) => {
    const padded = new Uint8Array(Math.ceil(bytes.length / 512) * 512);
    padded.set(bytes);
    return padded;
  };

  for (const [name, content] of Object.entries(files)) {
    const bytes = encoder.encode(content);
    if (longNames) {
      const nameBytes = encoder.encode(`${name}\0`);
      blocks.push(header("././@LongLink", nameBytes.length, "L"), body(nameBytes));
      blocks.push(header(name, bytes.length, "0"), body(bytes));
    } else {
      blocks.push(header(name, bytes.length, "0"), body(bytes));
    }
  }
  blocks.push(new Uint8Array(1024));

  const total = blocks.reduce((n, b) => n + b.length, 0);
  const out = new Uint8Array(total);
  let at = 0;
  for (const block of blocks) {
    out.set(block, at);
    at += block.length;
  }
  return out;
}

const text = (b: Uint8Array | undefined) => new TextDecoder().decode(b);

describe("reading a tarball", () => {
  test("entries come back by name", () => {
    const files = readTar(tar({ "repo.toml": "schema = 1", "a/b.toml": "id = 1" }));

    expect([...files.keys()].sort()).toEqual(["a/b.toml", "repo.toml"]);
    expect(text(files.get("repo.toml"))).toBe("schema = 1");
  });

  test("gzip is unwrapped", () => {
    const files = readTarGz(
      new Uint8Array(gzipSync(Buffer.from(tar({ "repo.toml": "schema = 1" })))),
    );

    expect(text(files.get("repo.toml"))).toBe("schema = 1");
  });

  /// `git archive` writes one for a path over 100 bytes, and a plugin file three
  /// directories deep under a long publisher name gets there.
  test("a GNU long name is used for the entry that follows it", () => {
    const name = `plugins/com/${"a".repeat(90)}/thing.toml`;
    const files = readTar(tar({ [name]: "id = 1" }, { longNames: true }));

    expect([...files.keys()]).toEqual([name]);
  });

  /// The name of the directory a source tarball wraps everything in **cannot be
  /// predicted**: GitHub puts the resolved commit sha in it for a `HEAD`
  /// archive. So it is taken from the entries.
  test("the single top directory is dropped, whatever it is called", () => {
    const files = stripTopDirectory(
      readTar(
        tar({
          "serverbox-plugins-fca4edc/repo.toml": "schema = 1",
          "serverbox-plugins-fca4edc/plugins/a/b/c.toml": "id = 1",
        }),
      ),
    );

    expect([...files.keys()].sort()).toEqual(["plugins/a/b/c.toml", "repo.toml"]);
  });

  test("an already flat archive is left alone", () => {
    const files = stripTopDirectory(readTar(tar({ "repo.toml": "schema = 1" })));

    expect([...files.keys()]).toEqual(["repo.toml"]);
  });

  test("two top-level entries are not a wrapper", () => {
    const files = stripTopDirectory(
      readTar(tar({ "a/one.toml": "1", "b/two.toml": "2" })),
    );

    expect([...files.keys()].sort()).toEqual(["a/one.toml", "b/two.toml"]);
  });

  describe("refusing", () => {
    test("an entry larger than the cap", () => {
      expect(() =>
        readTar(tar({ "big.sbp": "x".repeat(2048) }), { maxEntryBytes: 1024 }),
      ).toThrow(/larger than/);
    });

    /// A tarball is an untrusted archive: a small one can name a great deal.
    test("an archive that unpacks to more than the cap", () => {
      expect(() =>
        readTar(tar({ "a": "x".repeat(600), "b": "y".repeat(600) }), {
          maxTotalBytes: 1000,
        }),
      ).toThrow(/too much/);
    });

    test("an entry type nothing here implements", () => {
      const bytes = tar({ "a": "x" });
      // Turn the file entry into a character device, which nothing should read.
      bytes[156] = "3".charCodeAt(0);
      expect(() => readTar(bytes)).toThrow(/entry type 3/);
    });
  });
});
