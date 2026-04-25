import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
NODES_CSV = ROOT / "script" / "data_csv" / "bond_nodes.csv"
ROOT_SETS_CSV = ROOT / "script" / "data_csv" / "bond_root_sets.csv"


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def parent_id_of(row: dict[str, str]) -> str | None:
    parent_id = (row.get("parent_id") or "").strip()
    return parent_id or None


def parse_positive_int(raw: str, label: str) -> int:
    try:
        value = int((raw or "").strip())
    except ValueError as exc:
        raise AssertionError(f"{label} should be an integer: {raw!r}") from exc
    if value <= 0:
        raise AssertionError(f"{label} should be > 0: {raw!r}")
    return value


def build_node_index(node_rows: list[dict[str, str]]) -> dict[str, dict[str, str]]:
    by_id: dict[str, dict[str, str]] = {}
    for row in node_rows:
        node_id = (row.get("id") or "").strip()
        if node_id == "":
            raise AssertionError("bond_nodes.csv contains empty id")
        if node_id in by_id:
            raise AssertionError(f"bond_nodes.csv contains duplicate id: {node_id}")
        by_id[node_id] = row
    return by_id


def resolve_root_id(node_id: str, by_id: dict[str, dict[str, str]]) -> str:
    current = by_id[node_id]
    seen = set()
    while True:
        parent_id = parent_id_of(current)
        if parent_id is None:
            return current["id"]
        if parent_id not in by_id:
            raise AssertionError(f"{node_id} points to missing parent_id: {parent_id}")
        if current["id"] in seen:
            raise AssertionError(f"parent chain cycle detected from node: {node_id}")
        seen.add(current["id"])
        current = by_id[parent_id]


def validate_stage_rules(
    node_rows: list[dict[str, str]],
    root_set_rows: list[dict[str, str]],
) -> None:
    by_id = build_node_index(node_rows)
    root_set_by_id = {}
    for row in root_set_rows:
        root_id = (row.get("root_id") or "").strip()
        if root_id == "":
            raise AssertionError("bond_root_sets.csv contains empty root_id")
        if root_id in root_set_by_id:
            raise AssertionError(f"bond_root_sets.csv contains duplicate root_id: {root_id}")
        root_set_by_id[root_id] = row

    root_to_tiers: dict[str, dict[int, list[str]]] = {}
    root_to_group: dict[str, str] = {}
    root_ids_from_nodes = set()

    for row in node_rows:
        node_id = row["id"]
        tier = parse_positive_int(row.get("tier") or "", f"{node_id} tier")
        root_id = resolve_root_id(node_id, by_id)
        root_to_tiers.setdefault(root_id, {}).setdefault(tier, []).append(node_id)

        root_row = by_id[root_id]
        root_ids_from_nodes.add(root_id)
        if parent_id_of(root_row) is not None:
            raise AssertionError(f"root node should not have parent_id: {root_id}")
        if parse_positive_int(root_row.get("tier") or "", f"{root_id} tier") != 1:
            raise AssertionError(f"root node tier should stay at 1: {root_id}")

        root_group = (root_row.get("group_id") or "").strip()
        node_group = (row.get("group_id") or "").strip()
        root_to_group[root_id] = root_group
        if root_group == "" or node_group == "":
            raise AssertionError(f"group_id should not be empty inside root tree: {root_id} / {node_id}")
        if node_group != root_group:
            raise AssertionError(
                f"node should stay inside its root group: root={root_id}, node={node_id}, group={node_group}"
            )

    root_ids_from_sets = set(root_set_by_id.keys())
    if root_ids_from_nodes != root_ids_from_sets:
        missing_in_sets = sorted(root_ids_from_nodes - root_ids_from_sets)
        missing_in_nodes = sorted(root_ids_from_sets - root_ids_from_nodes)
        if missing_in_sets:
            raise AssertionError(f"root nodes missing from bond_root_sets.csv: {', '.join(missing_in_sets)}")
        raise AssertionError(f"bond_root_sets.csv points to missing root nodes: {', '.join(missing_in_nodes)}")

    for root_id, tiers in sorted(root_to_tiers.items()):
        root_set_row = root_set_by_id[root_id]
        required_count = parse_positive_int(
            root_set_row.get("required_count") or "",
            f"{root_id} required_count",
        )
        tier_one_count = len(tiers.get(1, []))
        if tier_one_count != required_count:
            raise AssertionError(
                f"{root_id} tier-1 count should match required_count: {tier_one_count} != {required_count}"
            )

        actual_tiers = sorted(tiers.keys())
        expected_tiers = list(range(1, actual_tiers[-1] + 1))
        if actual_tiers != expected_tiers:
            raise AssertionError(f"{root_id} tiers should stay contiguous from 1: {actual_tiers}")

        for tier in actual_tiers:
            for node_id in tiers[tier]:
                parent_id = parent_id_of(by_id[node_id])
                if parent_id is None:
                    continue
                parent_tier = parse_positive_int(by_id[parent_id]["tier"], f"{parent_id} tier")
                if tier < parent_tier:
                    raise AssertionError(
                        f"{root_id} node {node_id} should not go backwards in tier order: {tier} < {parent_tier}"
                    )


