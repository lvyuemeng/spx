# SPX Backup Module - Configuration Backup & Restore
# Provides functions for exporting and importing Scoop configuration

. "$PSScriptRoot\..\..\context.ps1"
. "$PSScriptRoot\..\..\lib\Core.ps1"

<#
.SYNOPSIS
    Gets the backup directory path.

.DESCRIPTION
    Returns the path where backups are stored.

.OUTPUTS
    String path to backup directory.
#>
function Get-BackupDirectory {
    [CmdletBinding()]
    [OutputType([string])]
    param ()
    
    $spxPath = Get-SpxConfigPath
    $backupPath = Join-Path $spxPath "backups"
    
    if (-not (Test-Path $backupPath)) {
        New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
    }
    
    return $backupPath
}

<#
.SYNOPSIS
    Creates a new backup archive.

.DESCRIPTION
    Creates a backup archive containing installed apps, buckets, and configurations.

.PARAMETER Path
    Optional custom path for the backup file. If not specified, uses default location.

.PARAMETER IncludePersist
    Include persist data in the backup.

.PARAMETER IncludeCache
    Include cache data in the backup.

.OUTPUTS
    String path to the created backup file.

.EXAMPLE
    New-Backup -Path "D:\backups\scoop-backup.zip"
#>
function New-Backup {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [string]$Path,
        
        [switch]$IncludePersist,
        
        [switch]$IncludeCache
    )
    
    $scoop = Get-ScoopContext
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    
    # Determine backup path
    if (-not $Path) {
        $backupDir = Get-BackupDirectory
        $Path = Join-Path $backupDir "scoop-backup-$timestamp.zip"
    }
    
    # Ensure parent directory exists
    $parentDir = Split-Path $Path -Parent
    if ($parentDir -and -not (Test-Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }
    
    Write-Host "[backup]: Creating backup..."
    
    # Collect backup data
    $backupData = @{
        "version" = "1.0.0"
        "created" = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
        "scoop"   = Get-ScoopBackupData -IncludePersist:$IncludePersist -IncludeCache:$IncludeCache
        "spx"     = Get-SpxBackupData
    }
    
    # Write backup file
    $tempDir = Join-Path $env:TEMP "spx-backup-$timestamp"
    try {
        # Create temp directory
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        
        # Write JSON manifest
        $manifestPath = Join-Path $tempDir "backup.json"
        $backupData | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding UTF8
        
        # Create ZIP archive
        if (Test-Path $Path) {
            Remove-Item $Path -Force
        }
        
        Compress-Archive -Path "$tempDir\*" -DestinationPath $Path -CompressionLevel Optimal
        
        Write-Host "[backup]: Backup created at '$Path'"
        return $Path
    } finally {
        # Cleanup temp directory
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

<#
.SYNOPSIS
    Restores from a backup archive.

.DESCRIPTION
    Restores Scoop configuration from a backup archive.

.PARAMETER Archive
    Path to the backup archive.

.PARAMETER Force
    Force restore even if data exists.

.EXAMPLE
    Restore-Backup -Archive "D:\backups\scoop-backup.zip"
#>
function Restore-Backup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Archive,
        
        [switch]$Force
    )
    
    if (-not (Test-Path $Archive)) {
        Write-Error "Backup archive not found: $Archive" -ErrorAction Stop
        return
    }
    
    Write-Host "[backup]: Restoring from '$Archive'..."
    
    $tempDir = Join-Path $env:TEMP "spx-restore-$(Get-Date -Format 'yyyyMMddHHmmss')"
    
    try {
        # Extract archive
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        Expand-Archive -Path $Archive -DestinationPath $tempDir -Force
        
        # Read manifest
        $manifestPath = Join-Path $tempDir "backup.json"
        if (-not (Test-Path $manifestPath)) {
            Write-Error "Invalid backup archive: missing backup.json" -ErrorAction Stop
            return
        }
        
        $backupData = Get-Content $manifestPath -Raw | ConvertFrom-Json -AsHashtable
        
        Write-Host "[backup]: Backup version: $($backupData['version'])"
        Write-Host "[backup]: Created: $($backupData['created'])"
        
        # Restore SPX data
        if ($backupData['spx']) {
            Restore-SpxBackupData -Data $backupData['spx'] -Force:$Force
        }
        
        # Restore Scoop data
        if ($backupData['scoop']) {
            Restore-ScoopBackupData -Data $backupData['scoop'] -Force:$Force
        }
        
        Write-Host "[backup]: Restore completed."
    } finally {
        # Cleanup temp directory
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

<#
.SYNOPSIS
    Lists available backups.

.DESCRIPTION
    Returns a list of backup files in the default backup directory.

.OUTPUTS
    Array of backup file information.

.EXAMPLE
    Get-BackupList
#>
function Get-BackupList {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable[]])]
    param ()
    
    $backupDir = Get-BackupDirectory
    $backups = @()
    
    if (-not (Test-Path $backupDir)) {
        return $backups
    }
    
    $files = Get-ChildItem $backupDir -Filter "*.zip" | Sort-Object LastWriteTime -Descending
    
    foreach ($file in $files) {
        $backupInfo = @{
            "Name"     = $file.Name
            "Path"     = $file.FullName
            "Size"     = $file.Length
            "Created"  = $file.LastWriteTime
        }
        
        # Try to read backup info
        try {
            $tempDir = Join-Path $env:TEMP "spx-info-$(Get-Random)"
            Expand-Archive -Path $file.FullName -DestinationPath $tempDir -Force
            $manifestPath = Join-Path $tempDir "backup.json"
            
            if (Test-Path $manifestPath) {
                $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -AsHashtable
                $backupInfo["Version"] = $manifest["version"]
                $backupInfo["BackupDate"] = $manifest["created"]
                $backupInfo["AppCount"] = $manifest["scoop"]["apps"].Count
            }
            
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            # Ignore errors reading backup info
        }
        
        $backups += $backupInfo
    }
    
    return $backups
}

