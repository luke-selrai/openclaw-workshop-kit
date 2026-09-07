const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync(process.argv[2], 'utf8');
let clicks = 0;
let removed = false;
let notice = null;
const password = 'A1b2'.repeat(6);
const username = { value: 'synthetic-admin' };
const name_field = { value: '', dispatchEvent() {} };
const button = { click() {
  clicks += 1;
  notice = {
    textContent: 'Your new password is: Copy',
    querySelector(selector) { return selector === '#new-application-password-value' ? { value: password } : null; },
    remove() { removed = true; notice = null; }
  };
} };
const context = {
  location: { href: 'http://localhost:8099/wp-admin/profile.php' },
  window: {},
  Event: class Event {},
  setTimeout,
  document: { querySelector(selector) {
    return ({ '#user_login': username, '#new_application_password_name': name_field, '#do_new_application_password': button, '.new-application-password-notice': notice })[selector] || null;
  } }
};
(async () => {
  const capture = vm.runInNewContext('(' + source + ')', context);
  const first = await capture();
  const second = await capture();
  assert.equal(first.password, password);
  assert.equal(first.username, username.value);
  assert.equal(clicks, 1);
  assert.equal(removed, true);
  assert.equal(first, second);
  process.stdout.write(JSON.stringify({ clicks, removed, input_value_captured: first.password === password, same_capture_reused: first === second }));
})().catch(() => { process.stderr.write('Offline capture fixture failed'); process.exitCode = 1; });
