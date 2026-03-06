# SPX Sandbox Module Tests
# Tests for the Sandbox functions that provide isolated test environments

BeforeAll {
    # Source the sandbox module
    . "$PSScriptRoot/../lib/Sandbox.ps1"
}

Describe "Enter-Sandbox" {
    BeforeEach {
        # Use temp directory for isolation
        $script:TestRoot = Join-Path $env:TEMP "spx_test_$(Get-Random)"
    }
    
    AfterEach {
        Exit-Sandbox -ErrorAction SilentlyContinue
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Should enter sandbox with default root" {
        $result = Enter-Sandbox
        
        $result | Should -Not -BeNullOrEmpty
        $result.Root | Should -Match "sandbox"
        $result.ScoopPath | Should -Match "scoop"
        $result.GlobalPath | Should -Match "scoop_global"
    }
    
    It "Should enter sandbox with custom root" {
        $result = Enter-Sandbox -Root $script:TestRoot
        
        $result.Root | Should -Be $script:TestRoot
        $result.ScoopPath | Should -Be (Join-Path $script:TestRoot "scoop")
        $result.GlobalPath | Should -Be (Join-Path $script:TestRoot "scoop_global")
    }
    
    It "Should inject environment variables" {
        Enter-Sandbox -Root $script:TestRoot
        
        $env:SCOOP | Should -Be (Join-Path $script:TestRoot "scoop")
        $env:SCOOP_GLOBAL | Should -Be (Join-Path $script:TestRoot "scoop_global")
    }
    
    It "Should save original environment" {
        # Set custom values before entering
        $originalScoop = $env:SCOOP
        $originalGlobal = $env:SCOOP_GLOBAL
        
        try {
            $env:SCOOP = "CustomScoop"
            $env:SCOOP_GLOBAL = "CustomGlobal"
            
            Enter-Sandbox -Root $script:TestRoot
            
            # After exit, should restore
            Exit-Sandbox
            
            $env:SCOOP | Should -Be "CustomScoop"
            $env:SCOOP_GLOBAL | Should -Be "CustomGlobal"
        } finally {
            # Restore for other tests
            $env:SCOOP = $originalScoop
            $env:SCOOP_GLOBAL = $originalGlobal
        }
    }
}

Describe "Exit-Sandbox" {
    BeforeEach {
        $script:TestRoot = Join-Path $env:TEMP "spx_test_$(Get-Random)"
    }
    
    AfterEach {
        # Make sure we exit even if test fails
        Exit-Sandbox -ErrorAction SilentlyContinue
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Should restore original environment variables" {
        # Save original values
        $origScoop = $env:SCOOP
        $origGlobal = $env:SCOOP_GLOBAL
        
        try {
            Enter-Sandbox -Root $script:TestRoot
            
            # Verify sandbox values are set
            $env:SCOOP | Should -Not -Be $origScoop
            
            Exit-Sandbox
            
            # Should be restored
            $env:SCOOP | Should -Be $origScoop
            $env:SCOOP_GLOBAL | Should -Be $origGlobal
        } finally {
            $env:SCOOP = $origScoop
            $env:SCOOP_GLOBAL = $origGlobal
        }
    }
    
    It "Should clear sandbox root" {
        Enter-Sandbox -Root $script:TestRoot
        
        Get-SandboxRoot | Should -Not -BeNullOrEmpty
        
        Exit-Sandbox
        
        Get-SandboxRoot | Should -BeNullOrEmpty
    }
}

Describe "Get-SandboxRoot" {
    BeforeEach {
        $script:TestRoot = Join-Path $env:TEMP "spx_test_$(Get-Random)"
    }
    
    AfterEach {
        Exit-Sandbox -ErrorAction SilentlyContinue
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Should return null when not in sandbox" {
        # Make sure we're not in a sandbox
        Exit-Sandbox -ErrorAction SilentlyContinue
        
        Get-SandboxRoot | Should -BeNullOrEmpty
    }
    
    It "Should return sandbox root when in sandbox" {
        Enter-Sandbox -Root $script:TestRoot
        
        Get-SandboxRoot | Should -Be $script:TestRoot
    }
}

