param(
    [string]$LogPath = "maps/EntryMap/script/.log/lua_player01.log"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $LogPath)) {
    Write-Output "N0 parse: log file not found: $LogPath"
    exit 1
}

$lines = Get-Content -LiteralPath $LogPath
if (-not $lines -or $lines.Count -eq 0) {
    Write-Output "N0 parse: log is empty: $LogPath"
    exit 1
}

$startRegex = '\[auto_acceptance\].*pass=(?<pass>\d+)\/(?<total>\d+)\s+fail=(?<fail>\d+).*ok=(?<ok>\d+)\s+fail=(?<afail>\d+)'
$spawnRegex = '\[auto_acceptance\].*count=(?<count>\d+)\s+unit_id=(?<uid>[^\s]+)\s+hp=(?<hp>\d+)'

$startIdx = -1
for ($i = $lines.Count - 1; $i -ge 0; $i--) {
    if ($lines[$i] -match $startRegex) {
        $startIdx = $i
        break
    }
}

if ($startIdx -lt 0) {
    Write-Output "N0 parse: no acceptance start marker found."
    exit 2
}

$endIdx = $lines.Count - 1
for ($i = $startIdx + 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match $startRegex) {
        $endIdx = $i - 1
        break
    }
}

$block = $lines[$startIdx..$endIdx]
$startLine = $lines[$startIdx]

$timestamp = ""
if ($startLine -match '^\[(?<ts>[^\]]+)\]') {
    $timestamp = $Matches["ts"]
}

$selfPass = $null
$selfTotal = $null
$selfFail = $null
$activeOk = $null
$activeFail = $null
$dummyCount = $null
$dummyUnitId = $null
$dummyHp = $null
$skillAudit = @()
$currentAuditSegment = $null
$latestAuditSegment = @()
$auditSummaryPass = $null
$auditSummaryFail = $null

if ($startLine -match $startRegex) {
    $selfPass = [int]$Matches["pass"]
    $selfTotal = [int]$Matches["total"]
    $selfFail = [int]$Matches["fail"]
    $activeOk = [int]$Matches["ok"]
    $activeFail = [int]$Matches["afail"]
}

foreach ($line in $block) {
    if ($line -match $spawnRegex) {
        $dummyCount = [int]$Matches["count"]
        $dummyUnitId = $Matches["uid"]
        $dummyHp = $Matches["hp"]
    }
    if ($line -match '\[auto_acceptance\]\[SKILL_AUDIT_BEGIN\]') {
        $currentAuditSegment = @()
        continue
    }
    if ($line -match '\[auto_acceptance\]\[SKILL_AUDIT_END\]') {
        if ($null -ne $currentAuditSegment -and $currentAuditSegment.Count -gt 0) {
            $latestAuditSegment = $currentAuditSegment
        }
        $currentAuditSegment = $null
        continue
    }
    if ($line -match '\[auto_acceptance\]\[SKILL_AUDIT\]\s*scope=(?<scope>[^\s]+)\s+key=(?<key>[^\s]+)\s+cast=(?<cast>\d+)\s+hit=(?<hit>\d+)\s+dmg=(?<dmg>[0-9\.]+)\s+dps=(?<dps>[0-9\.]+)') {
        $row = [PSCustomObject]@{
            scope = $Matches["scope"]
            key = $Matches["key"]
            cast = [int]$Matches["cast"]
            hit = [int]$Matches["hit"]
            dmg = [double]$Matches["dmg"]
            dps = [double]$Matches["dps"]
        }
        $skillAudit += $row
        if ($null -ne $currentAuditSegment) {
            $currentAuditSegment += $row
        }
        continue
    }
    if ($line -match '\[auto_acceptance\]\[SKILL_AUDIT_SUMMARY\]\s*pass=(?<pass>\d+)\s+fail=(?<fail>\d+)') {
        $auditSummaryPass = [int]$Matches["pass"]
        $auditSummaryFail = [int]$Matches["fail"]
        continue
    }
}

if ($latestAuditSegment.Count -gt 0) {
    $skillAudit = $latestAuditSegment
}

$fails = @()
foreach ($line in $block) {
    if ($line -match '\[bond_test\]\[FAIL\]') { $fails += $line }
    if ($line -match '\[auto_acceptance\]\[FAIL\]') { $fails += $line }
}

$status = "PASS"
if (($selfFail -as [int]) -gt 0 -or ($activeFail -as [int]) -gt 0) {
    $status = "FAIL"
}
if ($null -eq $dummyCount -or $dummyCount -le 0) {
    $status = "FAIL"
    $fails += "dummy spawn success line not found"
}
if ($null -ne $auditSummaryFail) {
    if ($auditSummaryFail -gt 0) {
        $status = "FAIL"
    }
}
elseif ($skillAudit.Count -le 0) {
    $status = "FAIL"
    $fails += "no skill audit lines in this run"
}

Write-Output "N0 Result: $status"
if ($timestamp -ne "") { Write-Output "Time: $timestamp" }
Write-Output "Log: $LogPath"
if ($null -ne $selfPass) { Write-Output ("SelfTest: pass={0}/{1} fail={2}" -f $selfPass, $selfTotal, $selfFail) }
if ($null -ne $activeOk) { Write-Output ("BondActivation: ok={0} fail={1}" -f $activeOk, $activeFail) }
if ($null -ne $dummyCount) { Write-Output ("Dummy: count={0} unit_id={1} hp={2}" -f $dummyCount, $dummyUnitId, $dummyHp) }
if ($null -ne $auditSummaryFail) { Write-Output ("SkillAuditSummary: pass={0} fail={1}" -f $auditSummaryPass, $auditSummaryFail) }

if ($skillAudit.Count -gt 0) {
    Write-Output "SkillAuditTop:"
    $skillAudit |
        Sort-Object -Property dmg -Descending |
        Select-Object -First 8 |
        ForEach-Object {
            Write-Output ("- {0}/{1}: cast={2} hit={3} dmg={4} dps={5}" -f $_.scope, $_.key, $_.cast, $_.hit, [math]::Round($_.dmg, 0), [math]::Round($_.dps, 1))
        }

    $bondRows = @($skillAudit | Where-Object { $_.scope -eq 'bond' })
    if ($bondRows.Count -gt 0) {
        Write-Output "BondAuditTop:"
        $bondRows |
            Sort-Object -Property dmg -Descending |
            Select-Object -First 8 |
            ForEach-Object {
                Write-Output ("- {0}: cast={1} hit={2} dmg={3} dps={4}" -f $_.key, $_.cast, $_.hit, [math]::Round($_.dmg, 0), [math]::Round($_.dps, 1))
            }
    }
}
else {
    Write-Output "SkillAuditTop: no skill audit lines in this run yet."
}

$fails = @($fails)
if (@($fails).Count -gt 0) {
    if ($null -ne $auditSummaryFail -and $auditSummaryFail -eq 0) {
        $fails = @($fails | Where-Object { $_ -notmatch '\[auto_acceptance\]\[FAIL\]\[SKILL\]' })
    }
}

if (@($fails).Count -gt 0) {
    Write-Output "FailDetails:"
    $fails | Select-Object -Unique | ForEach-Object { Write-Output $_ }
}

if ($status -ne "PASS") {
    exit 3
}
