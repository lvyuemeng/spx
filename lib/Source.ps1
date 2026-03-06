# SPX Config - Configuration Management
# Provides functions for managing SPX configuration files

. "$PSScriptRoot/../context.ps1"

# Generic spx.json config functions
function Get-SpxConfig {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [string]$Name = "spx.json",
        [string]$Key
    )
    
    $configFile = Get-SpxConfigFile -Name $Name -CreateIfMissing
    
    if (-not (Test-Path $configFile)) {
        return $null
    }
    
    $fileInfo = Get-Item $configFile -ErrorAction SilentlyContinue
    if ($null -eq $fileInfo -or $fileInfo.Length -eq 0) {
        return $null
    }
    
    try {
        $content = Get-Content $configFile -Raw
        if (-not $content) {
            return $null
        }
        
        # Convert to PSCustomObject
        $obj = ConvertFrom-Json $content
        
        # Convert PSCustomObject to hashtable
        $config = @{}
        $obj.PSObject.Properties | ForEach-Object { $config[$_.Name] = $_.Value }
        
        if ($Key) {
            if ($config.ContainsKey($Key)) {
                return $config[$Key]
            }
            return $null
        }
        
        return $config
    } catch {
        Write-Warning "Failed to parse $Name : $_"
        return $null
    }
}

function Set-SpxConfig {
    [CmdletBinding()]
    param (
        [string]$Name = "spx.json",
        [string]$Key,
        $Value
    )
    
    $configFile = Get-SpxConfigFile -Name $Name
    
    # Load existing config as PSCustomObject, preserve original fields
    $config = $null
    if (Test-Path $configFile) {
        try {
            $content = Get-Content $configFile -Raw
            if ($content) {
                $config = ConvertFrom-Json $content
            }
        } catch {
            $config = $null
        }
    }
    
    if (-not $config) {
        $config = [PSCustomObject]@{}
    }
    
    if ($Key) {
        # Convert hashtable to PSCustomObject if needed
        if ($Value -is [hashtable]) {
            $Value = [PSCustomObject]$Value
        }
        $config | Add-Member -MemberType NoteProperty -Name $Key -Value $Value -Force
    }
    
    $config | ConvertTo-Json -Depth 10 | Set-Content $configFile -Encoding UTF8
}

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
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $config = $content | ConvertFrom-JsonWithFallback
        } else {
            $obj = $content | ConvertFrom-Json
            $config = @{}
            $obj.PSObject.Properties | ForEach-Object { $config[$_.Name] = $_.Value }
        }
        
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
# SPX Source Module - Installed App Source Management
# Provides functions for managing the bucket/source of installed applications
# This module is STATELESS - no sources.json is maintained

. "$PSScriptRoot/../context.ps1"
. "$PSScriptRoot/Core.ps1"

<#
.SYNOPSIS
    Gets the source (bucket) information for an installed app.

.DESCRIPTION
    Returns the bucket name and manifest information for the specified app.
    Reads directly from Scoop's installed apps - no state is stored.

.PARAMETER AppName
    The name of the application.

.OUTPUTS
    Hashtable with source info, or $null if app not found.

.EXAMPLE
    Get-AppSource -AppName "7zip"
#>
function Get-AppSource {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName
    )
    
    # Check if app is installed (local or global)
    $isLocal = Test-AppInstalled -AppName $AppName
    $isGlobal = Test-AppInstalled -AppName $AppName -Global
    
    if (-not $isLocal -and -not $isGlobal) {
        Write-Warning "App '$AppName' is not installed."
        return $null
    }
    
    $global = $isGlobal -and -not $isLocal
    $appDir = Get-AppDirectory -AppName $AppName -Type "app" -Global:$global
    $currentDir = Join-Path $appDir "current"
    
    if (-not (Test-Path $currentDir)) {
        Write-Warning "App '$AppName' has no 'current' directory."
        return $null
    }
    
    # Read the install manifest
    $installFile = Join-Path $currentDir "install.json"
    if (-not (Test-Path $installFile)) {
        Write-Warning "App '$AppName' has no install.json."
        return $null
    }
    
    try {
        $installInfo = Get-Content $installFile -Raw | ConvertFrom-JsonWithFallback
        
        $result = @{
            "AppName"     = $AppName
            "Bucket"      = $installInfo["bucket"]
            "Version"     = $installInfo["version"]
            "URL"         = $installInfo["url"]
            "Manifest"    = $installInfo["manifest"]
            "Global"      = $global
            "InstallPath" = $currentDir
        }
        
        return $result
    } catch {
        Write-Warning "Failed to read install info for '$AppName': $_"
        return $null
    }
}