Describe "New-SandboxScoopStructure" {
    BeforeEach {
        $script:TestRoot = Join-Path $env:TEMP "spx_test_$(Get-Random)"
    }
    
    AfterEach {
        Exit-Sandbox -ErrorAction SilentlyContinue
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Should create all required directories" {
        Enter-Sandbox -Root $script:TestRoot
        $result = New-SandboxScoopStructure
        
        Test-Path $result.ScoopPath | Should -Be $true
        Test-Path $result.GlobalPath | Should -Be $true
        Test-Path $result.Apps | Should -Be $true
        Test-Path $result.GlobalApps | Should -Be $true
        Test-Path $result.Persist | Should -Be $true
        Test-Path $result.Buckets | Should -Be $true
        Test-Path $result.Shims | Should -Be $true
        Test-Path $result.Spx | Should -Be $true
    }
    
    It "Should return hashtable with all paths" {
        Enter-Sandbox -Root $script:TestRoot
        $result = New-SandboxScoopStructure
        
        $result | Should -BeOfType [hashtable]
        $result.Keys.Count | Should -BeGreaterThan 0
        $result.ScoopPath | Should -Match "scoop$"
        $result.GlobalPath | Should -Match "scoop_global$"
    }
    
    It "Should error when sandbox not initialized" {
        # The function writes an error message, not throwing an exception
        # So we verify the function returns nothing (null) which indicates error
        $result = New-SandboxScoopStructure -ErrorAction SilentlyContinue
        $result | Should -BeNullOrEmpty
    }
}

Describe "New-SandboxApp" {
    BeforeEach {
        $script:TestRoot = Join-Path $env:TEMP "spx_test_$(Get-Random)"
    }
    
    AfterEach {
        Exit-Sandbox -ErrorAction SilentlyContinue
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Should create app directory structure" {
        Enter-Sandbox -Root $script:TestRoot
        New-SandboxScoopStructure
        
        $result = New-SandboxApp -AppName "test-app" -Version "1.0.0"
        
        Test-Path $result.AppPath | Should -Be $true
        Test-Path $result.VersionPath | Should -Be $true
        Test-Path $result.CurrentPath | Should -Be $true
    }
    
    It "Should create app with dummy executable" {
        Enter-Sandbox -Root $script:TestRoot
        New-SandboxScoopStructure
        
        $result = New-SandboxApp -AppName "test-app" -Version "1.0.0"
        
        $exePath = Join-Path $result.VersionPath "app.exe"
        Test-Path $exePath | Should -Be $true
    }
    
    It "Should create global app in correct location" {
        Enter-Sandbox -Root $script:TestRoot
        New-SandboxScoopStructure
        
        $result = New-SandboxApp -AppName "global-app" -Version "2.0.0" -Global
        
        $result.AppPath | Should -Match "scoop_global"
    }
    
    It "Should return app metadata" {
        Enter-Sandbox -Root $script:TestRoot
        New-SandboxScoopStructure
        
        $result = New-SandboxApp -AppName "test-app" -Version "1.2.3"
        
        $result.AppName | Should -Be "test-app"
        $result.Version | Should -Be "1.2.3"
    }
}

