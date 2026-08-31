#Requires -Version 5.1
# Bộ định tuyến PRIMARY của mobile-reverse-skill.
# Nguồn sự thật duy nhất: skills/config/routing.json (không hard-code bảng định tuyến trong script này).
# Tương thích CLI cũ: -Hint / -OutDir; xuất route-scope.md; mã thoát 0 là thành công, 2 là thiếu cấu hình hoặc skill.
# Đọc nguồn UTF-8 có BOM để PowerShell 5.1 trên Windows hiển thị tiếng Việt chính xác.
param(
    [string] $Hint = '',
    [string] $OutDir = '',
    [string] $ProjectRoot = ''
)
$ErrorActionPreference = 'Stop'

# Chuyển chữ Latin về chữ thường; nội dung Unicode vẫn được giữ nguyên.
$t = if ($Hint) { $Hint.ToLowerInvariant() } else { '' }

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$skillsRoot = Split-Path -Parent $scriptDir
$packageRoot = Split-Path -Parent $skillsRoot
$configPath = Join-Path $skillsRoot 'config/routing.json'

# --- Đọc cấu hình định tuyến (nguồn sự thật duy nhất) ---
if (-not (Test-Path -LiteralPath $configPath)) {
    Write-Host ("ERROR: routing config missing: {0}" -f $configPath) -ForegroundColor Red
    Write-Host 'Restore skills/config/routing.json (git checkout / git pull) and retry.' -ForegroundColor Yellow
    exit 2
}
try {
    $cfg = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    Write-Host ("ERROR: routing config is not valid JSON: {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 2
}

# --- So khớp quy tắc: mỗi keyword khớp sẽ được tính vào tập ứng viên ---
$sel = New-Object System.Collections.Generic.List[string]
foreach ($route in $cfg.routes.PSObject.Properties) {
    $id = $route.Name
    foreach ($kw in $route.Value.keywords) {
        $hit = $false
        if ($null -ne $kw.must -and $t -match $kw.must) { $hit = $true }
        # mustAll: mọi biểu thức con phải cùng khớp.
        if ($hit -and $null -ne $kw.mustAll) {
            foreach ($m in $kw.mustAll) {
                if ($t -notmatch $m) { $hit = $false; break }
            }
        }
        # exclude: nếu khớp thì bỏ qua quy tắc này để tránh bắt nhầm ngữ cảnh.
        if ($hit -and $null -ne $kw.exclude -and $t -match $kw.exclude) { $hit = $false }
        if ($hit) { [void]$sel.Add($id) }
    }
}

# --- Tính điểm: mỗi quy tắc cùng mã khớp sẽ cộng thêm một điểm ---
$scores = [ordered]@{}
foreach ($item in $sel) {
    if (-not $scores.Contains($item)) { $scores[$item] = 0 }
    $scores[$item] = $scores[$item] + 1
}

$uniq = New-Object System.Collections.Generic.List[string]
foreach ($d in $scores.Keys) { [void]$uniq.Add($d) }

# --- Tự kiểm tra priority: routes và priority phải bao phủ đúng nhau ---
$routeIds = @($cfg.routes.PSObject.Properties | ForEach-Object { $_.Name })
$missingInPriority = @($routeIds | Where-Object { $_ -notin @($cfg.priority) })
$extraInPriority = @($cfg.priority | Where-Object { $_ -notin $routeIds })
if ($missingInPriority.Count -gt 0 -or $extraInPriority.Count -gt 0) {
    Write-Host 'WARN: routing.json routes/priority mismatch:' -ForegroundColor Yellow
    if ($missingInPriority.Count -gt 0) { Write-Host ("  routes not in priority: {0}" -f ($missingInPriority -join ', ')) -ForegroundColor Yellow }
    if ($extraInPriority.Count -gt 0) { Write-Host ("  priority not in routes: {0}" -f ($extraInPriority -join ', ')) -ForegroundColor Yellow }
}

# --- Chọn PRIMARY theo điểm cao nhất; hòa điểm thì ưu tiên phần tử đứng trước ---
$priority = @($cfg.priority)
$fallbackId = $cfg.meta.fallbackId
$primary = $null
$maxScore = -1
foreach ($p in $priority) {
    if ($scores.Contains($p)) {
        $score = $scores[$p]
        if ($score -gt $maxScore) {
            $maxScore = $score
            $primary = $p
        }
    }
}

$notes = New-Object System.Collections.Generic.List[string]
$confidence = 'low'
if ($null -eq $primary) {
    $primary = $fallbackId
    if ($t) { [void]$notes.Add('No strong keyword hit; open routing.md full matrix') }
    else { [void]$notes.Add('Empty hint; provide task text') }
} else {
    $confidence = if ($uniq.Count -eq 1) { 'high' } else { 'medium' }
}

# Bảo vệ: nếu PRIMARY không tồn tại trong routes, dùng fallback thay thế.
if ($routeIds -notcontains $primary) {
    Write-Host ("WARN: primary id '{0}' not in routes; falling back to {1}" -f $primary, $fallbackId) -ForegroundColor Yellow
    $primary = $fallbackId
}

# Dùng thư mục dự án của bên gọi để không ghi sản phẩm định tuyến vào gói skill.
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$skillsRoot = Split-Path -Parent $scriptDir
$packageRoot = Split-Path -Parent $skillsRoot
. (Join-Path (Join-Path $scriptDir 'lib') 'WorkRoot.ps1')
$projectRoot = Resolve-ReverseProjectRoot -RequestedRoot $ProjectRoot

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $workRoot = Join-Path $projectRoot 'work'
    $OutDir = Join-Path $workRoot ("master-route-{0}" -f $stamp)
}

