<#
.SYNOPSIS
Khởi chạy giao diện IDA Pro portable (có plugin MCP). Ưu tiên cách này khi license idalib chạy không giao diện bị lỗi.

.DESCRIPTION
1. Xác định IDADIR.
2. Tùy chọn mở đường dẫn file nhị phân.
3. Khởi chạy giao diện IDA để plugin ida_mcp tự mở HTTP tại 127.0.0.1:13337.

Cách dùng:
  powershell -File start-gui.ps1
  powershell -File start-gui.ps1 -Path C:\target.exe
#>

param(
    [string]$Path,
    [string]$IdaDir,
    [switch]$UsePortableLauncher
)

$ErrorActionPreference = 'Stop'

function Test-IdaInstallDir {
    param([string]$Candidate)
    if ([string]::IsNullOrWhiteSpace($Candidate)) { return $false }
    if (-not (Test-Path -LiteralPath $Candidate)) { return $false }
    $idaExe = Join-Path $Candidate 'ida.exe'
    $idaDll = Join-Path $Candidate 'ida.dll'
    return (Test-Path -LiteralPath $idaExe) -or (Test-Path -LiteralPath $idaDll)
}

if ([string]::IsNullOrWhiteSpace($IdaDir)) {
    if (-not [string]::IsNullOrWhiteSpace($env:IDADIR) -and (Test-IdaInstallDir $env:IDADIR)) {
        $IdaDir = $env:IDADIR
    } else {
        $persisted = [Environment]::GetEnvironmentVariable('IDADIR', 'User')
        if (Test-IdaInstallDir $persisted) {
            $IdaDir = $persisted
        } else {
            $candidates = @(
                'C:\Program Files\IDA Professional 9.4',
                'C:\Program Files\IDA Pro 9.4',
                'C:\Program Files\IDA Pro',
                (Join-Path $env:USERPROFILE 'Tools\IDAPro94'),
                (Join-Path $env:USERPROFILE 'Tools\IDA Pro 9.4\App\IDA Pro'),
                (Join-Path ([Environment]::GetFolderPath('Desktop')) 'IDA Pro 9.4\App\IDA Pro'),
                (Join-Path $env:USERPROFILE 'Desktop\IDA Pro 9.4\App\IDA Pro')
            )
            $IdaDir = $candidates | Where-Object { Test-IdaInstallDir $_ } | Select-Object -First 1
        }
    }
}

if (-not (Test-IdaInstallDir $IdaDir)) {
    Write-Output 'ERR:IDADIR_not_found'
    exit 1
}

$env:IDADIR = [System.IO.Path]::GetFullPath($IdaDir)
$portableRoot = Split-Path (Split-Path $env:IDADIR -Parent) -Parent
# Desktop\IDA Pro 9.4\App\IDA Pro -> Desktop\IDA Pro 9.4.
if ((Split-Path $env:IDADIR -Leaf) -eq 'IDA Pro') {
    $maybe = Split-Path (Split-Path $env:IDADIR -Parent) -Parent
    if (Test-Path (Join-Path $maybe 'Launch-IDA-Pro.cmd')) {
        $portableRoot = $maybe
    }
}

Write-Output "INFO:IDADIR=$env:IDADIR"

if ($UsePortableLauncher -or (Test-Path (Join-Path $portableRoot 'Launch-IDA-Pro.cmd'))) {
    $launcher = Join-Path $portableRoot 'Launch-IDA-Pro.cmd'
    if (Test-Path -LiteralPath $launcher) {
        Write-Output "INFO:launcher=$launcher"
        if (-not [string]::IsNullOrWhiteSpace($Path)) {
            if (-not (Test-Path -LiteralPath $Path)) {
                Write-Output 'ERR:file_not_found'
                exit 1
            }
            # Trình khởi chạy portable đã mở IDA; sau đó có thể truyền người dùng/file trực tiếp cho ida.exe.
            $target = [System.IO.Path]::GetFullPath($Path)
            Start-Process -FilePath (Join-Path $env:IDADIR 'ida.exe') -ArgumentList @('"' + $target + '"') -WorkingDirectory $env:IDADIR
        } else {
            Start-Process -FilePath $launcher -WorkingDirectory $portableRoot
        }
        Write-Output 'OK:gui_started'
        Write-Output 'HINT: Open a binary in IDA, confirm Output shows [MCP] port=13337, then use idapro MCP tools.'
        exit 0
    }
}

$idaExe = Join-Path $env:IDADIR 'ida.exe'
if (-not [string]::IsNullOrWhiteSpace($Path)) {
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Output 'ERR:file_not_found'
        exit 1
    }
    $target = [System.IO.Path]::GetFullPath($Path)
    Start-Process -FilePath $idaExe -ArgumentList @('"' + $target + '"') -WorkingDirectory $env:IDADIR
} else {
    Start-Process -FilePath $idaExe -WorkingDirectory $env:IDADIR
}

Write-Output 'OK:gui_started'
Write-Output 'HINT: Open a binary in IDA, confirm Output shows [MCP] port=13337, then use idapro MCP tools.'
