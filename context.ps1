# SPX Context - Scoop Environment Resolution
# Provides context functions for Scoop environment

function Get-ScoopContext {
    [CmdletBinding()]
    param ()
    
    $scoop = if ($env:SCOOP) { 
        $env:SCOOP 
    } else { 
        Join-Path $env:USERPROFILE "scoop" 
    }
    
    if (-not (Test-Path $scoop)) {
        Write-Error "Scoop is not found at $scoop. Please install Scoop first." -ErrorAction Stop
    }
    
    return $scoop
}

function Get-ScoopGlobalContext {
    [CmdletBinding()]
    param ()
    
    $global = if ($env:SCOOP_GLOBAL) {
        $env:SCOOP_GLOBAL
    } else {
        Join-Path $env:ProgramData "scoop\apps"
    }
    
    return $global
}

function Get-ScoopSubdirectories {
    [CmdletBinding()]
    param ()
    
    $scoop = Get-ScoopContext
    $global = Get-ScoopGlobalContext
    
    $subdirectories = @{
        "apps"    = Join-Path $scoop "apps"
        "global"  = $global
        "buckets" = Join-Path $scoop "buckets"
        "persist" = Join-Path $scoop "persist"
        "shims"   = Join-Path $scoop "shims"
    }
    
    return $subdirectories
}

function Get-SpxConfigPath {
    [CmdletBinding()]
    param (
        [switch]$Global
    )
    
    $scoop = Get-ScoopContext
    $spxPath = Join-Path $scoop "spx"
    
    # Ensure SPX config directory exists
    if (-not (Test-Path $spxPath)) {
        New-Item -Path $spxPath -ItemType Directory -Force | Out-Null
    }
    
    return $spxPath
}

function Get-SpxConfigFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [switch]$CreateIfMissing
    )
    
    $spxPath = Get-SpxConfigPath
    $filePath = Join-Path $spxPath $Name
    
    if ($CreateIfMissing -and -not (Test-Path $filePath)) {
        New-Item -Path $filePath -ItemType File -Force | Out-Null
    }
    
    return $filePath
}

# Initialize script-level context variables
$Script:ScoopSubs = Get-ScoopSubdirectories
$Script:SpxConfigPath = Get-SpxConfigPath
