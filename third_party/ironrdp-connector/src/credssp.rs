use ironrdp_core::{WriteBuf, other_err};
use ironrdp_pdu::{PduHint, nego};
use picky::key::PrivateKey;
use picky_asn1_x509::{Certificate, ExtensionView, GeneralName, oids};
use sspi::credssp::{self, ClientState, CredSspClient};
use sspi::generator::{Generator, NetworkRequest};
use sspi::{Secret, Username};
use tracing::debug;

use crate::{
    ConnectorError, ConnectorErrorKind, ConnectorResult, Credentials, ServerName, Written, custom_err, general_err,
};

#[derive(Debug, Clone)]
pub struct KerberosConfig {
    pub kdc_proxy_url: Option<url::Url>,
    pub hostname: String,
}

impl KerberosConfig {
    pub fn new(kdc_proxy_url: Option<String>, hostname: String) -> ConnectorResult<Self> {
        let kdc_proxy_url = kdc_proxy_url
            .map(|url| url::Url::parse(&url))
            .transpose()
            .map_err(|e| custom_err!("invalid KDC URL", e))?;
        Ok(Self {
            kdc_proxy_url,
            hostname,
        })
    }
}

impl From<KerberosConfig> for sspi::KerberosConfig {
    fn from(val: KerberosConfig) -> Self {
        sspi::KerberosConfig {
            kdc_url: val.kdc_proxy_url,
            client_computer_name: val.hostname,
        }
    }
}

#[derive(Clone, Copy, Debug)]
struct CredsspTsRequestHint;

const CREDSSP_TS_REQUEST_HINT: CredsspTsRequestHint = CredsspTsRequestHint;

impl PduHint for CredsspTsRequestHint {
    fn find_size(&self, bytes: &[u8]) -> ironrdp_core::DecodeResult<Option<(bool, usize)>> {
        match credssp::TsRequest::read_length(bytes) {
            Ok(length) => Ok(Some((true, length))),
            Err(e) if e.kind() == std::io::ErrorKind::UnexpectedEof => Ok(None),
            Err(e) => Err(other_err!("CredsspTsRequestHint", source: e)),
        }
    }
}

#[derive(Clone, Copy, Debug)]
struct CredsspEarlyUserAuthResultHint;

const CREDSSP_EARLY_USER_AUTH_RESULT_HINT: CredsspEarlyUserAuthResultHint = CredsspEarlyUserAuthResultHint;

impl PduHint for CredsspEarlyUserAuthResultHint {
    fn find_size(&self, _: &[u8]) -> ironrdp_core::DecodeResult<Option<(bool, usize)>> {
        Ok(Some((true, credssp::EARLY_USER_AUTH_RESULT_PDU_SIZE)))
    }
}

pub type CredsspProcessGenerator<'a> = Generator<'a, NetworkRequest, sspi::Result<Vec<u8>>, sspi::Result<ClientState>>;

#[derive(Debug)]
pub struct CredsspSequence {
    client: CredSspClient,
    state: CredsspState,
    selected_protocol: nego::SecurityProtocol,
}

#[derive(Debug, PartialEq)]
pub(crate) enum CredsspState {
    Ongoing,
    EarlyUserAuthResult,
    Finished,
}

impl CredsspSequence {
    pub fn next_pdu_hint(&self) -> Option<&dyn PduHint> {
        match self.state {
            CredsspState::Ongoing => Some(&CREDSSP_TS_REQUEST_HINT),
            CredsspState::EarlyUserAuthResult => Some(&CREDSSP_EARLY_USER_AUTH_RESULT_HINT),
            CredsspState::Finished => None,
        }
    }

    /// `server_name` must be the actual target server hostname (as opposed to the proxy)
    pub fn init(
        credentials: Credentials,
        domain: Option<&str>,
        protocol: nego::SecurityProtocol,
        server_name: ServerName,
        server_public_key: Vec<u8>,
        kerberos_config: Option<KerberosConfig>,
    ) -> ConnectorResult<(Self, credssp::TsRequest)> {
        let credentials: sspi::Credentials = match &credentials {
            Credentials::UsernamePassword { username, password } => {
                let username = Username::new(username, domain).map_err(|e| custom_err!("invalid username", e))?;

                sspi::AuthIdentity {
                    username,
                    password: password.to_owned().into(),
                }
                .into()
            }
            Credentials::SmartCard { pin, config } => match config {
                Some(config) => {
                    let cert: Certificate = picky_asn1_der::from_bytes(&config.certificate)
                        .map_err(|_e| general_err!("can't parse certificate"))?;
                    let key = PrivateKey::from_pkcs1(&config.private_key)
                        .map_err(|_e| general_err!("can't parse private key"))?;
                    let identity = sspi::SmartCardIdentity {
                        username: extract_user_principal_name(&cert)
                            .or_else(|| extract_user_name(&cert))
                            .unwrap_or_default(),
                        certificate: cert,
                        reader_name: config.reader_name.clone(),
                        card_name: None,
                        container_name: Some(config.container_name.clone()),
                        csp_name: config.csp_name.clone(),
                        pin: pin.as_bytes().to_vec().into(),
                        private_key: Some(key.into()),
                        scard_type: sspi::SmartCardType::Emulated {
                            scard_pin: Secret::new(pin.as_bytes().to_vec()),
                        },
                    };
                    sspi::Credentials::SmartCard(Box::new(identity))
                }
                None => {
                    return Err(general_err!("smart card configuration missing"));
                }
            },
        };

        let server_name = server_name.into_inner();

        let service_principal_name = format!("TERMSRV/{}", &server_name);

        let client_mode = match kerberos_config {
            Some(ref krb_config) => {
                let credssp_config = Box::new(Into::<sspi::KerberosConfig>::into(krb_config.clone()));
                debug!(?credssp_config);
                credssp::ClientMode::Negotiate(sspi::NegotiateConfig {
                    protocol_config: credssp_config,
                    package_list: None,
                    client_computer_name: server_name,
                })
            }
            None => credssp::ClientMode::Ntlm(sspi::ntlm::NtlmConfig::default()),
        };

        let client = CredSspClient::new(
            server_public_key,
            credentials,
            credssp::CredSspMode::WithCredentials,
            client_mode,
            service_principal_name,
        )
        .map_err(|e| ConnectorError::new("CredSSP", ConnectorErrorKind::Credssp(e)))?;

        let sequence = Self {
            client,
            state: CredsspState::Ongoing,
            selected_protocol: protocol,
        };

        let initial_request = credssp::TsRequest::default();

        Ok((sequence, initial_request))
    }

