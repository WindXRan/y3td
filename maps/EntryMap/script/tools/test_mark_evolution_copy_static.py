from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def assert_contains(content: str, needle: str, message: str) -> None:
    assert needle in content, message


def assert_not_contains(content: str, needle: str, message: str) -> None:
    assert needle not in content, message


marks_csv = read("data_csv/marks.csv")
rewards_lua = read("runtime/rewards.lua")
hud_lua = read("ui/runtime_hud.lua")
overview_lua = read("runtime/overview_model.lua")
runtime_overview_lua = read("ui/runtime_overview.lua")
boot_lua = read("runtime/boot.lua")
evolution_nodes_csv = read("data_csv/evolution_nodes.csv")

for evolution_name in [
    "战痕进化",
    "迅节进化",
    "猎王进化",
    "追风进化",
    "奥锋进化",
    "弑王进化",
    "风暴进化",
    "战神进化",
    "虚空进化",
]:
    assert_contains(marks_csv, evolution_name, f"missing evolution name: {evolution_name}")

for old_name in [
    "战痕烙印",
    "迅节烙印",
    "猎王烙印",
    "追风烙印",
    "奥锋烙印",
    "弑王烙印",
    "风暴烙印",
    "战神烙印",
    "虚空烙印",
]:
    assert_not_contains(marks_csv, old_name, f"old mark name still present: {old_name}")

for content in [rewards_lua, hud_lua, overview_lua, runtime_overview_lua, boot_lua, evolution_nodes_csv]:
    assert_not_contains(content, "烙印", "player-facing mark copy should be renamed to evolution")

for phrase in [
    "进化位",
    "进化栏",
    "获得一次英雄真身",
    "已完成进化",
    "真身抉择",
    "真身进化进行中",
    "宝物与进化",
]:
    assert (
        phrase in rewards_lua
        or phrase in hud_lua
        or phrase in overview_lua
        or phrase in runtime_overview_lua
        or phrase in boot_lua
        or phrase in evolution_nodes_csv
    ), f"missing updated phrase: {phrase}"

print("mark evolution copy static ok")
