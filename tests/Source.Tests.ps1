# SPX Source Module Tests
# Tests for the Source module functions using mocking

BeforeAll {
    # Define placeholder functions for mocking (if not already defined)
    if (-not (Get-Command 'Get-ScoopContext' -ErrorAction SilentlyContinue)) {
        function Get-ScoopContext { param() }
    }
    if (-not (Get-Command 'Get-ScoopGlobalContext' -ErrorAction SilentlyContinue)) {
        function Get-ScoopGlobalContext { param() }
    }
    if (-not (Get-Command 'Get-SpxConfigPath' -ErrorAction SilentlyContinue)) {
        function Get-SpxConfigPath { param() }
    }
    if (-not (Get-Command 'Get-SpxConfigFile' -ErrorAction SilentlyContinue)) {
        function Get-SpxConfigFile { param($Name, $CreateIfMissing) }
    }
    if (-not (Get-Command 'Test-AppInstalled' -ErrorAction SilentlyContinue)) {
        function Test-AppInstalled { param($AppName, [switch]$Global) }
    }
    if (-not (Get-Command 'Get-AppDirectory' -ErrorAction SilentlyContinue)) {
        function Get-AppDirectory { param($AppName, $Type, [switch]$Global, [switch]$MustExist) }
    }
    
    # Source the modules
    . "$PSScriptRoot/../context.ps1"
    . "$PSScriptRoot/../lib/Core.ps1"
}

Describe "Get-AppSource" {
    BeforeAll {
        . "$PSScriptRoot/../lib/Source.ps1"
        
        # Mock functions
        Mock Test-AppInstalled { return $true } -ParameterFilter { $AppName -eq "testapp" }
        Mock Test-AppInstalled { return $false } -ParameterFilter { $AppName -eq "notinstalled" }
        
        Mock Get-AppDirectory {
            param($AppName, $Type, [switch]$Global, [switch]$MustExist)
            return "TestDrive:\scoop\apps\$AppName"
        }
        
        # Create test app structure
        $testAppPath = "TestDrive:\scoop\apps\testapp\1.0.0"
        New-Item -Path $testAppPath -ItemType Directory -Force | Out-Null
        
        # Create install.json
        $installJson = @{
            bucket = "main"
            version = "1.0.0"
            url = "https://github.com/test/testapp"
            manifest = @{
                version = "1.0.0"
                homepage = "https://example.com"
            }
        }
        $installJsonPath = Join-Path $testAppPath "install.json"
        $installJson | ConvertTo-Json -Depth 5 | Set-Content $installJsonPath -Force
        
        # Create current directory (not symlink for test simplicity)
        $testCurrentPath = "TestDrive:\scoop\apps\testapp\current"
        New-Item -Path $testCurrentPath -ItemType Directory -Force | Out-Null
        Copy-Item $installJsonPath (Join-Path $testCurrentPath "install.json") -Force
    }
    
    It "Should return source info for installed app" {
        $result = Get-AppSource -AppName "testapp"
        
        $result | Should -Not -BeNullOrEmpty
        $result["AppName"] | Should -Be "testapp"
        $result["Bucket"] | Should -Be "main"
        $result["Version"] | Should -Be "1.0.0"
    }
    
    It "Should return null for non-installed app" {
        $result = Get-AppSource -AppName "notinstalled"
        $result | Should -BeNullOrEmpty
    }
}

