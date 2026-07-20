<#
.SYNOPSIS
    Скрипт установки v2rayN (portable, x64) для Windows.

.DESCRIPTION
    1. Запрашивает GitHub API для получения последнего релиза 2dust/v2rayN и
       загружает именно архив v2rayN-windows-64.zip (без жёстко заданной версии).
    2. Распаковывает архив встроенным командлетом PowerShell (Expand-Archive).
    3. Опционально принимает путь к текстовому файлу со ссылками конфигураций
       (vmess://, vless://, ss://, trojan:// и т.д., по одной на строку) и
       копирует их в буфер обмена — это собственный механизм массового импорта
       v2rayN (Серверы -> Импорт из буфера обмена (Import bulk URL from
       clipboard), либо Ctrl+V в главном окне). Скрипт не трогает внутренние
       файлы базы данных v2rayN (guiNConfig.json/guiNDB.db) — их формат не
       документирован, и прямое редактирование рискует повредить профиль.
    4. Создаёт ярлык v2rayN.exe на рабочем столе.

    Папка v2rayN создаётся рядом со скриптом ($PSScriptRoot), а не в текущей
    директории терминала — это делает поведение предсказуемым независимо от
    того, откуда скрипт был запущен.

.PARAMETER ConfigFile
    Путь к текстовому файлу со ссылками конфигураций (по одной на строку).

.EXAMPLE
    .\Install-V2rayN.ps1

.EXAMPLE
    .\Install-V2rayN.ps1 -ConfigFile "C:\configs\servers.txt"

.NOTES
    Возможно, потребуется разрешить выполнение скриптов:
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

# --- Проверяем ConfigFile заранее, чтобы не тратить время на загрузку из-за опечатки ---
if ($ConfigFile) {
    if (-not (Test-Path -LiteralPath $ConfigFile -PathType Leaf)) {
        throw "Файл конфигурации не найден: $ConfigFile"
    }
}

# --- Целевая папка — рядом со скриптом ---
$root = $PSScriptRoot
if ([string]::IsNullOrEmpty($root)) { $root = (Get-Location).Path }

$installDir = Join-Path $root 'v2rayN'
$zipPath    = Join-Path $root 'v2rayN-windows-64.zip'

Write-Host "Папка установки: $installDir"

# --- Находим последний релиз через GitHub API ---
Write-Step "Получаем информацию о последнем релизе v2rayN..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$apiUrl  = 'https://api.github.com/repos/2dust/v2rayN/releases/latest'
$headers = @{ 'User-Agent' = 'v2rayN-install-script' }

try {
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers
}
catch {
    throw "Не удалось получить информацию о релизе с GitHub API: $($_.Exception.Message)"
}

$asset = $release.assets | Where-Object { $_.name -eq 'v2rayN-windows-64.zip' } | Select-Object -First 1
if (-not $asset) {
    throw "Не удалось найти v2rayN-windows-64.zip в релизе $($release.tag_name)"
}

$downloadUrl = $asset.browser_download_url
Write-Host "Версия: $($release.tag_name)"
Write-Host "URL: $downloadUrl"

# --- Загрузка ---
Write-Step "Загружаем архив..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing

# --- Извлечение встроенными средствами Windows ---
if (-not (Test-Path -LiteralPath $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}
else {
    Write-Host "Папка $installDir уже существует — её содержимое будет обновлено." -ForegroundColor Yellow
}

Write-Step "Распаковываем архив..."
if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
    # Встроенный командлет, доступен в PowerShell 5.0+ (Windows 10 и новее из коробки)
    Expand-Archive -LiteralPath $zipPath -DestinationPath $installDir -Force
}
else {
    # Резервный вариант для очень старых систем без Expand-Archive
    $shell = New-Object -ComObject Shell.Application
    $zip   = $shell.NameSpace($zipPath)
    $dest  = $shell.NameSpace($installDir)
    $dest.CopyHere($zip.Items(), 4 + 16) # 4 = без диалога прогресса, 16 = "да для всех"
    Start-Sleep -Seconds 2
}

Remove-Item -LiteralPath $zipPath -Force

# Если архив содержит одну вложенную папку — разворачиваем её содержимое наружу
$topItems = Get-ChildItem -LiteralPath $installDir
if ($topItems.Count -eq 1 -and $topItems[0].PSIsContainer) {
    $nested = $topItems[0].FullName
    Get-ChildItem -LiteralPath $nested | Move-Item -Destination $installDir -Force
    Remove-Item -LiteralPath $nested -Force -Recurse
}

# --- Поиск исполняемого файла ---
$exePath = Get-ChildItem -LiteralPath $installDir -Filter 'v2rayN.exe' -Recurse |
    Select-Object -First 1 -ExpandProperty FullName

if (-not $exePath) {
    throw "v2rayN.exe не найден после распаковки. Проверьте содержимое папки: $installDir"
}
Write-Host "v2rayN установлен в: $exePath"

# --- Ярлык на рабочем столе ---
Write-Step "Создаём ярлык на рабочем столе..."
$desktop      = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'v2rayN.lnk'

$wshShell = New-Object -ComObject WScript.Shell
$shortcut = $wshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath       = $exePath
$shortcut.WorkingDirectory = Split-Path -Path $exePath -Parent
$shortcut.IconLocation     = $exePath
$shortcut.Description      = 'v2rayN'
$shortcut.Save()

Write-Host "Ярлык создан: $shortcutPath"

# --- Опциональный импорт конфигураций через буфер обмена ---
if ($ConfigFile) {
    Write-Step "Копируем конфигурации в буфер обмена..."
    $content = Get-Content -LiteralPath $ConfigFile -Raw
    Set-Clipboard -Value $content

    Write-Step "Запускаем v2rayN..."
    Start-Process -FilePath $exePath -WorkingDirectory (Split-Path -Path $exePath -Parent)
    Start-Sleep -Seconds 2

    Write-Host ""
    Write-Host "Готово. Конфигурации из '$ConfigFile' скопированы в буфер обмена и вставлены в окно v2rayN." -ForegroundColor Green
    Write-Host "Если этого не произошло, в главном окне v2rayN нажмите Ctrl+V (или Configuration -> Import Share Links from clipboard)" -ForegroundColor Green
    Write-Host "чтобы добавить серверы." -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "Установка завершена. Запустите v2rayN через ярлык на рабочем столе." -ForegroundColor Green
}