from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
BOOT_PATH = ROOT / "runtime" / "boot.lua"


def count_top_level_locals(path: Path) -> int:
    count = 0
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line.startswith("local function "):
            count += 1
            continue
        if not line.startswith("local "):
            continue
        if "=" not in line:
            continue
        left = line[6:].split("=", 1)[0]
        count += len([name for name in left.split(",") if name.strip()])
    return count


def test_runtime_boot_stays_within_lua_local_budget() -> None:
    local_count = count_top_level_locals(BOOT_PATH)
    assert local_count <= 198, f"boot.lua top-level local budget is too high: {local_count}"


def test_runtime_boot_parses_with_luac() -> None:
    subprocess.run(["luac", "-p", str(BOOT_PATH)], check=True)


if __name__ == "__main__":
    test_runtime_boot_stays_within_lua_local_budget()
    test_runtime_boot_parses_with_luac()
    print("runtime boot local budget static ok")
