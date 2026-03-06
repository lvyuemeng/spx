# SPX Link Module Tests
# Tests for the Link module functions using mocking

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
        function Get-SpxConfigFile { param($Name, [switch]$CreateIfMissing) }
    }
    
    # Mock context functions
    Mock Get-ScoopContext { return "TestDrive:\scoop" }
    Mock Get-ScoopGlobalContext { return "TestDrive:\scoop\global" }
    Mock Get-SpxConfigPath { return "TestDrive:\scoop\spx" }
    Mock Get-SpxConfigFile { 
        param($Name, [switch]$CreateIfMissing)
        return "TestDrive:\scoop\spx\$Name" 
    }
    
    # Source the modules
    . "$PSScriptRoot/../context.ps1"
    . "$PSScriptRoot/../lib/Core.ps1"
    . "$PSScriptRoot/../lib/Config.ps1"
    . "$PSScriptRoot/../lib/Link.ps1"
}

Describe "Get-PersistDefinition" {
    It "Should parse string persist definition" {
        $src, $tg = Get-PersistDefinition -Persist "data"
        $src | Should -Be "data"
        $tg | Should -Be "data"
    }
    
    It "Should parse array persist definition with both elements" {
        $src, $tg = Get-PersistDefinition -Persist @("source", "target")
        $src | Should -Be "source"
        $tg | Should -Be "target"
    }
    
    It "Should parse array persist definition with null target" {
        $src, $tg = Get-PersistDefinition -Persist @("source", $null)
        $src | Should -Be "source"
        $tg | Should -Be "source"
    }
}

Describe "Test-AppLinked" {
    BeforeAll {
        . "$PSScriptRoot/../lib/Link.ps1"
        
        Mock Get-AppLinkEntry {
            param($AppName)
            if ($AppName -eq "linkedapp") {
                return @{ Path = "D:\Apps"; Version = "1.0.0" }
            }
            return $null
        }
    }
    
    It "Should return true for linked app" {
        $result = Test-AppLinked -AppName "linkedapp"
        $result | Should -Be $true
    }
    
    It "Should return false for non-linked app" {
        $result = Test-AppLinked -AppName "notlinked"
        $result | Should -Be $false
    }
}

Describe "Get-AppLinkList" {
    BeforeAll {
        . "$PSScriptRoot/../lib/Link.ps1"
        
        Mock Get-LinksConfig {
            return @{
                "local" = @{
                    "app1" = @{ Path = "D:\Apps"; Version = "1.0.0" }
                }
                "global" = @{
                    "app2" = @{ Path = "E:\Apps"; Version = "2.0.0" }
                }
            }
        }
    }
    
    It "Should return local apps by default" {
        $result = Get-AppLinkList
        $result.ContainsKey("app1") | Should -Be $true
    }
    
    It "Should return global apps when Global switch is set" {
        $result = Get-AppLinkList -Global
        $result.ContainsKey("app2") | Should -Be $true
    }
}

Describe "Invoke-AppSync" {
    BeforeAll {
        . "$PSScriptRoot/../lib/Link.ps1"
        
        Mock Get-AppLinkList {
            return @{
                "app1" = @{ Path = "D:\Apps"; Version = "1.0.0" }
                "app2" = @{ Path = "D:\Apps"; Version = "2.0.0" }
            }
        }
        Mock Update-PersistLinks { }
        Mock Test-AppLinked { return $true }
        Mock Test-AppInstalled { return $true }
    }
    
    It "Should sync single app when AppName provided" {
        Invoke-AppSync -AppName "testapp"
        
        Should -Invoke Update-PersistLinks -ParameterFilter { $AppName -eq "testapp" }
    }
    
    It "Should warn when app is not linked" {
        Mock Test-AppLinked { return $false }
        
        Invoke-AppSync -AppName "notlinked" -WarningVariable warnings
        
        $warnings | Should -Not -BeNullOrEmpty
    }
}

