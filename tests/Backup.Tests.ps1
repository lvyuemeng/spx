# SPX Backup Module Tests
# Tests for the Backup module functions using mocking

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
    
    # Source the modules
    . "$PSScriptRoot/../context.ps1"
    . "$PSScriptRoot/../lib/Core.ps1"
}

Describe "Get-BackupDirectory" {
    BeforeAll {
        . "$PSScriptRoot/../modules/Backup/Backup.ps1"
    }
    
    It "Should return the backup directory path" {
        Mock Get-SpxConfigPath { return "TestDrive:\scoop\spx" }
        
        $result = Get-BackupDirectory
        
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeLike "*spx*backups*"
    }
    
    It "Should create backup directory if it does not exist" {
        $tempSpxPath = "TestDrive:\tempspx"
        $tempBackupPath = Join-Path $tempSpxPath "backups"
        
        Mock Get-SpxConfigPath { return $tempSpxPath }
        
        # Ensure directory doesn't exist
        if (Test-Path $tempBackupPath) {
            Remove-Item $tempBackupPath -Recurse -Force
        }
        
        $result = Get-BackupDirectory
        
        Test-Path $result | Should -Be $true
    }
}

Describe "Get-BackupList" {
    BeforeAll {
        . "$PSScriptRoot/../modules/Backup/Backup.ps1"
        
        # Create test backup directory
        $script:TestBackupPath = "TestDrive:\backups"
        New-Item -Path $script:TestBackupPath -ItemType Directory -Force | Out-Null
        
        # Create a test backup file
        $testBackupFile = Join-Path $script:TestBackupPath "test-backup.zip"
        Set-Content -Path $testBackupFile -Value "PK" -Force  # Minimal ZIP header
        
        Mock Get-BackupDirectory { return $script:TestBackupPath }
    }
    
    It "Should return list of backup files" {
        $result = Get-BackupList
        
        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -BeGreaterOrEqual 1
    }
    
    It "Should return empty array when no backups exist" {
        $emptyBackupPath = "TestDrive:\emptybackups"
        New-Item -Path $emptyBackupPath -ItemType Directory -Force | Out-Null
        
        Mock Get-BackupDirectory { return $emptyBackupPath }
        
        $result = Get-BackupList
        $result.Count | Should -Be 0
    }
}

