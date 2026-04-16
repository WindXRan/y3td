from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HUD_PATH = ROOT / "ui" / "runtime_hud.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_runtime_hud_challenge_status_uses_per_challenge_charge_count() -> None:
    source = read_text(HUD_PATH)
    assert "local challenge_buttons = {" not in source
    assert "runtime_hud.challenge_buttons" not in source


if __name__ == "__main__":
    test_runtime_hud_challenge_status_uses_per_challenge_charge_count()
    print("runtime hud challenge charge static ok")
