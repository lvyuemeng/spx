# SPX Source Module - Installed App Source Management
# Provides functions for managing the bucket/source of installed applications
# This module is STATELESS - no sources.json is maintained

. "$PSScriptRoot\..\..\context.ps1"
. "$PSScriptRoot\..\..\lib\Core.ps1"

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
        $installInfo = Get-Content $installFile -Raw | ConvertFrom-Json -AsHashtable
        
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
        $installInfo = Get-Content $installFile -Raw | ConvertFrom-Json -AsHashtable
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
                return $content | ConvertFrom-Json -AsHashtable
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
