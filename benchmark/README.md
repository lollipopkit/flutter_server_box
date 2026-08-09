# SSH throughput benchmarks

Answers one question: where does the app's SSH throughput actually go, and is
it worth replacing dartssh2 with a native/Rust stack.

Three layers, so a slow result points at a specific layer instead of "SSH is
slow":

| | What it measures | Needs a host |
|---|---|---|
| `bin/cipher_bench.dart` | symmetric crypto in isolation (pointycastle) | no |
| `bin/ssh_bench.dart` L2 | SSH transport — exec channel + `dd`, no SFTP | yes |
| `bin/ssh_bench.dart` L3 | SFTP, with the app's own chunk size and in-flight limit | yes |

L2 and L3 are each compared against the system `ssh`/`scp` over the same
cipher, which is the native reference point.

## Running

```sh
dart pub get
dart run bin/cipher_bench.dart          # no host needed

./tool/bench_target.sh up               # provision an OrbStack machine
dart run bin/ssh_bench.dart
./tool/bench_target.sh down             # revoke the throwaway key
```

`tool/bench_target.sh` installs a stock OpenSSH server inside an OrbStack
Linux machine (default `sbm-debian`, override with `SBM_BENCH_MACHINE`) and
writes `.env` for the benchmark. OrbStack's own `<machine>@orb` sshd is not
usable as a target: it is reached through an `ssh-proxy-fdpass` ProxyCommand
rather than a plain socket, and ships no `sftp-server`.

To point at some other host instead, set `SBM_BENCH_HOST`, `SBM_BENCH_USER`
and `SBM_BENCH_KEY` (or `SBM_BENCH_PASSWORD`) in the environment or in `.env`.
Credentials are never printed. Both `.env` and the generated key are
gitignored.

## What this found

Reports of ~1 MB/s SFTP turned out not to be a general dartssh2 problem. On a
server that offers CTR, dartssh2 is in the same class as the system `ssh`, and
the SFTP layer is not a bottleneck. The slow case reproduced only against a
server restricted to AEAD ciphers — which is what the Mozilla "modern" and CIS
hardening profiles recommend — and came from two independent defects:

1. **`chacha20-poly1305@openssh.com` could not connect at all**, on five
   separate counts: swapped K_1/K_2, the RFC 7539 ChaCha variant instead of the
   original DJB one, a 12-byte little-endian nonce instead of 8-byte
   big-endian, the RFC 8439 Poly1305 AEAD framing instead of OpenSSH's raw MAC,
   and packet padding that folded in the separately-encrypted length field.
2. **`aes256-gcm@openssh.com` runs at 1.9 MiB/s**, entirely inside
   pointycastle's GHASH.

Together those left an AEAD-only server with exactly one working cipher, the
slow one. Fixed in lollipopkit/dartssh2#18; the GCM half is tracked separately
as lollipopkit/dartssh2#19.

Two hypotheses this ruled out, both of which looked plausible from reading the
code alone:

- `BlockCipherX.processAll` in `cipher_ext.dart` loops `processBlock` once per
  16-byte block — 2048 virtual calls per 32 KiB packet. Driving the same cipher
  in bulk measures **0.99x**, so the dispatch overhead is not real.
- The SFTP layer's chunking and in-flight limits. L3 tracks L2 within ~10%, so
  the cost is not there either.

## Results — 2026-08-10, M-series macOS → OrbStack Debian 12, 64 MiB payload

Loopback-class RTT, so these are CPU and protocol overhead with the network
taken out. High-RTT behaviour is **not** covered — SFTP pipelining depth would
become an independent factor there.

Layer 1, 32 KiB packets:

| Algorithm | MiB/s |
|---|---|
| `hmac-sha2-256` alone | 132.7 |
| `aes256-ctr` (as driven by `cipher_ext.dart`) | 104.7 |
| `aes256-ctr` driven in bulk | 103.7 |
| `chacha20-poly1305` primitives | 84.5 |
| `aes256-ctr` + `hmac-sha2-256` | 57.8 |
| **`aes256-gcm`** | **1.9** |

Layers 2 and 3, after the fix, stock Debian sshd:

| Path | dartssh2 | system ssh/scp |
|---|---|---|
| L2 exec, app defaults | 47.5 MiB/s | — |
| L2 exec, `aes256-ctr` | 49.1 MiB/s | 71.5 MiB/s |
| L2 exec, `chacha20-poly1305@openssh.com` | 54.8 MiB/s | 48.9 MiB/s |
| L2 exec, `aes256-gcm@openssh.com` | 1.8 MiB/s | 18.8 MiB/s |
| L3 SFTP get, `aes256-ctr` | 39.3 MiB/s | 14.5 MiB/s (scp) |
| L3 SFTP get, `chacha20-poly1305@openssh.com` | 67.4 MiB/s | — |
| L3 SFTP put, `aes256-ctr` | 41.4 MiB/s | — |

Same server restricted to
`Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com`:

| Path | before the fix | after |
|---|---|---|
| L2 exec, app defaults | 1.8 MiB/s | **49.2 MiB/s** |
| L3 SFTP get, app defaults | 1.9 MiB/s | **65.5 MiB/s** |

Before the fix, forcing `chacha20-poly1305@openssh.com` threw
`SSHAuthAbortError(Connection closed before authentication)` and sshd logged
`padding error: need 28 block 8 mod 4`.

`bin/chacha_probe.dart` is the minimal reproduction, kept because nothing in
dartssh2's own suite exercises AEAD ciphers against a real OpenSSH peer — which
is how five protocol-level mistakes went unnoticed, one of them locked in place
by a unit test asserting the wrong key order.
