#!/usr/bin/env node
// Builds src/stations.json from the Yandex `stations_list` method (~40 MB).
// Keeps Moscow-region railway stops only: [yandexCode, title, direction].
//
// Usage: YANDEX_API_KEY=… node scripts/build-stations.mjs
// Docs: https://yandex.ru/dev/rasp/doc/ru/reference/stations-list
import { writeFile } from "node:fs/promises";

const key = process.env.YANDEX_API_KEY;
if (!key) {
  console.error("Set YANDEX_API_KEY");
  process.exit(1);
}

const url = new URL("https://api.rasp.yandex-net.ru/v3.0/stations_list/");
url.search = new URLSearchParams({ apikey: key, format: "json", lang: "ru_RU" });
const res = await fetch(url);
if (!res.ok) throw new Error(`stations_list ${res.status}: ${await res.text()}`);
const data = await res.json();

const RAIL_TYPES = new Set(["train", "suburban", "поезд", "электричка"]);
const rows = [];
for (const country of data.countries) {
  if (country.title !== "Россия") continue;
  for (const region of country.regions) {
    if (!/моск/i.test(region.title ?? "")) continue;
    for (const settlement of region.settlements) {
      for (const st of settlement.stations) {
        const code = st.codes?.yandex_code;
        if (!code || !RAIL_TYPES.has(String(st.transport_type).toLowerCase())) continue;
        rows.push([code, st.title, st.direction ?? ""]);
      }
    }
  }
}
rows.sort((x, y) => x[1].localeCompare(y[1], "ru"));

const out = new URL("../src/stations.json", import.meta.url);
await writeFile(out, JSON.stringify(rows) + "\n");
console.log(`Wrote ${rows.length} stations to ${out.pathname}`);
