# Adapted from Nokama's MIT deployment helper; copies only this mod.
[CmdletBinding(SupportsShouldProcess = $true)]
param([string]$GameRoot)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $GameRoot) { $GameRoot = $env:RON_GAME_ROOT }
if (-not $GameRoot) {
    $steam = Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction SilentlyContinue
    if ($steam) {
        $vdfPath = Join-Path $steam.SteamPath 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdfPath) {
            $libraries = [regex]::Matches((Get-Content -LiteralPath $vdfPath -Raw), '"path"\s+"([^"\r\n]+)"')
            foreach ($library in $libraries) {
                $libraryPath = $library.Groups[1].Value.Replace('\\', '\')
                $manifestPath = Join-Path $libraryPath 'steamapps\appmanifest_1144200.acf'
                if (-not (Test-Path -LiteralPath $manifestPath)) { continue }
                $manifest = Get-Content -LiteralPath $manifestPath -Raw
                if ($manifest -match '"installdir"\s+"([^"\r\n]+)"') {
                    $candidate = Join-Path $libraryPath ('steamapps\common\' + $matches[1])
                    if (Test-Path -LiteralPath $candidate) { $GameRoot = $candidate; break }
                }
            }
        }
    }
}
if (-not $GameRoot) { throw 'Game not found. Supply -GameRoot or RON_GAME_ROOT (the folder containing ReadyOrNot\).' }
$GameRoot = (Resolve-Path -LiteralPath $GameRoot).Path
$modsDir = Join-Path $GameRoot 'ReadyOrNot\Binaries\Win64\ue4ss\Mods'
if (-not (Test-Path -LiteralPath $modsDir -PathType Container)) {
    throw "Experimental UE4SS folder missing: $modsDir. Install experimental UE4SS first."
}
if (Get-Process -Name 'ReadyOrNot*' -ErrorAction SilentlyContinue) {
    throw 'Close Ready or Not before deployment. The script does not replace live watched Lua files.'
}
$destination = Join-Path $modsDir 'SRankAlert'
$scripts = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'Scripts') -Filter '*.lua' -File)
if ($scripts.Count -eq 0) { throw 'No Lua files found.' }
foreach ($fileName in @('LICENSE', 'README.md', 'CHANGELOG.md', 'CONFIG.md', 'config.example.json', 'THIRD-PARTY.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $fileName))) { throw "Missing $fileName" }
}
if (-not $PSCmdlet.ShouldProcess($destination, 'Back up existing scripts, copy SRankAlert and verify SHA256')) { return }
$destScripts = Join-Path $destination 'Scripts'
if (Test-Path -LiteralPath $destScripts) {
    $backup = Join-Path $destination ('backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss-ffff'))
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    Get-ChildItem -LiteralPath $destScripts -File -Filter '*.lua' | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $backup $_.Name)
    }
    Write-Host "Previous scripts backed up to $backup (config.json is never replaced)"
}
New-Item -ItemType Directory -Path $destScripts -Force | Out-Null
$copies = @()
foreach ($file in $scripts) {
    $copies += @{ Source = $file.FullName; Destination = (Join-Path $destScripts $file.Name) }
}
# Copy only code and documentation. The player's root config.json stays outside this list.
foreach ($fileName in @('LICENSE', 'README.md', 'CHANGELOG.md', 'CONFIG.md', 'config.example.json', 'THIRD-PARTY.md')) {
    $copies += @{ Source = (Join-Path $projectRoot $fileName); Destination = (Join-Path $destination $fileName) }
}
foreach ($copy in $copies) {
    Copy-Item -LiteralPath $copy.Source -Destination $copy.Destination -Force
    if ((Get-FileHash -LiteralPath $copy.Source -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath $copy.Destination -Algorithm SHA256).Hash) {
        throw "SHA256 mismatch: $($copy.Destination)"
    }
}
Write-Host "Deployed and SHA256 verified: $destination"
$modsTxt = Join-Path $modsDir 'mods.txt'
$enabled = (Test-Path -LiteralPath $modsTxt) -and
    (Select-String -LiteralPath $modsTxt -Pattern '^\s*SRankAlert\s*:\s*1\s*$' -Quiet)
if (-not $enabled) { Write-Host "Add 'SRankAlert : 1' above Keybinds in $modsTxt, then restart the game." }
else { Write-Host 'mods.txt already enables SRankAlert. Restart the game.' }
