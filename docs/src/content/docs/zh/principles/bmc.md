---
title: BMC(Redfish)
description: 主机不响应时,带外管理怎么够到这台服务器
---

:::caution[读取部分在一台机器上验证过,电源控制一台都没有]
Phase 1 已经实现,读取部分已经对着真实固件跑过——见[跑过的硬件](#跑过的硬件),就一个型号。
下面其余每一条厂商差异仍然是对着录下来的响应和一台本地 TLS 服务器处理的:足以确信那些**判断**,
不足以确信一台**机器**。

电源控制从未由任何自动化执行过,这是刻意的。见 `test/bmc_power_test.dart` 的头注释。
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
  String? credId;       // → BmcCredential,多台服务器共用
  String? certSha256;   // 用户审阅后钉住 —— 见下
}

class BmcCredential {   // 独立的表,独立的 sync root
  String id;            // 生成的;不是名字
  String name;          // 唯一,选择器里显示的就是它
  String user;
  String? pwd;
}
```

嵌套而不是像 PVE 那三个设置一样平铺在 `ServerCustom` 里:平铺表达不了「没配置」,而这正是当初把 SSH
那些字段抽成 `SshCredential` 的原因。

账户是独立记录,按 id 引用。BMC 是整机架一起开的,共用一个目录服务或同一个出厂密码,所以常态是多台服务器
对一个账户——存在每台服务器上就意味着一台机器填一遍、轮换密码时一台机器改一遍,而且除了「某台机器不响应了」
之外没有办法知道漏了哪台。引用是 `ON DELETE SET NULL`:删掉账户不能把用它的服务器一起删掉。

留在 `BmcCfg` 上的是属于单台设备的东西。地址是显然的;证书指纹没那么显然:两个 BMC 不可能出示同一张证书,
指纹放在共享记录里等于拿第一台的指纹去验第二台,也就是这个校验根本没发生。

共用**账户**不等于共用**同一个 BMC**。若干台 guest 跑在同一台物理机上时,它们指向的是同一个设备——在其中
任何一台上执行电源操作会切掉全部,而读回来的 `PowerState` 是宿主机的而不是 guest 的。那是 host/guest 关系,
不是存储问题,这里不建模。

## 分层

这样切是为了让值得测的那一半不需要一台服务器。

```
BmcCfg + BmcCredential    用户配置的东西
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

### `ResetType` 可能是规范里没有的名字

一台 H3C R5350 G6 广播的是 `ForcePowerCycle`——这个名字不在 Redfish 的 `ResetType`
枚举里，而它没有广播任何其它能切断电源的类型。只匹配标准名的话，电源循环意图会回落到
`ForceRestart`，那是另一个操作，在一个写着"电源循环"的按钮下面。

所以每个意图的候选列表在标准名之后带上厂商扩展名作为回落。这是实测出来的，不是读出来
的：这类问题只有真机回应时才会出现。

### 传感器"没有读数"时未必返回 null

规范建议无读数的传感器返回 `null`。有些固件改为发送哨兵值。同一台 H3C 对每一个读不到
的温度返回 `4294967295`——即 `0xFFFFFFFF`，无符号 -1——它的 20 个温度传感器里有 18 个
如此。原样透传会以 `4294967295 Cel` 出现在界面上。

因此读数按**合理性范围**过滤，而不是匹配已知哨兵值：下一家用的是 `65535` 或 `127`，
枚举永远差一个。没有任何真实读数落在被排除的区间——绝对零度以下或一千度以上不是机箱
传感器的读数，也没有风扇转到四十亿转。

这里有一个刻意保留的限制：`-1` 既是某些固件的哨兵值，也是冷通道进风的真实读数，所以
它被保留。为了掩盖一个假数据而删掉一条真实测量，是两种错误里更糟的那个，也是唯一没人
看得见的那个。

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

## 跑过的硬件

就一台,这一点值得说准确:下表是**已经回应过**的机器,不是**支持列表**。本页其余内容来自厂商文档和
录制的响应,那是另一种性质的把握——[厂商之间的差异](#厂商之间的差异)里标注为实测的那两条来自这里,
而它们都是读多少文档也不会发现的。

| | |
| --- | --- |
| 型号 | H3C R5350 G6 |
| BIOS | 6.30.50 |
| Redfish 版本 | 1.15.1 |
| 根节点的 `Vendor` / `Product` | **两者都缺失**——不要靠它们识别服务 |
| System id | `Systems/1` |
| Chassis id | `Chassis/1` |
| 传感器模型 | legacy(`Thermal` + `Power`)。`Sensors` 有链接但 `ThermalSubsystem` 没有,所以 modern 模型并不完整,不采用它是对的 |
| 允许的 `ResetType` | `ForceOff`、`ForcePowerCycle`、`ForceRestart`、`GracefulShutdown`、`Nmi`、`On` |
| 温度 | 上报 20 个,其中 18 个是 `0xFFFFFFFF` 哨兵值 |
| 风扇 | 8 个位置,每个上报两条且读数不同——双转子,两条共用一个名字 |
| 整机功耗 | 通过 `PowerControl` 上报 48 W |
| 会话 | 一个客户端连接时开着 1 个;关闭时释放 |
| 证书 | 自签,在有效期内 |
| 测试时间 | 2026-08-23 |

**没有覆盖到**、以及谁手上有就该加一行的:Dell(`System.Embedded.1`)、OpenBMC(`system`)、
Supermicro X11–X13 与 X14 的对比(传感器模型切换点)、HPE iLO 的优雅操作,以及任何会公布
多个 system 的机器。

## 怎么对着真实硬件验证

上面所有内容都是对着录下来的厂商响应和一台本地 TLS 服务器验证的——这确定了那些**判断**,没有确定任何
一台**机器**。剩下两件事需要人来做。

**读的那一半**是 `test/bmc_redfish_e2e_test.dart`,opt-in、只读。工作区根的 `.env` 里没有下面这些就静默跳过:

```
SBM_E2E_BMC_URL=https://10.0.0.9
SBM_E2E_BMC_USER=...
SBM_E2E_BMC_PWD=...
```

它把发现的东西**打印**出来,而不是断言某个形状——这家用的 id、固件呈现的是哪套传感器模型、广告了哪些
reset 类型、每个意图解析成什么。第四种 id 形状是需要知道的事,不是失败。它会**读**那个 reset action,
**从不向它 POST**。

**电源那一半没有自动化形式,也不会有。** 手工验证的话,在一台没人用的机器上:

1. 给那台服务器配好 BMC 并确认证书。
2. 确认卡片显示的电源状态和机器一致。
3. 按**重启**。对话框会写出协商到的 `ResetType`——核对它是不是这台硬件应该拿到的那个。
4. 看报告的结果是 *confirmed* 还是 *accepted*。iLO 上 graceful 操作报 accepted 是合理的;在会区分这两者的
   硬件上,accepted 意味着机器没动,值得查。