<#
.SYNOPSIS
    Gets backup status.

.DESCRIPTION
    Returns information about the backup system status.

.OUTPUTS
    Hashtable with backup status.

.EXAMPLE
    Get-BackupStatus
#>
function Get-BackupStatus {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param ()
    
    $backupDir = Get-BackupDirectory
    $backups = Get-BackupList
    
    $totalSize = ($backups | Measure-Object -Property Size -Sum).Sum
    
    $result = @{
        "BackupDirectory" = $backupDir
        "TotalBackups"    = $backups.Count
        "TotalSize"       = $totalSize
        "LatestBackup"    = $null
    }
    
    if ($backups.Count -gt 0) {
        $result["LatestBackup"] = $backups[0]
    }
    
    return $result
}

<#
.SYNOPSIS
    Gets Scoop data for backup.

.DESCRIPTION
    Collects Scoop configuration data for backup.

.OUTPUTS
    Hashtable with Scoop data.
#>
function Get-ScoopBackupData {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [switch]$IncludePersist,
        
        [switch]$IncludeCache
    )
    
    $scoop = Get-ScoopContext
    
    $data = @{
        "apps"    = @()
        "buckets" = @{}
        "config"  = $null
    }
    
    # Get installed apps
    $appsPath = Join-Path $scoop "apps"
    if (Test-Path $appsPath) {
        $apps = Get-ChildItem $appsPath -Directory | Where-Object { $_.Name -ne "scoop" }
        
        foreach ($app in $apps) {
            $currentDir = Join-Path $app.FullName "current"
            $installFile = Join-Path $currentDir "install.json"
            
            if (Test-Path $installFile) {
                try {
                    $installInfo = Get-Content $installFile -Raw | ConvertFrom-Json -AsHashtable
                    $data["apps"] += @{
                        "name"    = $app.Name
                        "version" = $installInfo["version"]
                        "bucket"  = $installInfo["bucket"]
                        "global"  = $false
                    }
                } catch {
                    $data["apps"] += @{
                        "name"    = $app.Name
                        "version" = "unknown"
                        "bucket"  = "unknown"
                        "global"  = $false
                    }
                }
            }
        }
    }
    
    # Get global apps
    $globalAppsPath = $Script:ScoopSubs["global"]
    if (Test-Path $globalAppsPath) {
        $apps = Get-ChildItem $globalAppsPath -Directory | Where-Object { $_.Name -ne "scoop" }
        
        foreach ($app in $apps) {
            $currentDir = Join-Path $app.FullName "current"
            $installFile = Join-Path $currentDir "install.json"
            
            if (Test-Path $installFile) {
                try {
                    $installInfo = Get-Content $installFile -Raw | ConvertFrom-Json -AsHashtable
                    $data["apps"] += @{
                        "name"    = $app.Name
                        "version" = $installInfo["version"]
                        "bucket"  = $installInfo["bucket"]
                        "global"  = $true
                    }
                } catch {
                    $data["apps"] += @{
                        "name"    = $app.Name
                        "version" = "unknown"
                        "bucket"  = "unknown"
                        "global"  = $true
                    }
                }
            }
        }
    }
    
    # Get buckets
    $bucketsPath = Join-Path $scoop "buckets"
    if (Test-Path $bucketsPath) {
        $buckets = Get-ChildItem $bucketsPath -Directory
        
        foreach ($bucket in $buckets) {
            $bucketFile = Join-Path $bucket.FullName ".git\config"
            $bucketUrl = $null
            
            if (Test-Path $bucketFile) {
                try {
                    $gitConfig = Get-Content $bucketFile -Raw
                    if ($gitConfig -match 'url\s*=\s*(.+)') {
                        $bucketUrl = $Matches[1].Trim()
                    }
                } catch {
                    # Ignore
                }
            }
            
            $data["buckets"][$bucket.Name] = $bucketUrl
        }
    }
    
    # Get Scoop config
    $configFile = Join-Path $scoop "config.json"
    if (Test-Path $configFile) {
        try {
            $data["config"] = Get-Content $configFile -Raw | ConvertFrom-Json -AsHashtable
        } catch {
            $data["config"] = @{}
        }
    }
    
    return $data
}

