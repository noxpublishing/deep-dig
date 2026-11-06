#!/bin/bash
# Deep scan: hidden data, leftovers of old apps, forgotten files.
# Read-only. Results are candidates, not verdicts: check each one before calling it junk.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
h() { printf '\n=== %s ===\n' "$1"; }
short() { sed "s|$HOME|~|"; }
LIB="$HOME/Library"
TMP=$(mktemp -d)
EXCL=(-path "$LIB/CloudStorage" -o -path "$LIB/Mobile Documents" -o -path "$HOME/Pictures/Photos Library.photoslibrary" -o -path "$LIB/Mail" -o -name .Trash)

# Installed apps and their bundle IDs
{ find /Applications "$HOME/Applications" -maxdepth 3 -name '*.app' -prune 2>/dev/null; mdfind "kMDItemContentType == 'com.apple.application-bundle'" 2>/dev/null | grep -vE '^/System|/Contents/|^/Volumes'; } | sort -u > "$TMP/apps"
while IFS= read -r a; do /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$a/Contents/Info.plist" 2>/dev/null; basename "$a" .app; done < "$TMP/apps" | tr 'A-Z' 'a-z' | sort -u > "$TMP/known"
ps -axo comm= | tr 'A-Z' 'a-z' > "$TMP/ps"
installed() { # match a data folder name or bundle ID against apps and processes
  n=$(printf '%s' "$1" | tr 'A-Z' 'a-z'); core=$(printf '%s' "$n" | sed -E 's/^[a-z0-9]{10}\.//; s/^group\.//; s/^(com|net|org|io|ai|app|co|de)\.[^.]+\.//; s/\.(helper|shared|desktop|client|app).*$//')
  grep -qF -- "$n" "$TMP/known" || grep -qF -- "$core" "$TMP/known" || grep -qF -- "/$core" "$TMP/ps"
}

