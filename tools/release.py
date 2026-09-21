"""Validate a tested release artifact and prepare its GitHub download instructions."""
import argparse
import re
from hashlib import sha256
from pathlib import Path
from zipfile import ZipFile


def prepare(tag, artifact_dir, notes_file):
    root = Path(__file__).resolve().parents[1]
    main = (root / "Scripts/main.lua").read_text(encoding="utf-8")
    version = re.search(r"loaded v(\d+\.\d+\.\d+);", main).group(1)
    if tag != f"v{version}":
        raise ValueError(f"Tag {tag!r} does not match runtime v{version}")
    archive_path = Path(artifact_dir) / f"SRankAlert-{version}.zip"
    with ZipFile(archive_path) as archive:
        expected = {"SRankAlert/" + path.relative_to(root).as_posix(): path
                    for path in (root / "Scripts").glob("*.lua")}
        expected.update({"SRankAlert/" + name: root / name for name in
                         ("LICENSE", "README.md", "CHANGELOG.md", "CONFIG.md",
                          "config.example.json", "THIRD-PARTY.md", "Install.ps1")})
        if len(archive.namelist()) != len(expected) or set(archive.namelist()) != set(expected):
            raise ValueError("Release ZIP contents do not match the expected public package")
        for name, path in expected.items():
            if archive.read(name) != path.read_bytes():
                raise ValueError(f"Release ZIP does not match the tagged source: {name}")
    changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")
    section = re.search(rf"^## {re.escape(version)}(?:\s[^\n]*)?\n(.*?)(?=^## |\Z)",
                        changelog, re.M | re.S)
    if not section:
        raise ValueError(f"No changelog entry for {version}")
    repo = "https://github.com/Mahcks/SRankAlert"
    notes = (
        f"Download **[SRankAlert-{version}.zip]({repo}/releases/download/{tag}/{archive_path.name})** below. "
        "The automatically generated Source code archives are for development; use the named mod ZIP to install.\n\n"
        "Requires **experimental UE4SS**, installed separately. Close the game, extract the entire ZIP, "
        "then run `Install.ps1` or follow `README.md`. Updates preserve your `config.json`.\n\n"
        f"[Installation guide]({repo}/blob/{tag}/README.md#installing) · "
        f"[Settings guide]({repo}/blob/{tag}/CONFIG.md)\n\n"
        "## Changes\n\n" + section.group(1).strip() + "\n\n"
        "Hold-to-restart is on by default and has had limited live testing (set `RESTART_ENABLED` "
        "to `false` for dismiss only). Automated checks do not establish in-game rendering.\n\n"
        f"SHA-256 (`{archive_path.name}`):\n```text\n{sha256(archive_path.read_bytes()).hexdigest()}\n```\n"
    )
    Path(notes_file).write_text(notes, encoding="utf-8")
    return archive_path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--artifact-dir", required=True, type=Path)
    parser.add_argument("--notes-file", required=True, type=Path)
    args = parser.parse_args()
    print(prepare(args.tag, args.artifact_dir, args.notes_file))
