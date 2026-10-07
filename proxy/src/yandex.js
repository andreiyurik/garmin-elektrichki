// Yandex Rasp API v3.0 client.
// Docs: https://yandex.ru/dev/rasp/doc/ru/reference/schedule-point-point
const BASE = "https://api.rasp.yandex-net.ru/v3.0";
const PAGE = 100; // documented maximum for `limit`

export class UpstreamError extends Error {
  constructor(status, body) {
    super(`Yandex API ${status}: ${body.slice(0, 300)}`);
    this.status = status;
  }
}

// All suburban segments between two stations on a date, following pagination.
export async function searchAll(apiKey, from, to, date, fetchImpl = fetch) {
  const segments = [];
  for (let offset = 0; ; offset += PAGE) {
    const url = new URL(`${BASE}/search/`);
    url.search = new URLSearchParams({
      apikey: apiKey,
      format: "json",
      lang: "ru_RU",
      from,
      to,
      date,
      transport_types: "suburban",
      result_timezone: "Europe/Moscow",
      limit: String(PAGE),
      offset: String(offset),
    });
    const res = await fetchImpl(url);
    if (!res.ok) throw new UpstreamError(res.status, await res.text());
    const body = await res.json();
    segments.push(...(body.segments ?? []));
    const total = body.pagination?.total ?? 0;
    if (offset + PAGE >= total) return segments;
  }
}
