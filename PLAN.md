# 监控项插件化改造方案（App + `server_box_monitor` HTTP API）

## 摘要

把现有“内置监控 + customCmds 文本输出”升级为“内置监控 + 可插拔插件监控”：

1. 内置实现（当前 `cmd_types.dart`）保留，可禁用后由插件补位。  
2. 插件支持两种来源：`command` 与 `inline`（`inline` 强制 shebang，按 shebang 原样执行）。  
3. 插件数据协议统一为 JSON item 数组，支持 `text/kv/percent/pie/line`（`line` 多序列，App 端累计历史 120 点）。  
4. 优先走 monitor HTTP API（Docker 友好）；不可用时自动降级到 SSH 远端文件自管。  
5. 旧 `customCmds` 启动时自动迁移为插件，旧入口替换为 Plugins 入口。  

## 对外接口与类型变更

### 1) 插件配置模型（Flutter）

新增插件配置模型（建议新建文件）：
`lib/data/model/server/plugin_models.dart`

全局模板（SettingStore）：

```json
[
  {
    "id": "amd.plugin",
    "title": "AMD Plugin",
    "enabled": true,
    "source": "command",
    "command": "/usr/local/bin/amd_plugin",
    "script": "#!/usr/bin/env python3\n...",
    "timeoutSec": 5,
    "hideInDetail": false
  }
]
```

单机覆盖（ServerCustom）：

```json
[
  { "id": "amd.plugin", "enabled": false },
  { "id": "vendor.foo", "source": "inline", "script": "#!/usr/bin/env bash\n...", "timeoutSec": 8 }
]
```

单机插件顺序（拖拽结果）：

```json
["vendor.foo", "amd.plugin"]
```

ID 规则：

- 格式：`[a-z0-9._-]+`
- 全量唯一（含内置保留 ID）
- 保存冲突时阻止并提示冲突列表
- item id 必须以前缀 `pluginId.` 开头（如 `amd.plugin.gpu0`）

保留特殊插件 ID：

- `server_card_top_right`：仅用于首页卡片右上角，不在详情页出卡片

### 2) 插件输出协议（脚本/monitor 执行结果）

统一返回“item 数组”：

```json
[
  { "id": "amd.plugin.util", "title": "GPU Util", "kind": "percent", "data": { "value": 73.5, "unit": "%" } },
  { "id": "amd.plugin.mem", "title": "VRAM", "kind": "pie", "data": { "segments": [ { "name": "used", "value": 8 }, { "name": "free", "value": 16 } ], "unit": "GB" } },
  { "id": "amd.plugin.temp", "title": "Temp", "kind": "line", "data": { "series": [ { "name": "gpu0", "value": 65.2 } ], "unit": "°C" } },
  { "id": "amd.plugin.note", "title": "Driver", "kind": "text", "data": { "value": "amdgpu 6.8" } },
  { "id": "amd.plugin.meta", "title": "Meta", "kind": "kv", "data": { "rows": [ { "key": "pci", "value": "0000:03:00.0" } ] } }
]
```

渲染与校验：

- `percent/pie` 越界值渲染前夹紧并记 warning
- 本轮失败：保留上次成功值并标记 `stale/error`
- 返回空数组：显示空态提示

### 3) Monitor HTTP API（`server_box_monitor`）

最终协议：HTTP，不用 CLI。  
鉴权：Bearer Token（可选）。  
路径前缀：`/api/v1`。  
执行接口：`POST /api/v1/plugins/execute`，支持 `ids` 过滤。

建议端点：

- `GET /api/v1/plugins`
- `PUT /api/v1/plugins/:id`
- `DELETE /api/v1/plugins/:id`
- `POST /api/v1/plugins/execute`

执行返回：

- 直接返回 item 数组（与上面协议一致）

URL/Token 来源：

- 全局默认 + 单机覆盖
- 全局默认 URL：`http://{ssh_host}:3770`
- 支持单机 `ignore cert`

### 4) 降级链路（无 monitor 或 monitor API 不可用）

自动降级到 App 自管远端文件：

- 插件文件目录：`scriptDir/plugins/`
- 连接时按 hash 增量下发
- 删除/禁用插件时自动清理远端陈旧文件
- 严格使用当前 SSH 用户权限，不自动 sudo

---

## 实施步骤（按里程碑）

### 1) 数据层与迁移

修改：

- `lib/data/model/server/custom.dart`
- `lib/data/model/server/server_private_info.dart`
- `lib/data/store/setting.dart`
- `lib/main.dart`

动作：

