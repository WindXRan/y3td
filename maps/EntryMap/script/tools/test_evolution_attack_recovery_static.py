from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ATTACK_SKILLS = ROOT / "runtime" / "attack_skills.lua"
REWARDS = ROOT / "runtime" / "rewards.lua"


def test_basic_attack_range_has_post_evolution_fallback() -> None:
    content = ATTACK_SKILLS.read_text(encoding="utf-8")

    assert "STATE.last_valid_basic_attack_range" in content
    assert "remember_basic_attack_range" in content
    assert "ATTACK_SKILL_DEFS.basic_attack.base_range" in content


def test_evolution_restores_basic_attack_runtime_multiple_times() -> None:
    content = REWARDS.read_text(encoding="utf-8")

    assert "cooldown_remaining = 0" in content
    assert "for _, delay in ipairs({ 0.03, 0.12, 0.35 }) do" in content
    assert "延迟再补一轮恢复" in content
