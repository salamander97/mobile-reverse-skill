[CmdletBinding()]
param(
    [ValidateSet('setup','update','check','status','uninstall')]
    [string]$Action = 'setup',
    [switch]$Copy,
    [switch]$Symlink,
    [ValidateSet('codex','claude','both')]
    [string]$Clients = 'both',
    [string]$CodexDir = '',
    [string]$ClaudeDir = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$UserHome = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
if ([string]::IsNullOrWhiteSpace($UserHome)) { $UserHome = $env:USERPROFILE }
if ([string]::IsNullOrWhiteSpace($CodexDir)) { $CodexDir = if ($env:CODEX_SKILLS_DIR) { $env:CODEX_SKILLS_DIR } else { Join-Path $UserHome '.codex\skills' } }
if ([string]::IsNullOrWhiteSpace($ClaudeDir)) { $ClaudeDir = if ($env:CLAUDE_SKILLS_DIR) { $env:CLAUDE_SKILLS_DIR } else { Join-Path $UserHome '.claude\skills' } }
$Mode = if ($Copy) { 'copy' } elseif ($Symlink) { 'symlink' } else { 'auto' }
if ($Mode -eq 'auto') { $Mode = 'copy' }
$Modules = @('mobile-reverse-router','mobile-reverse','apk-reverse','macos-reverse','reverse-engineering','ghidra-reverse','ida-reverse','radare2','binary-diff','case-review','docs-generator','diagram-generator')
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Log([string]$Message) { Write-Host "[mobile-reverse-skill] $Message" }
function Warn([string]$Message) { Write-Warning "[mobile-reverse-skill] $Message" }
function Is-Managed([string]$Marker, [string]$Module) {
    if (-not (Test-Path -LiteralPath $Marker -PathType Leaf)) { return $false }
    $text = Get-Content -LiteralPath $Marker -Raw
    return $text.Contains('"package": "mobile-reverse-skill"') -and $text.Contains(('"module": "{0}"' -f $Module))
}
function Marker([string]$Parent, [string]$Module) { Join-Path $Parent ('.mobile-reverse-skill-{0}.json' -f $Module) }
function Ensure-Parent([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -eq [IO.Path]::GetPathRoot($Path) -or $Path -eq $UserHome) { throw "Unsafe destination: $Path" }
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}
function Install-One([string]$Parent, [string]$Module) {
    $source = Join-Path $Root "skills\$Module"; $target = Join-Path $Parent $Module; $marker = Marker $Parent $Module
    if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw "Module missing: $source" }
    Ensure-Parent $Parent
    if (Test-Path -LiteralPath $target) {
        $backup = "$target.backup.$Stamp"
        Move-Item -LiteralPath $target -Destination $backup
        if (Test-Path -LiteralPath $marker) { Move-Item -LiteralPath $marker -Destination "$marker.backup.$Stamp" }
        Warn "Existing $target was preserved as $backup"
    }
    if ($Mode -eq 'symlink') {
        try { New-Item -ItemType SymbolicLink -Path $target -Target $source -ErrorAction Stop | Out-Null }
        catch {
            Warn "SymbolicLink unavailable; using directory junction for $Module"
            try { New-Item -ItemType Junction -Path $target -Target $source -ErrorAction Stop | Out-Null }
            catch { $Mode = 'copy'; Copy-Item -LiteralPath $source -Destination $target -Recurse -Force }
        }
    } else { Copy-Item -LiteralPath $source -Destination $target -Recurse -Force; New-Item -ItemType File -Path (Join-Path $target '.mobile-reverse-skill-managed') -Force | Out-Null }
    @{ package='mobile-reverse-skill'; module=$Module; source=$source; mode=$Mode } | ConvertTo-Json -Compress | Set-Content -LiteralPath $marker -Encoding utf8
}
function Check-One([string]$Parent, [string]$Module) {
    $source = Join-Path $Root "skills\$Module"; $target = Join-Path $Parent $Module; $marker = Marker $Parent $Module
    $item = Get-Item -LiteralPath $target -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType -in @('SymbolicLink','Junction')) { Log "OK link $target -> $source" }
    elseif ((Test-Path -LiteralPath $target -PathType Container) -and (Is-Managed $marker $Module)) { Log "OK copy $target" }
    elseif (Test-Path -LiteralPath $target) { Warn "Unmanaged or stale destination: $target" }
    else { Warn "Missing $target" }
}
function Uninstall-One([string]$Parent, [string]$Module) {
    $target = Join-Path $Parent $Module; $marker = Marker $Parent $Module
    if ((Test-Path -LiteralPath $target) -and (Is-Managed $marker $Module)) {
        $removed = "$target.removed.$Stamp"; Move-Item -LiteralPath $target -Destination $removed; Log "Moved managed install to $removed"
    } elseif (Test-Path -LiteralPath $target) { Warn "Skipped unmanaged destination: $target" }
    if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker -Force }
}
$Parents = switch ($Clients) { 'codex' { @($CodexDir) } 'claude' { @($ClaudeDir) } default { @($CodexDir,$ClaudeDir) } }
foreach ($parent in $Parents) {
    if ($Action -in @('setup','update')) { foreach ($module in $Modules) { Install-One $parent $module }; Log "$Action complete for $parent ($Mode)" }
    elseif ($Action -in @('check','status')) { Log "Checking $parent"; foreach ($module in $Modules) { Check-One $parent $module } }
    else { foreach ($module in $Modules) { Uninstall-One $parent $module }; Log "Uninstall complete for $parent" }
}
