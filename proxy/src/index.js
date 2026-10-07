// Cloudflare Worker between the watch and Yandex Rasp.
//
//   GET /v1/day?a=<station>&b=<station>&date=YYYY-MM-DD
//     -> {"v":1,"date":"…","a":"Одинцово","b":"Беговая","ab":[dep,dur,flags,…],"ba":[…]}
//   GET /v1/stations?q=<text>   (helper for checking what a name resolves to)
//
// Responses are cached at the edge, so one route/day costs one Yandex request
// pair no matter how many watches ask for it.
import { compactSegments } from "./compact.js";
import { resolveStation, searchStations } from "./stations.js";
import { searchAll, UpstreamError } from "./yandex.js";

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const MAX_DAYS_AHEAD = 30;
const TTL_SECONDS = 6 * 60 * 60;

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (request.method !== "GET") return json({ error: "method" }, 405);

    if (url.pathname === "/v1/stations") {
      return json({ stations: searchStations(url.searchParams.get("q") ?? "") });
    }
    if (url.pathname !== "/v1/day") return json({ error: "not_found" }, 404);

    const date = url.searchParams.get("date") ?? "";
    if (!isAllowedDate(date)) return json({ error: "date" }, 400);
    const a = resolveStation(url.searchParams.get("a"));
    if (!a) return json({ error: "station", which: "a" }, 404);
    const b = resolveStation(url.searchParams.get("b"));
    if (!b) return json({ error: "station", which: "b" }, 404);

    // Cache on resolved codes so "Одинцово" and "одинцово" share one entry.
    const cacheKey = new Request(`https://cache.local/v1/day/${a.code}/${b.code}/${date}`);
    const cache = caches.default;
    const hit = await cache.match(cacheKey);
    if (hit) return hit;

    let ab, ba;
    try {
      [ab, ba] = await Promise.all([
        searchAll(env.YANDEX_API_KEY, a.code, b.code, date),
        searchAll(env.YANDEX_API_KEY, b.code, a.code, date),
      ]);
    } catch (e) {
      if (e instanceof UpstreamError) {
        console.error(e.message);
        return json({ error: "upstream", status: e.status }, 502);
      }
      throw e;
    }

    const res = json(
      { v: 1, date, a: a.title, b: b.title, ab: compactSegments(ab), ba: compactSegments(ba) },
      200,
      { "Cache-Control": `public, max-age=${TTL_SECONDS}` },
    );
    ctx.waitUntil(cache.put(cacheKey, res.clone()));
    return res;
  },
};

function isAllowedDate(date) {
  if (!DATE_RE.test(date)) return false;
  const day = Date.parse(`${date}T00:00:00+03:00`);
  if (Number.isNaN(day)) return false;
  const diffDays = (day - Date.now()) / 86_400_000;
  return diffDays > -2 && diffDays < MAX_DAYS_AHEAD;
}

function json(body, status = 200, headers = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", ...headers },
  });
}
