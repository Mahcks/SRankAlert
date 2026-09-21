"""Build a distributable, verify its contents, and check that builds are reproducible."""
from pathlib import Path
from zipfile import ZipFile
import subprocess
import sys
import re
from shutil import copy2
from tempfile import TemporaryDirectory

root = Path(__file__).resolve().parents[1]
builder = root / "tools" / "package.py"


def build():
    result = subprocess.run([sys.executable, str(builder)], check=True, capture_output=True, text=True)
    # The builder prints the output path first; this also avoids selecting an old ZIP.
    path = Path(result.stdout.splitlines()[0])
    assert path.parent.resolve() == (root / "dist").resolve()
    return path


archive_path = build()
# A release must identify itself consistently in code, docs and the ZIP filename.
main = (root / "Scripts/main.lua").read_text(encoding="utf-8")
version = re.search(r'loaded v(\d+\.\d+\.\d+);', main).group(1)
assert main.startswith("-- SRankAlert " + version + " --")
assert archive_path.name == f"SRankAlert-{version}.zip", "Runtime/package version mismatch"
readme = (root / "README.md").read_text(encoding="utf-8")
assert f"Version {version}" in readme and f"loaded v{version};" in readme
assert f"dist/SRankAlert-{version}.zip" in readme
assert f"Settings reference for version {version}." in (root / "CONFIG.md").read_text(encoding="utf-8")
assert f"## {version}" in (root / "CHANGELOG.md").read_text(encoding="utf-8")
first_build = archive_path.read_bytes()
with ZipFile(archive_path) as archive:
    assert archive.testzip() is None, "ZIP failed its integrity check"
    names = set(archive.namelist())
    public_docs = {"README.md", "LICENSE", "CHANGELOG.md", "CONFIG.md", "config.example.json", "THIRD-PARTY.md", "Install.ps1"}
    required = {"SRankAlert/" + name for name in public_docs}
    required |= {"SRankAlert/Scripts/" + path.name for path in (root / "Scripts").glob("*.lua")}
    assert names == required, f"Unexpected/missing release files: {names ^ required}"
    assert not {"SRankAlert/API-NOTES.md", "SRankAlert/DEV-NOTES.md", "SRankAlert/config.json"} & names
    for name in names:
        relative = name.removeprefix("SRankAlert/")
        assert archive.read(name) == (root / relative).read_bytes(), f"Packaged bytes differ: {name}"

assert build().read_bytes() == first_build, "Identical sources produced different ZIP bytes"
# Run the lifecycle harness against the extracted ZIP, not a reconstruction from
# source files. Only the temporary extraction gains a tests folder; the ZIP does not.
with TemporaryDirectory(prefix="srankalert-release-") as temporary:
    with ZipFile(archive_path) as archive:
        archive.extractall(temporary)
    extracted = Path(temporary) / "SRankAlert"
    harness = extracted / "tests" / "config_lifecycle.py"
    harness.parent.mkdir()
    copy2(root / "tests/config_lifecycle.py", harness)
    subprocess.run([sys.executable, str(harness)], check=True, timeout=120)
print("package: matching versions, public files only, exact bytes, reproducible ZIP and extracted-ZIP install/update passed")
print(archive_path)
