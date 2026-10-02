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
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../../web/pwa_back_gesture.v4.js'), 'utf8'), ctx);
  return { ctx, fire(x, count = 1, cancelable = true, accepts = true) {
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

test('경계 조건별로 차단 여부가 갈린다', () => {
  // 진단 기록 대신 실제 차단 결과로 고정합니다. 각 분기가 의도대로 동작해야 합니다.
  const x = setup();
  assert.equal(x.fire(5), true, '가장자리 단일 터치는 차단한다');
  assert.equal(x.fire(5, 1, false), false, 'cancelable하지 않으면 차단하지 않는다');
  assert.equal(x.fire(50), false, '가장자리 밖은 차단하지 않는다');
  assert.equal(x.fire(5, 2), false, '다중 터치는 차단하지 않는다');
});
