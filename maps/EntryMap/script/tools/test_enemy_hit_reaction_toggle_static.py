from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ENTRY_CONFIG = ROOT / "config" / "entry_config.lua"
BATTLEFIELD = ROOT / "runtime" / "battlefield.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_entry_config_disables_enemy_hit_reaction_by_default() -> None:
    config = read_text(ENTRY_CONFIG)
    assert "enemy_hit_reaction_enabled = false" in config


def test_battlefield_gates_enemy_hit_reaction_event_by_config() -> None:
    battlefield = read_text(BATTLEFIELD)
    assert "if CONFIG.enemy_hit_reaction_enabled ~= false then" in battlefield
    assert "unit:event('单位-受到伤害后', function(_, data)" in battlefield
