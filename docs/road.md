# SPX Development Roadmap

---

## Phase 1: Core Refactoring ✅

- [x] Fix critical bugs
- [x] Modular architecture
- [x] CLI framework
- [x] Verb-Noun naming

**Done**: spx.ps1, context.ps1, Core.ps1, Parse.ps1, Config.ps1

---

## Phase 2: Link Module ✅

- [x] link/unlink/linked commands
- [x] --path/--to flags
- [x] Persist link handling

**Done**: modules/Link.ps1, modules/Move.ps1, exec/Link.ps1, exec/Unlink.ps1

---

## Phase 3: New Modules ✅

### Source Module
- [x] List/show/change commands
- [x] Stateless design

### Backup Module  
- [x] Create/restore/list

---

## Phase 4: Polish 🔄

- [x] Tests
- [ ] Documentation
- [ ] Publish to Scoop

---

## Phase 5: Config Cleanup & State Recovery ✅

- [x] `spx cleanup [--dry-run] [--force]`
- [x] Detect stale entries
- [x] Recover (reinstall + relink) or forget
- [x] **Sandbox Testing** - Isolated test environment

**Done**: modules/Link.ps1, exec/Cleanup.ps1, 18 tests pass, lib/Sandbox.ps1

---

## Summary

```
spx cleanup [--dry-run] [--force]
```

| Flag | Description |
|------|-------------|
| `--dry-run` | Show what would be cleaned without making changes |
| `--force` | Skip confirmation prompts |

### Implementation

**Step 1: Detect Stale Entries**

```powershell
function Get-StaleLinkEntries {
    $links = Get-LinksConfig
    $stale = @{ global = @(); local = @() }
    
    foreach ($scope in @("global", "local")) {
        foreach ($app in $links[$scope].Keys) {
            $appPath = Get-AppDirectory $app -Type "app" -Global:($scope -eq "global")
            if (-not (Test-Path $appPath)) {
                $stale[$scope] += @{
                    AppName = $app
                    LinkPath = $links[$scope][$app].Path
                    StoredVersion = $links[$scope][$app].Version
                }
            }
        }
    }
    return $stale
}
```

**Step 2: Recovery Options**

For each stale entry, user can:

| Option | Action |
|--------|--------|
| **Restore** | Reinstall app via Scoop, then relink to stored path |
| **Forget** | Remove stale entry without recovery |

**Step 3: Recovery Flow**

```powershell
function Invoke-CleanupRecovery {
    param(
        [hashtable]$StaleEntries,
        [switch]$Force
    )
    
    foreach ($entry in $StaleEntries) {
        Write-Host "App: $($entry.AppName)"
        Write-Host "  Was linked to: $($entry.LinkPath)"
        
        if (-not $Force) {
            $response = Read-Host "Restore? [Y]es/[N]o/[S]kip: "
            switch ($response.ToLower()) {
                "y" { 
                    # 1. Reinstall via scoop
                    scoop install $entry.AppName
                    # 2. Relink to stored path
                    spx link $entry.AppName --path $entry.LinkPath
                }
                "n" { 
                    # Forget - remove from config
                    Remove-AppLinkEntry -AppName $entry.AppName
                }
                "s" { continue }
            }
        }
    }
}
```

### Deliverables

| File | Change |
|------|--------|
| `modules/Link.ps1` | Add `Get-StaleLinkEntries`, `Invoke-CleanupRecovery` |
| `exec/Cleanup.ps1` | New cleanup command |

### Usage

```bash
# Show stale entries (dry run)
spx cleanup --dry-run

# Interactive cleanup with prompts
spx cleanup

# Non-interactive (restore all)
spx cleanup --force
```

---

## Summary

| Phase | Status |
|-------|--------|
| Phase 1-3 | ✅ Complete |
| Phase 4 | 🔄 In Progress |
| Phase 5 | ✅ Complete (with Sandbox) |

---

## Sandbox Testing

SPX includes an isolated sandbox environment for safe testing of destructive operations like cleanup and unlink.

### Features

| Feature | Description |
|---------|-------------|
| **Fake Directory Layout** | Creates mock Scoop structure in TestDrive |
| **Env Injection** | Redirects $env:SCOOP and $env:SCOOP_GLOBAL |
| **Stale Simulation** | Create config entries without actual app dirs |
| **Scenario Builder** | Predefined test scenarios |

### Usage

```powershell
# Enter sandbox
Enter-Sandbox -Root "TestDrive:\test"

# Create structure
New-SandboxScoopStructure

# Create test apps
New-SandboxApp -AppName "jq" -Version "1.7.1"
New-SandboxStaleEntry -AppName "deleted-app" -LinkPath "D:\Apps"

# Test cleanup
& .\spx.ps1 cleanup --dry-run

# Exit and cleanup
Exit-Sandbox
```

### Files

| File | Purpose |
|------|---------|
| [`lib/Sandbox.ps1`](lib/Sandbox.ps1) | Core sandbox implementation |
| [`docs/sandbox.md`](docs/sandbox.md) | Detailed design document |

### Architecture

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Sandbox    │    │    Fake      │    │   Env        │
│   Context    │───▶│  Directory   │───▶│   Injection  │
│   Manager    │    │   Builder    │    │   Layer      │
└──────────────┘    └──────────────┘    └──────────────┘
```
