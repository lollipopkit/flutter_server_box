/// A refusal from the BMC endpoint arrives as a stable code rather than as a
/// sentence, so the panel phrases it in the viewer's own language.
///
/// Two vocabularies arrive through one field. The first group is this agent's
/// own — what the operator can fix about the request or the stored section. The
/// rest is `sbm_parser::redfish::RedfishFailure`, the same names the app
/// phrases, and they are what the *machine* or the link to it did. None of them
/// is an upstream status: a BMC answering 401 is `unauthorized`, because what
/// failed is the *agent's* credential to a machine the operator is not signed in
/// to, and this client logs the operator out on a 401 of its own.
///
/// A word this build does not know is shown as the agent sent it: it is a
/// refusal added since, and a sentence invented here would misdescribe it.
import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'

export function bmcRefusalText(code: string): string {
  const ll = get(LL)
  switch (code) {
    case 'notConfigured':
      return ll.bmcNotConfigured()
    case 'invalidUrl':
      return ll.bmcInvalidUrl()
    case 'missingUsername':
      return ll.bmcMissingUsername()
    case 'missingFingerprint':
      return ll.bmcMissingFingerprint()
    case 'invalidIntent':
      return ll.bmcInvalidIntent()
    case 'notAService':
      return ll.bmcNotAService()
    case 'noSystem':
      return ll.bmcNoSystem()
    case 'certificateRejected':
      return ll.bmcCertificateRejected()
    case 'unauthorized':
      return ll.bmcUnauthorized()
    case 'noCredential':
      return ll.bmcNoCredential()
    case 'forbidden':
      return ll.bmcForbidden()
    case 'preconditionRequired':
      return ll.bmcPreconditionRequired()
    case 'unsupportedIntent':
      return ll.bmcUnsupportedIntent()
    case 'invalidResponse':
      return ll.bmcInvalidResponse()
    case 'unreachable':
      return ll.bmcUnreachable()
    default:
      return code
  }
}
