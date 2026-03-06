# SPX Link Module - Sandbox-Based Tests
# Tests for Link module functions using the Sandbox for isolation

BeforeAll {
    # Define placeholder functions for mocking
    if (-not (Get-Command 'Get-ScoopContext' -ErrorAction SilentlyContinue)) {
        function Get-ScoopContext { param() }
    }
    if (-not (Get-Command 'Get-ScoopGlobalContext' -ErrorAction SilentlyContinue)) {
        function Get-ScoopGlobalContext { param() }
    }
    
    # Source required modules
    . "$PSScriptRoot/../lib/Sandbox.ps1"
    . "$PSScriptRoot/../context.ps1"
    . "$PSScriptRoot/../lib/Core.ps1"
    . "$PSScriptRoot/../lib/Config.ps1"
    . "$PSScriptRoot/../lib/Link.ps1"
    
    # Mock Test-Administrator
    function Test-Administrator { return $true }
}

Describe "Get-AppLinkList - Sandbox" {
    BeforeEach {
        $script:TestRoot = Join-Path $env:TEMP "spx_link_test_$(Get-Random)"
        Enter-Sandbox -Root $script:TestRoot
        New-SandboxScoopStructure
        
        # Mock config path to use sandbox
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
    }
    
    AfterEach {
        Exit-Sandbox
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Should return empty when no links exist" {
        $links = Get-AppLinkList
        $links | Should -BeNullOrEmpty
    }
    
    It "Should return local links" {
        # Create linked app in sandbox
        New-SandboxLinkedApp -AppName "jq" -Version "1.7.1" -LinkPath "D:\Portable\jq"
        
        # Need to mock Get-SpxConfigPath again as it's reset per test
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
        
        $links = Get-AppLinkList
        
        $links | Should -Not -BeNullOrEmpty
        $links["jq"] | Should -Not -BeNullOrEmpty
        $links["jq"].Path | Should -Be "D:\Portable\jq"
    }
    
    It "Should return global links" {
        New-SandboxLinkedApp -AppName "vscode" -Version "1.85.0" -LinkPath "E:\GlobalApps\vscode" -Global
        
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
        
        $links = Get-AppLinkList -Global
        
        $links | Should -Not -BeNullOrEmpty
        $links["vscode"] | Should -Not -BeNullOrEmpty
        $links["vscode"].Path | Should -Be "E:\GlobalApps\vscode"
    }
    
    It "Should return both local and global links" {
        New-SandboxLinkedApp -AppName "local-app" -Version "1.0.0" -LinkPath "D:\Local"
        New-SandboxLinkedApp -AppName "global-app" -Version "2.0.0" -LinkPath "E:\Global" -Global
        
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
        
        $localLinks = Get-AppLinkList
        $globalLinks = Get-AppLinkList -Global
        
        $localLinks["local-app"] | Should -Not -BeNullOrEmpty
        $globalLinks["global-app"] | Should -Not -BeNullOrEmpty
    }
}

Describe "Get-StaleLinkEntries - Sandbox" {
    BeforeEach {
        $script:TestRoot = Join-Path $env:TEMP "spx_stale_test_$(Get-Random)"
        Enter-Sandbox -Root $script:TestRoot
        New-SandboxScoopStructure
        
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
    }
    
    AfterEach {
        Exit-Sandbox
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Should detect stale entries (links without app directories)" {
        # Create stale entries - no actual app directories
        New-SandboxStaleEntry -AppName "deleted-app" -Version "1.0.0" -LinkPath "D:\Apps"
        New-SandboxStaleEntry -AppName "another-deleted" -Version "2.0.0" -LinkPath "E:\Portable"
        
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
        
        $stale = Get-StaleLinkEntries
        
        # Should have stale entries in local scope
        $stale.local.Count | Should -BeGreaterThan 0
    }
    
    It "Should not report valid apps as stale" {
        # Create valid app (has directory)
        New-SandboxApp -AppName "valid-app" -Version "1.0.0"
        
        # Create stale entry for different app
        New-SandboxStaleEntry -AppName "stale-app" -Version "1.0.0"
        
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
        
        $stale = Get-StaleLinkEntries
        
        # Only stale-app should be in local stale entries (valid-app has directory)
        $stale.local.Count | Should -Be 1
        $stale.local[0].AppName | Should -Be "stale-app"
    }
    
    It "Should handle global stale entries" {
        New-SandboxStaleEntry -AppName "global-deleted" -Version "1.0.0" -LinkPath "E:\Global" -Global
        
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
        
        $stale = Get-StaleLinkEntries
        
        # Get-StaleLinkEntries returns both global and local in a hashtable
        $stale.global.Count | Should -BeGreaterThan 0
    }
}

Describe "Test-AppLinked - Sandbox" {
    BeforeEach {
        $script:TestRoot = Join-Path $env:TEMP "spx_testlinked_$(Get-Random)"
        Enter-Sandbox -Root $script:TestRoot
        New-SandboxScoopStructure
        
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
    }
    
    AfterEach {
        Exit-Sandbox
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Should return false for unlinked app" {
        $result = Test-AppLinked -AppName "unlinked-app"
        $result | Should -Be $false
    }
    
    It "Should return true for linked app" {
        New-SandboxLinkedApp -AppName "my-linked-app" -Version "1.0.0" -LinkPath "D:\Apps"
        
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
        
        $result = Test-AppLinked -AppName "my-linked-app"
        $result | Should -Be $true
    }
    
    It "Should return true for global linked app" {
        New-SandboxLinkedApp -AppName "global-linked" -Version "1.0.0" -LinkPath "E:\Global" -Global
        
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
        
        $result = Test-AppLinked -AppName "global-linked" -Global
        $result | Should -Be $true
    }
    
    It "Should return true for stale entry (checks link config)" {
        # Note: Test-AppLinked checks if link entry exists in config, not if app directory exists
        # So stale entries will return $true because they have a link entry
        New-SandboxStaleEntry -AppName "stale-entry" -Version "1.0.0" -LinkPath "D:\Apps"
        
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
        
        # Test-AppLinked returns true because there's a link entry, regardless of app dir
        $result = Test-AppLinked -AppName "stale-entry"
        $result | Should -Be $true
    }
}

