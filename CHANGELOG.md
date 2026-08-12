# Changelog

## 1.1.0 - 2026-08-12

- Added a bilingual graphical setup for install, update, verification, and uninstall.
- Added automatic discovery of Houdini 21 and Houdini 22 installations.
- Added manual folder selection and support for selecting the installation root, `bin` folder, or Houdini executable.
- Restricted packages to the complete Houdini 22 build number.
- Added separate data and package paths for each H22 build.
- Added automatic migration from the unversioned v1.0.0 overlay.
- Removed the redundant legacy `Install.cmd`, `Status.cmd`, and `Uninstall.cmd` launchers; `Setup.cmd` is now the single end-user entry point.
- Verified Houdini 21.0.631 and 21.0.700 as sources for Houdini 22.0.368.

## 1.0.0 - 2026-08-12

- Initial public release.
- Restored matching changed H21 SVG artwork while preserving H22-only icons.
- Added small-icon cache invalidation for viewport and native toolbar controls.
- Added integrity checks and a reversible user-level installation.
