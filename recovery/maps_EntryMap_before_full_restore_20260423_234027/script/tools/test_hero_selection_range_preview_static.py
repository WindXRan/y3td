from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BOOT_PATH = ROOT / "runtime" / "boot.lua"
SESSION_STATE_PATH = ROOT / "runtime" / "session_state.lua"
HERO_SELECTION_RANGE_PATH = ROOT / "runtime" / "hero_selection_range.lua"


boot = BOOT_PATH.read_text(encoding="utf-8")
session_state = SESSION_STATE_PATH.read_text(encoding="utf-8")
hero_selection_range = HERO_SELECTION_RANGE_PATH.read_text(encoding="utf-8")

assert "local HeroSelectionRangeSystem = require 'runtime.hero_selection_range'" in boot, (
    "boot.lua should require runtime.hero_selection_range"
)
assert "hero_selection_range_system = HeroSelectionRangeSystem.create({" in boot, (
    "boot.lua should create hero_selection_range_system"
)
assert "hero_selection_range_system.register_runtime_events()" in boot, (
    "boot.lua should register hero selection range events"
)
assert "disable_local_attack_preview = function()" in boot, (
    "boot.lua should pass a local attack preview cleanup callback into session_state"
)

assert "local disable_local_attack_preview = env.disable_local_attack_preview" in session_state, (
    "session_state.lua should accept the local attack preview cleanup callback"
)
assert "disable_local_attack_preview()" in session_state, (
    "session_state.lua should turn off the local attack preview when battle state resets"
)

assert "y3.particle.create" in hero_selection_range, (
    "hero_selection_range.lua should create a local particle preview ring"
)
assert "RANGE_EFFECT_ID = 101492" in hero_selection_range, (
    "hero_selection_range.lua should use the attack range preview particle resource"
)
assert "get_current_basic_attack_range" in hero_selection_range, (
    "hero_selection_range.lua should scale from the runtime basic attack range"
)
assert "本地-鼠标-按下单位" in hero_selection_range, (
    "hero_selection_range.lua should only show the preview after the player clicks a unit locally"
)
assert "本地-选中-单位" in hero_selection_range, (
    "hero_selection_range.lua should react to local unit selection changes"
)
assert "本地-选中-取消" in hero_selection_range, (
    "hero_selection_range.lua should react to local deselection"
)
assert "disable_builtin_preview()" in hero_selection_range, (
    "hero_selection_range.lua should proactively disable the builtin attack preview ring"
)

print("hero selection range preview static ok")
