# TODOs / 后续方向

不在排期内的想法和已知缺口,先记在这里,免得丢了。

## App:直接通过 HTTP 读取服务器数据,而不是只走 SSH + shell

目前 Flutter app 读取服务器状态的唯一方式是:SSH 上去、上传并运行生成的脚本、
解析 `SrvBoxSep` 分隔的文本输出。哪怕这台服务器本来就跑着 `monitor`(它本来就
通过带鉴权的 HTTP API 暴露同样的数据——甚至更多,包括历史数据),app 也只走
这一条路径。

想法:让 app 可以选择直接通过 HTTP API(`/api/v1/status`、`/api/v1/metrics`、
`/api/v1/metrics/history`)访问服务器上的 `monitor` 实例,而不是走 SSH+shell——
前提是用户那台服务器上确实跑着 `monitor`。好处:
- 状态轮询不用再走 SSH 往返 / shell 解析——延迟更低,不用折腾脚本上传和版本管理
- 能用上 `monitor` 的历史接口(图表)和更丰富的指标(gpus/disk_details/ifaces),
  现在 SSH+shell 这条路径完全没解析这些
- 少一条要维护正确性的代码路径——SSH+shell 解析已经积累了一长串平台差异问题
  (参见 crates/sbm_parser 的 dart_compat 测试用例)

待定问题(先记下来,不是结论):
- 鉴权/配对体验:app 需要每台服务器的 `monitor` URL + 凭证(和面板那边
  `monitor/frontend/src/lib/servers.svelte.ts` 的服务器注册表是同一套思路)
- SSH 大概率还是得留着,因为有些操作 monitor 根本不提供(进程列表/结束进程、
  关机/重启/休眠、终端、SFTP)——这是在 SSH 之上做加法,不是替代
- CORS:monitor 的 `cors_allowed_origins` 是为浏览器场景(Pages 面板)设计的;
  app 不是浏览器,这个限制对它可能根本不适用——需要确认 `ntex_cors`/`Cors`
  中间件对非浏览器 HTTP 客户端的行为(Origin 头是浏览器加的,Dart 的
  `http`/`dio` 客户端不主动设置的话不会带,那大概率就和 curl 一样直接绕过
  CORS 校验、不受影响)
- app 里需要一个 `monitor` 客户端模块(存 token、配 base URL),以及怎么和现有
  的按服务器分 provider 的模型整合到一起,这个也要想清楚

## monitor:relay 模式(不强制暴露公网端口)

目前要从局域网外访问 `monitor` 面板,必须把 agent 的端口暴露到公网(端口转发/
反向代理/内网穿透)——对非技术用户是个门槛,对技术用户也是实打实的攻击面。

想法:做一个可选的"relay"模式——agent 把状态数据推送到官方(维护者)部署的
relay 服务,而不是(或者除了)在本地直接对外提供面板访问;面板改为访问 relay
而不是直连 agent,这样 agent 完全不需要开放任何入站端口。relay 侧的历史数据
上限 1 小时(只是转发/缓存,不做长期存储——完整历史仍然只能通过直连 agent
获取)。

待定问题(先记下来,不是结论):
- **鉴权/身份**:relay 需要一套独立于 agent 本地 JWT 登录的推送凭证(config.toml
  里加一个用户自己申请的 relay token,例如 `[relay] token = "..."`);面板这边
  "relay 上的哪个 agent"要怎么映射成一个服务器条目也需要单独设计 UX(大概率是
  在 `monitor/frontend/src/lib/servers.svelte.ts` 现有的直连 URL 条目旁边,加一种
  `relay://<id>` 风格的条目)
- **推 vs 拉的节奏问题**:relay 模式把数据流向倒过来了(agent 主动推,而不是
  面板轮询);现有的空闲暂停机制(`AppState.last_viewer_seen`,见
  monitor/CLAUDE.md)是靠面板直接轮询 `/metrics`/`/status` 来判断"有没有人在看"
  的——relay 模式下 agent 侧完全拿不到这个信号,除非 relay 再把"有人在看"的提示
  回传给 agent(这就多了一条控制通道,不只是数据通道了)
- **数据最小化**:是不是所有字段都要推(包括电池/传感器/SMART/主机名这些),
  还是应该让用户在 relay 模式下自己选择哪些字段不想经过 relay——哪怕 relay 是
  同一个维护者运营的官方服务
- **relay 自身的滥用/成本控制**:每个 agent 的限流、每个账号能同时推送的 agent
  数量上限、是做限量的免费版还是搞个付费版换更长的保留期——这是这个仓库里第一个
  需要维护者自己运营、自己掏钱的托管服务,和现有"纯自托管"的模式不一样
- **直连优先的混合兜底**:如果一个 agent 既能直连(同一局域网)又能走 relay,
  面板要不要自动优先直连,直连失败了才退回 relay 数据,避免非必要时依赖 relay
  (也省延迟)
- relay 是一个新的、独立部署的服务(不是 `monitor` 本身的一部分)——需要单独
  决定放哪个 crate/仓库、怎么部署、TLS/域名怎么搞,这和现在"每个 agent 一个
  单体二进制"的假设不一样,是本仓库目前唯一的例外

## macOS 每核 CPU:monitor 已支持,App 还不行

`monitor` 现在通过 `sysinfo`/Mach 的 `host_processor_info`(参见
`monitor/src/monitoring/macos_cpu.rs`)在原生运行时能拿到 macOS 真实的每核 CPU
数据。但 **app** 通过 SSH 连上 macOS 服务器时还是拿不到——macOS 上没有任何 shell
命令能暴露每核数据(htop 自己的 macOS 后端也是进程内直接调用同一个 Mach API,
不是靠 shell)。这和上面那条是同一条架构主线:如果 app 能通过 HTTP 和 `monitor`
实例通信,就能顺带白嫖到真实的每核读数,而 SSH+shell 这条路在这件事上是条死路。
