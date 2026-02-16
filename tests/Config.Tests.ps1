# SPX Config Module Tests
# Tests for configuration management functions

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
    . "$PSScriptRoot/../lib/Config.ps1"
}

Describe "Get-LinksConfig" {
    BeforeEach {
        # Reset mocks for each test
        Mock Test-Path { return $true } -ParameterFilter { $Path -like "*links.json*" }
        Mock Get-Item { return [PSCustomObject]@{ Length = 100 } } -ParameterFilter { $Path -like "*links.json*" }
        Mock Get-Content { 
            return '{"global":{},"local":{"testapp":{"Path":"D:\\Apps","Version":"1.0.0"}}}'
        } -ParameterFilter { $Path -like "*links.json*" }
    }
    
    It "Should return a hashtable" {
        $result = Get-LinksConfig
        $result | Should -BeOfType [hashtable]
    }
    
    It "Should contain global and local scopes" {
        $result = Get-LinksConfig
        $result.ContainsKey("global") | Should -Be $true
        $result.ContainsKey("local") | Should -Be $true
    }
    
    It "Should handle malformed JSON gracefully" {
        Mock Get-Content { return "invalid json" } -ParameterFilter { $Path -like "*links.json*" }
        
        $result = Get-LinksConfig
        $result.ContainsKey("global") | Should -Be $true
        $result.ContainsKey("local") | Should -Be $true
    }
}

Describe "Set-LinksConfig" {
    BeforeEach {
        Mock Set-Content { } -ParameterFilter { $Path -like "*links.json*" }
    }
    
    It "Should call Set-Content with JSON content" {
        $config = @{
            "global" = @{}
            "local" = @{
                "testapp" = @{
                    Path = "D:\Apps"
                    Version = "1.0.0"
                }
            }
        }
        
        Set-LinksConfig -Config $config
        
        Should -Invoke Set-Content -ParameterFilter { $Path -like "*links.json*" }
    }
}

Describe "Get-AppLinkEntry" {
    BeforeEach {
        Mock Get-LinksConfig {
            return @{
                "global" = @{}
                "local" = @{
                    "testapp" = @{
                        Path = "D:\Apps"
                        Version = "1.0.0"
                        Updated = "2024-01-01 12:00:00"
                    }
                }
            }
        }
    }
    
    It "Should return entry for existing app" {
        $result = Get-AppLinkEntry -AppName "testapp"
        
        $result | Should -Not -Be $null
        $result.Path | Should -Be "D:\Apps"
        $result.Version | Should -Be "1.0.0"
    }
    
    It "Should return null for non-existing app" {
        $result = Get-AppLinkEntry -AppName "nonexistent"
        
        $result | Should -Be $null
    }
    
    It "Should respect Global switch" {
        $result = Get-AppLinkEntry -AppName "testapp" -Global
        
        $result | Should -Be $null
    }
}
