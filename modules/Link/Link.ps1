# SPX Link Module - Custom Path Management
# Provides functions for relocating installed packages to custom paths via symbolic links

. "$PSScriptRoot\..\..\context.ps1"
. "$PSScriptRoot\..\..\lib\Core.ps1"
. "$PSScriptRoot\..\..\lib\Config.ps1"
. "$PSScriptRoot\Move.ps1"

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
        
        Update-PersistLinks -AppName $AppName -Global:$Global
        Write-Host "[sync]: Synced '$AppName'"
    } else {
        # Sync all linked apps
        $links = Get-AppLinkList -Global:$Global
        
        foreach ($appName in $links.Keys) {
            try {
                Update-PersistLinks -AppName $appName -Global:$Global
                Write-Host "[sync]: Synced '$appName'"
            } catch {
                Write-Warning "Failed to sync '$appName': $_"
            }
        }
    }
}
