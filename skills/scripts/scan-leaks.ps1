<#
.SYNOPSIS
  Quét text/markdown để tìm thông tin nhạy cảm chưa ẩn danh (IP/email/điện thoại/JWT/API key/token).

.DESCRIPTION
  Dùng cùng quy tắc mẫu trong skills/field-journal/anonymization.md.
  Mặc định: thoát với mã 1 khi có phát hiện (cổng kiểm tra CI).
  Dùng -ReportOnly để chỉ báo cáo mà không đánh dấu thất bại.

.PARAMETER Path
  File hoặc thư mục cần quét (mặc định: skills/field-journal).
  Thư mục sẽ quét đệ quy *.md/*.txt/*.json; file chỉ quét chính file đó.

.PARAMETER ReportOnly
  Báo cáo phát hiện nhưng không đặt mã thoát thất bại.
#>
param(
  [string]$Path = "skills/field-journal",
  [switch]$ReportOnly
)

$ErrorActionPreference = 'Stop'

# Các domain mẫu được phép (ví dụ trong tài liệu không phải dữ liệu rò rỉ).
$allowedDomains = @('example.com','example.org','example.net','example.edu','example.test','test','localhost','local','invalid')

$patterns = @(
  @{ Name = 'Public IPv4'; Regex = '\b(?!(?:10\.|127\.|172\.(?:1[6-9]|2[0-9]|3[01])\.|192\.168\.|169\.254\.|100\.100\.|198\.51\.100\.|203\.0\.113\.|192\.0\.2\.|0\.0\.0\.|224\.|25[0-5]\.))(?:\d{1,3}\.){3}\d{1,3}\b' }
  @{ Name = 'Email'; Regex = '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b' }
  @{ Name = 'CN mobile'; Regex = '\b1[3-9][0-9]{9}\b' }
  @{ Name = 'JWT'; Regex = 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}' }
  @{ Name = 'AWS Access Key'; Regex = '\bAKIA[0-9A-Z]{16}\b' }
  @{ Name = 'OpenAI key'; Regex = '\bsk-(?:proj-)?[A-Za-z0-9]{20,}\b' }
  @{ Name = 'GitHub token'; Regex = '\bgh[pousr]_[A-Za-z0-9]{20,}\b' }
  @{ Name = 'npm token'; Regex = '\bnpm_[A-Za-z0-9]{30,}\b' }
  @{ Name = 'Slack token'; Regex = '\bxox[baprs]-[A-Za-z0-9-]{10,}\b' }
  @{ Name = 'Google API key'; Regex = '\bAIza[A-Za-z0-9_-]{35}\b' }
  @{ Name = 'Stripe live key'; Regex = '\b(?:sk|rk)_live_[A-Za-z0-9]{20,}\b' }
)

function Test-EmailAllowed {
  param([string]$Match)
  $domain = ($Match -split '@')[-1]
  foreach ($d in $allowedDomains) {
    if ($domain -eq $d -or $domain.EndsWith('.' + $d)) { return $true }
  }
  return $false
}

$targets = @()
if (Test-Path $Path -PathType Container) {
  $targets = Get-ChildItem -Path $Path -Recurse -File -Include *.md,*.txt,*.json | Sort-Object FullName
} elseif (Test-Path $Path -PathType Leaf) {
  $targets = @(Get-Item $Path)
} else {
  Write-Error "Path not found: $Path"
  exit 2
}

$findings = 0
foreach ($t in $targets) {
  $lines = Get-Content -Path $t.FullName -Encoding UTF8
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    foreach ($p in $patterns) {
      foreach ($m in [regex]::Matches($line, $p.Regex)) {
        if ($p.Name -eq 'Email' -and (Test-EmailAllowed $m.Value)) { continue }
        $findings++
        $kind = if ($ReportOnly) { 'warning' } else { 'error' }
        Write-Host "::$kind file=$($t.FullName),line=$($i + 1)::$($p.Name): $($m.Value -replace "\r","%0D" -replace "\n","%0A")"
      }
    }
  }
}

Write-Host "scan-leaks: scanned $($targets.Count) files, $findings finding(s)"
if ($findings -gt 0 -and -not $ReportOnly) { exit 1 }
