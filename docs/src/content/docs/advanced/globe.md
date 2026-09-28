---
title: Globe View
description: View servers by location and manage the on-device location data
---

The server tab offers two layouts: the server grid and an interactive globe.
Select the globe icon above the server list to switch to it. Server Box opens
the view you used most recently the next time you visit.

Globe view is enabled by default. Turn off **Settings → Server → General →
Globe** to hide its button and stop location lookups. This keeps the downloaded
city dataset on the device. To delete the files as well, select **Delete** on
the **City-level data** row.

## How a server gets a location

Server Box checks these sources in order and uses the first available location:

| Priority | Source | Requirement |
|---|---|---|
| 1 | Coordinates you entered | Set in the server editor under **More → Location** |
| 2 | A public address reported by the server | Used when Server Box connects through a private address; the downloaded city dataset is still required |
| 3 | The address used for the connection | The downloaded city dataset is required |

Location lookups use the dataset stored on this device; Server Box does not
send server addresses to a geolocation API. A configured hostname may still be
resolved through your device's DNS service, as it is when connecting to the
server.

### Servers reached through a private network

A VPS accessed through a VPN or internal hostname may still have a public IP
on one of its network interfaces. The regular status poll already collects
interface addresses over SSH or through a
[Monitor agent](/docs/advanced/monitor-agent/). Server Box selects a public
address and looks it up in the local city dataset; it does not run an additional
command or contact an external "what is my IP" service.

A home server behind NAT usually reports only private addresses. In that case,
only a manually entered location can place it on the globe.

## Download city-level data

Server Box does not bundle the city dataset or download it automatically. You
choose when to install it:

1. Open the globe and tap **Download** beside the unplaced servers. You can
   also open **Settings → Server → General → Globe** and tap **Download**
   on the **City-level data** row.
2. Server Box fetches a small manifest so it can show the current download
   size, installed size, source URL, and attribution.
3. Review the confirmation dialog. The data files are downloaded only after you
   accept.

The dataset currently downloads about 25 MB and uses about 52 MB when
installed. These are estimates; the confirmation dialog reads the latest sizes
from the manifest and shows the values to use if they change.

- IPv4 and IPv6 data are both city-level.
- The dataset is updated monthly. When data is already installed, tap
  **Update** in settings to check for a newer version.
- Installing a newer version replaces the existing files; it does not keep an
  additional copy.
- Tap **Delete** to remove the dataset from the device.

The download host can see requests for the manifest and dataset files. Once
the files are installed, lookups happen locally and do not generate requests to
that host, so it cannot see which server addresses you look up or when. See the
[privacy policy](/docs/privacy/#globe-and-location-data) for the complete data
flow.

Without the city dataset, only servers with manually entered coordinates can be
placed.

## Servers without a coordinate

Servers without a usable coordinate appear as chips along the bottom of the
globe. Select a chip to edit that server's location.

- **Private address** — Server Box connects through a LAN, loopback, or
  link-local address, or through a hostname that resolves to one. Public
  geolocation datasets cannot locate these addresses.
- **No location data** — The hostname could not be resolved, the installed
  dataset has no matching record, or the city dataset has not been installed.

When every unplaced server has the same reason, that reason is also shown above
the row of chips.

## Enter a location manually

In the server editor, open **More** and fill in **Location (lat, lon)**. Enter
latitude first and longitude second, in degrees. For example:
`39.9042, 116.4074`. Separate the values with a comma or whitespace.

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

Server Box does not cache lookup results. Each lookup uses the dataset
currently installed on the device, so updating the monthly dataset changes
the displayed location immediately.

For a server reached through a private address, Server Box may remember the
public interface address that the server reported for itself. Once that record
is seven days old, a later ordinary status poll can refresh it. To correct a
location immediately, set the coordinate in the server editor under **More →
Location**; a manual coordinate overrides every automatic source.

For implementation details, see
[Globe and Location Resolution](/docs/principles/globe/).
