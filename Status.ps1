[CmdletBinding()]
param(
    [string]$Houdini22 = 'C:\Program Files\Side Effects Software\Houdini 22.0.368',
    [string]$DataRoot = (Join-Path $env:LOCALAPPDATA 'Houdini21IconsFor22'),
    [string]$PackageDirectory,
    [switch]$VerifyFiles
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'HoudiniIcons.Common.ps1')

$target = Assert-HoudiniInstall -InstallRoot $Houdini22 -ExpectedMajor 22
$DataRoot = Get-NormalizedFullPath -Path $DataRoot
if ([string]::IsNullOrWhiteSpace($PackageDirectory)) {
    $PackageDirectory = Get-DefaultPackageDirectory -HConfig $target.HConfig
}
$PackageDirectory = Get-NormalizedFullPath -Path $PackageDirectory
$packagePath = Join-Path $PackageDirectory $script:PackageFileName
$manifest = Get-OwnedManifest -DataRoot $DataRoot
$packageOwned = Test-OwnedPackageFile -Path $packagePath

Write-Host ("Package installed: {0}" -f $packageOwned)
Write-Host "Package path: $packagePath"
Write-Host ("Generated overlay present: {0}" -f ($null -ne $manifest))
Write-Host "Data path: $DataRoot"

if ($null -ne $manifest) {
    Write-Host ("Source build: Houdini {0}" -f $manifest.source.version)
    Write-Host ("Target build: Houdini {0}" -f $manifest.target.version)
    Write-Host ("Replaced matching SVG icons: {0}" -f $manifest.stats.replacedMatchingSvg)
    Write-Host ("Houdini 22-only entries preserved: {0}" -f $manifest.stats.houdini22OnlyEntriesPreserved)
    if ($null -ne $manifest.PSObject.Properties['replacementStamp']) {
        Write-Host ("Small-icon UI cache invalidation stamp: {0}" -f $manifest.replacementStamp)
    }

    if ($VerifyFiles) {
        $bad = New-Object System.Collections.Generic.List[string]

        $currentTargetArchiveHash = (Get-FileHash -LiteralPath $target.IconsZip -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($currentTargetArchiveHash -ne [string]$manifest.target.archiveSha256) {
            $bad.Add('Houdini 22 icons.zip changed since installation; rebuild the mod with Install.ps1')
        }

        $sourceArchivePath = Join-Path ([string]$manifest.source.installRoot) 'houdini\config\Icons\icons.zip'
        if (Test-Path -LiteralPath $sourceArchivePath -PathType Leaf) {
            $currentSourceArchiveHash = (Get-FileHash -LiteralPath $sourceArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($currentSourceArchiveHash -ne [string]$manifest.source.archiveSha256) {
                $bad.Add('Houdini 21 icons.zip changed since installation; rebuild the mod with Install.ps1')
            }
        }

        foreach ($index in $manifest.generatedIndexes) {
            $path = Join-Path (Join-Path $DataRoot 'houdini\config\Icons') ([string]$index.name)
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                $bad.Add("missing: $($index.name)")
                continue
            }
            $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($hash -ne [string]$index.sha256) {
                $bad.Add("hash mismatch: $($index.name)")
            }
        }

        if ($bad.Count -eq 0) {
            Write-Host ("Source/build and index verification passed ({0} merged indexes, {1} old-icon replacements)." -f $manifest.generatedIndexes.Count, $manifest.files.Count)
        }
        else {
            Write-Error ("File verification failed:`n" + ($bad -join [Environment]::NewLine))
        }
    }
}

if ($packageOwned -and $null -ne $manifest) {
    Write-Host 'Status: ENABLED (restart Houdini if it was already open).'
}
elseif (-not $packageOwned -and $null -eq $manifest) {
    Write-Host 'Status: NOT INSTALLED.'
}
else {
    Write-Warning 'Status: PARTIAL. Re-run Install.ps1 to repair, or Uninstall.ps1 to clean up.'
}
