# SPX Link Module - Custom Path Management
# Provides functions for relocating installed packages to custom paths via symbolic links
# This file includes functions from the former Move module

. "$PSScriptRoot\..\context.ps1"
. "$PSScriptRoot\Core.ps1"
. "$PSScriptRoot\Config.ps1"


<#
.SYNOPSIS
    Creates a new link for an app, moving it to a custom path.

.DESCRIPTION
    The New-AppLink function moves an installed Scoop application to a custom
    path and creates a symbolic link from the original location.

.PARAMETER AppName
    The name of the application to link.

.PARAMETER Path
    The target path where the application will be moved.

.PARAMETER Global
    Operate on globally installed apps.

.EXAMPLE
    New-AppLink -AppName "7zip" -Path "D:\MyPortableApps"
#>
function New-AppLink {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [switch]$Global
    )
    
    # Check admin rights for global apps
    if ($Global -and -not (Test-Administrator)) {
        Write-Error "Moving global apps requires administrator privileges." -ErrorAction Stop
        return
    }
    
    # Verify app is installed
    if (-not (Test-AppInstalled $AppName -Global:$Global)) {
        Write-Warning "App '$AppName' is not installed."
        return
    }
    
    # Get installed versions
    $versions = Get-AppVersions $AppName -Global:$Global
    if ($versions.Count -eq 0) {
        Write-Warning "App '$AppName' has no installed versions."
        return
    }
    
    # Resolve and validate target path
    $targetPath = Resolve-TargetPath $Path
    if (-not $targetPath) {
        return
    }
    
    # Create target app directory
    $targetAppDir = Join-Path $targetPath $AppName
    if (-not (Test-Path $targetAppDir)) {
        New-Item -Path $targetAppDir -ItemType Directory -Force | Out-Null
    }
    
    try {
        # Move each version
        foreach ($version in $versions) {
            $sourceDir = Resolve-SymlinkTarget $version
            $targetVersionDir = Join-Path $targetAppDir $version.Name
            
            if ($sourceDir -eq $targetVersionDir) {
                Write-Host "[link]: $version is already at target location"
                continue
            }
            
            Write-Debug "[link]: Moving $sourceDir -> $targetVersionDir"
            Invoke-RobocopyMove -Source $sourceDir -Destination $targetVersionDir
            
            # Create symlink from original location
            New-Item -ItemType SymbolicLink -Path $version.FullName -Target $targetVersionDir -Force | Out-Null
        }
        
        # Update persist links
        $currentVersion = Get-AppCurrentVersion $AppName -Global:$Global
        if ($currentVersion) {
            Update-PersistLinks -AppName $AppName -Global:$Global
        }
        
        # Record in config
        New-AppLinkEntry -AppName $AppName -Path $targetPath -Version $currentVersion.Name -Global:$Global
        
        Write-Host "[link]: Successfully linked '$AppName' to '$targetPath'"
    } catch {
        Write-Error "Failed to link '$AppName': $_"
        Write-Host "You may need to reinstall the app: scoop uninstall $AppName; scoop install $AppName"
    }
}

<#
.SYNOPSIS
    Removes a link and restores the app to the Scoop directory.

.DESCRIPTION
    The Remove-AppLink function moves an app back to its original Scoop
    installation directory and removes the symbolic link.

.PARAMETER AppName
    The name of the application to unlink.

.PARAMETER Global
    Operate on globally installed apps.

.EXAMPLE
    Remove-AppLink -AppName "7zip"
