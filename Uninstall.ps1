[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [string]$Houdini22 = 'C:\Program Files\Side Effects Software\Houdini 22.0.368',
    [string]$DataRoot = (Join-Path $env:LOCALAPPDATA 'Houdini21IconsFor22'),
    [string]$PackageDirectory,
    [switch]$KeepGeneratedData
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

$removedAnything = $false
$foundAnything = $false
if (Test-Path -LiteralPath $packagePath -PathType Leaf) {
    $foundAnything = $true
    if (-not (Test-OwnedPackageFile -Path $packagePath)) {
        throw "Refusing to remove a package not owned by this mod: $packagePath"
    }
    if ($PSCmdlet.ShouldProcess($packagePath, 'Disable the classic icon overlay by removing its Houdini package')) {
        Remove-Item -LiteralPath $packagePath -Force
        Write-Host "Removed package: $packagePath"
        $removedAnything = $true
    }
}
else {
    Write-Host "Package is not installed: $packagePath"
}

if (-not $KeepGeneratedData -and (Test-Path -LiteralPath $DataRoot -PathType Container)) {
    $foundAnything = $true
    $safeDataRoot = Assert-SafeGeneratedDataRoot -DataRoot $DataRoot
    if ($PSCmdlet.ShouldProcess($safeDataRoot, 'Remove generated icon overlay and its disposable cache')) {
        Remove-Item -LiteralPath $safeDataRoot -Recurse -Force
        Write-Host "Removed generated data: $safeDataRoot"
        $removedAnything = $true
    }
}
elseif ($KeepGeneratedData -and (Test-Path -LiteralPath $DataRoot -PathType Container)) {
    Write-Host "Kept generated data: $DataRoot"
}

if (-not $foundAnything) {
    Write-Host 'Nothing needed to be removed.'
}

$warning = Get-HoudiniProcessWarning
if ($warning) { Write-Warning $warning }
else { Write-Host 'Houdini 22 will use its original icons on the next launch.' }
