const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = () => fs.readFileSync(path.join(__dirname, '../../web/swipe_diagnostics.js'), 'utf8');
function boot(storage = new Map(), search = '', guard) {
  const listeners = {};
  const elements = [];
  const context = {
    URLSearchParams, Date, Math, JSON,
    ysyncPwaBackGesture: guard,
    location: { search },
    sessionStorage: {
      getItem: k => storage.get(k) ?? null,
      setItem: (k, v) => storage.set(k, v),
      removeItem: k => storage.delete(k),
    },
    performance: { getEntriesByType: () => [{ type: 'navigate' }] },
    document: {
      visibilityState: 'visible',
      body: { appendChild: e => elements.push(e) },
      createElement: () => ({ style: {}, appendChild() {}, remove() {} }),
      addEventListener: (k, fn) => { listeners[k] = fn; },
    },
    addEventListener: (k, fn) => { listeners[k] = fn; },
  };
  context.window = context;
  vm.runInNewContext(source(), context);
  return { api: context.ysyncSwipeDiagnostics, listeners, elements, storage };
}
test('disabled mode has no event handlers, storage or UI', () => {
  const x = boot();
  x.api.record('route_pop', 'notice');
  assert.equal(x.storage.size, 0);
  assert.equal(Object.keys(x.listeners).length, 0);
  assert.equal(x.elements.length, 0);
});
test('reload preserves previous run and creates a new page marker', () => {
  const first = boot(new Map(), '?swipeDebug=1');
  first.api.record('route_pop', 'notice');
  const second = boot(first.storage);
  const events = JSON.parse(second.api.export());
  assert.equal(events.filter(e => e.event === 'page_start').length, 2);
  assert.equal(new Set(events.map(e => e.run)).size, 2);
  assert.ok(events.some(e => e.event === 'route_pop'));
});
test('records are bounded and arbitrary details are discarded', () => {
  const x = boot(new Map(), '?swipeDebug=1');
  for (let i = 0; i < 200; i++) x.api.record('route_pop', 'notice');
  x.api.record('route_pop', 'Bearer SECRET /notices/123?keyword=PRIVATE');
  const raw = x.api.export();
  assert.equal(JSON.parse(raw).length, 150);
  assert.ok(!raw.includes('SECRET'));
  assert.ok(!raw.includes('PRIVATE'));
});
test('disabling clears stored diagnostics', () => {
  const x = boot(new Map(), '?swipeDebug=1');
  boot(x.storage, '?swipeDebug=0');
  assert.equal(x.storage.size, 0);
});
test('browser history and cached restoration are distinguishable', () => {
  const x = boot(new Map(), '?swipeDebug=1');
  x.listeners.pagehide({ persisted: true });
  x.listeners.popstate({ state: { secret: 'PRIVATE' } });
  x.listeners.pageshow({ persisted: true });
  const events = JSON.parse(x.api.export());
  assert.deepEqual(events.slice(-3).map(e => [e.event, e.detail]), [
    ['page_hide', 'cached'], ['history_pop', ''], ['page_show', 'cached'],
  ]);
  assert.ok(!x.api.export().includes('PRIVATE'));
  x.api.stop();
  x.listeners.pageshow({ persisted: false });
  assert.equal(x.api.export(), '[]');
});
test('blocked session storage does not break diagnostic startup', () => {
  class BlockedStorage extends Map {
    get() { throw new Error('storage blocked'); }
    set() { throw new Error('storage blocked'); }
    delete() { throw new Error('storage blocked'); }
  }
  const x = boot(new BlockedStorage(), '?swipeDebug=1');
  x.api.record('flutter_start');
  assert.equal(JSON.parse(x.api.export()).length, 2);
  assert.doesNotThrow(() => x.api.stop());
});

test('left edge diagnostics match the guarded 20px region', () => {
  const x = boot(new Map(), '?swipeDebug=1');
  for (const clientX of [0, 20, 21, 24, -1]) {
    x.listeners.touchstart({ touches: [{ clientX }] });
  }
  const starts = JSON.parse(x.api.export()).filter(e => e.event === 'touch_start');
  assert.deepEqual(starts.map(e => e.detail), ['left_edge', 'left_edge', 'other', 'other', 'other']);
});

test('each event retains executing component revisions after the ring wraps', () => {
  const x = boot(new Map(), '?swipeDebug=1', { version: 'guard_v3', enabled: true });
  x.api.record('flutter_start', 'flutter_v2');
  for (let i = 0; i < 155; i++) x.api.record('guard_touch', 'prevented');
  const events = JSON.parse(x.api.export());
  assert.equal(events.length, 150);
  assert.equal(events[0].diagnosticVersion, 'diag_v2');
  assert.equal(events[0].guardVersion, 'guard_v3');
  assert.equal(events[0].guardEnabled, true);
  assert.equal(events[0].flutterVersion, 'flutter_v2');
  assert.equal(events[0].detail, 'prevented');
});
test('missing and older bridges are unknown, not misreported as current', () => {
  const x = boot(new Map(), '?swipeDebug=1');
  x.api.record('flutter_start');
  const e = JSON.parse(x.api.export()).at(-1);
  assert.equal(e.guardVersion, 'unknown');
  assert.equal(e.guardEnabled, null);
  assert.equal(e.flutterVersion, 'unknown');
});
