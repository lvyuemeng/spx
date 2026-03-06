# SPX - Scoop Power Extensions
# CLI Entry Point

param (
    [Parameter(Position = 0)]
    [string]$Command,
    
    [Parameter(ValueFromRemainingArguments = $true)]
    $RemainingArgs
)

$ErrorActionPreference = "Stop"

# Handle debug flag early
if ($RemainingArgs -contains "-d" -or $RemainingArgs -contains "--debug" -or $RemainingArgs -contains "-Debug") {
    $DebugPreference = "Continue"
    $RemainingArgs = $RemainingArgs | Where-Object { $_ -notin @("-d", "--debug", "-Debug") }
}

# Source dependencies
. "$PSScriptRoot/context.ps1"
. "$PSScriptRoot/lib/Parse.ps1"
. "$PSScriptRoot/lib/Core.ps1"

# Help system
$helpContent = @{
    main = @'
SPX - Scoop Power Extensions

Usage: spx <module> <action> [options]

Modules:
  link    Relocate apps to custom paths via symbolic links
  mirror  Configure alternative download mirrors
  source  Manage app bucket sources

Global Options:
  -h, --help       Show help
  -v, --verbose    Enable verbose output
  -d, --debug      Enable debug output
  --global         Operate on global apps
  --yes            Skip confirmation prompts

Run "spx <module> -h" for module-specific help.
'@
    
    link = @'
SPX Link - Custom Path Management

Usage:
  spx link <app> --path <path>    Move app to custom path
  spx link <app> --to <path>      Move app to custom path (alias)
  spx unlink <app>                Restore app to Scoop directory
  spx linked                      List all linked apps
  spx sync [<app>]                Sync linked app states

Options:
  --path, --to    Target path for the app (required for link)
  --global        Operate on global apps
  -h, --help      Show this help

Examples:
  spx link 7zip --path D:\MyPortableApps
  spx unlink 7zip
  spx linked
'@
    
    mirror = @'
SPX Mirror - Bucket URL Replacement

Usage:
  spx mirror list                    List all bucket mirrors
  spx mirror add <bucket> <url>      Add a mirror for a bucket
  spx mirror remove <bucket>         Remove a bucket mirror
  spx mirror set <bucket> <url>     Set/change mirror URL for a bucket

Options:
  -h, --help      Show this help

Examples:
  spx mirror list
  spx mirror add main https://mirror.example.com/scoop
  spx mirror set main https://new-mirror.com/scoop
  spx mirror remove main
'@
    
    source = @'
SPX Source - Bucket Source Management

Usage:
  spx source list                         List all bucket sources
  spx source show <app>                   Show source for an app
  spx source change <app> <bucket>        Change source for an app
  spx source verify <app>                 Verify source for an app
  spx source diff <app> <bucket>           Show source difference
  spx source add <bucket> [url]           Add a new bucket
  spx source remove <bucket>              Remove a bucket

Options:
  -h, --help      Show this help

Examples:
  spx source list
  spx source show 7zip
  spx source change 7zip main
'@
}

function Show-Help {
    param (
        [string]$Context = "main"
    )
    
    $help = $helpContent[$Context]
    if (-not $help) {
        Write-Warning "No help found for '$Context'."
        $help = $helpContent["main"]
    }
    Write-Host $help
}

# Command routing
$commandMap = @{
    "link"    = "link"
    "unlink"  = "unlink"
    "linked"  = "linked"
    "sync"    = "sync"
    "cleanup" = "cleanup"
    "mirror"  = "mirror"
    "source"  = "source"
}

$helpFlags = @("-h", "--help", "/?")

# Main entry logic
function Invoke-Main {
    param (
        [string]$Command,
        $RemainingArgs
    )
    
    Write-Debug "[spx]: Command: $Command"
    Write-Debug "[spx]: Args: $($RemainingArgs -join ' ')"
    
    # Show main help if no command or help flag
    if (-not $Command -or $Command -in $helpFlags) {
        Show-Help
        return
    }
    
    # Normalize command
    $normalized = $commandMap[$Command.ToLower()]
    Write-Debug "[spx]: Normalized: $normalized"
    
    if (-not $normalized) {
        # Fallback to scoop for unknown commands
        & scoop $Command @RemainingArgs
        return
    }
    
    # Check for help flag in remaining args
    if ($RemainingArgs | Where-Object { $_ -in $helpFlags }) {
        Show-Help -Context $normalized
        return
    }
    
    # Execute module
    $execPath = "$PSScriptRoot/exec/$normalized.ps1"
    if (-not (Test-Path $execPath)) {
        Write-Error "Module executor not found: $execPath" -ErrorAction Stop
    }
    
    Write-Debug "[spx]: Executing: $execPath"
    & $execPath @RemainingArgs
}

Invoke-Main -Command $Command -RemainingArgs $RemainingArgs
