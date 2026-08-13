[CmdletBinding()]
param(
    [string]$Version = "v2.0.0",
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

$releaseFiles = @(
    "JokCombat_CombatPrototype.lua",
    "JokCombat_NativeAbilities.lua",
    "JokCombat_NativeKeyblades.lua",
    "JokCombat_DropRate.lua",
    "README.md",
    "CHANGELOG.md",
    "LICENSE"
)

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

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}

Add-Type -AssemblyName System.IO.Compression
$fixedTimestamp = [System.DateTimeOffset]::new(
    2026, 8, 13, 0, 0, 0, [System.TimeSpan]::Zero)
$archiveStream = [System.IO.File]::Open(
    $archivePath,
    [System.IO.FileMode]::CreateNew,
    [System.IO.FileAccess]::Write,
    [System.IO.FileShare]::None)
try {
    $archive = [System.IO.Compression.ZipArchive]::new(
        $archiveStream,
        [System.IO.Compression.ZipArchiveMode]::Create,
        $false)
    try {
        foreach ($relativePath in $releaseFiles) {
            $entryName = ($bundleName + "/" + $relativePath).Replace('\', '/')
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

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash.ToLowerInvariant()
[System.IO.File]::WriteAllText(
    $checksumPath,
    $hash + "  " + [System.IO.Path]::GetFileName($archivePath) + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false))

Write-Output "Archive: $archivePath"
Write-Output "SHA256: $hash"
Write-Output "Checksum: $checksumPath"
