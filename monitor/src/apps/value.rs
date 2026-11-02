//! A component's values as JSON, both ways, by the function's WIT types:
//! what the frame sends as a call's parameters and gets as its answer.
//!
//! | WIT | JSON |
//! |---|---|
//! | a function, its parameters | by name, camelCase (`as-root` is `asRoot`), parameters as one object |
//! | `bool`, integers, floats | boolean, number (64-bit integers beyond 2⁵³ lose precision in a browser) |
//! | `char`, `string` | string |
//! | `list<T>`, `tuple<…>` | array |
//! | `record` | object, fields in camelCase |
//! | `enum` | string, camelCase |
//! | `flags` | array of strings, camelCase |
//! | `variant` | `{ "tag": "<case>", "val": … }` (`val` absent for a case without payload) |
//! | `option<T>` | `null` or the value |
//! | `result<T, E>` | `{ "ok": … }` or `{ "err": … }` |
//!
//! Resources, streams, futures, maps and an `option` directly inside an
//! `option` (whose `null` would be ambiguous) are not offered: [`check`]
//! refuses a function that has them.

use serde_json::{Map, Value};
use wasmtime::component::{Type, Val};

const MAX_DEPTH: usize = 64;

/// `kebab-case` as JSON names it: `cache-folder` → `cacheFolder`.
pub fn camel(name: &str) -> String {
    let mut out = String::with_capacity(name.len());
    let mut upper = false;
    for c in name.chars() {
        if c == '-' {
            upper = true;
        } else if upper {
            out.extend(c.to_uppercase());
            upper = false;
        } else {
            out.push(c);
        }
    }
    out
}

/// Whether [ty] crosses as JSON; the first that does not, named.
pub fn check(ty: &Type) -> Result<(), String> {
    check_at(ty, 0)
}

fn check_at(ty: &Type, depth: usize) -> Result<(), String> {
    if depth > MAX_DEPTH {
        return Err("nested too deep".into());
    }
    let next = depth + 1;
    match ty {
        Type::Bool
        | Type::S8
        | Type::U8
        | Type::S16
        | Type::U16
        | Type::S32
        | Type::U32
        | Type::S64
        | Type::U64
        | Type::Float32
        | Type::Float64
        | Type::Char
        | Type::String
        | Type::Enum(_)
        | Type::Flags(_) => Ok(()),
        Type::List(l) => check_at(&l.ty(), next),
        Type::FixedLengthList(l) => check_at(&l.ty(), next),
        Type::Record(r) => r.fields().try_for_each(|f| check_at(&f.ty, next)),
        Type::Tuple(t) => t.types().try_for_each(|t| check_at(&t, next)),
        Type::Variant(v) => v.cases().try_for_each(|c| c.ty.map_or(Ok(()), |t| check_at(&t, next))),
        Type::Option(o) => match o.ty() {
            Type::Option(_) => Err("option<option<…>>".into()),
            inner => check_at(&inner, next),
        },
        Type::Result(r) => {
            r.ok().map_or(Ok(()), |t| check_at(&t, next))?;
            r.err().map_or(Ok(()), |t| check_at(&t, next))
        }
        Type::Map(_) => Err("map".into()),
        Type::Own(_) | Type::Borrow(_) => Err("resource".into()),
        Type::Future(_) | Type::Stream(_) | Type::ErrorContext => Err("async value".into()),
    }
}

/// [v] as [ty]; the path to what does not fit when it does not.
pub fn from_json(ty: &Type, v: &Value) -> Result<Val, String> {
    from_json_at(ty, v, "$")
}

/// [v] as parameter [name]'s type.
pub fn from_json_at_param(ty: &Type, v: &Value, name: &str) -> Result<Val, String> {
    from_json_at(ty, v, &format!("$.{name}"))
}

fn int<T: TryFrom<i64> + TryFrom<u64>>(v: &Value, at: &str) -> Result<T, String> {
    let bad = || format!("{at}: not an integer in range");
    if let Some(n) = v.as_u64() {
        return T::try_from(n).map_err(|_| bad());
    }
    if let Some(n) = v.as_i64() {
        return T::try_from(n).map_err(|_| bad());
    }
    Err(bad())
}

