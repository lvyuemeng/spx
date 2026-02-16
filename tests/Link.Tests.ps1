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
        function Get-SpxConfigFile { param($Name, $CreateIfMissing) }
    }
    
    # Mock context functions
    Mock Get-ScoopContext { return "TestDrive:\scoop" }
    Mock Get-ScoopGlobalContext { return "TestDrive:\scoop\global" }
    Mock Get-SpxConfigPath { return "TestDrive:\scoop\spx" }
    Mock Get-SpxConfigFile { 
        param($Name, $CreateIfMissing)
        return "TestDrive:\scoop\spx\$Name" 
    }
    
    # Source the modules
    . "$PSScriptRoot/../context.ps1"
    . "$PSScriptRoot/../lib/Core.ps1"
    . "$PSScriptRoot/../lib/Config.ps1"
    . "$PSScriptRoot/../modules/Link/Move.ps1"
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
        . "$PSScriptRoot/../modules/Link/Link.ps1"
        
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
        . "$PSScriptRoot/../modules/Link/Link.ps1"
        
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
        . "$PSScriptRoot/../modules/Link/Link.ps1"
        
        Mock Get-AppLinkList {
            return @{
                "app1" = @{ Path = "D:\Apps"; Version = "1.0.0" }
                "app2" = @{ Path = "D:\Apps"; Version = "2.0.0" }
            }
        }
        Mock Update-PersistLinks { }
        Mock Test-AppLinked { return $true }
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
