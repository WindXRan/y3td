from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HUD = ROOT / 'ui' / 'runtime_hud.lua'
NODES = ROOT / 'ui' / 'runtime_hud_nodes.lua'


def require(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise AssertionError(message)


def main() -> None:
    hud = HUD.read_text(encoding='utf-8')
    nodes = NODES.read_text(encoding='utf-8')

    for needle, message in [
        ('bottom_skill_slot_hosts = {', 'expected bottom skill slot host mapping'),
        ("'技能栏.物品2'", 'expected first bottom skill slot path'),
        ("'技能栏.物品2_20'", 'expected last bottom skill slot path'),
        ("runtime_hud.legacy_game_hud_inventory = resolve_ui(y3, player, 'GameHUD.main.inventory')", 'expected legacy inventory binding'),
        ("runtime_hud.legacy_game_hud_skill_list = resolve_ui(y3, player, 'GameHUD.main.skill_list')", 'expected legacy skill list binding'),
        ('local function hide_legacy_bottom_panels(runtime_hud)', 'expected legacy bottom hide helper'),
        ('ensure_bottom_skill_slots(runtime_hud)', 'expected bottom skill slot bootstrap'),
        ("runtime_hud.editor_bottom_bond_slots[slot] = ensure_bottom_slot_entry(runtime_hud, 'bond_' .. tostring(slot), host, slot, 'bond')", 'expected bond slots to use bottom skill hosts'),
        ('slot_ui = runtime_hud.editor_bottom_inventory_anchors[slot]', 'expected equipment binding to prefer bottom inventory anchors'),
        ('local width, height = get_ui_size(slot_host, 66, 66)', 'expected bottom slot icon to size from host'),
        ('icon:set_anchor(0.5, 0.5)', 'expected bottom slot icon to stay centered while filling host'),
        ('render_bottom_bond_slot(runtime_hud.editor_bottom_bond_slots and runtime_hud.editor_bottom_bond_slots[slot] or nil, slot, payload)', 'expected bottom bond slot refresh'),
        ('render_bottom_attack_skill_slot(runtime_hud.skill_slots and runtime_hud.skill_slots[slot] or nil, slot, skill)', 'expected bottom attack skill refresh'),
    ]:
        require(hud + '\n' + nodes, needle, message)

    print('[OK] runtime hud bottom migration static passed')


if __name__ == '__main__':
    main()