def assert_validation_fails(
    node_rows: list[dict[str, str]],
    root_set_rows: list[dict[str, str]],
    expected_message: str,
) -> None:
    try:
        validate_stage_rules(node_rows, root_set_rows)
    except AssertionError as exc:
        if expected_message not in str(exc):
            raise AssertionError(f"expected '{expected_message}' in '{exc}'") from exc
        return
    raise AssertionError(f"expected validation to fail with: {expected_message}")


def run_self_checks() -> None:
    valid_nodes = [
        {"id": "root", "group_id": "demo", "tier": "1", "parent_id": ""},
        {"id": "base_2", "group_id": "demo", "tier": "1", "parent_id": "root"},
        {"id": "branch", "group_id": "demo", "tier": "2", "parent_id": "base_2"},
        {"id": "deeper", "group_id": "demo", "tier": "3", "parent_id": "branch"},
    ]
    valid_root_sets = [
        {"root_id": "root", "required_count": "2"},
    ]

    validate_stage_rules(valid_nodes, valid_root_sets)

    assert_validation_fails(
        [
            {"id": "root", "group_id": "demo", "tier": "1", "parent_id": ""},
            {"id": "branch", "group_id": "demo", "tier": "2", "parent_id": "root"},
        ],
        valid_root_sets,
        "tier-1 count should match required_count",
    )

    assert_validation_fails(
        [
            {"id": "root", "group_id": "demo", "tier": "1", "parent_id": ""},
            {"id": "base_2", "group_id": "demo", "tier": "1", "parent_id": "root"},
            {"id": "skipped", "group_id": "demo", "tier": "3", "parent_id": "base_2"},
        ],
        valid_root_sets,
        "tiers should stay contiguous from 1",
    )

    assert_validation_fails(
        [
            {"id": "root", "group_id": "demo", "tier": "1", "parent_id": ""},
            {"id": "base_2", "group_id": "demo", "tier": "1", "parent_id": "root"},
            {"id": "tier_2", "group_id": "demo", "tier": "2", "parent_id": "root"},
            {"id": "backward", "group_id": "demo", "tier": "2", "parent_id": "tier_2"},
            {"id": "broken", "group_id": "demo", "tier": "1", "parent_id": "backward"},
        ],
        [{"root_id": "root", "required_count": "3"}],
        "should not go backwards in tier order",
    )


def main() -> None:
    run_self_checks()
    validate_stage_rules(read_csv_rows(NODES_CSV), read_csv_rows(ROOT_SETS_CSV))
    print("bond stage tiers static ok")


if __name__ == "__main__":
    main()
