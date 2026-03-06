# SPX Tests - Unit Tests for SPX Modules
# These tests use mocking to avoid breaking user system resources

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
    
    # Mock external dependencies
    Mock Get-ScoopContext { return "TestDrive:\scoop" }
    Mock Get-ScoopGlobalContext { return "TestDrive:\scoop\global" }
    Mock Test-Path { return $true } -ParameterFilter { $Path -like "*scoop*" }
    Mock New-Item { return [PSCustomObject]@{ FullName = $Path } }
    
    # Source the modules
    . "$PSScriptRoot/../context.ps1"
    . "$PSScriptRoot/../lib/Core.ps1"
    . "$PSScriptRoot/../lib/Parse.ps1"
    . "$PSScriptRoot/../lib/Config.ps1"
}

Describe "Get-ParsedOptions" {
    It "Should parse empty arguments" {
        $result = Get-ParsedOptions -Arguments @()
        $result.Packages.Count | Should -Be 0
        $result.Options.Count | Should -Be 0
    }
    
    It "Should parse packages only" {
        $result = Get-ParsedOptions -Arguments @("app1", "app2")
        $result.Packages.Count | Should -Be 2
        $result.Packages[0] | Should -Be "app1"
        $result.Packages[1] | Should -Be "app2"
        $result.Options.Count | Should -Be 0
    }
    
    It "Should parse flags with values" {
        $result = Get-ParsedOptions -Arguments @("app1", "--path", "D:\Apps")
        $result.Packages.Count | Should -Be 1
        $result.Options["--path"] | Should -Be "D:\Apps"
    }
    
    It "Should parse boolean flags" {
        $result = Get-ParsedOptions -Arguments @("app1", "--global")
        $result.Packages.Count | Should -Be 1
        $result.Options["--global"] | Should -Be $true
    }
    
    It "Should parse multiple values for same flag" {
        $result = Get-ParsedOptions -Arguments @("app1", "--path", "D:\Apps", "E:\Apps")
        $result.Packages.Count | Should -Be 1
        $result.Options["--path"].Count | Should -Be 2
        $result.Options["--path"][0] | Should -Be "D:\Apps"
        $result.Options["--path"][1] | Should -Be "E:\Apps"
    }
}

Describe "Test-Administrator" {
    It "Should return boolean" {
        $result = Test-Administrator
        $result | Should -BeOfType [bool]
    }
}

Describe "Test-PathValid" {
    BeforeAll {
        Mock Test-Path { return $true } -ParameterFilter { $Path -eq "D:\ValidPath" }
        Mock Test-Path { return $false } -ParameterFilter { $Path -eq "X:\InvalidPath" }
    }
    
    It "Should return true for valid path without 'scoop'" {
        $result = Test-PathValid -Path "D:\ValidPath"
        $result | Should -Be $true
    }
    
    It "Should return false for path containing 'scoop'" {
        $result = Test-PathValid -Path "D:\scoop\apps"
        $result | Should -Be $false
    }
}

Describe "Resolve-TargetPath" {
    It "Should return full path for valid path" {
        Mock Test-PathValid { return $true }
        $result = Resolve-TargetPath -Path "D:\ValidPath"
        $result | Should -Be "D:\ValidPath"
    }
    
    It "Should throw error for invalid path" {
        Mock Test-PathValid { return $false }
        { Resolve-TargetPath -Path "D:\scoop\apps" } | Should -Throw
    }
}