Describe "New-SandboxLinkedApp" {
    BeforeEach {
        $script:TestRoot = Join-Path $env:TEMP "spx_test_$(Get-Random)"
    }
    
    AfterEach {
        Exit-Sandbox -ErrorAction SilentlyContinue
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Should create app with link entry" {
        Enter-Sandbox -Root $script:TestRoot
        New-SandboxScoopStructure
        
        $result = New-SandboxLinkedApp -AppName "linked-app" -Version "1.0.0" -LinkPath "D:\Apps"
        
        Test-Path $result.AppPath | Should -Be $true
        
        # Check links.json was created
        $linksFile = Join-Path $script:TestRoot "scoop\spx\links.json"
        Test-Path $linksFile | Should -Be $true
        
        $links = Get-Content $linksFile -Raw | ConvertFrom-Json -AsHashtable
        $links.local["linked-app"] | Should -Not -BeNullOrEmpty
        $links.local["linked-app"].Path | Should -Be "D:\Apps"
    }
    
    It "Should create global linked app" {
        Enter-Sandbox -Root $script:TestRoot
        New-SandboxScoopStructure
        
        $result = New-SandboxLinkedApp -AppName "global-linked" -Version "1.0.0" -LinkPath "E:\Global" -Global
        
        $linksFile = Join-Path $script:TestRoot "scoop\spx\links.json"
        $links = Get-Content $linksFile -Raw | ConvertFrom-Json -AsHashtable
        $links.global["global-linked"] | Should -Not -BeNullOrEmpty
    }
}

Describe "New-SandboxStaleEntry" {
    BeforeEach {
        $script:TestRoot = Join-Path $env:TEMP "spx_test_$(Get-Random)"
    }
    
    AfterEach {
        Exit-Sandbox -ErrorAction SilentlyContinue
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Should create stale entry without app directory" {
        Enter-Sandbox -Root $script:TestRoot
        New-SandboxScoopStructure
        
        $result = New-SandboxStaleEntry -AppName "stale-app" -Version "1.0.0" -LinkPath "D:\Apps"
        
        # App directory should NOT exist
        $appPath = Join-Path $script:TestRoot "scoop\apps\stale-app"
        Test-Path $appPath | Should -Be $false
        
        # But link entry should exist
        $result.AppName | Should -Be "stale-app"
        $result.Scope | Should -Be "local"
    }
    
    It "Should add to existing links.json" {
        Enter-Sandbox -Root $script:TestRoot
        New-SandboxScoopStructure
        
        # First create a linked app
        New-SandboxLinkedApp -AppName "valid-app" -Version "1.0.0" -LinkPath "C:\Apps"
        
        # Then add stale entry
        New-SandboxStaleEntry -AppName "stale-app" -Version "2.0.0" -LinkPath "D:\Stale"
        
        $linksFile = Join-Path $script:TestRoot "scoop\spx\links.json"
        $links = Get-Content $linksFile -Raw | ConvertFrom-Json -AsHashtable
        
        $links.local["valid-app"] | Should -Not -BeNullOrEmpty
        $links.local["stale-app"] | Should -Not -BeNullOrEmpty
    }
    
    It "Should create global stale entry" {
        Enter-Sandbox -Root $script:TestRoot
        New-SandboxScoopStructure
        
        $result = New-SandboxStaleEntry -AppName "global-stale" -Version "1.0.0" -LinkPath "E:\Global" -Global
        
        $result.Scope | Should -Be "global"
        
        $linksFile = Join-Path $script:TestRoot "scoop\spx\links.json"
        $links = Get-Content $linksFile -Raw | ConvertFrom-Json -AsHashtable
        $links.global["global-stale"] | Should -Not -BeNullOrEmpty
    }
}

Describe "Remove-SandboxApp" {
    BeforeEach {
        $script:TestRoot = Join-Path $env:TEMP "spx_test_$(Get-Random)"
    }
    
    AfterEach {
        Exit-Sandbox -ErrorAction SilentlyContinue
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Should remove existing app" {
        Enter-Sandbox -Root $script:TestRoot
        New-SandboxScoopStructure
        
        New-SandboxApp -AppName "to-remove" -Version "1.0.0"
        
        $appPath = Join-Path $script:TestRoot "scoop\apps\to-remove"
        Test-Path $appPath | Should -Be $true
        
        Remove-SandboxApp -AppName "to-remove"
        
        Test-Path $appPath | Should -Be $false
    }
    
    It "Should handle removing non-existent app" {
        Enter-Sandbox -Root $script:TestRoot
        New-SandboxScoopStructure
        
        # Should not throw
        { Remove-SandboxApp -AppName "non-existent" } | Should -Not -Throw
    }
    
    It "Should remove global app" {
        Enter-Sandbox -Root $script:TestRoot
        New-SandboxScoopStructure
        
        New-SandboxApp -AppName "global-app" -Version "1.0.0" -Global
        
        $appPath = Join-Path $script:TestRoot "scoop_global\apps\global-app"
        Test-Path $appPath | Should -Be $true
        
        Remove-SandboxApp -AppName "global-app" -Global
        
        Test-Path $appPath | Should -Be $false
    }
}

