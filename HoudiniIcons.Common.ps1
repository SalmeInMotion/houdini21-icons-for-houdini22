Set-StrictMode -Version Latest

$script:ModId = "houdini21-icons-for-22"
$script:LegacyPackageFileName = "houdini21_icons_for_houdini22.json"

function Get-HoudiniIconModPackageFileName {
    param([Parameter(Mandatory = $true)][string]$TargetVersion)

    $safeVersion = $TargetVersion -replace '[^0-9A-Za-z._-]', '_'
    return "houdini21_icons_for_houdini22_$safeVersion.json"
}

function Get-NormalizedFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
}

function ConvertTo-HoudiniPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return (Get-NormalizedFullPath -Path $Path).Replace('\', '/')
}

function Resolve-HoudiniInstallRoot {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = Get-NormalizedFullPath -Path $Path
    if (Test-Path -LiteralPath $resolved -PathType Leaf) {
        if ([System.IO.Path]::GetFileName($resolved) -notmatch '^houdini(fx|core|indie|apprentice)?\.exe$') {
            return $resolved
        }
        $resolved = Split-Path -Parent (Split-Path -Parent $resolved)
    }
    elseif ((Split-Path -Leaf $resolved) -ieq 'bin' -and
            (Test-Path -LiteralPath (Join-Path $resolved 'houdinifx.exe') -PathType Leaf)) {
        $resolved = Split-Path -Parent $resolved
    }

    return (Get-NormalizedFullPath -Path $resolved)
}

function Get-HoudiniBrowseInitialDirectory {
    param([AllowEmptyString()][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    try {
        $resolved = Resolve-HoudiniInstallRoot -Path $Path
        if (Test-Path -LiteralPath $resolved -PathType Container) {
            return $resolved
        }
    }
    catch {
        # An invalid manually typed path should not prevent Browse from opening.
    }

    return $null
}

function Get-HoudiniExecutableVersion {
    param([Parameter(Mandatory = $true)][string]$InstallRoot)

    $houdiniExe = Join-Path $InstallRoot "bin\houdinifx.exe"
    if (-not (Test-Path -LiteralPath $houdiniExe -PathType Leaf)) {
        throw "Not a Houdini installation (missing $houdiniExe)."
    }

    $versionInfo = (Get-Item -LiteralPath $houdiniExe).VersionInfo
    return ("{0}.{1}.{2}" -f $versionInfo.FileMajorPart, $versionInfo.FileMinorPart, $versionInfo.FilePrivatePart)
}

function Assert-HoudiniInstall {
    param(
        [Parameter(Mandatory = $true)][string]$InstallRoot,
        [Parameter(Mandatory = $true)][int]$ExpectedMajor
    )

    $resolved = Resolve-HoudiniInstallRoot -Path $InstallRoot
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "Houdini $ExpectedMajor installation directory does not exist: $resolved"
    }

    $version = Get-HoudiniExecutableVersion -InstallRoot $resolved
    if (-not $version.StartsWith("$ExpectedMajor.")) {
        throw "Expected Houdini $ExpectedMajor, but $resolved contains Houdini $version."
    }

    $iconsZip = Join-Path $resolved "houdini\config\Icons\icons.zip"
    if (-not (Test-Path -LiteralPath $iconsZip -PathType Leaf)) {
        throw "Houdini $version icon archive is missing: $iconsZip"
    }

    return [pscustomobject]@{
        Root = $resolved
        Version = $version
        IconsZip = $iconsZip
        HConfig = Join-Path $resolved "bin\hconfig.exe"
    }
}

function Get-HoudiniInstallCandidates {
    param([Parameter(Mandatory = $true)][int]$ExpectedMajor)

    $candidatePaths = New-Object System.Collections.Generic.List[string]
    $searchRoots = @()
    if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
        $searchRoots += (Join-Path $env:ProgramFiles 'Side Effects Software')
    }
    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
        $searchRoots += (Join-Path $programFilesX86 'Side Effects Software')
    }

    foreach ($searchRoot in ($searchRoots | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $searchRoot -PathType Container)) { continue }
        foreach ($directory in @(Get-ChildItem -LiteralPath $searchRoot -Directory -ErrorAction SilentlyContinue)) {
            if ($directory.Name -match ("^Houdini\s+{0}\." -f $ExpectedMajor)) {
                $candidatePaths.Add($directory.FullName)
            }
        }
    }

    $uninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($uninstallRoot in $uninstallRoots) {
        if (-not (Test-Path -LiteralPath $uninstallRoot)) { continue }
        foreach ($key in @(Get-ChildItem -LiteralPath $uninstallRoot -ErrorAction SilentlyContinue)) {
            try {
                $entry = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop
                if ([string]$entry.DisplayName -match ("^Houdini\s+{0}\." -f $ExpectedMajor) -and
                    -not [string]::IsNullOrWhiteSpace([string]$entry.InstallLocation)) {
                    $candidatePaths.Add([string]$entry.InstallLocation)
                }
            }
            catch {
                continue
            }
        }
    }

    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $installs = New-Object System.Collections.Generic.List[object]
    foreach ($path in $candidatePaths) {
        try {
            $install = Assert-HoudiniInstall -InstallRoot $path -ExpectedMajor $ExpectedMajor
            if ($seen.Add([string]$install.Root)) {
                $installs.Add($install)
            }
        }
        catch {
            continue
        }
    }

    return @($installs | Sort-Object -Property @{ Expression = { [version]$_.Version }; Descending = $true })
}

