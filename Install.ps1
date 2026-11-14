<#
.SYNOPSIS
    Installer script for v2rayN (portable, x64) on Windows.

.DESCRIPTION
    1. Queries the GitHub API for the latest 2dust/v2rayN release and downloads
       the v2rayN-windows-64.zip asset specifically (no hardcoded version).
    2. Verifies the archive's SHA-256 checksum against the digest published in
       the GitHub release metadata and aborts on mismatch.
    3. Extracts the archive using a built-in PowerShell cmdlet (Expand-Archive)
       into a temporary folder. If v2rayN is already installed, backs up the
       user configuration (guiConfigs) to v2rayN-backups\<timestamp> and then
       updates the application files, leaving the configuration untouched.
    4. Optionally accepts a path to a text file with config links
       (vmess://, vless://, ss://, trojan://, etc., one per line) and copies
       them to the clipboard — this is v2rayN's own bulk-import mechanism
       (Servers -> Import bulk URL from clipboard, or Ctrl+V in the main
       window). The script does not touch v2rayN's internal database files
       (guiNConfig.json/guiNDB.db) — their format is undocumented and editing
       them directly risks corrupting the profile.
    5. Creates a v2rayN.exe shortcut on the desktop.

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

# Verify SHA-256 against the digest published in the GitHub release metadata
Write-Step "Verifying SHA-256 checksum..."
if ($asset.digest -match '^sha256:([0-9a-fA-F]{64})$') {
    $expectedHash = $Matches[1].ToUpperInvariant()
    $actualHash   = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash

    if ($actualHash -ne $expectedHash) {
        Remove-Item -LiteralPath $zipPath -Force
        throw "SHA-256 mismatch for $($asset.name)! Expected: $expectedHash, got: $actualHash. The file was deleted."
    }
    Write-Host "Checksum OK: $actualHash" -ForegroundColor Green
}
else {
    Write-Warning "The release has no SHA-256 digest for $($asset.name); skipping verification."
}

# Extract into a temporary staging folder first, so a failed or partial
# extraction never touches an existing installation
$stagingDir = Join-Path $root 'v2rayN.staging'
if (Test-Path -LiteralPath $stagingDir) {
    Remove-Item -LiteralPath $stagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingDir | Out-Null

Write-Step "Extracting archive..."
if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
    # Built-in, available in PowerShell 5.0+ (Windows 10 and later out of the box)
    Expand-Archive -LiteralPath $zipPath -DestinationPath $stagingDir -Force
}
else {
    # Fallback for very old systems without Expand-Archive
    $shell = New-Object -ComObject Shell.Application
    $zip   = $shell.NameSpace($zipPath)
    $dest  = $shell.NameSpace($stagingDir)
    $dest.CopyHere($zip.Items(), 4 + 16) # 4 = no progress dialog, 16 = "yes to all"
    Start-Sleep -Seconds 2
}

Remove-Item -LiteralPath $zipPath -Force

# The release archive wraps everything in a single folder (v2rayN-windows-64) — use its contents
$sourceDir = $stagingDir
$topItems  = @(Get-ChildItem -LiteralPath $stagingDir)
if ($topItems.Count -eq 1 -and $topItems[0].PSIsContainer) {
    $sourceDir = $topItems[0].FullName
}
if (-not (Test-Path -LiteralPath (Join-Path $sourceDir 'v2rayN.exe') -PathType Leaf)) {
    throw "v2rayN.exe was not found in the downloaded archive. Check the contents of: $stagingDir"
}

# User data (settings, servers, subscriptions) lives in guiConfigs
$userDataDirName = 'guiConfigs'
$userDataDir     = Join-Path $installDir $userDataDirName
$backupDir       = $null

if (Test-Path -LiteralPath $installDir) {
    Write-Host "Existing installation found in $installDir — it will be updated." -ForegroundColor Yellow

    # Files of a running v2rayN are locked and cannot be replaced
    $running = Get-Process -Name 'v2rayN' -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -and $_.Path.StartsWith("$installDir\", [StringComparison]::OrdinalIgnoreCase) }
    if ($running) {
        Remove-Item -LiteralPath $stagingDir -Recurse -Force
        throw "v2rayN is running from $installDir. Close it (tray icon -> Exit) and run the script again."
    }

    if (Test-Path -LiteralPath $userDataDir) {
        Write-Step "Backing up user configuration..."
        $backupDir = Join-Path (Join-Path $root 'v2rayN-backups') (Get-Date -Format 'yyyyMMdd-HHmmss')
        New-Item -ItemType Directory -Path $backupDir | Out-Null
        Copy-Item -LiteralPath $userDataDir -Destination $backupDir -Recurse -Force
        Write-Host "Backup created: $backupDir"
    }
}
else {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}

# Copy the new application files over the installation. guiConfigs is never
# overwritten, even if a future release starts shipping a default one.
Write-Step "Installing files..."
try {
    Get-ChildItem -LiteralPath $sourceDir |
        Where-Object { -not ($backupDir -and $_.Name -eq $userDataDirName) } |
        Copy-Item -Destination $installDir -Recurse -Force
}
catch {
    Write-Host ""
    Write-Host "Update failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($backupDir) {
        Write-Host "Your configuration was backed up to: $backupDir" -ForegroundColor Yellow
        Write-Host "To restore it, copy the '$userDataDirName' folder from there into $installDir" -ForegroundColor Yellow
    }
    throw
}
finally {
    Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
}

$exePath = Join-Path $installDir 'v2rayN.exe'
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