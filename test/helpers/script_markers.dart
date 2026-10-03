/// The script protocol's segment markers, as the parser recognises them.
///
/// `sbm_parser::script` owns these; this is the same format written out for
/// fixtures that have to look like a server's output. It used to be an FFI
/// call (`scriptSegmentMarker` / `customResultKey`), which the app itself
/// never made — only these tests — so the bindings carried two functions
/// nothing shipped called.
///
/// A marker is only recognised as `<separator>.b64.<base64url name>`, and
/// anything else in the same stream is data. That is why a name is encoded at
/// all: custom commands run arbitrary user shell, so a command that printed
/// `SrvBoxSep.cpu` would otherwise have opened a section (see
/// `crates/sbm_parser/src/script.rs`).
///
/// A hardcoded format is the point as much as the cost: if the protocol's
/// separators or encoding ever move, these fixtures stop matching and the
/// tests fail here rather than following the parser silently.
library;

import 'dart:convert';

/// Built-in command sections, e.g. `SrvBoxSep.b64.dGltZQ==` for `time`.
const scriptSegmentSeparator = 'SrvBoxSep';

/// Custom-command sections, e.g. `SrvBoxCusCmdSep.b64.eA==` for `x`.
const customSegmentSeparator = 'SrvBoxCusCmdSep';

/// The marker line opening a segment: [custom] picks the custom namespace.
String scriptSegmentMarker(String key, {bool custom = false}) =>
    '${custom ? customSegmentSeparator : scriptSegmentSeparator}'
    '.b64.${base64Url.encode(utf8.encode(key))}';

/// The key one custom command's output is filed under.
///
/// Namespaced rather than the bare name, so a custom command called `cpu`
/// cannot overwrite the built-in section of that name.
String customResultKey(String name) => '$customSegmentSeparator.$name';
