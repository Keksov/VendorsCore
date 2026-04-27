# FPC Vendor Assets

This directory contains the Windows helper scripts and cached/generated files used to provision and build the Free Pascal toolchain for this repository.

This is the canonical location of the repository FPC workflow. The staged compiler lives under `fpc-main`, release/bootstrap helpers live under `scripts\win_x64`, and product build scripts are expected to reference the vendor toolchain from here.

SharedPasCore no longer carries shared FPC configs or bootstrap helpers. Product-local compiler configs should live next to each product's own `build_x64.bat` entry point.

All Windows x64 helper scripts live under `scripts\win_x64`.

## Free Pascal 3.2.2 Windows Compiler Bundle (win32 and win64)
**License**: GPL-2.0 / LGPL-2.1 (FPC)
**Original**: https://sourceforge.net/projects/freepascal/files/Win32/3.2.2/
**GitHub Release Asset**: `fpc-3.2.2.win32.and.win64.exe`
**MD5**: A249CF780E0EED1855960338669F1181
**SHA1**: 952E49290569362CD6F7B966C0EACEBDB4BC6D58

This installer exposes `fpc.exe`, `ppc386.exe`, and `ppcrossx64.exe` under `bin\i386-win32`, so the bootstrap flow uses `fpc.exe` as the primary compiler wrapper and verifies `ppcrossx64.exe` for the x86_64-win64 cross path.

The bootstrap installer is downloaded from GitHub Releases and is not stored in git. Recompute the hashes with PowerShell before updating the release asset:

```powershell
Get-FileHash -Path ".\fpc-3.2.2.win32.and.win64.exe" -Algorithm MD5
Get-FileHash -Path ".\fpc-3.2.2.win32.and.win64.exe" -Algorithm SHA1
```

The `fpc-bootstrap` release tag is expected to contain both `fpc-3.2.2.win32.and.win64.exe` and `gnumake-4.4.1-x64.exe`. The scripts in `scripts\win_x64` query GitHub release asset digest metadata and validate downloaded binaries locally before reuse.

Primary entry points:

1. `scripts\win_x64\fpc_bootstrap_build.bat`
2. `scripts\win_x64\fpc_main_build.bat`
3. `scripts\win_x64\fpc_release_setup.bat`

## Preconditions

- The scripts in this directory target Windows x64.
- `git.exe` must be available in `PATH` for source sync and the `git archive` fallback path.
- PowerShell must be available for `Expand-Archive`, `Compress-Archive`, and hash helper scripts.
- Internet access is required on the first run to download release assets and clone or refresh FPC sources.
- `7z.exe` is optional. If it is not available, `fpc_source_pack.bat` falls back to `git archive`.

## Output Layout

- The bootstrap compiler is installed into `bootstrap-install\bin\i386-win32` and provides `fpc.exe`, `ppc386.exe`, and `ppcrossx64.exe`.
- The final staged compiler that product build scripts should consume lives in `fpc-main\bin\x86_64-win64`.
- `fpc-main\bin\x86_64-win64\fpc.exe` is the main compiler wrapper that downstream product scripts should invoke.
- `fpc-main\bin\x86_64-win64\ppcx64.exe` is the native compiler binary produced by the local build pipeline.
- Downloaded installers and helper tools are cached under `downloads`.
- Temporary build state is created under `sources`, `work`, and `build-temp`.

## Build Scenarios

### 1. Consume an already published toolchain

Use this when you only need a ready local compiler layout and do not want to rebuild FPC from sources.

Run from `scripts\win_x64`:

```bat
fpc_release_setup.bat
```

What it does:

- Downloads `fpc-main.zip` from the configured GitHub release ref (`latest` by default).
- Verifies the archive digest before reuse or extraction.
- Extracts the archive and stages it into `fpc-main`.

Useful variants:

```bat
fpc_release_setup.bat --tag RELEASE_TAG
```

Use `--tag` when you need a specific published toolchain instead of the latest release asset.

### 2. Perform a full local rebuild from source

Use this when updating the vendored compiler, validating a source change, or producing a new `fpc-main.zip` for publication.

Run from `scripts\win_x64`:

```bat
fpc_main_build.bat
```

What it does:

- Ensures GNU Make is available via `gnumake_download.bat`.
- Ensures the 3.2.2 bootstrap compiler is present via `fpc_bootstrap_build.bat`.
- Creates or refreshes a dated `sources\sources-YYYYMMDD` snapshot from the `main` branch.
- Mirrors that snapshot into `sources\main`.
- Builds the compiler cycle, then uses `compiler\ppcx64.exe` as the reliable stage-3 compiler for the remaining build steps.
- Builds and installs `compiler`, `rtl`, `packages`, and `utils` into an installed layout.
- Moves the finished staged layout into `fpc-main`.
- Packs `fpc-main.zip` via `fpc_release_pack.bat`.

Useful variant:

```bat
fpc_main_build.bat --skip-pack
```

Use `--skip-pack` when you only need the local `fpc-main` directory and do not want to regenerate the outer release archive yet.

