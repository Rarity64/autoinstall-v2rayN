# v2rayN Installer Script

A PowerShell script that downloads and sets up the latest portable release of
[v2rayN](https://github.com/2dust/v2rayN) (Windows x64) with no manual steps.

## What it does

1. Queries the GitHub API for the **latest** v2rayN release and downloads
   `v2rayN-windows-64.zip` — the version number is never hardcoded.
2. Extracts the archive with the built-in `Expand-Archive` cmdlet (no extra
   tools required).
3. Installs into a `v2rayN` folder created **next to the script**.
4. Creates a `v2rayN.lnk` shortcut on the Desktop.
5. Optionally imports a list of server configs via the clipboard.

## Requirements

- Windows 10/11, 64-bit
- PowerShell 5.0+ (included by default)

## Usage

### Allow script execution (one-time)

By default, Windows blocks running local `.ps1` files. Open PowerShell and run:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

This allows locally created scripts to run while still requiring signed
scripts from remote sources. If you'd rather not change the policy globally,
you can bypass it for a single run instead:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-V2rayN.ps1
```

### Basic install

```powershell
.\Install-V2rayN.ps1
```

This downloads the latest release, extracts it into a `v2rayN` folder next
to the script, and creates a desktop shortcut.

### Install with server configs

```powershell
.\Install-V2rayN.ps1 -ConfigFile "C:\configs\servers.txt"
```

`servers.txt` should contain one config link per line, e.g.:

```
vmess://...
vless://...
trojan://...
```

The script copies the file's contents to the clipboard and launches v2rayN.
In the main v2rayN window, press **Ctrl+V** (or go to **Servers → Import
bulk URL from clipboard**) to add the servers — this is v2rayN's own
built-in import feature, so no internal files are modified directly.

## Notes

- Re-running the script updates the existing `v2rayN` folder in place.
- If Windows SmartScreen flags the downloaded executable, that's expected
  for unsigned third-party builds — this is a property of the upstream
  release, not of this script.