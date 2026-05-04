from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GM_BOND_EFFECTS = ROOT / "script" / "runtime" / "gm_bond_effects.lua"
BOND_EFFECTS = ROOT / "script" / "runtime" / "bond_modifier_effects.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def assert_contains(content: str, needle: str, label: str) -> None:
    if needle not in content:
        raise AssertionError(f"missing {label}: {needle}")


def test_bond_debug_commands_and_trace_hooks_exist() -> None:
    gm = read_text(GM_BOND_EFFECTS)
    effects = read_text(BOND_EFFECTS)

    assert_contains(gm, "develop_command.register('EGMBONDTRACE'", "gm trace command")
    assert_contains(gm, "develop_command.register('EGMBONDMAP'", "gm map command")
    assert_contains(gm, "STATE.bond_debug_trace_enabled", "trace state toggle")

    assert_contains(effects, "state.bond_debug_trace_enabled == true", "projectile trace hook")
    assert_contains(effects, "[bond_projectile_trace]", "projectile trace message")
    assert_contains(effects, "[bond_audio_trace]", "audio trace message")


if __name__ == "__main__":
    test_bond_debug_commands_and_trace_hooks_exist()
    print("bond debug tools static ok")

