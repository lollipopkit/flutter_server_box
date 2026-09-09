/**
 * What ends up in a `.sbp`, and what stops one being written.
 *
 * The rule these hold: **a package the app would refuse is not written at all.**
 * A packer that succeeds and produces something uninstallable moves the failure
 * to whoever downloads it, where there is nothing to be done about it.
 */
import { afterEach, describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { maxTotalBytes, packPlugin } from "../src/pack.ts";
import { readZip } from "../src/zip.ts";

const made: string[] = [];
afterEach(() => {
  for (const dir of made.splice(0)) rmSync(dir, { recursive: true, force: true });
});

interface PluginDir {
  manifest?: Record<string, unknown> | string;
  source?: string | null;
  l10n?: Record<string, string>;
  icon?: Uint8Array;
}

function plugin({ manifest, source = "export const x = 1", l10n, icon }: PluginDir) {
  const dir = mkdtempSync(join(tmpdir(), "sbp-"));
  made.push(dir);
  const m = manifest ?? {
    id: "app.serverbox.test",
    version: "1.2.3",
    abi: 2,
    name: "Test",
    description: "A plugin.",
  };
  writeFileSync(
    join(dir, "manifest.json"),
    typeof m === "string" ? m : JSON.stringify(m),
  );
  if (source !== null) {
    mkdirSync(join(dir, "dist"), { recursive: true });
    writeFileSync(join(dir, "dist", "plugin.js"), source);
  }
  if (l10n) {
    mkdirSync(join(dir, "l10n"), { recursive: true });
    for (const [locale, body] of Object.entries(l10n)) {
      writeFileSync(join(dir, "l10n", `${locale}.json`), body);
    }
  }
  if (icon) writeFileSync(join(dir, "icon.png"), icon);
  return dir;
}

describe("what goes in", () => {
  test("the manifest and the script, named as the app looks for them", () => {
    const packed = packPlugin(plugin({}));

    expect(packed.entries).toEqual(["manifest.json", "plugin.js"]);
    expect(packed.fileName).toBe("app.serverbox.test-1.2.3.sbp");
    const files = readZip(packed.bytes);
    expect(new TextDecoder().decode(files.get("plugin.js")!)).toBe(
      "export const x = 1",
    );
  });

  /// Left out once already, and the failure was silent: the plugin installed
  /// from its directory with translations and fell back to English from a
  /// package.
  test("the translations", () => {
    const packed = packPlugin(
      plugin({
        manifest: { id: "a.b", version: "1.0.0", abi: 2, l10n: ["en", "zh-CN"] },
        l10n: { en: '{"k":"v"}', "zh-CN": '{"k":"值"}' },
      }),
    );

    expect(packed.entries).toContain("l10n/en.json");
    expect(packed.entries).toContain("l10n/zh-CN.json");
  });

  /// The same class of omission as the translations, and the same silence:
  /// `PluginPackage` reads `icon.png` and the three copies of this packer never
  /// wrote one.
  test("the icon", () => {
    const icon = new Uint8Array([0x89, 0x50, 0x4e, 0x47]);
    const packed = packPlugin(plugin({ icon }));

    expect(packed.entries).toContain("icon.png");
    expect(readZip(packed.bytes).get("icon.png")).toEqual(icon);
  });

  test("the manifest goes in verbatim", () => {
    // Whitespace and key order included: the host parses the bytes in the
    // archive, and this is what its digest is over.
    const raw = '{\n  "id": "a.b",\n  "version": "1.0.0",\n  "abi": 2\n}';
    const packed = packPlugin(plugin({ manifest: raw }));

    expect(new TextDecoder().decode(readZip(packed.bytes).get("manifest.json")!))
      .toBe(raw);
  });
});

describe("refusing to write one", () => {
  test("no manifest", () => {
    const dir = mkdtempSync(join(tmpdir(), "sbp-"));
    made.push(dir);
    expect(() => packPlugin(dir)).toThrow(/no manifest\.json/);
  });

  test("no built script, and it says how to get one", () => {
    expect(() => packPlugin(plugin({ source: null }))).toThrow(/bun run build/);
  });

  test("a manifest missing what a repository index is built from", () => {
    expect(() => packPlugin(plugin({ manifest: { version: "1", abi: 2 } })))
      .toThrow(/names no id/);
    expect(() => packPlugin(plugin({ manifest: { id: "a", abi: 2 } })))
      .toThrow(/names no version/);
    expect(() => packPlugin(plugin({ manifest: { id: "a", version: "1" } })))
      .toThrow(/abi/);
    expect(() =>
      packPlugin(plugin({ manifest: { id: "a", version: "1", abi: "2" } })),
    ).toThrow(/abi/);
  });

  /// A promise the package does not keep. The app reads the files, so what
  /// ships is English and the manifest says otherwise.
  test("a declared locale with no file", () => {
    expect(() =>
      packPlugin(
        plugin({
          manifest: { id: "a.b", version: "1.0.0", abi: 2, l10n: ["en", "de"] },
          l10n: { en: "{}" },
        }),
      ),
    ).toThrow(/de/);
  });

  test("translations with no en, which is the fallback", () => {
    expect(() =>
      packPlugin(
        plugin({
          manifest: { id: "a.b", version: "1.0.0", abi: 2, l10n: ["de"] },
          l10n: { de: "{}" },
        }),
      ),
    ).toThrow(/en\.json/);
  });

  test("more than the app will unpack", () => {
    expect(() =>
      packPlugin(plugin({ source: "x".repeat(maxTotalBytes + 1) })),
    ).toThrow(/at most/);
  });
});

/// Not an error: the file is packed and the app reads it, so it works. But
/// nothing announces it, and the l10n consistency test on the app side goes by
/// the manifest.
test("a file the manifest does not list is a warning", () => {
  const packed = packPlugin(
    plugin({
      manifest: { id: "a.b", version: "1.0.0", abi: 2, l10n: ["en"] },
      l10n: { en: "{}", ja: "{}" },
    }),
  );

  expect(packed.entries).toContain("l10n/ja.json");
  expect(packed.warnings.join()).toMatch(/ja/);
});
