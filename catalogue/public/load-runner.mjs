// Générateur borné côté navigateur : aucun endpoint serveur ne déclenche de charge.
export const PROTOCOL = Object.freeze({
  users: 10, durationMs: 60_000, intervalMs: 5_000, staggerMs: 50,
  maxRequests: 240, maxBytes: 8_000_000, maxResponseBytes: 1_000_000,
  timeoutMs: 5_000, api: '/api/catalogue', media: '/media/demo-1.mp4',
});

export function createLoadRun({ fetchImpl = fetch, now = () => performance.now(),
  setTimer = (fn, ms) => setTimeout(fn, ms), clearTimer = id => clearTimeout(id),
  onUpdate = () => {} } = {}) {
  const abort = new AbortController();
  const rows = [];
  let phase = 'checking', reason = '', started = null, ended = null;
  let sent = 0, bytes = 0, deadlineTimer, completed = false;
  let mediaBytes = null, startedAt = null;
  const percentile = values => values.length
    ? Math.round(values.sort((a, b) => a - b)[Math.ceil(values.length * .95) - 1]) : null;
  function snapshot() {
    const category = kind => {
      const all = rows.filter(row => row.kind === kind);
      const good = all.filter(row => row.ok);
      return { responses: all.length, success: good.length,
        p95: percentile(good.map(row => row.ms)), hits: good.filter(row => row.cache === 'HIT').length };
    };
    return { phase, reason, completed, startedAt, mediaBytes, sent, bytes,
      elapsedMs: started === null ? 0 : Math.min(PROTOCOL.durationMs, (ended ?? now()) - started),
      errors: rows.filter(row => !row.ok).length, responses: rows.length,
      api: category('api'), media: category('media') };
  }
  const update = () => onUpdate(snapshot());
  function stop(message = 'Arrêt demandé.', normal = false) {
    if (abort.signal.aborted || phase === 'finished') return;
    completed = normal;
    reason = message;
    phase = 'stopping';
    ended = now();
    clearTimer(deadlineTimer);
    abort.abort();
    update();
  }
  function waitUntil(at) {
    if (abort.signal.aborted) return Promise.resolve(false);
    return new Promise(resolve => {
      const finish = () => {
        clearTimer(timer);
        abort.signal.removeEventListener('abort', finish);
        resolve(!abort.signal.aborted);
      };
      const timer = setTimer(finish, Math.max(0, at - now()));
      abort.signal.addEventListener('abort', finish, { once: true });
    });
  }
  async function request(path, { head = false, kind, user } = {}) {
    if (abort.signal.aborted) return;
    if (!head && (started === null || now() >= started + PROTOCOL.durationMs || sent >= PROTOCOL.maxRequests)) return;
    if (!head) sent++;
    const requestAbort = new AbortController();
    const signal = AbortSignal.any([abort.signal, requestAbort.signal]);
    const timer = setTimer(() => requestAbort.abort(), PROTOCOL.timeoutMs);
    const begin = now();
    let status = 0, size = 0, cache = '', error = '', response;
    try {
      response = await fetchImpl(path, { method: head ? 'HEAD' : 'GET',
        cache: 'no-store', redirect: 'error', credentials: 'omit', signal });
      status = response.status;
      cache = (response.headers.get('x-cache-status') || '').toUpperCase();
      const rawLength = response.headers.get('content-length');
      const length = rawLength === null ? NaN : Number(rawLength);
      if (head) {
        if (!response.ok || !Number.isInteger(length) || length <= 0 || length >= PROTOCOL.maxResponseBytes)
          throw new Error('Fichier de test absent ou taille non vérifiable / supérieure à la limite de 1 Mo.');
        mediaBytes = length;
        return;
      }
      if (length >= PROTOCOL.maxResponseBytes) throw new Error('Réponse trop volumineuse (limite : 1 Mo).');
      if (Number.isFinite(length) && bytes + length > PROTOCOL.maxBytes)
        throw new Error('Limite de 8 Mo atteinte.');
      const reader = response.body?.getReader();
      if (reader) {
        try {
          while (true) {
            const chunk = await reader.read();
            if (abort.signal.aborted) return;
            if (chunk.done) break;
            size += chunk.value.byteLength;
            bytes += chunk.value.byteLength;
            if (size >= PROTOCOL.maxResponseBytes) throw new Error('Réponse trop volumineuse (limite : 1 Mo).');
            if (bytes >= PROTOCOL.maxBytes) throw new Error('Limite de 8 Mo atteinte.');
          }
        } finally { await reader.cancel().catch(() => {}); }
      }
      if (!response.ok) error = `HTTP ${status}`;
    } catch (err) {
      if (abort.signal.aborted) return;
      error = requestAbort.signal.aborted ? 'Délai de 5 secondes dépassé.' : err.message;
      if (head) throw new Error(error);
      if (/volumineuse|8 Mo/.test(error)) stop(error);
    } finally {
      clearTimer(timer);
      // Ferme aussi les réponses refusées avant lecture du corps.
      requestAbort.abort();
      if (response?.body && !response.body.locked) await response.body.cancel().catch(() => {});
    }
    if (head) return;
    rows.push({ kind, user, path, status, ok: !error && status >= 200 && status < 300,
      ms: Math.round((now() - begin) * 100) / 100, bytes: size, cache, error });
    const failures = rows.filter(row => !row.ok).length;
    if (rows.length >= 3 && rows.slice(-3).every(row => !row.ok)) stop('Arrêt : 3 erreurs consécutives.');
    else if (rows.length >= 20 && failures / rows.length > .05) stop('Arrêt : plus de 5 % d’erreurs.');
    update();
  }
  async function worker(user) {
    for (let i = 0; i < PROTOCOL.durationMs / PROTOCOL.intervalMs; i++) {
      const due = started + i * PROTOCOL.intervalMs + user * PROTOCOL.staggerMs;
      // Aucun rattrapage en rafale si le navigateur ou le réseau prend du retard.
      if (now() >= due + PROTOCOL.intervalMs) continue;
      if (!await waitUntil(due)) break;
      if (now() >= due + PROTOCOL.intervalMs) continue;
      await request(PROTOCOL.api, { kind: 'api', user });
      await request(PROTOCOL.media, { kind: 'media', user });
    }
  }
  async function run() {
    try {
      update();
      await request(PROTOCOL.media, { head: true });
      if (abort.signal.aborted) return;
      started = now();
      startedAt = new Date().toISOString();
      phase = 'running';
      deadlineTimer = setTimer(() => stop('Simulation terminée : 60 secondes écoulées.', true), PROTOCOL.durationMs);
      update();
      await Promise.all(Array.from({ length: PROTOCOL.users }, (_, user) => worker(user)));
      if (!abort.signal.aborted) await waitUntil(started + PROTOCOL.durationMs);
      // Le réveil final peut précéder le callback du minuteur de fin.
      if (!abort.signal.aborted) stop('Simulation terminée : 60 secondes écoulées.', true);
    } catch (error) { stop(error.message); }
    finally {
      clearTimer(deadlineTimer);
      ended ??= now();
      phase = 'finished';
      update();
    }
    return snapshot();
  }
  const done = run();
  return { done, stop, snapshot, report: () => ({ protocol: PROTOCOL, ...snapshot(), requests: rows.slice() }) };
}