Describe "Get-BackupStatus" {
    BeforeAll {
        . "$PSScriptRoot/../modules/Backup/Backup.ps1"
        
        # Create test backup directory
        $script:TestBackupPath = "TestDrive:\statusbackups"
        New-Item -Path $script:TestBackupPath -ItemType Directory -Force | Out-Null
        
        # Create a test backup file
        $testBackupFile = Join-Path $script:TestBackupPath "status-test.zip"
        Set-Content -Path $testBackupFile -Value "PK" -Force
        
        Mock Get-BackupDirectory { return $script:TestBackupPath }
    }
    
    It "Should return backup status information" {
        $result = Get-BackupStatus
        
        $result | Should -Not -BeNullOrEmpty
        $result["BackupDirectory"] | Should -Not -BeNullOrEmpty
        $result["TotalBackups"] | Should -BeGreaterOrEqual 0
    }
    
    It "Should include latest backup info when backups exist" {
        $result = Get-BackupStatus
        
        if ($result["TotalBackups"] -gt 0) {
            $result["LatestBackup"] | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Get-ScoopBackupData" {
    BeforeAll {
        . "$PSScriptRoot/../modules/Backup/Backup.ps1"
        
        # Create test directory structure
        $script:TestScoopPath = "TestDrive:\scoopdata"
        $script:TestAppsPath = Join-Path $script:TestScoopPath "apps"
        $script:TestBucketsPath = Join-Path $script:TestScoopPath "buckets"
        
        New-Item -Path $script:TestAppsPath -ItemType Directory -Force | Out-Null
        New-Item -Path $script:TestBucketsPath -ItemType Directory -Force | Out-Null
        
        # Create test app with install.json
        $testAppName = "backupapp"
        $testAppPath = Join-Path $script:TestAppsPath $testAppName
        $testVersionPath = Join-Path $testAppPath "1.0.0"
        $testCurrentPath = Join-Path $testAppPath "current"
        
        New-Item -Path $testVersionPath -ItemType Directory -Force | Out-Null
        
        $installJson = @{
            bucket = "main"
            version = "1.0.0"
        }
        $installJsonPath = Join-Path $testVersionPath "install.json"
        $installJson | ConvertTo-Json | Set-Content $installJsonPath -Force
        
        # Create current as directory (not symlink for test simplicity)
        New-Item -Path $testCurrentPath -ItemType Directory -Force | Out-Null
        Copy-Item $installJsonPath (Join-Path $testCurrentPath "install.json") -Force
        
        # Create test bucket
        $testBucket = "main"
        $testBucketPath = Join-Path $script:TestBucketsPath $testBucket
        New-Item -Path $testBucketPath -ItemType Directory -Force | Out-Null
        
        # Create Scoop config
        $configPath = Join-Path $script:TestScoopPath "config.json"
        @{ lastupdate = "2024-01-01" } | ConvertTo-Json | Set-Content $configPath -Force
        
        # Mock context
        Mock Get-ScoopContext { return $script:TestScoopPath }
        
        # Mock ScoopSubs
        $Script:ScoopSubs = @{
            "apps"    = $script:TestAppsPath
            "buckets" = $script:TestBucketsPath
            "global"  = "TestDrive:\scoopdata\global"
        }
    }
    
    It "Should return backup data with apps list" {
        $result = Get-ScoopBackupData
        
        $result | Should -Not -BeNullOrEmpty
        $result["apps"] | Should -Not -BeNullOrEmpty
        $result["apps"].Count | Should -BeGreaterOrEqual 1
    }
    
    It "Should return backup data with buckets" {
        $result = Get-ScoopBackupData
        
        $result["buckets"] | Should -Not -BeNullOrEmpty
    }
    
    It "Should return backup data with config" {
        $result = Get-ScoopBackupData
        
        $result["config"] | Should -Not -BeNullOrEmpty
    }
}

Describe "Get-SpxBackupData" {
    BeforeAll {
        . "$PSScriptRoot/../modules/Backup/Backup.ps1"
        
        # Create test SPX directory
        $script:TestSpxPath = "TestDrive:\spxdata"
        New-Item -Path $script:TestSpxPath -ItemType Directory -Force | Out-Null
        
        # Create test SPX config files
        $linksPath = Join-Path $script:TestSpxPath "links.json"
        @{ local = @{}; global = @{} } | ConvertTo-Json | Set-Content $linksPath -Force
        
        $mirrorsPath = Join-Path $script:TestSpxPath "mirrors.json"
        @{ enabled = $true; rules = @() } | ConvertTo-Json | Set-Content $mirrorsPath -Force
        
        Mock Get-SpxConfigPath { return $script:TestSpxPath }
    }
    
    It "Should return SPX backup data with links" {
        $result = Get-SpxBackupData
        
        $result | Should -Not -BeNullOrEmpty
        $result["links"] | Should -Not -BeNullOrEmpty
    }
    
    It "Should return SPX backup data with mirrors" {
        $result = Get-SpxBackupData
        
        $result["mirrors"] | Should -Not -BeNullOrEmpty
    }
}

Describe "New-Backup" {
    BeforeAll {
        . "$PSScriptRoot/../modules/Backup/Backup.ps1"
        
        # Create test directory structure
        $script:TestScoopPath = "TestDrive:\newbackupscoop"
        $script:TestAppsPath = Join-Path $script:TestScoopPath "apps"
        $script:TestSpxPath = Join-Path $script:TestScoopPath "spx"
        $script:TestBackupPath = Join-Path $script:TestSpxPath "backups"
        
        New-Item -Path $script:TestAppsPath -ItemType Directory -Force | Out-Null
        New-Item -Path $script:TestSpxPath -ItemType Directory -Force | Out-Null
        New-Item -Path $script:TestBackupPath -ItemType Directory -Force | Out-Null
        
        # Create minimal test app
        $testAppName = "newbackupapp"
        $testAppPath = Join-Path $script:TestAppsPath $testAppName
        $testVersionPath = Join-Path $testAppPath "1.0.0"
        $testCurrentPath = Join-Path $testAppPath "current"
        
        New-Item -Path $testVersionPath -ItemType Directory -Force | Out-Null
        
        $installJson = @{
            bucket = "main"
            version = "1.0.0"
        }
        $installJsonPath = Join-Path $testVersionPath "install.json"
        $installJson | ConvertTo-Json | Set-Content $installJsonPath -Force
        
        # Create current as directory (not symlink for test simplicity)
        New-Item -Path $testCurrentPath -ItemType Directory -Force | Out-Null
        Copy-Item $installJsonPath (Join-Path $testCurrentPath "install.json") -Force
        
        Mock Get-ScoopContext { return $script:TestScoopPath }
        Mock Get-SpxConfigPath { return $script:TestSpxPath }
        Mock Get-BackupDirectory { return $script:TestBackupPath }
        
        # Mock ScoopSubs
        $Script:ScoopSubs = @{
            "apps"    = $script:TestAppsPath
            "buckets" = Join-Path $script:TestScoopPath "buckets"
            "global"  = Join-Path $script:TestScoopPath "global"
        }
    }
    
    It "Should create backup archive at default location" {
        $result = New-Backup
        
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeLike "*.zip"
        Test-Path $result | Should -Be $true
    }
    
    It "Should create backup archive at specified path" {
        $customPath = "TestDrive:\custom-backup.zip"
        
        $result = New-Backup -Path $customPath
        
        $result | Should -Be $customPath
        Test-Path $result | Should -Be $true
    }
    
    AfterEach {
        # Clean up created backups
        Get-ChildItem "TestDrive:\" -Filter "*.zip" -ErrorAction SilentlyContinue | 
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

Describe "Restore-Backup" {
    BeforeAll {
        . "$PSScriptRoot/../modules/Backup/Backup.ps1"
        
        # Create a test backup
        $script:TestBackupPath = "TestDrive:\restorebackups"
        New-Item -Path $script:TestBackupPath -ItemType Directory -Force | Out-Null
        
        $script:TestBackupFile = Join-Path $script:TestBackupPath "restore-test.zip"
        
        # Create temp directory with backup content
        $tempDir = "TestDrive:\backup-temp"
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        
        $backupData = @{
            version = "1.0.0"
            created = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
            scoop = @{
                apps = @(
                    @{ name = "testapp"; version = "1.0.0"; bucket = "main"; global = $false }
                )
                buckets = @{}
                config = @{}
            }
            spx = @{
                links = @{ local = @{}; global = @{} }
                mirrors = @{ enabled = $true; rules = @() }
            }
        }
        
        $manifestPath = Join-Path $tempDir "backup.json"
        $backupData | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Force
        
        # Create ZIP
        if (Test-Path $script:TestBackupFile) {
            Remove-Item $script:TestBackupFile -Force
        }
        Compress-Archive -Path "$tempDir\*" -DestinationPath $script:TestBackupFile -Force
    }
    
    It "Should restore from backup archive" {
        # Create empty SPX config directory for restore
        $restoreSpxPath = "TestDrive:\restorespx"
        New-Item -Path $restoreSpxPath -ItemType Directory -Force | Out-Null
        
        Mock Get-SpxConfigPath { return $restoreSpxPath }
        Mock Get-ScoopContext { return "TestDrive:\restorescoop" }
        
        { Restore-Backup -Archive $script:TestBackupFile -Force } | Should -Not -Throw
    }
    
    It "Should throw error for non-existent archive" {
        { Restore-Backup -Archive "TestDrive:\nonexistent.zip" } | 
            Should -Throw
    }
}
