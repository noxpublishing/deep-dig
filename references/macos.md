# macOS

```bash
bash ~/.claude/skills/deep-dig/scripts/macos-scan.sh
bash ~/.claude/skills/deep-dig/scripts/macos-deep-scan.sh
```

To check processes, run `lsof -d cwd -Fn` once for everything. Never `lsof +D` per folder, which takes forever. Don't run `git status` under `~/Library/CloudStorage`, it can hang for minutes. `git ls-files` is enough.

## Never offer without being asked

- Active projects with their build folders and worktrees. Ask which ones are active.
- Caches those projects use right now, and local AI models that tests or tools rely on
- Session histories of coding agents
- Bare Git mirrors and backups: check for unique commits, loose objects and secrets first
- The photo library and Mail: the settings in those apps are the lever, never delete them
- `.npm/_npx` if MCP servers run from it. `.npm/_cacache` is safe.
- System-owned temp folders such as `com.apple.fileproviderd` and `SpeechModelCache`

## Things worth knowing

- **Old simulator runtimes:** remove them with `xcrun simctl runtime delete <id>`. Keep the newest iOS runtime and any runtime a device uses.
- **`/System/Library/AssetsV2` is protected by SIP.** Even `sudo rm` fails. Never disable SIP. Runtime originals stored there can bring a runtime back after a restart. On one Mac they disappeared on their own after repeated deletes, but that is an observation, not a guarantee.
- **APFS clones:** a Chrome `code_sign_clone` folder can show many GB and free almost nothing.
- **Swap:** a restart frees it and usually clears temp folders.
- **Many `node` processes above 2 GB:** usually Metro workers. Crash reports are in `/Library/Logs/DiagnosticReports`.
- **System extensions** are removed by the user: System Settings → General → Login Items & Extensions.
- **Homebrew casks** often leave large folders behind, so measure after uninstalling. `android-commandlinetools` left 11 GB in one case.

## Google Drive

In streaming mode, uploaded files drop to 0 bytes locally once macOS frees them. Check upload status with `fileproviderctl evaluate <path>` (`isUploaded = 1`).

**If nothing arrives online:**
- Errors: `~/Library/Application Support/Google/DriveFS/Logs/drive_fs.txt`, lines with `HandleFailedChange`. `UNSUPPORTED` comes from symlinks. Check the timeline to see whether errors are still being added.
- Queue: run `fileproviderctl dump com.google.drivefs.fpext` and count `delete:ready`. This can take 2 minutes.
- Backlog: look for folders with `node_modules`, `.venv` or `.next` in the synced folder.
- Don't back up a folder in Drive that iCloud already syncs. It causes timeouts.
- Files you edit in a backed-up local folder appear online under "Computers", not under "My Drive".