#>
function Remove-AppLink {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$AppName,
        
        [switch]$Global
    )
    
    # Check admin rights for global apps
    if ($Global -and -not (Test-Administrator)) {
        Write-Error "Moving global apps requires administrator privileges." -ErrorAction Stop
        return
    }
    
    # Verify app is installed
    if (-not (Test-AppInstalled $AppName -Global:$Global)) {
        Write-Warning "App '$AppName' is not installed."
        return
    }
    
    # Get installed versions
    $versions = Get-AppVersions $AppName -Global:$Global
    if ($versions.Count -eq 0) {
        Write-Warning "App '$AppName' has no installed versions."
        return
    }
    
    try {
        # Move each version back
        foreach ($version in $versions) {
            $sourceDir = Resolve-SymlinkTarget $version
            $targetVersionDir = $version.FullName
            
            if ($sourceDir -eq $targetVersionDir) {
                Write-Host "[unlink]: $sourceDir is already in Scoop directory"
                continue
            }
            
            # Remove the symlink first
            if ($version.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                Remove-Item $version.FullName -Force -ErrorAction SilentlyContinue
            }
            
            Write-Debug "[unlink]: Moving $sourceDir -> $targetVersionDir"
            Invoke-RobocopyMove -Source $sourceDir -Destination $targetVersionDir
        }
        
        # Update persist links
        Get-AppCurrentVersion $AppName -Global:$Global | Out-Null
        
        # Remove from config
        Remove-AppLinkEntry -AppName $AppName -Global:$Global
        
        Write-Host "[unlink]: Successfully unlinked '$AppName'"
    } catch {
        Write-Error "Failed to unlink '$AppName': $_"
        Write-Host "You may need to reinstall the app: scoop uninstall $AppName; scoop install $AppName"
    }
}

<#
.SYNOPSIS
    Gets link information for an app.

.DESCRIPTION
    Returns link information for the specified app, or $null if not linked.

.PARAMETER AppName
    The name of the application.

.PARAMETER Global
    Check globally installed apps.

.OUTPUTS
    Hashtable with link info, or $null if not linked.

.EXAMPLE
    Get-AppLink -AppName "7zip"
#>
function Get-AppLink {
    [CmdletBinding()]
    param (
        [string]$AppName,
        
        [switch]$Global
    )
    
    if ($AppName) {
        return Get-AppLinkEntry -AppName $AppName -Global:$Global
    }
    
    return $null
}

<#
.SYNOPSIS
    Gets all linked apps.

.DESCRIPTION
    Returns a list of all linked applications.

.PARAMETER Global
    List globally linked apps.

.OUTPUTS
    Hashtable of linked apps.

.EXAMPLE
    Get-AppLinkList
#>
function Get-AppLinkList {
    [CmdletBinding()]
    param (
        [switch]$Global
    )
    
    $config = Get-LinksConfig
    $scope = if ($Global) { "global" } else { "local" }
    
    return $config[$scope]
}

<#
.SYNOPSIS
    Tests if an app is linked.

.DESCRIPTION
    Returns $true if the app is linked to a custom path.

.PARAMETER AppName
    The name of the application.

.PARAMETER Global
    Check globally installed apps.

.OUTPUTS
    Boolean indicating if the app is linked.

.EXAMPLE
    Test-AppLinked -AppName "7zip"
#>
function Test-AppLinked {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [switch]$Global
    )
    
    $entry = Get-AppLinkEntry -AppName $AppName -Global:$Global
    return $null -ne $entry
}

<#
.SYNOPSIS
    Syncs linked app states.

.DESCRIPTION
    Synchronizes the state of linked apps, ensuring persist links are correct.

.PARAMETER AppName
    The name of the application to sync. If omitted, syncs all linked apps.

.PARAMETER Global
    Operate on globally installed apps.

.EXAMPLE
    Invoke-AppSync -AppName "7zip"
