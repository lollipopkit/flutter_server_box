---
title: 主题来源
description: 内置主题改编自哪些上游调色板
---

ServerBox 把下面这些 VS Code 主题的 UI 调色板改编到 Material 的表面、选中态、卡片
和按钮上。这些改编与 VS Code 扩展包无关。字体和终端/编辑器配色仍是单独的设置。
Midnight 和 AMOLED 是 ServerBox 原创的调色板。AMOLED 在 dark 下使用纯黑表面、在
light 下使用生成色，因此支持 System 外观。

入选依据是 Marketplace 上独立配色主题的安装量，已排除 icon 主题和随语言工具分发的
主题。GitHub Theme、One Dark Pro 和 Dracula 是这次比较中排名最前的三个。GitHub
Dark 使用 GitHub Theme 的 dark 调色板。

Default 是 Dart const 默认值，不需要任何 asset 或文件系统访问。
其他主题定义放在 `assets/themes/<id>/manifest.toml`，与导入的文件夹和 `.fsbt`
压缩包使用同一套 schema 和安装器。Flutter 直接打包这些源目录；Git 里不提交任何
压缩包或二进制 asset。新目录需要在 `pubspec.yaml` 注册，其选择器标签在
`ThemePackages.builtinNames`。打开选择器不加载任何主题文件；一个文件夹只在被选中
时加载，或在启动时已是保存的选择时加载。加载成功的结果会被缓存，并发请求共用一次
加载；加载失败可以重试。内置 asset 使用单独的运行时缓存，不出现在用户安装的主题
列表中。必要时会调整次要文字颜色，使正常文字的对比度不低于 4.5:1。

## 上游署名

### One Dark Pro

Source: [One Dark Pro](https://github.com/Binaryify/OneDark-Pro)

The MIT License (MIT)

Copyright (c) 2013-2022 Binaryify

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

### GitHub Theme

Source: [GitHub Theme](https://github.com/primer/github-vscode-theme)

MIT License

Copyright (c) 2020 Primer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

### Dracula

Source: [Dracula](https://github.com/dracula/visual-studio-code)

The MIT License (MIT)

Copyright (c) 2016 Dracula Theme

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