<#
.SYNOPSIS
    Lists all installed apps with their sources.

.DESCRIPTION
    Returns a list of all installed applications with their bucket sources.
    Reads directly from Scoop's installed apps directory.

.OUTPUTS
    Array of hashtables with app source info.

.EXAMPLE
    Get-AppSourceList
#>
function Get-AppSourceList {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable[]])]
    param ()
    
    $results = @()
    
    # Get local apps
    $localAppsPath = $Script:ScoopSubs["apps"]
    if (Test-Path $localAppsPath) {
        $apps = Get-ChildItem $localAppsPath -Directory | Where-Object { $_.Name -ne "scoop" }
        
        foreach ($app in $apps) {
            $source = Get-AppSource -AppName $app.Name
            if ($source) {
                $results += $source
            }
        }
    }
    
    # Get global apps
    $globalAppsPath = $Script:ScoopSubs["global"]
    if (Test-Path $globalAppsPath) {
        $apps = Get-ChildItem $globalAppsPath -Directory | Where-Object { $_.Name -ne "scoop" }
        
        foreach ($app in $apps) {
            $source = Get-AppSource -AppName $app.Name
            if ($source -and $source["Global"]) {
                $results += $source
            }
        }
    }
    
    return $results
}

<#
.SYNOPSIS
    Moves an app to a different bucket.

.DESCRIPTION
    Changes the source bucket for an installed application.
    This is a stateless operation - it updates Scoop's install.json directly.
    Fails if the target bucket doesn't have the package.

.PARAMETER AppName
    The name of the application.

.PARAMETER Bucket
    The target bucket name.

.PARAMETER Force
    Force the change even if versions differ.

.EXAMPLE
    Move-AppSource -AppName "7zip" -Bucket "extras"
#>
function Move-AppSource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [string]$Bucket,
        
        [switch]$Force
    )
    
    # Verify app is installed
    $currentSource = Get-AppSource -AppName $AppName
    if (-not $currentSource) {
        Write-Error "App '$AppName' is not installed." -ErrorAction Stop
        return
    }
    
    if ($currentSource["Bucket"] -eq $Bucket) {
        Write-Warning "App '$AppName' is already in bucket '$Bucket'."
        return
    }
    
    # Check if target bucket exists
    $bucketPath = Join-Path $Script:ScoopSubs["buckets"] $Bucket
    if (-not (Test-Path $bucketPath)) {
        Write-Error "Bucket '$Bucket' is not installed. Run 'scoop bucket add $Bucket' first." -ErrorAction Stop
        return
    }
    
    # Check if package exists in target bucket
    if (-not (Test-AppInBucket -AppName $AppName -Bucket $Bucket)) {
        Write-Error "Package '$AppName' not found in bucket '$Bucket'." -ErrorAction Stop
        return
    }
    
    # Get manifest from target bucket
    $targetManifest = Get-BucketManifest -AppName $AppName -Bucket $Bucket
    if (-not $targetManifest) {
        Write-Error "Failed to read manifest for '$AppName' from bucket '$Bucket'." -ErrorAction Stop
        return
    }
    
    # Compare versions
    $currentVersion = $currentSource["Version"]
    $targetVersion = $targetManifest["version"]
    
    if ($currentVersion -ne $targetVersion -and -not $Force) {
        Write-Warning "Version mismatch: installed '$currentVersion' vs bucket '$targetVersion'"
        Write-Warning "Use -Force to proceed anyway."
        return
    }
    
    # Update install.json
    $installFile = Join-Path $currentSource["InstallPath"] "install.json"
    
    try {
        $installInfo = Get-Content $installFile -Raw | ConvertFrom-JsonWithFallback
        $installInfo["bucket"] = $Bucket
        $installInfo["manifest"] = $targetManifest
        
        $installInfo | ConvertTo-Json -Depth 10 | Set-Content $installFile -Encoding UTF8
        
        Write-Host "[source]: Changed '$AppName' from '$($currentSource['Bucket'])' to '$Bucket'"
    } catch {
        Write-Error "Failed to update install.json: $_" -ErrorAction Stop
    }
}