Describe "Test-AppInBucket" {
    BeforeAll {
        . "$PSScriptRoot/../lib/Source.ps1"
        
        # Create a test bucket with a manifest
        $testBucket = "testbucket"
        $testBucketPath = "TestDrive:\scoop\buckets\$testBucket"
        $testBucketDir = Join-Path $testBucketPath "bucket"
        
        New-Item -Path $testBucketDir -ItemType Directory -Force | Out-Null
        
        # Create a manifest file
        $manifestPath = Join-Path $testBucketDir "testapp.json"
        @{ version = "1.0.0" } | ConvertTo-Json | Set-Content $manifestPath -Force
        
        # Mock ScoopSubs
        $Script:ScoopSubs = @{
            "apps"    = "TestDrive:\scoop\apps"
            "buckets" = "TestDrive:\scoop\buckets"
            "global"  = "TestDrive:\scoop\global"
        }
    }
    
    It "Should return true when app exists in bucket" {
        $result = Test-AppInBucket -AppName "testapp" -Bucket "testbucket"
        $result | Should -Be $true
    }
    
    It "Should return false when app does not exist in bucket" {
        $result = Test-AppInBucket -AppName "nonexistent" -Bucket "testbucket"
        $result | Should -Be $false
    }
    
    It "Should return false when bucket does not exist" {
        $result = Test-AppInBucket -AppName "testapp" -Bucket "nonexistent"
        $result | Should -Be $false
    }
}

Describe "Get-BucketManifest" {
    BeforeAll {
        . "$PSScriptRoot/../lib/Source.ps1"
        
        # Create a test bucket with a manifest
        $testBucket = "manifestbucket"
        $testBucketPath = "TestDrive:\scoop\buckets\$testBucket"
        $testBucketDir = Join-Path $testBucketPath "bucket"
        
        New-Item -Path $testBucketDir -ItemType Directory -Force | Out-Null
        
        # Create a manifest file
        $manifestPath = Join-Path $testBucketDir "manifestapp.json"
        @{
            version = "2.0.0"
            homepage = "https://example.com/manifestapp"
            license = "MIT"
        } | ConvertTo-Json | Set-Content $manifestPath -Force
        
        # Mock ScoopSubs
        $Script:ScoopSubs = @{
            "apps"    = "TestDrive:\scoop\apps"
            "buckets" = "TestDrive:\scoop\buckets"
            "global"  = "TestDrive:\scoop\global"
        }
    }
    
    It "Should return manifest for existing app" {
        $result = Get-BucketManifest -AppName "manifestapp" -Bucket "manifestbucket"
        
        $result | Should -Not -BeNullOrEmpty
        $result["version"] | Should -Be "2.0.0"
        $result["homepage"] | Should -Be "https://example.com/manifestapp"
    }
    
    It "Should return null for non-existing app" {
        $result = Get-BucketManifest -AppName "nonexistent" -Bucket "manifestbucket"
        $result | Should -BeNullOrEmpty
    }
}

Describe "Get-BucketList" {
    BeforeAll {
        . "$PSScriptRoot/../lib/Source.ps1"
        
        # Create test buckets
        $bucketsPath = "TestDrive:\scoop\buckets"
        "bucket1", "bucket2", "bucket3" | ForEach-Object {
            New-Item -Path (Join-Path $bucketsPath $_) -ItemType Directory -Force | Out-Null
        }
        
        # Mock ScoopSubs
        $Script:ScoopSubs = @{
            "apps"    = "TestDrive:\scoop\apps"
            "buckets" = $bucketsPath
            "global"  = "TestDrive:\scoop\global"
        }
    }
    
    It "Should return list of installed buckets" {
        $result = Get-BucketList
        
        $result | Should -Contain "bucket1"
        $result | Should -Contain "bucket2"
        $result | Should -Contain "bucket3"
    }
}

