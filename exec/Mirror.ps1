# SPX Mirror Executor - CLI entry point for mirror commands
# Handles command-line interface for managing bucket mirror URLs

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
. "$PSScriptRoot\..\lib\Config.ps1"

function Show-MirrorHelp {
    Write-Host @"
SPX Mirror - Bucket URL Replacement

Usage:
  spx mirror list                    List all bucket mirrors
  spx mirror add <bucket> <url>      Add a mirror for a bucket
  spx mirror remove <bucket>         Remove a bucket mirror
  spx mirror set <bucket> <url>     Set/change mirror URL for a bucket

Options:
  -h, --help      Show this help

Examples:
  spx mirror list
  spx mirror add main https://mirror.example.com/scoop
  spx mirror set main https://new-mirror.com/scoop
  spx mirror remove main
"@
}

function Get-BucketRemoteUrl {
    param ([string]$BucketPath)
    Push-Location $BucketPath
    try { git remote get-url origin 2>$null } finally { Pop-Location }
}

function Set-BucketRemoteUrl {
    param ([string]$BucketPath, [string]$Url)
    
    Write-Host "Setting bucket remote to: $Url"
    Push-Location $BucketPath
    try {
        git remote set-url origin $Url
        $newUrl = git remote get-url origin
        Write-Host "Verify: remote is now: $newUrl"
    } catch {
        Write-Error "Failed to set remote URL: $_"
    } finally {
        Pop-Location
    }
}

function Invoke-MirrorList {
    $scoop = Get-ScoopContext
    $bucketsPath = Join-Path $scoop "buckets"
    
    if (-not (Test-Path $bucketsPath)) {
        Write-Host "No buckets found."
        return
    }
    
    $buckets = Get-ChildItem $bucketsPath -Directory
    if ($buckets.Count -eq 0) {
        Write-Host "No buckets found."
        return
    }
    
    Write-Host "Bucket Mirrors:"
    Write-Host "---------------"
    
    $mirrors = Get-SpxConfig -Name "spx.json" -Key "mirrors"
    if (-not $mirrors) { $mirrors = [PSCustomObject]@{ } }
    
    foreach ($bucket in $buckets) {
        $bucketPath = $bucket.FullName
        $gitDir = Join-Path $bucketPath ".git"
        $isGit = Test-Path $gitDir
        
        Write-Host ""
        Write-Host "Bucket: $($bucket.Name)"
        if ($isGit) {
            $currentUrl = Get-BucketRemoteUrl -BucketPath $bucketPath
            Write-Host "  Remote: $currentUrl"
            if ($mirrors.PSObject.Properties.Name -contains $bucket.Name) {
                Write-Host "  (mirrored)"
            }
        } else {
            Write-Host "  (not a git repository)"
        }
    }
}

function Invoke-MirrorSet {
    param ([string]$Bucket, [string]$Url, [switch]$AddOnly)
    
    if (-not $Bucket -or -not $Url) {
        Write-Error "Usage: spx mirror <add|set> <bucket> <url>" -ErrorAction Stop
        return
    }
    
    $scoop = Get-ScoopContext
    $bucketPath = Join-Path $scoop "buckets\$Bucket"
    
    if (-not (Test-Path $bucketPath)) {
        Write-Error "Bucket '$Bucket' not found in '$scoop\buckets\'" -ErrorAction Stop
        return
    }
    
    $gitDir = Join-Path $bucketPath ".git"
    if (-not (Test-Path $gitDir)) {
        Write-Error "Bucket '$Bucket' is not a git repository." -ErrorAction Stop
        return
    }
    
    # Get current URL from git
    $currentUrl = Get-BucketRemoteUrl -BucketPath $bucketPath
    
    # Get existing mirror config
    $mirrors = Get-SpxConfig -Name "spx.json" -Key "mirrors"
    if (-not $mirrors) { $mirrors = @{ } }
    
    # Determine original URL - prefer saved original, fall back to current git remote
    $originalUrl = $currentUrl
    $bucketMirror = $mirrors.$Bucket
    if ($bucketMirror) {
        $savedOriginal = $bucketMirror.original
        if ($savedOriginal) {
            $originalUrl = $savedOriginal
        }
    }
    
    # Check if mirror already exists (for add command)
    if ($AddOnly -and $bucketMirror) {
        Write-Error "Mirror for '$Bucket' already exists. Use 'set' to change it." -ErrorAction Stop
        return
    }
    
    # Update git remote
    Set-BucketRemoteUrl -BucketPath $bucketPath -Url $Url
    
    # Save to config - convert to hashtable for proper serialization
    $mirrorsHash = @{ }
    foreach ($prop in $mirrors.PSObject.Properties) {
        if ($prop.Value -is [PSCustomObject]) {
            $mirrorsHash[$prop.Name] = @{ original = $prop.Value.original; mirror = $prop.Value.mirror }
        } else {
            $mirrorsHash[$prop.Name] = $prop.Value
        }
    }
    $mirrorsHash[$Bucket] = @{ original = $originalUrl; mirror = $Url }
    Set-SpxConfig -Name "spx.json" -Key "mirrors" -Value $mirrorsHash
    
    Write-Host "Mirror set for '$Bucket':"
    Write-Host "  Old: $currentUrl"
    Write-Host "  New: $Url"
}

