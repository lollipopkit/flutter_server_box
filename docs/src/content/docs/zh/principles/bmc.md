---
title: BMC 概述
description: 带外管理的用途和当前支持范围
---

SSH 和 Monitor agent 都依赖主机操作系统运行。主机关机、卡死或重启时，
这些连接可能无法访问。BMC（Baseboard Management Controller）是主板上的
独立计算机，拥有自己的电源和网络连接，因此操作系统不可用时仍可能上报
硬件状态并接受电源操作。

Server Box 通过现代服务器常用的 HTTPS API——Redfish——连接 BMC。当前
App 不包含 IPMI client，因此只支持 IPMI 的设备无法使用此功能。

## BMC 能提供什么

- 操作系统不可用时读取主机电源状态
- 读取温度、风扇转速和功耗等硬件传感器数据
- 执行开机、优雅关机或重启、强制断电和电源循环等操作；具体操作取决于设备支持情况

BMC 是 SSH 和 Monitor HTTP 之外的独立管理通道，不会取代常规服务器连接。
如果 BMC 位于隔离的管理网络，手机必须能够直接访问它；Monitor agent 不能
中继 BMC 连接。

## 当前验证情况

:::caution[Beta]
目前只在一台真实设备上读取过电源状态和传感器；电源控制尚未经过自动化验证，
也尚未确认其他厂商和型号的兼容性。

请把电源操作当作按下服务器上的物理电源按钮。
:::

已验证读取路径的设备是 **H3C R5350 G6**，Redfish 版本为 1.15.1。它使用
自签名证书，并提供旧版 `Thermal` 和 `Power` 传感器资源。这只是单台测试设备
的记录，不代表兼容性列表。更多响应与实现细节见
[BMC 实现说明](/docs/zh/development/bmc/)。

## 证书信任

BMC 通常使用自签名证书。Server Box 会提示你将证书 fingerprint 与 BMC 自带
Web 界面显示的值核对。确认后，App 只信任该 fingerprint。若 fingerprint
发生变化，请先核实设备再接受新证书；固件更新和中间人攻击都可能导致相同变化。

配置步骤和操作选项见 [BMC 使用指南](/docs/zh/advanced/bmc/)。
