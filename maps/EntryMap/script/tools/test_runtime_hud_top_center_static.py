import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HUD_PATH = ROOT / "script" / "ui" / "runtime_hud.lua"
TOP_PREFAB_PATH = ROOT / "ui" / "prefab" / "top.json"


def walk_paths(node, path=""):
    if not isinstance(node, dict):
        return
    name = node.get("name")
    current = f"{path}.{name}" if path and name else (name or path)
    if current:
        yield current
    for child in node.get("children", []):
        yield from walk_paths(child, current)


def test_top_prefab_keeps_runtime_top_center_nodes():
    prefab = json.loads(TOP_PREFAB_PATH.read_text(encoding="utf-8"))
    paths = set(walk_paths(prefab["data"]))

    for expected in [
        "top.layout_2.金币.image_3.label_2",
        "top.layout_2.木材.image_3.label_2",
        "top.layout_2.杀敌数.image_3.label_2",
        "top.layout_2.bg.boss",
        "top.layout_2.bg.第X波",
        "top.layout_2.bg.游戏时长",
        "top.layout_2.bg.关卡",
        "top.layout_2.bg.BOSS倒计时",
    ]:
        assert expected in paths, f"missing top prefab runtime node: {expected}"


def test_runtime_hud_binds_and_refreshes_top_center_overlay():
    source = HUD_PATH.read_text(encoding="utf-8")

    for token in [
        "local function format_editor_top_wave_time_text(text)",
        "local function format_editor_top_boss_text(name, state)",
        "local function format_editor_top_game_time_text(text)",
        "'top.top.layout_2.金币.image_3.label_2'",
        "'top.top.layout_2.木材.image_3.label_2'",
        "'top.top.layout_2.杀敌数.image_3.label_2'",
        "'top.top.layout_2.bg.第X波'",
        "'top.top.layout_2.bg.关卡'",
        "'top.top.layout_2.bg.游戏时长'",
        "'top.top.layout_2.bg.boss'",
        "'top.top.layout_2.bg.BOSS倒计时'",
        "runtime_hud.editor_top_wave_value = resolve_first_ui(",
        "runtime_hud.editor_top_stage_value = resolve_first_ui(",
        "runtime_hud.editor_top_game_time_value = resolve_first_ui(",
        "runtime_hud.editor_top_boss_value = resolve_first_ui(",
        "runtime_hud.editor_top_boss_countdown_value = resolve_first_ui(",
        "local wave_text = get_wave_title_text()",
        "local stage_text = get_stage_text()",
        "local game_time_text = format_editor_top_game_time_text(format_time(STATE.runtime_elapsed or 0))",
        "local boss_text = format_editor_top_boss_text(boss_display.name, boss_display.state)",
        "local boss_countdown_text = format_editor_top_wave_time_text(boss_display.state)",
        "set_text_if_alive(runtime_hud.editor_top_wave_value, wave_text)",
        "set_text_if_alive(runtime_hud.editor_top_stage_value, stage_text)",
    ]:
        assert token in source, f"missing runtime top-center wiring token: {token}"


if __name__ == "__main__":
    test_top_prefab_keeps_runtime_top_center_nodes()
    test_runtime_hud_binds_and_refreshes_top_center_overlay()