function Invoke-MirrorRemove {
    param ([string]$Bucket)
    
    if (-not $Bucket) {
        Write-Error "Usage: spx mirror remove <bucket>" -ErrorAction Stop
        return
    }
    
    $scoop = Get-ScoopContext
    $bucketPath = Join-Path $scoop "buckets\$Bucket"
    
    if (-not (Test-Path $bucketPath)) {
        Write-Error "Bucket '$Bucket' not found." -ErrorAction Stop
        return
    }
    
    # Load full spx.json config
    $fullConfig = Get-SpxConfig -Name "spx.json"
    
    if (-not $fullConfig -or -not $fullConfig.PSObject.Properties.Name -contains "mirrors") {
        Write-Error "No mirror config found." -ErrorAction Stop
        return
    }
    
    $mirrors = $fullConfig.mirrors
    
    if (-not $mirrors) {
        Write-Error "No mirrors configured." -ErrorAction Stop
        return
    }
    
    # Check if bucket exists in mirrors
    $bucketMirror = $mirrors.$Bucket
    if (-not $bucketMirror) {
        Write-Error "No mirror config found for '$Bucket'." -ErrorAction Stop
        return
    }
    
    $originalUrl = $bucketMirror.original
    
    Write-Host "Restoring '$Bucket' to original URL: $originalUrl"
    
    if ($originalUrl) {
        Set-BucketRemoteUrl -BucketPath $bucketPath -Url $originalUrl
    }
    
    # Remove from config - build new hashtable excluding the bucket
    $newMirrors = @{ }
    foreach ($prop in $mirrors.PSObject.Properties) {
        if ($prop.Name -ne $Bucket) {
            if ($prop.Value -is [PSCustomObject]) {
                $newMirrors[$prop.Name] = @{ original = $prop.Value.original; mirror = $prop.Value.mirror }
            } else {
                $newMirrors[$prop.Name] = $prop.Value
            }
        }
    }
    Set-SpxConfig -Name "spx.json" -Key "mirrors" -Value $newMirrors
    
    Write-Host "Removed mirror for '$Bucket'."
}

# Parse arguments
$helpFlags = @("-h", "--help", "/?")
if ($Action -in $helpFlags -or $RemainingArgs | Where-Object { $_ -in $helpFlags }) {
    Show-MirrorHelp
    return
}

# Route commands
$parsed = Invoke-ParseArguments -Args $RemainingArgs
$bucket = $parsed['Positional'][0]
$url = $parsed['Positional'][1]

switch (($Action -as [string]).ToLower()) {
    "list" { Invoke-MirrorList }
    "add" { Invoke-MirrorSet -Bucket $bucket -Url $url -AddOnly }
    "set" { Invoke-MirrorSet -Bucket $bucket -Url $url }
    "remove" { Invoke-MirrorRemove -Bucket $bucket }
    default { Show-MirrorHelp }
}
