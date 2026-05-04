from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
RUNTIME_HUD_PATH = ROOT / "maps" / "EntryMap" / "script" / "ui" / "runtime_hud.lua"


def test_exp_bar_click_uses_dedicated_click_area_and_matching_fill_width():
    content = RUNTIME_HUD_PATH.read_text(encoding="utf-8")
    assert "local EXP_BAR_INNER_WIDTH = 260" in content
    assert "local EXP_BAR_FILL_LEFT = 122" in content
    assert "resolve_center_module_ui('exp_bar.evolve_click_area')" in content
    assert "set_visible_if_alive(resolve_center_module_ui('exp_bar.evolve_click_area'), can_evolve)" in content


def test_attr_rows_do_not_show_crit_or_crit_damage_side_text():
    content = RUNTIME_HUD_PATH.read_text(encoding="utf-8")
    assert "{ label = '战力', value = attack_value, delta = '' }" in content
    assert "delta = '暴击 ' .. format_percent" not in content
    assert "delta = '爆伤 ' .. format_percent" not in content


def test_skill_slot_hotkeys_are_not_rendered_for_passive_skills():
    content = RUNTIME_HUD_PATH.read_text(encoding="utf-8")
    assert "resolve_center_module_ui(prefix .. '.key')" not in content
    assert "resolve_center_module_ui(prefix .. '.cooldown')" not in content
    assert "resolve_center_module_ui(prefix .. '.label')" not in content
    assert "set_visible_if_alive(key_ui, false)" not in content


def test_bottom_action_buttons_use_short_labels():
    content = RUNTIME_HUD_PATH.read_text(encoding="utf-8")
    assert "draw_button.button'), '抽卡')" in content
    assert "reward_button.button'), '已吞')" in content
    assert "kill_reward_button.button'), '杀敌')" in content
    assert "fish_button.button'), '钓鱼')" in content
    assert "reward_button.button'), '已吞卡牌')" not in content
    assert "kill_reward_button.button'), '杀敌抽奖')" not in content
    assert "fish_button.button'), '摆烂钓鱼')" not in content
