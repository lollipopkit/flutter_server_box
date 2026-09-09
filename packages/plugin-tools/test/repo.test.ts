/**
 * The repository: where a plugin's file goes, what is in it, and what happens
 * when it is written again.
 *
 * Three of these are the reason the generator exists rather than somebody
 * editing TOML by hand: **the digest is computed from the bytes being
 * published**, **a plugin's file keeps versions this run knows nothing about**
 * (which is what lets an older app find a release its ABI can run), and **a
 * file's path has to agree with the id inside it**.
 */
import { describe, expect, test } from "bun:test";
import { createHash } from "node:crypto";

import {
  buildRepo,
  compareVersions,
  idOfLayout,
  layoutOf,
  readPlugin,
  readRepoFile,
  schema,
  tagOf,
  writePlugin,
  writeRepoFile,
} from "../src/repo.ts";
import { writeZip } from "../src/zip.ts";

interface Fields {
  id?: string;
  version?: string;
  abi?: number;
  name?: string;
  description?: string;
  source_url?: string;
  license?: string;
}

const base = "https://github.com/lollipopkit/serverbox-plugins/releases/download";

function sbp(fields: Fields = {}, script = "export const x = 1") {
  const manifest = {
    id: "app.serverbox.test",
    version: "1.0.0",
    abi: 2,
    name: "Test",
    description: "A plugin.",
    ...fields,
  };
  const bytes = writeZip([
    {
      name: "manifest.json",
      data: new Uint8Array(new TextEncoder().encode(JSON.stringify(manifest))),
    },
    { name: "plugin.js", data: new Uint8Array(new TextEncoder().encode(script)) },
  ]);
  return { bytes, fileName: `${manifest.id}-${manifest.version}.sbp` };
}

/** What `buildRepo` wrote, parsed back. */
function pluginsIn(files: Map<string, string>) {
  return [...files].map(([path, text]) => readPlugin(text, path));
}

describe("where a file goes", () => {
  test("two directory levels, taken from the id", () => {
    expect(layoutOf("app.serverbox.diskusage")).toBe(
      "plugins/app/serverbox/diskusage.toml",
    );
    // Everything after the publisher is the file name, dots and all, so an id
    // with four parts is not a third directory.
    expect(layoutOf("com.example.my.thing")).toBe(
      "plugins/com/example/my.thing.toml",
    );
  });

  test("the path reads back as the id", () => {
    for (const id of ["app.serverbox.ports", "com.example.my.thing"]) {
      expect(idOfLayout(layoutOf(id))).toBe(id);
    }
  });

  test("something that is not a plugin file has no id", () => {
    for (const path of ["repo.toml", "README.md", "packages/x.sbp", "plugins/a/b.toml"]) {
      expect(idOfLayout(path)).toBeNull();
    }
  });

  /// An id with two parts has nowhere to go under a two-level layout, and a
  /// path segment with a slash or a dot in it would make the mapping ambiguous.
  test("an id that cannot be laid out is refused", () => {
    for (const id of ["single", "two.parts", "app..empty", "app.serverbox.a/b"]) {
      expect(() => layoutOf(id)).toThrow();
    }
  });
});

describe("a plugin file", () => {
  const plugin = {
    id: "app.serverbox.test",
    name: "Test",
    description: 'A "quoted" plugin.',
    license: "MIT",
    homepage: "https://example.com/p",
    versions: [
      {
        version: "1.0.0",
        abi: 2,
        path: "packages/app.serverbox.test-1.0.0.sbp",
        sha256: "a".repeat(64),
        size: 17595,
        notes: "First release.",
      },
    ],
  };

  test("round trips", () => {
    const text = writePlugin(plugin);

    expect(readPlugin(text, layoutOf(plugin.id))).toEqual(plugin);
  });

  test("a quote in a description does not produce a file nothing can read", () => {
    const text = writePlugin(plugin);

    expect(text).toContain('description = "A \\"quoted\\" plugin."');
    expect(readPlugin(text, layoutOf(plugin.id)).description).toBe(
      'A "quoted" plugin.',
    );
  });

  /// The check that catches a file copied into the wrong folder. Without it the
  /// app would install something the repository does not think it offers.
  test("a path that disagrees with the id is refused", () => {
    const text = writePlugin(plugin);

    expect(() => readPlugin(text, "plugins/com/example/other.toml")).toThrow(
      /path says com\.example\.other/,
    );
  });

  test("a release names exactly one of path and url", () => {
    const both = `id = "a.b.c"
name = "x"
description = ""

[[version]]
version = "1.0.0"
abi = 1
path = "packages/x.sbp"
url = "https://example.com/x.sbp"
sha256 = "${"a".repeat(64)}"
size = 1
`;
    expect(() => readPlugin(both, "plugins/a/b/c.toml")).toThrow(/exactly one/);

    const neither = both.replace(/path = .*\n/, "").replace(/url = .*\n/, "");
    expect(() => readPlugin(neither, "plugins/a/b/c.toml")).toThrow(/exactly one/);
  });

  test("a digest that is not 64 hex characters is refused", () => {
    const text = writePlugin(plugin).replace("a".repeat(64), "nope");

    expect(() => readPlugin(text, layoutOf(plugin.id))).toThrow(/sha256/);
  });

  test("a file with no version is not a listing", () => {
    expect(() =>
      readPlugin('id = "a.b.c"\nname = "x"\ndescription = ""\n', "plugins/a/b/c.toml"),
    ).toThrow(/\[\[version\]\]/);
  });
});

