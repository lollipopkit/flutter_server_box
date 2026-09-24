# Built-in theme sources

ServerBox adapts the UI palettes of these VS Code themes to Material surfaces,
selection states, cards and buttons. These are independent adaptations, not
VS Code extension bundles. Fonts and terminal/editor color settings remain
separate. Midnight and AMOLED are original ServerBox palettes. AMOLED uses black surfaces
in dark mode and generated colors in light mode, allowing System appearance.

The selection uses Marketplace install counts for standalone color themes,
excluding icon themes and themes distributed with language tooling.
GitHub Theme, One Dark Pro and Dracula were the three leading entries in that
comparison. GitHub Dark uses the GitHub Theme dark palette.

Default is a Dart const default and needs no asset or filesystem access.
Other theme definitions are kept in `assets/themes/<id>/manifest.toml`, using the same
schema and installer as imported folders and `.fsbt` archives. Flutter bundles
the source folders directly; no archive or binary assets are checked into Git.
Register new folders in `pubspec.yaml` and their picker labels in
`ThemePackages.builtinNames`. Opening the picker loads no theme files. A folder
is loaded only when selected, or at startup if it is the saved selection.
Successful loads are cached and concurrent requests share one load; failed loads
can be retried. Built-in assets use a separate runtime cache
and do not appear among user-installed themes. Muted text colors are adjusted where
needed to keep normal text at a contrast ratio of at least 4.5:1.

## Upstream attribution

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

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
