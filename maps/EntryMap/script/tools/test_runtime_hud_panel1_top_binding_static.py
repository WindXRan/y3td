from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HUD_PANEL1_TOP_PATH = ROOT / "script" / "ui" / "runtime_hud_panel1_top.lua"


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def test_runtime_hud_panel1_top_binds_panel1_tophud_nodes():
    content = HUD_PANEL1_TOP_PATH.read_text(encoding="utf-8")

    assert_contains(content, "panel_1.tophud.layout_2.wave", "panel1 top hud should bind wave node")
    assert_contains(content, "panel_1.tophud.layout_2.wavetime", "panel1 top hud should bind wavetime node")
    assert_contains(content, "panel_1.tophud.layout_2.tips", "panel1 top hud should bind tips node")
    assert_contains(content, "panel_1.tophud.layout_2.curlevel", "panel1 top hud should bind curlevel node")
    assert_contains(content, "panel_1.tophud.layout_2.gametime", "panel1 top hud should bind gametime node")
    assert_contains(content, "runtime_hud.wave_title = make_text_proxy(", "panel1 top hud should remap wave title to panel1")
    assert_contains(content, "runtime_hud.stage_text = make_text_proxy(", "panel1 top hud should remap stage text to panel1")
    assert_contains(content, "runtime_hud.timer_text = make_text_proxy(", "panel1 top hud should remap timer text to panel1")
    assert_contains(content, "runtime_hud.boss_name = make_boss_name_proxy(", "panel1 top hud should remap boss name to panel1")
    assert_contains(content, "runtime_hud.boss_state = make_boss_state_proxy(", "panel1 top hud should remap boss state to panel1")


if __name__ == "__main__":
    test_runtime_hud_panel1_top_binds_panel1_tophud_nodes()
