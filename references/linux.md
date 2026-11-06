# Linux

For Arch-based systems, Debian/Ubuntu, Fedora and WSL.

```bash
bash ~/.claude/skills/deep-dig/scripts/linux-scan.sh
```

Without `sudo`, some sizes stay incomplete. The script never asks for it. If that isn't enough, say so and give the user the command.

## Where to look, and the official way to clean (only after approval)

| What | Check | Clean up |
|---|---|---|
| Pacman cache | `du -sh /var/cache/pacman/pkg` | `paccache -rk2`, not a blanket `pacman -Scc` |
| Pacman orphans | `pacman -Qdtq` | check each, then `pacman -Rns <package>` |
| AUR caches | `~/.cache/yay`, `~/.cache/paru` | the package subfolders |
| APT | `du -sh /var/cache/apt` | `apt clean`, `apt autoremove` (show the list first) |
| DNF | `dnf history` | `dnf clean packages`, `dnf autoremove` |
| Journal | `journalctl --disk-usage` | `journalctl --vacuum-time=14d` |
| Core dumps | `coredumpctl list` | `/var/lib/systemd/coredump` |
| Docker | `docker system df` | targeted. `system prune` only with approval, and **never** `--volumes` unasked |
| Flatpak | `flatpak list --app --columns=name,size` | `flatpak uninstall --unused` |
| Snap | `snap list --all` | old `disabled` revisions |
| Btrfs snapshots | `snapper list`, `timeshift --list` | through the tool only. They often take a lot of invisible space. |
| Old kernels | `dpkg -l 'linux-image*'` | package manager, never the running kernel |
| Trash | `~/.local/share/Trash` | the user empties it |

## Be careful

- **`~/.config` and `~/.local/share`** hold real settings and data, not just leftovers. Wallets, browser profiles and keys stay.
- **`~/.ssh`, `~/.gnupg` and password databases:** don't touch them or list their contents.
- **Btrfs and Docker:** `df` and `du` can disagree widely. On Btrfs, look at `btrfs filesystem usage /`.
- **Dotfile-managed distributions:** don't delete distribution config that updates expect.
- **Servers:** avoid `du` across everything, it loads the disk in production. Check services, databases and logs of running applications selectively.
