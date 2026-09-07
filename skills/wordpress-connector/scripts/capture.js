async () => {
  const expected_profile = __EXPECTED_PROFILE__;
  const application_name = __APPLICATION_NAME__;
  const state_key = '__claudeWordPressPrivateCapture';
  if (location.href !== expected_profile) throw new Error('EXPECTED_PROFILE_REQUIRED');
  const existing = window[state_key];
  if (existing && existing.application_name !== application_name) throw new Error('OTHER_CAPTURE_PRESERVED');
  if (existing && existing.payload) return existing.payload;
  const username = document.querySelector('#user_login')?.value;
  const name_field = document.querySelector('#new_application_password_name');
  const button = document.querySelector('#do_new_application_password');
  if (!username || !name_field || !button) throw new Error('PROFILE_FIELDS_REQUIRED');
  if (!existing) {
    if (document.querySelector('.new-application-password-notice')) throw new Error('EXISTING_NOTICE_REQUIRES_REVIEW');
    window[state_key] = { application_name };
    name_field.value = application_name;
    name_field.dispatchEvent(new Event('input', { bubbles: true }));
    name_field.dispatchEvent(new Event('change', { bubbles: true }));
    button.click();
  }
  for (let attempt = 0; attempt < 100; attempt++) {
    const notice = document.querySelector('.new-application-password-notice');
    const password_field = notice?.querySelector('#new-application-password-value');
    if (notice && password_field) {
      const password = password_field.value.replace(/\s/g, '');
      notice.remove();
      if (!/^[A-Za-z0-9]{24}$/.test(password)) throw new Error('PASSWORD_SCHEMA_NOT_VERIFIED');
      const payload = { profile_url: location.href, username, password };
      window[state_key].payload = payload;
      return payload;
    }
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  throw new Error('CREATION_RESULT_UNCERTAIN_DO_NOT_CLICK_AGAIN');
}