function Get-HoudiniConfigValue {
    param(
        [Parameter(Mandatory = $true)][string]$HConfig,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $output = & $HConfig -a 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "hconfig failed while resolving $Name (exit code $LASTEXITCODE)."
    }

    $pattern = '^' + [regex]::Escape($Name) + "\s*:=\s*'(.*)'\s*$"
    foreach ($line in $output) {
        $match = [regex]::Match([string]$line, $pattern)
        if ($match.Success) {
            return $match.Groups[1].Value
        }
    }

    throw "hconfig did not report $Name."
}

function Get-DefaultPackageDirectory {
    param([Parameter(Mandatory = $true)][string]$HConfig)

    $userPrefDir = Get-HoudiniConfigValue -HConfig $HConfig -Name "HOUDINI_USER_PREF_DIR"
    return (Join-Path $userPrefDir "packages")
}

function Get-HoudiniIconModBaseRoot {
    return (Join-Path $env:LOCALAPPDATA 'Houdini21IconsFor22')
}

function Get-DefaultDataRoot {
    param([Parameter(Mandatory = $true)][string]$TargetVersion)

    $safeVersion = $TargetVersion -replace '[^0-9A-Za-z._-]', '_'
    return (Join-Path (Join-Path (Get-HoudiniIconModBaseRoot) 'overlays') $safeVersion)
}

function Get-ExistingDataRoot {
    param([Parameter(Mandatory = $true)][string]$TargetVersion)

    $versioned = Get-DefaultDataRoot -TargetVersion $TargetVersion
    if ($null -ne (Get-OwnedManifest -DataRoot $versioned)) {
        return $versioned
    }

    # Compatibility with v1.0.0, which stored one unversioned overlay.
    $legacy = Get-HoudiniIconModBaseRoot
    $legacyManifest = Get-OwnedManifest -DataRoot $legacy
    if ($null -ne $legacyManifest -and [string]$legacyManifest.target.version -eq $TargetVersion) {
        return $legacy
    }

    return $versioned
}

