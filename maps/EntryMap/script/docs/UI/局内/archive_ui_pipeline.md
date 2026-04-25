# 存档 UI 生成流程

存档 UI 必须使用标准 `y3-ui-pipeline` 流程生成：

1. 使用 `y3-ui-generator` 生成或更新 `maps/EntryMap/ui/*.json`。
2. 运行 `gen_ui_tree.py <map_root_path>` 生成 `maps/EntryMap/ui_tree/*_Tree.json`。
3. Lua 只绑定节点树中确认存在的路径，不再通过自定义 Python builder 生成存档 UI。

不要再新增常驻守护脚本或镜像目录同步脚本来回写 UI 文件；如果编辑器保存导致 UI 回退，应重新按 pipeline 生成。
