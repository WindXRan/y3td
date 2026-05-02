# Data Tables 清理记录（2026-05-01）

## 本次完成

- 将 `maps/EntryMap/script/data/tables/` 根目录下的转发壳 Lua（`return require ...`）清理为 0。
- 全仓 Lua 引用统一改为真实分层路径：
  - `data.tables.skill.*`
  - `data.tables.bond.*`
  - `data.tables.economy.*`
  - `data.tables.hero.*`
  - `data.tables.outgame.*`
  - `data.tables.battle.*`
- 保留了真正有逻辑或 CSV 解析职责的 Lua（如 `editor_json_table.lua`、`helpers.lua`、`outgame_detail_config.lua` 等）。

## 规范结论

- `data/tables` 根目录不再新增“兼容转发壳”文件。
- 新表优先落在 `data_csv/`，Lua 只负责最小必要解析与运行时结构转换。
- 业务代码只引用真实路径，不再引用历史短路径别名。

## 校验结果

- Lua 诊断：`0` 问题（`read_problems_lua`）。
- 旧路径关键字回扫：无命中。
