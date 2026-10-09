import test from 'node:test';
import assert from 'node:assert/strict';
import { readProgress, saveProgress, unfinished, KEY } from '../public/v2/progress.mjs';

const memory = () => {
  const data = new Map();
  return { getItem: key => data.get(key), setItem: (key, value) => data.set(key, value) };
};
test('resume survives reload, and completed videos leave the resume list', () => {
  const storage = memory();
  assert.equal(saveProgress(storage, 'intro-gcp', 2.5, 6), true);
  const loaded = readProgress(storage)['intro-gcp'];
  assert.equal(loaded.position, 2.5);
  assert.equal(unfinished(loaded), true);
  saveProgress(storage, 'intro-gcp', 6, 6);
  assert.equal(unfinished(readProgress(storage)['intro-gcp']), false);
});
test('denied storage and corrupt data do not prevent playback', () => {
  const denied = { getItem() { throw Error('denied'); }, setItem() { throw Error('quota'); } };
  assert.deepEqual(readProgress(denied), {});
  assert.equal(saveProgress(denied, 'intro-gcp', 3, 6), false);
  const storage = memory();
  for (const value of ['{bad', 'null', '[]', '{"intro-gcp":{"position":-1,"duration":6,"updated":0}}']) {
    storage.setItem(KEY, value); assert.deepEqual(readProgress(storage), {});
  }
});
test('unavailable duration is not persisted, positions stay within the video', () => {
  const storage = memory();
  assert.equal(saveProgress(storage, 'intro-gcp', 2, NaN), false);
  assert.equal(saveProgress(storage, 'intro-gcp', Infinity, 6), false);
  saveProgress(storage, 'intro-gcp', 7, 6);
  assert.equal(readProgress(storage)['intro-gcp'].position, 6);
});
