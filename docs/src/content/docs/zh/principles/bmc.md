---
title: BMC(Redfish)
description: 主机不响应时,带外管理怎么够到这台服务器
---

:::caution[未在真实硬件上验证]
Phase 1 已经实现。还没发生的是对着真正的 BMC 跑一次——下面每一条厂商差异都是对着录下来的响应和一台
本地 TLS 服务器处理的,这足以确信那些**判断**,不足以确信一台**机器**。电源控制尤其从未由任何自动化
执行过,这是刻意的:见 `test/bmc_power_test.dart` 的头注释。
:::

这个 App 够到服务器的其他每一条路,都要求主机操作系统还活着。SSH 需要 sshd,monitor agent 是机器上的
一个进程。主机断电、卡死、或者正在重启时,它们报的是同一件事——连接失败——App 再说不出别的。

BMC 是另一条路。它是主板上一台独立供电、独立网口的小计算机,在机器上其他东西都不可达时依然可达。
它能回答三个主机无法回答的关于自己的问题:电源状态、硬件传感器读数、硬件事件日志。

## 为什么是 Redfish 而不是 IPMI

| | Redfish | IPMI 2.0 over LAN |
|---|---|---|
| 传输 | HTTPS + JSON | RMCP+ over UDP 623,二进制 |
| 在这个仓库里的成本 | `dio`,不需要原生代码 | 没有 Dart 实现,要在 `crates/` 写客户端过 FFI |
| 数据模型 | 自描述、可遍历 | SDR / SEL / chassis 命令,再往外是厂商私有的 raw 字节 |
| 认证 | TLS + 会话令牌 | RAKP,有固件修不了的弱点 |
| 硬件覆盖 | 大约 2016 年及以后 | 更老的和入门级的也能覆盖 |
| 规范状态 | 活跃 | 最后一次修订在 2013 年 |

IPMI 剩下的优势是 Redfish 之前的硬件和 Serial-over-LAN。这两样都不值得为它引入一个 FFI 客户端和
第二套安全模型,所以 **IPMI 不实现,也不在计划里**。如果 Redfish 之前的硬件后来真的重要,那是一个
需要自己论证的新决定,不是这件事的某个阶段。

## 它在模型里的位置

BMC 不是够到主机的方式,所以不在 `ServerConnectCredential` 那条轴上——那条轴回答的是「这台服务器的
**状态**从哪来」,轴上每种 transport 有一个 `ServerCapabilities` 实现。而 BMC 回答的是主机不在时的事。

它是侧信道,建模方式和已有的 Wake-on-LAN 一致:挂在 `Spi` 上的一个可选嵌套配置,和 `wolCfg` 同级。

```dart
class Spi {
  SshCredential? ssh;
  MonitorHttpCredential? monitorHttp;
  WakeOnLanCfg? wolCfg;
  BmcCfg? bmc;          // ← 没配置时为 null
}

final class BmcCfg {
  String addr;          // https://...
  String user;
  String? pwd;
  String? certSha256;   // 首次见到时钉住 —— 见下
}
```

嵌套而不是像 PVE 那三个设置一样平铺在 `ServerCustom` 里:平铺表达不了「没配置」,而这正是当初把 SSH
那些字段抽成 `SshCredential` 的原因。

## 分层

这样切是为了让值得测的那一半不需要一台服务器。

```
BmcCfg                    用户配置的东西
  ↓
RedfishClient             传输层:TLS 信任、会话生命周期、GET/POST
  ↓
RedfishService            一次性发现并缓存:哪些 id、哪套 schema
  ↓
redfish/*.dart(纯函数)    JSON → 类型化模型,不做 IO
  ↓
BmcNotifier(riverpod)     状态,以及它自己的轮询周期
```

只有 `RedfishClient` 碰网络。它下面的每一层都是「拿一个解析好的 JSON map,返回一个模型」,这让厂商差异
能对着保存下来的响应测,而不是对着硬件测。

## TLS:首次使用即信任,而不是「忽略证书」

BMC 一律自签证书。这个 App 里已经有两处遇到自签 HTTPS 端点——monitor agent 和 PVE——两处都给用户一个
开关,把 `badCertificateCallback` 设成接受一切。

这里不沿用。BMC 位于管理网络上,而且握着电源控制;对它关掉校验,意味着接受那个地址上任何东西给出的
任何证书。

