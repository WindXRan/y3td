from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ATTACK_SKILLS = ROOT / "runtime" / "attack_skills.lua"
REWARDS = ROOT / "runtime" / "rewards.lua"


def test_basic_attack_range_has_post_evolution_fallback() -> None:
    content = ATTACK_SKILLS.read_text(encoding="utf-8")

    assert "STATE.last_valid_basic_attack_range" in content
    assert "remember_basic_attack_range" in content
    assert "ATTACK_SKILL_DEFS.basic_attack.base_range" in content


def test_evolution_only_replaces_model() -> None:
    content = REWARDS.read_text(encoding="utf-8")

    assert "resolve_evolution_target_model_id" in content
    assert "y3.unit.get_model_by_key(target_unit_id)" in content
    assert "hero:replace_model(target_model_id)" in content
