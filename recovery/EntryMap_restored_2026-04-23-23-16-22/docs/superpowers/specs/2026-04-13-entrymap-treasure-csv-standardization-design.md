# EntryMap 宝物 CSV 标准化设计

## 目标

将当前临时整理的宝物 `csv` 升级为一套更适合程序接入、同时仍方便策划维护的标准化结构。

## 设计结论

采用“主表可读、效果拆子表”的折中方案：

- `treasures.csv`
  - 保存宝物基础信息与摘要文案
- `treasure_effects.csv`
  - 保存单件宝物效果，一行一个效果
- `treasure_sets.csv`
  - 保存套装基础信息
- `treasure_set_members.csv`
  - 保存套装成员映射
- `treasure_set_effects.csv`
  - 保存套装激活效果

## 字段约定

### treasures.csv

- `id`
- `name`
- `category`
- `rarity`
- `is_set_item`
- `set_id`
- `summary`
- `notes`

### treasure_effects.csv

- `treasure_id`
- `effect_type`
- `effect_key`
- `op`
- `value`
- `scope`
- `condition`
- `notes`

### treasure_sets.csv

- `set_id`
- `set_name`
- `piece_count`
- `bonus_desc`
- `notes`

### treasure_set_members.csv

- `set_id`
- `treasure_id`
- `member_order`

### treasure_set_effects.csv

- `set_id`
- `effect_type`
- `effect_key`
- `op`
- `value`
- `condition`
- `notes`

## 处理原则

- 保留中文摘要，方便策划直接阅读。
- 程序应优先读取 `effects` 子表中的原子化字段，不从 `summary` 反解析。
- `我全都要`、`暂时隐藏`、`放弃`、`刷新(1)` 不属于永久宝物，不进入配置表。
- `ITEM_022` 当前单件效果未确认，允许在主表和效果表中保留待补充标记，但套装效果正常入表。