改成和这个 App 已有的 SSH host key 一样(`HostKeyVerifier`):首次见到时,在用户同意后记下证书的
SHA-256 指纹;之后指纹变了就再问一次,并把新旧都列出来;拒绝从不落盘。这个校验器写成可复用的,方便
PVE 和 monitor agent 以后采用——但改它们的行为是另一个决定,不是这一页的事。

## 各家有哪些不一样

这一节里的每一条,都是必须**发现**而不能假设的东西。硬编码其中任何一条的客户端,在写它时那台机器上能用,
在下一台上就不行。

### 资源 id 不固定

只有服务根这一个路径是固定的。往下,system 和 chassis 的 id 各家不同:

| 厂商 | 典型的 system id |
|---|---|
| Supermicro | `1` |
| Dell iDRAC | `System.Embedded.1` |
| OpenBMC | `system` |

所以客户端要遍历 `/redfish/v1/Systems`、读集合的 `Members`,而不是拼路径。

### 传感器有两套模型,而且可能同时存在

Redfish 2020.4 弃用了 `Chassis/{id}/Thermal` 和 `/Power`,改用 `ThermalSubsystem`、`PowerSubsystem`
和统一的 `Sensors` 集合。固件比规范落后好几年,而且各家进度不一——Supermicro 是从 X14 世代才切的,
所以 X11 到 X13 仍然是旧模型。

过渡期的固件**两套都有**。规则:看 `Chassis` 资源实际有哪些 link,有新的用新的,没有再退回旧的,
永远不要从厂商名字推断。

### `ResetType` 广告了,不等于实现了

`ComputerSystem.Reset` 接受一个 `ResetType`,而某个服务实际接受哪些值,写在这个 action 的
`ResetType@Redfish.AllowableValues` 里。各家不同,而且 `Nmi` 和 `PowerCycle` 尤其常见于「广告了但
没实现,或者要 license」。

所以一个意图——「重启这台机器」——要映射到该服务允许的值上,并带降级链;映射不到任何值的意图,
UI 里干脆不提供。

### HPE iLO 的 graceful 是建议性的

HPE 文档写明 `GracefulShutdown` 和 `GracefulRestart` 的行为取决于 OS,而且 iLO 不在 OS 层区分这两者。
所以 `204 No Content` 的意思是「请求被接受了」,不是「有什么事发生了」。

电源操作靠轮询 `PowerState` 直到它变化或超时来确认——HTTP 状态码不是结果。

### 会话会泄漏,而且上限很低

Redfish 的会话认证是 `POST` 到 `SessionService/Sessions`,拿回一个 `X-Auth-Token`。没有被删除的会话
会一直留在 BMC 上直到超时,而 BMC 允许的并发会话很少——泄漏够多就会把管理界面整个锁死,直到超时或者
有人去手动重置 BMC。

所以:一个 client 只登录一次,client 被销毁时 `DELETE` 掉会话资源,失败路径和正常路径一样要走到。
对服务根做一次不需要认证的探测,则完全不需要建会话。

### License 会门禁掉一部分

Supermicro 的 `SFT-OOB-LIC` / `SFT-DCMS-SINGLE` 门禁的是固件更新和虚拟媒体这类,不是读取;实践中
X11 到 X13 上只读 GET 和 `ComputerSystem.Reset` 不需要它们——但这是实践经验,不是写死的厂商政策。

也就是说,子资源上的 `401` 或 `403` 是一个需要如实报告的普通答案,不是 bug,也不构成让整次抓取失败的理由。

## 轮询

BMC 很慢,一次热数据抓取可能要好几秒。所以它有自己的周期,不搭在状态轮询上——和扩展状态命令从快轮询里
切出去(`_extendedStatusInterval`)是同一个做法。

发现的结果——哪些 id、哪套传感器模型、有哪些 reset 类型——每个 client 只做一次并缓存。每次轮询都重新推导
一遍,恰恰是这类设备最负担不起的开销。

## Phase 1 覆盖什么

- 探测:`GET /redfish/v1/` 以及它下面的集合
- `Systems/{id}`:电源状态、机型、序列号、BIOS 版本、健康汇总
- `Chassis/{id}`:温度、风扇转速、功耗,走固件实际提供的那套传感器模型
- `ComputerSystem.Reset`,带确认对话框,reset 类型经过协商,结果靠轮询确认

不在 Phase 1:事件日志、存储清单、启动项覆盖、虚拟媒体,以及为那些手机路由不到的管理网络上的 BMC
通过 monitor agent 中继 Redfish。
