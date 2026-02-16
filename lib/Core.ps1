# SPX Core - Shared Utilities
# Provides common utility functions for SPX modules

function Test-Administrator {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()
    
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $user
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Test-AppInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [switch]$Global
    )
    
    $base = if ($Global) {
        $Script:ScoopSubs["global"]
    } else {
        $Script:ScoopSubs["apps"]
    }
    
    $appPath = Join-Path $base $AppName
    return Test-Path $appPath
}

function Get-AppDirectory {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [ValidateSet("app", "persist")]
        [string]$Type = "app",
        
        [switch]$Global,
        [switch]$MustExist
    )
    
    $dir = switch ($Type) {
        "app" {
            $base = if ($Global) {
                $Script:ScoopSubs["global"]
            } else {
                $Script:ScoopSubs["apps"]
            }
            Join-Path $base $AppName
        }
        "persist" {
            Join-Path $Script:ScoopSubs["persist"] $AppName
        }
    }
    
    if ($MustExist -and -not (Test-Path $dir)) {
        Write-Error "Directory does not exist: $dir" -ErrorAction Stop
    }
    
    return $dir
}

function Get-AppVersions {
    [CmdletBinding()]
    [OutputType([System.IO.DirectoryInfo])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [switch]$Global
    )
    
    $pkgDir = Get-AppDirectory $AppName -Type "app" -Global:$Global
    
    if (-not (Test-Path $pkgDir)) {
        return @()
    }
    
    $versions = Get-ChildItem $pkgDir -Directory | Where-Object { $_.Name -ne "current" }
    return $versions
}

function Get-AppCurrentVersion {
    [CmdletBinding()]
    [OutputType([System.IO.DirectoryInfo])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [switch]$Global
    )
    
    $pkgDir = Get-AppDirectory $AppName -Type "app" -Global:$Global
    $currentLink = Join-Path $pkgDir "current"
    
    if (-not (Test-Path $currentLink)) {
        # Return the most recent version if no current link
        $versions = Get-AppVersions $AppName -Global:$Global
        return $versions | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }
    
    # Resolve the current symlink target
    $target = (Get-Item $currentLink).Target
    if ($target) {
        return Get-Item $target
    }
    
    return $null
}

function Resolve-SymlinkTarget {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$Path
    )
    
    if ($Path.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        return $Path.Target
    }
    
    return $Path.FullName
}

function Invoke-RobocopyMove {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Source,
        
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )
    
    Write-Debug "[RobocopyMove]: $Source -> $Destination"
    
    robocopy $Source $Destination /MIR /MOVE /NFL /NDL /NJH /NJS /NP /NS /NC | Out-Null
    
    if ($LASTEXITCODE -ge 8) {
        Write-Error "Failed to move from '$Source' to '$Destination'. Robocopy exit code: $LASTEXITCODE" -ErrorAction Stop
    }
}

function Show-HelpMessage {
    [CmdletBinding()]
    param (
        [string]$Context = "main"
    )
    
    # This function is defined in spx.ps1, but we provide a stub for module use
    Write-Host "Use 'spx $Context --help' for more information."
}
