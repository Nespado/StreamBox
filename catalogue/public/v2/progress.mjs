export const KEY = 'streambox.v2.progress';

export function readProgress(storage) {
  try {
    const value = JSON.parse(storage.getItem(KEY) || '{}');
    if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
    return Object.fromEntries(Object.entries(value).filter(([id, p]) =>
      /^[a-z0-9-]+$/.test(id) && p && Number.isFinite(p.position) && p.position >= 0 &&
      Number.isFinite(p.duration) && p.duration > 0 && p.position <= p.duration &&
      Number.isFinite(p.updated)));
  } catch { return {}; }
}

export function saveProgress(storage, id, position, duration) {
  if (!Number.isFinite(position) || !Number.isFinite(duration) || duration <= 0) return false;
  try {
    const all = readProgress(storage);
    all[id] = { position: Math.max(0, Math.min(position, duration)), duration, updated: Date.now() };
    storage.setItem(KEY, JSON.stringify(all));
    return true;
  } catch { return false; }
}

export function unfinished(p) {
  return !!p && p.position >= .25 && p.position < p.duration - .25;
}

export function formatTime(seconds) {
  const s = Math.max(0, Math.floor(Number(seconds) || 0));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}
