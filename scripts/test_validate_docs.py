"""Counterexamples for the read-only documentation gate, using isolated fixtures."""
import contextlib
import io
from pathlib import Path
import shutil
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
import validate_docs


class DocumentationGateTest(unittest.TestCase):
    def setUp(self):
        self.directory = TemporaryDirectory(prefix="novax-doc-gate-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        source = validate_docs.ROOT
        for name in ("README.md", "README_ko.md", "README_ja.md", "VERSIONING.md"):
            shutil.copy2(source / name, self.root / name)
        for row in validate_docs.inventory():
            board = row["board"]
            for relative in ("VERSION", "ardupilot/hwdef.dat", "ardupilot/hwdef-bl.dat", "betaflight/config.h"):
                original = source / "boards" / board / relative
                if original.exists():
                    target = self.root / "boards" / board / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(original, target)
        self.override = patch.object(validate_docs, "ROOT", self.root)
        self.override.start()
        self.addCleanup(self.override.stop)

    def test_current_inventory_passes(self):
        with contextlib.redirect_stdout(io.StringIO()):
            validate_docs.check()

    def test_inventory_order_is_platform_independent(self):
        names = [row["board"] for row in validate_docs.inventory()]
        self.assertEqual(names, sorted(names, key=str.casefold))
        self.assertLess(names.index("AF-F4_nano"), names.index("AF-F4_T10_nano"))
        self.assertLess(names.index("AF-H7_nano"), names.index("AF-H7E"))

    def test_version_drift_fails(self):
        (self.root / "boards/AF-F4_nano/VERSION").write_text("99.0.0\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Stale/incomplete"):
            validate_docs.check()

    def test_gnss_returning_to_fc_fails(self):
        (self.root / "boards/AP-RTK_Test").mkdir()
        with self.assertRaisesRegex(ValueError, "GNSS product reappeared"):
            validate_docs.check()

    def test_bootloader_id_mismatch_fails(self):
        target = self.root / "boards/AF-F4_nano/ardupilot/hwdef-bl.dat"
        target.write_text(target.read_text(encoding="utf-8").replace("APJ_BOARD_ID 6203", "APJ_BOARD_ID 9999"), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "App/bootloader"):
            validate_docs.check()

    def test_missing_board_in_tree_fails(self):
        target = self.root / "README.md"
        target.write_text(target.read_text(encoding="utf-8").replace("│  ├─ AD-ME1/\n", ""), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Missing board in repository tree"):
            validate_docs.check()

    def test_chinese_translation_reappearing_fails(self):
        (self.root / "README_zh.md").write_text("fixture\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Chinese translation"):
            validate_docs.check()


if __name__ == "__main__":
    unittest.main(verbosity=2)
