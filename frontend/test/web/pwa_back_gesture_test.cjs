const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
function setup(standalone = true, agent = 'iPhone') {
  let listener;
  const records = [];
  const ctx = {
    ysyncSwipeDiagnostics: { record: (...args) => records.push(args) },
    navigator: { standalone, userAgent: agent, maxTouchPoints: 1 },
    document: { addEventListener: (name, fn, options) => {
      assert.equal(name, 'touchstart');
      assert.equal(options.passive, false);
      listener = fn;
    } },
    matchMedia: () => ({ matches: standalone }),
  };
  ctx.window = ctx;
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../../web/pwa_back_gesture.v4.js'), 'utf8'), ctx);
  return { ctx, records, fire(x, count = 1, cancelable = true, accepts = true) {
    let prevented = false;
    listener?.({ touches: Array.from({ length: count }, () => ({ clientX: x })),
      cancelable, get defaultPrevented() { return prevented; },
      preventDefault: () => { prevented = accepts; } });
    return prevented;
  } };
}
test('iOS PWA claims the left edge on lists as well as details', () => {
  const x = setup();
  assert.equal(x.ctx.ysyncPwaBackGesture.enabled, true);
  assert.equal(x.fire(5), true);
  x.ctx.ysyncPwaBackGesture.setDetailActive(true);
  assert.equal(x.fire(5), true);
  assert.equal(x.fire(0), true);
  assert.equal(x.fire(20), true);
  assert.equal(x.fire(21), true);
  assert.equal(x.fire(22), true);
  assert.equal(x.fire(32), true);
  assert.equal(x.fire(33), false);
  assert.equal(x.fire(-1), false);
  assert.equal(x.fire(100), false);
  assert.equal(x.fire(5, 2), false);
  assert.equal(x.fire(5, 1, false), false);
  x.ctx.ysyncPwaBackGesture.setDetailActive(false);
  assert.equal(x.fire(5), true);
});
test('Safari tabs and Android keep browser navigation', () => {
  for (const args of [[false, 'iPhone'], [true, 'Android']]) {
    const x = setup(...args);
    assert.equal(x.ctx.ysyncPwaBackGesture.enabled, false);
    x.ctx.ysyncPwaBackGesture.setDetailActive(true);
    assert.equal(x.fire(5), false);
  }
});

test('reports whether prevention ran, was accepted, or could not run', () => {
  const x = setup();
  x.fire(5);
  x.fire(5, 1, false);
  x.fire(5, 1, true, false);
  x.fire(50);
  x.fire(5, 2);
  assert.deepEqual(x.records, [
    ['guard_touch', 'prevented'], ['guard_touch', 'not_cancelable'],
    ['guard_touch', 'not_prevented'], ['guard_touch', 'outside_edge'],
    ['guard_touch', 'multi_touch'],
  ]);
});
test('missing or broken diagnostics never interrupts prevention', () => {
  const x = setup();
  delete x.ctx.ysyncSwipeDiagnostics;
  assert.equal(x.fire(5), true);
  x.ctx.ysyncSwipeDiagnostics = { record() { throw Error('unavailable'); } };
  assert.equal(x.fire(5), true);
});
