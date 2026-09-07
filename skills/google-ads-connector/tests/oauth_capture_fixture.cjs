const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const mode = process.argv[3];
const output_path = process.argv[4];
const client_id = '123456789-synthetic.apps.googleusercontent.com';
const client_secret = 'synthetic-secret-' + 's'.repeat(24);
const expected = { client_id, client_secret };
const capture_context = {
  capture_name: 'ads-capture-aaaaaaaaaaaaaaaaaaaaaaaa',
  create_url: 'https://example.invalid/public-create-form',
  create_selector: '#observed-create'
};
const source = fs.readFileSync(process.argv[2], 'utf8').replace('__ADS_CAPTURE_CONTEXT__', JSON.stringify(capture_context));
const storage = new Map();
const events = [];
const snapshots = [];
let clicks = 0;
let ticks = 0;
let rendered = false;
let visibility = 'visible';
let display = '';
const explicit_visible_child = mode === 'explicit-visible';
let labels = [];
const render_after = mode === 'uncertain-late' ? 151 : 3;
function renderModal() {
  if (rendered) return;
  rendered = true;
  events.push('secret-rendered');
  labels = Object.entries(expected).map(([field]) => {
    const label = { children: [], textContent: field === 'client_id' ? 'Client ID' : 'Your Client Secret:' };
    const values = [{ value: client_id, textContent: '' }, { value: client_secret, textContent: '' }];
    if (mode === 'ambiguous') values.push({ value: 'different-synthetic-secret-value', textContent: '' });
    label.parentElement = { querySelectorAll: () => values, parentElement: null };
    return label;
  });
}
const button = {
  disabled: false,
  getAttribute: () => null,
  click() {
    events.push('create-click');
    assert.equal(display, 'none', 'Page must be excluded from rendering before creation');
    clicks += 1;
  }
};
const sandbox = {
  location: { href: capture_context.create_url },
  window: {},
  URL,
  sessionStorage: { getItem: key => storage.get(key) || null, setItem: (key, value) => storage.set(key, value) },
  document: {
    documentElement: { style: {
      set visibility(value) { visibility = value; events.push('visibility-' + value); },
      get visibility() { return visibility; },
      set display(value) { display = value; events.push('display-' + value); },
      get display() { return display; }
    } },
    querySelectorAll: selector => selector === capture_context.create_selector ? [button] : labels
  },
  setTimeout(callback) {
    ticks += 1;
    if (clicks && ticks >= render_after) renderModal();
    callback();
  }
};
const context = vm.createContext(sandbox);
const capture = vm.runInContext('(' + source + ')', context);
function snapshot() {
  const concealed = display === 'none' || (visibility === 'hidden' && !explicit_visible_child);
  const value = concealed ? '' : labels.map(label => label.textContent).join(' ') + (rendered ? JSON.stringify(expected) : '');
  snapshots.push(value);
  events.push('snapshot');
  return value;
}
async function evaluateToFile(fail_output = false) {
  let payload;
  try {
    payload = await capture();
  } catch (error) {
    snapshot();
    throw error;
  }
  if (fail_output) {
    snapshot();
    throw new Error('SYNTHETIC_OUTPUT_DELIVERY_FAILED');
  }
  assert.equal(fs.statSync(output_path).mode & 0o777, 0o600);
  fs.writeFileSync(output_path, JSON.stringify(payload));
  const result = { artifact: output_path, snapshot: snapshot() };
  for (const value of Object.values(expected)) assert.ok(!JSON.stringify(result).includes(value));
  return result;
}
(async () => {
  if (mode === 'output-retry' || mode === 'spa-output-retry') {
    await assert.rejects(evaluateToFile(true), /SYNTHETIC_OUTPUT_DELIVERY_FAILED/);
    assert.equal(fs.readFileSync(output_path, 'utf8'), '');
    if (mode === 'spa-output-retry') sandbox.location.href = 'https://example.invalid/credentials?new-client=true';
    await evaluateToFile();
  } else if (mode === 'uncertain-late') {
    await assert.rejects(evaluateToFile(), /CREATION_RESULT_UNCERTAIN_DO_NOT_CLICK_AGAIN/);
    assert.equal(clicks, 1);
    renderModal();
    snapshot();
    await evaluateToFile();
  } else if (mode === 'reload') {
    await assert.rejects(evaluateToFile(true), /SYNTHETIC_OUTPUT_DELIVERY_FAILED/);
    sandbox.window = {};
    labels = [];
    rendered = false;
    visibility = 'visible';
    display = '';
    await assert.rejects(evaluateToFile(), /CREATION_UNCERTAIN_PRESERVE_EXISTING_CLIENT/);
    assert.equal(fs.readFileSync(output_path, 'utf8'), '');
  } else if (mode === 'ambiguous') {
    await assert.rejects(evaluateToFile(), /AMBIGUOUS_CREDENTIAL_FIELDS/);
    assert.equal(fs.readFileSync(output_path, 'utf8'), '');
  } else {
    await evaluateToFile();
  }
  assert.equal(clicks, 1);
  if (explicit_visible_child) {
    const field_rendered = rendered && display !== 'none' && (explicit_visible_child || visibility !== 'hidden');
    assert.equal(field_rendered, false, 'Explicit visibility must not render a credential field');
    assert.equal(field_rendered ? 120 : 0, 0, 'Credential field must have no rendered width');
  }
  assert.ok(events.indexOf('display-none') < events.indexOf('create-click'));
  assert.ok(events.indexOf('create-click') < events.indexOf('secret-rendered'));
  for (const value of Object.values(expected)) {
    assert.ok(snapshots.every(item => !item.includes(value)));
    assert.ok(!JSON.stringify(Array.from(storage.entries())).includes(value));
  }
  if (mode !== 'reload' && mode !== 'ambiguous') assert.deepEqual(JSON.parse(fs.readFileSync(output_path, 'utf8')), expected);
  assert.equal(fs.statSync(output_path).mode & 0o777, 0o600);
  process.stdout.write(JSON.stringify({ mode, clicks, snapshots_checked: snapshots.length }));
})().catch(error => {
  process.stderr.write('Synthetic capture assertion failed: ' + error.message);
  process.exitCode = 1;
});
