from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MONSTER_OBJECT_TABLE_PATH = ROOT / "data" / "object_tables" / "monster_maintask.lua"
OBJECT_TABLE_PATH = ROOT / "data" / "object_tables" / "mainline_task_rewards.lua"
BATTLEFIELD_PATH = ROOT / "runtime" / "battlefield.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_monster_maintask_object_table_exports_spawn_fields() -> None:
    content = read_text(MONSTER_OBJECT_TABLE_PATH)
    assert "EditorJsonTable.read_rows('monster_maintask')" in content
    assert "spawn_unit_id = spawn_unit_id" in content
    assert "target_count = target_count" in content
    assert "attr_overrides = next(attr_overrides) and attr_overrides or nil" in content


def test_mainline_task_object_table_uses_monster_maintask_spawn_fields() -> None:
    content = read_text(OBJECT_TABLE_PATH)
    assert "local MonsterMaintask = require 'data.object_tables.monster_maintask'" in content
    assert "local source_rows = #MonsterMaintask.list > 0 and MonsterMaintask.list or rows" in content
    assert "local monster_row = source_row.source == 'monster_maintask' and source_row or MonsterMaintask.by_id[source_row.id]" in content
    assert "time_limit = tonumber(row.time_limit) or 60" in content
    assert "spawn_unit_id = monster_row and monster_row.spawn_unit_id or to_optional_number(row.spawn_unit_id)" in content
    assert "spawn_area_id = row.spawn_area_id ~= '' and row.spawn_area_id or nil" in content
    assert "attr_overrides = monster_row and monster_row.attr_overrides or nil" in content


def test_battlefield_mainline_spawn_reads_task_config_instead_of_waves() -> None:
    content = read_text(BATTLEFIELD_PATH)
    assert "if not task.spawn_unit_id or not task.spawn_area_id then" in content
    assert "spawn_area_id = task.spawn_area_id" in content
    assert "unit_id = task.spawn_unit_id" in content
    assert "attr_overrides = task.attr_overrides" in content
    assert "attr_overrides = instance.def.attr_overrides" in content
    assert "wave.boss_unit_id" not in content[content.find("function api.start_mainline_task_challenge"):content.find("function api.update_wave")]
    assert "wave.main_unit_id" not in content[content.find("function api.start_mainline_task_challenge"):content.find("function api.update_wave")]


if __name__ == "__main__":
    test_monster_maintask_object_table_exports_spawn_fields()
    test_mainline_task_object_table_uses_monster_maintask_spawn_fields()
    test_battlefield_mainline_spawn_reads_task_config_instead_of_waves()
    print("mainline task spawn config static ok")
