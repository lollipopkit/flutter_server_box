# Flutter Math

[![Build Status](https://travis-ci.com/znjameswu/flutter_math.svg?branch=master)](https://travis-ci.com/znjameswu/flutter_math) [![codecov](https://codecov.io/gh/znjameswu/flutter_math/branch/master/graph/badge.svg)](https://codecov.io/gh/znjameswu/flutter_math) [![Pub Version](https://img.shields.io/pub/v/flutter_math_fork)](https://pub.dev/packages/flutter_math_fork)


## ⚠ fork

This is a fork of [flutter_math](https://github.com/znjameswu/flutter_math) addressing compatibility
problems while `flutter_math` is not being maintained. 

---



Math equation rendering in pure Dart & Flutter. 


This project aims to achieve maximum compatibility and fidelity with regard to the [KaTeX](https://github.com/KaTeX/KaTeX) project, while maintaining the performance advantage of Dart and Flutter. A further [UnicodeMath](https://www.unicode.org/notes/tn28/UTN28-PlainTextMath-v3.1.pdf)-style equation editing support will be experimented in the future.


The TeX parser is a Dart port of the KaTeX parser. There are only a few unsupported features and parsing differences compared to the original KaTeX parser. List of some unsupported features can be found [here](doc/unsupported.md).

## [Online Demo](https://znjameswu.github.io/flutter_math_demo/)

## Rendering Samples

`x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}`

![Example1](https://raw.githubusercontent.com/znjameswu/flutter_math/master/doc/img/delta.png)

`i\hbar\frac{\partial}{\partial t}\Psi(\vec x,t) = -\frac{\hbar}{2m}\nabla^2\Psi(\vec x,t)+ V(\vec x)\Psi(\vec x,t)`

![Example2](https://raw.githubusercontent.com/znjameswu/flutter_math/master/doc/img/schrodinger.png)

`\hat f(\xi) = \int_{-\infty}^\infty f(x)e^{- 2\pi i \xi x}\mathrm{d}x`

![Example3](https://raw.githubusercontent.com/znjameswu/flutter_math/master/doc/img/fourier.png)


## How to use

Add `flutter_math` to your `pubspec.yaml` dependencies

### Mobile
Currently only Android platform has been tested. If you encounter any issues with iOS, please file them.

### Web
Web support is added in v0.1.6. It is tested for DomCanvas backend. In general it should behave largely the same with mobile. It is expected to break with CanvasKit backend. Check out the [Online Demo](https://znjameswu.github.io/flutter_math_demo/)

## API usage (v0.2.0)
The usage is straightforward. Just `Math.tex(r'\frac a b')`. There is also optional arguments of `TexParserSettings settings`, which corresponds to  Settings in KaTeX and support a subset of its features.

Display-style equations:
```dart
Math.tex(r'\frac a b', mathStyle: MathStyle.display) // Default
```

In-line equations
```dart
Math.tex(r'\frac a b', mathStyle: MathStyle.text)
```

The default size of the equation is obtained from the build context. If you wish to specify the size, you can use `textStyle`. Note: this parameter will also change how big 1cm/1pt/1inch is rendered on the screen. If you wish to specify the size of those absolute units, use `logicalPpi`

```dart
Math.tex(
  r'\frac a b',
  textStyle: TextStyle(fontSize: 42),
  // logicalPpi: MathOptions.defaultLogicalPpiFor(42),
)
```

There is also a selectable variant `SelectableMath` that creates selectable and copy-able equations on both mobile and web. (EXPERIMENTAL) Users can select part of the equation and obtain the encoded TeX strings. The usage is similar to Flutter's `SelectableText`.

```dart
SelectableMath.tex(r'\frac a b', textStyle: TextStyle(fontSize: 42))
```

If you would like to display custom styled error message, you should use `onErrorFallback` parameter. You can also process the errors in this function. But beware this function is called in build function.
```dart
Math.tex(
  r'\garbled $tring', 
  textStyle: TextStyle(color: Colors.green),
  onErrorFallback: (err) => Container(
    color: Colors.red,
    child: Text(err.messageWithType, style: TextStyle(color: Colors.yellow)),
  ),
)
```

If you wish to have more granularity dealing with equations, you can manually invoke the parser and supply AST into the widget.
```dart
SyntaxTree ast;
try {
  ast = SyntaxTree(greenRoot: TexParser(r'\frac a b', TexParserSettings()).parse());
} on ParseException catch (e) {
  // Handle my error here
}

SelectableMath(
  ast: ast,
  mathStyle: MathStyle.text,
  textStyle: TextStyle(fontSize: 42),
)
```

## [Line Breaking](doc/line_breaking.md)

## Credits
This project is possible thanks to the inspirations and resources from [the KaTeX Project](https://katex.org/), [MathJax](www.mathjax.org), [Zefyr](https://github.com/memspace/zefyr), and [CaTeX](https://github.com/simpleclub/CaTeX).

## Goals
- [x] : TeX math parsing (See [design doc](doc/design.md))
- [x] : AST rendering in flutter
- [x] : Selectable widget
- [x] : TeX output (WIP)
- [ ] : UnicodeMath parsing and encoding
- [ ] : [UnicodeMath](https://www.unicode.org/notes/tn28/UTN28-PlainTextMath-v3.1.pdf)-style editing
- [ ] : Breakable equations
- [ ] : MathML parsing and encoding
