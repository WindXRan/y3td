# 配表分层说明

已按功能拆分到子目录（旧路径保留兼容转发）：

- `data/tables/battle/`：战场与主线任务
- `data/tables/bond/`：羁绊体系
- `data/tables/hero/`：英雄基础与成长
- `data/tables/outgame/`：局外养成与入口
- `data/tables/skill/`：技能与效果
- `data/tables/economy/`：经济与商店

兼容策略：

- 旧文件名路径仍可 `require 'data.tables.xxx'`
- 旧文件现为转发壳：`return require 'data.tables.<folder>.xxx'`

