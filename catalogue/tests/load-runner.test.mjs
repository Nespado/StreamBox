import test from 'node:test';
import assert from 'node:assert/strict';
import { createLoadRun, PROTOCOL } from '../public/load-runner.mjs';

const flush = () => new Promise(resolve => setImmediate(resolve));
function clock(reverseTies = false) {
  let time = 0, serial = 0;
  const timers = new Map();
  return {
    now: () => time,
    setTimer(fn, ms) { const id = ++serial; timers.set(id, { fn, at: time + ms }); return id; },
    clearTimer(id) { timers.delete(id); },
    stall(ms) { time += ms; },
    async advanceTo(end) {
      await flush();
      while (true) {
        const next = [...timers].filter(([, t]) => t.at <= end)
          .sort((a, b) => a[1].at - b[1].at || (reverseTies ? b[0] - a[0] : a[0] - b[0]))[0];
        if (!next) break;
        const [id, timer] = next;
        time = Math.max(time, timer.at);
        timers.delete(id);
        timer.fn();
        await flush();
      }
      time = Math.max(time, end);
      await flush();
    },
  };
}
function setup(overrides = {}) {
  const c = clock(overrides.reverseTies);
  const calls = [];
  const defaultFetch = async (path, opts) => {
    if (opts.method === 'HEAD') return new Response(null, { headers: { 'content-length': '39631' } });
    const isMedia = path === PROTOCOL.media;
    return new Response(new Uint8Array(isMedia ? 39631 : 488), {
      headers: { 'content-length': isMedia ? '39631' : '488', ...(isMedia ? { 'x-cache-status': 'hit' } : {}) },
    });
  };
  const run = createLoadRun({ ...c, fetchImpl: (path, opts) => {
    calls.push({ path, ...opts, at: c.now() });
    return (overrides.fetchImpl ?? defaultFetch)(path, opts, c, defaultFetch);
  } });
  return { c, calls, run };
}

test('60 s : exactement 120 API + 120 médias, un contrôle HEAD et aucune autre cible', async () => {
  const { c, calls, run } = setup();
  await c.advanceTo(60_000);
  await run.done;
  const s = run.snapshot();
  assert.equal(s.phase, 'finished');
  assert.equal(s.completed, true);
  assert.equal(s.api.success, 120);
  assert.equal(s.media.success, 120);
  assert.equal(s.media.hits, 120);
  assert.equal(s.errors, 0);
  assert.equal(s.bytes, (39631 + 488) * 120);
  assert.equal(calls.length, 241);
  assert.equal(calls.filter(x => x.method === 'HEAD').length, 1);
  assert(calls.every(x => [PROTOCOL.api, PROTOCOL.media].includes(x.path)));
  assert(calls.every(x => x.cache === 'no-store' && x.redirect === 'error'));
  assert(calls.every(x => x.at < 60_000));
  for (let user = 0; user < 10; user++) assert.equal(run.report().requests.filter(x => x.user === user).length, 24);
});

test('fin normale même si le réveil final précède le minuteur de fin', async () => {
  const { c, run } = setup({ reverseTies: true });
  await c.advanceTo(60_000);
  await run.done;
  assert.equal(run.snapshot().completed, true);
  assert.match(run.snapshot().reason, /60 secondes/);
});

test('arrêt manuel : annule tous les prochains cycles', async () => {
  const { c, calls, run } = setup();
  await c.advanceTo(10_000);
  run.stop();
  await run.done;
  const count = calls.length;
  await c.advanceTo(90_000);
  assert.equal(calls.length, count);
  assert.equal(run.snapshot().completed, false);
  assert.equal(run.snapshot().reason, 'Arrêt demandé.');
});

test('précontrôle : refuse un fichier de 1 Mo avant de générer la charge', async () => {
  const { run, calls } = setup({ fetchImpl: async () => new Response(null, { headers: { 'content-length': '1000000' } }) });
  await run.done;
  assert.equal(calls.length, 1);
  assert.equal(run.snapshot().sent, 0);
  assert.match(run.snapshot().reason, /1 Mo/);
});

test('précontrôle : refuse une taille inconnue', async () => {
  const { run, calls } = setup({ fetchImpl: async () => new Response(null) });
  await run.done;
  assert.equal(calls.length, 1);
  assert.equal(run.snapshot().sent, 0);
});

test('trois erreurs HTTP arrêtent la démo, y compris les 4xx', async () => {
  const { c, run } = setup({ fetchImpl: async (path, opts, c, normal) => opts.method === 'HEAD'
    ? normal(path, opts) : new Response('refusé', { status: 403 }) });
  await c.advanceTo(60_000);
  await run.done;
  assert.equal(run.snapshot().errors, 3);
  assert.match(run.snapshot().reason, /3 erreurs/);
  assert(run.snapshot().sent < 240);
});

test('plus de 5 % d’erreurs après 20 réponses, sans trois erreurs consécutives', async () => {
  let n = 0;
  const { c, run } = setup({ fetchImpl: async (path, opts, c, normal) => {
    if (opts.method === 'HEAD') return normal(path, opts);
    return [2, 12].includes(++n) ? new Response('erreur', { status: 500 }) : normal(path, opts);
  } });
  await c.advanceTo(60_000);
  await run.done;
  assert.equal(run.snapshot().responses, 20);
  assert.equal(run.snapshot().errors, 2);
  assert.match(run.snapshot().reason, /5 %/);
});

test('réponse sans Content-Length : lecture bornée et arrêt si elle atteint 1 Mo', async () => {
  const { c, run } = setup({ fetchImpl: async (path, opts, c, normal) => opts.method === 'HEAD'
    ? normal(path, opts) : new Response(new Uint8Array(1_000_000)) });
  await c.advanceTo(60_000);
  await run.done;
  assert.match(run.snapshot().reason, /1 Mo/);
  assert(run.snapshot().sent < 240);
});

test('arrêt au plafond de volume total', async () => {
  const { c, run } = setup({ fetchImpl: async (path, opts, c, normal) => opts.method === 'HEAD'
    ? normal(path, opts) : new Response(new Uint8Array(500_000), { headers: { 'content-length': '500000' } }) });
  await c.advanceTo(60_000);
  await run.done;
  assert.match(run.snapshot().reason, /8 Mo/);
  assert.equal(run.snapshot().bytes, 8_000_000);
});

test('requête bloquée : délai de cinq secondes et arrêt des requêtes en vol', async () => {
  const signals = [];
  const { c, run } = setup({ fetchImpl: (path, opts, c, normal) => {
    if (opts.method === 'HEAD') return normal(path, opts);
    signals.push(opts.signal);
    return new Promise((resolve, reject) => opts.signal.addEventListener('abort', () => reject(new Error('aborted')), { once: true }));
  } });
  await c.advanceTo(60_000);
  await run.done;
  assert.match(run.snapshot().reason, /3 erreurs/);
  assert(signals.every(s => s.aborted));
  assert(run.snapshot().elapsedMs <= 5500);
});

test('un onglet ralenti saute les cycles manqués sans rafale de rattrapage', async () => {
  const { c, calls, run } = setup();
  await c.advanceTo(1000);
  c.stall(20_000);
  await c.advanceTo(21_000);
  // Seul le cycle courant (20 s) peut partir, pas les cycles manqués à 5/10/15 s.
  assert.equal(calls.filter(x => x.at === 21_000).length, 20);
  await c.advanceTo(60_000);
  await run.done;
  assert(run.snapshot().responses < 240);
  assert.equal(run.snapshot().completed, true);
});