<#
.SYNOPSIS
    Tests if a package exists in a bucket.

.DESCRIPTION
    Checks if the specified package exists in the given bucket.

.PARAMETER AppName
    The name of the application.

.PARAMETER Bucket
    The bucket name to check.

.OUTPUTS
    Boolean indicating if the package exists in the bucket.

.EXAMPLE
    Test-AppInBucket -AppName "7zip" -Bucket "main"
#>
function Test-AppInBucket {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [string]$Bucket
    )
    
    $bucketPath = Join-Path $Script:ScoopSubs["buckets"] $Bucket
    if (-not (Test-Path $bucketPath)) {
        return $false
    }
    
    # Check for manifest file (bucket.json or manifest.json or AppName.json)
    $manifestPatterns = @(
        "bucket/$AppName.json"
        "manifest/$AppName.json"
        "$AppName.json"
    )
    
    foreach ($pattern in $manifestPatterns) {
        $manifestPath = Join-Path $bucketPath $pattern
        if (Test-Path $manifestPath) {
            return $true
        }
    }
    
    # Check in bucket directory structure
    $bucketDir = Join-Path $bucketPath "bucket"
    if (Test-Path $bucketDir) {
        $manifestPath = Join-Path $bucketDir "$AppName.json"
        if (Test-Path $manifestPath) {
            return $true
        }
    }
    
    return $false
}

<#
.SYNOPSIS
    Gets the manifest for an app from a bucket.

.DESCRIPTION
    Reads the manifest file for the specified app from the given bucket.

.PARAMETER AppName
    The name of the application.

.PARAMETER Bucket
    The bucket name.

.OUTPUTS
    Hashtable with manifest content, or $null if not found.

.EXAMPLE
    Get-BucketManifest -AppName "7zip" -Bucket "main"
#>
function Get-BucketManifest {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [string]$Bucket
    )
    
    $bucketPath = Join-Path $Script:ScoopSubs["buckets"] $Bucket
    if (-not (Test-Path $bucketPath)) {
        return $null
    }
    
    # Try different manifest locations
    $manifestPaths = @(
        (Join-Path $bucketPath "bucket/$AppName.json")
        (Join-Path $bucketPath "manifest/$AppName.json")
        (Join-Path $bucketPath "$AppName.json")
        (Join-Path $bucketPath "bucket/$AppName.json")
    )
    
    foreach ($path in $manifestPaths) {
        if (Test-Path $path) {
            try {
                $content = Get-Content $path -Raw
                return $content | ConvertFrom-JsonWithFallback
            } catch {
                Write-Debug "Failed to parse manifest at $path"
            }
        }
    }
    
    return $null
}

<#
.SYNOPSIS
    Compares installed manifest with bucket manifest.

.DESCRIPTION
    Compares the installed version of an app with the version in a bucket.

.PARAMETER AppName
    The name of the application.

.PARAMETER Bucket
    The bucket to compare against.

.OUTPUTS
    Hashtable with comparison results.

.EXAMPLE
    Compare-AppManifest -AppName "7zip" -Bucket "main"
#>
function Compare-AppManifest {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [string]$Bucket
    )
    
    $currentSource = Get-AppSource -AppName $AppName
    if (-not $currentSource) {
        Write-Warning "App '$AppName' is not installed."
        return $null
    }
    
    $bucketManifest = Get-BucketManifest -AppName $AppName -Bucket $Bucket
    if (-not $bucketManifest) {
        Write-Warning "Package '$AppName' not found in bucket '$Bucket'."
        return $null
    }
    
    $result = @{
        "AppName"         = $AppName
        "CurrentBucket"   = $currentSource["Bucket"]
        "CompareBucket"   = $Bucket
        "InstalledVersion" = $currentSource["Version"]
        "BucketVersion"   = $bucketManifest["version"]
        "VersionMatch"    = $currentSource["Version"] -eq $bucketManifest["version"]
        "Differences"     = @()
    }
    
    # Compare key fields
    $keysToCompare = @("description", "homepage", "license", "url", "bin", "shortcuts")
    
    foreach ($key in $keysToCompare) {
        $installed = if ($currentSource["Manifest"]) { $currentSource["Manifest"][$key] } else { $null }
        $bucket = $bucketManifest[$key]
        
        if ($installed -ne $bucket) {
            $result["Differences"] += @{
                "Key"       = $key
                "Installed" = $installed
                "Bucket"    = $bucket
            }
        }
    }
    
    return $result
}

