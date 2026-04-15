from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HUD_PATH = ROOT / "ui" / "runtime_hud.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_runtime_hud_challenge_status_uses_per_challenge_charge_count() -> None:
    source = read_text(HUD_PATH)
    assert "if get_challenge_charge_count(challenge_id) < (def and def.cost_charge or 1) then" in source
    assert "if (STATE.challenge_charges or 0) < (def and def.cost_charge or 1) then" not in source


if __name__ == "__main__":
    test_runtime_hud_challenge_status_uses_per_challenge_charge_count()
    print("runtime hud challenge charge static ok")
