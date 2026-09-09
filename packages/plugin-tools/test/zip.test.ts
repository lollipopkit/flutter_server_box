/**
 * The archive format, both directions.
 *
 * The reader exists so the index generator can read a manifest out of the bytes
 * it is about to publish a digest for, so what matters here is that it reads
 * what the writer wrote — and that it says so when it cannot, rather than
 * returning something plausible.
 */
import { describe, expect, test } from "bun:test";
import { deflateRawSync } from "node:zlib";

import { crc32, readZip, writeZip } from "../src/zip.ts";

const utf8 = (s: string) => new Uint8Array(new TextEncoder().encode(s));
const text = (b: Uint8Array) => new TextDecoder().decode(b);

describe("round trip", () => {
  test("every entry comes back, by name", () => {
    const bytes = writeZip([
      { name: "manifest.json", data: utf8('{"id":"a"}') },
      { name: "plugin.js", data: utf8("export const x = 1") },
      { name: "l10n/zh-CN.json", data: utf8('{"k":"值"}') },
    ]);

    const files = readZip(bytes);
    expect([...files.keys()].sort()).toEqual([
      "l10n/zh-CN.json",
      "manifest.json",
      "plugin.js",
    ]);
    expect(text(files.get("manifest.json")!)).toBe('{"id":"a"}');
    // Non-ASCII survives, which is the whole point of the l10n entries.
    expect(text(files.get("l10n/zh-CN.json")!)).toBe('{"k":"值"}');
  });

  test("an empty entry is an entry", () => {
    const files = readZip(writeZip([{ name: "a", data: new Uint8Array(0) }]));
    expect(files.get("a")).toEqual(new Uint8Array(0));
  });

  test("binary bytes are not touched", () => {
    const icon = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0, 0xff, 0x0d, 0x0a]);
    const files = readZip(writeZip([{ name: "icon.png", data: icon }]));
    expect(files.get("icon.png")).toEqual(icon);
  });
});

describe("reading what somebody else wrote", () => {
  /// The packer stores, but nothing says a `.sbp` handed to the generator was
  /// written by it.
  test("a deflated entry is inflated", () => {
    const body = "x".repeat(4096);
    const data = new Uint8Array(deflateRawSync(Buffer.from(body)));
    const bytes = deflatedZip("plugin.js", data, body.length, crc32(utf8(body)));

    expect(text(readZip(bytes).get("plugin.js")!)).toBe(body);
  });

  test("a directory entry is skipped rather than read as a file", () => {
    const bytes = writeZip([
      { name: "l10n/", data: new Uint8Array(0) },
      { name: "l10n/en.json", data: utf8("{}") },
    ]);
    expect([...readZip(bytes).keys()]).toEqual(["l10n/en.json"]);
  });
});

describe("refusing", () => {
  test("something that is not a zip", () => {
    expect(() => readZip(utf8("hello"))).toThrow(/not a zip/);
  });

  /// A directory that describes more data than the file holds. Read without the
  /// check, this is a silent short read — which for the generator would be a
  /// digest published for a manifest it never saw all of.
  test("an entry that runs past the end", () => {
    const bytes = writeZip([{ name: "a", data: utf8("hello") }]);
    new DataView(bytes.buffer).setUint32(central(bytes) + 20, 9999, true);
    expect(() => readZip(bytes)).toThrow(/past the end/);
  });

  test("a compression method nothing here implements", () => {
    const bytes = deflatedZip("a", utf8("xx"), 2, 0, 14);
    expect(() => readZip(bytes)).toThrow(/compression method 14/);
  });

  /// The size in the directory is what a caller sizes a buffer from, so a
  /// disagreement has to be an error rather than a short read.
  test("a size that disagrees with the data", () => {
    const bytes = writeZip([{ name: "a", data: utf8("hello") }]);
    new DataView(bytes.buffer).setUint32(central(bytes) + 24, 99, true);
    expect(() => readZip(bytes)).toThrow(/99/);
  });
});

/** Where the central directory starts in a one-entry archive named `a`. */
function central(bytes: Uint8Array): number {
  return bytes.length - 22 - 46 - 1;
}

/** A one-entry archive with a chosen compression method, written by hand. */
function deflatedZip(
  name: string,
  data: Uint8Array,
  uncompressed: number,
  crc: number,
  method = 8,
): Uint8Array {
  const nameBytes = utf8(name);
  const local = new DataView(new ArrayBuffer(30));
  local.setUint32(0, 0x04034b50, true);
  local.setUint16(4, 20, true);
  local.setUint16(8, method, true);
  local.setUint32(14, crc, true);
  local.setUint32(18, data.length, true);
  local.setUint32(22, uncompressed, true);
  local.setUint16(26, nameBytes.length, true);

  const dir = new DataView(new ArrayBuffer(46));
  dir.setUint32(0, 0x02014b50, true);
  dir.setUint16(10, method, true);
  dir.setUint32(16, crc, true);
  dir.setUint32(20, data.length, true);
  dir.setUint32(24, uncompressed, true);
  dir.setUint16(28, nameBytes.length, true);
  dir.setUint32(42, 0, true);

  const offset = 30 + nameBytes.length + data.length;
  const end = new DataView(new ArrayBuffer(22));
  end.setUint32(0, 0x06054b50, true);
  end.setUint16(8, 1, true);
  end.setUint16(10, 1, true);
  end.setUint32(12, 46 + nameBytes.length, true);
  end.setUint32(16, offset, true);

  const parts = [
    new Uint8Array(local.buffer),
    nameBytes,
    data,
    new Uint8Array(dir.buffer),
    nameBytes,
    new Uint8Array(end.buffer),
  ];
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const part of parts) {
    out.set(part, at);
    at += part.length;
  }
  return out;
}
