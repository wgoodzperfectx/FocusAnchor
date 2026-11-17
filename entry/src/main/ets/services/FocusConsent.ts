export interface FocusConsentSettings {
  consentFocusSupport?: boolean;
  consentThoughtSandbox?: boolean;
}

export interface FocusConsent {
  consentFocusSupport: boolean;
  consentThoughtSandbox: boolean;
}

/** Missing, revoked or malformed consent never grants access to personal data. */
export function resolveFocusConsent(settings?: FocusConsentSettings): FocusConsent {
  const consentFocusSupport = settings?.consentFocusSupport === true;
  return {
    consentFocusSupport: consentFocusSupport,
    consentThoughtSandbox: consentFocusSupport && settings?.consentThoughtSandbox === true
  };
}
