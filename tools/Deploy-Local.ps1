[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$DestinationDirectory = "",
    [switch]$IncludeDiagnostics
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($DestinationDirectory)) {
    $documents = [Environment]::GetFolderPath(
        [Environment+SpecialFolder]::MyDocuments)
    $DestinationDirectory = Join-Path $documents (
        "My Games\KINGDOM HEARTS HD 1.5+2.5 ReMIX\scripts\kh1")
}
$destinationPath = [System.IO.Path]::GetFullPath($DestinationDirectory)

$runtimeFiles = @(
    "JokCombat_CombatPrototype.lua",
    "JokCombat_NativeAbilities.lua",
    "JokCombat_NativeKeyblades.lua",
    "JokCombat_DropRate.lua"
)

$diagnosticFiles = @(
    "JokCombat_StateProbe.lua",
    "JokCombat_InputProbe.lua",
    "JokCombat_CommandMenuProbe.lua",
    "JokCombat_MPHitProbe.lua"
)

$deployFiles = @($runtimeFiles)
if ($IncludeDiagnostics) {
    $deployFiles += $diagnosticFiles
}

foreach ($relativePath in $deployFiles) {
    $sourcePath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Missing deployment file: $relativePath"
    }
}

if (-not $PSCmdlet.ShouldProcess(
        $destinationPath,
        "Deploy $($deployFiles.Count) JokCombat Lua files")) {
    return
}

New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
foreach ($relativePath in $deployFiles) {
    $sourcePath = Join-Path $repoRoot $relativePath
    $deployedPath = Join-Path $destinationPath $relativePath
    Copy-Item -LiteralPath $sourcePath -Destination $deployedPath -Force

    $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash
    $deployedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $deployedPath).Hash
    if ($sourceHash -ne $deployedHash) {
        throw "Deployment verification failed for $relativePath"
    }
    Write-Output "Deployed: $relativePath"
}

Write-Output "Destination: $destinationPath"
Write-Output "Verified: $($deployFiles.Count) file(s)"
Write-Output "LuaBackend: scripts/kh1/ (relative = true)"
