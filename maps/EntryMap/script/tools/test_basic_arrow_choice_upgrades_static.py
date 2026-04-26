from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
UPGRADES = ROOT / "script" / "runtime" / "attack_upgrades.lua"
INPUT_EVENTS = ROOT / "script" / "runtime" / "input_events.lua"
ATTACK_SKILLS = ROOT / "script" / "runtime" / "attack_skills.lua"
BOOT = ROOT / "script" / "runtime" / "boot.lua"
SYNC = ROOT / "script" / "tools" / "sync_runtime_editor_objects.py"


def test_reference_arrow_upgrades_are_four_choice_options() -> None:
    content = UPGRADES.read_text(encoding="utf-8")

    assert "local UPGRADE_CHOICE_COUNT = 4" in content
    assert "pick_upgrade_choices(UPGRADE_CHOICE_COUNT)" in content
    assert "攻击技能强化 4 选 1" in content

    for key, name in {
        "basic_poison_arrow": "淬毒箭",
        "basic_power_arrow": "强化箭",
        "basic_explosive_arrow": "爆炸箭",
        "basic_sniper_arrow": "狙击箭",
    }.items():
        assert f"key = '{key}'" in content
        assert f"name = '{name}'" in content


def test_fourth_keyboard_choice_is_bound() -> None:
    content = INPUT_EVENTS.read_text(encoding="utf-8")
    assert "y3.const.KeyboardKey['KEY_4']" in content
    assert "apply_round_choice(4)" in content


def test_poison_arrow_runtime_fields_are_wired() -> None:
    attack_content = ATTACK_SKILLS.read_text(encoding="utf-8")
    boot_content = BOOT.read_text(encoding="utf-8")

    assert "local function apply_poison_on_hit(target)" in attack_content
    assert "get_effective_skill_value(skill, 'poison_tick_ratio')" in attack_content
    assert "apply_enemy_status(target, 'poison', status)" in attack_content
    assert "info.status.poison = nil" in attack_content

    assert "poison_duration = 0" in boot_content
    assert "poison_tick_ratio = 0" in boot_content
    assert "poison_max_stacks = 0" in boot_content


def test_arrow_projectile_profiles_cover_at_least_ten_styles() -> None:
    content = SYNC.read_text(encoding="utf-8")
    assert "ARROW_PROJECTILE_PROFILES = {" in content
    assert content.count('("') >= 10
    for style_name in [
        "破空箭",
        "金翎穿云箭",
        "玄光长虹箭",
        "玄冰裂羽箭",
        "雷音连珠箭",
        "火云爆裂箭",
        "月轮回旋箭",
    ]:
        assert style_name in content
