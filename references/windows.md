# Windows

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\deep-dig\scripts\windows-scan.ps1"
```

The script runs without admin rights and only reads. Some system sizes will be missing or too small, and the output says so.

## Where to look, and the official way to clean (only after approval)

| What | Check | Clean up |
|---|---|---|
| Old Windows install | `C:\Windows.old` | Settings → System → Storage → Temporary files |
| Update leftovers | `C:\Windows\SoftwareDistribution\Download` | the same setting, or Disk Cleanup |
| WinSxS | as admin: `Dism /Online /Cleanup-Image /AnalyzeComponentStore` | only `Dism /Online /Cleanup-Image /StartComponentCleanup`, **never by hand** |
| User temp | `%LOCALAPPDATA%\Temp` | older files, locked ones stay |
| Crash dumps | `%LOCALAPPDATA%\CrashDumps`, `C:\Windows\Minidump`, `C:\Windows\MEMORY.DMP` | one by one after approval |
| Restore points | as admin: `vssadmin list shadowstorage` | through Control Panel, not `vssadmin delete` unasked |
| Hibernation | `C:\hiberfil.sys` | as admin `powercfg /h off`. This also turns off Fast Startup, so say that first. |
| WSL | `ext4.vhdx` under `%LOCALAPPDATA%\Packages` | only grows on its own. Clean inside WSL first, then compact it. |
| Docker | `docker system df`, `docker_data.vhdx` | targeted, never `--volumes` unasked |
| Developer caches | npm, pip, NuGet, Gradle, Cargo | official commands such as `npm cache clean --force` |
| Recycle Bin | `$Recycle.Bin` | the user empties it |

Remove programs through Settings → Apps or their own uninstaller, not by deleting the folder.

## Never touch

- `C:\Windows\Installer`, `C:\Windows\WinSxS`, `System32`, `pagefile.sys`, `swapfile.sys`: deleting these damages the system
- The registry: "cleaning" it frees no meaningful space
- `%APPDATA%` folders of installed programs: settings, data and often licenses
- Cloud folders (OneDrive, Google Drive): deleting there usually deletes online too. "Free up space" frees local space.
- Files deleted with `del` or `Remove-Item` skip the Recycle Bin. Say that before asking for approval.
