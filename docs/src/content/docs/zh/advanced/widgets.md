---
title: 主屏幕小组件
description: 在主屏幕上添加服务器状态小组件
---

需要在服务器上安装 [ServerBox Monitor](https://github.com/lollipopkit/server_box_monitor)。

## 前置条件

请先在你的服务器上安装 ServerBox Monitor。安装说明请参考 [ServerBox Monitor Wiki](https://github.com/lollipopkit/server_box_monitor/wiki/Home)。

安装完成后，你的服务器应具备：
- HTTP/HTTPS 端点
- `/status` API 接口
- 可选的身份验证

## URL 格式

```
https://your-server.com/status
```

必须以 `/status` 结尾。

## iOS 小组件

### 设置步骤

1. 长按主屏幕 → 点击 **+**
2. 搜索 “ServerBox”
3. 选择小组件尺寸
4. 长按小组件 → **编辑小组件**
5. 输入以 `/status` 结尾的 URL

### 注意事项

- 必须使用 HTTPS（局域网 IP 除外）
- 最大刷新频率：30 分钟（iOS 系统限制）
- 可以为多个服务器添加多个小组件

## Android 小组件

### 设置步骤

1. 长按主屏幕 → **小组件**
2. 找到 “ServerBox” → 添加到主屏幕
3. 记下显示的 Widget ID 数字
4. 打开 ServerBox 应用 → 设置
5. 点击 **配置桌面小组件链接**
6. 添加条目：`Widget ID` = `状态 URL`

示例：
- 键 (Key)：`17`
- 值 (Value)：`https://my-server.com/status`

7. 点击主屏幕上的小组件进行刷新

## watchOS 小组件

### 设置步骤

1. 打开 iPhone 上的应用 → 设置
2. **iOS 设置** → **Watch 应用**
3. 点击 **添加 URL**
4. 输入以 `/status` 结尾的 URL
5. 等待手表端同步

### 注意事项

- 如果未更新，请尝试重启手表应用
- 确保手机和手表已连接

## 故障排除

### 小组件不更新

**iOS：** 等待最多 30 分钟，然后尝试删除并重新添加。
**Android：** 点击小组件强制刷新，检查设置中的 ID 是否正确。
**watchOS：** 重启手表应用，等待几分钟。

### 小组件显示错误

- 确保 ServerBox Monitor 正在运行
- 在浏览器中测试 URL 是否可用
- 检查 URL 是否以 `/status` 结尾

## 安全性

- 尽可能**始终使用 HTTPS**
- **局域网 IP** 仅建议在信任的网络中使用
