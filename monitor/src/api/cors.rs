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

        if let Some(origin) = &allowed {
            if req.method() == Method::OPTIONS {
                let res = HttpResponse::NoContent()
                    .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, origin.as_str())
                    .header(header::ACCESS_CONTROL_ALLOW_METHODS, "GET, POST")
                    .header(header::ACCESS_CONTROL_ALLOW_HEADERS, "authorization, content-type")
                    .header(header::ACCESS_CONTROL_MAX_AGE, "3600")
                    .header(header::VARY, "Origin")
                    .finish();
                return Ok(req.into_response(res));
            }
        }

        let mut res = ctx.call(&self.service, req).await?;
        if let Some(origin) = allowed {
            if let Ok(value) = header::HeaderValue::from_str(&origin) {
                let headers = res.headers_mut();
                headers.insert(header::ACCESS_CONTROL_ALLOW_ORIGIN, value);
                headers.insert(header::VARY, header::HeaderValue::from_static("Origin"));
            }
        }
        Ok(res)
    }
}
