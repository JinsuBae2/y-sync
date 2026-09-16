const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
function setup(standalone = true, agent = 'iPhone') {
  let listener;
  const ctx = {
    navigator: { standalone, userAgent: agent, maxTouchPoints: 1 },
    document: { addEventListener: (name, fn, options) => {
      assert.equal(name, 'touchstart');
      assert.equal(options.passive, false);
      listener = fn;
    } },
    matchMedia: () => ({ matches: standalone }),
  };
  ctx.window = ctx;
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../../web/pwa_back_gesture.js'), 'utf8'), ctx);
  return { ctx, fire(x, count = 1, cancelable = true) {
    let prevented = false;
    listener?.({ touches: Array.from({ length: count }, () => ({ clientX: x })),
      cancelable, preventDefault: () => { prevented = true; } });
    return prevented;
  } };
}
test('only an active detail route in iOS PWA claims the left edge', () => {
  const x = setup();
  assert.equal(x.fire(5), false);
  x.ctx.ysyncPwaBackGesture.setDetailActive(true);
  assert.equal(x.fire(5), true);
  assert.equal(x.fire(100), false);
  assert.equal(x.fire(5, 2), false);
  assert.equal(x.fire(5, 1, false), false);
  x.ctx.ysyncPwaBackGesture.setDetailActive(false);
  assert.equal(x.fire(5), false);
});
test('Safari tabs and Android keep browser navigation', () => {
  for (const args of [[false, 'iPhone'], [true, 'Android']]) {
    const x = setup(...args);
    x.ctx.ysyncPwaBackGesture.setDetailActive(true);
    assert.equal(x.fire(5), false);
  }
});
