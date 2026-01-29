---
title: Network Tools
description: Network testing and diagnostic tools
---

Server Box includes several network tools for testing and diagnostics.

## iPerf

Perform network speed tests between your device and server.

### Features

- **Upload/Download Speed**: Test bandwidth
- **Server Mode**: Use server as iPerf server
- **Client Mode**: Connect to iPerf servers
- **Custom Parameters**: Duration, parallel streams, etc.

### Usage

1. Open a server
2. Tap **iPerf**
3. Choose server or client mode
4. Configure parameters
5. Start test

## Ping

Test network connectivity and latency.

### Features

- **ICMP Ping**: Standard ping tool
- **Packet Count**: Specify number of packets
- **Packet Size**: Custom packet size
- **Interval**: Time between pings

### Usage

1. Open a server
2. Tap **Ping**
3. Enter target host
4. Configure parameters
5. Start pinging

## Wake on LAN

Wake up remote servers via magic packet.

### Features

- **MAC Address**: Target device MAC
- **Broadcast**: Send broadcast magic packet
- **Saved Profiles**: Store WoL configurations

### Requirements

- Target device must support Wake-on-LAN
- WoL must be enabled in BIOS/UEFI
- Device must be in sleep/soft-off state
- Device must be on the same network or reachable via broadcast

## Tips

- Use iPerf to diagnose network bottlenecks
- Ping multiple hosts to compare latency
- Save WoL profiles for frequently woken devices
