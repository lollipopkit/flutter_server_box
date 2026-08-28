---
title: BMC（Redfish）
description: BMC 功能的设计、限制和硬件兼容性
---

:::caution[Beta]
目前只有读取功能（电源状态和传感器）在一台真实设备上验证过；电源控制尚未进行自动化验证。以下硬件差异主要来自厂商文档、录制的响应和本地测试服务，不能视为硬件兼容列表。

请把电源操作当作按下远程服务器上的物理电源按钮。
:::

SSH 和 Monitor agent 都要求主机操作系统正常运行：SSH 需要 `sshd`，Monitor agent 需要在主机上运行进程。主机断电、卡死或重启时，二者通常只能报告连接失败。

BMC（Baseboard Management Controller）是主板上的独立计算机，拥有独立供电和网络接口。主机上的其他服务不可用时，BMC 仍可能响应。它可以提供电源状态、硬件传感器读数和硬件事件等主机操作系统无法提供的信息。

## 为什么选择 Redfish

Server Box 通过 Redfish 的 HTTPS/JSON API 与 BMC 通信。Redfish 是现代服务器常见的带外管理接口。

| | Redfish | IPMI 2.0 over LAN |
|---|---|---|
| 传输 | HTTPS + JSON | RMCP+ over UDP 623，二进制协议 |
| 在本项目中的实现成本 | `dio` 即可实现，不需要原生代码 | 没有 Dart 实现，需要通过 FFI 在 `crates/` 中实现客户端 |
| 数据模型 | 自描述资源，可通过链接遍历 | SDR、SEL、chassis 命令及厂商自定义 raw 数据 |
| 认证 | TLS + session token | RAKP |
| 硬件覆盖 | 通常为 2016 年及之后的设备 | 还覆盖更早和入门级设备 |
| 规范状态 | 持续更新 | 最近一次修订在 2013 年 |

IPMI 的优势主要是支持更早的硬件和 Serial-over-LAN。当前项目暂不引入 IPMI 客户端；如果未来需要覆盖 Redfish 之前的设备，需单独评估 FFI 客户端和另一套安全模型。

## 在应用模型中的位置

BMC 是主机的带外管理通道，属于服务器配置中的独立侧通道。服务器的 SSH 和 Monitor HTTP 配置决定状态数据和常规操作从哪里获取；BMC 用于主机操作系统不可用时读取硬件状态和执行电源操作。

BMC 配置挂在 `Spi` 上，与 Wake-on-LAN 的 `wolCfg` 同级：

```dart
class Spi {
  SshCredential? ssh;
  MonitorHttpCredential? monitorHttp;
  WakeOnLanCfg? wolCfg;
  BmcCfg? bmc;          // 未配置 BMC 时为 null
}

final class BmcCfg {
  String addr;          // https://...
  String? credId;       // 多台服务器共用 BmcCredential
  String? certSha256;   // 用户确认后固定
}

class BmcCredential {
  String id;            // 生成的 ID，不是显示名称
  String name;          // 选择器中显示的唯一名称
  String user;
  String? pwd;
}
```

BMC 账户是独立记录，按 ID 引用。机架中的多台服务器通常共用一组 BMC 账户，因此修改一次账户即可更新所有引用它的服务器。删除账户使用 `ON DELETE SET NULL`，这样不会连带删除服务器配置。

地址和证书 fingerprint 属于单台 BMC，应保存在 `BmcCfg` 中。不同 BMC 可能使用不同证书；将 fingerprint 放在共享账户记录中会导致一台设备的 fingerprint 被错误地用于验证另一台设备。

物理主机和虚拟机可能共同指向一台 BMC。此时从任意虚拟机执行电源操作都会影响整台物理主机，读到的 `PowerState` 也是主机状态。当前模型不处理这种 host/guest 关系，建议只在物理主机记录上配置 BMC。

## 分层设计

分层的目标是让可由 fixture 验证的代码不依赖真实服务器：

```text
BmcCfg + BmcCredential    用户配置                       App
  ↓
RedfishClient             TLS 信任、session、GET/POST     package:redfish
RedfishDiscovery          一次性发现资源和 reset 类型      package:redfish
resources / sensors       JSON → model，不执行 IO          package:redfish
  ↓
BmcNotifier               状态和独立轮询周期               App
```

