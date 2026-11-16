#!/bin/sh
# Called over wsl.exe stdin. Only the selected Linux user's managed files and
# exact, installation-specific shell blocks are changed.
set -eu
action=$1
id=$2
shell_name=${SHELL:-/bin/sh}
case "$id" in ''|*[!0-9a-f]*) echo 'Invalid installation id' >&2; exit 1 ;; esac
[ "${#id}" -eq 32 ] || exit 1
root="$HOME/.local/share/doom-windows/$id"
begin="# >>> Doom Emacs WSL $id >>>"
end="# <<< Doom Emacs WSL $id <<<"
block=$(printf '%s\n%s\n%s' "$begin" "[ ! -r \"\$HOME/.local/share/doom-windows/$id/env.sh\" ] || . \"\$HOME/.local/share/doom-windows/$id/env.sh\"" "$end")

for command in base64 realpath wslpath sha256sum awk mktemp grep stat; do
    command -v "$command" >/dev/null || { echo "Required command missing: $command" >&2; exit 1; }
done
if [ "$action" = probe ]; then
    case "${SHELL:-/bin/sh}" in */bash|*/zsh|*/sh|*/dash) ;; *) echo 'Automatic PATH integration currently supports Bash, Zsh and POSIX login shells.' >&2; exit 1 ;; esac
    printf 'DOOM_USER=%s\nDOOM_HOME=%s\n' "$(id -un)" "$HOME"
    exit 0
fi
[ "$HOME" = "$3" ] || { echo 'Linux home changed; refusing to modify another profile.' >&2; exit 1; }
[ ! -L "$root" ] || { echo 'Managed root is a symlink' >&2; exit 1; }
if [ -e "$root" ]; then
    [ -f "$root/.owner" ] && [ "$(cat "$root/.owner")" = "$id" ] || { echo 'Unrecognized managed root' >&2; exit 1; }
fi
for relative in bin tmp .owner .checksums .created-profiles env.sh bin/doom bin/doom-wsl; do
    [ ! -L "$root/$relative" ] || { echo "Redirected managed path: $relative" >&2; exit 1; }
done

verify_owned() {
    [ -f "$root/.checksums" ] || return 0
    while read -r expected relative; do
        case "$relative" in bin/doom|bin/doom-wsl|env.sh) ;; *) echo 'Invalid ownership checksum entry' >&2; return 1 ;; esac
        [ -e "$root/$relative" ] || continue
        actual=$(sha256sum "$root/$relative")
        actual=${actual%% *}
        [ "$actual" = "$expected" ] || return 1
    done < "$root/.checksums"
}

remove_block() {
    file=$1
    [ -e "$file" ] || return 0
    [ ! -L "$file" ] || { echo "Shell profile is a symlink: $file" >&2; return 1; }
    grep -Fqx "$begin" "$file" || return 0
    current=$(awk -v b="$begin" -v e="$end" '$0==b{inside=1} inside{print} $0==e{inside=0}' "$file")
    [ "$current" = "$block" ] || { echo "Managed PATH block was edited; preserving $file" >&2; return 1; }
    temporary=$(mktemp "$HOME/.doom-wsl-profile.XXXXXXXX")
    if awk -v b="$begin" -v e="$end" '$0==b{inside=1;next} $0==e{inside=0;next} !inside{print}' "$file" > "$temporary"; then
        chmod "$(stat -c %a "$file")" "$temporary"
        cat "$temporary" > "$file"
    else
        rm -f -- "$temporary"
        return 1
    fi
    rm -f -- "$temporary"
}

if [ "$action" = remove ]; then
    # Validate every hook and managed file before making any destructive change.
    for profile in .profile .bashrc .zshrc; do
        file="$HOME/$profile"
        if [ -e "$file" ] && grep -Fqx "$begin" "$file"; then
            current=$(awk -v b="$begin" -v e="$end" '$0==b{inside=1} inside{print} $0==e{inside=0}' "$file")
            [ ! -L "$file" ] && [ "$current" = "$block" ] || { echo "Edited or redirected shell block: $file" >&2; exit 1; }
        fi
    done
    verify_owned || { echo 'Managed WSL scripts were edited; preserving them for review.' >&2; exit 1; }
    for profile in .profile .bashrc .zshrc; do remove_block "$HOME/$profile"; done
    if [ -f "$root/.created-profiles" ]; then
        while IFS= read -r profile; do
            case "$profile" in .profile|.bashrc|.zshrc) ;; *) exit 1 ;; esac
            [ -s "$HOME/$profile" ] || rm -f -- "$HOME/$profile"
        done < "$root/.created-profiles"
    fi
    # The root is fixed under this home and its .owner was checked above.
    if [ -d "$root" ]; then rm -r -- "$root"; fi
    exit 0
fi
[ "$action" = install ] || exit 1
verify_owned || { echo 'Existing managed WSL scripts were edited; refusing to overwrite.' >&2; exit 1; }
for profile in .profile .bashrc .zshrc; do
    [ ! -L "$HOME/$profile" ] || { echo "Shell profile is a symlink: $HOME/$profile" >&2; exit 1; }
done
mkdir -p "$root/bin" "$root/tmp"
chmod 700 "$root" "$root/tmp"
printf '%s\n' "$id" > "$root/.owner"
touch "$root/.created-profiles"
printf '%s' "$4" | base64 -d > "$root/bin/doom-wsl"
printf '%s' "$5" | base64 -d > "$root/bin/doom"
chmod 700 "$root/bin/doom-wsl" "$root/bin/doom"
printf 'case ":$PATH:" in *":$HOME/.local/share/doom-windows/%s/bin:"*) ;; *) export PATH="$HOME/.local/share/doom-windows/%s/bin:$PATH" ;; esac\n' "$id" "$id" > "$root/env.sh"
(cd "$root" && sha256sum bin/doom-wsl bin/doom env.sh > .checksums)
for profile in .profile .bashrc .zshrc; do
    [ "$profile" != .zshrc ] || [ -e "$HOME/$profile" ] || [ "${shell_name##*/}" = zsh ] || continue
    file="$HOME/$profile"
    if [ ! -e "$file" ]; then printf '%s\n' "$profile" >> "$root/.created-profiles"; fi
    if [ -e "$file" ] && grep -Fqx "$begin" "$file"; then remove_block "$file"; fi
    # A newline separates the managed block from a preexisting unterminated line.
    if [ -s "$file" ] && [ "$(tail -c 1 "$file" | wc -l)" -eq 0 ]; then printf '\n' >> "$file"; fi
    printf '%s\n' "$block" >> "$file"
done
printf 'DOOM_ROOT=%s\n' "$root"
