# SPX - Scoop Power Extensions

**SPX** (Scoop Power Extensions is a PowerShell-based enhancement toolkit for Scoop that provides orthogonal functionalities not covered by Scoop's core features.

## Motivation

Scoop is an excellent package manager for Windows, but it has limitations in certain scenarios:

- **Path constraints**: Installed apps are confined to Scoop's directory structure, making it difficult to place portable apps on separate drives or custom locations
- **Download issues**: GitHub releases can be slow or inaccessible in restricted regions
- **Bucket management**: Moving apps between buckets requires manual intervention
- **Disaster recovery**: No built-in way to backup and restore configurations

SPX addresses these gaps with orthogonal features that complement Scoop without duplicating functionality. Each feature is an independent module with clear boundaries, following a "safety first" approach where destructive operations require confirmation and all operations are reversible where possible.

## Installation

### Prerequisites

- Windows 10 or later
- PowerShell 5.1 or later
- [Scoop](https://scoop.sh/) package manager

### Install via Scoop (Recommended)

```powershell
scoop bucket add spx https://github.com/yourusername/spx
scoop install spx
```

### Manual Installation

1. Clone this repository to your preferred location:
   ```powershell
   git clone https://github.com/yourusername/spx.git
   ```

2. Add the SPX directory to your PATH, or create an alias:
   ```powershell
   Set-Alias -Name spx -Value "path\to\spx\spx.ps1"
   ```

## Usage

### Global Options

```
-h, --help       Show help
-v, --verbose    Enable verbose output
-d, --debug      Enable debug output
--global         Operate on global apps
--yes            Skip confirmation prompts
```

### LINK Module - Custom Path Management

Relocate installed packages to custom paths via symbolic links.

```powershell
# Move app to custom path
spx link 7zip --path D:\MyPortableApps

# Restore app to Scoop directory
spx unlink 7zip

# List all linked apps
spx linked

# Sync linked app states
spx sync 7zip
spx sync  # sync all linked apps
```

### MIRROR Module - Download Source Management

Configure alternative download mirrors for packages.

```powershell
# List configured mirrors
spx mirror list

# Add mirror rule
spx mirror add "github.com/*" "https://mirror.ghproxy.com/"

# Remove mirror rule
spx mirror remove "github.com/*"

# Enable/disable mirror system
spx mirror enable
spx mirror disable

# Test mirror connectivity
spx mirror test "github.com/*"

# Show current mirror status
spx mirror status
```

### SOURCE Module - Installed App Source Management

Change or manage the bucket/source of installed applications.

```powershell
# List all apps with their sources
spx source list

# Show detailed source info for app
spx source show 7zip

# Change app to different bucket
spx source change 7zip extras

# Verify app manifest matches bucket
spx source verify 7zip

# Compare installed vs bucket manifest
spx source diff 7zip extras
```

### BACKUP Module - Configuration Backup & Restore

Export and import Scoop configuration for migration or disaster recovery.

```powershell
# Create backup archive
spx backup create
spx backup create D:\Backups --IncludePersist

# Restore from backup
spx backup restore spx-backup-2024-01-15.zip

# List available backups
spx backup list

# Show backup status
spx backup status
```

## Configuration

SPX stores its configuration in the Scoop directory:

| Config Type | Location |
|-------------|----------|
| SPX Config | `$env:SCOOP\spx\` or `~/scoop/spx/` |
| Global Config | `$env:SCOOP_GLOBAL\spx\` or `~/scoop/apps/spx/` |
| Links Registry | `$env:SCOOP\spx\links.json` |
| Mirror Rules | `$env:SCOOP\spx\mirrors.json` |
| Backups | `$env:SCOOP\spx\backups\` |

## Migration from Legacy (scpl)

SPX is the successor to the legacy scpl tool. The command mapping is:

| Old (scpl) | New (spx) |
|------------|-----------|
| `scpl move <app> -R <path>` | `spx link <app> --path <path>` |
| `scpl back <app>` | `spx unlink <app>` |
| `scpl list` | `spx linked` |
| `scpl sync <app>` | `spx sync <app>` |

## Architecture

```
spx/
├── spx.ps1              # CLI entry point
├── context.ps1          # Scoop context resolution
├── lib/
│   ├── Core.ps1         # Shared utilities
│   ├── Parse.ps1        # Argument parsing
│   └── Config.ps1       # Configuration management
├── modules/
│   ├── Link/            # Custom path management
│   ├── Mirror/          # Download source management
│   ├── Source/          # Installed app source management
│   └── Backup/          # Configuration backup/restore
└── exec/
    ├── Link.ps1         # Link command executor
    ├── Mirror.ps1       # Mirror command executor
    ├── Source.ps1       # Source command executor
    └── Backup.ps1       # Backup command executor
```

## Development

### Design Philosophy

1. **Orthogonality**: SPX features complement Scoop without duplicating functionality
2. **Modularity**: Each feature is an independent module with clear boundaries
3. **Safety First**: Destructive operations require confirmation; all operations are reversible where possible
4. **Transparency**: Clear logging and status reporting for all operations
5. **Stateless by Default**: Modules should not record state unless absolutely necessary

### Function Naming Convention

SPX follows canonical Microsoft PowerShell naming conventions (Verb-Noun):

| Verb | Purpose | Example |
|------|---------|---------|
| `Get-` | Retrieve data | `Get-AppLink` |
| `Set-` | Modify configuration | `Set-MirrorRule` |
| `New-` | Create new resource | `New-AppLink` |
| `Remove-` | Delete resource | `Remove-AppLink` |
| `Test-` | Validate/Check | `Test-AppLinked` |
| `Invoke-` | Execute operation | `Invoke-AppSync` |
| `Export-` | Export data | `Export-Backup` |
| `Import-` | Import data | `Import-Backup` |

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-Apache](LICENSE-Apache))
- MIT license ([LICENSE-MIT](LICENSE-MIT))

at your option.
