#!/bin/sh
# Windows Emacs client. Template values are base64, never shell code.
set -eu
wait=0
frame=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --wait) wait=1; shift ;;
        --new-frame) frame=1; shift ;;
        -t|--tty) echo 'doom-wsl: a Windows GUI Emacs server cannot create a WSL terminal frame.' >&2; exit 2 ;;
        -h|--help) echo 'Usage: doom-wsl [--wait] [--new-frame] [--] [+LINE[:COLUMN]] FILE...'; exit 0 ;;
        --) shift; break ;;
        -*) echo "doom-wsl: unknown option: $1 (use -- before a filename beginning with -)" >&2; exit 2 ;;
        *) break ;;
    esac
done
bridge_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
mkdir -p "$bridge_root/tmp"
request=$(mktemp "$bridge_root/tmp/request.XXXXXXXX")
trap 'rm -f -- "$request"' EXIT HUP INT TERM
printf '%s\000' 1 "$wait" "$frame" "${WSL_DISTRO_NAME:-}" > "$request"
if [ "$#" -eq 0 ]; then set -- .; fi
for file do
    case "$file" in
        +[0-9]*)
            if printf '%s' "$file" | grep -Eq '^\+[0-9]+(:[0-9]+)?$'; then
                printf '%s\000' "$file" >> "$request"
                continue
            fi ;;
    esac
    absolute=$(realpath -m -- "$file")
    windows=$(wslpath -w "$absolute")
    printf '%s\000' "$windows" >> "$request"
done
payload=$(base64 < "$request" | tr -d '\r\n')
rm -f -- "$request"
trap - EXIT HUP INT TERM
client=$(printf '%s' '@CLIENT_BASE64@' | base64 -d)
powershell=$(printf '%s' '@POWERSHELL_BASE64@' | base64 -d)
exec "$powershell" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$client" -Request "$payload"
