# Only writes under tools/.deploy-test; never deploys to the real game.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path $projectRoot ('tools\.deploy-test\' + [guid]::NewGuid().ToString('N'))
$mods = Join-Path $fixture 'ReadyOrNot\Binaries\Win64\ue4ss\Mods'
New-Item -ItemType Directory -Path $mods -Force | Out-Null
$modsTxt = Join-Path $mods 'mods.txt'
Set-Content -LiteralPath $modsTxt -Value 'Keybinds : 1'
$modsHash = (Get-FileHash -LiteralPath $modsTxt).Hash
$deploy = Join-Path $projectRoot 'tools\deploy.ps1'
# Isolate the precondition from any unrelated running game on the machine.
function Get-Process { param($Name, $ErrorAction) return $null }
& $deploy -GameRoot $fixture -WhatIf
$dest = Join-Path $mods 'SRankAlert'
if (Test-Path -LiteralPath $dest) { throw '-WhatIf created a destination' }
& $deploy -GameRoot $fixture
$main = Join-Path $dest 'Scripts\main.lua'
if (-not (Test-Path -LiteralPath $main)) { throw 'main.lua not deployed' }
Set-Content -LiteralPath $main -Value '-- old script to preserve for rollback'
$config = Join-Path $dest 'config.json'
Set-Content -LiteralPath $config -Value '{"ACTION_KEY":"F11","RESTART_ENABLED":false}'
$configHash = (Get-FileHash -LiteralPath $config).Hash
& $deploy -GameRoot $fixture
$backups = @(Get-ChildItem -LiteralPath (Join-Path $dest 'backups') -Recurse -Filter main.lua)
if ($backups.Count -ne 1) { throw 'Expected one script backup' }
if ((Get-Content -LiteralPath $backups[0].FullName -Raw) -notmatch 'script to preserve') { throw 'Script backup was not preserved' }
if ((Get-FileHash -LiteralPath $config).Hash -ne $configHash) { throw 'Persistent config.json was modified' }
if ((Get-FileHash -LiteralPath $modsTxt).Hash -ne $modsHash) { throw 'mods.txt was modified' }
if ((Get-FileHash -LiteralPath $main).Hash -ne (Get-FileHash -LiteralPath (Join-Path $projectRoot 'Scripts\main.lua')).Hash) {
    throw 'Deployed main hash mismatch'
}
function Get-Process { param($Name, $ErrorAction) return @{ ProcessName = 'ReadyOrNot-test' } }
$rejected = $false
try { & $deploy -GameRoot $fixture } catch { $rejected = $_.Exception.Message -like 'Close Ready or Not*' }
if (-not $rejected) { throw 'Running-game precondition not enforced' }
Write-Host 'deploy: dry run, copy hashes, script backup, persistent config.json, mods.txt preservation and running-game refusal passed'
