import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FOLDERINFO = ROOT.parent / "editor" / "folderinfo" / "folderinfo_editor_item.json"

ROOT_FOLDER_UID = "entry_runtime_item_root"
TREASURE_ITEM_IDS = [201390200 + index for index in range(1, 23)]


def test_runtime_treasure_items_grouped_in_single_root_folder() -> None:
    data = json.loads(FOLDERINFO.read_text(encoding="utf-8"))
    folders = {
        tuple_entry["items"][2]: tuple_entry["items"]
        for tuple_entry in data["f"]
        if isinstance(tuple_entry, dict) and tuple_entry.get("__tuple__") is True
    }

    root_folder = folders.get(ROOT_FOLDER_UID)
    assert root_folder is not None
    assert root_folder[3] == "EntryRuntime道具"
    assert root_folder[0] == "/2147483647"

    managed_uids = [
        folder_uid
        for folder_uid in folders
        if isinstance(folder_uid, str) and folder_uid.startswith("entry_runtime_item_")
    ]
    assert managed_uids == [ROOT_FOLDER_UID]

    for order, item_id in enumerate(TREASURE_ITEM_IDS):
        mapping = data["d"].get(str(item_id))
        assert mapping is not None
        assert mapping["items"][0] == ROOT_FOLDER_UID
        assert mapping["items"][1] == order
