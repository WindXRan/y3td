"""验证 boot.lua 不再手写 custom_area_dot / custom_area_burst 注册块"""
from pathlib import Path

BOOT = Path(r"maps/EntryMap/script/runtime/boot.lua")
text = BOOT.read_text(encoding="utf-8")

# 确认不再有手写的技能注册块
assert "custom_area_dot" not in text, "boot.lua should not contain custom_area_dot registration"
assert "custom_area_burst" not in text, "boot.lua should not contain custom_area_burst registration"

# 确认批量注册入口存在
assert "GeneratedSkills.create" in text, "boot.lua should use GeneratedSkills.create for batch registration"

print("[PASS] test_runtime_skill_framework_smoke: boot.lua 已去掉手写技能注册")
