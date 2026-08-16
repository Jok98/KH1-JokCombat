"""Static checks for JokCombat's OpenKH manifest and package inputs."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUNTIME_FILES = (
    "JokCombat_CombatPrototype.lua",
    "JokCombat_NativeAbilities.lua",
    "JokCombat_NativeKeyblades.lua",
    "JokCombat_DropRate.lua",
)
DIAGNOSTIC_FILES = (
    "JokCombat_StateProbe.lua",
    "JokCombat_InputProbe.lua",
    "JokCombat_CommandMenuProbe.lua",
    "JokCombat_MPHitProbe.lua",
)


def read(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def test_openkh_manifest_metadata() -> None:
    manifest = read("mod.yml")
    assert 'title: "KH1 JokCombat"' in manifest
    assert 'originalAuthor: "Jok"' in manifest
    assert "game: kh1" in manifest
    assert "assets:" in manifest


def test_openkh_manifest_contains_only_runtime_modules() -> None:
    manifest = read("mod.yml")
    assert manifest.count("  method: copy") == len(RUNTIME_FILES)
    for runtime_file in RUNTIME_FILES:
        block = (
            f"- name: scripts/{runtime_file}\n"
            "  method: copy\n"
            "  source:\n"
            f"  - name: {runtime_file}"
        )
        assert block in manifest
        assert (ROOT / runtime_file).is_file()
    for diagnostic_file in DIAGNOSTIC_FILES:
        assert diagnostic_file not in manifest


def test_release_builder_has_dedicated_openkh_archive() -> None:
    build_script = read("tools/Build-Release.ps1")
    assert '$openKhFiles = @("mod.yml") + $runtimeFiles' in build_script
    assert '$bundleName + "-OpenKH.zip"' in build_script
    assert "New-JokCombatArchive -Path $openKhArchivePath -Files $openKhFiles" in build_script
    assert "-OpenKH.zip.sha256" not in build_script


def main() -> None:
    test_openkh_manifest_metadata()
    test_openkh_manifest_contains_only_runtime_modules()
    test_release_builder_has_dedicated_openkh_archive()
    print("PASS: OpenKH manifest and dedicated runtime package are consistent")


if __name__ == "__main__":
    main()
