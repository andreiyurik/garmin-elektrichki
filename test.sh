#!/usr/bin/env bash
# Runs every check: proxy tests, a strict build for each device in the
# manifest, and the watch unit tests in the Connect IQ simulator.
#
#   ./test.sh            everything
#   ./test.sh proxy      proxy tests only (what CI runs)
set -euo pipefail
cd "$(dirname "$0")"

SDK=${CIQ_SDK:-$(cat ~/.Garmin/ConnectIQ/current-sdk.cfg 2>/dev/null || true)}
KEY=${CIQ_KEY:-~/.Garmin/ConnectIQ/keys/developer_key.der}
DEVICES_DIR=~/.Garmin/ConnectIQ/Devices
TEST_DEVICE=${TEST_DEVICE:-fenix6}
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT

echo "== proxy tests"
(cd proxy && npm test --silent)
[[ ${1:-} == proxy ]] && exit 0

echo "== watch builds (type check: strict)"
missing=()
for device in $(grep -oP 'product id="\K[^"]+' watch/manifest.xml); do
  if [[ ! -d $DEVICES_DIR/$device ]]; then
    missing+=("$device")
    continue
  fi
  log=$("$SDK/bin/monkeyc" -f watch/monkey.jungle -d "$device" -o "$OUT/$device.prg" -y "$KEY" -l 3 2>&1) \
    || { echo "$log" | grep -v WARNING; echo "BUILD FAILED: $device"; exit 1; }
  echo "ok  $device"
done
((${#missing[@]})) && echo "skipped (no device files, download in SDK Manager): ${missing[*]}"

echo "== watch unit tests on $TEST_DEVICE"
"$SDK/bin/monkeyc" -f watch/monkey.jungle -d "$TEST_DEVICE" -o "$OUT/test.prg" -y "$KEY" -l 3 --unit-test 2>&1 \
  | grep -v WARNING || true
if ! pgrep -x simulator >/dev/null; then
  # setsid -f always forks, so the simulator is never this script's child.
  (cd "$SDK/bin" && WEBKIT_DISABLE_DMABUF_RENDERER=1 setsid -f ./simulator >/dev/null 2>&1 < /dev/null)
  sleep 8
fi
result=$(timeout 300 "$SDK/bin/monkeydo" "$OUT/test.prg" "$TEST_DEVICE" -t 2>&1 || true)
echo "$result" | grep -E 'FAILED:|^Ran |PASSED|FAILED \(' || { echo "$result"; exit 1; }
echo "$result" | grep -q '^PASSED' || exit 1