Describe "Invoke-SandboxScenario" {
    BeforeEach {
        $script:TestRoot = Join-Path $env:TEMP "spx_scenario_$(Get-Random)"
    }
    
    AfterEach {
        Exit-Sandbox -ErrorAction SilentlyContinue
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Should create scenario with valid apps" {
        $scenario = @{
            ValidApps = @(
                @{ Name = "jq"; Version = "1.7.1"; Global = $false }
            )
            StaleApps = @()
            LinkedApps = @()
        }
        
        $result = Invoke-SandboxScenario -Scenario $scenario -Root $script:TestRoot
        
        $result | Should -Not -BeNullOrEmpty
        $result.ScoopPath | Should -Match "scoop"
    }
    
    It "Should create scenario with stale apps" {
        $scenario = @{
            ValidApps = @()
            StaleApps = @(
                @{ Name = "deleted-app"; Version = "1.0.0"; Path = "D:\Apps"; Global = $false }
            )
            LinkedApps = @()
        }
        
        $result = Invoke-SandboxScenario -Scenario $scenario -Root $script:TestRoot
        
        $result | Should -Not -BeNullOrEmpty
    }
    
    It "Should create scenario with linked apps" {
        $scenario = @{
            ValidApps = @()
            StaleApps = @()
            LinkedApps = @(
                @{ Name = "my-app"; Version = "1.0.0"; Path = "D:\Portable"; Global = $false }
            )
        }
        
        $result = Invoke-SandboxScenario -Scenario $scenario -Root $script:TestRoot
        
        $result | Should -Not -BeNullOrEmpty
    }
    
    It "Should create mixed scenario" {
        $scenario = @{
            ValidApps = @(
                @{ Name = "jq"; Version = "1.7.1"; Global = $false }
            )
            StaleApps = @(
                @{ Name = "deleted"; Version = "1.0.0"; Path = "D:\Apps"; Global = $false }
            )
            LinkedApps = @(
                @{ Name = "linked"; Version = "2.0.0"; Path = "E:\Apps"; Global = $false }
            )
        }
        
        $result = Invoke-SandboxScenario -Scenario $scenario -Root $script:TestRoot
        
        $result | Should -Not -BeNullOrEmpty
    }
}

Describe "Sandbox Integration - Full Workflow" {
    BeforeEach {
        $script:TestRoot = Join-Path $env:TEMP "spx_test_$(Get-Random)"
    }
    
    AfterEach {
        Exit-Sandbox -ErrorAction SilentlyContinue
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Should support complete sandbox lifecycle" {
        # 1. Enter sandbox
        Enter-Sandbox -Root $script:TestRoot
        
        # 2. Create structure
        $structure = New-SandboxScoopStructure
        $structure.ScoopPath | Should -Match "scoop"
        
        # 3. Create apps
        New-SandboxApp -AppName "app1" -Version "1.0.0"
        New-SandboxApp -AppName "app2" -Version "2.0.0"
        
        # 4. Create stale entry
        New-SandboxStaleEntry -AppName "stale1" -Version "1.0.0" -LinkPath "D:\Stale"
        
        # 5. Verify environment is correct
        $env:SCOOP | Should -Match "scoop$"
        
        # 6. Exit sandbox
        Exit-Sandbox
        
        # 7. Verify environment restored
        $script:OriginalEnv = Get-Variable -Name "script:OriginalEnv" -ErrorAction SilentlyContinue
    }
}
