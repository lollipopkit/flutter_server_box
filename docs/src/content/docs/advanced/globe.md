---
title: Globe View
description: View servers by location and manage the on-device location data
---

The server tab can display your servers on an interactive globe instead of in
the grid. Tap the globe icon above the server list to switch views. Server Box
remembers the last view you used.

The feature is enabled by default. To remove the globe button and stop location
resolution, turn off **Settings → Server → General → Globe**. Disabling the
feature does not delete the downloaded city dataset. To remove it, use
**Delete** on the **City-level data** row.

## How a server gets a location

Server Box uses the first available source in this order:

| Priority | Source | Requirement |
|---|---|---|
| 1 | Coordinates you entered | Set in the server editor under **More → Location** |
| 2 | A public address reported by the server | Used when Server Box connects through a private address; the downloaded city dataset is still required |
| 3 | The address used for the connection | The downloaded city dataset is required |

All geolocation lookups use files on this device. Server addresses are not sent
to a geolocation API. If a server is configured with a hostname, the device may
resolve it through its configured DNS service, just as it does when connecting
to that server.

### Servers reached through a private network

A VPS reached through a VPN or an internal hostname may still have a public IP
address on one of its interfaces. The normal status poll already reports those
interface addresses over SSH or through a
[Monitor agent](/docs/advanced/monitor-agent/). Server Box selects a public
address and looks it up in the local city dataset; it does not run an additional
command or contact an external "what is my IP" service.

A home server behind NAT usually reports only private addresses. In that case,
only a manually entered location can place it on the globe.

## Download city-level data

The city dataset is not bundled with Server Box and is never downloaded
automatically.

1. Open the globe and tap **Download** beside the unplaced servers. You can
   also open **Settings → Server → General → Globe** and tap **Download**
   on the **City-level data** row.
2. Server Box fetches a small manifest so it can show the current download
   size, installed size, source URL, and attribution.
3. Review the confirmation dialog. The data files are downloaded only after you
   accept.

The current dataset is typically about 25 MB to download and 52 MB after
installation. The confirmation dialog reads both values from the manifest, so
its figures are authoritative if these estimates change.

- IPv4 and IPv6 data are both city-level.
- The dataset is updated monthly. When data is already installed, tap
  **Update** in settings to check for a newer version.
- Installing a newer version replaces the existing files; it does not keep an
  additional copy.
- Tap **Delete** to remove the dataset from the device.

The download host can observe that your network requested the manifest or data
files. After installation, it receives no requests for individual lookups and
cannot learn which server addresses you query or when you query them. See the
[privacy policy](/docs/privacy/#globe-and-location-data) for the complete data
flow.

Without the city dataset, only servers with manually entered coordinates can be
placed.

## Servers without a coordinate

Servers that cannot be placed appear as chips along the bottom of the globe.
Tap a chip to open that server's editor and enter a location.

- **Private address** — Server Box connects through a LAN, loopback, or
  link-local address, or through a hostname that resolves to one. Public
  geolocation datasets cannot locate these addresses.
- **No location data** — The hostname could not be resolved, the installed
  dataset has no matching record, or the city dataset has not been installed.

When every unplaced server has the same reason, that reason is also shown above
the row of chips.

## Enter a location manually

In the server editor, open **More** and enter **Location (lat, lon)**. Put
latitude first and longitude second, in degrees—for example,
`39.9042, 116.4074`. A comma or whitespace can separate the two values.

Latitude must be between -90 and 90, and longitude between -180 and 180. Server
Box rejects an invalid value when you save instead of silently discarding it.
A manual location has the highest priority and is not replaced by an automatic
lookup.

## Use the globe

- Drag to rotate it. A quick flick continues with momentum.
- Pinch to zoom. On desktop, use a mouse wheel or trackpad gesture.
- The globe rotates slowly while a located server is hidden on the far side.
  The first touch stops automatic rotation for the rest of that view.
- A server card shows its name and CPU and memory usage after readings arrive;
  while connecting, it shows the connection state.
- Marker colors indicate status: green when readings are available, orange
  while connecting, red after a failed connection, and gray when disconnected.
- Tap a card or marker to open the server.
- When more than 14 located servers are displayed, the globe shows markers
  without permanent cards. Tap a marker once to label it and again to open it.

The globe initially faces the first server in the current list that has a
coordinate.

## When a location looks wrong

Coordinates are not cached. Each lookup uses the dataset currently installed
on the device, so installing a newer monthly release immediately changes what
the globe draws, with nothing to clear.

For a server reached through a private address, Server Box may remember the
public interface address that the server reported for itself. Once that record
is seven days old, a later ordinary status poll can refresh it. To correct a
location immediately, set the coordinate in the server editor under **More →
Location**; a manual coordinate overrides every automatic source.

For implementation details, see
[Globe and Location Resolution](/docs/principles/globe/).