fn from_json_at(ty: &Type, v: &Value, at: &str) -> Result<Val, String> {
    let wrong = |what: &str| format!("{at}: expected {what}");
    Ok(match ty {
        Type::Bool => Val::Bool(v.as_bool().ok_or_else(|| wrong("a boolean"))?),
        Type::S8 => Val::S8(int(v, at)?),
        Type::U8 => Val::U8(int(v, at)?),
        Type::S16 => Val::S16(int(v, at)?),
        Type::U16 => Val::U16(int(v, at)?),
        Type::S32 => Val::S32(int(v, at)?),
        Type::U32 => Val::U32(int(v, at)?),
        Type::S64 => Val::S64(int(v, at)?),
        Type::U64 => Val::U64(int(v, at)?),
        Type::Float32 => Val::Float32(v.as_f64().ok_or_else(|| wrong("a number"))? as f32),
        Type::Float64 => Val::Float64(v.as_f64().ok_or_else(|| wrong("a number"))?),
        Type::Char => {
            let s = v.as_str().ok_or_else(|| wrong("a character"))?;
            let mut chars = s.chars();
            match (chars.next(), chars.next()) {
                (Some(c), None) => Val::Char(c),
                _ => return Err(wrong("one character")),
            }
        }
        Type::String => Val::String(v.as_str().ok_or_else(|| wrong("a string"))?.to_string()),
        Type::List(l) => {
            let items = v.as_array().ok_or_else(|| wrong("an array"))?;
            let ty = l.ty();
            Val::List(items.iter().enumerate().map(|(i, v)| from_json_at(&ty, v, &format!("{at}[{i}]"))).collect::<Result<_, _>>()?)
        }
        Type::FixedLengthList(l) => {
            let items = v.as_array().ok_or_else(|| wrong("an array"))?;
            if items.len() != l.len() as usize {
                return Err(wrong(&format!("{} items", l.len())));
            }
            let ty = l.ty();
            Val::FixedLengthList(items.iter().enumerate().map(|(i, v)| from_json_at(&ty, v, &format!("{at}[{i}]"))).collect::<Result<_, _>>()?)
        }
        Type::Record(r) => {
            let obj = v.as_object().ok_or_else(|| wrong("an object"))?;
            let fields: Vec<_> = r.fields().collect();
            if let Some(extra) = obj.keys().find(|k| !fields.iter().any(|f| camel(f.name) == **k)) {
                return Err(format!("{at}: unknown field {extra}"));
            }
            Val::Record(
                fields
                    .iter()
                    .map(|f| {
                        let name = camel(f.name);
                        let value = obj.get(&name).unwrap_or(&Value::Null);
                        from_json_at(&f.ty, value, &format!("{at}.{name}")).map(|v| (f.name.to_string(), v))
                    })
                    .collect::<Result<_, _>>()?,
            )
        }
        Type::Tuple(t) => {
            let items = v.as_array().ok_or_else(|| wrong("an array"))?;
            let types: Vec<_> = t.types().collect();
            if items.len() != types.len() {
                return Err(wrong(&format!("{} items", types.len())));
            }
            Val::Tuple(types.iter().zip(items).enumerate().map(|(i, (t, v))| from_json_at(t, v, &format!("{at}[{i}]"))).collect::<Result<_, _>>()?)
        }
        Type::Variant(var) => {
            let obj = v.as_object().ok_or_else(|| wrong("{ tag, val }"))?;
            let tag = obj.get("tag").and_then(Value::as_str).ok_or_else(|| wrong("a tag"))?;
            let case = var.cases().find(|c| camel(c.name) == tag).ok_or_else(|| format!("{at}: unknown tag {tag}"))?;
            let payload = match &case.ty {
                Some(t) => Some(Box::new(from_json_at(t, obj.get("val").unwrap_or(&Value::Null), &format!("{at}.val"))?)),
                None => None,
            };
            Val::Variant(case.name.to_string(), payload)
        }
        Type::Enum(e) => {
            let s = v.as_str().ok_or_else(|| wrong("a string"))?;
            Val::Enum(e.names().find(|n| camel(n) == s).ok_or_else(|| format!("{at}: unknown value {s}"))?.to_string())
        }
        Type::Flags(f) => {
            let items = v.as_array().ok_or_else(|| wrong("an array"))?;
            let names: Vec<&str> = f.names().collect();
            Val::Flags(
                items
                    .iter()
                    .map(|v| {
                        let s = v.as_str().ok_or_else(|| wrong("strings"))?;
                        names.iter().find(|n| camel(n) == s).map(|n| n.to_string()).ok_or_else(|| format!("{at}: unknown flag {s}"))
                    })
                    .collect::<Result<_, _>>()?,
            )
        }
        Type::Option(o) => match v {
            Value::Null => Val::Option(None),
            v => Val::Option(Some(Box::new(from_json_at(&o.ty(), v, at)?))),
        },
        Type::Result(r) => {
            let obj = v.as_object().ok_or_else(|| wrong("{ ok } or { err }"))?;
            let side = |t: Option<Type>, key: &str| -> Result<Option<Box<Val>>, String> {
                match t {
                    Some(t) => Ok(Some(Box::new(from_json_at(&t, obj.get(key).unwrap_or(&Value::Null), &format!("{at}.{key}"))?))),
                    None => Ok(None),
                }
            };
            if obj.contains_key("ok") {
                Val::Result(Ok(side(r.ok(), "ok")?))
            } else if obj.contains_key("err") {
                Val::Result(Err(side(r.err(), "err")?))
            } else {
                return Err(wrong("{ ok } or { err }"));
            }
        }
        Type::Map(_) | Type::Own(_) | Type::Borrow(_) | Type::Future(_) | Type::Stream(_) | Type::ErrorContext => {
            return Err(format!("{at}: not offered as JSON"));
        }
    })
}

