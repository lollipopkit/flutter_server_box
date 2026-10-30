/// Why a sign-in, refresh, revocation or homebase read did not go through.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Failure {
    /// Nothing answered, or the service failed (5xx, a proxy's page): try
    /// again later; a session already held stays.
    Unreachable,
    /// The service answered with something that is not what it should be.
    InvalidResponse,
    /// The person declined.
    Denied,
    /// A device code ran out before it was approved.
    Expired,
    /// A refresh asked for before [`crate::Tokens::due`]; nothing was sent.
    TooEarly,
    /// The session is over: the IdP's `invalid_grant` for a refresh token, or
    /// homebase refusing the access token (`perm`).
    Rejected,
    /// Refused for another reason (an OAuth error other than the above, a
    /// homebase code other than `perm`): it ends a sign-in, a session stays.
    Refused,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Error {
    pub failure: Failure,
    /// For logs; never a token.
    pub detail: String,
}

impl Error {
    pub fn new(failure: Failure, detail: impl Into<String>) -> Self {
        Self { failure, detail: detail.into() }
    }
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}: {}", self.failure, self.detail)
    }
}

impl std::error::Error for Error {}
