"""Read-only documentation gate. No build, firmware signing, publishing or hardware I/O."""
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def field(text, name):
    match = re.search(rf"^{re.escape(name)}\s+([^\n#]+)", text, re.M)
    if not match:
        raise ValueError(f"Missing hardware definition field: {name}")
    return match[1].strip()


def inventory():
    rows = []
    # Path ordering differs between WindowsPath (case-insensitive) and
    # PosixPath (case-sensitive). Keep README ordering identical on both.
    for board in sorted((ROOT / "boards").iterdir(), key=lambda path: path.name.casefold()):
        if board.name.startswith("AP-RTK_"):
            raise ValueError("GNSS product reappeared in the FC repository")
        definition = board / "ardupilot/hwdef.dat"
        if not definition.is_file():
            continue
        hwdef = definition.read_text(encoding="utf-8")
        boot = (board / "ardupilot/hwdef-bl.dat").read_text(encoding="utf-8")
        board_id = field(hwdef, "APJ_BOARD_ID")
        if board_id != field(boot, "APJ_BOARD_ID"):
            raise ValueError(f"App/bootloader board ID mismatch: {board.name}")
        version = (board / "VERSION").read_text(encoding="utf-8").strip()
        if not re.fullmatch(r"\d+\.\d+\.\d+", version):
            raise ValueError(f"Invalid board version: {board.name}")
        peripheral = board.name.startswith("AP-RTK_")
        config = "AP_Periph" if peripheral else "ArduPilot"
        if (board / "betaflight/config.h").is_file():
            config += " + Betaflight config"
        rows.append({"board": board.name, "boardId": board_id, "version": version,
                     "mcuTarget": field(hwdef, "MCU").split()[-1], "config": config,
                     "scope": "GNSS (transitional)" if peripheral else ("Rebrand variant" if board.name == "AD-ME1" else "FC")})
    if not rows:
        raise ValueError("Empty board inventory")
    return rows


def table(rows):
    lines = ["| Board directory | Scope | Build MCU target | Board ID | Source version | Configuration present |",
             "|---|---|---|---|---|---|"]
    for row in rows:
        name = row["board"]
        lines.append(f'| [{name}](boards/{name}/ardupilot/) | {row["scope"]} | `{row["mcuTarget"]}` | {row["boardId"]} | {row["version"]} | {row["config"]} |')
    return "\n".join(lines)


def check():
    rows = inventory()
    expected = table(rows)
    if (ROOT / "README_zh.md").exists():
        raise ValueError("Removed Chinese translation reappeared")
    for name in ("README.md", "README_ko.md", "README_ja.md", "VERSIONING.md"):
        text = (ROOT / name).read_text(encoding="utf-8")
        actual = text.split("<!-- board-inventory:start -->\n", 1)[1].split("\n<!-- board-inventory:end -->", 1)[0]
        if actual != expected:
            raise ValueError(f"Stale/incomplete board table: {name}")
        for old in ("novaX-ALUX/fc-boards", "cd flight_controller", "git pull", "All flight controllers share", "README_zh.md", "[中文]"):
            if old in text:
                raise ValueError(f"Retired instruction in {name}: {old}")
        if name.startswith("README"):
            tree = text.split("```text\n", 1)[1].split("\n```", 1)[0]
            for row in rows:
                if f'{row["board"]}/' not in tree:
                    raise ValueError(f"Missing board in repository tree: {name} {row['board']}")
    print(f"PASS: {len(rows)} boards; app/bootloader IDs; source versions; three complete README inventories and trees; VERSIONING; retired instructions and Chinese translation absent")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--inventory", action="store_true")
    options = parser.parse_args()
    if options.inventory:
        print(json.dumps({"rows": inventory(), "table": table(inventory())}, ensure_ascii=False))
    else:
        check()
