# Houdini 21 Icons for Houdini 22

A reversible Windows mod that restores the Houdini 21 icon artwork in Houdini 22 while keeping icons that are genuinely new to Houdini 22.

The project does not redistribute SideFX artwork. It builds the icon overlay locally from the user's own Houdini installations and never modifies files under `Program Files`.

## What it does

- Compares the icon archives installed with Houdini 21 and Houdini 22.
- Replaces matching SVG icons whose artwork changed in Houdini 22.
- Preserves icons that exist only in Houdini 22.
- Regenerates Houdini 22's small-icon cache so viewport and toolbar buttons also use the classic artwork.
- Installs everything as a user-level Houdini package.
- Restores stock Houdini 22 cleanly with the included uninstaller.

With the default builds listed below, the installer restores 347 changed SVG icons, including 309 icons used by the main UI, and leaves all 359 Houdini 22-only archive entries untouched.

## Requirements

- Windows
- Houdini 21 and Houdini 22 installed locally
- Windows PowerShell 5.1 or newer

Default tested builds:

- Houdini 21.0.700: `C:\Program Files\Side Effects Software\Houdini 21.0.700`
- Houdini 22.0.368: `C:\Program Files\Side Effects Software\Houdini 22.0.368`

Other 21.x/22.x build pairs can be supplied on the command line. The comparison is data-driven, but each pair should be tested because SideFX may change its icon indexes between builds.

## Quick start

1. Download or clone this repository.
2. Close every Houdini window.
3. Double-click `Install.cmd`.
4. Start Houdini 22.

The generated overlay is stored by default in:

```text
%LOCALAPPDATA%\Houdini21IconsFor22
```

The package is written to Houdini 22's resolved user preferences directory:

```text
%HOUDINI_USER_PREF_DIR%\packages\houdini21_icons_for_houdini22.json
```

Localized Documents folders and OneDrive redirection are supported because the installer asks Houdini itself for the active preferences directory.

## Install from PowerShell

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

For custom builds or installation paths:

```powershell
.\Install.ps1 `
  -Houdini21 'D:\SideFX\Houdini 21.0.700' `
  -Houdini22 'D:\SideFX\Houdini 22.0.368'
```

Preview the operation without writing anything:

```powershell
.\Install.ps1 -WhatIf
```

## Verify the installation

Double-click `Status.cmd`, or run:

```powershell
.\Status.ps1 -VerifyFiles
```

The integrity check verifies the source and target archives, both generated icon indexes, the number of replacements, and whether the package is enabled. It also detects when an in-place Houdini update requires the overlay to be rebuilt.

## Uninstall

Close Houdini and double-click `Uninstall.cmd`, or run:

```powershell
.\Uninstall.ps1
```

The uninstaller removes only the package and generated data owned by this mod. Since the original Houdini installation is never edited, Houdini 22 returns to its stock icons on the next launch.

To disable the package while retaining the generated overlay:

```powershell
.\Uninstall.ps1 -KeepGeneratedData
```

Run `Install.ps1` again to enable or rebuild it.

## How it works

The installer validates both Houdini executable versions and reads their local `icons.zip` archives. SVG entries with the same internal path are compared using SHA-256. Only entries whose artwork differs are selected.

It then creates merged copies of Houdini 22's `SVGIcons.index` and `SVGIconsUI.index`, preserving the complete Houdini 22 index while substituting the selected Houdini 21 payloads. Replaced entries receive a fresh stamp so Houdini 22 regenerates the pre-rendered small icons used by viewport toolbars instead of reusing its stock UI cache.

The overlay is enabled through `HOUDINI_PATH` in a user package. A dedicated disposable `HOUDINI_ICON_CACHE_DIR` prevents the normal Houdini cache from being modified or masking the overlay.

## Safety and distribution

- No files in either Houdini installation are modified.
- No SideFX icons or generated icon indexes are included in this repository.
- Each user must provide their own installed copies of Houdini 21 and Houdini 22.
- Generated overlay files should not be redistributed.
- Review the SideFX license terms that apply to your Houdini installations and generated local files.

This is an unofficial community project and is not affiliated with, endorsed by, or supported by SideFX. Houdini and the Houdini icons are property of their respective owner. The MIT license in this repository applies only to the original scripts and documentation in this project.

## License

The original code and documentation in this repository are available under the [MIT License](LICENSE).
