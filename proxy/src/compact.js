// Converts Yandex Rasp `search` segments into the compact form sent to the watch.
//
// Connect IQ limits drive the format: BLE runs at ~400-800 bytes/s and the
// glance and background processes have 32 KB each (a dense MCD day as nested
// arrays ran the fenix 6 glance out of memory). So each train is ONE number:
//
//   bits  0-10  departure, minutes since midnight (0..1439)
//   bits 11-12  flags (1 = express, 2 = aeroexpress)
//   bits 13-20  terminal: index into the day's string table `s`
//   bits 21-28  platform: index into `s` (0 = "")
//
// Strings repeat all day (same terminals and platforms), so they live once in
// `s` and trains refer to them by index.

const FLAG_EXPRESS = 1;
const FLAG_AEROEXPRESS = 2;
const MAX_STRINGS = 256; // 8-bit indexes

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

function packTrain(departure, flags, terminal, platform) {
  return departure | (flags << 11) | (terminal << 13) | (platform << 21);
}

class StringTable {
  constructor() {
    this.list = [""];
    this.index = new Map([["", 0]]);
  }
  id(value) {
    const s = String(value ?? "").trim();
    if (!this.index.has(s)) {
      if (this.list.length >= MAX_STRINGS) throw new Error("String table overflow");
      this.index.set(s, this.list.length);
      this.list.push(s);
    }
    return this.index.get(s);
  }
}

function compactSegments(segments, table) {
  return segments
    .filter((s) => !s.has_transfers && s.departure)
    .map((s) => ({
      dep: toMinutes(s.departure),
      packed: packTrain(toMinutes(s.departure), flagsOf(s.thread), table.id(terminalOf(s.thread)), table.id(s.departure_platform)),
    }))
    .sort((x, y) => x.dep - y.dep)
    .map((t) => t.packed);
}

// Both directions of a day with their shared string table.
function compactDay(abSegments, baSegments) {
  const table = new StringTable();
  const ab = compactSegments(abSegments, table);
  const ba = compactSegments(baSegments, table);
  return { ab, ba, s: table.list };
}

module.exports = { FLAG_EXPRESS, FLAG_AEROEXPRESS, toMinutes, flagsOf, terminalOf, packTrain, compactDay };
