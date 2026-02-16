# SPX Parse - Argument Parsing Utilities
# Provides functions for parsing command-line arguments

function Get-ParsedOptions {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [string[]]$Flags,
        
        [Parameter(ValueFromRemainingArguments = $true)]
        $Arguments
    )
    
    if (-not $Arguments -or $Arguments.Count -eq 0) {
        return @{
            Packages = @()
            Options  = @{}
        }
    }
    
    $packages = @()
    $options = @{}
    $i = 0
    
    while ($i -lt $Arguments.Count) {
        $current = $Arguments[$i]
        
        if ($current.StartsWith('-')) {
            # Parse flag
            $values = @()
            $i++
            
            # Collect flag values until next flag or end
            while ($i -lt $Arguments.Count -and -not $Arguments[$i].StartsWith('-')) {
                $values += $Arguments[$i]
                $i++
            }
            
            # Store based on value count
            switch ($values.Count) {
                0 { $options[$current] = $true }
                1 { $options[$current] = $values[0] }
                Default { $options[$current] = $values }
            }
        } else {
            # Parse package name
            $packages += $current
            $i++
        }
    }
    
    return @{
        Packages = $packages
        Options  = $options
    }
}

function Invoke-ScriptWithArgs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        
        [Parameter(ValueFromRemainingArguments = $true)]
        $Arguments
    )
    
    # Flatten arguments for proper invocation
    $formattedArgs = foreach ($arg in $Arguments) {
        if (-not $arg) {
            ""
        } elseif ($arg -is [array] -or ($arg -is [System.Collections.IEnumerable] -and $arg -isnot [string])) {
            $arg -join ", "
        } else {
            $arg.ToString()
        }
    }
    
    $command = "$ScriptPath $($formattedArgs -join ' ')"
    Write-Debug "[Invoke-ScriptWithArgs]: $command"
    
    Invoke-Expression $command
}

function Test-PathValid {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    # Check if path is a valid container path and doesn't contain "scoop"
    if ((Test-Path $Path -PathType Container -IsValid) -and (-not $Path.Contains("scoop"))) {
        return $true
    }
    
    return $false
}

function Resolve-TargetPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    if (-not (Test-PathValid $Path)) {
        Write-Error "Path '$Path' is not a valid directory path or contains 'scoop'." -ErrorAction Stop
        return $null
    }
    
    return [System.IO.Path]::GetFullPath($Path)
}
