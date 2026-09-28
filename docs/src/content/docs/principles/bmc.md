---
title: BMC Overview
description: What out-of-band management provides and its current scope
---

SSH and Monitor agent work through the host operating system. If the host is
powered off, stuck, or rebooting, those connections may be unavailable. A BMC
(Baseboard Management Controller) is a separate computer on the motherboard
with its own power and network connection, so it can still report hardware
state and accept power requests.

Server Box connects to BMCs through Redfish, an HTTPS API used by modern
servers. IPMI-only devices are not supported because the App does not include
an IPMI client.

## What BMC can provide

- Host power state, even while the operating system is unavailable
- Hardware sensor readings such as temperatures, fan speeds, and power draw
- Hardware power operations, including power on, graceful shutdown or restart,
  force off, and power cycle, when the device exposes those actions

BMC is a separate management path alongside SSH and Monitor HTTP. It is not a
replacement for normal server access. A phone on an isolated management
network must be able to reach the BMC directly; Monitor agent cannot relay
BMC connections.

## Current verification

:::caution[Beta]
Power state and sensors have been read from one real device. Power control has
not been covered by automated verification. Compatibility with other vendors
and models has not been established.

Treat a power action like pressing the server's physical power button.
:::

The device used for the read-path check was an **H3C R5350 G6** with Redfish
1.15.1. Its BMC used a self-signed certificate and exposed the legacy
`Thermal` and `Power` sensor resources. This is a record of one test device,
not a compatibility list. See [BMC implementation details](/docs/development/bmc/)
for the observed responses and implementation behavior.

## Certificate trust

BMCs commonly use self-signed certificates. Server Box asks you to compare the
certificate fingerprint with the value shown by the BMC's own web interface.
After you accept it, the App trusts only that fingerprint. If it changes,
verify the device before accepting the replacement; a firmware update and a
man-in-the-middle attack can produce the same change.

For setup steps and the available controls, see the [BMC user guide](/docs/advanced/bmc/).
