#Requires -Version 5.1
# Tạo skills/INDEX.md: trích xuất name và description từ frontmatter của từng SKILL.md để tạo chỉ mục.
# Có tính lặp an toàn: chạy lại cho cùng kết quả (CI dùng git diff để phát hiện lệch).
# Cách dùng:
#   powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/extract-summaries.ps1
#   powershell -File skills/scripts/extract-summaries.ps1 -Check   # chỉ kiểm tra, không ghi (chế độ CI, lệch thì exit 1)
param(
    [switch] $Check
)
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$skillsRoot = Split-Path -Parent $scriptDir
$indexPath = Join-Path $skillsRoot 'INDEX.md'

# Quét SKILL.md của các module trong repo (loại cây ignored/private để clone sạch và máy phát triển cho cùng kết quả).
$skipDirs = @('ops', 'scripts', 'config', 'tests', 'field-journal', 'references')
$packageRoot = Split-Path -Parent $skillsRoot
$trackedSkillFiles = @()
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    $trackedPaths = @(& $git.Source -C $packageRoot ls-files -- 'skills/**/SKILL.md')
    if ($LASTEXITCODE -eq 0) {
        $trackedSkillFiles = @($trackedPaths | ForEach-Object {
            $fullPath = Join-Path $packageRoot ($_ -replace '/', [IO.Path]::DirectorySeparatorChar)
            if (Test-Path -LiteralPath $fullPath -PathType Leaf) { Get-Item -LiteralPath $fullPath }
        })
    }
}
$candidateSkillFiles = if ($trackedSkillFiles.Count -gt 0) {
    $trackedSkillFiles
} else {
    @(Get-ChildItem -Path $skillsRoot -Recurse -Filter 'SKILL.md')
}
$skillFiles = $candidateSkillFiles | Where-Object {
    $rel = $_.FullName.Substring($skillsRoot.Length + 1)
    $rel -ne 'SKILL.md' -and -not ($skipDirs | Where-Object { $rel.StartsWith($_ + '\') -or $rel.StartsWith($_ + '/') })
} | Sort-Object { $_.FullName.Substring($skillsRoot.Length + 1) }

$rows = New-Object System.Collections.ArrayList
foreach ($sf in $skillFiles) {
    $rel = $sf.FullName.Substring($skillsRoot.Length + 1)
    # Tương thích cả dấu phân cách đường dẫn Windows (\) và Linux/macOS (/).
    $dir = $rel.Split(@('\', '/'))[0]
    $head = Get-Content -LiteralPath $sf.FullName -TotalCount 15 -Encoding UTF8
    $name = ''; $desc = ''; $blockMode = $false; $inFm = $false
    foreach ($line in $head) {
        if ($line -match '^---') {
            if ($inFm) { break }   # Dấu --- thứ hai kết thúc frontmatter.
            $inFm = $true; continue
        }
        if (-not $inFm) { continue }
        if ($line -match '^name:\s*(.+)$') { $name = $Matches[1].Trim(); continue }
        if ($line -match '^description:\s*\|') { $blockMode = $true; continue }
        if ($line -match '^description:\s*(.+)$') { $desc = $Matches[1].Trim(); continue }
        if ($blockMode) {
            # Khối YAML: ghép các dòng văn bản thụt vào (lấy dòng đầu, cắt nếu quá dài).
            if ($line -match '^\s{2,}(.+)$') {
                if (-not $desc) { $desc = $Matches[1].Trim() }
            } elseif ($line -match '^\S') { $blockMode = $false }
        }
    }
    if (-not $name) { $name = $dir }
    if (-not $desc) { $desc = '(无摘要)' }
    if ($desc.Length -gt 160) { $desc = $desc.Substring(0, 157) + '...' }
    [void]$rows.Add([pscustomobject]@{
        Dir  = $dir
        Name = $name
        Desc = $desc
        Path = $rel
    })
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# reverse-skill 技能导航索引')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('> 本文件由 `skills/scripts/extract-summaries.ps1` 自动生成，**请勿手改**。')
[void]$sb.AppendLine('> 修改摘要请编辑对应模块 `SKILL.md` 的 frontmatter `description`，然后重跑脚本。')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## 模块总览')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| 模块 | 摘要 |')
[void]$sb.AppendLine('|------|------|')
foreach ($r in $rows) {
    $esc = $r.Desc -replace '\|', '\|'
    [void]$sb.AppendLine(("| [{0}]({1}) | {2} |" -f $r.Name, ($r.Path -replace '\\', '/'), $esc))
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## 目录树')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('```')
foreach ($r in $rows) {
    [void]$sb.AppendLine(("skills/{0}/" -f ($r.Path -replace '\\', '/')))
}
[void]$sb.AppendLine('```')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## 路由')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('PRIMARY 路由由 `skills/config/routing.json`（唯一事实源）驱动，用 `master-route.ps1 -Hint "<任务>"` 分诊。')
[void]$sb.AppendLine('歧义场景读 `skills/routing.md` 全矩阵；CTF 多类型任务走 `CTF-Sandbox-Orchestrator/`。')

$newContent = $sb.ToString()
# Chuẩn hóa kết thúc dòng LF để đồng nhất với .gitattributes (*.md eol=lf), bảo đảm -Check ổn định sau clone.
$newContent = $newContent -replace "`r`n", "`n"
$utf8 = New-Object System.Text.UTF8Encoding $true

if ($Check) {
    if (-not (Test-Path -LiteralPath $indexPath)) {
        Write-Host '[CHECK] INDEX.md missing' -ForegroundColor Red
        exit 1
    }
    # Miễn nhiễm kết thúc dòng: worktree trên máy có autocrlf=true có thể là CRLF; chuẩn hóa trước khi so sánh.
    $old = ([System.IO.File]::ReadAllText($indexPath)) -replace "`r`n", "`n"
    if ($old -eq $newContent) {
        Write-Host '[CHECK] INDEX.md up to date' -ForegroundColor Green
        exit 0
    }
    Write-Host '[CHECK] INDEX.md out of date (run extract-summaries.ps1)' -ForegroundColor Red
    exit 1
}

[System.IO.File]::WriteAllText($indexPath, $newContent, $utf8)
Write-Host ("INDEX.md regenerated: {0} modules" -f $rows.Count) -ForegroundColor Green
