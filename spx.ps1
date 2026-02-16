# SPX - Scoop Power Extensions
# CLI Entry Point

param (
    [Parameter(Position = 0)]
    [string]$Command,
    
    [Parameter(ValueFromRemainingArguments = $true)]
    $RemainingArgs
)

$ErrorActionPreference = "Stop"

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
  backup  Export/import configurations

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
    # Legacy aliases for backward compatibility
    "move"    = "link"
    "mv"      = "link"
    "back"    = "unlink"
    "list"    = "linked"
    "ls"      = "linked"
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
