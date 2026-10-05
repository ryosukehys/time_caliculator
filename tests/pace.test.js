import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  parseHms, paceFromTime, timeFromPace, speedKmh, formatClock, formatPace,
  formatDistance, splitOptions, defaultSplit, splits, riegel,
} from '../js/pace.js';

test('parseHms', () => {
  assert.equal(parseHms('', '', ''), null);
  assert.equal(parseHms('', '0', '0'), null);
  assert.equal(parseHms('1', '30', '15'), 5415);
  assert.equal(parseHms('', '14', '30.5'), 870.5);
  assert.equal(parseHms('', '', '58.3'), 58.3);
  assert.equal(parseHms('', 'x', '1'), null);
});

test('5000m 16:40 は 3\'20"/km・400m 80秒', () => {
  const pace = paceFromTime(5000, 1000);
  assert.equal(pace, 200);
  assert.equal(formatPace(pace), `3'20"`);
  assert.equal(formatPace(pace * 0.4, 1), `1'20"0`);
  assert.equal(speedKmh(pace), 18);
});

test('フル 3時間 は 4\'16"/km', () => {
  const pace = paceFromTime(42195, 3 * 3600);
  assert.equal(formatPace(pace), `4'16"`);
  assert.equal(formatClock(timeFromPace(42195, pace)), '3:00:00');
});

test('ハーフ 4\'00"/km は 1:24:23', () => {
  assert.equal(formatClock(timeFromPace(21097.5, 240)), '1:24:23');
});

test('丸めの繰り上がり', () => {
  assert.equal(formatPace(59.96, 1), `1'00"0`);
  assert.equal(formatPace(119.6), `2'00"`);
  assert.equal(formatClock(3599.6), '1:00:00');
  assert.equal(formatClock(870.55, 1), '14:30.6');
  assert.equal(formatPace(58.3, 1), `58"3`);
});

test('formatDistance', () => {
  assert.equal(formatDistance(400), '400m');
  assert.equal(formatDistance(1000), '1km');
  assert.equal(formatDistance(21097.5), '21.0975km');
  assert.equal(formatDistance(42195), '42.195km');
  assert.equal(formatDistance(12500), '12.5km');
});

test('スプリット', () => {
  assert.deepEqual(splitOptions(400), [100, 200]);
  assert.equal(defaultSplit(400), 100);
  assert.equal(defaultSplit(1500), 400);
  assert.equal(defaultSplit(5000), 400);
  assert.equal(defaultSplit(10000), 1000);
  assert.equal(defaultSplit(42195), 5000);
  assert.equal(defaultSplit(150), null);

  const rows = splits(1500, 160, 400);
  assert.deepEqual(rows.map((r) => r.meters), [400, 800, 1200, 1500]);
  assert.equal(rows.at(-1).seconds, 240);

  const full = splits(42195, 240, 5000);
  assert.equal(full.length, 9);
  assert.equal(full.at(-1).meters, 42195);
  // ちょうど割り切れる距離でゴールが重複しない
  assert.deepEqual(splits(5000, 200, 1000).map((r) => r.meters), [1000, 2000, 3000, 4000, 5000]);
});

test('Riegel 予想', () => {
  assert.equal(riegel(5000, 1200, 5000), 1200);
  const t10k = riegel(5000, 1200, 10000);
  assert.ok(t10k > 2400 && t10k < 2550);
});
