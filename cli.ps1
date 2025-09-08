param (
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)

. "$PSScriptRoot/context.ps1"
. "$PSScriptRoot/lib/parse.ps1"

$helpCommands = "-h", "--help", "/?"
$commands = @{
	"move" = "move"
	"mv"   = "move"
	"sync" = "sync"
	"list" = "list"
	"ls"   = "list"
	"back" = "back"
}

$helpContext = @{
	main = @'
Usage: scoop-ext <command> [options/arguments]

Commands:
  move	[apps] [-R move_path]		- Move installed apps to a new custom path.
  back	[apps]				- Move apps back to original path.
  sync	[apps]|[*]			- Sync moved apps.
  list	[scoop_args]			- List installed apps with paths.
  
Caveat: 
  - You should install scoop first.

Common Options:
  -h, --help, /?    Display help for a command.

Examples:
  scpl move 7zip -R D:\MyPortableApps
  scpl sync 7zip
  scpl sync # sync all apps!
  scpl back 7zip
  scpl list
'@
	move = @"
Usage: scpl move [apps] [-R move_path]

You can move apps multiple times with different paths.
"@
	back = @"
Usuage: scpl back [apps]
"@
	sync = @"
Usuage: scpl sync [apps]|[*]
"@
	list = @"
Usage: scpl list [scoop_args]
"@
}

function Show-Help {
	param (
		[string]$Context = "main"
	)
	$help = $helpContext[$Context]
	if (-Not $help) {
		Write-Error "No help found for '$Context'."
		Write-Host $helpContext["main"]
	}
	Write-Host $help
}

# entry
function Invoke-Entry {
	param (
		[string]$command,
		[Parameter(ValueFromRemainingArguments = $true)]
		[string[]]$args
	)
	Write-Debug "[entry]: command: $command"
	Write-Debug "[entry]: args: $args"
	
	if (-Not $command -or $command -in $helpCommands) {
		Show-Help
		return
	}

	$normal = $commands[$command.ToLower()]
	Write-Debug "[entry]: normal: $canonical"
	if (-Not $normal) {
		# fallback to scoop
		& scoop $command @args
		return
	}

	if ($args | Where-Object { $_ -in $helpCommands }) {
		Show-Help -Context $normal
		return
	}
	
	# Safety: conanical must be exist
	$handle = "$PSScriptRoot/exec/$normal.ps1"
	Write-Debug "$handle $($args -join ' ')"
	& $handle @args
	# flatten_exec $handle @args
}

Invoke-Entry @args