<#
.SYNOPSIS
    Verifies an app's manifest matches its bucket.

.DESCRIPTION
    Checks if the installed app's manifest matches the current version in its bucket.

.PARAMETER AppName
    The name of the application to verify.

.OUTPUTS
    Boolean indicating if the manifest is valid.

.EXAMPLE
    Test-AppSourceValid -AppName "7zip"
#>
function Test-AppSourceValid {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName
    )
    
    $source = Get-AppSource -AppName $AppName
    if (-not $source) {
        return $false
    }
    
    $bucket = $source["Bucket"]
    if (-not $bucket) {
        Write-Warning "App '$AppName' has no bucket information."
        return $false
    }
    
    # Check if bucket still exists
    $bucketPath = Join-Path $Script:ScoopSubs["buckets"] $bucket
    if (-not (Test-Path $bucketPath)) {
        Write-Warning "Bucket '$bucket' is not installed."
        return $false
    }
    
    # Check if package still exists in bucket
    if (-not (Test-AppInBucket -AppName $AppName -Bucket $bucket)) {
        Write-Warning "Package '$AppName' not found in bucket '$bucket'."
        return $false
    }
    
    # Compare versions
    $comparison = Compare-AppManifest -AppName $AppName -Bucket $bucket
    if ($comparison -and -not $comparison["VersionMatch"]) {
        Write-Warning "Version mismatch: installed '$($comparison['InstalledVersion'])' vs bucket '$($comparison['BucketVersion'])'"
        return $false
    }
    
    return $true
}

<#
.SYNOPSIS
    Gets list of available buckets.

.DESCRIPTION
    Returns a list of all installed Scoop buckets.

.OUTPUTS
    Array of bucket names.

.EXAMPLE
    Get-BucketList
#>
function Get-BucketList {
    [CmdletBinding()]
    [OutputType([string[]])]
    param ()
    
    $bucketsPath = $Script:ScoopSubs["buckets"]
    if (-not (Test-Path $bucketsPath)) {
        return @()
    }
    
    $buckets = Get-ChildItem $bucketsPath -Directory | Select-Object -ExpandProperty Name
    return $buckets
}
# SPX Sandbox - Isolated Test Environment
# Provides fake directory structures and environment injection for safe testing

# Sandbox root directory
$script:SandboxRoot = $null
$script:OriginalEnv = $null

<#
.SYNOPSIS
    Enters the sandbox environment, injecting test paths.

.DESCRIPTION
    Saves the original environment variables and injects sandbox paths
    to prevent modification of user's actual Scoop installation.

.PARAMETER Root
    The root directory for the sandbox. Defaults to TestDrive:\sandbox.

.EXAMPLE
    Enter-Sandbox -Root "TestDrive:\mytest"
#>
function Enter-Sandbox {
    [CmdletBinding()]
    param(
        [string]$Root = "TestDrive:\sandbox"
    )
    
    # Check if TestDrive exists (Pester), otherwise use temp directory
    # TestDrive is typically available in Pester tests
    $testDrivePath = $null
    if ($Root -match '^([A-Za-z]+):') {
        $testDrivePath = $matches[1] + ':/'
    }
    if ($testDrivePath -and -not (Test-Path $testDrivePath)) {
        $Root = Join-Path $env:TEMP "spx_sandbox_$(Get-Random)"
        Write-Debug "[sandbox]: TestDrive not available, using temp: $Root"
    }
    
    $script:SandboxRoot = $Root
    
    # Save original environment
    $script:OriginalEnv = @{
        SCOOP = $env:SCOOP
        SCOOP_GLOBAL = $env:SCOOP_GLOBAL
    }
    
    # Inject sandbox environment
    $env:SCOOP = Join-Path $Root "scoop"
    $env:SCOOP_GLOBAL = Join-Path $Root "scoop_global"
    
    Write-Debug "[sandbox]: Entered sandbox at $Root"
    
    return @{
        Root = $Root
        ScoopPath = $env:SCOOP
        GlobalPath = $env:SCOOP_GLOBAL
    }
}

<#
.SYNOPSIS
    Exits the sandbox, restoring original environment.

.EXAMPLE
    Exit-Sandbox