h "1. Data with no recognizable app (20 MB and up, Apple excluded)"
for base in "$LIB/Application Support" "$LIB/Containers" "$LIB/Group Containers" "$LIB/Saved Application State" "$LIB/HTTPStorages" "$LIB/WebKit" "/Library/Application Support"; do
  [ -d "$base" ] || continue
  for d in "$base"/*/; do d=${d%/}; n=$(basename "$d"); case "$n" in com.apple*|group.com.apple*|*.com.apple*|Apple|CloudDocs|FileProvider|CrashReporter|Knowledge|AddressBook|Google|Caches|'*') continue;; esac
    installed "$n" && continue; k=$(du -sk "$d" 2>/dev/null | cut -f1); [ "${k:-0}" -ge 20480 ] && printf '%s\t%s\t%s\n' "$k" "$(stat -f %Sm -t %Y-%m "$d")" "$d"
  done
done | sort -rn | head -45 | awk -F'\t' '{printf "%7.0f MB  last used %s  %s\n",$1/1024,$2,$3}' | short

h "2. Hidden folders in ~ (size, last changed)"
for d in "$HOME"/.[!.]*; do [ -d "$d" ] || continue; case "$(basename "$d")" in .Trash|.ssh|.gnupg) continue;; esac; k=$(du -sk "$d" 2>/dev/null | cut -f1); [ "${k:-0}" -ge 51200 ] && printf '%s\t%s\t%s\n' "$k" "$(find "$d" -maxdepth 2 -type f -exec stat -f %m {} + 2>/dev/null | sort -rn | head -1 | xargs -I{} date -r {} +%Y-%m-%d)" "$d"; done | sort -rn | awk -F'\t' '{printf "%7.0f MB  last used %s  %s\n",$1/1024,$2,$3}' | short

h "3. Single files of 300 MB and up (except photo library, mail, cloud, node_modules)"
find "$HOME" -xdev \( "${EXCL[@]}" -o -name node_modules -o -name .git -o -name target -o -name DerivedData -o -path "$LIB/Developer/CoreSimulator" \) -prune -o -type f -size +300M -print0 2>/dev/null | xargs -0 ls -lT 2>/dev/null | awk '{sz=$5/1048576; m=$6" "$7" "$9; $1=$2=$3=$4=$5=$6=$7=$8=$9=""; sub(/^ +/,""); printf "%7.0f MB  %s  %s\n",sz,m,$0}' | sort -rn | head -30 | short

h "4. Old installers, images and archives (20 MB and up)"
find "$HOME" -xdev \( "${EXCL[@]}" -o -name node_modules -o -name .git -o -path "$LIB" \) -prune -o -type f \( -iname '*.dmg' -o -iname '*.pkg' -o -iname '*.iso' -o -iname '*.xip' -o -iname '*.nsp' -o -iname '*.exe' -o -iname '*.msi' -o -iname '*.ipa' -o -iname '*.apk' \) -size +20M -print0 2>/dev/null | xargs -0 du -h 2>/dev/null | sort -rh | head -20 | short
ls -d /Applications/Install\ macOS*.app 2>/dev/null

h "5. Zip next to its unpacked folder (20 MB and up)"
for r in "$HOME/Downloads" "$HOME/Desktop"; do for z in "$r"/*.zip; do [ -f "$z" ] && [ -d "${z%.zip}" ] && k=$(du -sk "$z" | cut -f1) && [ "$k" -ge 20480 ] && echo "$((k/1024)) MB  $z"; done; done | sort -rn | head -15 | short

h "6. Build folders in projects idle for 60 days"
find "$HOME" -xdev -maxdepth 5 \( "${EXCL[@]}" -o -path "$LIB" -o -name .git \) -prune -o -type d \( -name node_modules -o -name target -o -name .next -o -name Pods -o -name .venv -o -name venv -o -name __pycache__ -o -name .gradle \) -prune -print 2>/dev/null | grep -vE '/\.(claude|codex|cache|npm|local)/' > "$TMP/build"
while IFS= read -r b; do p=$(dirname "$b"); t=$(git -C "$p" log -1 --format=%ct 2>/dev/null); [ -z "$t" ] && t=$(stat -f %m "$p"); [ $(( ($(date +%s)-t)/86400 )) -ge 60 ] || continue; k=$(du -sk "$b" 2>/dev/null | cut -f1); [ "${k:-0}" -ge 20480 ] && printf '%s\t%s\t%s\n' "$k" "$(date -r "$t" +%Y-%m-%d)" "$b"; done < "$TMP/build" | sort -rn | head -25 | awk -F'\t' '{printf "%7.0f MB  project last active %s  %s\n",$1/1024,$2,$3}' | short

h "7. Largest apps and last known use"
echo "A missing date means use is unknown, not that the app is unused."
find /Applications -maxdepth 2 -name '*.app' -prune 2>/dev/null | while IFS= read -r a; do u=$(mdls -raw -name kMDItemLastUsedDate "$a" 2>/dev/null | cut -c1-10); case "$u" in '(null)'|'') u=unknown;; esac; printf '%s\t%s\t%s\n' "$(du -sk "$a" 2>/dev/null | cut -f1)" "$u" "$a"; done | sort -rn | head -20 | awk -F'\t' '{printf "%7.0f MB  last used %s  %s\n",$1/1024,$2,$3}'

h "8. Background services and extensions whose program is missing"
for f in "$LIB/LaunchAgents"/*.plist /Library/LaunchAgents/*.plist /Library/LaunchDaemons/*.plist; do [ -f "$f" ] || continue; p=$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$f" 2>/dev/null || /usr/libexec/PlistBuddy -c 'Print :Program' "$f" 2>/dev/null); [ -n "$p" ] && [ "${p#/}" != "$p" ] && [ ! -e "$p" ] && echo "$f -> missing: $p"; done | short
systemextensionsctl list 2>/dev/null | grep -E 'activated|terminated' | cut -c1-120 | sed -E 's/^[* ]+//' | head -12

h "9. Known hiding places"
for d in "$LIB/Application Support/MobileSync/Backup" "$LIB/Containers/com.apple.mail/Data/Library/Mail Downloads" "$LIB/Application Support/Adobe/Common" "$LIB/Developer/Xcode/Archives" "$LIB/Developer/Xcode/iOS DeviceSupport" "$LIB/Developer/Xcode/watchOS DeviceSupport" "$LIB/Developer/CoreSimulator/Caches" "$LIB/Containers/com.apple.CoreDevice.CoreDeviceService/Data/Library/Caches" "$LIB/Group Containers/group.net.whatsapp.WhatsApp.shared/Message/Media" "$LIB/Metadata/CoreSpotlight" "$HOME/.Trash" "/Users/Shared" "/Library/Caches" "/Library/Logs" "/private/var/log" "/private/var/tmp" "/private/tmp"; do [ -e "$d" ] && du -sh "$d" 2>/dev/null; done | sort -rh | short
xcrun simctl list devices unavailable 2>/dev/null | grep -c unavailable | sed 's/^/unavailable simulators: /'
tmutil listlocalsnapshots / 2>/dev/null | grep -c com.apple | sed 's/^/local Time Machine snapshots: /'

h "10. Old tooling"
brew autoremove -n 2>/dev/null | tail -8 | cut -c1-100
brew cleanup -n 2>/dev/null | tail -1
ls "$HOME/.rustup/toolchains" 2>/dev/null | sed 's/^/rust: /'; ls "$HOME/.nvm/versions/node" 2>/dev/null | sed 's/^/nvm: /'; ls "$HOME/.pyenv/versions" 2>/dev/null | sed 's/^/pyenv: /'
ls /opt/homebrew/Cellar 2>/dev/null | grep -E '^(python@|node@|openjdk@|postgresql@)' | while read -r v; do echo "$v used by: $(brew uses --installed "$v" 2>/dev/null | wc -l | tr -d ' ') packages"; done
du -sh /opt/homebrew/share/* /opt/homebrew/lib/node_modules 2>/dev/null | grep -v '^ *0B' | sort -rh | head -5

rm -rf "$TMP"
exit 0
