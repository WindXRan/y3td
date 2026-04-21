from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PANEL = ROOT / "script" / "ui" / "choice_panel.lua"
LOOPS = ROOT / "script" / "runtime" / "loops.lua"


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def main() -> None:
    panel = PANEL.read_text(encoding="utf-8")
    loops = LOOPS.read_text(encoding="utf-8")

    assert_contains(
        panel,
        "local function is_choice_panel_active(model)",
        "choice panel should centralize whether the panel is actually active",
    )
    assert_contains(
        panel,
        "if not is_choice_panel_active(model) then",
        "choice panel should bail out when no active choice content exists",
    )
    assert_contains(
        panel,
        "local function debug_refresh_panel_lifecycle(message)",
        "choice panel should dedupe repeated refresh lifecycle logs",
    )

    refresh_start = panel.index("  refresh_panel = function()")
    hidden_idx = panel.index("    if not visible then", refresh_start)
    recreate_idx = panel.index("    if panel.renderer_signature ~= renderer_signature then", refresh_start)
    if hidden_idx > recreate_idx:
        raise AssertionError("choice panel should hide first and only recreate while visible")

    ensure_start = panel.index("    ensure_panel = function()")
    alive_guard_idx = panel.index("      if is_panel_alive(panel) then", ensure_start)
    active_guard_idx = panel.index("      if not is_choice_panel_active(model) then", ensure_start)
    ensure_create_idx = panel.index("      return create_choice_panel()", ensure_start)
    if not (alive_guard_idx < active_guard_idx < ensure_create_idx):
        raise AssertionError("choice panel ensure_panel should short-circuit before creating a panel")

    if "ensure_choice_panel()" in loops:
        raise AssertionError("battle ui loop should not poll ensure_choice_panel every refresh tick")

    print("choice panel lifecycle static ok")


if __name__ == "__main__":
    main()
