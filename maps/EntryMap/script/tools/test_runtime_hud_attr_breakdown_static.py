from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HUD_PATH = ROOT / "ui" / "runtime_hud_v2.lua"
NODES_PATH = ROOT / "ui" / "runtime_hud_nodes.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_bottom_bg_bonus_nodes_are_bound_from_prefab_paths() -> None:
    source = read_text(NODES_PATH)
    for token in [
        "bottom_attack_percent_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.攻击力.百分比加成')",
        "bottom_attack_value_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.攻击力.数值加成')",
        "bottom_strength_percent_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.力量.百分比加成')",
        "bottom_strength_value_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.力量.数值加成')",
        "bottom_agility_percent_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.敏捷.百分比加成')",
        "bottom_agility_value_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.敏捷.数值加成')",
        "bottom_intelligence_percent_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.智力.百分比加成')",
        "bottom_intelligence_value_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.智力.数值加成')",
        "bottom_armor_percent_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.护甲值.百分比加成')",
        "bottom_armor_value_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.护甲值.数值加成')",
        "bottom_attack_value = resolve_prefab_node(prefab, 'layout_1.mid.panel.攻击力.value')",
        "bottom_strength_value = resolve_prefab_node(prefab, 'layout_1.mid.panel.力量.value_1')",
    ]:
        assert token in source


def test_runtime_hud_formats_and_writes_all_breakdown_fields() -> None:
    source = read_text(HUD_PATH)
    for token in [
        "local function combine_percent_bonus(value_a, value_b)",
        "local function format_percent_bonus_text(value_a, value_b)",
        "local function format_signed_compact(value)",
        "set_optional_text(runtime_hud.bottom_attack_percent, '攻击力')",
        "set_optional_text(runtime_hud.bottom_attack_percent_bonus, format_percent_bonus_text(",
        "set_optional_text(runtime_hud.bottom_attack_value_bonus, format_signed_compact(",
        "set_optional_text(runtime_hud.bottom_strength_percent, '力量')",
        "set_optional_text(runtime_hud.bottom_strength_percent_bonus, format_percent_bonus_text(",
        "set_optional_text(runtime_hud.bottom_strength_value_bonus, format_signed_compact(",
        "set_optional_text(runtime_hud.bottom_agility_percent, '敏捷')",
        "set_optional_text(runtime_hud.bottom_intelligence_percent, '智力')",
        "set_optional_text(runtime_hud.bottom_armor_percent, '护甲值')",
    ]:
        assert token in source


if __name__ == "__main__":
    test_bottom_bg_bonus_nodes_are_bound_from_prefab_paths()
    test_runtime_hud_formats_and_writes_all_breakdown_fields()
