# Электрички на Garmin

Виджет для часов Garmin fēnix 6 с расписанием электричек Москвы и МЦД:
ближайшие поезда между станциями «Дом» и «Работа», гланс в ленте виджетов,
работа без телефона на сохранённом расписании.

> Статус: в разработке. Приложение ещё не собиралось на устройстве.

## Как это работает

```
[часы] ←BLE→ [Garmin Connect на телефоне] → [proxy: Cloudflare Worker] → [API Яндекс.Расписаний]
```

- **Часы** (`watch/`, Monkey C) хранят расписание на 3 дня в `Application.Storage`.
  Фоновый сервис раз в час докачивает недостающие или устаревшие дни, поэтому
  в течение дня связь с телефоном не нужна.
- **Прокси** (`proxy/`) находит станции по названию, забирает у Яндекса оба
  направления за день и отдаёт компактный JSON (~2–4 КБ):
  `{"a":"Одинцово","b":"Беговая","ab":[мин_отпр, длит_мин, флаги, …],"ba":[…]}`.
  Ответы кэшируются на 6 часов.

## Использование

1. Установите виджет.
2. В Garmin Connect → Connect IQ → «Электрички» → Настройки укажите станции
   «Дом» и «Работа» (по названию, например `Одинцово`).
3. До выбранного часа (по умолчанию 13:00) виджет показывает поезда из дома,
   после — домой. **START** — развернуть направление, **MENU** (долгое нажатие
   UP) — обновить сейчас.

## Разработка

### Часы

Требуются [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) и файлы
устройств fēnix 6 (SDK Manager → Devices).

```sh
monkeyc -f watch/monkey.jungle -d fenix6 -o bin/app.prg -y ~/.Garmin/ConnectIQ/keys/developer_key.der -l 3
connectiq && monkeydo bin/app.prg fenix6
```

URL прокси задаётся свойством `ProxyUrl` в `watch/resources/settings/properties.xml`.

### Прокси

```sh
cd proxy
npm install
npm test
YANDEX_API_KEY=… npm run stations   # пересобрать src/stations.json
npx wrangler secret put YANDEX_API_KEY
npm run deploy
```

Ключ API: https://developer.tech.yandex.ru → «API Яндекс.Расписаний».

## Основа

- Официальная документация и примеры Connect IQ SDK: WebRequest,
  BackgroundTimer, ApplicationStorage, Menu2Sample; разделы Glances,
  Backgrounding, Persisting Data, UX Guidelines.
- Идеи интерфейса: [Avgånär](https://github.com/felwal/avganar) (Стокгольм, GPL-3.0).

## Данные

Расписание предоставлено сервисом [Яндекс.Расписания](https://rasp.yandex.ru).

## Лицензия

GPL-3.0, см. [LICENSE](LICENSE).
