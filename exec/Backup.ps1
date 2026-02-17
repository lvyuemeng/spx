# SPX Backup Executor - CLI entry point for backup commands
# Handles command-line interface for the backup module

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
. "$PSScriptRoot\..\modules\Backup\Backup.ps1"

# Help content for backup module
$backupHelp = @'
SPX Backup - Configuration Backup & Restore

Usage:
  spx backup create [path]                 Create backup archive
  spx backup restore <archive>             Restore from backup
  spx backup list                          List available backups
  spx backup status                        Show backup status

Options:
  --include-persist    Include persist data in backup
  --include-cache      Include cache data in backup
  --force              Force restore even if data exists
  -h, --help           Show this help

Examples:
  spx backup create
  spx backup create D:\backups\my-backup.zip
  spx backup restore D:\backups\my-backup.zip
  spx backup list
  spx backup status
'@

function Show-BackupHelp {
    Write-Host $backupHelp
}

function Invoke-BackupCreate {
    param (
        [string]$Path,
        [switch]$IncludePersist,
        [switch]$IncludeCache
    )
    
    $result = New-Backup -Path $Path -IncludePersist:$IncludePersist -IncludeCache:$IncludeCache
    
    if ($result) {
        Write-Host ""
        Write-Host "Backup contents:"
        Write-Host "  - Installed apps list"
        Write-Host "  - Bucket configurations"
        Write-Host "  - Scoop config.json"
        Write-Host "  - SPX configurations (links, mirrors)"
        if ($IncludePersist) {
            Write-Host "  - Persist data"
        }
        if ($IncludeCache) {
            Write-Host "  - Cache data"
        }
    }
}

function Invoke-BackupRestore {
    param (
        [string]$Archive,
        [switch]$Force
    )
    
    if (-not $Archive) {
        Write-Error "Usage: spx backup restore <archive>" -ErrorAction Stop
        return
    }
    
    # Resolve relative path
    if (-not [System.IO.Path]::IsPathRooted($Archive)) {
        $Archive = Join-Path $PWD $Archive
    }
    
    Restore-Backup -Archive $Archive -Force:$Force
}

function Invoke-BackupList {
    $backups = Get-BackupList
    
    if ($backups.Count -eq 0) {
        Write-Host "No backups found."
        $backupDir = Get-BackupDirectory
        Write-Host "Backup directory: $backupDir"
        Write-Host "Use 'spx backup create' to create a backup."
        return
    }
    
    Write-Host "Available Backups:"
    Write-Host "------------------"
    
    foreach ($backup in $backups) {
        $sizeKB = [math]::Round($backup['Size'] / 1KB, 2)
        Write-Host ""
        Write-Host "$($backup['Name'])"
        Write-Host "    Path: $($backup['Path'])"
        Write-Host "    Size: $sizeKB KB"
        Write-Host "    Created: $($backup['Created'])"
        
        if ($backup['AppCount']) {
            Write-Host "    Apps: $($backup['AppCount'])"
        }
    }
}

function Invoke-BackupStatus {
    $status = Get-BackupStatus
    
    Write-Host "Backup Status"
    Write-Host "-------------"
    Write-Host "Backup Directory: $($status['BackupDirectory'])"
    Write-Host "Total Backups: $($status['TotalBackups'])"
    
    if ($status['TotalSize']) {
        $sizeMB = [math]::Round($status['TotalSize'] / 1MB, 2)
        Write-Host "Total Size: $sizeMB MB"
    } else {
        Write-Host "Total Size: 0 MB"
    }
    
    if ($status['LatestBackup']) {
        Write-Host ""
        Write-Host "Latest Backup:"
        $latest = $status['LatestBackup']
        Write-Host "    Name: $($latest['Name'])"
        Write-Host "    Created: $($latest['Created'])"
        if ($latest['AppCount']) {
            Write-Host "    Apps: $($latest['AppCount'])"
        }
    }
}

# Parse arguments
$helpFlags = @("-h", "--help", "/?")

# Check for help flag
if ($Action -in $helpFlags -or $RemainingArgs | Where-Object { $_ -in $helpFlags }) {
    Show-BackupHelp
    return
}

# Route to appropriate action
switch ($Action.ToLower()) {
    "create" {
        $parsed = Invoke-ParseArguments -Args $RemainingArgs
        Invoke-BackupCreate -Path $parsed['Positional'][0] `
            -IncludePersist:($parsed.ContainsKey('include-persist')) `
            -IncludeCache:($parsed.ContainsKey('include-cache'))
    }
    "restore" {
        $parsed = Invoke-ParseArguments -Args $RemainingArgs
        Invoke-BackupRestore -Archive $parsed['Positional'][0] `
            -Force:($parsed.ContainsKey('force'))
    }
    "list" {
        Invoke-BackupList
    }
    "status" {
        Invoke-BackupStatus
    }
    default {
        Show-BackupHelp
    }
}
