#!/usr/bin/env python
import json
import os
import sys


def simplify(node):
    if not isinstance(node, dict):
        return None
    return {
        "name": node.get("name"),
        "uid": node.get("uid"),
        "type": node.get("type"),
        "children": [
            child_tree
            for child_tree in (simplify(child) for child in node.get("children", []))
            if child_tree is not None
        ],
    }


def main(src_path, dst_path):
    with open(src_path, "r", encoding="utf-8") as src_file:
        data = json.load(src_file)

    tree = simplify(data)
    output_dir = os.path.dirname(dst_path)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    with open(dst_path, "w", encoding="utf-8") as dst_file:
        json.dump(tree, dst_file, ensure_ascii=False, indent=2)
        dst_file.write("\n")

    print(f"[OK] wrote {dst_path}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(
            "Usage: py -3 script/tools/build_gamehud_tree.py ui/GameHUD.json ui_tree/GameHUD_Tree.json"
        )
    main(sys.argv[1], sys.argv[2])
