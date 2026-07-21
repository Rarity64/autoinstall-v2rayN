<#
.SYNOPSIS
    Installer script for v2rayN (portable, x64) on Windows.

.DESCRIPTION
    1. Queries the GitHub API for the latest 2dust/v2rayN release and downloads
       the v2rayN-windows-64.zip asset specifically (no hardcoded version).
    2. Extracts the archive using a built-in PowerShell cmdlet (Expand-Archive).
    3. Optionally accepts a path to a text file with config links
       (vmess://, vless://, ss://, trojan://, etc., one per line) and copies
       them to the clipboard — this is v2rayN's own bulk-import mechanism
       (Servers -> Import bulk URL from clipboard, or Ctrl+V in the main
       window). The script does not touch v2rayN's internal database files
       (guiNConfig.json/guiNDB.db) — their format is undocumented and editing
       them directly risks corrupting the profile.
    4. Creates a v2rayN.exe shortcut on the desktop.

    The v2rayN folder is created next to the script ($PSScriptRoot), not in
    the terminal's current directory — this keeps behavior predictable
    regardless of where the script is called from.

.PARAMETER ConfigFile
    Path to a text file containing config links (one per line).

.EXAMPLE
    .\Install-V2rayN.ps1

.EXAMPLE
    .\Install-V2rayN.ps1 -ConfigFile "C:\configs\servers.txt"

.NOTES
    You may need to allow script execution first:
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

# Validate ConfigFile early so we don't waste time downloading on a typo
if ($ConfigFile) {
    if (-not (Test-Path -LiteralPath $ConfigFile -PathType Leaf)) {
        throw "Config file not found: $ConfigFile"
    }
}

# Target folder — next to the script
$root = $PSScriptRoot
if ([string]::IsNullOrEmpty($root)) { $root = (Get-Location).Path }

$installDir = Join-Path $root 'v2rayN'
$zipPath    = Join-Path $root 'v2rayN-windows-64.zip'

Write-Host "Install directory: $installDir"

# Find the latest release via GitHub API
Write-Step "Fetching latest v2rayN release info..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$apiUrl  = 'https://api.github.com/repos/2dust/v2rayN/releases/latest'
$headers = @{ 'User-Agent' = 'v2rayN-install-script' }

try {
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers
}
catch {
    throw "Failed to fetch release info from GitHub API: $($_.Exception.Message)"
}

$asset = $release.assets | Where-Object { $_.name -eq 'v2rayN-windows-64.zip' } | Select-Object -First 1
if (-not $asset) {
    throw "Could not find v2rayN-windows-64.zip in release $($release.tag_name)"
}

$downloadUrl = $asset.browser_download_url
Write-Host "Version: $($release.tag_name)"
Write-Host "URL: $downloadUrl"

# Download
Write-Step "Downloading archive..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing

# Extract using built-in Windows tooling
if (-not (Test-Path -LiteralPath $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}
else {
    Write-Host "Folder $installDir already exists — its contents will be updated." -ForegroundColor Yellow
}

Write-Step "Extracting archive..."
if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
    # Built-in, available in PowerShell 5.0+ (Windows 10 and later out of the box)
    Expand-Archive -LiteralPath $zipPath -DestinationPath $installDir -Force
}
else {
    # Fallback for very old systems without Expand-Archive
    $shell = New-Object -ComObject Shell.Application
    $zip   = $shell.NameSpace($zipPath)
    $dest  = $shell.NameSpace($installDir)
    $dest.CopyHere($zip.Items(), 4 + 16) # 4 = no progress dialog, 16 = "yes to all"
    Start-Sleep -Seconds 2
}

Remove-Item -LiteralPath $zipPath -Force

# In case the archive contains a single nested folder, flatten it
$topItems = Get-ChildItem -LiteralPath $installDir
if ($topItems.Count -eq 1 -and $topItems[0].PSIsContainer) {
    $nested = $topItems[0].FullName
    Get-ChildItem -LiteralPath $nested | Move-Item -Destination $installDir -Force
    Remove-Item -LiteralPath $nested -Force -Recurse
}

# Locate the executable
$exePath = Get-ChildItem -LiteralPath $installDir -Filter 'v2rayN.exe' -Recurse |
    Select-Object -First 1 -ExpandProperty FullName

if (-not $exePath) {
    throw "v2rayN.exe was not found after extraction. Check the contents of: $installDir"
}
Write-Host "v2rayN installed at: $exePath"

# Desktop shortcut
Write-Step "Creating desktop shortcut..."
$desktop      = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'v2rayN.lnk'

$wshShell = New-Object -ComObject WScript.Shell
$shortcut = $wshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath       = $exePath
$shortcut.WorkingDirectory = Split-Path -Path $exePath -Parent
$shortcut.IconLocation     = $exePath
$shortcut.Description      = 'v2rayN'
$shortcut.Save()

Write-Host "Shortcut created: $shortcutPath"

# Optional config import via clipboard
if ($ConfigFile) {
    Write-Step "Copying configs to clipboard..."
    $content = Get-Content -LiteralPath $ConfigFile -Raw
    Set-Clipboard -Value $content

    Write-Step "Launching v2rayN..."
    Start-Process -FilePath $exePath -WorkingDirectory (Split-Path -Path $exePath -Parent)
    Start-Sleep -Seconds 2

    Write-Host ""
    Write-Host "Done. Configs from '$ConfigFile' were copied to the clipboard and pasted into the v2rayN window." -ForegroundColor Green
    Write-Host "Otherwise, in the main v2rayN window, press Ctrl+V (or Configuration -> Import Share Links from clipboard)" -ForegroundColor Green
    Write-Host "to add the servers." -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "Installation complete. Launch v2rayN via the desktop shortcut." -ForegroundColor Green
}