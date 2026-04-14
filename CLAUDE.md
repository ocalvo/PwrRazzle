# PwrRazzle

Sets up the Razzle build environment for Windows Apps (Xbox/TV/OS) development.

## Key Command

```powershell
Execute-Razzle [-arch x64|x86|arm|arm64] [-flavor fre|chk] [-enlistment <path>]
               [-vsYear 2022] [-vsVersion Enterprise] [-fast] [-Async]
```

- Probes the enlistment for the Razzle kind (DevDiv, Windows, Lifted, Phone) and runs the correct `razzle.ps1` / `init.cmd`.
- Persists last-used enlistment/arch/flavor in `$env:LOCALAPPDATA\dd.ini` so a plain `Execute-Razzle` re-opens the previous environment.
- `-fast` (default on): skips the full Razzle and restores the environment from a cached `.env.json` snapshot if one exists within the last 20 commits.
- `-Async`: starts Razzle in a background thread job and shows progress in a scroll region at the bottom of the terminal.

## Aliases / Globals Set After Razzle

| Name | Description |
|------|-------------|
| `UnRazzle` | `Execute-OutsideRazzle` — exit the Razzle environment |
| `$env:SDXROOT` / `$env:_XROOT` | Root of the enlistment |
| `$env:_BuildArch` / `$env:_BuildType` | Active architecture / flavor |

## Notes

- Requires Windows; not available on Linux/macOS.
- Uses `gsudo` for symbolic-link creation (auto-installed via `winget` if absent).
- `Check-GSudo` is called automatically when `-noSymbolicLinks` is not set.