#>
function Invoke-AppSync {
    [CmdletBinding()]
    param (
        [string]$AppName,
        
        [switch]$Global
    )
    
    if ($AppName) {
        # Sync single app
        if (-not (Test-AppLinked $AppName -Global:$Global)) {
            Write-Warning "App '$AppName' is not linked."
            return
        }
        
        # Check if app is still installed
        if (-not (Test-AppInstalled $AppName -Global:$Global)) {
            Write-Host "[sync]: App '$AppName' is no longer installed, removing link..."
            Remove-AppLinkEntry -AppName $AppName -Global:$Global
            Write-Host "[sync]: Removed link for uninstalled app '$AppName'"
            return
        }
        
        # Get stored and current versions
        $linkEntry = Get-AppLinkEntry -AppName $AppName -Global:$Global
        $currentVersion = Get-AppCurrentVersion -AppName $AppName -Global:$Global
        
        if ($currentVersion -and $linkEntry.Version -ne $currentVersion.Name) {
            Write-Host "[sync]: Version changed for '$AppName' ($($linkEntry.Version) -> $($currentVersion.Name)), updating..."
            
            # Get target path from link entry
            $targetPath = $linkEntry.Path
            $targetAppDir = Join-Path $targetPath $AppName
            $targetVersionDir = Join-Path $targetAppDir $currentVersion.Name
            
            # Create target version directory
            if (-not (Test-Path $targetVersionDir)) {
                New-Item -Path $targetVersionDir -ItemType Directory -Force | Out-Null
            }
            
            # Move new version to target
            $sourceDir = $currentVersion.FullName
            if ($sourceDir -ne $targetVersionDir) {
                Write-Debug "[sync]: Moving new version $sourceDir -> $targetVersionDir"
                Invoke-RobocopyMove -Source $sourceDir -Destination $targetVersionDir
                
                # Create symlink from original location
                New-Item -ItemType SymbolicLink -Path $currentVersion.FullName -Target $targetVersionDir -Force | Out-Null
            }
            
            # Update version in config
            $linkEntry.Version = $currentVersion.Name
            $linkEntry.Updated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            
            Invoke-WithLinksConfig -Global:$Global {
                param($Config)
                $Config[$AppName] = @{
                    Path = $linkEntry.Path
                    Version = $linkEntry.Version
                    Updated = $linkEntry.Updated
                }
                return $Config
            }
            
            Write-Host "[sync]: Updated version for '$AppName' to '$($currentVersion.Name)'"
        }
        
        Update-PersistLinks -AppName $AppName -Global:$Global
        Write-Host "[sync]: Synced '$AppName'"
    } else {
        # Sync all linked apps
        $links = Get-AppLinkList -Global:$Global
        
        foreach ($appName in $links.Keys) {
            try {
                # Check if app is still installed
                if (-not (Test-AppInstalled $appName -Global:$Global)) {
                    Write-Host "[sync]: App '$appName' is no longer installed, removing link..."
                    Remove-AppLinkEntry -AppName $appName -Global:$Global
                    Write-Host "[sync]: Removed link for uninstalled app '$appName'"
                    continue
                }
                
                # Get stored and current versions
                $linkEntry = $links[$appName]
                $currentVersion = Get-AppCurrentVersion -AppName $appName -Global:$Global
                
                if ($currentVersion -and $linkEntry.Version -ne $currentVersion.Name) {
                    Write-Host "[sync]: Version changed for '$appName' ($($linkEntry.Version) -> $($currentVersion.Name)), updating..."
                    
                    # Get target path from link entry
                    $targetPath = $linkEntry.Path
                    $targetAppDir = Join-Path $targetPath $appName
                    $targetVersionDir = Join-Path $targetAppDir $currentVersion.Name
                    
                    # Create target version directory
                    if (-not (Test-Path $targetVersionDir)) {
                        New-Item -Path $targetVersionDir -ItemType Directory -Force | Out-Null
                    }
                    
                    # Move new version to target
                    $sourceDir = $currentVersion.FullName
                    if ($sourceDir -ne $targetVersionDir) {
                        Write-Debug "[sync]: Moving new version $sourceDir -> $targetVersionDir"
                        Invoke-RobocopyMove -Source $sourceDir -Destination $targetVersionDir
                        
                        # Create symlink from original location
                        New-Item -ItemType SymbolicLink -Path $currentVersion.FullName -Target $targetVersionDir -Force | Out-Null
                    }
                    
                    # Update version in config
                    $linkEntry.Version = $currentVersion.Name
                    $linkEntry.Updated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    
                    Invoke-WithLinksConfig -Global:$Global {
                        param($Config)
                        $Config[$appName] = @{
                            Path = $linkEntry.Path
                            Version = $linkEntry.Version
                            Updated = $linkEntry.Updated
                        }
                        return $Config
                    }
                    
                    Write-Host "[sync]: Updated version for '$appName' to '$($currentVersion.Name)'"
                }
                
                Update-PersistLinks -AppName $appName -Global:$Global
                Write-Host "[sync]: Synced '$appName'"
            } catch {
                Write-Warning "Failed to sync '$appName': $_"
            }
        }
    }
}

