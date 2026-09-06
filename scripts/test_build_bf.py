"""Offline builder/packaging regression with isolated source and tool fixtures."""
import os
from pathlib import Path
import shutil
import subprocess
from tempfile import TemporaryDirectory
import unittest

SCRIPT = Path(__file__).with_name("build_bf.sh")


class BetaflightBuildTest(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory(prefix="novax-bf-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for folder in ("scripts", "boards/AF-Test/betaflight", "firmware/betaflight", "sdk/bin", "mock-bin"):
            (self.root / folder).mkdir(parents=True)
        shutil.copyfile(SCRIPT, self.root / "scripts/build_bf.sh")
        (self.root / "boards/AF-Test/betaflight/config.h").write_text("// test config\n")
        (self.root / "firmware/betaflight/Makefile").touch()
        gcc = self.root / "sdk/bin/arm-none-eabi-gcc"
        gcc.write_text("#!/bin/sh\nprintf '13.3.1\\n'\n")
        gcc.chmod(0o755)
        make = self.root / "mock-bin/make"
        make.write_text('''#!/usr/bin/env bash
set -eu
for arg; do case "$arg" in BIN_DIR=*) output=${arg#*=};; CONFIG=*) board=${arg#*=};; esac; done
format=${!#}
echo "$format" >> "$TEST_ROOT/calls.txt"
mkdir -p "$output"
if [[ "$format" == hex ]]; then printf 'hex fixture' > "$output/betaflight_test_$board.hex";
elif [[ "$format" == binary && "${TEST_MISSING_BIN:-0}" != 1 ]]; then printf 'bin fixture' > "$output/betaflight_test_$board.bin"; fi
''')
        make.chmod(0o755)
        self.env = dict(os.environ, NOVAX_ARM_SDK_ROOT=str(self.root / "sdk"),
                        NOVAX_BF_BUILD_DIR=str(self.root / "build"),
                        NOVAX_RELEASE_DIR=str(self.root / "release"), TEST_ROOT=str(self.root),
                        PATH=str(self.root / "mock-bin") + os.pathsep + os.environ["PATH"])

    def run_build(self, board="AF-Test"):
        return subprocess.run(["bash", str(self.root / "scripts/build_bf.sh"), board],
                              env=self.env, text=True, capture_output=True)

    def test_formats_are_serial_and_sources_not_overwritten(self):
        result = self.run_build()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "calls.txt").read_text().splitlines(), ["hex", "binary"])
        self.assertEqual(len(list((self.root / "release").iterdir())), 2)
        self.assertFalse((self.root / "firmware/betaflight/src").exists())

    def test_missing_binary_fails_before_packaging(self):
        self.env["TEST_MISSING_BIN"] = "1"
        result = self.run_build()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Expected exactly one HEX and one BIN", result.stderr)
        self.assertFalse((self.root / "release").exists())

    def test_missing_source_is_not_treated_as_initialized(self):
        (self.root / "firmware/betaflight/Makefile").unlink()
        result = self.run_build()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Initialize the pinned source", result.stderr)
        self.assertFalse((self.root / "calls.txt").exists())

    def test_invalid_or_missing_board_does_not_build(self):
        for board in ("../AF-Test", "AF-Test;echo", "missing"):
            self.assertNotEqual(self.run_build(board).returncode, 0)
        self.assertFalse((self.root / "calls.txt").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
