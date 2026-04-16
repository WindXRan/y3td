from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BATTLEFIELD_PATH = ROOT / "runtime" / "battlefield.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_validate_config_checks_mainline_task_units_and_areas() -> None:
    content = read_text(BATTLEFIELD_PATH)
    validate_block = content[content.find("function api.validate_config()"):content.find("function api.get_active_challenge_count()")]

    assert "for _, task in ipairs(CONFIG.mainline_task_rewards and CONFIG.mainline_task_rewards.list or {}) do" in validate_block
    assert "check_unit('mainline_task[' .. tostring(task.id) .. '].spawn_unit_id', task.spawn_unit_id)" in validate_block
    assert "missing[#missing + 1] = string.format('mainline_task[%s].spawn_area_id: %s', tostring(task.id), tostring(task.spawn_area_id))" in validate_block


if __name__ == "__main__":
    test_validate_config_checks_mainline_task_units_and_areas()
    print("mainline task validate config static ok")
