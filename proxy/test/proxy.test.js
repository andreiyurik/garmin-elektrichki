import assert from "node:assert/strict";
import { test } from "node:test";
import { compactSegments, FLAG_EXPRESS, toMinutes } from "../src/compact.js";
import { normalize, resolveStation } from "../src/stations.js";
import { searchAll } from "../src/yandex.js";

const seg = (dep, arr, durMin, express_type = null, extra = {}) => ({
  departure: `2026-10-07T${dep}:00+03:00`,
  arrival: `2026-10-07T${arr}:00+03:00`,
  duration: durMin * 60,
  has_transfers: false,
  thread: { express_type },
  ...extra,
});

test("toMinutes reads the Moscow wall clock", () => {
  assert.equal(toMinutes("2026-10-07T00:00:00+03:00"), 0);
  assert.equal(toMinutes("2026-10-07T08:42:00+03:00"), 522);
  assert.equal(toMinutes("2026-10-07T23:59:00+03:00"), 1439);
});

test("compactSegments sorts, flattens, flags express, drops transfers", () => {
  const out = compactSegments([
    seg("09:03", "09:26", 23),
    seg("08:51", "09:08", 17, "express"),
    seg("08:00", "09:00", 60, null, { has_transfers: true }),
  ]);
  assert.deepEqual(out, [531, 17, FLAG_EXPRESS, 543, 23, 0]);
});

const STATIONS = [
  ["s9600721", "Одинцово", "Белорусское"],
  ["s9601666", "Беговая", "Белорусское"],
  ["s9601000", "Одинцово-2", "Тестовое"],
  ["s9602000", "Лесной Городок", "Киевское"],
];

test("normalize drops station-type words and ё", () => {
  assert.equal(normalize("пл. Беговая"), "беговая");
  assert.equal(normalize("Станция Лесной  Городок"), "лесной городок");
  assert.equal(normalize("Щёлково"), "щелково");
});

test("resolveStation prefers exact, then prefix, then substring", () => {
  assert.equal(resolveStation("одинцово", STATIONS).code, "s9600721");
  assert.equal(resolveStation("Бегов", STATIONS).code, "s9601666");
  assert.equal(resolveStation("городок", STATIONS).code, "s9602000");
  assert.equal(resolveStation("s9601666", STATIONS).title, "Беговая");
  assert.equal(resolveStation("Нет такой", STATIONS), null);
  assert.equal(resolveStation("", STATIONS), null);
});

test("searchAll follows pagination", async () => {
  const calls = [];
  const fakeFetch = async (url) => {
    const offset = Number(url.searchParams.get("offset"));
    calls.push(offset);
    const n = offset === 0 ? 100 : 30;
    return Response.json({
      pagination: { total: 130, limit: 100, offset },
      segments: Array.from({ length: n }, () => seg("10:00", "10:20", 20)),
    });
  };
  const all = await searchAll("k", "s1", "s2", "2026-10-07", fakeFetch);
  assert.equal(all.length, 130);
  assert.deepEqual(calls, [0, 100]);
});
