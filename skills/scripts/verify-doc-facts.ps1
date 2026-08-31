<#
.SYNOPSIS
  Kiểm tra bảng dữ kiện tài liệu (danh sách capability, cổng MCP, số công cụ Burp)
  với nguồn sự thật (bootstrap-manifest.json / McpHttpServer.java).

.DESCRIPTION
  Cổng P1-4: bảng dữ kiện trong RULES.md / RULES_zh.md / skills/SKILL.md không được
  lệch manifest và mã nguồn extension Burp. Thoát với mã 1 khi không khớp.
#>
$ErrorActionPreference = 'Stop'
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$fail = 0

function Check([string]$Name, [bool]$Ok, [string]$Detail) {
  if ($Ok) { Write-Host "OK   $Name" } else { $script:fail++; Write-Host "FAIL $Name : $Detail" }
}

# --- Nguồn sự thật: manifest ---
$manifestPath = Join-Path $Root 'skills\scripts\bootstrap-manifest.json'
$manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$capNames = @($manifest.capabilities | ForEach-Object { $_.name } | Sort-Object)

# --- Nguồn sự thật: Burp getToolList() ---
$javaPath = Join-Path $Root 'burp-mcp-full\src\main\java\com\burpmcp\McpHttpServer.java'
$java = Get-Content $javaPath -Raw
$def = [regex]::Match($java, 'String\s+getToolList\s*\([^)]*\)\s*\{')
if (-not $def.Success) { throw 'getToolList() not found in McpHttpServer.java' }
$endIdx = $java.IndexOf("`n    }", $def.Index)
$body = $java.Substring($def.Index, $endIdx - $def.Index)
$burpTools = @([regex]::Matches($body, '\\"([a-z_0-9]+)\\"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
$burpCount = $burpTools.Count

Write-Host "source-of-truth: $($capNames.Count) capabilities, Burp getToolList = $burpCount tools"

# --- Hàm hỗ trợ tài liệu ---
function Get-ListLine([string]$Text, [string]$Marker) {
  $lines = $Text -split "`r?`n"
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match [regex]::Escape($Marker)) {
      $inline = [regex]::Match($lines[$i], '）：(.+?)\s*$')
      if ($inline.Success) { return $inline.Groups[1].Value }
      if ($i + 1 -lt $lines.Count) { return $lines[$i + 1] }
    }
  }
  return ''
}

function Test-ListHasAll([string]$ListText, [string[]]$Names) {
  $tokens = @($ListText -split '[、,]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  if ($tokens.Count -ne $Names.Count) { return $false }
  foreach ($n in $Names) { if ($tokens -notcontains $n) { return $false } }
  return $true
}

$rulesEn = Get-Content (Join-Path $Root 'RULES.md') -Raw -Encoding UTF8
$rulesZh = Get-Content (Join-Path $Root 'RULES_zh.md') -Raw -Encoding UTF8
$skillMd = Get-Content (Join-Path $Root 'skills\SKILL.md') -Raw -Encoding UTF8

$enList = Get-ListLine $rulesEn 'Supported capability names'
$zhList = Get-ListLine $rulesZh '支持的能力名'
$skList = Get-ListLine $skillMd '支持的能力'

Check 'RULES.md capability list' (Test-ListHasAll $enList $capNames) "expected $($capNames.Count) capabilities: $($capNames -join ', ')"
Check 'RULES_zh.md capability list' (Test-ListHasAll $zhList $capNames) "expected $($capNames.Count) capabilities"
Check 'SKILL.md capability list' (Test-ListHasAll $skList $capNames) "expected $($capNames.Count) capabilities"
Check 'RULES_zh.md count text' ($rulesZh.Contains("共 $($capNames.Count) 项")) "expected 共 $($capNames.Count) 项"

# --- Cổng MCP từ servicePort / servicePortRange trong manifest ---
foreach ($c in $manifest.capabilities) {
  if (-not $c.PSObject.Properties['servicePort']) { continue }
  $port = [string]$c.servicePort
  Check "RULES.md port $($c.name)=$port" ($rulesEn.Contains($port)) "missing port $port for $($c.name)"
  Check "RULES_zh.md port $($c.name)=$port" ($rulesZh.Contains($port)) "missing port $port for $($c.name)"
  if ($c.PSObject.Properties['servicePortRange']) {
    $range = @($c.servicePortRange) -join '-'
    Check "RULES.md range $($c.name)=$range" ($rulesEn.Contains($range)) "missing range $range for $($c.name)"
    Check "RULES_zh.md range $($c.name)=$range" ($rulesZh.Contains($range)) "missing range $range for $($c.name)"
  }
}

# --- Số lượng công cụ Burp ---
Check 'RULES.md burp tool count' ($rulesEn.Contains("$burpCount-tool")) "expected '$burpCount-tool' in RULES.md"
Check 'RULES_zh.md burp tool count' ($rulesZh.Contains("$burpCount 工具全控制")) "expected '$burpCount 工具全控制' in RULES_zh.md"

Write-Host "verify-doc-facts: $fail failure(s)"
if ($fail -gt 0) { exit 1 }