Describe "Compare-AppManifest" {
    BeforeAll {
        . "$PSScriptRoot/../lib/Source.ps1"
        
        # Create test app with install.json
        $testAppName = "compareapp"
        $testAppPath = "TestDrive:\scoop\apps\$testAppName\1.0.0"
        $testCurrentPath = "TestDrive:\scoop\apps\$testAppName\current"
        
        New-Item -Path $testAppPath -ItemType Directory -Force | Out-Null
        
        $installJson = @{
            bucket = "main"
            version = "1.0.0"
            manifest = @{
                version = "1.0.0"
                description = "Test app"
            }
        }
        $installJsonPath = Join-Path $testAppPath "install.json"
        $installJson | ConvertTo-Json -Depth 5 | Set-Content $installJsonPath -Force
        
        # Create current directory (not symlink for test simplicity)
        New-Item -Path $testCurrentPath -ItemType Directory -Force | Out-Null
        Copy-Item $installJsonPath (Join-Path $testCurrentPath "install.json") -Force
        
        # Create bucket with different version
        $testBucket = "comparebucket"
        $testBucketPath = "TestDrive:\scoop\buckets\$testBucket"
        $testBucketDir = Join-Path $testBucketPath "bucket"
        
        New-Item -Path $testBucketDir -ItemType Directory -Force | Out-Null
        
        $manifestPath = Join-Path $testBucketDir "$testAppName.json"
        @{
            version = "2.0.0"
            description = "Updated test app"
        } | ConvertTo-Json | Set-Content $manifestPath -Force
        
        Mock Test-AppInstalled { return $true } -ParameterFilter { $AppName -eq "compareapp" }
        Mock Get-AppDirectory {
            param($AppName, $Type, [switch]$Global, [switch]$MustExist)
            return "TestDrive:\scoop\apps\$AppName"
        }
        
        # Mock ScoopSubs
        $Script:ScoopSubs = @{
            "apps"    = "TestDrive:\scoop\apps"
            "buckets" = "TestDrive:\scoop\buckets"
            "global"  = "TestDrive:\scoop\global"
        }
    }
    
    It "Should compare installed and bucket manifests" {
        $result = Compare-AppManifest -AppName "compareapp" -Bucket "comparebucket"
        
        $result | Should -Not -BeNullOrEmpty
        $result["InstalledVersion"] | Should -Be "1.0.0"
        $result["BucketVersion"] | Should -Be "2.0.0"
        $result["VersionMatch"] | Should -Be $false
    }
}

Describe "Test-AppSourceValid" {
    BeforeAll {
        . "$PSScriptRoot/../lib/Source.ps1"
        
        # Create valid app
        $validApp = "validapp"
        $validAppPath = "TestDrive:\scoop\apps\$validApp\1.0.0"
        $validCurrentPath = "TestDrive:\scoop\apps\$validApp\current"
        
        New-Item -Path $validAppPath -ItemType Directory -Force | Out-Null
        
        $installJson = @{
            bucket = "validbucket"
            version = "1.0.0"
            manifest = @{
                version = "1.0.0"
            }
        }
        $installJsonPath = Join-Path $validAppPath "install.json"
        $installJson | ConvertTo-Json -Depth 5 | Set-Content $installJsonPath -Force
        
        # Create current directory (not symlink for test simplicity)
        New-Item -Path $validCurrentPath -ItemType Directory -Force | Out-Null
        Copy-Item $installJsonPath (Join-Path $validCurrentPath "install.json") -Force
        
        # Create bucket with matching manifest
        $validBucketPath = "TestDrive:\scoop\buckets\validbucket"
        $validBucketDir = Join-Path $validBucketPath "bucket"
        
        New-Item -Path $validBucketDir -ItemType Directory -Force | Out-Null
        
        $manifestPath = Join-Path $validBucketDir "$validApp.json"
        @{ version = "1.0.0" } | ConvertTo-Json | Set-Content $manifestPath -Force
        
        Mock Test-AppInstalled { return $true } -ParameterFilter { $AppName -eq "validapp" }
        Mock Test-AppInstalled { return $false } -ParameterFilter { $AppName -eq "invalidapp" }
        Mock Get-AppDirectory {
            param($AppName, $Type, [switch]$Global, [switch]$MustExist)
            return "TestDrive:\scoop\apps\$AppName"
        }
        
        # Mock ScoopSubs
        $Script:ScoopSubs = @{
            "apps"    = "TestDrive:\scoop\apps"
            "buckets" = "TestDrive:\scoop\buckets"
            "global"  = "TestDrive:\scoop\global"
        }
    }
    
    It "Should return true for valid app source" {
        $result = Test-AppSourceValid -AppName "validapp"
        $result | Should -Be $true
    }
    
    It "Should return false for non-existent app" {
        $result = Test-AppSourceValid -AppName "invalidapp"
        $result | Should -Be $false
    }
}
