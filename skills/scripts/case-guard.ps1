#Requires -Version 5.1
# Cổng kiểm tra phạm vi nhẹ trước ACT. Mã thoát 0 = đạt, 2 = chưa sẵn sàng, 1 = sai cách dùng/lỗi.
# Cách dùng:
#   powershell -File skills/scripts/case-guard.ps1 -CaseRoot work\my-case
#   powershell -File skills/scripts/case-guard.ps1 -CaseRoot work\my-case -Force   # cờ tương thích; không bao giờ vượt cổng phạm vi bắt buộc
param(
    [Parameter(Mandatory = $true)]
    [string] $CaseRoot,

    [switch] $Force,
    [switch] $Quiet
)
$ErrorActionPreference = 'Stop'

function Write-Info([string] $m) {
    if (-not $Quiet) { Write-Host $m }
}

if (-not (Test-Path -LiteralPath $CaseRoot)) {
    Write-Host ("ERROR: CaseRoot missing: {0}" -f $CaseRoot) -ForegroundColor Red
    exit 1
}

$scopePath = Join-Path $CaseRoot 'scope.md'
if (-not (Test-Path -LiteralPath $scopePath)) {
    Write-Host ("ERROR: scope.md missing under {0}" -f $CaseRoot) -ForegroundColor Red
    exit 1
}

$scope = Get-Content -LiteralPath $scopePath -Raw -Encoding UTF8
$issues = New-Object System.Collections.Generic.List[string]

function Get-ScopeSection([string] $Text, [string] $Name) {
    $pattern = '(?ms)^##\s*' + [regex]::Escape($Name) + '\s*\r?\n(?<body>.*?)(?=^##\s|\z)'
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) { return $match.Groups['body'].Value }
    return ''
}

function Get-SectionField([string] $Section, [string] $Name) {
    $pattern = '(?m)^\s*-\s*' + [regex]::Escape($Name) + ':\s*(?<value>.*?)\s*$'
    $match = [regex]::Match($Section, $pattern)
    if ($match.Success) { return $match.Groups['value'].Value.Trim() }
    return ''
}

$authSection = Get-ScopeSection -Text $scope -Name 'auth'
$networkSection = Get-ScopeSection -Text $scope -Name 'network_profile'
$signoffSection = Get-ScopeSection -Text $scope -Name 'signoff'

# Trường auth.status trong phần ủy quyền.
$authGranted = (Get-SectionField -Section $authSection -Name 'status') -eq 'granted'
if (-not $authGranted) { [void]$issues.Add('auth.status is not granted') }

# Trường network_profile.mode trong phần cấu hình mạng.
$netMode = Get-SectionField -Section $networkSection -Name 'mode'
$allowedNetworkModes = @('offline', 'lab_only', 'authorized_target_only', 'unrestricted_lab')
if ([string]::IsNullOrWhiteSpace($netMode)) {
    [void]$issues.Add('network_profile.mode missing')
} elseif ($netMode -notin $allowedNetworkModes) {
    [void]$issues.Add("network_profile.mode is unsupported: $netMode")
} elseif ($netMode -eq 'offline') {
    # offline chỉ đạt nếu assets/notes có nhắc đường dẫn mẫu; đây là ghi chú mềm.
    if ($scope -notmatch 'sample|offline.?path|本地.?样本|\.apk\b|\.bin\b|\.exe\b') {
        [void]$issues.Add('network_profile.mode is offline without offline sample cue')
    }
}

# assets trong in_scope: chỉ lấy các mục dưới "- assets:" bên trong ## in_scope.
# Không coi chính "- assets:", ops_refs hoặc URL evidence_of_auth là tài sản.
$hasAsset = $false
$inScopeSection = Get-ScopeSection -Text $scope -Name 'in_scope'
if ($inScopeSection -and $inScopeSection -match '(?ms)-\s*assets:\s*\r?\n(?<body>(?:\s+.+\r?\n?|\s+\r?\n?)*)') {
    $assetBody = $Matches['body']
    # Yêu cầu mục danh sách thụt vào: "  - value", trong đó value không phải dấu [] rỗng.
    if ($assetBody -match '(?m)^\s+-\s+(?!\[\s*\])\S+') {
        $hasAsset = $true
    }
}
if (-not $hasAsset -and $netMode -ne 'offline') {
    [void]$issues.Add('in_scope.assets appears empty')
}

# Trường ready_for_act trong phần xác nhận.
$ready = (Get-SectionField -Section $signoffSection -Name 'ready_for_act') -eq 'true'
if (-not $ready) { [void]$issues.Add('ready_for_act is not true') }

if ($issues.Count -eq 0) {
    Write-Info ("CASE-GUARD OK: {0}" -f $CaseRoot)
    exit 0
}

Write-Host ("CASE-GUARD NOT READY: {0}" -f $CaseRoot) -ForegroundColor Yellow
foreach ($i in $issues) { Write-Host (" - {0}" -f $i) -ForegroundColor Yellow }

if ($Force) {
    Write-Host 'CASE-GUARD: -Force does not bypass scope hard gates.' -ForegroundColor Yellow
}

Write-Host 'Fix scope (or re-run case-init -AuthGranted -TargetUrl ...).' -ForegroundColor Yellow
exit 2
