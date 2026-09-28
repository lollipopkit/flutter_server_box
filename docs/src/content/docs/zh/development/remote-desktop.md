---
title: 远程桌面开发说明
description: 协议实现、代码生成与平台验证
---

## 协议引擎

RDP 和 VNC 协议引擎位于现有的 `sbm_ffi` Rust library 中：

- [IronRDP 0.17](https://github.com/Devolutions/IronRDP)，MIT OR Apache-2.0
- [vnc-rs 0.5.3](https://github.com/HsuJv/vnc-rs)，MIT OR Apache-2.0

IronRDP 只启用了所需功能。`third_party/ironrdp` submodule 指向
[lollipopkit/IronRDP fork](https://github.com/lollipopkit/IronRDP) 的 `serverbox`
branch。该 branch 保持 IronRDP 0.17 的 API 和 crate 版本不变，并包含 Server Box 所需的
transport、certificate trust 和 dependency compatibility 修改。更新时应先更新 fork，再在
本仓库中 pin 新的 commit。

目前使用跨平台 Flutter BGRA image path 渲染。后续可以替换为 native texture renderer，而
不改变 session API。

## 相关开发指南

修改 FFI API 时，请遵循[代码生成指南](/docs/zh/development/codegen/)。测试套件和平台构建
流程见[测试指南](/docs/zh/development/testing/)与[构建指南](/docs/zh/development/building/)。
