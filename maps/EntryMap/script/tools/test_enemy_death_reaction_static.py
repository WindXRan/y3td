from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BATTLEFIELD = ROOT / "runtime" / "battlefield.lua"


def test_enemy_death_reaction_is_wired() -> None:
    content = BATTLEFIELD.read_text(encoding="utf-8")

    assert "local function play_enemy_death_reaction(unit, info, data)" in content
    assert "local play_enemy_death_sound = env.play_enemy_death_sound" in content
    assert "local source_unit = data and data.source_unit or nil" in content
    assert "play_enemy_death_sound(unit, info)" in content
    assert "unit:mover_line({" in content
    assert "particle:mover_line({" in content
    assert "102702" in content
    assert "102705" in content
    assert "102706" in content
    assert "102877" in content
    assert "102820" in content
    assert "unit:event('单位-死亡', function(_, data)" in content
    assert "local corpse_remove_delay = play_enemy_death_reaction(unit, info, data)" in content
    assert "y3.ltimer.wait(corpse_remove_delay, function()" in content
