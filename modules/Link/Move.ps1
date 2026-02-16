# SPX Link Module - Move Operations
# Provides internal functions for moving apps and managing persist links

. "$PSScriptRoot\..\..\context.ps1"
. "$PSScriptRoot\..\..\lib\Core.ps1"

<#
.SYNOPSIS
    Gets the manifest of an installed app.

.DESCRIPTION
    Retrieves the manifest for the specified app using scoop cat.

.PARAMETER AppName
    The name of the application.

.OUTPUTS
    The manifest as a PowerShell object.
#>
function Get-AppManifest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName
    )
    
    $manifest = & scoop cat $AppName 2>$null | ConvertFrom-Json
    return $manifest
}

<#
.SYNOPSIS
    Parses a persist definition into source and target.

.DESCRIPTION
    Converts a Scoop persist definition (string or array) into
    source and target path components.

.PARAMETER Persist
    The persist definition from the manifest.

.OUTPUTS
    A tuple of (source, target) paths.
#>
function Get-PersistDefinition {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Persist
    )
    
    if ($Persist -is [Array]) {
        $source = $Persist[0]
        $target = if ($Persist[1]) { $Persist[1] } else { $Persist[0] }
    } else {
        $source = $Persist
        $target = $Persist
    }
    
    return $source, $target
}

<#
.SYNOPSIS
    Updates persist links for an app.

.DESCRIPTION
    Creates symbolic links from the app's current version directory
    to the persist directory for each persist entry in the manifest.

.PARAMETER AppName
    The name of the application.

.PARAMETER Global
    Operate on globally installed apps.
#>
function Update-PersistLinks {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [switch]$Global
    )
    
    $currentVersion = Get-AppCurrentVersion $AppName -Global:$Global
    if (-not $currentVersion) {
        Write-Debug "[Update-PersistLinks]: No current version for $AppName"
        return
    }
    
    $installedDir = Resolve-SymlinkTarget $currentVersion
    Write-Debug "[Update-PersistLinks]: Resolved version: $installedDir"
    
    $manifest = Get-AppManifest $AppName
    if (-not $manifest -or -not $manifest.persist) {
        Write-Debug "[Update-PersistLinks]: No persist entries"
        return
    }
    
    $persistDir = Get-AppDirectory $AppName -Type "persist" -Global:$Global -MustExist
    Write-Debug "[Update-PersistLinks]: Persist directory: $persistDir"
    
    $entries = @($manifest.persist)
    
    foreach ($entry in $entries) {
        $srcRel, $tgRel = Get-PersistDefinition $entry
        
        $srcFull = Join-Path $installedDir $srcRel.TrimEnd("/", "\")
        $tgFull = Join-Path $persistDir $tgRel.TrimEnd("/", "\")
        
        Write-Debug "[Update-PersistLinks]: $srcFull -> $tgFull"
        
        if (Test-Path $srcFull) {
            $srcItem = Get-Item -LiteralPath $srcFull -Force
            $resolved = Resolve-SymlinkTarget $srcItem
            
            if ($resolved -eq $tgFull) {
                Write-Debug "[Update-PersistLinks]: Already linked"
                continue
            }
            
            Remove-Item -LiteralPath $srcFull -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        New-Item -ItemType SymbolicLink -Path $srcFull -Target $tgFull -Force | Out-Null
    }
}
