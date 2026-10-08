// Converts Yandex Rasp `search` segments into the compact form sent to the watch.
//
// Connect IQ guidance: BLE transfers run at ~400-800 bytes/s and the background
// process has a 32 KB heap, so the watch receives only what it draws.
// Each direction is a flat array, STRIDE numbers per train:
//   [departureMinute, durationMinutes, flags, terminalIndex, platformIndex, ...]
// Strings repeat a lot (same terminals and platforms all day), so they go into
// one per-day table `s` and trains refer to them by index; index 0 is "".

const FLAG_EXPRESS = 1;
const FLAG_AEROEXPRESS = 2;
const STRIDE = 5;

// "2026-10-07T08:42:00+03:00" -> 522 (minutes since local midnight).
// Times are requested with result_timezone=Europe/Moscow, so the wall clock in
// the string is already Moscow time.
function toMinutes(iso) {
  const hh = Number(iso.slice(11, 13));
  const mm = Number(iso.slice(14, 16));
  if (!Number.isInteger(hh) || !Number.isInteger(mm)) {
    throw new Error(`Bad time: ${iso}`);
  }
  return hh * 60 + mm;
}

function flagsOf(thread) {
  switch (thread?.express_type) {
    case "express":
      return FLAG_EXPRESS;
    case "aeroexpress":
      return FLAG_AEROEXPRESS;
    default:
      return 0;
  }
}

// "Москва (Курский вокзал) — Петушки" -> "Петушки"
function terminalOf(thread) {
  const title = thread?.short_title || thread?.title || "";
  const parts = title.split(/\s+[—–-]\s+/);
  return parts[parts.length - 1].trim();
}

class StringTable {
  constructor() {
    this.list = [""];
    this.index = new Map([["", 0]]);
  }
  id(value) {
    const s = String(value ?? "").trim();
    if (!this.index.has(s)) {
      this.index.set(s, this.list.length);
      this.list.push(s);
    }
    return this.index.get(s);
  }
}

function compactSegments(segments, table) {
  const rows = segments
    .filter((s) => !s.has_transfers && s.departure && s.arrival)
    .map((s) => [
      toMinutes(s.departure),
      Math.round(Number(s.duration) / 60),
      flagsOf(s.thread),
      table.id(terminalOf(s.thread)),
      table.id(s.departure_platform),
    ])
    .sort((x, y) => x[0] - y[0] || x[1] - y[1]);
  return rows.flat();
}

// Both directions of a day with their shared string table.
function compactDay(abSegments, baSegments) {
  const table = new StringTable();
  const ab = compactSegments(abSegments, table);
  const ba = compactSegments(baSegments, table);
  return { ab, ba, s: table.list };
}

module.exports = { FLAG_EXPRESS, FLAG_AEROEXPRESS, STRIDE, toMinutes, flagsOf, terminalOf, compactDay };