#>
function Exit-Sandbox {
    # Restore original environment
    if ($script:OriginalEnv) {
        $env:SCOOP = $script:OriginalEnv.SCOOP
        $env:SCOOP_GLOBAL = $script:OriginalEnv.SCOOP_GLOBAL
    }
    
    $script:SandboxRoot = $null
    $script:OriginalEnv = $null
    Write-Debug "[sandbox]: Exited sandbox"
}

<#
.SYNOPSIS
    Gets the current sandbox root path.

.EXAMPLE
    Get-SandboxRoot
#>
function Get-SandboxRoot {
    return $script:SandboxRoot
}

<#
.SYNOPSIS
    Creates a fake Scoop directory structure in the sandbox.

.DESCRIPTION
    Creates all necessary directories for a Scoop installation:
    apps, global/apps, persist, buckets, shims, spx

.PARAMETER Root
    The sandbox root directory. Defaults to current sandbox root.

.EXAMPLE
    New-SandboxScoopStructure
#>
function New-SandboxScoopStructure {
    [CmdletBinding()]
    param(
        [string]$Root = (Get-SandboxRoot)
    )
    
    if (-not $Root) {
        Write-Error "Sandbox not initialized. Call Enter-Sandbox first."
        return
    }
    
    $scoopPath = Join-Path $Root "scoop"
    $globalPath = Join-Path $Root "scoop_global"
    
    $structure = @{
        ScoopPath = $scoopPath
        GlobalPath = $globalPath
        Apps = Join-Path $scoopPath "apps"
        GlobalApps = Join-Path $globalPath "apps"
        Persist = Join-Path $scoopPath "persist"
        Buckets = Join-Path $scoopPath "buckets"
        Shims = Join-Path $scoopPath "shims"
        Spx = Join-Path $scoopPath "spx"
    }
    
    # Create all directories
    foreach ($key in $structure.Keys) {
        New-Item -Path $structure[$key] -ItemType Directory -Force | Out-Null
    }
    
    Write-Debug "[sandbox]: Created Scoop structure at $Root"
    
    return $structure
}

<#
.SYNOPSIS
    Creates a fake app directory in the sandbox.

.DESCRIPTION
    Creates a realistic Scoop app structure with version directory
    and current symlink.

.PARAMETER AppName
    Name of the application.

.PARAMETER Version
    Version string. Defaults to "1.0.0".

.PARAMETER Global
    Create in global apps directory.

.PARAMETER Root
    The sandbox root directory.

.EXAMPLE
    New-SandboxApp -AppName "jq" -Version "1.7.1"
#>
function New-SandboxApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$AppName,
        
        [string]$Version = "1.0.0",
        
        [switch]$Global,
        
        [string]$Root = (Get-SandboxRoot)
    )
    
    if (-not $Root) {
        Write-Error "Sandbox not initialized."
        return
    }
    
    $appsPath = if ($Global) {
        Join-Path $Root "scoop_global\apps"
    } else {
        Join-Path $Root "scoop\apps"
    }
    
    $appPath = Join-Path $appsPath $AppName
    $versionPath = Join-Path $appPath $Version
    $currentPath = Join-Path $appPath "current"
    
    # Create version directory with dummy file
    New-Item -Path $versionPath -ItemType Directory -Force | Out-Null
    Set-Content -Path (Join-Path $versionPath "app.exe") -Value "dummy" -Force
    
    # Create current symlink
    New-Item -ItemType SymbolicLink -Path $currentPath -Target $versionPath -Force | Out-Null
    
    Write-Debug "[sandbox]: Created app '$AppName' v$Version at $versionPath"
    
    return @{
        AppPath = $appPath
        VersionPath = $versionPath
        CurrentPath = $currentPath
        AppName = $AppName
        Version = $Version
    }
}

<#
.SYNOPSIS
    Creates a stale link entry without actual app directory.

.DESCRIPTION
    Adds an entry to links.json for an app that doesn't exist,
    simulating a stale/unlinked app for cleanup testing.

.PARAMETER AppName
    Name of the stale app.

.PARAMETER Version
    Stored version string.

.PARAMETER LinkPath
    The linked path that was stored.

.PARAMETER Global
    Create in global scope.

.PARAMETER Root
    The sandbox root directory.

.EXAMPLE
    New-SandboxStaleEntry -AppName "deleted-app" -LinkPath "D:\Apps"
