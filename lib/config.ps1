# SPX Config - Configuration Management
# Provides functions for managing SPX configuration files

. "$PSScriptRoot/../context.ps1"

function Get-LinksConfig {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param ()
    
    $configFile = Get-SpxConfigFile -Name "links.json" -CreateIfMissing
    
    # Check if file exists first, then check if it's empty
    if (-not (Test-Path $configFile)) {
        return @{
            "global" = @{}
            "local"  = @{}
        }
    }
    
    $fileInfo = Get-Item $configFile -ErrorAction SilentlyContinue
    if ($null -eq $fileInfo -or $fileInfo.Length -eq 0) {
        return @{
            "global" = @{}
            "local"  = @{}
        }
    }
    
    try {
        $content = Get-Content $configFile -Raw
        $config = $content | ConvertFrom-Json -AsHashtable
        
        # Ensure scope fields exist
        foreach ($scope in @("global", "local")) {
            if (-not $config.ContainsKey($scope)) {
                $config[$scope] = @{}
            }
        }
        
        return $config
    } catch {
        Write-Warning "Failed to parse links.json, returning empty config."
        return @{
            "global" = @{}
            "local"  = @{}
        }
    }
}

function Set-LinksConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]$Config
    )
    
    $configFile = Get-SpxConfigFile -Name "links.json"
    $Config | ConvertTo-Json -Depth 5 | Set-Content $configFile -Encoding UTF8
}

function Invoke-WithLinksConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [switch]$Global,
        [switch]$AsReference
    )
    
    $config = Get-LinksConfig
    $scope = if ($Global) { "global" } else { "local" }
    $scopeConfig = $config[$scope]
    
    if ($AsReference) {
        $configRef = [ref]$scopeConfig
        & $ScriptBlock $configRef
        $config[$scope] = $configRef.Value
        Set-LinksConfig $config
    } else {
        $result = & $ScriptBlock $scopeConfig
        if ($result -is [hashtable]) {
            $config[$scope] = $result
            Set-LinksConfig $config
        }
    }
}

function New-AppLinkEntry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$Version,
        
        [switch]$Global
    )
    
    Invoke-WithLinksConfig -Global:$Global {
        param($Config)
        
        if ($Config.ContainsKey($AppName)) {
            $oldPath = $Config[$AppName].Path
            $oldAppDir = Join-Path $oldPath $AppName
            $newAppDir = Join-Path $Path $AppName
            
            Write-Debug "[New-AppLinkEntry]: $AppName : $oldPath -> $Path"
            
            # Remove old app directory if different from new
            if ($oldAppDir -ne $newAppDir -and (Test-Path $oldAppDir)) {
                Remove-Item $oldAppDir -Recurse -Force
            }
        }
        
        $entry = @{
            Path    = $Path
            Version = $Version
            Updated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        $Config[$AppName] = $entry
        return $Config
    }
}

function Remove-AppLinkEntry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [switch]$Global
    )
    
    Invoke-WithLinksConfig -Global:$Global -AsReference {
        param([ref]$Config)
        
        if (-not $Config.Value.ContainsKey($AppName)) {
            Write-Debug "[Remove-AppLinkEntry]: $AppName not found in config"
            return
        }
        
        $appDir = Join-Path $Config.Value[$AppName].Path $AppName
        if (Test-Path $appDir) {
            Write-Debug "[Remove-AppLinkEntry]: Removing $appDir"
            Remove-Item $appDir -Recurse -Force
        }
        
        $Config.Value.Remove($AppName)
    }
}

function Get-AppLinkEntry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [switch]$Global
    )
    
    $config = Get-LinksConfig
    $scope = if ($Global) { "global" } else { "local" }
    
    if ($config[$scope].ContainsKey($AppName)) {
        return $config[$scope][$AppName]
    }
    
    return $null
}
