from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parent


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=ROOT.parent.parent.parent,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )


def assert_ok(result: subprocess.CompletedProcess[str], message: str) -> None:
    if result.returncode != 0:
        sys.stderr.write(result.stdout)
        sys.stderr.write(result.stderr)
        raise AssertionError(message)


result = run([sys.executable, "maps/EntryMap/script/tools/verify_csv_object_tables.py"])
if result.returncode != 0 and "can't open file" in result.stderr:
    result = run([sys.executable, "EntryMap/script/tools/verify_csv_object_tables.py"])
assert_ok(result, "verify_csv_object_tables.py should succeed")

assert "[OK] treasure catalog consistency smoke passed" in result.stdout, (
    "verify_csv_object_tables.py should run treasure catalog consistency smoke"
)
assert "[OK] marks catalog consistency smoke passed" in result.stdout, (
    "verify_csv_object_tables.py should run marks catalog consistency smoke"
)
assert "[OK] stages catalog consistency smoke passed" in result.stdout, (
    "verify_csv_object_tables.py should run stages catalog consistency smoke"
)
assert "[OK] waves challenges catalog consistency smoke passed" in result.stdout, (
    "verify_csv_object_tables.py should run waves challenges catalog consistency smoke"
)
assert "[OK] bond catalog consistency smoke passed" in result.stdout, (
    "verify_csv_object_tables.py should run bond catalog consistency smoke"
)
assert "[OK] hero level progression csv loader smoke passed" in result.stdout, (
    "verify_csv_object_tables.py should run hero level progression csv loader smoke"
)
assert "[OK] gear upgrade config csv loader smoke passed" in result.stdout, (
    "verify_csv_object_tables.py should run gear upgrade config csv loader smoke"
)
assert "[OK] config catalog consistency smoke passed" in result.stdout, (
    "verify_csv_object_tables.py should run config catalog consistency smoke"
)
assert "[OK] outgame attr bonus config csv loader smoke passed" in result.stdout, (
    "verify_csv_object_tables.py should run outgame attr bonus config csv loader smoke"
)

print("verify csv object tables smoke ok")