#>
function New-SandboxStaleEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$AppName,
        
        [string]$Version = "1.0.0",
        
        [string]$LinkPath = "D:\Apps",
        
        [switch]$Global,
        
        [string]$Root = (Get-SandboxRoot)
    )
    
    if (-not $Root) {
        Write-Error "Sandbox not initialized."
        return
    }
    
    # Create config entry WITHOUT actual app directory (simulating stale)
    $spxPath = Join-Path $Root "scoop\spx"
    $linksFile = Join-Path $spxPath "links.json"
    
    $links = @{}
    if (Test-Path $linksFile) {
        $content = Get-Content $linksFile -Raw -ErrorAction SilentlyContinue
        if ($content) {
            try {
                $links = $content | ConvertFrom-JsonWithFallback
            } catch {
                $links = @{}
            }
        }
    }
    
    if (-not $links["global"]) { $links["global"] = @{} }
    if (-not $links["local"]) { $links["local"] = @{} }
    
    $scope = if ($Global) { "global" } else { "local" }
    $links[$scope][$AppName] = @{
        Path = $LinkPath
        Version = $Version
        Updated = "2024-01-01 00:00:00"  # Old timestamp
    }
    
    # Ensure directory exists
    if (-not (Test-Path $spxPath)) {
        New-Item -Path $spxPath -ItemType Directory -Force | Out-Null
    }
    
    $links | ConvertTo-Json -Depth 5 | Set-Content $linksFile -Encoding UTF8
    
    Write-Debug "[sandbox]: Created stale entry for '$AppName' ($scope)"
    
    return @{
        AppName = $AppName
        Scope = $scope
        LinkPath = $LinkPath
        Version = $Version
    }
}

<#
.SYNOPSIS
    Removes an app directory from the sandbox.

.DESCRIPTION
    Deletes the app directory to simulate an uninstalled app.

.PARAMETER AppName
    Name of the app to remove.

.PARAMETER Global
    Remove from global apps.

.PARAMETER Root
    The sandbox root directory.

.EXAMPLE
    Remove-SandboxApp -AppName "jq"
#>
function Remove-SandboxApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$AppName,
        
        [switch]$Global,
        
        [string]$Root = (Get-SandboxRoot)
    )
    
    if (-not $Root) {
        Write-Error "Sandbox not initialized."
        return
    }
    
    $appsPath = if ($Global) {
        Join-Path $Root "scoop_global\apps"
    } else {
        Join-Path $Root "scoop\apps"
    }
    
    $appPath = Join-Path $appsPath $AppName
    
    if (Test-Path $appPath) {
        Remove-Item -Path $appPath -Recurse -Force
        Write-Debug "[sandbox]: Removed app '$AppName'"
    }
}

<#
.SYNOPSIS
    Creates a linked app scenario in the sandbox.

.DESCRIPTION
    Creates an app with both the directory and a links.json entry,
    simulating a fully linked app.

.PARAMETER AppName
    Name of the app.

.PARAMETER Version
    Version string.

.PARAMETER LinkPath
    The custom path the app is linked to.

.PARAMETER Global
    Create in global scope.

.PARAMETER Root
    The sandbox root directory.

.EXAMPLE
    New-SandboxLinkedApp -AppName "jq" -LinkPath "D:\Portable"
#>
function New-SandboxLinkedApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$AppName,
        
        [string]$Version = "1.0.0",
        
        [string]$LinkPath = "D:\Apps",
        
        [switch]$Global,
        
        [string]$Root = (Get-SandboxRoot)
    )
    
    # First create the app directory
    $app = New-SandboxApp -AppName $AppName -Version $Version -Global:$Global -Root $Root
    
    # Then add the link entry
    $spxPath = Join-Path $Root "scoop\spx"
    $linksFile = Join-Path $spxPath "links.json"
    
    $links = @{}
    if (Test-Path $linksFile) {
        $content = Get-Content $linksFile -Raw -ErrorAction SilentlyContinue
        if ($content) {
            try {
                $links = $content | ConvertFrom-JsonWithFallback
            } catch {
                $links = @{}
            }
        }
    }
    
    if (-not $links["global"]) { $links["global"] = @{} }
    if (-not $links["local"]) { $links["local"] = @{} }
    
    $scope = if ($Global) { "global" } else { "local" }
    $links[$scope][$AppName] = @{
        Path = $LinkPath
        Version = $Version
        Updated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
    
    if (-not (Test-Path $spxPath)) {
        New-Item -Path $spxPath -ItemType Directory -Force | Out-Null
    }
    
    $links | ConvertTo-Json -Depth 5 | Set-Content $linksFile -Encoding UTF8
    
    Write-Debug "[sandbox]: Created linked app '$AppName' -> $LinkPath"
    
    return $app
}