function Get-HoudiniIconModInstalledOverlays {
    $baseRoot = Get-HoudiniIconModBaseRoot
    $dataRoots = New-Object System.Collections.Generic.List[string]
    $dataRoots.Add($baseRoot)

    $overlaysRoot = Join-Path $baseRoot 'overlays'
    if (Test-Path -LiteralPath $overlaysRoot -PathType Container) {
        foreach ($directory in @(Get-ChildItem -LiteralPath $overlaysRoot -Directory -ErrorAction SilentlyContinue)) {
            $dataRoots.Add($directory.FullName)
        }
    }

    $installed = New-Object System.Collections.Generic.List[object]
    foreach ($dataRoot in $dataRoots) {
        $manifest = Get-OwnedManifest -DataRoot $dataRoot
        if ($null -ne $manifest) {
            $installed.Add([pscustomobject]@{
                DataRoot = (Get-NormalizedFullPath -Path $dataRoot)
                Manifest = $manifest
            })
        }
    }
    return @($installed | ForEach-Object { $_ })
}

function Get-StreamSha256 {
    param([Parameter(Mandatory = $true)][System.IO.Stream]$Stream)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($sha.ComputeHash($Stream)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-ZipEntrySha256 {
    param([Parameter(Mandatory = $true)]$Entry)

    $stream = $Entry.Open()
    try {
        return Get-StreamSha256 -Stream $stream
    }
    finally {
        $stream.Dispose()
    }
}

function Get-ZipEntriesByName {
    param([Parameter(Mandatory = $true)]$Archive)

    $entries = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal)
    foreach ($entry in $Archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name)) {
            continue
        }
        $entries[$entry.FullName] = $entry
    }
    return $entries
}

function Read-BigEndianUInt32 {
    param([Parameter(Mandatory = $true)][System.IO.BinaryReader]$Reader)

    $bytes = $Reader.ReadBytes(4)
    if ($bytes.Length -ne 4) { throw 'Unexpected end of icon index.' }
    [Array]::Reverse($bytes)
    return [BitConverter]::ToUInt32($bytes, 0)
}

function Read-BigEndianUInt64 {
    param([Parameter(Mandatory = $true)][System.IO.BinaryReader]$Reader)

    $bytes = $Reader.ReadBytes(8)
    if ($bytes.Length -ne 8) { throw 'Unexpected end of icon index.' }
    [Array]::Reverse($bytes)
    return [BitConverter]::ToUInt64($bytes, 0)
}

function Write-BigEndianUInt32 {
    param(
        [Parameter(Mandatory = $true)][System.IO.Stream]$Stream,
        [Parameter(Mandatory = $true)][uint32]$Value
    )

    $bytes = [BitConverter]::GetBytes($Value)
    [Array]::Reverse($bytes)
    $Stream.Write($bytes, 0, $bytes.Length)
}

function Write-BigEndianUInt64 {
    param(
        [Parameter(Mandatory = $true)][System.IO.Stream]$Stream,
        [Parameter(Mandatory = $true)][uint64]$Value
    )

    $bytes = [BitConverter]::GetBytes($Value)
    [Array]::Reverse($bytes)
    $Stream.Write($bytes, 0, $bytes.Length)
}

