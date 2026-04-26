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