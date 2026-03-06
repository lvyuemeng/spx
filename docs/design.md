# SPX - Scoop Power Extensions

## Project Overview

**SPX** (Scoop Power Extensions) is a PowerShell enhancement toolkit for Scoop.

### Design Philosophy

1. **Orthogonality** - Features complement Scoop without duplication
2. **Modularity** - Independent modules with clear boundaries
3. **Safety First** - Destructive ops require confirmation; reversible
4. **Transparency** - Clear logging and status reporting
5. **Stateless by Default** - Don't record state unless necessary

---

## Architecture

```
spx/
├── spx.ps1              # CLI entry point
├── context.ps1          # Scoop context resolution
├── lib/
│   ├── Core.ps1         # Shared utilities
│   ├── Parse.ps1        # Argument parsing
│   ├── Config.ps1       # Configuration
│   ├── Sandbox.ps1     # Isolated test environment
│   └── Source.ps1       # Bucket/source management
├── modules/
│   └── Link.ps1         # Custom path management (includes Move functions)
└── exec/
    ├── Link.ps1         # link/unlink/linked/sync
    ├── Mirror.ps1       # mirror commands
    ├── Source.ps1       # source commands
    └── Backup.ps1       # backup commands
```

---

## Sandbox - Isolated Test Environment

The Sandbox provides an isolated test environment that creates fake Scoop directory structures and injects environment variables to prevent modifying the user's actual state.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     SPX Sandbox System                       │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   Sandbox    │    │    Fake      │    │   Env        │  │
│  │   Context    │───▶│  Directory   │───▶│   Injection  │  │
│  │   Manager    │    │   Builder    │    │   Layer      │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         │                                       │            │
│         ▼                                       ▼            │
│  ┌──────────────┐                      ┌──────────────┐    │
│  │   Cleanup    │                      │    User      │    │
│  │   Simulator  │                      │    State     │    │
│  │              │                      │  Protected   │    │
│  └──────────────┘                      └──────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Functions

| Function | Description |
|----------|-------------|
| `Enter-Sandbox` | Enter sandbox, inject test paths |
| `Exit-Sandbox` | Exit sandbox, restore original environment |
| `Get-SandboxRoot` | Get current sandbox root path |
| `New-SandboxScoopStructure` | Create fake Scoop directory structure |
| `New-SandboxApp` | Create fake app directory |
| `New-SandboxLinkedApp` | Create linked app scenario |
| `New-SandboxStaleEntry` | Create stale link entry |
| `Remove-SandboxApp` | Remove sandbox app |
| `Invoke-SandboxScenario` | Create complete test scenario |

### Environment Injection

| Variable | Original | Sandbox |
|----------|----------|---------|
| `$env:SCOOP` | User's scoop path | `TestDrive:\sandbox\scoop` |
| `$env:SCOOP_GLOBAL` | User's global scoop path | `TestDrive:\sandbox\scoop_global` |

### Predefined Scenarios

```powershell
# Scenario 1: All Valid
$Scenario1 = @{
    ValidApps = @(
        @{ Name = "jq"; Version = "1.7.1"; Global = $false }
    )
    StaleApps = @()
}

# Scenario 2: Mixed (Some Stale)
$Scenario2 = @{
    ValidApps = @(
        @{ Name = "jq"; Version = "1.7.1"; Global = $false }
    )
    StaleApps = @(
        @{ Name = "deleted-app"; Version = "1.0.0"; Path = "D:\Apps"; Global = $false }
    )
}

# Scenario 3: All Stale
$Scenario3 = @{
    ValidApps = @()
    StaleApps = @(
        @{ Name = "stale1"; Version = "1.0.0"; Path = "D:\Apps"; Global = $false }
    )
}
```

### Test Integration

```powershell
# tests/Cleanup.Sandbox.Tests.ps1

BeforeAll {
    . "$PSScriptRoot/../lib/Sandbox.ps1"
    . "$PSScriptRoot/../lib/Link.ps1"
}

Describe "Get-StaleLinkEntries" {
    BeforeEach {
        $script:SandboxRoot = "TestDrive:\test_cleanup"
        Enter-Sandbox -Root $script:SandboxRoot
        New-SandboxScoopStructure
    }
    
    AfterEach {
        Exit-Sandbox
    }
    
    It "Should detect stale entries where app directory is missing" {
        New-SandboxStaleEntry -AppName "deleted-app" -Version "1.0.0" -LinkPath "D:\Apps"
        $stale = Get-StaleLinkEntries
        $stale.local.Count | Should -Be 1
    }
}
```

---

## Configuration

| Config | Location |
|--------|----------|
| SPX Config | `$env:SCOOP/spx/` |
| Links | `$env:SCOOP/spx/links.json` |
| Mirrors | `$env:SCOOP/spx/spx.json` |

---

## Modules

### LINK - Custom Path Management

Move apps to custom paths via symbolic links. Includes persist path handling functions.

| Command | Description |
|---------|-------------|
| `spx link <app> --path <path>` | Move app to custom path |
| `spx unlink <app>` | Restore to Scoop directory |
| `spx linked` | List linked apps |
| `spx sync [<app>]` | Sync persist links |

**Functions**: `New-AppLink`, `Remove-AppLink`, `Get-AppLink`, `Get-AppLinkList`, `Test-AppLinked`, `Invoke-AppSync`, `Get-PersistDefinition`, `Get-AppManifest`, `Update-PersistLinks`

---

### SOURCE - Bucket Management

Manage app bucket sources. **Stateless** - reads directly from Scoop. (Located in `lib/Source.ps1`)

| Command | Description |
|---------|-------------|
| `spx source list` | List apps with sources |
| `spx source show <app>` | Show app source |
| `spx source change <app> <bucket>` | Change bucket |

**Functions**: `Get-AppSource`, `Get-AppSourceList`, `Move-AppSource`, `Test-AppInBucket`, `Compare-AppManifest`

---

### BACKUP - Backup & Restore

Export/import Scoop configuration.

| Command | Description |
|---------|-------------|
| `spx backup create [path]` | Create backup |
| `spx backup restore <archive>` | Restore backup |
| `spx backup list` | List backups |

---

### ~~MIRROR~~ - Removed

URL rewriting was too complex. Buckets provide mirrors instead.

---

## CLI

```
spx <module> <action> [args] [options]

Options:
  -h, --help       Help
  -v, --verbose    Verbose
  -d, --debug      Debug
  --global         Global apps
  --yes            Skip confirmations
```

---

## Function Naming

| Verb | Purpose |
|------|---------|
| `Get-` | Retrieve data |
| `Set-` | Modify config |
| `New-` | Create resource |
| `Remove-` | Delete resource |
| `Test-` | Validate |
| `Invoke-` | Execute operation |

---

## Error Handling

| Category | Behavior |
|----------|----------|
| Context | Terminate immediately |
| Validation | Return error, no action |
| Maybe | Return `$null` |
| Recoverable | Try/catch with rollback |
