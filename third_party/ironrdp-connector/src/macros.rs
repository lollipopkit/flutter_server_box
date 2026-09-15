/// Creates a `ConnectorError` with `General` kind
///
/// Shorthand for
/// ```rust
/// <ironrdp_connector::ConnectorError as ironrdp_connector::ConnectorErrorExt>::general(context)
/// ```
#[macro_export]
macro_rules! general_err {
    ( $context:expr $(,)? ) => {{ <$crate::ConnectorError as $crate::ConnectorErrorExt>::general($context) }};
}

/// Creates a `ConnectorError` with `Reason` kind
///
/// Shorthand for
/// ```rust
/// <ironrdp_connector::ConnectorError as ironrdp_connector::ConnectorErrorExt>::reason(context, reason)
/// ```
#[macro_export]
macro_rules! reason_err {
    ( $context:expr, $($arg:tt)* ) => {{
        <$crate::ConnectorError as $crate::ConnectorErrorExt>::reason($context, format!($($arg)*))
    }};
}

/// Creates a `ConnectorError` with `Custom` kind and a source error attached to it
///
/// Shorthand for
/// ```rust
/// <ironrdp_connector::ConnectorError as ironrdp_connector::ConnectorErrorExt>::custom(context, source)
/// ```
#[macro_export]
macro_rules! custom_err {
    ( $context:expr, $source:expr $(,)? ) => {{ <$crate::ConnectorError as $crate::ConnectorErrorExt>::custom($context, $source) }};
}
