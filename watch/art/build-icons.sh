#!/usr/bin/env bash
# Renders the launcher icon at each device's exact size (compiler.json
# launcherIcon / Device Reference) so the compiler never scales it.
set -euo pipefail
cd "$(dirname "$0")/.."
X='xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="https://developer.garmin.com/downloads/connect-iq/resources.xsd"'

render() { # <resource dir> <size>
  mkdir -p "$1/drawables"
  rsvg-convert -w "$2" -h "$2" art/launcher_icon.svg -o "$1/drawables/launcher_icon.png"
  printf '<resources %s>\n    <bitmap id="LauncherIcon" filename="launcher_icon.png" />\n</resources>\n' "$X" \
    > "$1/drawables/drawables.xml"
}

render resources 40               # fenix 6 family
render resources-vivoactive4 35
render resources-vivoactive4s 30
render resources-vivoactive5 56
render resources-vivoactive6 54
