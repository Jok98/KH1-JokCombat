"""Checks for the standard LuaBackend local-deployment workflow."""

from hashlib import sha256
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
DEPLOY = ROOT / "tools" / "Deploy-Local.ps1"
RUNTIME_FILES = (
    "JokCombat_CombatPrototype.lua",
    "JokCombat_NativeAbilities.lua",
    "JokCombat_NativeKeyblades.lua",
    "JokCombat_DropRate.lua",
)
DIAGNOSTICS = (
    "JokCombat_StateProbe.lua",
    "JokCombat_InputProbe.lua",
    "JokCombat_CommandMenuProbe.lua",
    "JokCombat_MPHitProbe.lua",
)


def digest(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


class LocalDeployTests(unittest.TestCase):
    def test_standard_steam_documents_path_is_the_default(self) -> None:
        source = DEPLOY.read_text(encoding="utf-8")
        self.assertIn(
            "My Games\\KINGDOM HEARTS HD 1.5+2.5 ReMIX\\scripts\\kh1",
            source,
        )
        self.assertIn("[Environment+SpecialFolder]::MyDocuments", source)

    def test_default_manifest_contains_only_runtime_files(self) -> None:
        source = DEPLOY.read_text(encoding="utf-8")
        for filename in RUNTIME_FILES:
            self.assertIn(f'    "{filename}"', source)
        self.assertIn("$deployFiles = @($runtimeFiles)", source)
        self.assertIn("if ($IncludeDiagnostics)", source)

    def test_deployment_copies_and_verifies_runtime_files(self) -> None:
        shell = shutil.which("pwsh") or shutil.which("powershell")
        if shell is None:
            self.skipTest("PowerShell is required for the deployment test")

        with tempfile.TemporaryDirectory() as temporary_directory:
            destination = Path(temporary_directory) / "scripts" / "kh1"
            result = subprocess.run(
                [
                    shell,
                    "-NoProfile",
                    "-File",
                    str(DEPLOY),
                    "-DestinationDirectory",
                    str(destination),
                ],
                check=True,
                capture_output=True,
                text=True,
            )

            self.assertIn("Verified: 4 file(s)", result.stdout)
            for filename in RUNTIME_FILES:
                self.assertEqual(
                    digest(ROOT / filename), digest(destination / filename)
                )
            for filename in DIAGNOSTICS:
                self.assertFalse((destination / filename).exists())


if __name__ == "__main__":
    unittest.main()
