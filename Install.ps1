[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [string]$Houdini21 = 'C:\Program Files\Side Effects Software\Houdini 21.0.700',
    [string]$Houdini22 = 'C:\Program Files\Side Effects Software\Houdini 22.0.368',
    [string]$DataRoot,
    [string]$PackageDirectory,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'HoudiniIcons.Common.ps1')
Add-Type -AssemblyName System.IO.Compression.FileSystem

$source = Assert-HoudiniInstall -InstallRoot $Houdini21 -ExpectedMajor 21
$target = Assert-HoudiniInstall -InstallRoot $Houdini22 -ExpectedMajor 22
$usingDefaultDataRoot = [string]::IsNullOrWhiteSpace($DataRoot)
if ($usingDefaultDataRoot) {
    $DataRoot = Get-DefaultDataRoot -TargetVersion $target.Version
}
$DataRoot = Get-NormalizedFullPath -Path $DataRoot
$legacyDataRoot = Get-HoudiniIconModBaseRoot
$legacyManifest = if ($usingDefaultDataRoot) { Get-OwnedManifest -DataRoot $legacyDataRoot } else { $null }

if ([string]::IsNullOrWhiteSpace($PackageDirectory)) {
    $PackageDirectory = Get-DefaultPackageDirectory -HConfig $target.HConfig
}
$PackageDirectory = Get-NormalizedFullPath -Path $PackageDirectory
$packageFileName = Get-HoudiniIconModPackageFileName -TargetVersion $target.Version
$packagePath = Join-Path $PackageDirectory $packageFileName
$legacyPackagePath = Join-Path $PackageDirectory $script:LegacyPackageFileName

if ((Test-Path -LiteralPath $packagePath -PathType Leaf) -and -not (Test-OwnedPackageFile -Path $packagePath) -and -not $Force) {
    throw "A package not owned by this mod already exists at $packagePath. Use -Force only after reviewing it."
}

if ((Test-Path -LiteralPath $DataRoot -PathType Container) -and $null -eq (Get-OwnedManifest -DataRoot $DataRoot) -and -not $Force) {
    throw "The data directory exists but is not owned by this mod: $DataRoot. Choose another -DataRoot or review it and use -Force."
}

