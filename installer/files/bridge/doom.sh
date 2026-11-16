#!/bin/sh
# Forward every argument to this installation's Windows Doom CLI.
set -eu
bridge_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
mkdir -p "$bridge_root/tmp"
request=$(mktemp "$bridge_root/tmp/request.XXXXXXXX")
trap 'rm -f -- "$request"' EXIT HUP INT TERM
printf '%s\000' 1 "${WSL_DISTRO_NAME:-}" > "$request"
for argument do printf '%s\000' "$argument" >> "$request"; done
payload=$(base64 < "$request" | tr -d '\r\n')
rm -f -- "$request"
trap - EXIT HUP INT TERM
client=$(printf '%s' '@CLIENT_BASE64@' | base64 -d)
powershell=$(printf '%s' '@POWERSHELL_BASE64@' | base64 -d)
exec "$powershell" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$client" -Request "$payload"
