# CSV 功能分组（单一数据源）

`data_csv/by_feature/` 是按功能分组的 CSV 数据源目录：

- `battle/` - 战场相关数据
- `bond/` - 羁绊系统数据
- `hero/` - 英雄相关数据
- `skill/` - 技能系统数据
- `economy/` - 经济系统数据
- `common/` - 通用配置数据

说明：

- **运行时统一从此目录读取**，根目录不再保留冗余副本
- 所有 CSV 文件按功能领域组织，便于策划和开发者维护
- 加载路径统一为 `data_csv/by_feature/{feature}/{table}.csv`
