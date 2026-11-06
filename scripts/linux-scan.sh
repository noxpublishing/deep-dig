#!/usr/bin/env bash
# Disk inventory and deep scan for Linux. Read-only, never asks for sudo.
# Results are candidates, not verdicts: check each one before calling it junk.
h() { printf '\n=== %s ===\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }
short() { sed "s|$HOME|~|"; }
PRUNE=(-path "$HOME/.ssh" -o -path "$HOME/.gnupg" -o -path "$HOME/.local/share/Trash" -o -name .git -o -name node_modules -o -path '/proc' -o -path '/sys')

h "System and disk"
. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Linux} / Kernel $(uname -r)"
grep -qi microsoft /proc/version 2>/dev/null && echo "WSL: check the Windows side separately."
df -h -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null
findmnt -no FSTYPE / 2>/dev/null | sed 's/^/Filesystem of \/: /'
free -h 2>/dev/null
ps -eo rss=,comm= --sort=-rss 2>/dev/null | head -6 | awk '{printf "%7.0f MB  %s\n",$1/1024,$2}'

h "Home (top 28)"
du -x -h -d 1 "$HOME" 2>/dev/null | sort -rh | head -28 | short

h "Hidden folders of 50 MB and up (last changed)"
for d in "$HOME"/.[!.]*; do [ -d "$d" ] || continue; case "$(basename "$d")" in .ssh|.gnupg|.password-store) continue;; esac; k=$(du -sk "$d" 2>/dev/null | cut -f1); [ "${k:-0}" -ge 51200 ] && printf '%s\t%s\t%s\n' "$k" "$(find "$d" -maxdepth 2 -type f -printf '%TY-%Tm-%Td\n' 2>/dev/null | sort -r | head -1)" "$d"; done | sort -rn | awk -F'\t' '{printf "%7.0f MB  last used %s  %s\n",$1/1024,$2,$3}' | short

h "Caches and data"
du -sh "$HOME/.cache"/*/ 2>/dev/null | sort -rh | head -14 | short
du -sh "$HOME/.local/share"/*/ 2>/dev/null | sort -rh | head -12 | short
du -sh "$HOME/.config"/*/ 2>/dev/null | sort -rh | head -8 | short
du -sh "$HOME/.local/share/Trash" /tmp /var/tmp /var/log 2>/dev/null | short

h "Single files of 300 MB and up"
find "$HOME" -xdev \( "${PRUNE[@]}" \) -prune -o -type f -size +300M -printf '%s\t%TY-%Tm-%Td\t%p\n' 2>/dev/null | sort -rn | head -30 | awk -F'\t' '{printf "%7.0f MB  %s  %s\n",$1/1048576,$2,$3}' | short

h "Old installers, images and VMs (20 MB and up)"
find "$HOME" -xdev \( "${PRUNE[@]}" \) -prune -o -type f \( -iname '*.iso' -o -iname '*.appimage' -o -iname '*.deb' -o -iname '*.rpm' -o -iname '*.pkg.tar.*' -o -iname '*.run' -o -iname '*.exe' -o -iname '*.msi' -o -iname '*.dmg' -o -iname '*.qcow2' -o -iname '*.vdi' -o -iname '*.vmdk' -o -iname '*.apk' \) -size +20M -printf '%s\t%p\n' 2>/dev/null | sort -rn | head -20 | awk -F'\t' '{printf "%7.0f MB  %s\n",$1/1048576,$2}' | short

h "Zip next to its unpacked folder (20 MB and up)"
for r in "$HOME/Downloads" "$HOME/Desktop" "$HOME/Schreibtisch"; do for z in "$r"/*.zip "$r"/*.tar.gz; do [ -f "$z" ] || continue; b=${z%.zip}; b=${b%.tar.gz}; [ -d "$b" ] && k=$(du -sk "$z" | cut -f1) && [ "$k" -ge 20480 ] && echo "$((k/1024)) MB  $z"; done; done | sort -rn | head -15 | short

h "Build folders in projects idle for 60 days"
now=$(date +%s)
find "$HOME" -xdev -maxdepth 5 \( -path "$HOME/.ssh" -o -path "$HOME/.gnupg" -o -path "$HOME/.local/share/Trash" -o -name .git \) -prune -o -type d \( -name node_modules -o -name target -o -name .next -o -name .venv -o -name venv -o -name __pycache__ -o -name .gradle \) -prune -print 2>/dev/null | grep -vE '/\.(cache|npm|local|cargo|rustup)/' | while IFS= read -r b; do p=$(dirname "$b"); t=$(git -C "$p" log -1 --format=%ct 2>/dev/null); [ -z "$t" ] && t=$(stat -c %Y "$p"); [ $(( (now-t)/86400 )) -ge 60 ] || continue; k=$(du -sk "$b" 2>/dev/null | cut -f1); [ "${k:-0}" -ge 20480 ] && printf '%s\t%s\t%s\n' "$k" "$(date -d "@$t" +%F)" "$b"; done | sort -rn | head -25 | awk -F'\t' '{printf "%7.0f MB  project last active %s  %s\n",$1/1024,$2,$3}' | short

h "Worktrees per project"
for p in "$HOME"/*/; do [ -d "$p.claude/worktrees" ] && echo "$(du -sh "$p.claude/worktrees" 2>/dev/null | cut -f1) ${p#"$HOME"/}.claude/worktrees ($(ls "$p.claude/worktrees" | wc -l))"; done | sort -rh | head -8