$primaryPath = $cfg.routes.$primary.skill
$primaryLabel = $cfg.routes.$primary.label
$skillAbs = Join-Path $skillsRoot ($primaryPath -replace '/', [IO.Path]::DirectorySeparatorChar)
if (-not (Test-Path -LiteralPath $skillAbs)) {
    Write-Host ("ERROR: PRIMARY skill missing: {0}" -f $skillAbs) -ForegroundColor Red
    exit 2
}

# --- Thư mục đầu ra mặc định: work\master-route-<ts> trong dự án gọi ---
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    if ($packageRoot -and (Test-Path -LiteralPath $packageRoot)) {
        $OutDir = Join-Path (Join-Path $packageRoot 'work') ("master-route-{0}" -f $stamp)
    } else {
        $tmpBase = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
        $OutDir = Join-Path (Join-Path $tmpBase 'reverse-skill-route') ("master-route-{0}" -f $stamp)
    }
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# --- Ghi route-scope.md; định dạng giữ tương thích để script sau đọc primary_skill / primary ---
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# reverse-skill Master route (PRIMARY)')
[void]$sb.AppendLine(("- created: {0}" -f (Get-Date -Format 'o')))
[void]$sb.AppendLine(("- package: reverse-skill"))
$hintOneLine = (($Hint -replace '[\r\n]+', ' ').Trim())
[void]$sb.AppendLine(("- hint: {0}" -f $hintOneLine))
[void]$sb.AppendLine(("- primary: {0}" -f $primary))
[void]$sb.AppendLine(("- primary_label: {0}" -f $primaryLabel))
[void]$sb.AppendLine(("- primary_skill: skills/{0}" -f $primaryPath))
[void]$sb.AppendLine(("- confidence: {0}" -f $confidence))
[void]$sb.AppendLine(("- project_root: {0}" -f $projectRoot))
$sec = New-Object System.Collections.Generic.List[string]
foreach ($d in $uniq) {
    if ($d -ne $primary) { [void]$sec.Add(("skills/{0}" -f $cfg.routes.$d.skill)) }
}
$secText = if ($sec.Count -gt 0) { ($sec -join ', ') } else { '(none)' }
[void]$sb.AppendLine(("- secondary: {0}" -f $secText))
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## MUST open next')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('1. skills/MASTER-ROUTING.md')
[void]$sb.AppendLine(("2. skills/{0}" -f $primaryPath))
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Notes')
if ($notes.Count -eq 0) { [void]$sb.AppendLine('- (none)') }
foreach ($n in $notes) { [void]$sb.AppendLine(("- {0}" -f $n)) }

# route-scope dùng UTF-8 có BOM để tương thích Notepad trên Windows.
$utf8 = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText((Join-Path $OutDir 'route-scope.md'), $sb.ToString(), $utf8)

Write-Host ("PRIMARY -> skills/{0}" -f $primaryPath) -ForegroundColor Green
Write-Host ("Label: {0} | confidence: {1}" -f $primaryLabel, $confidence)
foreach ($n in $notes) { Write-Host ("NOTE: {0}" -f $n) -ForegroundColor Yellow }
Write-Host ("Wrote {0}\route-scope.md" -f $OutDir)
Write-Host 'ACTION: Open PRIMARY SKILL.md now and execute ACTION REQUIRED.' -ForegroundColor Yellow