<#
.SYNOPSIS
    Gets SPX data for backup.

.DESCRIPTION
    Collects SPX configuration data for backup.

.OUTPUTS
    Hashtable with SPX data.
#>
function Get-SpxBackupData {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param ()
    
    $spxPath = Get-SpxConfigPath
    
    $data = @{
        "links"   = @{}
        "mirrors" = @{}
    }
    
    # Get links config
    $linksFile = Join-Path $spxPath "links.json"
    if (Test-Path $linksFile) {
        try {
            $data["links"] = Get-Content $linksFile -Raw | ConvertFrom-Json -AsHashtable
        } catch {
            $data["links"] = @{}
        }
    }
    
    # Get mirrors config
    $mirrorsFile = Join-Path $spxPath "mirrors.json"
    if (Test-Path $mirrorsFile) {
        try {
            $data["mirrors"] = Get-Content $mirrorsFile -Raw | ConvertFrom-Json -AsHashtable
        } catch {
            $data["mirrors"] = @{}
        }
    }
    
    return $data
}

<#
.SYNOPSIS
    Restores SPX data from backup.

.DESCRIPTION
    Restores SPX configuration from backup data.

.PARAMETER Data
    The backup data to restore.

.PARAMETER Force
    Force overwrite existing data.
#>
function Restore-SpxBackupData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]$Data,
        
        [switch]$Force
    )
    
    $spxPath = Get-SpxConfigPath
    
    # Restore links
    if ($Data["links"]) {
        $linksFile = Join-Path $spxPath "links.json"
        if (-not (Test-Path $linksFile) -or $Force) {
            $Data["links"] | ConvertTo-Json -Depth 5 | Set-Content $linksFile -Encoding UTF8
            Write-Host "[backup]: Restored links configuration"
        } else {
            Write-Warning "Links config exists. Use -Force to overwrite."
        }
    }
    
    # Restore mirrors
    if ($Data["mirrors"]) {
        $mirrorsFile = Join-Path $spxPath "mirrors.json"
        if (-not (Test-Path $mirrorsFile) -or $Force) {
            $Data["mirrors"] | ConvertTo-Json -Depth 5 | Set-Content $mirrorsFile -Encoding UTF8
            Write-Host "[backup]: Restored mirrors configuration"
        } else {
            Write-Warning "Mirrors config exists. Use -Force to overwrite."
        }
    }
}

<#
.SYNOPSIS
    Restores Scoop data from backup.

.DESCRIPTION
    Restores Scoop configuration from backup data.

.PARAMETER Data
    The backup data to restore.

.PARAMETER Force
    Force overwrite existing data.
#>
function Restore-ScoopBackupData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]$Data,
        
        [switch]$Force
    )
    
    $scoop = Get-ScoopContext
    
    # Restore buckets
    if ($Data["buckets"]) {
        Write-Host "[backup]: Restoring buckets..."
        
        foreach ($bucket in $Data["buckets"].Keys) {
            $url = $Data["buckets"][$bucket]
            $bucketPath = Join-Path $scoop "buckets/$bucket"
            
            if (Test-Path $bucketPath) {
                Write-Host "[backup]: Bucket '$bucket' already exists"
                continue
            }
            
            if ($url) {
                Write-Host "[backup]: Adding bucket '$bucket' from $url"
                & scoop bucket add $bucket $url
            } else {
                Write-Host "[backup]: Adding bucket '$bucket'"
                & scoop bucket add $bucket
            }
        }
    }
    
    # Restore config
    if ($Data["config"]) {
        $configFile = Join-Path $scoop "config.json"
        if (-not (Test-Path $configFile) -or $Force) {
            $Data["config"] | ConvertTo-Json -Depth 5 | Set-Content $configFile -Encoding UTF8
            Write-Host "[backup]: Restored Scoop configuration"
        } else {
            Write-Warning "Scoop config exists. Use -Force to overwrite."
        }
    }
    
    # Note: Apps are not automatically reinstalled
    # User should run 'spx backup restore' then manually install apps
    if ($Data["apps"] -and $Data["apps"].Count -gt 0) {
        Write-Host ""
        Write-Host "[backup]: Apps to reinstall ($($Data['apps'].Count)):"
        foreach ($app in $Data["apps"]) {
            $globalFlag = if ($app["global"]) { " --global" } else { "" }
            Write-Host "  scoop install $($app['name'])$globalFlag"
        }
    }
}