h "Package managers"
if have pacman; then
  du -sh /var/cache/pacman/pkg 2>/dev/null
  echo "Orphans: $(pacman -Qdtq 2>/dev/null | wc -l)"; pacman -Qdtq 2>/dev/null | head -20 | tr '\n' ' '; echo
  have paccache && paccache -dk2 2>/dev/null | tail -1
  du -sh "$HOME/.cache/yay" "$HOME/.cache/paru" 2>/dev/null | short
  LC_ALL=C pacman -Qei 2>/dev/null | awk -F': ' '/^Name/{n=$2} /^Installed Size/{print $2" "n}' | awk '{v=$1; u=$2; if(u=="GiB")v*=1024; if(u=="KiB")v/=1024; if(u=="B")v/=1048576; printf "%8.0f MB  %s\n",v,$3}' | sort -rn | head -12
fi
if have apt-get; then du -sh /var/cache/apt 2>/dev/null; apt-get -s autoremove 2>/dev/null | grep -c '^Remv' | sed 's/^/apt autoremove would remove: /'; dpkg -l 'linux-image-*' 2>/dev/null | awk '/^ii/{print $2}' | tr '\n' ' '; echo "(running: $(uname -r))"; fi
if have dnf; then du -sh /var/cache/dnf /var/cache/libdnf5 2>/dev/null; fi
if have flatpak; then flatpak list --columns=name,size,application 2>/dev/null | head -20; fi
if have snap; then snap list --all 2>/dev/null | awk '/disabled/{print "old revision: "$1" "$3}'; fi
have brew && brew cleanup -n 2>/dev/null | tail -1

h "System"
have journalctl && journalctl --disk-usage 2>/dev/null
du -sh /var/lib/systemd/coredump 2>/dev/null
have coredumpctl && coredumpctl list --no-pager 2>/dev/null | tail -n +2 | wc -l | sed 's/^/Coredumps: /'
have docker && docker system df 2>/dev/null
have podman && podman system df 2>/dev/null
have snapper && snapper list 2>/dev/null | tail -8
have timeshift && echo "Timeshift present, check with: sudo timeshift --list"
[ "$(findmnt -no FSTYPE / 2>/dev/null)" = btrfs ] && echo "Btrfs: df and du disagree, check with: sudo btrfs filesystem usage /"
systemctl --failed --no-legend --no-pager 2>/dev/null | head -8
systemctl --user --failed --no-legend --no-pager 2>/dev/null | head -8

h "Autostart entries with no program"
for f in "$HOME/.config/autostart"/*.desktop "$HOME/.local/share/applications"/*.desktop; do [ -f "$f" ] || continue; e=$(sed -n 's/^Exec=//p' "$f" | head -1 | awk '{print $1}'); [ -n "$e" ] && ! command -v "$e" >/dev/null 2>&1 && [ ! -e "$e" ] && echo "$f -> missing: $e"; done | short | head -15

h "Old tooling"
ls "$HOME/.rustup/toolchains" 2>/dev/null | sed 's/^/rust: /'; ls "$HOME/.nvm/versions/node" 2>/dev/null | sed 's/^/nvm: /'; ls "$HOME/.pyenv/versions" 2>/dev/null | sed 's/^/pyenv: /'
du -sh "$HOME/.npm/_cacache" "$HOME/.npm/_npx" "$HOME/.gradle" "$HOME/.cargo/registry" "$HOME/.m2" "$HOME/Android" "$HOME/.android" "$HOME/.local/share/Steam" 2>/dev/null | sort -rh | short
exit 0
