import {
  EVENTS,
  parseHms,
  paceFromTime,
  timeFromPace,
  speedKmh,
  formatClock,
  formatPace,
  formatDistance,
  splitOptions,
  defaultSplit,
  splits,
  riegel,
} from './pace.js';

const STORAGE_KEY = 'pace-calculator-state-v1';

const state = {
  mode: 'time',
  eventId: '5000',
  customValue: '',
  customUnit: 'km',
  h: '',
  m: '',
  s: '',
  pm: '',
  ps: '',
  paceUnit: 'km',
  split: null,
};

const $ = (id) => document.getElementById(id);

function load() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null');
    if (saved && typeof saved === 'object') {
      for (const key of Object.keys(state)) {
        if (key in saved) state[key] = saved[key];
      }
    }
  } catch {
    // 保存データが読めなくても初期状態で動かす
  }
  if (!EVENTS.some((e) => e.id === state.eventId)) state.eventId = '5000';
}

function save() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch {
    // プライベートブラウズ等で保存できなくても計算は続ける
  }
}

function currentMeters() {
  const ev = EVENTS.find((e) => e.id === state.eventId);
  if (ev.meters) return ev.meters;
  const v = Number(String(state.customValue).trim());
  if (!Number.isFinite(v) || v <= 0) return null;
  return state.customUnit === 'km' ? v * 1000 : v;
}

// 1時間を超えうる距離だけ「時間」欄を出す
function showsHours(meters) {
  return state.eventId === 'custom' || (meters ?? 0) >= 10000;
}

// ---------- 入力欄の描画 ----------

function renderEvents() {
  const box = $('events');
  box.innerHTML = '';
  for (const ev of EVENTS) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'chip';
    b.textContent = ev.label;
    b.dataset.id = ev.id;
    b.setAttribute('aria-pressed', String(ev.id === state.eventId));
    b.addEventListener('click', () => {
      state.eventId = ev.id;
      state.split = null;
      syncControls();
      update();
      if (ev.id === 'custom' && !state.customValue) $('custom-value').focus();
    });
    box.appendChild(b);
  }
}

function setPressed(container, attr, value) {
  for (const b of container.querySelectorAll('button')) {
    b.setAttribute(container.getAttribute('role') === 'tablist' ? 'aria-selected' : 'aria-pressed',
      String(b.dataset[attr] === value));
  }
}

function syncControls() {
  setPressed(document.querySelector('[role=tablist]'), 'mode', state.mode);
  for (const b of $('events').children) {
    b.setAttribute('aria-pressed', String(b.dataset.id === state.eventId));
  }
  $('custom-distance').hidden = state.eventId !== 'custom';
  setPressed($('custom-unit'), 'unit', state.customUnit);
  setPressed($('pace-unit'), 'unit', state.paceUnit);
  $('time-input').hidden = state.mode !== 'time';
  $('pace-input').hidden = state.mode !== 'pace';
  const hours = showsHours(currentMeters());
  $('hours-box').hidden = !hours;
  $('hours-colon').hidden = !hours;
}

// ---------- 計算と結果の描画 ----------

function heroItem(label, value, sub = '') {
  return `<div class="hero-item"><div class="k">${label}</div><div class="v">${value}</div>${
    sub ? `<div class="sub">${sub}</div>` : ''}</div>`;
}

function stat(label, value) {
  return `<div class="stat"><div class="k">${label}</div><div class="v">${value}</div></div>`;
}

function compute() {
  const meters = currentMeters();
  if (!meters) return { meters: null };
  if (state.mode === 'time') {
    const seconds = parseHms(showsHours(meters) ? state.h : '', state.m, state.s);
    if (!seconds) return { meters };
    return { meters, seconds, secPerKm: paceFromTime(meters, seconds) };
  }
  const pace = parseHms('', state.pm, state.ps);
  if (!pace) return { meters };
  const secPerKm = state.paceUnit === 'km' ? pace : pace * 2.5;
  return { meters, seconds: timeFromPace(meters, secPerKm), secPerKm };
}

function goalDecimals(meters) {
  return meters <= 10000 ? 1 : 0;
}

function renderResults() {
  const out = $('results');
  const { meters, seconds, secPerKm } = compute();

  if (!meters) {
    out.innerHTML = '<div class="card empty">距離を入力してください</div>';
    return;
  }
  if (!secPerKm) {
    const what = state.mode === 'time' ? 'タイム' : 'ペース';
    out.innerHTML = `<div class="card empty">${formatDistance(meters)} の${what}を入力すると<br>すぐに結果が表示されます</div>`;
    return;
  }

  const per400 = secPerKm * 0.4;
  let hero;
  if (state.mode === 'time') {
    hero = heroItem('1kmあたり', `${formatPace(secPerKm)}`, '/km') +
      heroItem('400mあたり', formatPace(per400, 1), `${per400.toFixed(1)}秒`);
  } else {
    const other = state.paceUnit === 'km'
      ? heroItem('400mあたり', formatPace(per400, 1), `${per400.toFixed(1)}秒`)
      : heroItem('1kmあたり', formatPace(secPerKm), '/km');
    hero = heroItem('ゴールタイム', formatClock(seconds, goalDecimals(meters)), formatDistance(meters)) + other;
  }

  const stats = stat('200m', formatPace(secPerKm * 0.2, 1)) +
    stat('100m', formatPace(secPerKm * 0.1, 1)) +
    stat('時速', `${speedKmh(secPerKm).toFixed(2)}<small>km/h</small>`);

  let html = `<div class="hero">${hero}</div><section class="card"><div class="stats">${stats}</div></section>`;
  html += renderSplits(meters, secPerKm);
  html += state.mode === 'time' ? renderPredictions(meters, seconds) : renderSamePace(secPerKm);
  out.innerHTML = html;

  const seg = out.querySelector('#split-unit');
  if (seg) {
    seg.addEventListener('click', (e) => {
      const b = e.target.closest('button');
      if (!b) return;
      state.split = Number(b.dataset.unit);
      update();
    });
  }
}

