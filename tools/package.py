"""Create a deterministic mod ZIP containing only distributable files."""
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED
from hashlib import sha256

root = Path(__file__).resolve().parents[1]
files = sorted((root / "Scripts").glob("*.lua"))
# Never ship the user's config.json; the mod generates defaults only on first load.
files += [root / name for name in ("LICENSE", "README.md", "CHANGELOG.md", "CONFIG.md", "config.example.json", "THIRD-PARTY.md", "Install.ps1")]
output = root / "dist" / "SRankAlert-0.5.1.zip"
output.parent.mkdir(exist_ok=True)
with ZipFile(output, "w") as archive:
    for path in files:
        info = ZipInfo("SRankAlert/" + path.relative_to(root).as_posix(), (2026, 9, 20, 0, 0, 0))
        info.compress_type = ZIP_DEFLATED
        archive.writestr(info, path.read_bytes())
print(output)
print("SHA256:", sha256(output.read_bytes()).hexdigest())
