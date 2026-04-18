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

    assert "basic_attack,普攻,1,御使 1 口本命飞剑破空诛敌，造成 125% 攻击的金行飞剑伤害。,物理,weapon,metal,金行飞剑,1.25,1.05,820" in skills_csv
    assert "basic_attack,134267104,1880,1.45,28,,,,,,,,,,,,,,,," in vfx_csv

    assert "local effective_base_interval = math.max(0.15, (skill.base_cooldown or 1.7) * (1 - math.max(0, skill.cooldown_reduction or 0)))" in attack_content
    assert "local interval_offset = y3.helper.tonumber(get_hero_attr('攻击间隔')) or 0" in attack_content
    assert "local attack_speed = math.max(20, get_hero_attr('攻击速度') + (skill.attack_speed_bonus or 0))" in attack_content
    assert "return math.max(0.15, effective_base_interval * 100 / attack_speed + interval_offset)" in attack_content
    assert "play_skill_particle_on_unit(skill, STATE.hero, 'cast')" in attack_content

    assert "local basic_attack_vfx = AttackSkillObjects.vfx_by_id.basic_attack or {}" in boot_content
    assert "local basic_chain_particle = basic_attack_vfx.chain_particle" in boot_content
    assert "deal_skill_damage(unit, data.damage * skill.chain_ratio, basic_attack_def, {" in boot_content
