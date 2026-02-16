# SPX Test Runner
# Runs all Pester tests for the SPX project

param (
    [switch]$Verbose,
    [switch]$Coverage
)

# Check if Pester is installed
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host "Installing Pester module..."
    Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
}

# Import Pester
Import-Module Pester -MinimumVersion 5.0

# Configure Pester
$config = New-PesterConfiguration
$config.Run.Path = "$PSScriptRoot"
$config.Run.Exit = $true
$config.Output.Verbosity = if ($Verbose) { "Detailed" } else { "Normal" }

# Enable code coverage if requested
if ($Coverage) {
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = @(
        "$PSScriptRoot/../lib/*.ps1"
        "$PSScriptRoot/../modules/**/*.ps1"
        "$PSScriptRoot/../exec/*.ps1"
    )
    $config.CodeCoverage.OutputPath = "$PSScriptRoot/coverage.xml"
    $config.CodeCoverage.OutputFormat = "JaCoCo"
}

# Run tests
Write-Host "Running SPX tests..." -ForegroundColor Cyan
Write-Host "Test path: $PSScriptRoot" -ForegroundColor Gray

Invoke-Pester -Configuration $config