<#
.SYNOPSIS
    Gets stale link entries for apps that no longer exist.

.DESCRIPTION
    Scans links.json and returns entries where the app directory no longer exists.

.OUTPUTS
    Hashtable with 'global' and 'local' arrays of stale entries.

.EXAMPLE
    Get-StaleLinkEntries
#>
function Get-StaleLinkEntries {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param ()
    
    $links = Get-LinksConfig
    $stale = @{ global = @(); local = @() }
    
    foreach ($scope in @("global", "local")) {
        foreach ($appName in $links[$scope].Keys) {
            $appPath = Get-AppDirectory -AppName $appName -Type "app" -Global:($scope -eq "global")
            if (-not (Test-Path $appPath)) {
                $stale[$scope] += @{
                    AppName = $appName
                    LinkPath = $links[$scope][$appName].Path
                    StoredVersion = $links[$scope][$appName].Version
                }
            }
        }
    }
    
    return $stale
}

<#
.SYNOPSIS
    Removes a stale link entry from config.

.DESCRIPTION
    Removes the specified app from links.json without modifying any files.

.PARAMETER AppName
    Name of the app to remove.

.PARAMETER Global
    Check global apps.

.EXAMPLE
    Remove-StaleLinkEntry -AppName "myapp" -Global
#>
function Remove-StaleLinkEntry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [switch]$Global
    )
    
    $config = Get-LinksConfig
    $scope = if ($Global) { "global" } else { "local" }
    
    if ($config[$scope].ContainsKey($AppName)) {
        $config[$scope].Remove($AppName)
        Set-LinksConfig $config
        Write-Host "Removed stale entry for '$AppName'."
    }
}

# ============================================================================
# Move Module Functions - Persist Path Parsing
# ============================================================================

# SPX Move Module - Persist Path Parsing
# Provides functions for parsing persist path definitions and updating persist symlinks

function Get-PersistDefinition {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Persist
    )
    
    process {
        # If it's already a string, use it as both source and target
        if ($Persist -is [string]) {
            return $Persist, $Persist
        }
        
        # If it's an array with two elements
        if ($Persist -is [array] -and $Persist.Count -eq 2) {
            $source = $Persist[0]
            $target = $Persist[1]
            
            # If target is null, default to source
            if ($null -eq $target) {
                $target = $source
            }
            
            return $source, $target
        }
        
        # Default: return the input as both
        return $Persist, $Persist
    }
}

function Get-AppManifest {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [switch]$Global
    )
    
    # Get the current version directory
    $currentVersion = Get-AppCurrentVersion -AppName $AppName -Global:$Global
    if (-not $currentVersion) {
        Write-Debug "[Get-AppManifest]: No current version found for '$AppName'"
        return $null
    }
    
    # Try to read install.json first (Scoop's standard manifest location)
    $installJson = Join-Path $currentVersion.FullName "install.json"
    if (Test-Path $installJson) {
        try {
            $content = Get-Content $installJson -Raw | ConvertFrom-Json
            $manifest = @{}
            $content.PSObject.Properties | ForEach-Object { $manifest[$_.Name] = $_.Value }
            return $manifest
        } catch {
            Write-Debug "[Get-AppManifest]: Failed to parse install.json: $_"
        }
    }
    
    # Try to find a manifest.json in the app directory
    $manifestJson = Join-Path $currentVersion.FullName "manifest.json"
    if (Test-Path $manifestJson) {
        try {
            $content = Get-Content $manifestJson -Raw | ConvertFrom-Json
            $manifest = @{}
            $content.PSObject.Properties | ForEach-Object { $manifest[$_.Name] = $_.Value }
            return $manifest
        } catch {
            Write-Debug "[Get-AppManifest]: Failed to parse manifest.json: $_"
        }
    }
    
    Write-Debug "[Get-AppManifest]: No manifest found for '$AppName' in '$($currentVersion.FullName)'"
    return $null
}

