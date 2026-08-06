// The MIT License (MIT)
//
// Copyright (c) 2013-2019 Khan Academy and other contributors
// Copyright (c) 2020 znjameswu <znjameswu@gmail.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

/// Converted from KaTeX/src/katex.less

import 'dart:ui';

import '../../ast/options.dart';

// Map<String, FontOptions> _fontOptionsTable;
// Map<String, FontOptions> get fontOptionsTable {
//   if (_fontOptionsTable != null) return _fontOptionsTable;
//   _fontOptionsTable = {};
//   _fontOptionsEntries.forEach((key, value) {
//     for (final name in key) {
//       _fontOptionsTable[name] = value;
//     }
//   });
//   return _fontOptionsTable;
// }

// const _fontOptionsEntries = {
//   // Text font weights.
//   ['textbf']: FontOptions(
//     fontWeight: FontWeight.bold,
//   ),

//   // Text font shapes.
//   ['textit']: FontOptions(
//     fontShape: FontStyle.italic,
//   ),

//   // Text font families.
//   ['textrm']: FontOptions(fontFamily: 'Main'),

//   ['textsf']: FontOptions(fontFamily: 'SansSerif'),

//   ['texttt']: FontOptions(fontFamily: 'Typewriter'),

//   // Math fonts.
//   ['mathdefault']: FontOptions(
//     fontFamily: 'Math',
//     fontShape: FontStyle.italic,
//   ),

//   ['mathit']: FontOptions(
//     fontFamily: 'Main',
//     fontShape: FontStyle.italic,
//   ),

//   ['mathrm']: FontOptions(
//     fontFamily: 'Main',
//     fontShape: FontStyle.normal,
//   ),

//   ['mathbf']: FontOptions(
//     fontFamily: 'Main',
//     fontWeight: FontWeight.bold,
//   ),

//   ['boldsymbol']: FontOptions(
//     fontFamily: 'Math',
//     fontWeight: FontWeight.bold,
//     fontShape: FontStyle.italic,
//     fallback: [
//       FontOptions(
//         fontFamily: 'Math',
//         fontWeight: FontWeight.bold,
//       )
//     ],
//   ),

//   ['amsrm']: FontOptions(fontFamily: 'AMS'),

//   ['mathbb', 'textbb']: FontOptions(fontFamily: 'AMS'),

//   ['mathcal']: FontOptions(fontFamily: 'Caligraphic'),

//   ['mathfrak', 'textfrak']: FontOptions(fontFamily: 'Fraktur'),

//   ['mathtt']: FontOptions(fontFamily: 'Typewriter'),

//   ['mathscr', 'textscr']: FontOptions(fontFamily: 'Script'),

//   ['mathsf', 'textsf']: FontOptions(fontFamily: 'SansSerif'),

//   ['mathboldsf', 'textboldsf']: FontOptions(
//     fontFamily: 'SansSerif',
//     fontWeight: FontWeight.bold,
//   ),

//   ['mathitsf', 'textitsf']: FontOptions(
//     fontFamily: 'SansSerif',
//     fontShape: FontStyle.italic,
//   ),

//   ['mainrm']: FontOptions(
//     fontFamily: 'Main',
//     fontShape: FontStyle.normal,
//   ),
// };

// const fontFamilyFallback = ['Main', 'Times New Roman', 'serif'];

const texMathFontOptions = {
  // Math fonts.
  // 'mathdefault': FontOptions(
  //   fontFamily: 'Math',
  //   fontShape: FontStyle.italic,
  // ),

  '\\mathit': FontOptions(
    fontFamily: 'Main',
    fontShape: FontStyle.italic,
  ),

  '\\mathrm': FontOptions(
    fontFamily: 'Main',
    fontShape: FontStyle.normal,
  ),

  '\\mathbf': FontOptions(
    fontFamily: 'Main',
    fontWeight: FontWeight.bold,
  ),

  '\\boldsymbol': FontOptions(
    fontFamily: 'Math',
    fontWeight: FontWeight.bold,
    fontShape: FontStyle.italic,
    fallback: [
      FontOptions(
        fontFamily: 'Main',
        fontWeight: FontWeight.bold,
      )
    ],
  ),

  '\\mathbb': FontOptions(fontFamily: 'AMS'),

  '\\mathcal': FontOptions(fontFamily: 'Caligraphic'),

  '\\mathfrak': FontOptions(fontFamily: 'Fraktur'),

  '\\mathtt': FontOptions(fontFamily: 'Typewriter'),

  '\\mathscr': FontOptions(fontFamily: 'Script'),

  '\\mathsf': FontOptions(fontFamily: 'SansSerif'),
};

const texTextFontOptions = {
  '\\textrm': PartialFontOptions(fontFamily: 'Main'),
  '\\textsf': PartialFontOptions(fontFamily: 'SansSerif'),
  '\\texttt': PartialFontOptions(fontFamily: 'Typewriter'),
  '\\textnormal': PartialFontOptions(fontFamily: 'Main'),
  '\\textbf': PartialFontOptions(fontWeight: FontWeight.bold),
  '\\textmd': PartialFontOptions(fontWeight: FontWeight.normal),
  '\\textit': PartialFontOptions(fontShape: FontStyle.italic),
  '\\textup': PartialFontOptions(fontShape: FontStyle.normal),
};
