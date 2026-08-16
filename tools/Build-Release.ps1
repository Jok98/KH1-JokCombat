[CmdletBinding()]
param(
    [string]$Version = "v2.2.0",
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"

if ($Version -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+$') {
    throw "Version must use the vMAJOR.MINOR.PATCH form."
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot "dist"
}
$outputPath = [System.IO.Path]::GetFullPath($OutputDirectory)
$repoPrefix = $repoRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
if (-not $outputPath.StartsWith(
        $repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputDirectory must remain inside the repository."
}

$runtimeFiles = @(
    "JokCombat_CombatPrototype.lua",
    "JokCombat_NativeAbilities.lua",
    "JokCombat_NativeKeyblades.lua",
    "JokCombat_DropRate.lua"
)
$releaseFiles = @(
    $runtimeFiles
    "mod.yml",
    "tools/Deploy-Local.ps1",
    "README.md",
    "CHANGELOG.md",
    "LICENSE"
)
$openKhFiles = @("mod.yml") + $runtimeFiles

foreach ($relativePath in $releaseFiles) {
    $sourcePath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Missing release file: $relativePath"
    }
}

$mainSource = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "JokCombat_CombatPrototype.lua")
if ($mainSource -notmatch ('local VERSION = "' + [regex]::Escape($Version) + '"')) {
    throw "Combat prototype VERSION does not match $Version."
}

$plainVersion = $Version.TrimStart('v')
$readme = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "README.md")
if ($readme -notmatch ('\*\*Version ' + [regex]::Escape($plainVersion) + '\*\*')) {
    throw "README version does not match $Version."
}

New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
$bundleName = "KH1-JokCombat-$Version"
$archivePath = Join-Path $outputPath ($bundleName + ".zip")
$checksumPath = $archivePath + ".sha256"
$openKhArchivePath = Join-Path $outputPath ($bundleName + "-OpenKH.zip")
$openKhChecksumPath = $openKhArchivePath + ".sha256"

Add-Type -AssemblyName System.IO.Compression
$fixedTimestamp = [System.DateTimeOffset]::new(
    2026, 8, 16, 0, 0, 0, [System.TimeSpan]::Zero)

function New-JokCombatArchive {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string[]]$Files,
        [string]$EntryPrefix = ""
    )

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
    }

    $archiveStream = [System.IO.File]::Open(
        $Path,
        [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None)
    try {
        $archive = [System.IO.Compression.ZipArchive]::new(
            $archiveStream,
            [System.IO.Compression.ZipArchiveMode]::Create,
            $false)
        try {
            foreach ($relativePath in $Files) {
                $entryName = $relativePath.Replace('\', '/')
                if (-not [string]::IsNullOrWhiteSpace($EntryPrefix)) {
                    $entryName = ($EntryPrefix.TrimEnd('/', '\') + "/" + $entryName)
                }
                $entry = $archive.CreateEntry(
                    $entryName,
                    [System.IO.Compression.CompressionLevel]::Optimal)
                $entry.LastWriteTime = $fixedTimestamp
                $sourceStream = [System.IO.File]::OpenRead(
                    (Join-Path $repoRoot $relativePath))
                $entryStream = $entry.Open()
                try {
                    $sourceStream.CopyTo($entryStream)
                } finally {
                    $entryStream.Dispose()
                    $sourceStream.Dispose()
                }
            }
        } finally {
            $archive.Dispose()
        }
    } finally {
        $archiveStream.Dispose()
    }
}

function Write-JokCombatChecksum {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$ChecksumPath
    )

    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
    [System.IO.File]::WriteAllText(
        $ChecksumPath,
        $hash + "  " + [System.IO.Path]::GetFileName($Path) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false))
    return $hash
}

New-JokCombatArchive -Path $archivePath -Files $releaseFiles -EntryPrefix $bundleName
New-JokCombatArchive -Path $openKhArchivePath -Files $openKhFiles
$hash = Write-JokCombatChecksum -Path $archivePath -ChecksumPath $checksumPath
$openKhHash = Write-JokCombatChecksum `
    -Path $openKhArchivePath `
    -ChecksumPath $openKhChecksumPath

Write-Output "Archive: $archivePath"
Write-Output "SHA256: $hash"
Write-Output "Checksum: $checksumPath"
Write-Output "OpenKH archive: $openKhArchivePath"
Write-Output "OpenKH SHA256: $openKhHash"
Write-Output "OpenKH checksum: $openKhChecksumPath"
