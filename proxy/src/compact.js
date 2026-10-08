// Converts Yandex Rasp `search` segments into the compact form sent to the watch.
//
// Connect IQ guidance: BLE transfers run at ~400-800 bytes/s and the background
// process has a 32 KB heap, so the watch receives only what it draws:
// a flat array [departureMinute, durationMinutes, flags, ...] per direction.

const FLAG_EXPRESS = 1;
const FLAG_AEROEXPRESS = 2;

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

function compactSegments(segments) {
  const rows = segments
    .filter((s) => !s.has_transfers && s.departure && s.arrival)
    .map((s) => [toMinutes(s.departure), Math.round(Number(s.duration) / 60), flagsOf(s.thread)])
    .sort((x, y) => x[0] - y[0] || x[1] - y[1]);
  return rows.flat();
}

module.exports = { FLAG_EXPRESS, FLAG_AEROEXPRESS, toMinutes, flagsOf, compactSegments };
