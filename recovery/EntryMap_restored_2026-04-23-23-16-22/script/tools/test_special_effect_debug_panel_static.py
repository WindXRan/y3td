from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]


def read(rel_path: str) -> str:
    return (ROOT / rel_path).read_text(encoding="utf-8")


def assert_contains(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def test_effect_debug_module_is_wired() -> None:
    boot_text = read("maps/EntryMap/script/runtime/boot.lua")
    session_state_text = read("maps/EntryMap/script/runtime/session_state.lua")
    auto_effect_text = read("maps/EntryMap/script/runtime/auto_active_effects.lua")
    effect_debug_text = read("maps/EntryMap/script/runtime/effect_debug.lua")
    debug_actions_text = read("maps/EntryMap/script/runtime/debug_actions.lua")
    debug_tools_text = read("maps/EntryMap/script/runtime/debug_tools.lua")

    assert (ROOT / "maps/EntryMap/script/runtime/effect_debug.lua").exists(), "missing runtime/effect_debug.lua"

    assert_contains(boot_text, "local EffectDebugSystem = require 'runtime.effect_debug'", "boot require")
    assert_contains(boot_text, "local effect_debug_system", "boot local")
    assert_contains(boot_text, "effect_debug_runtime = nil", "state slot")
    assert_contains(boot_text, "effect_debug_system = EffectDebugSystem.create({", "boot create")
    assert_contains(boot_text, "create_effect_debug_runtime = create_effect_debug_runtime", "session state injection")
    assert_contains(boot_text, "get_modifier_name_by_key", "boot modifier name injection")

    assert_contains(session_state_text, "local create_effect_debug_runtime = env.create_effect_debug_runtime", "session state env")
    assert_contains(session_state_text, "STATE.effect_debug_runtime = create_effect_debug_runtime()", "battle reset state")

    assert_contains(auto_effect_text, "is_debug_effect_mounted", "auto effect debug mount hook")
    assert_contains(auto_effect_text, "get_effect_runtime_snapshot", "auto effect snapshot")
    assert_contains(auto_effect_text, "force_trigger_effect", "auto effect force trigger")
    assert_contains(auto_effect_text, "last_modifier_apply", "auto effect modifier apply runtime")
    assert_contains(auto_effect_text, "record_modifier_apply", "auto effect modifier apply recorder")
    assert_contains(effect_debug_text, "modifier_key", "effect debug modifier detail")
    assert_contains(effect_debug_text, "modifier_name", "effect debug modifier name detail")
    assert_contains(effect_debug_text, "最近挂Buff", "effect debug last modifier apply detail")
    assert_contains(effect_debug_text, "Buff资源", "effect debug modifier resource detail")

    assert_contains(debug_actions_text, "debug_mount_effect", "debug action mount")
    assert_contains(debug_actions_text, "debug_unmount_effect", "debug action unmount")
    assert_contains(debug_actions_text, "debug_clear_mounted_effects", "debug action clear")
    assert_contains(debug_actions_text, "debug_trigger_effect", "debug action trigger")

    assert_contains(debug_tools_text, "特效调试", "gm effect debug button")
    assert_contains(debug_tools_text, "debug_open_effect_debug_panel", "gm open panel action")
    assert_contains(debug_tools_text, "effect_debug", "effect debug ui refs")


if __name__ == "__main__":
    test_effect_debug_module_is_wired()
    print("ok")
