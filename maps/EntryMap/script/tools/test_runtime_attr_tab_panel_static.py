from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BOOT_PATH = ROOT / "script" / "runtime" / "boot.lua"
HUD_PATH = ROOT / "script" / "ui" / "runtime_hud_panel1_top.lua"
PANEL_LUA_PATH = ROOT / "script" / "ui" / "runtime_attr_tab_panel.lua"
PANEL_JSON_PATH = ROOT / "ui" / "RuntimeAttrTabPanel.json"
PANEL_TREE_PATH = ROOT.parents[1] / "ui_tree" / "RuntimeAttrTabPanel_Tree.json"


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def test_runtime_attr_tab_panel_wired():
    boot = BOOT_PATH.read_text(encoding="utf-8")
    hud = HUD_PATH.read_text(encoding="utf-8")
    panel_lua = PANEL_LUA_PATH.read_text(encoding="utf-8")
    panel_json = PANEL_JSON_PATH.read_text(encoding="utf-8")
    panel_tree = PANEL_TREE_PATH.read_text(encoding="utf-8")

    assert_contains(hud, "require 'ui.runtime_attr_tab_panel'", "runtime_hud_panel1_top.lua should load the attr tab panel controller")
    assert_contains(hud, "toggle_attr_panel", "runtime_hud_panel1_top.lua should expose a tab-panel toggle entry")
    assert_contains(hud, "refresh_attr_panel", "runtime_hud_panel1_top.lua should refresh the attr tab panel during hud updates")

    assert_contains(boot, "runtime_hud_system.toggle_attr_panel()", "boot.lua should route TAB attr dialog toggles to the runtime attr tab panel")
    assert_contains(boot, "get_runtime_overview_model = function()", "boot.lua should pass the overview model provider into the runtime hud system")

    assert_contains(panel_lua, "RuntimeAttrTabPanel", "runtime_attr_tab_panel.lua should target the new editor ui root")
    assert_contains(panel_lua, "'progress'", "runtime_attr_tab_panel.lua should bind all attr tabs")

    assert_contains(panel_json, '"name": "RuntimeAttrTabPanel"', "RuntimeAttrTabPanel.json should define the new editor ui panel")
    assert_contains(panel_json, '"visible": false', "RuntimeAttrTabPanel.json should start hidden")

    assert_contains(panel_tree, '"name": "tab_summary"', "RuntimeAttrTabPanel tree should include the summary tab")
    assert_contains(panel_tree, '"name": "tab_progress"', "RuntimeAttrTabPanel tree should include the progress tab")
    assert_contains(panel_tree, '"name": "row_8"', "RuntimeAttrTabPanel tree should expose all content rows")


if __name__ == "__main__":
    test_runtime_attr_tab_panel_wired()
