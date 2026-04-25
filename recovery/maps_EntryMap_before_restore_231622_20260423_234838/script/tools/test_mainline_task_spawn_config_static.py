from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "data_csv" / "mainline_task_rewards.csv"
OBJECT_TABLE_PATH = ROOT / "data" / "object_tables" / "mainline_task_rewards.lua"
BATTLEFIELD_PATH = ROOT / "runtime" / "battlefield.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_mainline_task_csv_declares_explicit_spawn_columns() -> None:
    header = read_text(CSV_PATH).splitlines()[0]
    assert "time_limit" in header
    assert "spawn_unit_id" in header
    assert "spawn_area_id" in header
    assert "is_boss_task" in header


def test_mainline_task_object_table_exports_spawn_fields() -> None:
    content = read_text(OBJECT_TABLE_PATH)
    assert "time_limit = tonumber(row.time_limit) or 60" in content
    assert "spawn_unit_id = to_optional_number(row.spawn_unit_id)" in content
    assert "spawn_area_id = row.spawn_area_id ~= '' and row.spawn_area_id or nil" in content
    assert "is_boss_task = row.is_boss_task == 'true'" in content


def test_battlefield_mainline_spawn_reads_task_config_instead_of_waves() -> None:
    content = read_text(BATTLEFIELD_PATH)
    assert "if not task.spawn_unit_id or not task.spawn_area_id then" in content
    assert "spawn_area_id = task.spawn_area_id" in content
    assert "unit_id = task.spawn_unit_id" in content
    assert "wave.boss_unit_id" not in content[content.find("function api.start_mainline_task_challenge"):content.find("function api.update_wave")]
    assert "wave.main_unit_id" not in content[content.find("function api.start_mainline_task_challenge"):content.find("function api.update_wave")]


if __name__ == "__main__":
    test_mainline_task_csv_declares_explicit_spawn_columns()
    test_mainline_task_object_table_exports_spawn_fields()
    test_battlefield_mainline_spawn_reads_task_config_instead_of_waves()
    print("mainline task spawn config static ok")
