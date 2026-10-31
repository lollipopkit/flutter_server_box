//! Refuses a client older than the agent still answers — see
//! `sbm_parser::protocol`.
//!
//! A client names its protocol in `X-SBM-Protocol`; one that names none
//! predates the header and speaks the first. Too old is `426` with
//! `{error: "client_too_old", protocol, min_client_protocol}`, which the app
//! shows as "update the app" rather than as a failed sign-in.
//!
//! Not checked: `/health`, which is where a client learns the numbers before
//! anything else; preflights, which carry no custom header; and WebSocket
//! upgrades, which a browser cannot add a header to — the `/ws-ticket` POST
//! before each one is checked instead.

use ntex::http::{Method, StatusCode, header};
use ntex::service::{Ctx, Middleware, Service};
use ntex::web::{HttpResponse, WebRequest, WebResponse};
use sbm_parser::protocol;

pub struct Protocol;

/// The protocol the client named, kept on the request for the handlers that
/// answer an older one in its shape (`api::compat_v1`).
#[derive(Clone, Copy)]
struct ClientProtocol(u32);

/// What [req]'s client speaks; [`protocol::UNNAMED`] where nothing said
/// (exempt routes, a scope without the middleware).
pub fn client_of(req: &ntex::web::HttpRequest) -> u32 {
    req.extensions().get::<ClientProtocol>().map_or(protocol::UNNAMED, |c| c.0)
}

impl<S, St> Middleware<S, St> for Protocol {
    type Service = ProtocolService<S>;

    fn create(&self, _: &St, service: S) -> Self::Service {
        ProtocolService { service }
    }
}

pub struct ProtocolService<S> {
    service: S,
}

impl<S, St, In> Service<St, WebRequest<In>> for ProtocolService<S>
where
    S: Service<St, WebRequest<In>, Res = WebResponse>,
{
    type Res = WebResponse;
    type Error = S::Error;

    ntex::forward_bind!(St, service);
    ntex::forward_ready!(St, service);
    ntex::forward_shutdown!(St, service);

    async fn call(&self, req: WebRequest<In>, ctx: Ctx<'_, Self, St>) -> Result<WebResponse, Self::Error> {
        let exempt = req.method() == Method::OPTIONS || req.path().ends_with("/health") || is_ws_upgrade(&req);
        if !exempt {
            let named = req.headers().get(protocol::HEADER).map(|v| v.to_str().unwrap_or(""));
            let client = protocol::client_protocol(named);
            if let Some(p) = client {
                req.extensions_mut().insert(ClientProtocol(p));
            }
            let refusal = match client {
                None => Some(HttpResponse::BadRequest().json(&serde_json::json!({ "error": "bad_protocol" }))),
                Some(p) if !protocol::agent_serves(p) => Some(
                    HttpResponse::builder(StatusCode::UPGRADE_REQUIRED).json(&serde_json::json!({
                        "error": "client_too_old",
                        "protocol": protocol::PROTOCOL,
                        "min_client_protocol": protocol::MIN_CLIENT_PROTOCOL,
                    })),
                ),
                Some(_) => None,
            };
            if let Some(res) = refusal {
                return Ok(req.into_response(res));
            }
        }
        ctx.call(&self.service, req).await
    }
}

/// A WebSocket upgrade to one of the `/…/ws` routes. An `Upgrade` header on
/// any other request exempts nothing.
fn is_ws_upgrade<In>(req: &WebRequest<In>) -> bool {
    req.path().ends_with("/ws")
        && req
            .headers()
            .get(header::UPGRADE)
            .and_then(|v| v.to_str().ok())
            .is_some_and(|v| v.eq_ignore_ascii_case("websocket"))
}
