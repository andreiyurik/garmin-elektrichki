#!/usr/bin/env bash
# Deploys the proxy as a public Yandex Cloud Function.
# Commands follow https://yandex.cloud/ru/docs/functions/operations/function/version-manage
#
# Prerequisites: `yc init` done; Yandex Rasp key in ~/.config/mcd-garmin/yandex_key.
set -euo pipefail

NAME=elektrichki-proxy
KEY_FILE=~/.config/mcd-garmin/yandex_key
cd "$(dirname "$0")"

[[ -s $KEY_FILE ]] || { echo "No API key in $KEY_FILE" >&2; exit 1; }

# Station names -> codes; Yandex data, built here and never committed.
YANDEX_API_KEY=$(cat "$KEY_FILE") node scripts/build-stations.mjs

if ! yc serverless function get --name "$NAME" >/dev/null 2>&1; then
  yc serverless function create --name "$NAME"
  yc serverless function allow-unauthenticated-invoke "$NAME"
fi

build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
cp src/*.js src/stations.json "$build/"
(cd "$build" && zip -q -r function.zip .)

yc serverless function version create \
  --function-name "$NAME" \
  --runtime nodejs22 \
  --entrypoint index.handler \
  --memory 128m \
  --execution-timeout 15s \
  --environment "YANDEX_API_KEY=$(cat "$KEY_FILE")" \
  --source-path "$build/function.zip" >/dev/null

id=$(yc serverless function get --name "$NAME" --format json | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
echo "Deployed: https://functions.yandexcloud.net/$id"
