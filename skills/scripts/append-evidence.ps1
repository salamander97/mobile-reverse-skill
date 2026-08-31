#Requires -Version 5.1
# Thêm một mục Evidence vào work/<case>/evidence/ theo quy ước Evidence vận hành.
#
# Cách dùng đơn giản:
#   powershell -File skills/scripts/append-evidence.ps1 -CaseRoot work\my-case `
#     -Id E-001 -Title "Open clock API" -ReproCommand 'curl -sI https://example/' `
#     -Severity info -Status observed
#
# Ký tự đặc biệt / khoảng trắng / dấu nháy trong excerpt (khuyến nghị khi gọi lồng qua -File):
#   Set-Content excerpt.txt -Value '"XML parsing error" / Entities are not allowed'
#   powershell -File skills/scripts/append-evidence.ps1 ... -RawExcerptFile excerpt.txt
#
# LƯU Ý: `powershell -File` lồng sẽ tách giá trị nhiều từ nếu không đặt trong dấu nháy.
# Ưu tiên -RawExcerptFile hoặc gọi script trong cùng tiến trình: & .\append-evidence.ps1 -RawExcerpt 'full text here'.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $CaseRoot,

    [Parameter(Mandatory = $true)]
    [string] $Id,

    [Parameter(Mandatory = $true)]
    [string] $Title,

    [Parameter(Mandatory = $true)]
    [string] $ReproCommand,

    [string] $Severity = 'info',
    [string] $Status = 'observed',
    [string] $SourceType = 'command',
    [string] $RawExcerpt = '',
    [string] $RawExcerptFile = '',
    [string] $Location = '',
    [string] $Notes = '',
    [string] $NotesFile = '',
    [string] $ReproCommandFile = '',
    [string] $ArtifactPath = ''
)
$ErrorActionPreference = 'Stop'

# Hàm nâng cao từ chối tham số vị trí lạ lúc bind; vẫn giữ kiểm tra rõ ràng cho host đặc biệt.
if ($args -and $args.Count -gt 0) {
    $extra = ($args | ForEach-Object { [string]$_ }) -join ' | '
    throw ("Unexpected arguments (likely -RawExcerpt/-Title quoting broke multi-word value): {0}. Use -RawExcerptFile for special characters, or pass a single quoted string." -f $extra)
}

$allowedSeverity = @('critical', 'high', 'medium', 'low', 'info', 'n/a', 'n/a_re')
$allowedStatus = @('observed', 'candidate', 'validated', 'false_positive', 'accepted_risk')

function ConvertTo-YamlBlock([string] $text) {
    if ([string]::IsNullOrEmpty($text)) { return '    n/a' }
    $clean = ($text -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', '')
    $lines = $clean -split "`r?`n", -1
    if ($lines.Count -eq 0) { return '    n/a' }
    return (($lines | ForEach-Object { '    ' + $_ }) -join [Environment]::NewLine)
}

function ConvertTo-SingleLine([string] $text) {
    if ([string]::IsNullOrEmpty($text)) { return 'n/a' }
    $t = ($text -replace '[\x00-\x1F]', ' ')
    $t = $t -replace '\s+', ' '
    return $t.Trim()
}

function Read-OptionalFile([string] $path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $null }
    if (-not (Test-Path -LiteralPath $path)) {
        throw "File not found: $path"
    }
    return [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $path), [System.Text.Encoding]::UTF8)
}

if (-not (Test-Path -LiteralPath $CaseRoot)) {
    throw "CaseRoot does not exist: $CaseRoot"
}

# Nội dung từ file được ưu tiên hơn chuỗi inline (an toàn cho ký tự đặc biệt khi dùng powershell -File).
$fromReproFile = Read-OptionalFile $ReproCommandFile
if ($null -ne $fromReproFile) { $ReproCommand = $fromReproFile }

$fromExcerptFile = Read-OptionalFile $RawExcerptFile
if ($null -ne $fromExcerptFile) { $RawExcerpt = $fromExcerptFile }

$fromNotesFile = Read-OptionalFile $NotesFile
if ($null -ne $fromNotesFile) { $Notes = $fromNotesFile }