function Read-HoudiniIconIndex {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    $reader = New-Object System.IO.BinaryReader($stream, [System.Text.Encoding]::UTF8, $false)
    try {
        $magic = [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
        if ($magic -ne 'INDX') { throw "Invalid Houdini icon index magic in $Path." }

        $descriptionLength = Read-BigEndianUInt64 -Reader $reader
        if ($descriptionLength -gt 1048576) { throw "Invalid icon index description length in $Path." }
        $descriptionBytes = $reader.ReadBytes([int]$descriptionLength)
        if ($descriptionBytes.Length -ne [int]$descriptionLength) { throw "Truncated icon index description in $Path." }
        $description = [System.Text.Encoding]::UTF8.GetString($descriptionBytes)
        $count = Read-BigEndianUInt32 -Reader $reader
        if ($count -gt 100000) { throw "Invalid icon count in $Path." }

        $entries = New-Object System.Collections.Generic.List[object]
        for ($i = 0; $i -lt $count; $i++) {
            $nameLength = Read-BigEndianUInt32 -Reader $reader
            if ($nameLength -gt 65536) { throw "Invalid icon name length in $Path." }
            $nameBytes = $reader.ReadBytes([int]$nameLength)
            if ($nameBytes.Length -ne [int]$nameLength) { throw "Truncated icon name in $Path." }
            $entries.Add([pscustomobject]@{
                name = [System.Text.Encoding]::UTF8.GetString($nameBytes)
                offset = Read-BigEndianUInt32 -Reader $reader
                length = Read-BigEndianUInt32 -Reader $reader
                stamp = Read-BigEndianUInt32 -Reader $reader
            })
        }

        $dataStart = $stream.Position
        foreach ($entry in $entries) {
            if ([int64]$dataStart + [int64]$entry.offset + [int64]$entry.length -gt $stream.Length) {
                throw "Icon section $($entry.name) extends beyond the end of $Path."
            }
        }

        return [pscustomobject]@{
            path = (Get-NormalizedFullPath -Path $Path)
            description = $description
            entries = @($entries | ForEach-Object { $_ })
            dataStart = [int64]$dataStart
            fileLength = [int64]$stream.Length
        }
    }
    finally {
        $reader.Dispose()
    }
}

function Copy-StreamRange {
    param(
        [Parameter(Mandatory = $true)][System.IO.Stream]$InputStream,
        [Parameter(Mandatory = $true)][System.IO.Stream]$OutputStream,
        [Parameter(Mandatory = $true)][int64]$Length
    )

    $buffer = New-Object byte[] 1048576
    $remaining = $Length
    while ($remaining -gt 0) {
        $requested = [int][Math]::Min([int64]$buffer.Length, $remaining)
        $read = $InputStream.Read($buffer, 0, $requested)
        if ($read -le 0) { throw 'Unexpected end of stream while copying an icon section.' }
        $OutputStream.Write($buffer, 0, $read)
        $remaining -= $read
    }
}

function Get-IconSectionName {
    param([Parameter(Mandatory = $true)][string]$ArchivePath)

    $separator = $ArchivePath.IndexOf('/')
    if ($separator -ge 0) {
        return $ArchivePath.Substring(0, $separator).ToUpperInvariant() + '_' + $ArchivePath.Substring($separator + 1)
    }
    return $ArchivePath
}

function Write-MergedHoudiniIconIndex {
    param(
        [Parameter(Mandatory = $true)][string]$SourceIndexPath,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)]$ReplacementEntriesBySection,
        [Parameter(Mandatory = $true)][uint32]$ReplacementStamp
    )

    $index = Read-HoudiniIconIndex -Path $SourceIndexPath
    $destinationDir = Split-Path -Parent $DestinationPath
    if (-not (Test-Path -LiteralPath $destinationDir -PathType Container)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }

    $sourceStream = [System.IO.File]::OpenRead($index.path)
    $outputStream = [System.IO.File]::Create($DestinationPath)
    $applied = 0
    try {
        $magic = [System.Text.Encoding]::ASCII.GetBytes('INDX')
        $outputStream.Write($magic, 0, $magic.Length)
        $descriptionBytes = [System.Text.Encoding]::UTF8.GetBytes($index.description)
        Write-BigEndianUInt64 -Stream $outputStream -Value ([uint64]$descriptionBytes.Length)
        $outputStream.Write($descriptionBytes, 0, $descriptionBytes.Length)
        Write-BigEndianUInt32 -Stream $outputStream -Value ([uint32]$index.entries.Count)

        [uint64]$nextOffset = 0
        foreach ($entry in $index.entries) {
            $nameBytes = [System.Text.Encoding]::UTF8.GetBytes([string]$entry.name)
            $length = [uint32]$entry.length
            $stamp = [uint32]$entry.stamp
            if ($ReplacementEntriesBySection.ContainsKey([string]$entry.name)) {
                $replacement = $ReplacementEntriesBySection[[string]$entry.name]
                if ([int64]$replacement.Length -gt [uint32]::MaxValue) {
                    throw "Replacement icon is too large: $($entry.name)"
                }
                $length = [uint32]$replacement.Length
                # Houdini 22 pre-renders small UI icons into SVGIconsUI.cache.
                # Keeping Houdini 22's original stamp makes that cache look
                # valid even though the SVG payload was replaced, so native
                # toolbars continue to display the stock Houdini 22 artwork.
                # A distinct stamp makes Houdini rebuild just these entries.
                $stamp = $ReplacementStamp
                if ($stamp -eq [uint32]$entry.stamp) {
                    $stamp = if ($stamp -eq [uint32]::MaxValue) { [uint32]0 } else { [uint32]($stamp + 1) }
                }
                $applied++
            }
            if ($nextOffset -gt [uint32]::MaxValue) { throw 'Merged icon index exceeds the 32-bit format limit.' }

            Write-BigEndianUInt32 -Stream $outputStream -Value ([uint32]$nameBytes.Length)
            $outputStream.Write($nameBytes, 0, $nameBytes.Length)
            Write-BigEndianUInt32 -Stream $outputStream -Value ([uint32]$nextOffset)
            Write-BigEndianUInt32 -Stream $outputStream -Value $length
            Write-BigEndianUInt32 -Stream $outputStream -Value $stamp
            $nextOffset += $length
        }

        foreach ($entry in $index.entries) {
            if ($ReplacementEntriesBySection.ContainsKey([string]$entry.name)) {
                $replacementStream = $ReplacementEntriesBySection[[string]$entry.name].Open()
                try {
                    # DeflateStream does not expose Length in Windows
                    # PowerShell/.NET Framework; use ZipArchiveEntry.Length.
                    $replacementLength = [int64]$ReplacementEntriesBySection[[string]$entry.name].Length
                    Copy-StreamRange -InputStream $replacementStream -OutputStream $outputStream -Length $replacementLength
                }
                finally {
                    $replacementStream.Dispose()
                }
            }
            else {
                $null = $sourceStream.Seek($index.dataStart + [int64]$entry.offset, [System.IO.SeekOrigin]::Begin)
                Copy-StreamRange -InputStream $sourceStream -OutputStream $outputStream -Length ([int64]$entry.length)
            }
        }
    }
    finally {
        $outputStream.Dispose()
        $sourceStream.Dispose()
    }

    return [pscustomobject]@{
        name = [System.IO.Path]::GetFileName($DestinationPath)
        entries = $index.entries.Count
        replacementsApplied = $applied
        bytes = (Get-Item -LiteralPath $DestinationPath).Length
        sha256 = (Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$Depth = 10
    )

    $json = $Value | ConvertTo-Json -Depth $Depth
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8NoBom)
}

