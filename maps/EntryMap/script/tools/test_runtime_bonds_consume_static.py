from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BONDS_CHAIN_PATH = ROOT / "runtime" / "bonds_chain.lua"
CHOICE_PANEL_MODEL_PATH = ROOT / "runtime" / "choice_panel_model.lua"
HUD_V2_PATH = ROOT / "ui" / "runtime_hud_v2.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_bonds_chain_has_root_set_completion_runtime_and_consume_mode() -> None:
    source = read_text(BONDS_CHAIN_PATH)
    for token in [
        "return meta.completion_mode or 'consume_all'",
        "if mode == 'consume_all' then",
        "completed_root_sets = {},",
        "consumed_root_sets = {},",
        "completed_root_set_modes = {},",
        "completed_root_set_attr_bonuses = {},",
        "completed_root_set_runtime_bonuses = {},",
        "local function resolve_root_set_completion(",
        "local function apply_completed_root_set_bonus_pack(",
    ]:
        assert token in source


def test_choice_panel_model_maps_bond_set_title_above_and_node_name_below() -> None:
    source = read_text(CHOICE_PANEL_MODEL_PATH)
    for token in [
        "local top_title_text, progress_text = split_title_progress(choice and choice.title_text or '')",
        "local item_title_text = trim_inline_text((choice and choice.subtitle_text) or '')",
        "title_text = card_labels.item_title_text,",
        "set_title_text = card_labels.top_title_text,",
    ]:
        assert token in source


def test_runtime_hud_v2_uses_completed_root_sets_for_bond_count_instead_of_legacy_swallowed_cards() -> None:
    source = read_text(HUD_V2_PATH)
    assert "return require 'ui.runtime_hud'" in source
    assert "swallowed_cards" not in source


if __name__ == "__main__":
    test_bonds_chain_has_root_set_completion_runtime_and_consume_mode()
    test_choice_panel_model_maps_bond_set_title_above_and_node_name_below()
    test_runtime_hud_v2_uses_completed_root_sets_for_bond_count_instead_of_legacy_swallowed_cards()
