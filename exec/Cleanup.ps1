# SPX Cleanup Command Executor
# Handles the 'spx cleanup' command

param (
    [Parameter(ValueFromRemainingArguments = $true)]
    $Args
)

. "$PSScriptRoot/../lib/Parse.ps1"
. "$PSScriptRoot/../modules/Link.ps1"

Write-Debug "[cleanup]: Args: $Args, Count: $($Args.Count)"

# Parse arguments
$parsed = Get-ParsedOptions -Flags @("--dry-run", "--force", "--global", "-g") -Arguments $Args
$opts = $parsed.Options

$dryRun = $opts["--dry-run"]
$force = $opts["--force"]
$global = $opts["--global"] -or $opts["-g"]

Write-Debug "[cleanup]: Dry-run: $dryRun, Force: $force, Global: $global"

# Get stale entries
$stale = Get-StaleLinkEntries
$allStale = $stale.global + $stale.local

if ($allStale.Count -eq 0) {
    Write-Host "No stale entries found. All linked apps are valid."
    return
}

Write-Host "Found $($allStale.Count) stale entry(s):"
Write-Host ""

foreach ($entry in $allStale) {
    $scope = if ($stale.global -contains $entry) { "global" } else { "local" }
    Write-Host "  App: $($entry.AppName) ($scope)"
}

if ($dryRun) {
    Write-Host ""
    Write-Host "[dry-run] Run without --dry-run to unlink all."
    return
}

if (-not $force) {
    Write-Host ""
    $response = Read-Host "Unlink all stale apps? [Y/n]: "
    if ($response -and $response.ToLower() -ne "y") {
        return
    }
}

Write-Host "Unlinking all stale apps..."
foreach ($entry in $allStale) {
    $isGlobal = $stale.global -contains $entry
    try {
        Remove-AppLink -AppName $entry.AppName -Global:$isGlobal
    } catch {
        Write-Warning "Failed to unlink '$($entry.AppName)': $_"
    }
}

Write-Host "Cleanup complete."
