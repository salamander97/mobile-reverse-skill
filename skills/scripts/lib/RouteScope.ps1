# Bộ phân tích dùng chung cho route-scope.md của master-route.
# Neo theo đầu dòng để hint chứa "primary: R11" không thể chiếm PRIMARY thật.
function Get-ReverseRouteScopeFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )
    $id = $null
    $skill = $null
    $idHits = [regex]::Matches($Text, '(?m)^- primary:\s*(\S+)\s*$')
    if ($idHits.Count -gt 0) { $id = $idHits[$idHits.Count - 1].Groups[1].Value }
    $skillHits = [regex]::Matches($Text, '(?m)^- primary_skill:\s*skills/(\S+)\s*$')
    if ($skillHits.Count -gt 0) { $skill = $skillHits[$skillHits.Count - 1].Groups[1].Value }
    return [pscustomobject]@{
        Id    = $id
        Skill = $skill
    }
}
