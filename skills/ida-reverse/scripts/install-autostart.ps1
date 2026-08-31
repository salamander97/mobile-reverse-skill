<#
.SYNOPSIS
Đăng ký tác vụ đã lên lịch để giữ HTTP MCP của IDA Pro hoạt động.

.DESCRIPTION
Các thiết lập của tác vụ reverse-skill-ida-mcp:
- Chạy khi đăng nhập, trễ 30 giây.
- Kích hoạt từ thời điểm hiện tại và lặp mỗi phút trong 3650 ngày
  (máy này không ghi được -Daily.Repetition).
- Khởi động lại tối đa 3 lần nếu chính script bị lỗi.
- Chạy watchdog.ps1 (dùng lại khi khỏe, chỉ khởi động khi tắt;
  không bao giờ kill ida.exe khi plugin giao diện đang giữ cổng 13337).

Cách dùng:
  powershell -File install-autostart.ps1
  powershell -File install-autostart.ps1 -Unregister
#>

param(
    [switch]$Unregister
)

$ErrorActionPreference = 'Stop'

$taskName = 'reverse-skill-ida-mcp'
$watchdog = Join-Path $PSScriptRoot 'watchdog.ps1'
if (-not (Test-Path -LiteralPath $watchdog)) {
    Write-Output "ERR:missing $watchdog"
    exit 1
}

if ($Unregister) {
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
    Write-Output 'OK:unregistered'
    exit 0
}

$arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watchdog`""
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg -WorkingDirectory $PSScriptRoot

$logon = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$logon.Delay = 'PT30S'

# -Daily.Repetition không ghi được trên host này; dùng -Once với thời lượng dài.
$repeat = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 1) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)
$settings.Hidden = $true

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger @($logon, $repeat) `
    -Settings $settings `
    -Principal $principal `
    -Force `
    -Description 'Keep IDA Pro MCP HTTP (127.0.0.1:13337) alive. Reuses a healthy server; starts idalib_supervisor only when down.' `
    | Out-Null

Start-ScheduledTask -TaskName $taskName
Write-Output "OK:registered:$taskName"
Write-Output 'INFO:triggers=AtLogOn+30s, every 1 min'
Write-Output ("INFO:watchdog={0}" -f $watchdog)