只有 `RedfishClient` 访问网络。下层解析组件接收已获取的 JSON map 并返回 model，因此厂商差异可以通过保存的响应测试，而不必每次连接真实硬件。

## TLS 和首次使用信任

BMC 通常使用自签名证书。BMC 具有电源控制权限，接受地址上的任意证书会允许其他服务冒充 BMC，因此这里采用与 SSH host key 类似的首次使用信任机制：

1. 首次连接时显示证书的 SHA-256 fingerprint。
2. 你在 BMC 自带的 Web 界面中核对 fingerprint，并确认是否信任。
3. App 保存已确认的 fingerprint，后续只接受匹配的证书。
4. fingerprint 变化时拒绝连接，显示新旧值并要求重新确认。

BMC 重新生成证书或升级固件后，fingerprint 可能正常变化；中间人攻击也会造成相同现象。接受新证书前，请先确认 BMC 的身份。

## 厂商差异

以下内容都需要通过 Redfish 资源发现，不能根据厂商名称或常见路径硬编码。不同固件可能实现不同版本的资源模型。

### 资源 ID 不固定

`/redfish/v1/` 是固定入口，但 `Systems` 和 `Chassis` 下的 ID 由厂商决定：

| 厂商 | 典型的 system ID |
|---|---|
| Supermicro | `1` |
| Dell iDRAC | `System.Embedded.1` |
| OpenBMC | `system` |

客户端应遍历 `/redfish/v1/Systems`，读取集合返回的 `Members`，然后访问具体资源。

### 传感器模型可能有两套

Redfish 2020.4 将 `Chassis/{id}/Thermal` 和 `/Power` 标记为旧模型，推荐使用 `ThermalSubsystem`、`PowerSubsystem` 和统一的 `Sensors` 集合。许多固件仍然只实现旧模型，也有固件同时提供两套模型。

客户端应检查 `Chassis` 资源实际提供的 links：优先使用完整的新模型，缺少新模型时再使用旧模型。不要根据厂商名称推断模型。

### `ResetType` 的声明可能不可靠

`ComputerSystem.Reset` action 会通过 `ResetType@Redfish.AllowableValues` 声明支持的值。不同设备支持的值不同；`Nmi` 和 `PowerCycle` 尤其可能因固件实现或 license 限制而不可用。

App 将“重启”“电源循环”等用户意图映射到设备声明的值，并为必要操作提供降级顺序。找不到可用值时，不显示对应按钮。

### 厂商可能扩展 `ResetType`

H3C R5350 G6 会声明标准枚举中不存在的 `ForcePowerCycle`，同时不声明其他断电操作。只匹配标准名称会错误地把“电源循环”映射为 `ForceRestart`。

因此每个用户意图的候选列表会在标准名称之后包含已知的厂商扩展名称。扩展名称来自实际设备响应，不能只根据规范推断。

### 传感器可能返回哨兵值

规范建议没有读数时返回 `null`，但有些固件会返回哨兵值。例如测试过的 H3C 设备将无法读取的温度返回 `4294967295`（`0xFFFFFFFF`）。

App 按合理范围过滤读数，而不是只匹配已知哨兵值；当前过滤范围不会接受低于绝对零度或高于 1000°C 的温度，也不会接受不合理的风扇转速。`-1` 保留，因为它既可能是哨兵值，也可能是真实的低温读数。

### Graceful 操作只表示请求已接受

HPE iLO 文档说明 `GracefulShutdown` 和 `GracefulRestart` 的行为取决于操作系统。`204 No Content` 只能说明请求已被接受，不能证明操作系统已经执行。

App 会轮询 `PowerState`，直到观察到状态变化或达到超时。HTTP status code 不作为电源操作结果。

### Session 数量有限

Redfish session 通过 `POST` 到 `SessionService/Sessions` 创建，并在响应中返回 `X-Auth-Token`。未删除的 session 会在 BMC 上保留到超时；BMC 的并发 session 数量通常很少，泄漏过多可能导致管理界面拒绝新连接。

