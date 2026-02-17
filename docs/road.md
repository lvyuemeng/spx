# SPX Development Roadmap

This document tracks the implementation progress of SPX (Scoop Power Extensions) based on the design specifications in [design.md](design.md).

---

## Phase 1: Core Refactoring

> Status: **Completed** ✅

- [x] Fix critical bugs identified in inspection
- [x] Restructure to modular architecture
- [x] Implement unified CLI framework
- [x] Rename functions to Verb-Noun convention
- [x] Move config to Scoop directory

### Deliverables

| Component | File | Status |
|-----------|------|--------|
| CLI Entry Point | [`spx.ps1`](../spx.ps1) | ✅ Done |
| Context Resolution | [`context.ps1`](../context.ps1) | ✅ Done |
| Core Utilities | [`lib/Core.ps1`](../lib/Core.ps1) | ✅ Done |
| Argument Parsing | [`lib/Parse.ps1`](../lib/parse.ps1) | ✅ Done |
| Configuration Management | [`lib/Config.ps1`](../lib/config.ps1) | ✅ Done |

---

## Phase 2: Module Migration

> Status: **Completed** ✅

- [x] Migrate link module from legacy version
- [x] Change `-R` flag to `--path`/`--to`
- [x] Add `linked` and `unlink` commands
- [x] Implement configuration management

### Deliverables

| Component | File | Status |
|-----------|------|--------|
| Link Module | [`modules/Link/Link.ps1`](../modules/Link/Link.ps1) | ✅ Done |
| Move Utilities | [`modules/Link/Move.ps1`](../modules/Link/Move.ps1) | ✅ Done |
| Link Executor | [`exec/link.ps1`](../exec/link.ps1) | ✅ Done |
| Unlink Executor | [`exec/unlink.ps1`](../exec/unlink.ps1) | ✅ Done |
| Linked Executor | [`exec/linked.ps1`](../exec/linked.ps1) | ✅ Done |
| Sync Executor | [`exec/sync.ps1`](../exec/sync.ps1) | ✅ Done |

### Link Module Functions

| Function | Status |
|----------|--------|
| [`New-AppLink`](../modules/Link/Link.ps1:29) | ✅ Done |
| [`Remove-AppLink`](../modules/Link/Link.ps1:123) | ✅ Done |
| [`Get-AppLink`](../modules/Link/Link.ps1:203) | ✅ Done |
| [`Get-AppLinkList`](../modules/Link/Link.ps1:234) | ✅ Done |
| [`Test-AppLinked`](../modules/Link/Link.ps1:265) | ✅ Done |
| [`Invoke-AppSync`](../modules/Link/Link.ps1:295) | ✅ Done |

---

## Phase 3: New Modules

> Status: **Completed** ✅

### 3.1 Source Module - Installed App Source Management

- [x] Create `modules/Source/Source.ps1`
- [x] Create `exec/Source.ps1`
- [x] Implement stateless bucket validation
- [x] Add manifest comparison functionality

#### Commands Implemented

```
spx source list                          List all apps with their sources
spx source show <app>                    Show detailed source info for app
spx source change <app> <bucket>         Change app to different bucket
spx source verify [<app>]                Verify app manifest matches bucket
spx source diff <app> <bucket>           Compare installed vs bucket manifest
```

#### Functions Implemented

| Function | Status |
|----------|--------|
| [`Get-AppSource`](../modules/Source/Source.ps1:14) | ✅ Done |
| [`Get-AppSourceList`](../modules/Source/Source.ps1:78) | ✅ Done |
| [`Move-AppSource`](../modules/Source/Source.ps1:115) | ✅ Done |
| [`Test-AppInBucket`](../modules/Source/Source.ps1:191) | ✅ Done |
| [`Compare-AppManifest`](../modules/Source/Source.ps1:258) | ✅ Done |
| [`Test-AppSourceValid`](../modules/Source/Source.ps1:313) | ✅ Done |

