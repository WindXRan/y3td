from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BOOT_PATH = ROOT / "runtime" / "boot.lua"


source = BOOT_PATH.read_text(encoding="utf-8")

assert "require('runtime.hero_form_skills').create({" in source, (
    "boot.lua should create hero_form_skills_system from runtime.hero_form_skills"
)
assert "STATE.hero_form_skills_system.update(dt)" in source, (
    "boot.lua should update hero_form_skills_system"
)
assert "STATE.hero_form_skills_system.handle_enemy_kill(info)" in source, (
    "boot.lua should forward enemy kill events to hero_form_skills_system"
)
assert "STATE.hero_form_skills_system.handle_basic_attack_cast(target)" in source, (
    "boot.lua should forward basic attack casts to hero_form_skills_system"
)
assert "STATE.hero_form_skills_system.handle_attack_skill_cast(skill, target)" in source, (
    "boot.lua should forward attack skill casts to hero_form_skills_system"
)

print("hero form skill boot wiring static ok")