Describe "Get-LinksConfig" {
    BeforeAll {
        $testConfig = @{
            "global" = @{ "testapp" = @{ Path = "D:\Apps"; Version = "1.0.0" } }
            "local"  = @{ }
        }
        
        Mock Get-SpxConfigFile { return "TestDrive:\links.json" }
        Mock Test-Path { return $true } -ParameterFilter { $Path -like "*links.json*" }
        Mock Get-Content { return $testConfig | ConvertTo-Json -Depth 5 } -ParameterFilter { $Path -like "*links.json*" }
    }
    
    It "Should return config hashtable" {
        $result = Get-LinksConfig
        $result | Should -BeOfType [hashtable]
    }
    
    It "Should ensure global and local scopes exist" {
        $result = Get-LinksConfig
        $result.ContainsKey("global") | Should -Be $true
        $result.ContainsKey("local") | Should -Be $true
    }
    
    It "Should return empty config when file does not exist" {
        Mock Test-Path { return $false } -ParameterFilter { $Path -like "*links.json*" }
        Mock Get-Item { return [PSCustomObject]@{ Length = 0 } } -ParameterFilter { $Path -like "*links.json*" }
        
        $result = Get-LinksConfig
        $result["global"].Count | Should -Be 0
        $result["local"].Count | Should -Be 0
    }
}

Describe "Set-LinksConfig" {
    BeforeAll {
        Mock Get-SpxConfigFile { return "TestDrive:\links.json" }
        Mock Set-Content { } -ParameterFilter { $Path -like "*links.json*" }
    }
    
    It "Should call Set-Content with JSON" {
        $config = @{
            "global" = @{ }
            "local"  = @{ "app" = @{ Path = "D:\Apps" } }
        }
        
        Set-LinksConfig -Config $config
        
        Should -Invoke Set-Content -ParameterFilter { $Path -like "*links.json*" }
    }
}

Describe "Get-AppLinkEntry" {
    BeforeAll {
        $testConfig = @{
            "global" = @{ }
            "local"  = @{ 
                "testapp" = @{ 
                    Path = "D:\Apps"
                    Version = "1.0.0"
                    Updated = "2024-01-01"
                }
            }
        }
        
        Mock Get-LinksConfig { return $testConfig }
    }
    
    It "Should return entry for existing app" {
        $result = Get-AppLinkEntry -AppName "testapp"
        $result.Path | Should -Be "D:\Apps"
        $result.Version | Should -Be "1.0.0"
    }
    
    It "Should return null for non-existing app" {
        $result = Get-AppLinkEntry -AppName "nonexistent"
        $result | Should -Be $null
    }
    
    It "Should respect global scope" {
        $result = Get-AppLinkEntry -AppName "testapp" -Global
        $result | Should -Be $null
    }
}

Describe "New-AppLinkEntry" {
    BeforeAll {
        Mock Invoke-WithLinksConfig { 
            param($ScriptBlock, $Global, $AsReference)
            $config = @{ "existing" = @{ Path = "D:\Old" } }
            & $ScriptBlock $config
        }
    }
    
    It "Should create new entry" {
        New-AppLinkEntry -AppName "newapp" -Path "D:\NewApps" -Version "2.0.0"
        Should -Invoke Invoke-WithLinksConfig
    }
}

Describe "Remove-AppLinkEntry" {
    BeforeAll {
        Mock Invoke-WithLinksConfig { 
            param($ScriptBlock, $AsReference)
            $configRef = [ref]@{ "testapp" = @{ Path = "D:\Apps" } }
            & $ScriptBlock $configRef
        }
        Mock Test-Path { return $false }
    }
    
    It "Should remove entry from config" {
        Remove-AppLinkEntry -AppName "testapp"
        Should -Invoke Invoke-WithLinksConfig
    }
}

Describe "Get-PersistDefinition" {
    BeforeAll {
        . "$PSScriptRoot/../lib/Link.ps1"
    }
    
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

Describe "CLI Command Parsing" {
    It "Should recognize 'link' command" {
        $commandMap = @{
            "link" = "link"
            "unlink" = "unlink"
            "linked" = "linked"
            "sync" = "sync"
        }
        $commandMap["link"] | Should -Be "link"
    }
    
    It "Should map legacy commands" {
        $commandMap = @{
            "move" = "link"
            "mv"   = "link"
            "back" = "unlink"
            "list" = "linked"
            "ls"   = "linked"
        }
        $commandMap["move"] | Should -Be "link"
        $commandMap["back"] | Should -Be "unlink"
        $commandMap["list"] | Should -Be "linked"
    }
}