1. 新增全局插件模板、monitor 全局 URL/token 配置。  
2. 在 `ServerCustom` 增加单机覆盖、单机插件顺序、monitor 单机覆盖（url/token/ignoreCert）。  
3. 启动迁移：`customCmds -> server-local text 插件`。  
4. 冲突迁移策略：自动加 `legacy.` 前缀保留数据。  
5. 迁移后清空旧 `cmds`，记录迁移完成标记。  

### 2) 执行引擎与合并逻辑

修改：

- `lib/data/provider/server/single.dart`
- `lib/data/model/server/server.dart`
- `lib/data/model/server/server_status_update_req.dart`

新增：

- `lib/data/provider/server/plugin_engine.dart`
- `lib/data/provider/server/monitor_api_client.dart`
- `lib/data/model/server/plugin_runtime.dart`

动作：

1. 计算“有效插件集”：全局模板 + 单机覆盖（按 id 覆盖/禁用）+ 单机顺序。  
2. 校验 ID 唯一性（含内置保留 ID）。  
3. 优先 monitor HTTP 执行插件，失败自动降级 SSH。  
4. 解析 item 数组并更新插件运行态（含 stale、历史曲线、错误状态）。  
5. 首页右上角读取 `server_card_top_right` 插件值。  

### 3) UI 与交互

修改：

- `lib/view/page/server/edit/widget.dart`
- `lib/view/page/server/edit/actions.dart`
- `lib/view/page/server/detail/view.dart`
- `lib/view/page/server/tab/utils.dart`
- `lib/view/page/setting/entries/server.dart`

动作：

1. 服务器编辑页：把旧 Custom Commands 入口替换为 Plugins 入口。  
2. 增加 `More > Plugin Order`（单机拖拽排序，按插件）。  
3. 详情页以 `custom` 卡位为锚点展开“每插件一张卡片”。  
4. 插件卡内渲染 `text/kv/percent/pie/line`。  
5. `server_card_top_right` 不在详情页出卡片。  

### 4) `server_box_monitor` HTTP API

修改：

- `packages/server_box_monitor/model/config.go`
- `packages/server_box_monitor/runner/runner.go`
- `packages/server_box_monitor/web/web.go`
- `packages/server_box_monitor/web/base.go`

新增：

- `packages/server_box_monitor/model/plugin.go`
- `packages/server_box_monitor/web/plugin.go`
- `packages/server_box_monitor/model/plugin_exec.go`

动作：

1. 扩展 monitor 配置：可选 API token、插件定义持久化。  
2. 新增插件 CRUD + execute API。  
3. execute 实现：超时控制、shebang 执行、JSON item 校验与聚合返回。  
4. 鉴权中间件：token 配置时启用 Bearer 校验。  

### 5) 文档与说明

修改：

- `docs/src/content/docs/advanced/custom-commands.md`
- `docs/src/content/docs/zh/advanced/custom-commands.md`
- `docs/src/content/docs/advanced/widgets.md`
- `docs/src/content/docs/zh/advanced/widgets.md`

动作：

1. 新增插件协议文档与 JSON 示例。  
2. 明确 monitor API 与降级路径。  
3. 标注 `server_card_top_right` 新语义。  

---

## 测试与验收场景

### Dart 侧

1. 合并规则：全局 + 单机覆盖 + 禁用 + 顺序。  
2. ID 校验：格式、前缀、全量唯一。  
3. 启动迁移：旧 customCmds 正确迁移，冲突加 `legacy.`。  
4. 执行链路：monitor 成功、monitor 失败降级 SSH、SSH 失败仅插件报错。  
5. 渲染协议：5 种 kind 正确展示。  
6. line 历史：多序列累计与 120 点窗口裁剪。  
7. stale 策略：失败保留上次值并标记。  
8. top_right：仅首页显示，不在详情页显示。  

### Go 侧（monitor）

1. 插件 CRUD 正常读写。  
2. `execute` 支持全量和 `ids` 过滤。  
3. token 可选鉴权生效。  
4. inline shebang 执行与 command 执行均可用。  
5. timeout 生效。  
6. 非法 JSON、非法 id 前缀、空数组返回行为符合约定。  

---

## 显式假设与默认值

1. 内置监控保留，不做“内置全部插件化”重构。  
2. 插件替代内置走“禁用内置 + 新 id 插件补位”。  
3. monitor API 为新增能力，旧 monitor 自动降级 SSH 自管。  
4. 插件执行默认超时 5 秒，支持单插件覆盖。  
5. 无 shebang 的 inline 脚本视为非法配置。  
6. 插件卡片排序粒度为“插件级”，不是 item 级。  
7. 新出现插件默认追加到末尾。  
8. 详情卡全局顺序中继续使用 `custom` 作为插件区锚点。  
