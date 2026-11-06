---
name: deep-dig
description: Deep search for junk data and guided cleanup on macOS, Linux and Windows, plus help with full disks, opaque "System Data", leftovers of old apps and stuck cloud sync. Use for "deep dig", "clean my mess", "junk", "cleanup", "deep clean", "hidden data", "old apps", "what can I delete", "disk full", "free up space", "system data", "what is eating my disk", "move to Drive", "Drive won't upload", or when a computer crashes from low disk space or memory. Searches and lists first, and never deletes anything without explicit approval.
---

# Deep Dig

> **TOP RULE: Never delete anything without the user's explicit approval.** This covers every file, cache and package, even when the disk is almost full. In an emergency, report it, name the options and wait for an answer. Approval covers only the things it names, and only this round. Until then, run read-only commands only.

Answer in the user's language. Prefer short tables to long prose. The order is always: **detect the system → dig deep → list → the user decides → delete exactly that → measure again → report honestly.**

## 1. Detect the system, read the matching guide

| System | Detect | Read | Scripts in `scripts/` (read-only) |
|---|---|---|---|
| macOS | `uname` is `Darwin` | `references/macos.md` | `macos-scan.sh`, then `macos-deep-scan.sh` |
| Linux | `uname` is `Linux` | `references/linux.md` | `linux-scan.sh` |
| Windows | PowerShell, `$env:OS` is `Windows_NT` | `references/windows.md` | `windows-scan.ps1` |

WSL counts as Linux. Check its Windows side separately.

Also read the user's own notes if they exist: project rules, memory, earlier cleanup documents. They say what is in active use. Ask which projects are active if you can't tell.

## 2. Dig deep (read-only)

The scripts take minutes, so run them in the background and wait for the result. On Windows: `powershell -ExecutionPolicy Bypass -File <path>\windows-scan.ps1`. That applies to this one run and changes no setting.

**Then keep digging yourself.** The scripts return candidates, not verdicts. For every large or unexplained item, look one level deeper until you know what it is. This regularly finds the most:
- Tools in unexpected places, such as SDKs inside package manager folders
- Copies and migration leftovers of nearly identical size
- Temp folders of old sessions and build output in scratch folders
- Leftovers of uninstalled apps
- Whatever has grown a lot since the last measurement

**Verify each candidate before calling it junk:**
- **A worktree is safe only if** it has no commits beyond the main branch, no uncommitted changes, at least 2 quiet days and no process inside it.
- **A local project folder may go only if** a verified copy exists. An old cloud copy can be incomplete, so compare them.
- **A missing app proves nothing.** The scripts match rough names and can be wrong. Check each one against installed apps and running processes.
- **Not everything called a cache is one.** Session histories, models, databases and browser profiles with bookmarks and passwords are real data.
- **Explain catch-all categories.** "System Data" is a bookkeeping label, not lost space. Compare used space against folders you can attribute.

## 3. Show the list

Tables, in this order:
1. 🟢 **Safe:** rebuilds itself and gets in no project's way
2. 🟠 **Has consequences:** name each one, such as "the next build takes longer"
3. 🔴 **Stays:** with the reason

Then ask. In Claude Code, use `AskUserQuestion` with multiple selection. If no answer comes, it is unclear, or a message doesn't arrive: delete nothing and ask again.

## 4. Delete, only after approval

- **Only what was approved.** "Leave the rest" means exactly that. Don't include anything similar. A deleted item coming back is not a new approval.
- **Show the size first, measure free space afterwards.** Don't report an estimate as the result. Clones and hard links often show more size than they free.
- **Write out target paths.** No variables in delete commands. Never work around safety checks.
- **The user empties trash folders**, local and in the cloud. Don't do the final deletion for them.
- **Prefer official routes:** `git worktree remove`, uninstallers and package managers instead of deleting folders by hand. Never disable system protection.
- **Never print secrets**, only names and counts. Never put them unencrypted in the cloud.
- Never stop other sessions or processes. Name them instead.

## 5. Moving things to the cloud

1. Compare with any existing cloud copy, using metadata only, without downloading.
2. Check for uncommitted changes, unpushed commits and running processes.
3. Find secret files and keep them in a private local place, not in the cloud.
4. Create one zip without `node_modules`, `.venv` and build folders. Save package versions first if there is no lockfile.
5. Unpack a test copy and compare checksums against the original.
6. Wait until the sync client confirms the upload. Only then delete locally.
7. Write down the new location where the user would look for it.

Warn before deleting or unpacking tens of thousands of files in a sync folder. That can block the queue for hours, and new uploads wait behind it.

## Finish

- Report honestly: what was deleted, what it really freed, what is still open. Correct your own mistakes and wrong assumptions out loud.
- Document changed storage locations. Cache deletions don't need it.
- Stop your own background processes. Don't start wait loops that will hit a timeout.
