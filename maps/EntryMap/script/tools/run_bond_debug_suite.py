import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "script" / "tools"


TEST_FILES = [
    "test_bond_projectile_visual_static.py",
    "test_bond_debug_tools_static.py",
]


def run_one(file_name: str) -> tuple[bool, str]:
    path = TOOLS / file_name
    if not path.exists():
        return False, f"[MISS] {file_name} not found"
    result = subprocess.run(
        [sys.executable, str(path)],
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if result.returncode == 0:
        return True, f"[PASS] {file_name}: {result.stdout.strip()}"
    stderr = result.stderr.strip()
    stdout = result.stdout.strip()
    detail = stderr or stdout or f"exit={result.returncode}"
    return False, f"[FAIL] {file_name}: {detail}"


def main() -> int:
    passed = 0
    failed = 0
    for file_name in TEST_FILES:
        ok, line = run_one(file_name)
        print(line)
        if ok:
            passed += 1
        else:
            failed += 1

    print(f"bond debug suite summary: pass={passed}, fail={failed}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
