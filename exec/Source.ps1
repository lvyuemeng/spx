# SPX Source Executor - CLI entry point for source commands
# Handles command-line interface for the source module

param (
    [Parameter(Position = 0)]
    [string]$Action,
    
    [Parameter(ValueFromRemainingArguments = $true)]
    $RemainingArgs
)

$ErrorActionPreference = "Stop"

# Source dependencies
. "$PSScriptRoot\..\context.ps1"
. "$PSScriptRoot\..\lib\Parse.ps1"
. "$PSScriptRoot\..\lib\Core.ps1"
. "$PSScriptRoot\..\modules\Source\Source.ps1"

# Help content for source module
$sourceHelp = @'
SPX Source - Installed App Source Management

Usage:
  spx source list                          List all apps with their sources
  spx source show <app>                    Show detailed source info for app
  spx source change <app> <bucket>         Change app to different bucket
  spx source verify [<app>]                Verify app manifest matches bucket
  spx source diff <app> <bucket>           Compare installed vs bucket manifest

Options:
  --force          Force change even if versions differ
  -h, --help       Show this help

Examples:
  spx source list
  spx source show 7zip
  spx source change 7zip extras
  spx source verify
  spx source diff 7zip main
'@

function Show-SourceHelp {
    Write-Host $sourceHelp
}

function Invoke-SourceList {
    $sources = Get-AppSourceList
    
    if ($sources.Count -eq 0) {
        Write-Host "No apps installed."
        return
    }
    
    Write-Host "Installed Apps:"
    Write-Host "---------------"
    
    $sources | ForEach-Object {
        $globalMark = if ($_["Global"]) { " (global)" } else { "" }
        Write-Host "$($_['AppName'])$globalMark"
        Write-Host "    Bucket: $($_['Bucket'])"
        Write-Host "    Version: $($_['Version'])"
    }
}

function Invoke-SourceShow {
    param (
        [string]$AppName
    )
    
    if (-not $AppName) {
        Write-Error "Usage: spx source show <app>" -ErrorAction Stop
        return
    }
    
    $source = Get-AppSource -AppName $AppName
    
    if (-not $source) {
        Write-Warning "App '$AppName' not found or has no source information."
        return
    }
    
    Write-Host "App: $($source['AppName'])"
    Write-Host "----"
    Write-Host "Bucket: $($source['Bucket'])"
    Write-Host "Version: $($source['Version'])"
    Write-Host "Global: $($source['Global'])"
    Write-Host "Install Path: $($source['InstallPath'])"
    
    if ($source['URL']) {
        Write-Host "URL: $($source['URL'])"
    }
}

function Invoke-SourceChange {
    param (
        [string]$AppName,
        [string]$Bucket,
        [switch]$Force
    )
    
    if (-not $AppName -or -not $Bucket) {
        Write-Error "Usage: spx source change <app> <bucket>" -ErrorAction Stop
        return
    }
    
    Move-AppSource -AppName $AppName -Bucket $Bucket -Force:$Force
}

function Invoke-SourceVerify {
    param (
        [string]$AppName
    )
    
    if ($AppName) {
        # Verify single app
        $isValid = Test-AppSourceValid -AppName $AppName
        
        if ($isValid) {
            Write-Host "[OK] '$AppName' source is valid."
        } else {
            Write-Host "[FAIL] '$AppName' source verification failed."
        }
    } else {
        # Verify all apps
        $sources = Get-AppSourceList
        $valid = 0
        $invalid = 0
        
        foreach ($source in $sources) {
            $appName = $source['AppName']
            $isValid = Test-AppSourceValid -AppName $appName
            
            if ($isValid) {
                Write-Host "[OK] $appName"
                $valid++
            } else {
                Write-Host "[FAIL] $appName"
                $invalid++
            }
        }
        
        Write-Host ""
        Write-Host "Summary: $valid valid, $invalid invalid"
    }
}

function Invoke-SourceDiff {
    param (
        [string]$AppName,
        [string]$Bucket
    )
    
    if (-not $AppName -or -not $Bucket) {
        Write-Error "Usage: spx source diff <app> <bucket>" -ErrorAction Stop
        return
    }
    
    $comparison = Compare-AppManifest -AppName $AppName -Bucket $Bucket
    
    if (-not $comparison) {
        return
    }
    
    Write-Host "Comparison: $AppName"
    Write-Host "-----------"
    Write-Host "Current Bucket: $($comparison['CurrentBucket'])"
    Write-Host "Compare Bucket: $($comparison['CompareBucket'])"
    Write-Host ""
    Write-Host "Installed Version: $($comparison['InstalledVersion'])"
    Write-Host "Bucket Version: $($comparison['BucketVersion'])"
    Write-Host "Version Match: $(if ($comparison['VersionMatch']) { 'Yes' } else { 'No' })"
    
    if ($comparison['Differences'].Count -gt 0) {
        Write-Host ""
        Write-Host "Differences:"
        foreach ($diff in $comparison['Differences']) {
            Write-Host "  [$($diff['Key'])]"
            Write-Host "    Installed: $($diff['Installed'])"
            Write-Host "    Bucket: $($diff['Bucket'])"
        }
    } else {
        Write-Host ""
        Write-Host "No significant differences found."
    }
}

# Parse arguments
$helpFlags = @("-h", "--help", "/?")

# Check for help flag
if ($Action -in $helpFlags -or $RemainingArgs | Where-Object { $_ -in $helpFlags }) {
    Show-SourceHelp
    return
}

# Route to appropriate action
switch ($Action.ToLower()) {
    "list" {
        Invoke-SourceList
    }
    "show" {
        $parsed = Invoke-ParseArguments -Args $RemainingArgs
        Invoke-SourceShow -AppName $parsed['Positional'][0]
    }
    "change" {
        $parsed = Invoke-ParseArguments -Args $RemainingArgs
        Invoke-SourceChange -AppName $parsed['Positional'][0] -Bucket $parsed['Positional'][1] `
            -Force:($parsed.ContainsKey('force'))
    }
    "verify" {
        $parsed = Invoke-ParseArguments -Args $RemainingArgs
        Invoke-SourceVerify -AppName $parsed['Positional'][0]
    }
    "diff" {
        $parsed = Invoke-ParseArguments -Args $RemainingArgs
        Invoke-SourceDiff -AppName $parsed['Positional'][0] -Bucket $parsed['Positional'][1]
    }
    default {
        Show-SourceHelp
    }
}
