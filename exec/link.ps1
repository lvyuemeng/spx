# SPX Link Command Executor
# Handles the 'spx link' command

param (
    [Parameter(ValueFromRemainingArguments = $true)]
    $Args
)

. "$PSScriptRoot/../lib/Parse.ps1"
. "$PSScriptRoot/../modules/Link.ps1"

Write-Debug "[link]: Args: $Args, Count: $($Args.Count)"

# Parse arguments
$parsed = Get-ParsedOptions -Flags @("--path", "--to", "--global", "-g") -Arguments $Args
$pkgs = $parsed.Packages
$opts = $parsed.Options

$global = $opts["--global"] -or $opts["-g"]
$path = if ($opts["--path"]) { $opts["--path"] } elseif ($opts["--to"]) { $opts["--to"] } else { $null }

Write-Debug "[link]: Packages: $pkgs"
Write-Debug "[link]: Path: $path"
Write-Debug "[link]: Global: $global"

# Validate required arguments
if ($pkgs.Count -eq 0) {
    Write-Host "Usage: spx link <app> --path <path>"
    Write-Host "Use 'spx link --help' for more information."
    exit 0
}

if (-not $path) {
    Write-Error "Missing required parameter: --path or --to"
    Write-Host "Usage: spx link <app> --path <path>"
    exit 1
}

# Execute link for each package
foreach ($pkg in $pkgs) {
    New-AppLink -AppName $pkg -Path $path -Global:$global
}
