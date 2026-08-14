"""Static checks for JokCombat's public release metadata and archive manifest."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VERSION = "2.1.0"
TAG = f"v{VERSION}"


def read(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def test_release_versions_are_consistent() -> None:
    assert f'local VERSION = "{TAG}"' in read("JokCombat_CombatPrototype.lua")
    assert f"**Version {VERSION}**" in read("README.md")
    assert f"# JokCombat {TAG} Technical Design" in read(
        "docs/TECHNICAL_DESIGN.md"
    )
    assert f"Stato: **{TAG}" in read("docs/JokCombat_BranchCombo_Mapping.md")
    assert f"## {VERSION} - 2026-08-14" in read("CHANGELOG.md")


def test_release_manifest_is_minimal_and_complete() -> None:
    build_script = read("tools/Build-Release.ps1")
    expected = {
        "JokCombat_CombatPrototype.lua",
        "JokCombat_NativeAbilities.lua",
        "JokCombat_NativeKeyblades.lua",
        "JokCombat_DropRate.lua",
        "README.md",
        "CHANGELOG.md",
        "LICENSE",
    }
    for relative_path in expected:
        assert f'    "{relative_path}"' in build_script
        assert (ROOT / relative_path).is_file()

    for diagnostic in (
        "JokCombat_StateProbe.lua",
        "JokCombat_InputProbe.lua",
        "JokCombat_CommandMenuProbe.lua",
    ):
        assert f'    "{diagnostic}"' not in build_script

    assert '    "v2.1.0"' not in build_script
    assert '[string]$Version = "v2.1.0"' in build_script
    assert "System.IO.Compression.ZipArchive]::new" in build_script
    assert "$entry.LastWriteTime = $fixedTimestamp" in build_script
    assert "Compress-Archive" not in build_script
    assert "dist/" in read(".gitignore")


def main() -> None:
    test_release_versions_are_consistent()
    test_release_manifest_is_minimal_and_complete()
    print("PASS: v2.1.0 release metadata and seven-file manifest are consistent")


if __name__ == "__main__":
    main()
