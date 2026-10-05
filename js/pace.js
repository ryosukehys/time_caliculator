// ランニングのペース計算ロジック（UI に依存しない純粋関数のみ）

export const EVENTS = [
  { id: '400', label: '400m', meters: 400 },
  { id: '800', label: '800m', meters: 800 },
  { id: '1500', label: '1500m', meters: 1500 },
  { id: '3000', label: '3000m', meters: 3000 },
  { id: '5000', label: '5000m', meters: 5000 },
  { id: '10000', label: '10000m', meters: 10000 },
  { id: 'half', label: 'ハーフ', meters: 21097.5 },
  { id: 'full', label: 'フル', meters: 42195 },
  { id: 'custom', label: '距離入力', meters: null },
];

export const SPLIT_INTERVALS = [100, 200, 400, 1000, 5000];

// 時・分・秒の文字列から合計秒数を求める。どれも空なら null
export function parseHms(h, m, s) {
  const parts = [h, m, s].map((v) => String(v ?? '').trim());
  if (parts.every((v) => v === '')) return null;
  const [hh, mm, ss] = parts.map((v) => (v === '' ? 0 : Number(v)));
  if (![hh, mm, ss].every((v) => Number.isFinite(v) && v >= 0)) return null;
  const total = hh * 3600 + mm * 60 + ss;
  return total > 0 ? total : null;
}

// 秒/km
export function paceFromTime(meters, seconds) {
  return (seconds / meters) * 1000;
}

// ゴールタイム（秒）
export function timeFromPace(meters, secPerKm) {
  return (secPerKm * meters) / 1000;
}

export function speedKmh(secPerKm) {
  return 3600 / secPerKm;
}

// 小数桁で丸めた整数単位に変換し、繰り上がり（59.96秒→1分など）を正しく扱う
function toUnits(seconds, decimals) {
  const scale = 10 ** decimals;
  const units = Math.round(seconds * scale);
  const frac = units % scale;
  const whole = (units - frac) / scale;
  return { whole, frac, scale };
}

function pad2(n) {
  return String(n).padStart(2, '0');
}

// 時計表記: 2:05:30 / 14:30 / 14:30.5
export function formatClock(seconds, decimals = 0) {
  const { whole, frac } = toUnits(seconds, decimals);
  const h = Math.floor(whole / 3600);
  const m = Math.floor((whole % 3600) / 60);
  const s = whole % 60;
  const fracStr = decimals > 0 ? '.' + String(frac).padStart(decimals, '0') : '';
  if (h > 0) return `${h}:${pad2(m)}:${pad2(s)}${fracStr}`;
  return `${m}:${pad2(s)}${fracStr}`;
}

// 陸上表記: 3'20" / 1'20"5 / 58"3
export function formatPace(seconds, decimals = 0) {
  const { whole, frac } = toUnits(seconds, decimals);
  const m = Math.floor(whole / 60);
  const s = whole % 60;
  const fracStr = decimals > 0 ? String(frac).padStart(decimals, '0') : '';
  if (m === 0) return `${s}"${fracStr}`;
  return `${m}'${pad2(s)}"${fracStr}`;
}

export function formatDistance(meters) {
  if (meters >= 1000) return `${parseFloat((meters / 1000).toFixed(4))}km`;
  return `${parseFloat(meters.toFixed(1))}m`;
}

// 距離に応じて選べるスプリット間隔（2〜60 区間に収まるもの）
export function splitOptions(meters) {
  return SPLIT_INTERVALS.filter((i) => meters / i >= 2 && meters / i <= 60);
}

export function defaultSplit(meters) {
  const opts = splitOptions(meters);
  if (opts.length === 0) return null;
  if (meters > 20000 && opts.includes(5000)) return 5000;
  if (meters > 5000 && opts.includes(1000)) return 1000;
  if (opts.includes(400)) return 400;
  return opts[0];
}

// interval ごとの通過タイム。最後はゴール地点
export function splits(meters, secPerKm, interval) {
  const rows = [];
  for (let d = interval; d < meters - 1e-9; d += interval) {
    rows.push({ meters: d, seconds: timeFromPace(d, secPerKm) });
  }
  rows.push({ meters, seconds: timeFromPace(meters, secPerKm) });
  return rows;
}

// Riegel の式 T2 = T1 × (D2 / D1)^1.06 による予想タイム
export function riegel(meters, seconds, targetMeters, exponent = 1.06) {
  return seconds * (targetMeters / meters) ** exponent;
}
