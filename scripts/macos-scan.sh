#!/bin/bash
# Disk inventory for macOS. Read-only: changes nothing, downloads nothing.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
h() { printf '\n=== %s ===\n' "$1"; }
top() { sort -rh | head -"$1" | sed "s|$HOME|~|"; }
DRIVE=""
for d in "$HOME/Library/CloudStorage"/GoogleDrive-*/; do [ -d "$d" ] || continue; for m in "My Drive" "Meine Ablage"; do [ -d "$d$m" ] && DRIVE="$d$m"; done; done

h "Disk and memory"
df -h / | tail -1 | awk '{print $4" free of "$2}'
sysctl vm.swapusage | cut -c1-70
date -r "$(sysctl -n kern.boottime | sed -E 's/.*sec = ([0-9]+),.*/\1/')" '+last boot: %F %R'
diskutil apfs list 2>/dev/null | grep -E "Name:|Capacity Consumed" | head -10 | sed -E 's/^[| ]+//'
echo "Claude processes: $(ps -axo comm= | grep -c 'MacOS/claude$'), node: $(ps -axo comm= | grep -c '/node$\|^node$')"

h "Home (top 28)"
du -x -h -d 1 "$HOME" 2>/dev/null | top 28

h "Library"
du -x -h -d 1 "$HOME/Library" 2>/dev/null | top 10
du -sh "$HOME/Library/Application Support"/*/ 2>/dev/null | top 10
du -sh "$HOME/Library/Application Support/Claude"/*/ 2>/dev/null | top 4

h "Caches"
du -sh "$HOME/Library/Caches"/*/ 2>/dev/null | top 14
du -sh "$HOME/.cache"/*/ 2>/dev/null | top 8
du -sh "$HOME/.npm/_cacache" "$HOME/.npm/_npx" 2>/dev/null | sed "s|$HOME|~|"
brew cleanup -n 2>/dev/null | tail -1

h "Xcode and simulators"
xcrun simctl runtime list 2>&1 | grep -E '\(|Total'
du -sh /Library/Developer/CoreSimulator/Volumes/* /Library/Developer/CoreSimulator/Caches/dyld/*/* 2>/dev/null | sed 's|/Library/Developer/CoreSimulator/||' | top 8
du -sh /System/Library/AssetsV2/com_apple_MobileAsset_*SimulatorRuntime/*.asset 2>/dev/null | sed 's|/System/Library/AssetsV2/com_apple_MobileAsset_||' | top 6
du -sh "$HOME/Library/Developer/Xcode/DerivedData"/*/ "$HOME/Library/Developer/Xcode/iOS DeviceSupport" 2>/dev/null | top 6
xcrun simctl list devices -j 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; [print(x['udid'], x['name']) for v in d.values() for x in v]" | while read -r u n; do echo "$(du -sh "$HOME/Library/Developer/CoreSimulator/Devices/$u" 2>/dev/null | cut -f1) $n"; done | sort -rh

h "Worktrees per project"
for p in "$HOME"/*/; do [ -d "$p.claude/worktrees" ] && echo "$(du -sh "$p.claude/worktrees" 2>/dev/null | cut -f1) ${p#"$HOME"/}.claude/worktrees ($(ls "$p.claude/worktrees" | wc -l | tr -d ' '))"; done | sort -rh | head -8
du -sh "$HOME/.codex/worktrees" 2>/dev/null | sed "s|$HOME|~|"

h "Downloads and Trash"
du -sh "$HOME/Downloads" "$HOME/.Trash" 2>/dev/null | sed "s|$HOME|~|"
du -sh "$HOME/Downloads"/* 2>/dev/null | top 8
find "$HOME/Downloads" -maxdepth 1 -iname '*.dmg' -print0 2>/dev/null | xargs -0 du -ch 2>/dev/null | tail -1 | sed 's/total/.dmg total/'

h "Temp"
T=$(getconf DARWIN_USER_TEMP_DIR); du -sh "$T" "/private/tmp/claude-$(id -u)" 2>/dev/null
du -sh "$T"* 2>/dev/null | sort -rh | head -6 | sed "s|$T||"
du -sh "/private/tmp/claude-$(id -u)"/*/* 2>/dev/null | sort -rh | head -4 | cut -c1-110

h "Google Drive"
if pgrep -x "Google Drive" >/dev/null; then echo "Drive is running"; else echo "Drive is not running"; fi
[ -n "$DRIVE" ] && ls -1A "$DRIVE" | grep -v '^\.' | while IFS= read -r n; do fileproviderctl evaluate "$DRIVE/$n" 2>/dev/null | grep -q 'isUploading = 1' && echo "still uploading: $n"; done
LOG="$HOME/Library/Application Support/Google/DriveFS/Logs/drive_fs.txt"
[ -f "$LOG" ] && { echo "Errors in current log: $(grep -cE 'E \[.*HandleFailedChange' "$LOG"), latest: $(grep -E 'E \[.*HandleFailedChange' "$LOG" | tail -1 | cut -c1-19) UTC"; }
exit 0