**Note**: This module is **stateless** - no `sources.json` is maintained. Operations read directly from Scoop's installed apps and bucket manifests.

---

### 3.2 Backup Module - Configuration Backup & Restore

- [x] Create `modules/Backup/Backup.ps1`
- [x] Create `exec/Backup.ps1`
- [x] Implement backup archive creation
- [x] Implement restore functionality

#### Commands Implemented

```
spx backup create [path]                 Create backup archive
spx backup restore <archive>             Restore from backup
spx backup list                          List available backups
spx backup status                        Show backup status
```

#### Functions Implemented

| Function | Status |
|----------|--------|
| [`New-Backup`](../modules/Backup/Backup.ps1:34) | ✅ Done |
| [`Restore-Backup`](../modules/Backup/Backup.ps1:96) | ✅ Done |
| [`Get-BackupList`](../modules/Backup/Backup.ps1:152) | ✅ Done |
| [`Get-BackupStatus`](../modules/Backup/Backup.ps1:200) | ✅ Done |

#### Backup Contents

- Installed app list with versions
- Bucket configurations
- SPX configurations (links, mirrors)
- Scoop config.json
- Persist data (optional)

---

### ~~3.3 Mirror Module~~ - Removed

> **Decision**: The Mirror module was removed because:
> - URL rewriting requires intercepting Scoop's download process (complex, fragile)
> - Many bucket sources already provide mirror-prepared buckets
> - Not orthogonal to other modules - overlaps with network/proxy configuration

---

## Phase 4: Polish

> Status: **In Progress** 🔄

- [x] Add comprehensive tests
- [ ] Write documentation
- [ ] Create migration tool
- [ ] Publish to Scoop bucket

### Test Coverage

| Test File | Status |
|-----------|--------|
| [`tests/SPX.Tests.ps1`](../tests/SPX.Tests.ps1) | ✅ Done |
| [`tests/Link.Tests.ps1`](../tests/Link.Tests.ps1) | ✅ Done |
| [`tests/Config.Tests.ps1`](../tests/Config.Tests.ps1) | ✅ Done |
| [`tests/TestHelpers.ps1`](../tests/TestHelpers.ps1) | ✅ Done |
| [`tests/RunTests.ps1`](../tests/RunTests.ps1) | ✅ Done |
| [`tests/Source.Tests.ps1`](../tests/Source.Tests.ps1) | ✅ Done |
| [`tests/Backup.Tests.ps1`](../tests/Backup.Tests.ps1) | ✅ Done |

### Documentation

| Document | Status |
|----------|--------|
| [`README.md`](../README.md) | ✅ Done |
| [`docs/design.md`](design.md) | ✅ Done |
| [`docs/development.md`](development.md) | ✅ Done |
| [`docs/scoopQA.md`](scoopQA.md) | ✅ Done |
| User Guide | ⬜ Not Started |
| API Reference | ⬜ Not Started |

---

## Summary

| Phase | Description | Status |
|-------|-------------|--------|
| Phase 1 | Core Refactoring | ✅ Completed |
| Phase 2 | Module Migration (Link) | ✅ Completed |
| Phase 3 | New Modules (Source, Backup) | ✅ Completed |
| Phase 4 | Polish | 🔄 In Progress |

### Overall Progress

```
██████████████████████░░░░ 90%
```

---

## Module Orthogonality

| Module | Question Answered | State |
|--------|-------------------|-------|
| **Link** | Where is my app installed? | Stateful (links.json) |
| **Source** | Which bucket owns my app? | Stateless |
| **Backup** | How do I migrate my setup? | Stateful (archives) |

Each module answers a distinct question without overlapping concerns.

---

## Next Steps

1. **Tests** - Add tests for Source and Backup modules
2. **Documentation** - Complete user guide and API reference
3. **Migration Tool** - Create tool for migrating from legacy SPX version
4. **Publish** - Publish to Scoop bucket for easy installation
