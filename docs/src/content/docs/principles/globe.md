---
title: Globe and Location Resolution
description: How Server Box resolves coordinates, stores the city dataset, and renders the globe
---

The globe feature has two distinct responsibilities: resolve each server to a
coordinate, then render those coordinates interactively. Keeping these concerns
separate makes the privacy boundary explicit and keeps the geometry testable.

For user-facing instructions, see [Globe View](/docs/advanced/globe/). For the
data-handling policy, see
[Globe and location data](/docs/privacy/#globe-and-location-data).

## Architecture

```text
┌─────────────────────────────────────────────┐
│ ServerGlobe                                 │
│ Resolves servers, builds cards, handles UI  │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ GlobeView                                   │
│ Rotation, zoom, layout, and hit testing     │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ IpGeo                                       │
│ Selects the coordinate and its source       │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ GeoData / GeoBundle                         │
│ Installs and reads the on-device dataset    │
└─────────────────────────────────────────────┘
```

`ServerGlobe` is the only layer that knows about server records and connection
state. It passes `GlobeView` an id, coordinate, marker color, and card widget.
Projection and card placement therefore remain independent of server models,
Riverpod, and location resolution.

Resolution runs only while the globe is displayed. Keeping it out of a provider
avoids resolving every server merely because another widget reads shared state.

## Resolution flow

The settings and resolver enforce the following flow:

1. When `globeEnabled` is disabled, the server tab removes the globe view and
   no automatic resolution starts. `IpGeo` also checks the setting before DNS
   or dataset access.
2. `IpGeo.locate` returns a manually configured coordinate first. This is a
   local server-record value, not a lookup; the method can therefore return it
   even before its internal feature-switch check.
3. `IpGeo.geoHostOf` selects the host for the preferred transport, falling back
   to the other configured transport.
4. `locateHost` rejects a known private host immediately. For any other host,
   it resolves a hostname when needed, rejects a private resolved address, and
   then queries the city bundle.
5. If the connection host is private, `locate` may use a public address already
   reported by that server and query the city bundle with it.

The resulting source priority is:

| `GeoSource` | Meaning |
|---|---|
| `manual` | Coordinate stored on the server record; never overridden |
| `selfReported` | Public interface address reported by the server, resolved with the city dataset |
| `city` | Connection host or address resolved with the city dataset |

The enum follows the same order as the resolver. Priority is enforced by
control flow: `IpGeo.locate` stops at the first source that produces a
coordinate, so there is no stored result to compare or replace.

`GeoMiss.private` represents a LAN, loopback, link-local, documentation, or
otherwise non-public address. `GeoMiss.noData` covers unresolved hostnames,
public addresses missing from the dataset, missing city data, and configurations
from which no host can be selected. The UI keeps these cases separate because
their remedies differ.

## Public addresses reported by a server

`SelfAddr` supports servers reached through a private route even though the
machine itself has a public interface address.

- The shared status manifest exposes interface addresses in its `ip` field on
  the extended polling cadence.
- SSH and Monitor transports populate the same status field. A Monitor-only
  server does not need a `full_access` grant or an `/exec` request.
- `SelfAddr.publicIn` parses, deduplicates, and removes non-public addresses.
  When both address families are available, `SelfAddr.pick` prefers IPv4 as a
  stable tie-break for dual-stack servers.
- A positive result—or the fact that no public address exists—is stored by
  server id with a timestamp. It becomes eligible for refresh after seven
  days.

What is stored is the address, never the resulting coordinate. The coordinate
belongs to the public address, but the `selfReported` source describes how one
specific server supplied that address — stored under the public host, that label
would be applied to every other server behind the same address. Storing the
address instead keeps the one fact only the machine knows and leaves the lookup
to be redone from whatever dataset is installed.

A machine behind NAT with only private interface addresses cannot be placed by
this path. It requires a manual coordinate.

## City dataset

### Manifest and consent

The app does not bundle or automatically fetch the dataset. After the user taps
**Download** from the globe or settings, `GeoDataInstall` runs the shared flow.
It calls `GeoData.fetchManifest` before the final confirmation dialog so the
dialog can show current values rather than compiled estimates. The settings row
shows download progress inline; other entry points use a modal progress dialog.

The manifest provides:

- format version and build month;
- attribution text;
- asset name and address family;
- compressed and uncompressed sizes; and
- SHA-256 of each compressed asset.

Parsing rejects unsupported versions, malformed months, missing or duplicate
address families, unsafe names, invalid or oversized lengths, and malformed digests.
Asset names must match a restricted character and length pattern and must not
contain `..`, because they are used in both a URL and a local path.

The dialog shows total download size and total installed size separately. It
also displays the primary endpoint and attribution before enabling confirmation.

### Installation and failure handling

`GeoData.install` removes the existing dataset before writing a replacement.
For each asset it:

1. enforces a receive-size limit while downloading;
2. checks the compressed length and SHA-256;
3. decompresses the asset with gzip;
4. checks the uncompressed length; and
5. writes the bundle and, after all assets succeed, the installed manifest.

Any failure removes the partial installation. This avoids presenting an
apparently valid globe with only one address family available, but it also means
a failed update leaves no older dataset installed.

The primary endpoint is `ipgeo.lollipopkit.com`. A GitHub Releases URL is used
as a fallback when the primary endpoint does not return usable data. The digest
detects corruption or truncation; it is not a signature because the manifest
and assets come from the same endpoint.

### Bundle format

Each address family uses one big-endian `SBGX` bundle:

```text
magic "SBGX"          4 B
format                1 B   == 1
family                1 B   == 4 or 6
year u16, month u8    3 B
count u32             4 B
reserved              3 B   zero, padding the header to 16 B
bucket table          (2^bucketBits + 1) × u32
records               count × (offset + lat i16 + lon i16)
```

IPv4 uses a 32-bit key bucketed by its first 8 bits; its record offset is 3
bytes and each record is 7 bytes. IPv6 stores the first 48 bits and buckets by
the first 16; its record offset is 4 bytes and each record is 8 bytes. A `/48`
is therefore the finest IPv6 distinction the format can represent.

Records are sorted within each bucket. A lookup performs a binary search for
the last record whose start offset does not exceed the address. Coordinates are
quantized as signed 16-bit values; latitude `-32768` is reserved to mean that no
location is allocated for the range.

`GeoBundle.open` checks the magic, format, build month, family, monotonic table
boundaries, and exact file length before accepting a bundle. The family and
build month are read from the header and compared with the installed manifest,
rather than inferred from the filename.

Only the header and bucket table remain in memory—about 1 KB for IPv4 and 256 KB
for IPv6. Record reads are small and synchronous against an open file, allowing
the operating system page cache to serve them without keeping the roughly 52 MB
dataset resident in the Dart heap. Synchronous access also avoids unresolved
real-I/O futures inside Flutter widget tests' fake-async zones.

## What is stored

| Store | Key | Value |
|---|---|---|
| `SelfAddrStore` | Server id | Reported public address or an explicit miss, plus probe time |

That is the whole list. It is derived, device-local state: it does not update
the app's user data modification timestamp and is not synced or backed up.

**No coordinate is stored.** A `GeoStore` keyed by connection host used to
cache them, and it was removed with the per-lookup network requests it was
written for. Once the complete dataset is on the device, a lookup needs only
about a dozen very small synchronous reads from an already-open file. Adding a
database row read and JSON decode would add work while preserving stale results:
an installed dataset update would not move a cached host, and a hostname record
would not notice that DNS now resolves it elsewhere. `m019_drop_geo_cache`
deletes those obsolete rows when an existing installation upgrades.

`SelfAddrStore` stays because it is not a cache of a computed coordinate. Only
the server knows which public address is assigned to one of its interfaces. The
store keeps that address rather than its coordinate, so the coordinate always
follows the installed dataset. After `staleAfter` (7 days), the record becomes
eligible to be refreshed by a later status poll.

Losing the cache costs one thing: a name-addressed server is no longer placed
while the device is offline, since the resolver cannot answer and nothing is
held back to answer with. Those servers are unreachable in that state anyway.

## Rendering and interaction

- `projection.dart` maps coordinates through the globe camera and excludes
  points on the far side.
- `layout.dart` separates overlapping fixed-size cards and returns leader lines
  to their markers.
- `painter.dart` draws the sphere, land, markers, and leader lines, fading
  markers and lines near the horizon.
- At more than `labelLimit` located items—14 by default—only the selected item
  receives a card. The first marker tap selects it; the second opens it.
- Automatic longitude rotation runs while at least one located server is on the
  far side. The first user interaction disables automatic rotation for that
  `GlobeView` instance.
- Drag inertia integrates decay using elapsed time, so behavior is consistent
  across refresh rates. Zoom is multiplicative, and mouse-wheel or trackpad
  pointer signals are handled separately from touch gestures.

The initial camera faces the first located server in the current list. Later
resolution results do not re-center a view the user has already moved.

## Diagnostics

Globe instrumentation uses redacted, structured breadcrumbs. It records coarse
actions and counts—for example opening or closing the view, dataset outcomes,
placement counts by source, and whether a card or marker opened a server. It
does not include coordinates, addresses, server names, or countries.

At the **Full information** diagnostic level, these breadcrumbs can also be
sent as feature-use events. At **Basic information**, relevant breadcrumbs may
accompany an error report, but they are not streamed as analytics events. See
the [privacy policy](/docs/privacy/) for the complete diagnostic behavior.
