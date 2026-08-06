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

import '../../ast/types.dart';

const Map<String, Map<Mode, String?>> unicodeAccents = {
  '\u0300': {Mode.text: '\\`', Mode.math: '\\grave'},
  '\u0308': {Mode.text: '\\"', Mode.math: '\\ddot'},
  '\u0303': {Mode.text: '\\~', Mode.math: '\\tilde'},
  '\u0304': {Mode.text: '\\=', Mode.math: '\\bar'},
  '\u0301': {Mode.text: "\\'", Mode.math: '\\acute'},
  '\u0306': {Mode.text: '\\u', Mode.math: '\\breve'},
  '\u030c': {Mode.text: '\\v', Mode.math: '\\check'},
  '\u0302': {Mode.text: '\\^', Mode.math: '\\hat'},
  '\u0307': {Mode.text: '\\.', Mode.math: '\\dot'},
  '\u030a': {Mode.text: '\\r', Mode.math: '\\mathring'},
  '\u030b': {Mode.text: '\\H', Mode.math: null},
};