每个 client 只创建一个 session，并在销毁时 `DELETE` 对应资源。正常路径和失败路径都必须释放 session。只探测服务根资源时无需创建 session。

### License 可能限制功能

部分 Supermicro license 会限制固件更新和虚拟介质等功能。测试表明，某些 X11 到 X13 设备的只读 GET 和 `ComputerSystem.Reset` 不需要这些 license；这属于设备经验，不代表所有型号的固定政策。

子资源返回 `401` 或 `403` 时，App 应如实报告该资源不可用，并继续处理其他资源。

## 轮询

BMC 的响应通常比操作系统 API 慢，一次传感器读取可能需要几秒。因此 BMC 使用独立的轮询周期，不与常规服务器状态轮询共用计时器。

资源 ID、传感器模型和可用 reset 类型属于每个 client 的 discovery 结果，只发现一次并缓存。每次轮询只读取和转换实时数据，避免重复请求设备结构。

## Phase 1 范围

- 探测 `GET /redfish/v1/` 及其集合
- 读取 `Systems/{id}`：电源状态、机型、序列号、BIOS 版本和健康汇总
- 读取 `Chassis/{id}`：温度、风扇转速和功耗，使用设备提供的传感器模型
- 调用 `ComputerSystem.Reset`：显示确认对话框，协商 reset 类型，并通过轮询确认结果

暂不支持事件日志、存储清单、启动项覆盖、虚拟介质，以及通过 Monitor agent 中继访问隔离网络中的 BMC。

## 已验证硬件

下表记录的是已经实际响应过的设备，不是兼容性列表。其他行为来自厂商文档、录制的响应和本地测试服务。

| 项目 | 值 |
|---|---|
| 型号 | H3C R5350 G6 |
| BIOS | 6.30.50 |
| Redfish 版本 | 1.15.1 |
| 根节点 `Vendor` / `Product` | 两者都缺失，不能依赖它们识别服务 |
| System ID | `Systems/1` |
| Chassis ID | `Chassis/1` |
| 传感器模型 | legacy（`Thermal` + `Power`）；`Sensors` 有链接但 `ThermalSubsystem` 不完整，因此使用旧模型 |
| `ResetType` | `ForceOff`、`ForcePowerCycle`、`ForceRestart`、`GracefulShutdown`、`Nmi`、`On` |
| 温度 | 20 个，其中 18 个返回 `0xFFFFFFFF` 哨兵值 |
| 风扇 | 8 个位置，每个位置返回两条不同读数 |
| 整机功耗 | `PowerControl` 返回 48 W |
| Session | 一个 client 保持一个 session，关闭时释放 |
| 证书 | 自签名，测试时在有效期内 |
| 测试时间 | 2026-08-23 |

尚未覆盖 Dell（`System.Embedded.1`）、OpenBMC（`system`）、Supermicro X11–X14 的传感器模型差异、HPE iLO 的 graceful 操作，以及提供多个 system 的设备。

## 如何验证真实硬件

### 只读测试

`packages/redfish/test/e2e_test.dart` 是 opt-in 的只读测试。工作区根目录的 `.env` 中设置以下变量后才会连接真实设备；未设置时会静默跳过：

```bash
SBM_E2E_BMC_URL=https://10.0.0.9
SBM_E2E_BMC_USER=...
SBM_E2E_BMC_PWD=...
```

测试会打印发现到的资源 ID、传感器模型、reset 类型和每个用户意图的映射结果，不会断言某个厂商必须使用某种形状。它会读取 reset action，但不会向 action 发送 POST。

### 电源操作

电源控制没有自动化测试。手工验证时，请使用不承载重要业务的设备：

1. 配置 BMC，并核对证书 fingerprint。
2. 确认 App 显示的电源状态与设备实际状态一致。
3. 点击**重启**，在确认对话框中核对协商得到的 `ResetType`。
4. 检查结果是 *confirmed* 还是 *accepted*。对于 iLO 的 graceful 操作，*accepted* 是合理结果；对于明确区分请求和结果的设备，*accepted* 表示尚未观察到状态变化，需要进一步检查。