function Test-OwnedPackageFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }

    try {
        $package = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        foreach ($item in $package.env) {
            if ($null -ne $item.PSObject.Properties['HOUDINI21_ICONS_FOR_22'] -and
                [string]$item.HOUDINI21_ICONS_FOR_22 -eq $script:ModId) {
                return $true
            }
        }
    }
    catch {
        return $false
    }

    return $false
}

function Get-OwnedManifest {
    param([Parameter(Mandatory = $true)][string]$DataRoot)

    $manifestPath = Join-Path $DataRoot "manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        return $null
    }

    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        if ([string]$manifest.modId -eq $script:ModId) {
            return $manifest
        }
    }
    catch {
        return $null
    }

    return $null
}

function Assert-SafeGeneratedDataRoot {
    param([Parameter(Mandatory = $true)][string]$DataRoot)

    $resolved = Get-NormalizedFullPath -Path $DataRoot
    $root = [System.IO.Path]::GetPathRoot($resolved).TrimEnd('\', '/')
    if ($resolved -eq $root -or $resolved.Length -lt ($root.Length + 8)) {
        throw "Refusing to remove an unsafe data path: $resolved"
    }

    if ($null -eq (Get-OwnedManifest -DataRoot $resolved)) {
        throw "Refusing to remove $resolved because it has no valid $script:ModId manifest."
    }

    return $resolved
}

function Get-HoudiniProcessWarning {
    $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -match '^houdini(fx|core|indie|apprentice)?$'
    })
    if ($running.Count -gt 0) {
        return "Houdini is currently running. The change will take effect after all Houdini windows are restarted."
    }
    return $null
}
