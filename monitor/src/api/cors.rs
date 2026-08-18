//! Minimal CORS allowlist middleware.
//!
//! Adds CORS headers (and answers preflights) only for configured origins;
//! every other request passes through untouched. Rejecting unknown Origins
//! server-side (as ntex-cors does) is wrong here: fetch sends an Origin header
//! even on same-origin POSTs, so a hard reject breaks the panel's own login.
//! Cross-origin blocking is the browser's job, and auth is a bearer token
//! (not cookies), so there is no CSRF surface requiring server-side blocks.

use std::rc::Rc;

use ntex::http::{Method, header};
use ntex::service::{Middleware, Service, ServiceCtx, cfg::SharedCfg};
use ntex::web::{ErrorRenderer, HttpResponse, WebRequest, WebResponse};

/// Methods advertised on preflight responses.
///
/// Must cover every method registered under `/api/v1` — a method missing here
/// is silently unusable from a cross-origin panel (the browser rejects the
/// request after preflight, the server never sees it). `PUT` used to be
/// missing, which broke saving settings and card order on a panel hosted
/// away from the agent. `allow_methods_covers_registered_api_methods` guards
/// against that drifting again.
const ALLOW_METHODS: &str = "GET, POST, PUT, DELETE";

pub struct Cors {
    origins: Rc<Vec<String>>,
}

impl Cors {
    pub fn new(origins: Vec<String>) -> Self {
        Self { origins: Rc::new(origins) }
    }
}

impl<S> Middleware<S, SharedCfg> for Cors {
    type Service = CorsService<S>;

    fn create(&self, service: S, _: SharedCfg) -> Self::Service {
        CorsService { service, origins: self.origins.clone() }
    }
}

pub struct CorsService<S> {
    service: S,
    origins: Rc<Vec<String>>,
}

impl<S, E> Service<WebRequest<E>> for CorsService<S>
where
    S: Service<WebRequest<E>, Response = WebResponse>,
    E: ErrorRenderer,
{
    type Response = WebResponse;
    type Error = S::Error;

    ntex::forward_poll!(service);
    ntex::forward_ready!(service);
    ntex::forward_shutdown!(service);

    async fn call(
        &self,
        req: WebRequest<E>,
        ctx: ServiceCtx<'_, Self>,
    ) -> Result<WebResponse, Self::Error> {
        let allowed = req
            .headers()
            .get(header::ORIGIN)
            .and_then(|v| v.to_str().ok())
            .filter(|o| self.origins.iter().any(|a| a == o))
            .map(String::from);

        if let Some(origin) = &allowed
            && req.method() == Method::OPTIONS
        {
            let res = HttpResponse::NoContent()
                .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, origin.as_str())
                .header(header::ACCESS_CONTROL_ALLOW_METHODS, ALLOW_METHODS)
                .header(header::ACCESS_CONTROL_ALLOW_HEADERS, "authorization, content-type")
                .header(header::ACCESS_CONTROL_MAX_AGE, "3600")
                .header(header::VARY, "Origin")
                .finish();
            return Ok(req.into_response(res));
        }

        let mut res = ctx.call(&self.service, req).await?;
        if let Some(origin) = allowed
            && let Ok(value) = header::HeaderValue::from_str(&origin)
        {
            let headers = res.headers_mut();
            headers.insert(header::ACCESS_CONTROL_ALLOW_ORIGIN, value);
            headers.insert(header::VARY, header::HeaderValue::from_static("Origin"));
        }
        Ok(res)
    }
}

#[cfg(test)]
mod tests {
    use super::ALLOW_METHODS;

    /// Reads the route table's source rather than taking a hand-maintained
    /// list on faith: any `web::<method>()` that appears in `server.rs` must
    /// be advertised on preflight, or cross-origin panels lose that verb
    /// without any server-side symptom to notice.
    #[test]
    fn allow_methods_covers_registered_api_methods() {
        const ROUTES_SRC: &str = include_str!("server.rs");
        let advertised: Vec<&str> = ALLOW_METHODS.split(',').map(str::trim).collect();

        for method in ["get", "post", "put", "delete", "patch", "head"] {
            if !ROUTES_SRC.contains(&format!("web::{method}()")) {
                continue;
            }
            let upper = method.to_uppercase();
            assert!(
                advertised.contains(&upper.as_str()),
                "server.rs registers {upper} routes but ALLOW_METHODS ({ALLOW_METHODS}) omits it"
            );
        }
    }
}
