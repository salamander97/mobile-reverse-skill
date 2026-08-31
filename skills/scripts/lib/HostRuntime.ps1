Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Xác định file thực thi PowerShell dùng khi script phải khởi chạy tiến trình
# PowerShell con (ví dụ chạy .ps1 khác độc lập với -NoProfile).
#
# Vì sao không hard-code "powershell":
#   - Máy Windows hiện đại có thể chỉ cài PowerShell 7+ ("pwsh") và không có
#     Windows PowerShell 5.1 ("powershell.exe") trên PATH.
#   - Ngược lại, "powershell" đơn lẻ trỏ tới 5.1 và phân tích sai script UTF-8
#     không BOM khi được gọi lồng từ pwsh.
# Thứ tự xác định (độ tin cậy cao trước):
#   1. File thực thi của tiến trình hiện tại (host đã khởi chạy script này).
#   2. pwsh trên PATH.
#   3. powershell trên PATH.
#   4. %SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe.
# Trả về đường dẫn tuyệt đối tới file thực thi; báo lỗi nếu không có lựa chọn dùng được.
function Resolve-ReverseHostExe {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $hostExe = $null

    try {
        $procPath = (Get-Process -Id $PID -ErrorAction Stop).Path
        if ($procPath -and (Test-Path -LiteralPath $procPath)) {
            $hostExe = $procPath
        }
    } catch { }

    if (-not $hostExe) {
        $cmd = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) {
            $hostExe = $cmd.Source
        }
    }

    if (-not $hostExe) {
        $cmd = Get-Command powershell -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) {
            $hostExe = $cmd.Source
        }
    }

    if (-not $hostExe -and $env:SystemRoot) {
        $fallback = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (Test-Path -LiteralPath $fallback) {
            $hostExe = $fallback
        }
    }

    if (-not $hostExe) {
        throw 'No usable PowerShell host executable found (tried current process, pwsh, powershell, Windows PowerShell fallback).'
    }

    return $hostExe
}