### 3. Prepare only the bootstrap compiler

Use this when troubleshooting bootstrap installer download or validation, or when you want to verify the base compiler independently before a full build.

Run from `scripts\win_x64`:

```bat
fpc_bootstrap_build.bat
```

What it does:

- Resolves the expected digest for the bootstrap installer release asset.
- Reuses the cached installer when its digest still matches.
- Downloads the installer when needed.
- Installs the bootstrap compiler into `bootstrap-install`.

This script does not build `fpc-main`; it only prepares the bootstrap compiler used by `fpc_main_build.bat`.

### 4. Repack an existing staged toolchain

Use this when `fpc-main` is already built and you only want to regenerate `fpc-main.zip` for release publication.

Run from `scripts\win_x64`:

```bat
fpc_release_pack.bat
```

What it does:

- Verifies that `fpc-main\bin\x86_64-win64\fpc.exe` already exists.
- Ensures a `sources-*.zip` archive is available by packing the latest source snapshot or reusing one already copied into `fpc-main`.
- Creates `fpc-main.zip` in the vendor root.
- Prints the manual upload steps for GitHub Releases.

### 5. Sync sources without building

Use this when you want to refresh the source worktrees separately from the full build, or when you are diagnosing fetch or local worktree issues.

Run from `scripts\win_x64`:

```bat
fpc_source_sync.bat main
fpc_source_sync.bat bootstrap
```

Useful variants:

```bat
fpc_source_sync.bat main --force
fpc_source_sync.bat main --force ..\..\sources\sources-20260427
```

What it does:

- `main` syncs the `main` branch worktree.
- `bootstrap` syncs the `release_3_2_2` sources.
- `--force` discards local changes and untracked files in an existing worktree.
- An optional trailing directory argument overrides the default target directory.

This script is mainly a maintenance entry point. The standard full build already calls it internally.

### 6. Pack a source snapshot only

Use this when you need to refresh the `sources-*.zip` archive without rebuilding the compiler itself.

Run from `scripts\win_x64`:

```bat
fpc_source_pack.bat
```

Useful variants:

```bat
fpc_source_pack.bat ..\..\sources\sources-20260427
fpc_source_pack.bat ..\..\sources\sources-20260427 ..\..\fpc-main
```

What it does:

- Picks the newest `sources-*` snapshot automatically if no path is provided.
- Writes the resulting zip into `fpc-main` by default.
- Uses 7-Zip when available and falls back to `git archive` otherwise.

### 7. Remove intermediate build state

Use this when you want to restart the bootstrap and source preparation flow from a clean working state without deleting downloaded caches or the staged `fpc-main` output.

Run from `scripts\win_x64`:

```bat
cleanup.bat
```

What it removes:

- `work`
- `build-temp`
- `sources`
- `bootstrap-install`

It intentionally does not remove `downloads` or `fpc-main`.

## Script Reference

| Script | Run directly | Purpose |
| --- | --- | --- |
| `fpc_release_setup.bat` | Yes | Download and unpack a published `fpc-main.zip` into `fpc-main`. |
| `fpc_main_build.bat` | Yes | Full local build of the main x86_64-win64 toolchain, optionally followed by archive packing. |
| `fpc_bootstrap_build.bat` | Yes | Download, verify, and install the 3.2.2 bootstrap compiler. |
| `fpc_release_pack.bat` | Yes | Create `fpc-main.zip` from an already staged `fpc-main` directory. |
| `fpc_source_sync.bat` | Yes | Clone or refresh the bootstrap or main FPC source worktree. |
| `fpc_source_pack.bat` | Yes | Pack the latest or specified dated source snapshot into `sources-*.zip`. |
| `cleanup.bat` | Yes | Remove intermediate build state while leaving downloaded caches and `fpc-main` intact. |
| `gnumake_download.bat` | Usually no | Ensure the cached GNU Make executable exists and passes digest validation. |
| `release_asset_digest.bat` | Usually no | Wrapper around the shared GitHub release digest helper for this repository. |
| `release_asset_download.bat` | Usually no | Wrapper around the shared GitHub release asset download helper for this repository. |
| `verify_hash.bat` | Usually no | Wrapper around the shared hash verification helper. |
| `common.bat` | No | Defines shared paths, versions, release tags, and output locations used by all other scripts. |

## Recommended Flows

Fresh machine, but a published toolchain already exists:

```bat
cd scripts\win_x64
fpc_release_setup.bat
```

Update the vendored compiler from current FPC `main` and prepare a release archive:

```bat
cd scripts\win_x64
fpc_main_build.bat
```

Debug bootstrap or download problems before attempting a full rebuild:

```bat
cd scripts\win_x64
gnumake_download.bat
fpc_bootstrap_build.bat
fpc_main_build.bat --skip-pack
```

## Workflow Tests

Regression and smoke checks for this script set live under `scripts\win_x64\tests`.

- `run_smoke_tests.bat` runs the quick path checks.
- `run_all_tests.bat` runs the broader workflow regression suite.

Use these after changing the vendor FPC scripts themselves.