Describe "Get-AppLink - Sandbox" {
    BeforeEach {
        $script:TestRoot = Join-Path $env:TEMP "spx_getlink_$(Get-Random)"
        Enter-Sandbox -Root $script:TestRoot
        New-SandboxScoopStructure
        
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
    }
    
    AfterEach {
        Exit-Sandbox
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Should return null for non-existent link" {
        $link = Get-AppLink -AppName "non-existent"
        $link | Should -BeNullOrEmpty
    }
    
    It "Should return link info for linked app" {
        New-SandboxLinkedApp -AppName "test-app" -Version "1.2.3" -LinkPath "D:\MyApps"
        
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
        
        $link = Get-AppLink -AppName "test-app"
        
        $link | Should -Not -BeNullOrEmpty
        $link.Path | Should -Be "D:\MyApps"
        $link.Version | Should -Be "1.2.3"
    }
    
    It "Should return link info for global app" {
        New-SandboxLinkedApp -AppName "global-app" -Version "2.0.0" -LinkPath "E:\GlobalApps" -Global
        
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
        
        $link = Get-AppLink -AppName "global-app" -Global
        
        $link | Should -Not -BeNullOrEmpty
        $link.Path | Should -Be "E:\GlobalApps"
    }
}

Describe "Scenario: Mixed App States - Sandbox" {
    BeforeEach {
        $script:TestRoot = Join-Path $env:TEMP "spx_mixed_$(Get-Random)"
        Enter-Sandbox -Root $script:TestRoot
        New-SandboxScoopStructure
        
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
    }
    
    AfterEach {
        Exit-Sandbox
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Should correctly categorize apps in mixed scenario" {
        # Set up mixed environment
        # 1. Normal app (no link)
        New-SandboxApp -AppName "normal-app" -Version "1.0.0"
        
        # 2. Linked app
        New-SandboxLinkedApp -AppName "linked-app" -Version "2.0.0" -LinkPath "D:\Apps"
        
        # 3. Stale entry (link without app directory)
        New-SandboxStaleEntry -AppName "stale-app" -Version "3.0.0" -LinkPath "E:\Stale"
        
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
        
        # Test Test-AppLinked
        Test-AppLinked -AppName "normal-app" | Should -Be $false
        Test-AppLinked -AppName "linked-app" | Should -Be $true
        # Stale entries have link entries, so Test-AppLinked returns $true
        Test-AppLinked -AppName "stale-app" | Should -Be $true
        
        # Test Get-AppLink
        $link = Get-AppLink -AppName "linked-app"
        $link.Path | Should -Be "D:\Apps"
        
        $staleLink = Get-AppLink -AppName "stale-app"
        $staleLink | Should -Not -BeNullOrEmpty
        
        # Test Get-StaleLinkEntries - should find stale-app
        $stale = Get-StaleLinkEntries
        $staleAppNames = $stale.local | ForEach-Object { $_.AppName }
        $staleAppNames | Should -Contain "stale-app"
    }
}

Describe "Scenario: Complete Link Workflow - Sandbox" {
    BeforeEach {
        $script:TestRoot = Join-Path $env:TEMP "spx_workflow_$(Get-Random)"
    }
    
    AfterEach {
        Exit-Sandbox
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Should simulate complete link/unlink workflow" {
        # Step 1: Enter sandbox and create structure
        Enter-Sandbox -Root $script:TestRoot
        New-SandboxScoopStructure
        
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
        
        # Step 2: Install app (create app directory)
        New-SandboxApp -AppName "myapp" -Version "1.0.0"
        
        # Verify app exists
        Test-Path (Join-Path $script:TestRoot "scoop\apps\myapp\1.0.0") | Should -Be $true
        
        # Step 3: Link app (create link entry)
        New-SandboxLinkedApp -AppName "myapp" -Version "1.0.0" -LinkPath "D:\Portable\myapp"
        
        Mock Get-SpxConfigPath { return Join-Path $script:TestRoot "scoop\spx" }
        
        # Verify link exists
        Test-AppLinked -AppName "myapp" | Should -Be $true
        
        # Step 4: Get link info
        $link = Get-AppLink -AppName "myapp"
        $link.Path | Should -Be "D:\Portable\myapp"
        
        # Step 5: Get all links
        $allLinks = Get-AppLinkList
        $allLinks["myapp"] | Should -Not -BeNullOrEmpty
        
        # Step 6: Remove app directory (simulate uninstall)
        Remove-SandboxApp -AppName "myapp"
        
        # Verify app directory gone
        Test-Path (Join-Path $script:TestRoot "scoop\apps\myapp") | Should -Be $false
        
        # Step 7: App should still be detected as linked (link entry exists)
        # Note: Test-AppLinked checks link config, not app directory existence
        Test-AppLinked -AppName "myapp" | Should -Be $true
    }
}
