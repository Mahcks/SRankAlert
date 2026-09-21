"""Exercise the shipped installer and Lua config loader against real isolated files."""
from pathlib import Path
from tempfile import TemporaryDirectory
from shutil import copy2, copytree
from hashlib import sha256
import json
import subprocess
from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


def fingerprint(path):
    return sha256(path.read_bytes()).hexdigest(), path.stat().st_mtime_ns


with TemporaryDirectory(prefix="srankalert-lifecycle-") as temporary:
    fixture = Path(temporary)
    package = fixture / "Extracted Mod [test]"
    copytree(ROOT / "Scripts", package / "Scripts")
    for name in ("Install.ps1", "LICENSE", "README.md", "CHANGELOG.md", "CONFIG.md", "config.example.json", "THIRD-PARTY.md"):
        copy2(ROOT / name, package / name)
    # Even a mistakenly included config in the extracted folder must not be copied.
    (package / "config.json").write_text('{"ACTION_KEY":"WrongPackagedSetting"}', encoding="utf-8")
    game = fixture / "Game [test]"
    ue4ss = game / "ReadyOrNot/Binaries/Win64/ue4ss"
    mods = ue4ss / "Mods"
    mods.mkdir(parents=True)
    (ue4ss / "UE4SS.dll").write_bytes(b"test prerequisite; not executable")
    (mods / "mods.txt").write_bytes(b"OtherMod : 0\r\nKeybinds : 1\r\n")
    installed = mods / "SRankAlert"
    config_path = installed / "config.json"
    # Authorize only the installer's expected replacement prompt; no real game is used.
    runner = fixture / "run-installer.ps1"
    runner.write_text('''param([string]$Installer, [string]$GameRoot)
$ErrorActionPreference = 'Stop'
function Get-Process { param($Name, $ErrorAction) return $null }
function Read-Host {
    param($Prompt)
    if ($Prompt -ne 'Type YES to approve, or press Enter to leave it alone') { throw "Unexpected prompt: $Prompt" }
    return 'YES'
}
& $Installer -GameRoot $GameRoot -NoPause
''', encoding="utf-8")

    def install():
        result = subprocess.run(
            ["powershell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
             "-File", str(runner), "-Installer", str(package / "Install.ps1"), "-GameRoot", str(game)],
            capture_output=True, text=True, check=True, timeout=30,
        )
        assert "Installation complete." in result.stdout, result.stdout + result.stderr
        assert "Installation stopped:" not in result.stdout, result.stdout
        return result.stdout

    def load_config():
        # Resolve config.json from the installed module location, just as UE4SS does.
        lua = LuaRuntime()
        lua.globals().scripts_path = (installed / "Scripts/?.lua").as_posix()
        lua.execute('package.path = scripts_path .. ";" .. package.path')
        logs = []
        lua.globals().config_test_log = logs.append
        values = lua.execute('return require("sra_config").load(function(s) config_test_log(s) end)')
        return values, logs

    install()
    assert not config_path.exists(), "Installer shipped/generated a config instead of leaving first load to the mod"
    first, logs = load_config()
    generated = json.loads(config_path.read_text(encoding="utf-8"))
    assert first["ACTION_KEY"] == generated["ACTION_KEY"] == "F9"
    assert first["RESTART_ENABLED"] is False and generated["RESTART_ENABLED"] is False
    assert any("config created with defaults:" in line for line in logs)
    assert any("config loaded:" in line for line in logs)

    # Change a setting, then run an actual update of the installed code.
    generated.update(ACTION_KEY="F11", RESTART_ENABLED=False, SCALE=1.25)
    config_path.write_text(json.dumps(generated, indent=2), encoding="utf-8")
    before = fingerprint(config_path)
    old_main = installed / "Scripts/main.lua"
    old_main.write_text("-- old version to replace\n", encoding="utf-8")
    mod_list_before = fingerprint(mods / "mods.txt")
    output = install()
    assert "Copied:" in output and "main.lua" in output
    assert old_main.read_bytes() == (package / "Scripts/main.lua").read_bytes()
    assert fingerprint(config_path) == before, "Installer altered config contents or write time"
    assert fingerprint(mods / "mods.txt") == mod_list_before, "Update changed an enabled mod list"
    assert not list(installed.glob("config.json.SRankAlert-backup-*")), "Config was included in replacement backups"
    after, logs = load_config()
    assert after["ACTION_KEY"] == "F11" and after["RESTART_ENABLED"] is False and after["SCALE"] == 1.25
    assert fingerprint(config_path) == before, "Loading changed the saved config"

    # A broken value falls back by field; other saved choices remain effective.
    generated["POLL_MS"] = "not a duration"
    config_path.write_text(json.dumps(generated), encoding="utf-8")
    corrupt_before = fingerprint(config_path)
    repaired, logs = load_config()
    assert repaired["POLL_MS"] == 350 and repaired["ACTION_KEY"] == "F11"
    assert any("config warning: POLL_MS" in line for line in logs)
    assert fingerprint(config_path) == corrupt_before, "Loader rewrote the invalid field on disk"
    install()
    assert fingerprint(config_path) == corrupt_before, "Reinstall changed an invalid config"

    # Even invalid JSON is preserved on update; only runtime defaults change.
    config_path.write_text('{"POLL_MS": broken', encoding="utf-8")
    corrupt_before = fingerprint(config_path)
    install()
    defaults, logs = load_config()
    assert defaults["ACTION_KEY"] == "F9" and any("config warning: config.json" in line for line in logs)
    assert defaults["RESTART_ENABLED"] is False, "Broken JSON enabled restart"
    assert fingerprint(config_path) == corrupt_before

    # Existing explicit opt-ins also survive updates; changing defaults is not a migration.
    config_path.write_text('{"RESTART_ENABLED":true}', encoding="utf-8")
    opted_in_before = fingerprint(config_path)
    install()
    opted_in, logs = load_config()
    assert opted_in["RESTART_ENABLED"] is True and fingerprint(config_path) == opted_in_before

print("lifecycle: fresh installed config generation, edited settings surviving real installer update, invalid-field fallback/logging, corrupt-file preservation passed")
