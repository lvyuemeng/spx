param(
    [Parameter(ValueFromRemainingArguments = $true)]
    $args
)

. "$PSScriptRoot/../lib/parse.ps1"
. "$PSScriptRoot/../lib/config.ps1"
. "$PSScriptRoot/../lib/move.ps1"

Write-Debug "[sync]: args: $args, count: $($args.Count)"

$pkgs, $opts = opts "--global", "-g" $args
$global = $opts["--global"] -or $opts["-g"]
Write-Debug "[sync]: pkgs: $pkgs"
Write-Debug "[sync]: global: $global"

$cfg = get_inventory
$cfg = if ($global) { $cfg["global"] } else { $cfg["local"] }

$sync_apps = if (-Not $pkgs) { 
    $cfg.Keys 
}
else { 
    $pkgs | Where-Object { $cfg.ContainsKey($_) }
}
foreach ($pkg in $sync_apps) {
    $path = $cfg[$pkg].Path
    Write-Debug "[sync]: app: $pkg; path: $path"
    move_pkg $pkg $path -Global:$global
}