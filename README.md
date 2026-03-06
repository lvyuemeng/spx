# SPX - Scoop Power Extensions

**SPX** (Scoop Power Extensions) is a PowerShell-based enhancement toolkit for Scoop that provides orthogonal functionalities not covered by Scoop's core features.

## Motivation

Scoop is an excellent package manager for Windows, but it has limitations in certain scenarios:

- **Path constraints**: Installed apps are confined to Scoop's directory structure, making it difficult to place portable apps on separate drives or custom locations
- **Bucket management**: Moving apps between buckets requires manual intervention
- **Disaster recovery**: No built-in way to backup and restore configurations

SPX addresses these gaps with orthogonal features that complement Scoop without duplicating functionality. Each feature is an independent module with clear boundaries, following a "safety first" approach where destructive operations require confirmation and all operations are reversible where possible.

## Installation

### Prerequisites

- PowerShell 5.1 or later
- [Scoop](https://scoop.sh/) package manager

### Install via Scoop (Recommended)

```powershell
scoop bucket add spx https://github.com/lvyuemeng/spx
scoop install spx
```

### Manual Installation

1. Clone this repository to your preferred location:
   ```powershell
   git clone https://github.com/lvyuemeng/spx.git
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
| Backups | `$env:SCOOP\spx\backups\` |

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-Apache](LICENSE-Apache))
- MIT license ([LICENSE-MIT](LICENSE-MIT))
