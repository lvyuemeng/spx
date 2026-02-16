# SPX Linked Command Executor
# Handles the 'spx linked' command - lists all linked apps

param (
    [Parameter(ValueFromRemainingArguments = $true)]
    $Args
)

. "$PSScriptRoot/../lib/Parse.ps1"
. "$PSScriptRoot/../lib/Config.ps1"
. "$PSScriptRoot/../context.ps1"

Write-Debug "[linked]: Args: $Args, Count: $($Args.Count)"

# Parse arguments
$parsed = Get-ParsedOptions -Flags @("--global", "-g") -Arguments $Args
$opts = $parsed.Options

$global = $opts["--global"] -or $opts["-g"]

Write-Debug "[linked]: Global: $global"

# Get linked apps from config
$config = Get-LinksConfig

# Display local linked apps
if (-not $global) {
    $localApps = $config["local"]
    if ($localApps.Count -gt 0) {
        Write-Host "Local linked apps:"
        $localApps.GetEnumerator() | ForEach-Object {
            $appName = $_.Key
            $info = $_.Value
            Write-Host "  $appName -> $($info.Path) (v$($info.Version))"
        }
    } else {
        Write-Host "No local linked apps."
    }
}

# Display global linked apps
if ($global -or -not $global) {
    $globalApps = $config["global"]
    if ($globalApps.Count -gt 0) {
        Write-Host "`nGlobal linked apps:"
        $globalApps.GetEnumerator() | ForEach-Object {
            $appName = $_.Key
            $info = $_.Value
            Write-Host "  $appName -> $($info.Path) (v$($info.Version))"
        }
    } elseif ($global) {
        Write-Host "No global linked apps."
    }
}