function renderSplits(meters, secPerKm) {
  const opts = splitOptions(meters);
  if (opts.length === 0) return '';
  const interval = opts.includes(state.split) ? state.split : defaultSplit(meters);
  const rows = splits(meters, secPerKm, interval);
  const dec = goalDecimals(meters);
  const buttons = opts.map((o) =>
    `<button type="button" data-unit="${o}" aria-pressed="${o === interval}">${formatDistance(o)}</button>`).join('');
  const body = rows.map((r, i) => {
    const goal = i === rows.length - 1;
    return `<tr class="${goal ? 'goal' : ''}"><td>${goal ? 'ゴール' : formatDistance(r.meters)}${
      goal ? `<span class="muted">${formatDistance(r.meters)}</span>` : ''}</td><td>${formatClock(r.seconds, dec)}</td></tr>`;
  }).join('');
  return `<section class="card">
    <h2 class="label">スプリット（イーブンペース）</h2>
    <div class="segmented compact" id="split-unit">${buttons}</div>
    <table class="table"><tbody>${body}</tbody></table>
  </section>`;
}

function renderPredictions(meters, seconds) {
  // Riegel 式は 3 分〜4 時間程度の記録で使うのが目安
  if (seconds < 180 || seconds > 4 * 3600) return '';
  const targets = EVENTS.filter((e) => e.meters && e.meters >= 1500 && e.meters !== meters);
  const body = targets.map((e) => {
    const t = riegel(meters, seconds, e.meters);
    return `<tr><td>${e.label}<span class="muted">${formatPace(paceFromTime(e.meters, t))}/km</span></td><td>${
      formatClock(t, goalDecimals(e.meters))}</td></tr>`;
  }).join('');
  return `<section class="card">
    <h2 class="label">この記録からの予想タイム</h2>
    <table class="table"><tbody>${body}</tbody></table>
    <p class="note">Riegel の式（T₂ = T₁ × (D₂ / D₁)^1.06）による参考値です。練習量や得意距離で実際とは差が出ます。</p>
  </section>`;
}

function renderSamePace(secPerKm) {
  const body = EVENTS.filter((e) => e.meters).map((e) =>
    `<tr><td>${e.label}</td><td>${formatClock(timeFromPace(e.meters, secPerKm), goalDecimals(e.meters))}</td></tr>`).join('');
  return `<section class="card">
    <h2 class="label">このペースでの各種目タイム</h2>
    <table class="table"><tbody>${body}</tbody></table>
  </section>`;
}

function update() {
  syncControls();
  renderResults();
  save();
}

// ---------- イベント ----------

function bindField(id, maxDigitsToAdvance, nextId) {
  const el = $(id);
  el.value = state[id];
  el.addEventListener('focus', () => el.select());
  el.addEventListener('input', () => {
    // 数字と小数点以外は捨てる（ペースト対策）
    const cleaned = el.value.replace(/[^0-9.]/g, '');
    if (cleaned !== el.value) el.value = cleaned;
    state[id] = el.value;
    update();
    // テンキーには「次へ」が無いので、桁が埋まったら次の欄へ送る
    if (nextId && maxDigitsToAdvance && /^\d+$/.test(el.value) && el.value.length >= maxDigitsToAdvance) {
      const next = $(nextId);
      if (!next.closest('[hidden]')) next.focus();
    }
  });
}

function init() {
  load();
  renderEvents();

  document.querySelector('[role=tablist]').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (!b) return;
    state.mode = b.dataset.mode;
    update();
  });
  $('custom-unit').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (!b) return;
    state.customUnit = b.dataset.unit;
    state.split = null;
    update();
  });
  $('pace-unit').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (!b) return;
    state.paceUnit = b.dataset.unit;
    update();
  });

  const custom = $('custom-value');
  custom.value = state.customValue;
  custom.addEventListener('input', () => {
    state.customValue = custom.value.replace(/[^0-9.]/g, '');
    if (custom.value !== state.customValue) custom.value = state.customValue;
    update();
  });

  bindField('h', 2, 'm');
  bindField('m', 2, 's');
  bindField('s');
  bindField('pm', 2, 'ps');
  bindField('ps');

  $('reset').addEventListener('click', () => {
    for (const id of ['h', 'm', 's', 'pm', 'ps']) {
      state[id] = '';
      $(id).value = '';
    }
    update();
  });

  update();

  if ('serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost')) {
    navigator.serviceWorker.register('sw.js').catch(() => {});
  }
}

init();