<#
.SYNOPSIS
    Creates a complete sandbox scenario for testing.

.DESCRIPTION
    Sets up a sandbox with a predefined scenario including
    valid apps, stale entries, or linked apps.

.PARAMETER Scenario
    Hashtable defining the scenario with ValidApps, StaleApps, and LinkedApps arrays.

.PARAMETER Root
    The sandbox root directory.

.EXAMPLE
    $scenario = @{
        ValidApps = @(@{ Name = "jq"; Version = "1.7.1"; Global = $false })
        StaleApps = @(@{ Name = "deleted"; Version = "1.0.0"; Path = "D:\Apps"; Global = $false })
    }
    Invoke-SandboxScenario -Scenario $scenario
#>
function Invoke-SandboxScenario {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Scenario,
        
        [string]$Root = "TestDrive:\sandbox"
    )
    
    # Check if TestDrive exists (Pester), otherwise use temp directory
    $testDrivePath = $null
    if ($Root -match '^([A-Za-z]+):') {
        $testDrivePath = $matches[1] + ':/'
    }
    if ($testDrivePath -and -not (Test-Path $testDrivePath)) {
        $Root = Join-Path $env:TEMP "spx_sandbox_$(Get-Random)"
        Write-Debug "[sandbox]: Using temp directory: $Root"
    }
    
    # Enter and set up sandbox
    Enter-Sandbox -Root $Root
    New-SandboxScoopStructure -Root $Root
    
    # Create valid (normal) apps
    if ($Scenario.ValidApps) {
        foreach ($app in $Scenario.ValidApps) {
            New-SandboxApp -AppName $app.Name -Version $app.Version -Global:$app.Global -Root $Root
        }
    }
    
    # Create stale entries (config exists but app directory missing)
    if ($Scenario.StaleApps) {
        foreach ($stale in $Scenario.StaleApps) {
            New-SandboxStaleEntry -AppName $stale.Name -Version $stale.Version `
                -LinkPath $stale.Path -Global:$stale.Global -Root $Root
        }
    }
    
    # Create linked apps (both config and app directory exist)
    if ($Scenario.LinkedApps) {
        foreach ($linked in $Scenario.LinkedApps) {
            New-SandboxLinkedApp -AppName $linked.Name -Version $linked.Version `
                -LinkPath $linked.Path -Global:$linked.Global -Root $Root
        }
    }
    
    Write-Host "[sandbox]: Scenario created - Valid: $($Scenario.ValidApps.Count), Stale: $($Scenario.StaleApps.Count), Linked: $($Scenario.LinkedApps.Count)"
    
    return @{
        Root = $Root
        ScoopPath = Join-Path $Root "scoop"
        GlobalPath = Join-Path $Root "scoop_global"
    }
}

<#
.SYNOPSIS
    Gets the current links configuration from sandbox.

.EXAMPLE
    Get-SandboxLinksConfig
#>
function Get-SandboxLinksConfig {
    [CmdletBinding()]
    param(
        [string]$Root = (Get-SandboxRoot)
    )
    
    if (-not $Root) {
        return $null
    }
    
    $linksFile = Join-Path $Root "scoop\spx\links.json"
    
    if (-not (Test-Path $linksFile)) {
        return @{ global = @{}; local = @{} }
    }
    
    try {
        $content = Get-Content $linksFile -Raw
        return $content | ConvertFrom-JsonWithFallback
    } catch {
        return @{ global = @{}; local = @{} }
    }
}

<#
.SYNOPSIS
    Clears all sandbox data.

.DESCRIPTION
    Removes all files and directories in the sandbox root.

.PARAMETER Root
    The sandbox root to clear.

.EXAMPLE
    Clear-Sandbox
#>
function Clear-Sandbox {
    [CmdletBinding()]
    param(
        [string]$Root = (Get-SandboxRoot)
    )
    
    if ($Root -and (Test-Path $Root)) {
        Remove-Item -Path $Root -Recurse -Force -ErrorAction SilentlyContinue
        Write-Debug "[sandbox]: Cleared sandbox at $Root"
    }
    
    Exit-Sandbox
}