    /// Returns Some(ts_request) when a TS request is received from server,
    /// and None when an early user auth result PDU is received instead.
    pub fn decode_server_message(&mut self, input: &[u8]) -> ConnectorResult<Option<credssp::TsRequest>> {
        match self.state {
            CredsspState::Ongoing => {
                let message = credssp::TsRequest::from_buffer(input).map_err(|e| custom_err!("TsRequest", e))?;
                debug!(?message, "Received");
                Ok(Some(message))
            }
            CredsspState::EarlyUserAuthResult => {
                let early_user_auth_result = credssp::EarlyUserAuthResult::from_buffer(input)
                    .map_err(|e| custom_err!("EarlyUserAuthResult", e))?;

                debug!(message = ?early_user_auth_result, "Received");

                match early_user_auth_result {
                    credssp::EarlyUserAuthResult::Success => {
                        self.state = CredsspState::Finished;
                        Ok(None)
                    }
                    credssp::EarlyUserAuthResult::AccessDenied => {
                        Err(ConnectorError::new("CredSSP", ConnectorErrorKind::AccessDenied))
                    }
                }
            }
            _ => Err(general_err!(
                "attempted to feed server request to CredSSP sequence in an unexpected state"
            )),
        }
    }

    pub fn process_ts_request(&mut self, request: credssp::TsRequest) -> CredsspProcessGenerator<'_> {
        self.client.process(request)
    }

    pub fn handle_process_result(&mut self, result: ClientState, output: &mut WriteBuf) -> ConnectorResult<Written> {
        let (size, next_state) = match self.state {
            CredsspState::Ongoing => {
                let (ts_request_from_client, next_state) = match result {
                    ClientState::ReplyNeeded(ts_request) => (ts_request, CredsspState::Ongoing),
                    ClientState::FinalMessage(ts_request) => (
                        ts_request,
                        if self.selected_protocol.contains(nego::SecurityProtocol::HYBRID_EX) {
                            CredsspState::EarlyUserAuthResult
                        } else {
                            CredsspState::Finished
                        },
                    ),
                };

                debug!(message = ?ts_request_from_client, "Send");

                let written = write_credssp_request(ts_request_from_client, output)?;

                Ok((Written::from_size(written)?, next_state))
            }
            CredsspState::EarlyUserAuthResult => Ok((Written::Nothing, CredsspState::Finished)),
            CredsspState::Finished => Err(general_err!("CredSSP sequence is already done")),
        }?;

        self.state = next_state;

        Ok(size)
    }
}

fn extract_user_name(cert: &Certificate) -> Option<String> {
    cert.tbs_certificate.subject.find_common_name().map(ToString::to_string)
}

fn extract_user_principal_name(cert: &Certificate) -> Option<String> {
    cert.extensions()
        .iter()
        .find(|ext| ext.extn_id().0 == oids::subject_alternative_name())
        .iter()
        .flat_map(|ext| match ext.extn_value() {
            ExtensionView::SubjectAltName(names) => names.0,
            _ => vec![],
        })
        .find_map(|name| match name {
            GeneralName::OtherName(name) if name.type_id.0 == oids::user_principal_name() => Some(name.value),
            _ => None,
        })
        .and_then(|asn1| picky_asn1_der::from_bytes(&asn1.0.0).ok())
}

fn write_credssp_request(ts_request: credssp::TsRequest, output: &mut WriteBuf) -> ConnectorResult<usize> {
    let length = usize::from(ts_request.buffer_len());

    let unfilled_buffer = output.unfilled_to(length);

    ts_request
        .encode_ts_request(unfilled_buffer)
        .map_err(|e| custom_err!("TsRequest", e))?;

    output.advance(length);

    Ok(length)
}
