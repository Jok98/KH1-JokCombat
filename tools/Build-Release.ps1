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
$stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "JokCombat-release-" + [guid]::NewGuid().ToString("N"))
$bundlePath = Join-Path $stagingRoot $bundleName

try {
    New-Item -ItemType Directory -Path $bundlePath -Force | Out-Null
    foreach ($relativePath in $releaseFiles) {
        Copy-Item -LiteralPath (Join-Path $repoRoot $relativePath) `
            -Destination (Join-Path $bundlePath $relativePath)
    }
    Compress-Archive -LiteralPath $bundlePath -DestinationPath $archivePath `
        -CompressionLevel Optimal -Force
} finally {
    if (Test-Path -LiteralPath $stagingRoot) {
        $resolvedStage = [System.IO.Path]::GetFullPath($stagingRoot)
        $tempPrefix = [System.IO.Path]::GetFullPath(
            [System.IO.Path]::GetTempPath())
        if ($resolvedStage.StartsWith(
                $tempPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedStage -Recurse -Force
        }
    }
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash.ToLowerInvariant()
[System.IO.File]::WriteAllText(
    $checksumPath,
    $hash + "  " + [System.IO.Path]::GetFileName($archivePath) + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false))

Write-Output "Archive: $archivePath"
Write-Output "SHA256: $hash"
Write-Output "Checksum: $checksumPath"
