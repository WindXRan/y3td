"""验证 generated_skills.lua 不再写死 fireball 特例 hook"""
from pathlib import Path

GEN = Path(r"maps/EntryMap/script/runtime/generated_skills.lua")
text = GEN.read_text(encoding="utf-8")

# 确认不再写死 fireball 灼烧 hook
assert "apply_buff(unit, 'burn'" not in text, "generated_skills should not hardcode fireball burn hook"

# 确认使用 SkillHooks 注册表
assert "SkillHooks.get" in text, "generated_skills should use SkillHooks.get for hook mounting"

# 确认内建技能入口存在
assert "load_builtin_defs" in text, "generated_skills should have load_builtin_defs"

print("[PASS] test_generated_skills_smoke: generated_skills.lua 已解耦特例 hook")
