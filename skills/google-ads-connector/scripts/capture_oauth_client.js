async () => {
  const context = __ADS_CAPTURE_CONTEXT__;
  const state_key = '__claudeGoogleAdsClientCapture';
  const attempt_key = 'claude-google-ads-client:' + context.capture_name;
  if (!/^ads-capture-[a-f0-9]{24}$/.test(context.capture_name) || new URL(location.href).origin !== new URL(context.create_url).origin) {
    throw new Error('EXPECTED_CREATE_PAGE_AND_ATTEMPT_REQUIRED');
  }
  const previous = window[state_key];
  if (previous && (previous.capture_name !== context.capture_name || previous.create_url !== context.create_url)) throw new Error('OTHER_CAPTURE_PRESERVED');
  if (!previous && location.href !== context.create_url) throw new Error('EXPECTED_CREATE_PAGE_AND_ATTEMPT_REQUIRED');
  document.documentElement.style.display = 'none';
  if (previous?.payload) return previous.payload;
  if (!previous) {
    if (sessionStorage.getItem(attempt_key)) throw new Error('CREATION_UNCERTAIN_PRESERVE_EXISTING_CLIENT');
    const buttons = Array.from(document.querySelectorAll(context.create_selector));
    if (buttons.length !== 1 || buttons[0].disabled || buttons[0].getAttribute('aria-disabled') === 'true') {
      throw new Error('ONE_OBSERVED_ENABLED_CREATE_BUTTON_REQUIRED');
    }
    sessionStorage.setItem(attempt_key, 'started');
    window[state_key] = { capture_name: context.capture_name, create_url: context.create_url };
    buttons[0].click();
  }
  function extractCredentials() {
    const labels = Array.from(document.querySelectorAll('*'))
      .filter(element => element.children.length === 0 && /^(your )?client (id|secret)\s*:?$/i.test((element.textContent || '').trim()));
    const output = {};
    for (const label of labels) {
      const field = /id/i.test(label.textContent) ? 'client_id' : 'client_secret';
      let scope = label.parentElement;
      for (let depth = 0; depth < 6 && scope; depth++) {
        const candidates = new Set();
        for (const element of scope.querySelectorAll('code, input[type=text], input:not([type])')) {
          const value = (element.value || element.textContent || '').trim();
          const valid = field === 'client_id'
            ? /^[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$/.test(value)
            : /^[A-Za-z0-9_-]{21,128}$/.test(value);
          if (valid) candidates.add(value);
        }
        if (candidates.size > 1) throw new Error('AMBIGUOUS_CREDENTIAL_FIELDS_PRESERVE_CLIENT');
        if (candidates.size === 1) {
          const value = Array.from(candidates)[0];
          if (output[field] && output[field] !== value) throw new Error('AMBIGUOUS_CREDENTIAL_FIELDS_PRESERVE_CLIENT');
          output[field] = value;
          break;
        }
        scope = scope.parentElement;
      }
    }
    if (!output.client_id || !output.client_secret || output.client_id === output.client_secret) return null;
    return output;
  }
  for (let attempt = 0; attempt < 150; attempt++) {
    const payload = extractCredentials();
    if (payload) {
      window[state_key].payload = payload;
      return payload;
    }
    await new Promise(resolve => setTimeout(resolve, 200));
  }
  throw new Error('CREATION_RESULT_UNCERTAIN_DO_NOT_CLICK_AGAIN');
}