describe("repo.toml", () => {
  test("round trips", () => {
    expect(readRepoFile(writeRepoFile("ServerBox plugins"))).toEqual({
      name: "ServerBox plugins",
    });
  });

  /// The app refuses a repository announcing a schema it does not read, whole
  /// rather than in part: a field it does not know about may be the one that
  /// decides something.
  test("a schema this tool does not write is refused", () => {
    expect(() => readRepoFile(`schema = ${schema + 1}\n`)).toThrow(/schema/);
    expect(() => readRepoFile('name = "x"\n')).toThrow(/no schema/);
  });
});

describe("building", () => {
  test("a release carries the digest of the bytes and where they are", () => {
    const pkg = sbp();
    const { files } = buildRepo({ packages: [pkg], baseUrl: base });

    const plugin = pluginsIn(files)[0]!;
    const release = plugin.versions[0]!;
    expect(release.sha256).toBe(
      createHash("sha256").update(pkg.bytes).digest("hex"),
    );
    expect(release.size).toBe(pkg.bytes.length);
    // A url, not a path: **nothing binary goes into the repository.** The
    // digest is what binds that address to these bytes, which is the whole of
    // why it is here — the file and the package come from different places.
    //
    // And the address carries the version's own tag: one release per plugin
    // version, so it identifies exactly these bytes.
    expect(release.url).toBe(
      `${base}/${tagOf("app.serverbox.test", "1.0.0")}/${pkg.fileName}`,
    );
    expect(release.path).toBeUndefined();
  });

  test("the tag is the package's name, so a release holds its one asset", () => {
    expect(tagOf("app.serverbox.diskusage", "1.0.1")).toBe(
      "app.serverbox.diskusage-1.0.1",
    );
    const { files } = buildRepo({ packages: [sbp({ version: "2.3.4" })], baseUrl: base });
    const url = pluginsIn(files)[0]!.versions[0]!.url!;
    expect(url).toEndWith(
      "/app.serverbox.test-2.3.4/app.serverbox.test-2.3.4.sbp",
    );
  });

  test("a trailing slash on the base url does not double up", () => {
    const { files } = buildRepo({ packages: [sbp()], baseUrl: `${base}/` });

    expect(pluginsIn(files)[0]!.versions[0]!.url).toStartWith(`${base}/app.`);
  });

  test("the file is written where the id says", () => {
    const { files } = buildRepo({
      packages: [sbp({ id: "com.example.thing" })],
      baseUrl: base,
    });

    expect([...files.keys()]).toEqual(["plugins/com/example/thing.toml"]);
  });

  test("version and abi are read out of the package, not guessed", () => {
    const { files } = buildRepo({
      baseUrl: base,
      packages: [sbp({ version: "2.1.0", abi: 5 })],
    });

    expect(pluginsIn(files)[0]!.versions[0]).toMatchObject({
      version: "2.1.0",
      abi: 5,
    });
  });

  test("license and homepage come from the manifest", () => {
    const { files } = buildRepo({
      baseUrl: base,
      packages: [sbp({ license: "MIT", source_url: "https://example.com/p" })],
    });

    expect(pluginsIn(files)[0]).toMatchObject({
      license: "MIT",
      homepage: "https://example.com/p",
    });
  });

  describe("merging into what is published", () => {
    /// The whole reason a file lists more than one version: one repository
    /// serves apps of different ages, and each installs the newest release its
    /// own ABI can run. Writing only what is in `dist/` would drop the rest.
    test("a version this run knows nothing about is kept", () => {
      const first = buildRepo({
        baseUrl: base,
        packages: [sbp({ version: "1.0.0", abi: 1 })],
      }).files;

      const { files } = buildRepo({
        baseUrl: base,
        packages: [sbp({ version: "2.0.0", abi: 2 })],
        existing: first,
      });

      const versions = pluginsIn(files)[0]!.versions;
      expect(versions.map((v) => v.version)).toEqual(["2.0.0", "1.0.0"]);
      expect(versions[1]!.abi).toBe(1);
    });

    test("newest first, numerically", () => {
      let files = buildRepo({
        baseUrl: base, packages: [sbp({ version: "1.9.0" })] }).files;
      for (const version of ["1.10.0", "1.10.0-beta"]) {
        files = buildRepo({ packages: [sbp({ version })], existing: files, baseUrl: base }).files;
      }

      expect(pluginsIn(files)[0]!.versions.map((v) => v.version)).toEqual([
        "1.10.0",
        "1.10.0-beta",
        "1.9.0",
      ]);
    });

    /// A repository holds files other people sent. Rewriting all of them on
    /// every publish would bury the change that was actually made.
    test("only the plugins this run touched are written", () => {
      const other = buildRepo({
        packages: [sbp({ id: "com.other.thing" })],
        baseUrl: base,
      }).files;

      const { files } = buildRepo({ packages: [sbp()], existing: other, baseUrl: base });

      expect([...files.keys()]).toEqual(["plugins/app/serverbox/test.toml"]);
    });

    test("the name and description follow the newest package", () => {
      const first = buildRepo({
        baseUrl: base,
        packages: [sbp({ version: "1.0.0", name: "Old", description: "Was." })],
      }).files;

      const { files } = buildRepo({
        baseUrl: base,
        packages: [sbp({ version: "1.1.0", name: "New", description: "Is." })],
        existing: first,
      });

      expect(pluginsIn(files)[0]).toMatchObject({
        name: "New",
        description: "Is.",
      });
    });

    test("repacking the same bytes changes nothing", () => {
      const pkg = sbp();
      const first = buildRepo({ packages: [pkg], baseUrl: base }).files;

      const { files, notes } = buildRepo({ packages: [pkg], existing: first, baseUrl: base });

      expect(files).toEqual(first);
      expect(notes[0]).toStartWith("=");
    });

    test("notes already published survive a rebuild that has none", () => {
      const pkg = sbp();
      const first = buildRepo({
        baseUrl: base,
        packages: [{ ...pkg, notes: "First release." }],
      }).files;

      const { files } = buildRepo({ packages: [pkg], existing: first, baseUrl: base });

      expect(pluginsIn(files)[0]!.versions[0]!.notes).toBe("First release.");
    });
  });

  describe("republishing", () => {
    /// Nothing breaks the instant this happens — the app verifies against the
    /// file at download time. What breaks is a version number meaning a
    /// particular set of bytes, which is what everything else here relies on.
    test("a version whose bytes changed is refused, and says why", () => {
      const first = buildRepo({ packages: [sbp()], baseUrl: base }).files;

      expect(() =>
        buildRepo({
          packages: [sbp({}, "export const x = 2")],
          existing: first,
          baseUrl: base,
        }),
      ).toThrow(/different checksum/);
    });

    test("--allow-republish takes the new digest and says so", () => {
      const first = buildRepo({ packages: [sbp()], baseUrl: base }).files;
      const again = sbp({}, "export const x = 2");

      const { files, notes } = buildRepo({
        packages: [again],
        existing: first,
        baseUrl: base,
        allowRepublish: true,
      });

      const versions = pluginsIn(files)[0]!.versions;
      expect(versions).toHaveLength(1);
      expect(versions[0]!.sha256).toBe(
        createHash("sha256").update(again.bytes).digest("hex"),
      );
      expect(notes.join()).toMatch(/republished/);
    });
  });
});

/// The app compares versions itself (`PluginVersion.compare`) and does not trust
/// the order in a file. This is the same comparison, so the file's order and the
/// app's agree — whoever reads the top entry sees what will install.
describe("version comparison matches the app's", () => {
  test.each([
    ["1.10.0", "1.9.0", 1],
    ["1.0.0", "1.0.0", 0],
    ["1.0.0-beta", "1.0.0", -1],
    ["1.0.0-beta.2", "1.0.0-beta.1", 1],
    ["2.0", "1.9.9", 1],
    ["1.0.1", "1.0", 1],
  ])("%s vs %s", (a, b, want) => {
    expect(Math.sign(compareVersions(a as string, b as string))).toBe(want);
  });
});