Describe "Get-AppManifest" {
    BeforeAll {
        # Source Link.ps1 to get the function definition (includes Move functions)
        . "$PSScriptRoot/../lib/Link.ps1"
    }
    
    It "Should return null when app version not found" {
        Mock Get-AppCurrentVersion { return $null }
        
        $result = Get-AppManifest -AppName "nonexistent"
        $result | Should -BeNullOrEmpty
    }
    
    It "Should return null when no manifest files exist" {
        Mock Get-AppCurrentVersion { return [PSCustomObject]@{ FullName = "TestDrive:\scoop\apps\testapp\21.07" } }
        Mock Test-Path { return $false }
        
        $result = Get-AppManifest -AppName "testapp"
        $result | Should -BeNullOrEmpty
    }
}

Describe "Update-PersistLinks" {
    BeforeAll {
        . "$PSScriptRoot/../lib/Link.ps1"
    }
    
    It "Should return null when app not installed" {
        Mock Get-AppCurrentVersion { return $null }
        
        $result = Update-PersistLinks -AppName "nonexistent"
        $result | Should -BeNullOrEmpty
    }
    
    It "Should return version when no persist defined" {
        Mock Get-AppCurrentVersion { return [PSCustomObject]@{ FullName = "TestDrive:\scoop\apps\testapp\21.07" } }
        Mock Get-AppManifest { return @{ version = "21.07" } }
        Mock Get-AppDirectory { return "TestDrive:\scoop\persist\testapp" }
        Mock Test-Path { return $true }
        
        $result = Update-PersistLinks -AppName "testapp"
        $result | Should -Not -BeNullOrEmpty
    }
    
    It "Should create persist directory if not exists" {
        Mock Get-AppCurrentVersion { return [PSCustomObject]@{ FullName = "TestDrive:\scoop\apps\testapp\21.07" } }
        Mock Get-AppManifest { return @{ persist = @("config") } }
        Mock Get-AppDirectory { return "TestDrive:\scoop\persist\testapp" }
        Mock Test-Path { return $false }
        Mock New-Item { }
        
        Update-PersistLinks -AppName "testapp"
        
        Should -Invoke New-Item -ParameterFilter { $ItemType -eq "Directory" } -Times 1
    }
    
    It "Should create symbolic link for persist path" {
        Mock Get-AppCurrentVersion { return [PSCustomObject]@{ FullName = "TestDrive:\scoop\apps\testapp\21.07" } }
        Mock Get-AppManifest { return @{ persist = @("config") } }
        Mock Get-AppDirectory { return "TestDrive:\scoop\persist\testapp" }
        Mock Test-Path { return $false }
        Mock New-Item { }
        
        Update-PersistLinks -AppName "testapp"
        
        Should -Invoke New-Item -ParameterFilter { $ItemType -eq "SymbolicLink" } -Times 1
    }
}

Describe "Get-StaleLinkEntries" {
    BeforeAll {
        . "$PSScriptRoot/../lib/Link.ps1"
    }
    
    It "Should return empty when no stale entries" {
        Mock Get-LinksConfig {
            return @{
                "local" = @{ "existingapp" = @{ Path = "D:\Apps"; Version = "1.0.0" } }
                "global" = @{}
            }
        }
        Mock Get-AppDirectory { return "TestDrive:\scoop\apps\existingapp" }
        Mock Test-Path { return $true }
        
        $result = Get-StaleLinkEntries
        $result.local.Count | Should -Be 0
    }
    
    It "Should detect stale entries when app directory doesn't exist" {
        Mock Get-LinksConfig {
            return @{
                "local" = @{ "deletedapp" = @{ Path = "D:\Apps"; Version = "2.0.0" } }
                "global" = @{}
            }
        }
        Mock Get-AppDirectory { return "TestDrive:\scoop\apps\deletedapp" }
        Mock Test-Path { return $false }
        
        $result = Get-StaleLinkEntries
        $result.local.Count | Should -Be 1
        $result.local[0].AppName | Should -Be "deletedapp"
    }
}

Describe "Remove-StaleLinkEntry" {
    BeforeAll {
        . "$PSScriptRoot/../lib/Link.ps1"
    }
    
    It "Should remove entry from config" {
        Mock Get-LinksConfig {
            return @{
                "local" = @{ "testapp" = @{ Path = "D:\Apps"; Version = "1.0.0" } }
                "global" = @{}
            }
        }
        Mock Set-LinksConfig { }
        
        Remove-StaleLinkEntry -AppName "testapp"
        
        Should -Invoke Set-LinksConfig
    }
}