$contentHash = 'n/a'
$artifactRef = 'n/a'
if (-not [string]::IsNullOrWhiteSpace($ArtifactPath)) {
    $artifactCandidate = $ArtifactPath
    if (-not [System.IO.Path]::IsPathRooted($artifactCandidate)) {
        $caseArtifact = Join-Path $CaseRoot $artifactCandidate
        if (Test-Path -LiteralPath $caseArtifact -PathType Leaf) { $artifactCandidate = $caseArtifact }
    }
    if (-not (Test-Path -LiteralPath $artifactCandidate -PathType Leaf)) {
        throw "ArtifactPath must point to a file inside CaseRoot: $ArtifactPath"
    }
    $caseRootFull = (Resolve-Path -LiteralPath $CaseRoot).Path
    $artifactFull = (Resolve-Path -LiteralPath $artifactCandidate).Path
    $casePrefix = $caseRootFull.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $artifactFull.StartsWith($casePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "ArtifactPath must point inside CaseRoot: $ArtifactPath"
    }
    $artifactRef = $artifactFull.Substring($casePrefix.Length) -replace '\\', '/'
    $contentHash = 'sha256:' + (Get-FileHash -LiteralPath $artifactFull -Algorithm SHA256).Hash.ToLowerInvariant()
}

$evDir = Join-Path $CaseRoot 'evidence'
New-Item -ItemType Directory -Force -Path $evDir | Out-Null

$idSafe = ($Id -replace '[^\w\-]+', '-').Trim('-')
if ($idSafe -notmatch '^E-') { $idSafe = 'E-' + $idSafe }
$fileName = $idSafe + '.md'
$path = Join-Path $evDir $fileName

$observed = Get-Date -Format 'o'
$titleLine = ConvertTo-SingleLine $Title
$sev = (ConvertTo-SingleLine $Severity).ToLowerInvariant()
if ($allowedSeverity -notcontains $sev) {
    throw ("Invalid -Severity '{0}' (allowed: {1})" -f $Severity, ($allowedSeverity -join ', '))
}
$st = (ConvertTo-SingleLine $Status).ToLowerInvariant()
if ($allowedStatus -notcontains $st) {
    throw ("Invalid -Status '{0}' (allowed: {1})" -f $Status, ($allowedStatus -join ', '))
}
$src = ConvertTo-SingleLine $SourceType
$loc = ConvertTo-SingleLine $(if ($Location) { $Location } else { 'n/a' })
if ([string]::IsNullOrWhiteSpace($ReproCommand)) {
    throw '-ReproCommand (or -ReproCommandFile) is required and must be non-empty'
}
$reproBlock = ConvertTo-YamlBlock $ReproCommand
$excerptBlock = ConvertTo-YamlBlock $(if ($RawExcerpt) { $RawExcerpt } else { 'n/a' })
$notesBlock = ConvertTo-YamlBlock $(if ($Notes) { $Notes } else { 'n/a' })

$body = @"
### $idSafe
- title: $titleLine
- observed_at: $observed
- source_type: $src
- source_ref: append-evidence.ps1
- content_hash: $contentHash
- artifact_path: $artifactRef
- severity: $sev
- status: $st
- location: $loc
- repro_command: |
$reproBlock
- raw_excerpt: |
$excerptBlock
- linked_workitem: n/a
- supersedes: none
- notes: |
$notesBlock
"@

$utf8 = New-Object System.Text.UTF8Encoding $false
$stream = $null
$writer = $null
try {
    try {
        $stream = [System.IO.File]::Open(
            $path,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None
        )
    } catch [System.IO.IOException] {
        if (Test-Path -LiteralPath $path) {
            throw ("Evidence record already exists and is immutable: {0}. Use a new -Id." -f $fileName)
        }
        throw
    }
    $writer = [System.IO.StreamWriter]::new($stream, $utf8)
    $writer.Write($body)
} finally {
    if ($null -ne $writer) {
        $writer.Dispose()
    } elseif ($null -ne $stream) {
        $stream.Dispose()
    }
}

$index = Join-Path $evDir 'INDEX.md'
$line = "- $idSafe | $sev | $st | $titleLine | $fileName"
if (-not (Test-Path -LiteralPath $index)) {
    $hdr = @"
# Chỉ mục Evidence.

| id | severity | status | title | file |
|----|----------|--------|-------|------|

"@
    [System.IO.File]::WriteAllText($index, $hdr, $utf8)
}
Add-Content -Path $index -Value $line -Encoding UTF8

Write-Host ("EVIDENCE -> {0}" -f $path) -ForegroundColor Green
Write-Host ("ID: {0} | {1} | {2}" -f $idSafe, $sev, $st)
exit 0
