# entry_objects

这里存放按“物编风格”拆分后的玩法对象定义。

## 目录约定

- `waves/`
  - 单文件一个波次对象，文件名与 `id` 保持一致
- `challenges/`
  - 单文件一个挑战对象，文件名与 `id` 保持一致
- `attack_skills/`
  - 单文件一个攻击技能对象
  - 每个文件导出主定义表，并额外挂 `vfx` 字段
- `treasures/`
  - 单文件一个宝物对象，文件名与 `id` 保持一致
- `marks/`
  - 单文件一个烙印对象，文件名与 `id` 保持一致
- `mark_nodes/`
  - 单文件一个烙印节点对象，文件名与 `id` 保持一致
  - 当前用于 `10/20/30/40` 级触发的烙印轮次

## Loader 约定

- 每个目录的 `init.lua` 只做两件事：
  - 维护稳定的加载顺序
  - 构建 `list` / `by_id` 一类聚合结构
- `mark_nodes/init.lua` 额外构建 `by_level`
- 如果上层逻辑依赖顺序，不要把对象注册改成 `pairs`
- 新增对象时，除了加单文件，还要把模块路径补到对应目录的 `init.lua`

## 命名规则

- 文件名优先使用对象的英文 `id`
- 文件导出对象必须带 `id`
- 文件名、`id`、`by_id` 的 key 保持一致
- 不要在单对象文件里写运行时逻辑，只保留静态定义

## 修改边界

- 调整对象数值、描述、标签：
  - 直接改对应单文件
- 调整烙印节点触发等级、标题、队列优先级：
  - 改 `mark_nodes/*.lua`
- 调整聚合结构或派生索引：
  - 改对应目录的 `init.lua`
- 调整通用构造器：
  - 改 `helpers.lua` 或 `config_helpers.lua`
- 调整脚手架生成：
  - 改 `generate_object_editor_scaffolds.ps1`
- 调整玩法行为：
  - 回到 `entry_runtime.lua`、`entry_runtime_battlefield.lua`、`entry_runtime_attack_skills.lua`、`runtime_bonds.lua` 等运行时模块

## 当前约定的“不继续拆”

以下内容暂时继续留在主配置文件，不强行做成单文件：

- `points`
- `areas`
- `resource_rules`
- `challenge_rules`
- 其他偏全局、偏环境的基础配置

这样可以把“玩法对象”与“地图环境配置”分层，避免文件数量继续膨胀。
