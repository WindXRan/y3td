from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / "runtime" / "bond_modifier_core_effects.lua"
SPECIAL = ROOT / "runtime" / "bond_modifier_special_effects.lua"
AUTO_ACCEPTANCE = ROOT / "runtime" / "battle_auto_acceptance.lua"
VISUAL_IDS = ROOT / "data" / "object_tables" / "bond_visual_editor_ids.lua"
EFFECTS = ROOT / "runtime" / "bond_modifier_effects.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def assert_contains(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise AssertionError(message)


def parse_visual_bonds() -> set[str]:
    text = read_text(VISUAL_IDS)
    bonds: set[str] = set()
    for raw in text.splitlines():
        line = raw.strip()
        if not line.startswith("['"):
            continue
        marker = "'] = {"
        idx = line.find(marker)
        if idx <= 2:
            continue
        bonds.add(line[2:idx])
    return bonds


def test_line_collection_uses_full_segment() -> None:
    content = read_text(EFFECTS)
    assert_contains(
        content,
        "local start_projection = 0",
        "直线采样必须覆盖完整线段，避免只命中末端区域",
    )
    if "local start_projection = math.max(0, length - width)" in content:
        raise AssertionError("检测到旧的末端截断采样逻辑，需保持完整线段采样")
    assert_contains(
        content,
        "local fallback_target = (opts and opts.guarantee_target_hit == true) and target or nil",
        "直线模板应默认按几何命中，仅在显式配置时才允许目标兜底",
    )
    assert_contains(
        content,
        "local max_segment_length = math.max(80, pierce_width * 0.75)",
        "直线穿透采样应与线宽联动，避免高速投射物跨段漏判",
    )


def test_dragon_cast_metric_counts_real_cast_only() -> None:
    core = read_text(CORE)
    assert_contains(
        core,
        "local dragon_triggered = trigger_dragon_fireball_effect",
        "龙骑士应先判断是否实际触发",
    )
    assert_contains(
        core,
        "if dragon_triggered then",
        "龙骑士应只在实际触发时上报 cast",
    )


def test_lightning_balance_constants() -> None:
    core = read_text(CORE)
    special = read_text(SPECIAL)
    rules = read_text(ROOT / "data" / "object_tables" / "bond_effect_runtime_rules.lua")

    assert_contains(
        rules,
        "max_targets = 'max'",
        "枪炮师这类割草直线穿透技能应显式保持不封顶",
    )
    assert_contains(
        rules,
        "max_target_count = 5",
        "雷电法王这类点名链技能可以保留目标上限，规则表中需明确声明",
    )

    assert_contains(
        core,
        "local periodic_rule = get_bond_periodic_rule(bond_name)",
        "核心羁绊应通过规则表读取周期参数",
    )
    assert_contains(
        core,
        "rule_number(periodic_rule.interval, 1.20)",
        "雷电法王羁绊应使用规则表中的触发间隔",
    )
    assert_contains(
        special,
        "local lightning_rule = get_card_periodic_rule('引雷咒')",
        "引雷咒卡牌应通过规则表读取参数",
    )
    assert_contains(
        special,
        "rule_number(lightning_rule.interval, 1.20)",
        "引雷咒应使用规则表中的触发间隔",
    )
    assert_contains(
        rules,
        "damage_ratio_default = 0.65",
        "雷电法王默认伤害倍率应为 0.65",
    )
    assert_contains(
        rules,
        "damage_ratio_with_talent = 0.90",
        "雷电法王天赋伤害倍率应为 0.90",
    )


def test_gunner_uses_line_pierce_damage_shape() -> None:
    core = read_text(CORE)
    assert_contains(
        core,
        "hit = bond_damage_target(unit, wave_damage, '物理') or hit",
        "枪炮师应按直线命中的单位逐个结算伤害",
    )
    if "hit = bond_damage_area(target, wave_radius, wave_damage, '物理') or hit" in core:
        raise AssertionError("枪炮师仍在使用目标点圆形伤害，与直线穿透表现不一致")


def test_area_fx_prefers_point_anchor() -> None:
    core = read_text(CORE)
    special = read_text(SPECIAL)
    assert_contains(
        core,
        "if type(center.get_point) == 'function' then",
        "核心羁绊AOE特效应优先使用地面点位锚定，避免单位挂点导致范围错觉",
    )
    assert_contains(
        special,
        "if type(center.get_point) == 'function' then",
        "卡牌AOE特效应优先使用地面点位锚定，避免单位挂点导致范围错觉",
    )


def test_auto_acceptance_uses_active_bonds_and_balance_limits() -> None:
    content = read_text(AUTO_ACCEPTANCE)
    assert_contains(
        content,
        "local activation = runtime.activation_report and runtime.activation_report.activation or nil",
        "自动验收应按当前激活羁绊动态评估",
    )
    assert_contains(
        content,
        "local BOND_DPS_LIMITS = {",
        "自动验收应包含羁绊DPS平衡阈值",
    )
    assert_contains(
        content,
        "['雷电法王'] = { min = 20, max = 1200 }",
        "雷电法王应有明确DPS上限守卫",
    )
    assert_contains(
        content,
        "[auto_acceptance][FAIL][BALANCE]",
        "自动验收应输出平衡失败日志",
    )
    assert_contains(
        content,
        "local clear_ok = clear_active_modifier_bond_effects()",
        "切换单羁绊/全羁绊前应先清空已激活羁绊，避免残留串扰",
    )
    assert_contains(
        content,
        "[auto_acceptance][SKILL_AUDIT_REQUIRED_BONDS]",
        "自动验收应记录本轮实际判定羁绊列表，便于排查误报",
    )


def test_every_visual_bond_has_balance_limit() -> None:
    content = read_text(AUTO_ACCEPTANCE)
    aliases = {
        "寒冰法师": "冰霜法师",
        "战法法师": "战斗法师",
    }
    visual_bonds = parse_visual_bonds()
    missing = []
    for bond_name in sorted(visual_bonds):
        target = aliases.get(bond_name, bond_name)
        if f"['{target}'] = {{ min =" not in content:
            missing.append(f"{bond_name}->{target}" if target != bond_name else bond_name)
    if missing:
        raise AssertionError(f"以下羁绊缺少DPS平衡阈值: {missing}")


if __name__ == "__main__":
    test_line_collection_uses_full_segment()
    test_dragon_cast_metric_counts_real_cast_only()
    test_gunner_uses_line_pierce_damage_shape()
    test_area_fx_prefers_point_anchor()
    test_lightning_balance_constants()
    test_auto_acceptance_uses_active_bonds_and_balance_limits()
    test_every_visual_bond_has_balance_limit()
    print("bond balance guard static ok")