function Update-PersistLinks {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [string]$Bucket,
        
        [switch]$Global
    )
    
    Write-Debug "[Update-PersistLinks]: Processing '$AppName' Global: $Global"
    
    # Get the current version of the app
    $currentVersion = Get-AppCurrentVersion -AppName $AppName -Global:$Global
    if (-not $currentVersion) {
        Write-Debug "[Update-PersistLinks]: No current version found for '$AppName'"
        return $null
    }
    
    $installedVersionDir = $currentVersion.FullName
    Write-Debug "[Update-PersistLinks]: Version directory: $installedVersionDir"
    
    # Get the app's manifest to find persist definitions
    $manifest = Get-AppManifest -AppName $AppName -Global:$Global
    if (-not $manifest -or -not $manifest.persist) {
        Write-Debug "[Update-PersistLinks]: No persist defined for '$AppName'"
        return $currentVersion
    }
    
    # Get the persist directory for this app
    $persistDir = Get-AppDirectory -AppName $AppName -Type "persist" -Global:$Global
    
    # Ensure persist directory exists
    if (-not (Test-Path $persistDir)) {
        New-Item -Path $persistDir -ItemType Directory -Force | Out-Null
    }
    
    # Process each persist entry
    $entries = @($manifest.persist)
    foreach ($entry in $entries) {
        # Get source and target relative paths
        $srcRel, $tgRel = Get-PersistDefinition -Persist $entry
        
        # Build full paths
        $srcFull = Join-Path $installedVersionDir $srcRel.TrimEnd("/", "\")
        $tgFull = Join-Path $persistDir $tgRel.TrimEnd("/", "\")
        
        Write-Debug "[Update-PersistLinks]: Source: $srcFull -> Target: $tgFull"
        
        # Check if target directory exists, create if not
        $tgDir = Split-Path $tgFull -Parent
        if ($tgDir -and -not (Test-Path $tgDir)) {
            New-Item -Path $tgDir -ItemType Directory -Force | Out-Null
        }
        
        # Check if source already exists (might be a file, directory, or symlink)
        if (Test-Path $srcFull) {
            $srcItem = Get-Item -LiteralPath $srcFull -Force
            
            # Resolve if it's a symlink
            $resolvedTarget = $srcItem
            if ($srcItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $resolvedTarget = $srcItem.Target
            }
            
            # Check if already pointing to correct target
            if ($resolvedTarget -eq $tgFull -or $resolvedTarget.FullName -eq $tgFull) {
                Write-Debug "[Update-PersistLinks]: Already linked correctly"
                continue
            }
            
            # Remove existing item (symlink, file, or directory)
            Write-Debug "[Update-PersistLinks]: Removing existing item at '$srcFull'"
            Remove-Item -LiteralPath $srcFull -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Create new symbolic link from source to target
        Write-Debug "[Update-PersistLinks]: Creating symlink: $srcFull -> $tgFull"
        try {
            New-Item -ItemType SymbolicLink -Path $srcFull -Target $tgFull -Force | Out-Null
            Write-Debug "[Update-PersistLinks]: Successfully created symlink"
        } catch {
            Write-Warning "[Update-PersistLinks]: Failed to create symlink: $_"
        }
    }
    
    return $currentVersion
}
