const assert = require("node:assert/strict");
const { test } = require("node:test");
const { compactDay, FLAG_EXPRESS, packTrain, terminalOf, toMinutes } = require("../src/compact.js");
const { normalize, resolveStation } = require("../src/stations.js");
const { searchAll } = require("../src/yandex.js");

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

test("terminalOf takes the last part of the thread title", () => {
  assert.equal(terminalOf({ title: "Москва (Курский вокзал) — Петушки" }), "Петушки");
  assert.equal(terminalOf({ short_title: "Одинцово — Лобня", title: "x" }), "Лобня");
  assert.equal(terminalOf({ title: "Кольцевой" }), "Кольцевой");
  assert.equal(terminalOf(undefined), "");
});

test("packTrain keeps every field in its own bits", () => {
  const x = packTrain(1439, 2, 255, 255);
  assert.equal(x & 0x7ff, 1439);
  assert.equal((x >> 11) & 3, 2);
  assert.equal((x >> 13) & 0xff, 255);
  assert.equal((x >> 21) & 0xff, 255);
  assert.ok(x < 2 ** 31, "fits a signed 32-bit Monkey C Number");
});

test("compactDay sorts, flags express, drops transfers, shares a string table", () => {
  const day = compactDay(
    [
      seg("09:03", "09:26", 23, null, { departure_platform: "2", thread: { title: "Одинцово — Лобня" } }),
      seg("08:51", "09:08", 17, "express", { departure_platform: "2", thread: { express_type: "express", title: "Одинцово — Беговая" } }),
      seg("08:00", "09:00", 60, null, { has_transfers: true }),
    ],
    [seg("18:10", "18:33", 23, null, { departure_platform: null, thread: { title: "Лобня — Одинцово" } })],
  );
  // Strings are numbered in input order; rows are then sorted by time.
  assert.deepEqual(day.s, ["", "Лобня", "2", "Беговая", "Одинцово"]);
  assert.deepEqual(day.ab, [packTrain(531, FLAG_EXPRESS, 3, 2), packTrain(543, 0, 1, 2)]);
  assert.deepEqual(day.ba, [packTrain(1090, 0, 4, 0)]);
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

const { handleRequest } = require("../src/index.js");

test("handleRequest validates input and caches by resolved codes", async () => {
  const now = Date.parse("2026-10-07T09:00:00+03:00");
  let calls = 0;
  const fakeFetch = async (url) => {
    calls++;
    const from = url.searchParams.get("from");
    return Response.json({
      pagination: { total: 1 },
      segments: [seg(from === "s9600721" ? "08:42" : "18:10", "09:05", 23)],
    });
  };
  const ctx = { apiKey: "k", fetchImpl: fakeFetch, now };

  assert.equal((await handleRequest({ a: "x", b: "y", date: "bad" }, ctx)).statusCode, 400);
  const missing = await handleRequest({ a: "Нет", b: "Беговая", date: "2026-10-07" }, ctx);
  assert.equal(missing.statusCode, 404);
  assert.deepEqual(JSON.parse(missing.body), { error: "station", which: "a", q: "Нет" });

  // stations.json is empty in the repo, so pass codes directly.
  const res = await handleRequest({ a: "s9600721", b: "s9601666", date: "2026-10-07" }, ctx);
  assert.equal(res.statusCode, 200);
  const body = JSON.parse(res.body);
  assert.equal(body.v, 3);
  assert.deepEqual(body.ab, [522]);
  assert.deepEqual(body.ba, [1090]);
  assert.deepEqual(body.s, [""]);

  await handleRequest({ a: "s9600721", b: "s9601666", date: "2026-10-07" }, ctx);
  assert.equal(calls, 2, "second call is served from cache");
});
