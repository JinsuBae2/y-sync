const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
function boot(enabled = true) {
  const listeners = {}, timers = new Map(), frames = [], elements = [];
  let timerId = 0;
  const ctx = {
    ysyncPwaBackGesture: { enabled },
    document: { createElement: () => ({ style: {}, setAttribute() {} }),
      body: { appendChild: e => elements.push(e) } },
    addEventListener: (name, fn) => { listeners[name] = fn; },
    setTimeout: fn => { timers.set(++timerId, fn); return timerId; },
    clearTimeout: id => timers.delete(id),
    requestAnimationFrame: fn => frames.push(fn),
  };
  ctx.window = ctx;
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../../web/back_navigation_loading.v1.js'), 'utf8'), ctx);
  return { api: ctx.ysyncBackLoading, listeners, elements,
    paint() { while (frames.length) frames.shift()(); },
    timeout() { for (const fn of [...timers.values()]) fn(); } };
}
test('history navigation shows loading until matching Flutter completion paints', () => {
  const x = boot();
  x.listeners.popstate();
  assert.equal(x.elements[0].hidden, false);
  assert.equal(x.elements[0].style.pointerEvents, 'none');
  x.api.complete(x.api.token);
  assert.equal(x.elements[0].hidden, false);
  x.paint();
  assert.equal(x.elements[0].hidden, true);
});
test('stale completion cannot dismiss newer navigation; timeout always releases', () => {
  const x = boot();
  x.listeners.popstate();
  const old = x.api.token;
  x.api.complete(old);
  x.listeners.popstate();
  x.paint();
  assert.equal(x.elements[0].hidden, false);
  x.api.complete(old);
  x.paint();
  assert.equal(x.elements[0].hidden, false);
  x.timeout();
  assert.equal(x.elements[0].hidden, true);
});
test('pagehide clears the overlay and ordinary browsers have no listener', () => {
  const x = boot();
  x.listeners.popstate();
  x.listeners.pagehide();
  assert.equal(x.elements[0].hidden, true);
  const other = boot(false);
  assert.equal(other.listeners.popstate, undefined);
  assert.equal(other.elements.length, 0);
});
