# SPX Test Helpers
# Provides mock functions and test utilities that don't affect user system

# Create a test scoop directory structure in TestDrive
function New-TestScoopStructure {
    param (
        [string]$TestDrive = "TestDrive:"
    )
    
    $scoopPath = Join-Path $TestDrive "scoop"
    $appsPath = Join-Path $scoopPath "apps"
    $persistPath = Join-Path $scoopPath "persist"
    $bucketsPath = Join-Path $scoopPath "buckets"
    $spxPath = Join-Path $scoopPath "spx"
    
    # Create directories
    New-Item -Path $appsPath -ItemType Directory -Force | Out-Null
    New-Item -Path $persistPath -ItemType Directory -Force | Out-Null
    New-Item -Path $bucketsPath -ItemType Directory -Force | Out-Null
    New-Item -Path $spxPath -ItemType Directory -Force | Out-Null
    
    return @{
        ScoopPath = $scoopPath
        AppsPath = $appsPath
        PersistPath = $persistPath
        BucketsPath = $bucketsPath
        SpxPath = $spxPath
    }
}

# Create a mock app directory structure
function New-TestApp {
    param (
        [string]$AppsPath,
        [string]$AppName,
        [string]$Version = "1.0.0",
        [switch]$WithCurrent
    )
    
    $appPath = Join-Path $AppsPath $AppName
    $versionPath = Join-Path $appPath $Version
    
    New-Item -Path $versionPath -ItemType Directory -Force | Out-Null
    
    # Create a dummy file in the version directory
    $dummyFile = Join-Path $versionPath "app.exe"
    Set-Content -Path $dummyFile -Value "dummy content" -Force
    
    if ($WithCurrent) {
        $currentPath = Join-Path $appPath "current"
        New-Item -ItemType SymbolicLink -Path $currentPath -Target $versionPath -Force | Out-Null
    }
    
    return @{
        AppPath = $appPath
        VersionPath = $versionPath
    }
}

# Create a mock persist directory
function New-TestPersist {
    param (
        [string]$PersistPath,
        [string]$AppName,
        [string[]]$Entries = @("data")
    )
    
    $appPersistPath = Join-Path $PersistPath $AppName
    New-Item -Path $appPersistPath -ItemType Directory -Force | Out-Null
    
    foreach ($entry in $Entries) {
        $entryPath = Join-Path $appPersistPath $entry
        $parentDir = Split-Path $entryPath -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
        }
        Set-Content -Path $entryPath -Value "persist data" -Force
    }
    
    return $appPersistPath
}

# Create a mock manifest
function New-TestManifest {
    param (
        [string]$AppName,
        [string]$Version = "1.0.0",
        [string[]]$Persist = @()
    )
    
    $manifest = @{
        version = $Version
        homepage = "https://example.com/$AppName"
        license = "MIT"
    }
    
    if ($Persist.Count -gt 0) {
        $manifest.persist = $Persist
    }
    
    return $manifest
}

# Create a mock links.json config
function New-TestLinksConfig {
    param (
        [string]$SpxPath,
        [hashtable]$LocalApps = @{},
        [hashtable]$GlobalApps = @{}
    )
    
    $config = @{
        "local" = $LocalApps
        "global" = $GlobalApps
    }
    
    $configPath = Join-Path $SpxPath "links.json"
    $config | ConvertTo-Json -Depth 5 | Set-Content $configPath -Force
    
    return $configPath
}

# Mock Get-AppManifest to return test manifest
function Mock-GetAppManifest {
    param (
        [string]$AppName,
        [hashtable]$Manifest
    )
    
    Mock Get-AppManifest { return $Manifest } -ParameterFilter { $AppName -eq $AppName }
}

# Mock scoop command
function Mock-ScoopCommand {
    param (
        [string]$Command,
        [object]$Output
    )
    
    Mock Invoke-Expression { return $Output } -ParameterFilter { $command -like "*scoop $Command*" }
}

# Create a mock directory info object
function New-MockDirectoryInfo {
    param (
        [string]$FullName,
        [string]$Name,
        [bool]$IsSymlink = $false,
        [string]$Target = $null
    )
    
    $mock = [PSCustomObject]@{
        FullName = $FullName
        Name = $Name
        Attributes = if ($IsSymlink) { [IO.FileAttributes]::ReparsePoint } else { [IO.FileAttributes]::Directory }
        Target = $Target
    }
    
    return $mock
}

# Assert that a file exists
function Assert-FileExists {
    param (
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        throw "Expected file does not exist: $Path"
    }
}

# Assert that a file does not exist
function Assert-FileNotExists {
    param (
        [string]$Path
    )
    
    if (Test-Path $Path) {
        throw "File exists but should not: $Path"
    }
}

# Assert that a path is a symlink
function Assert-IsSymlink {
    param (
        [string]$Path
    )
    
    $item = Get-Item $Path -Force
    if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Path is not a symlink: $Path"
    }
}

# Compare two hashtables
function Assert-HashtableEqual {
    param (
        [hashtable]$Expected,
        [hashtable]$Actual
    )
    
    foreach ($key in $Expected.Keys) {
        if (-not $Actual.ContainsKey($key)) {
            throw "Missing key: $key"
        }
        if ($Expected[$key] -ne $Actual[$key]) {
            throw "Value mismatch for key '$key': expected '$($Expected[$key])', got '$($Actual[$key])'"
        }
    }
}

# Functions are available when dot-sourced
# No Export-ModuleMember needed for .ps1 files
