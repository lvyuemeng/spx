# SPX Sync Command Executor
# Handles the 'spx sync' command - syncs linked app states

param (
    [Parameter(ValueFromRemainingArguments = $true)]
    $Args
)

. "$PSScriptRoot/../lib/Parse.ps1"
. "$PSScriptRoot/../modules/Link.ps1"

Write-Debug "[sync]: Args: $Args, Count: $($Args.Count)"

# Parse arguments
$parsed = Get-ParsedOptions -Flags @("--global", "-g") -Arguments $Args
$pkgs = $parsed.Packages
$opts = $parsed.Options

$global = $opts["--global"] -or $opts["-g"]

Write-Debug "[sync]: Packages: $pkgs"
Write-Debug "[sync]: Global: $global"

# If no packages specified, sync all linked apps
if ($pkgs.Count -eq 0) {
    Write-Host "Syncing all linked apps..."
    Invoke-AppSync -Global:$global
} else {
    # Sync specified packages
    foreach ($pkg in $pkgs) {
        Invoke-AppSync -AppName $pkg -Global:$global
    }
}