/// What the guest answered, as JSON.
pub fn to_json(v: &Val) -> Value {
    match v {
        Val::Bool(b) => Value::Bool(*b),
        Val::S8(n) => (*n).into(),
        Val::U8(n) => (*n).into(),
        Val::S16(n) => (*n).into(),
        Val::U16(n) => (*n).into(),
        Val::S32(n) => (*n).into(),
        Val::U32(n) => (*n).into(),
        Val::S64(n) => (*n).into(),
        Val::U64(n) => (*n).into(),
        Val::Float32(f) => serde_json::Number::from_f64(*f as f64).map_or(Value::Null, Value::Number),
        Val::Float64(f) => serde_json::Number::from_f64(*f).map_or(Value::Null, Value::Number),
        Val::Char(c) => Value::String(c.to_string()),
        Val::String(s) => Value::String(s.clone()),
        Val::List(items) | Val::Tuple(items) | Val::FixedLengthList(items) => Value::Array(items.iter().map(to_json).collect()),
        Val::Record(fields) => Value::Object(fields.iter().map(|(k, v)| (camel(k), to_json(v))).collect()),
        Val::Variant(tag, payload) => {
            let mut obj = Map::new();
            obj.insert("tag".into(), Value::String(camel(tag)));
            if let Some(p) = payload {
                obj.insert("val".into(), to_json(p));
            }
            Value::Object(obj)
        }
        Val::Enum(name) => Value::String(camel(name)),
        Val::Flags(names) => Value::Array(names.iter().map(|n| Value::String(camel(n))).collect()),
        Val::Option(o) => o.as_deref().map_or(Value::Null, to_json),
        Val::Result(r) => {
            let (key, side) = match r {
                Ok(v) => ("ok", v),
                Err(v) => ("err", v),
            };
            let mut obj = Map::new();
            obj.insert(key.into(), side.as_deref().map_or(Value::Null, to_json));
            Value::Object(obj)
        }
        // Refused by `check` before any call.
        Val::Map(_) | Val::Resource(_) | Val::Future(_) | Val::Stream(_) | Val::ErrorContext(_) => Value::Null,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names_are_camel_case() {
        assert_eq!(camel("cache-folder"), "cacheFolder");
        assert_eq!(camel("a-b-c"), "aBC");
        assert_eq!(camel("plain"), "plain");
    }

    #[test]
    fn answers_become_json() {
        let v = Val::Record(vec![
            ("at".into(), Val::S64(5)),
            ("items".into(), Val::List(vec![Val::Record(vec![
                ("is-ok".into(), Val::Bool(true)),
                ("group".into(), Val::Enum("system-wide".into())),
                ("count".into(), Val::Option(None)),
                ("kind".into(), Val::Variant("file-count".into(), Some(Box::new(Val::U32(3))))),
                ("bare".into(), Val::Variant("none-here".into(), None)),
            ])])),
            ("done".into(), Val::Result(Ok(None))),
        ]);
        assert_eq!(
            to_json(&v),
            serde_json::json!({
                "at": 5,
                "items": [{ "isOk": true, "group": "systemWide", "count": null, "kind": { "tag": "fileCount", "val": 3 }, "bare": { "tag": "noneHere" } }],
                "done": { "ok": null },
            })
        );
    }
}