$zip21 = [System.IO.Compression.ZipFile]::OpenRead($source.IconsZip)
$zip22 = [System.IO.Compression.ZipFile]::OpenRead($target.IconsZip)
try {
    $entries21 = Get-ZipEntriesByName -Archive $zip21
    $entries22 = Get-ZipEntriesByName -Archive $zip22

    $only21 = New-Object System.Collections.Generic.List[string]
    $only22 = New-Object System.Collections.Generic.List[string]
    $same = New-Object System.Collections.Generic.List[string]
    $replacements = New-Object System.Collections.Generic.List[object]

    foreach ($name in ($entries21.Keys | Sort-Object)) {
        if (-not $entries22.ContainsKey($name)) {
            $only21.Add($name)
            continue
        }
        if (-not $name.EndsWith('.svg', [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $hash21 = Get-ZipEntrySha256 -Entry $entries21[$name]
        $hash22 = Get-ZipEntrySha256 -Entry $entries22[$name]
        if ($hash21 -eq $hash22) {
            $same.Add($name)
        }
        else {
            $replacements.Add([pscustomobject]@{
                path = $name
                sourceSha256 = $hash21
                targetSha256 = $hash22
                bytes = [int64]$entries21[$name].Length
            })
        }
    }
    foreach ($name in ($entries22.Keys | Sort-Object)) {
        if (-not $entries21.ContainsKey($name)) {
            $only22.Add($name)
        }
    }

    Write-Host ("Matched changed SVG icons to replace: {0}" -f $replacements.Count)
    Write-Host ("Matching SVG icons already identical: {0}" -f $same.Count)
    Write-Host ("Houdini 22-only archive entries left untouched: {0}" -f $only22.Count)
    Write-Host ("Houdini 21-only archive entries not injected: {0}" -f $only21.Count)

    if ($replacements.Count -eq 0) {
        throw "No changed matching SVG icons were found. Check the supplied Houdini builds."
    }

    if (-not $PSCmdlet.ShouldProcess($DataRoot, "Build and enable the Houdini 21 icon overlay for Houdini 22")) {
        return
    }

    $parent = Split-Path -Parent $DataRoot
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $stage = $DataRoot + '.staging.' + [guid]::NewGuid().ToString('N')
    $backup = $DataRoot + '.backup.' + [guid]::NewGuid().ToString('N')
    $overlayRoot = Join-Path $stage 'houdini'
    $iconsRoot = Join-Path $overlayRoot 'config\Icons'
    New-Item -ItemType Directory -Path $iconsRoot -Force | Out-Null

    try {
        $replacementEntriesBySection = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal)
        foreach ($replacement in $replacements) {
            $sectionName = Get-IconSectionName -ArchivePath $replacement.path
            $replacementEntriesBySection[$sectionName] = $entries21[$replacement.path]
        }

        # This stamp is deliberately different from Houdini 22's stock icon
        # stamps so its small-icon UI cache cannot mask the replacement SVGs.
        $replacementStamp = [uint32]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())

        $stockIconsRoot = Join-Path $target.Root 'houdini\config\Icons'
        $generatedIndexes = @(
            Write-MergedHoudiniIconIndex `
                -SourceIndexPath (Join-Path $stockIconsRoot 'SVGIcons.index') `
                -DestinationPath (Join-Path $iconsRoot 'SVGIcons.index') `
                -ReplacementEntriesBySection $replacementEntriesBySection `
                -ReplacementStamp $replacementStamp
            Write-MergedHoudiniIconIndex `
                -SourceIndexPath (Join-Path $stockIconsRoot 'SVGIconsUI.index') `
                -DestinationPath (Join-Path $iconsRoot 'SVGIconsUI.index') `
                -ReplacementEntriesBySection $replacementEntriesBySection `
                -ReplacementStamp $replacementStamp
        )

        $manifest = [ordered]@{
            modId = $script:ModId
            schemaVersion = 3
            installedAtUtc = [DateTime]::UtcNow.ToString('o')
            replacementStamp = $replacementStamp
            source = [ordered]@{
                version = $source.Version
                installRoot = ConvertTo-HoudiniPath -Path $source.Root
                archiveSha256 = (Get-FileHash -LiteralPath $source.IconsZip -Algorithm SHA256).Hash.ToLowerInvariant()
            }
            target = [ordered]@{
                version = $target.Version
                installRoot = ConvertTo-HoudiniPath -Path $target.Root
                archiveSha256 = (Get-FileHash -LiteralPath $target.IconsZip -Algorithm SHA256).Hash.ToLowerInvariant()
            }
            stats = [ordered]@{
                replacedMatchingSvg = $replacements.Count
                identicalMatchingSvg = $same.Count
                houdini21OnlyEntriesExcluded = $only21.Count
                houdini22OnlyEntriesPreserved = $only22.Count
            }
            generatedIndexes = $generatedIndexes
            # Windows PowerShell 5.1 can throw while directly array-wrapping a
            # generic List[object], so enumerate it explicitly.
            files = @($replacements | ForEach-Object { $_ })
        }
        Write-JsonFile -Value $manifest -Path (Join-Path $stage 'manifest.json') -Depth 10

        if (-not (Test-Path -LiteralPath $PackageDirectory -PathType Container)) {
            New-Item -ItemType Directory -Path $PackageDirectory -Force | Out-Null
        }

        $finalOverlayRoot = Join-Path $DataRoot 'houdini'
        $finalCacheRoot = Join-Path $DataRoot 'cache'
        $package = [ordered]@{
            enable = "houdini_version == '$($target.Version)'"
            show = $true
            env = @(
                [ordered]@{ HOUDINI21_ICONS_FOR_22 = $script:ModId },
                [ordered]@{ HOUDINI_ICON_CACHE_DIR = (ConvertTo-HoudiniPath -Path $finalCacheRoot) }
            )
            hpath = (ConvertTo-HoudiniPath -Path $finalOverlayRoot)
        }
        $packageTemp = Join-Path $PackageDirectory ($script:PackageFileName + '.tmp.' + [guid]::NewGuid().ToString('N'))
        Write-JsonFile -Value $package -Path $packageTemp -Depth 8

        $hadExistingData = Test-Path -LiteralPath $DataRoot -PathType Container
        if ($hadExistingData) {
            Move-Item -LiteralPath $DataRoot -Destination $backup
        }

        try {
            Move-Item -LiteralPath $stage -Destination $DataRoot
            Move-Item -LiteralPath $packageTemp -Destination $packagePath -Force
        }
        catch {
            if (Test-Path -LiteralPath $DataRoot -PathType Container) {
                $installedManifest = Get-OwnedManifest -DataRoot $DataRoot
                if ($null -ne $installedManifest) {
                    Remove-Item -LiteralPath $DataRoot -Recurse -Force
                }
            }
            if ($hadExistingData -and (Test-Path -LiteralPath $backup -PathType Container)) {
                Move-Item -LiteralPath $backup -Destination $DataRoot
            }
            throw
        }

        if (Test-Path -LiteralPath $backup -PathType Container) {
            $null = Assert-SafeGeneratedDataRoot -DataRoot $backup
            Remove-Item -LiteralPath $backup -Recurse -Force
        }

        if ($usingDefaultDataRoot -and $legacyPackagePath -ne $packagePath -and
            (Test-OwnedPackageFile -Path $legacyPackagePath)) {
            Remove-Item -LiteralPath $legacyPackagePath -Force
            Write-Host "Removed the legacy unversioned package file."
        }

        if ($usingDefaultDataRoot -and $null -ne $legacyManifest -and
            (Get-NormalizedFullPath -Path $legacyDataRoot) -ne $DataRoot) {
            # v1.0.0 stored its generated files directly in the base folder.
            # Remove only those known owned artifacts after the versioned
            # replacement and package have both been installed successfully.
            foreach ($legacyDirectoryName in @('houdini', 'cache')) {
                $legacyDirectory = Join-Path $legacyDataRoot $legacyDirectoryName
                if (Test-Path -LiteralPath $legacyDirectory -PathType Container) {
                    Remove-Item -LiteralPath $legacyDirectory -Recurse -Force
                }
            }
            $legacyManifestPath = Join-Path $legacyDataRoot 'manifest.json'
            if (Test-Path -LiteralPath $legacyManifestPath -PathType Leaf) {
                Remove-Item -LiteralPath $legacyManifestPath -Force
            }
            Write-Host "Migrated the v1.0.0 overlay to build-specific storage."
        }

        Write-Host "Installed package: $packagePath"
        Write-Host "Generated overlay: $DataRoot"
        $warning = Get-HoudiniProcessWarning
        if ($warning) { Write-Warning $warning }
        else { Write-Host "Start Houdini 22 to use the classic icons." }
    }
    catch {
        if (Test-Path -LiteralPath $stage -PathType Container) {
            Remove-Item -LiteralPath $stage -Recurse -Force
        }
        throw
    }
}
finally {
    $zip22.Dispose()
    $zip21.Dispose()
}
