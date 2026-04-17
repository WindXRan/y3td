from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ATTACK_SKILLS = ROOT / "runtime" / "attack_skills.lua"
BOOT = ROOT / "runtime" / "boot.lua"
ATTACK_SKILLS_CSV = ROOT / "data_csv" / "attack_skills.csv"
ATTACK_VFX_CSV = ROOT / "data_csv" / "attack_skill_vfx.csv"


def test_basic_attack_feel_config_and_runtime_hooks() -> None:
    attack_content = ATTACK_SKILLS.read_text(encoding="utf-8")
    boot_content = BOOT.read_text(encoding="utf-8")
    skills_csv = ATTACK_SKILLS_CSV.read_text(encoding="utf-8")
    vfx_csv = ATTACK_VFX_CSV.read_text(encoding="utf-8")

    assert "basic_attack,普攻,1,凝出 1 道御剑剑罡，造成 110% 攻击的金行剑罡伤害。,物理,weapon,metal,金行剑罡,1.1,1.25,760" in skills_csv
    assert "basic_attack,134222874,1680,1.35,34,102740,0.42,0.10,102731,0.90,0.24,,,,,,,102877,0.68,0.18," in vfx_csv

    assert "local effective_base_interval = math.max(0.15, (skill.base_cooldown or 1.7) * (1 - math.max(0, skill.cooldown_reduction or 0)))" in attack_content
    assert "local interval_offset = y3.helper.tonumber(get_hero_attr('攻击间隔')) or 0" in attack_content
    assert "local attack_speed = math.max(20, get_hero_attr('攻击速度') + (skill.attack_speed_bonus or 0))" in attack_content
    assert "return math.max(0.15, effective_base_interval * 100 / attack_speed + interval_offset)" in attack_content

    assert "local basic_attack_vfx = AttackSkillObjects.vfx_by_id.basic_attack or {}" in boot_content
    assert "local basic_chain_particle = basic_attack_vfx.chain_particle" in boot_content
    assert "deal_skill_damage(unit, data.damage * skill.chain_ratio, basic_attack_def, {" in boot_content
