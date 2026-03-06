# SPX Unlink Command Executor
# Handles the 'spx unlink' command

param (
    [Parameter(ValueFromRemainingArguments = $true)]
    $Args
)

. "$PSScriptRoot/../lib/Parse.ps1"
. "$PSScriptRoot/../modules/Link.ps1"

Write-Debug "[unlink]: Args: $Args, Count: $($Args.Count)"

# Parse arguments
$parsed = Get-ParsedOptions -Flags @("--global", "-g") -Arguments $Args
$pkgs = $parsed.Packages
$opts = $parsed.Options

$global = $opts["--global"] -or $opts["-g"]

Write-Debug "[unlink]: Packages: $pkgs"
Write-Debug "[unlink]: Global: $global"

# Validate required arguments
if ($pkgs.Count -eq 0) {
    Write-Host "Usage: spx unlink <app>"
    Write-Host "Use 'spx link --help' for more information."
    exit 0
}

# Execute unlink for each package
foreach ($pkg in $pkgs) {
    Remove-AppLink -AppName $pkg -Global:$global
}
