# Codex Script Root

本目录是当前玩法代码根目录。Codex 在 `maps/EntryMap/script` 或其子目录工作时，必须以本目录下的代码和文档为准。

## 基本规则

- 始终使用中文回复用户。
- 以本目录下的实现为准，不以设计稿、旧入口或占位文件为准。
- 功能实现状态先看 `runtime/` 目录下的实际 Lua 代码和 `data/tables/` 配置。
- **代码风格规范**：新增业务代码必须遵循 [CODE_STYLE.md](CODE_STYLE.md) 中的 y3 仓库风格。
- **优先使用官方 API**：如果 Y3 API 和 y3maker 已有实现的功能，不要自己重复实现。
- 详细项目说明继续读 `CLAUDE.md`。

## 错误处理原则（重要）

**禁止随意编写回退兜底代码。** 所有预期外的失败情况必须主动抛出错误，而不是静默返回默认值或空值。

### 具体要求

1. **不要写隐藏错误的兜底逻辑** - 当代码走到意料之外的分支时，应该报错而不是返回 nil、空字符串或 false 让程序继续运行
2. **所有 fallback 都要改成报错** - 任何为了"防止报错"而写的兜底代码（如 `if not xxx then return nil end` 或 `local result = xxx or default_value`）都应改为 `error("具体错误信息")`
3. **优先暴露问题而不是掩盖问题** - 让开发者尽早发现问题，比让 bug 在远离根源的地方爆发要好得多
4. **例外情况** - 只有明确业务逻辑允许的默认值（如配置未填写时使用配置中的默认值）才可以使用回退

## 真实入口

- 启动入口：`main.lua`
- 运行时总协调：`runtime/boot.lua`
- 配置汇总：`config/entry_config.lua`
- 运行时模块：`runtime/`
- UI 交互代码：`ui/`

## 不要误判

- `y3/演示/项目配置/可重载的代码.lua` 是热重载示例，不是主入口。
- `../ui` 和 `../ui_tree` 是 UI 资源目录，不是玩法运行时主逻辑。
- `y3/` 是框架目录，除非明确修框架，否则不要改。
- `.y3maker/knowledge/` 是知识库文档，不代表已经实现。

## 修改优先级

1. 先判断需求属于配置、战场、成长、攻击技能、羁绊、HUD、调试中的哪一层。
2. 优先复用已有模块，不要把已拆分的逻辑回退成单文件堆积。
3. 写 Lua 前必须先确认 y3 API 存在，优先查 `.codex/skills/y3-lua-pipeline/references/` 和 `y3/` 源码。
4. UI 需求优先走项目 UI 生成流程，避免手写大型 UI JSON。
5. 修改风险高或用户明确要求时，再补最小必要测试。

## 继续阅读

建议顺序：

1. `CLAUDE.md`
2. `CODE_STYLE.md` - **代码风格规范（必须阅读）**，规定新增代码必须使用 y3 仓库风格（Class 系统 + TypeDoc 注解）
3. `runtime/boot.lua` - 启动入口逻辑
4. `config/entry_config.lua` - 配置汇总
5. `.y3maker/knowledge/项目结构说明.md` - 项目结构说明
6. `data/tables/README.md` - 数据表说明

## 当前状态说明

- 奖励系统在 `runtime/rewards.lua` 中实现，包含英雄进阶功能。

## 辅助技能体系

项目在 `.y3maker/skills/` 下提供了完整的辅助技能体系，开发时可主动调用：

### 开发工具
- **y3-lua-pipeline** - Lua 开发管道，包含 API 参考文档和代码生成
- **y3-lua-review** - Lua 代码审查工具
- **y3-env-setup** - 开发环境设置

### UI 开发
- **y3-ui-pipeline** - UI 开发管道，自动生成 UI 树结构
- **y3-ui-generator** - UI 组件生成器，支持 HTML 转 Y3 UI 格式

### 对象编辑
- **y3-obj-edit** - 对象编辑器，支持单位属性修改
- **y3-obj-gen** - 对象生成器，基于模板批量创建游戏对象

### 测试与规范
- **y3-auto-test** - 自动化测试框架
- **y3-game-spec** - 游戏规格设计文档生成

### 知识库
- `.y3maker/knowledge/` - Y3 引擎知识文档（UI系统、核心系统、物编系统）
- `.y3maker/memory/` - 项目记忆系统，记录历史开发会话和问题

### 使用建议
- 写 Lua 代码前建议查阅 `y3-lua-pipeline/references/` 中的 API 文档
- UI 开发优先使用 `y3-ui-generator` 生成组件
- 代码提交前使用 `y3-lua-review` 进行代码审查

---

## boot.lua 函数清单

boot.lua 是运行时总协调入口，分为 10 个阶段按序初始化。以下是每个函数的签名、职责和导出方式。

### 阶段0：模块级初始化（加载时立即执行）

| 函数/变量 | 位置 | 职责 | 导出 |
|-----------|------|------|------|
| `ensure_helper_signals()` | 53 | 调试模式下发心跳和就绪信号 | `_G.ensure_helper_signals` |
| `install_projectile_override_hook()` | 99 | 劫持 `y3.projectile.create`，支持强制指定投射物 key 用于调试 | 内部调用 |
| `BootCore.create({AttackSkillObjects})` | 74 | 创建核心状态工厂，产出 ATTACK_SKILL_DEFS、SkillRuntime 等 | 解构为局部变量 |
| `ProjectileNameGuard.validate({y3}, {id})` | 130 | 校验已知投射物 ID 在引擎中有效 | 仅初始化时执行 |

### 阶段1：核心状态初始化

| 函数/变量 | 位置 | 职责 | 导出 |
|-----------|------|------|------|
| `boot_core.create_initial_state()` | 86 | 创建全局 STATE 表 | `_G.STATE` |
| `buff_system` require | 97 | 加载 Buff 系统 | `_G.buff_system_tick`（仅 tick 方法） |

### 阶段2：基础能力

| 函数 | 位置 | 职责 | 导出 |
|------|------|------|------|
| `get_player()` | 136 | 通过 BootHelpers 获取当前玩家对象 | `_G.get_player` |
| `get_enemy_player()` | 140 | 获取敌方玩家对象 | `_G.get_enemy_player` |

### 阶段3：RuntimeEntry API

| 函数 | 位置 | 职责 | 导出 |
|------|------|------|------|
| `RuntimeEntry.has_valid_hero()` | 149 | 检查 STATE.hero 是否存在且存活 | 返回给 entry_runtime |
| `RuntimeEntry.apply_fixed_camera_mode(enabled)` | 153 | TPS 跟随/释放相机，设置视角距离、禁用鼠标滚轮等 | 返回给 entry_runtime |
| `RuntimeEntry.sync_fixed_camera_mode()` | 211 | 按 STATE.fixed_camera_enabled 同步相机模式 | 返回给 entry_runtime |
| `RuntimeEntry.toggle_fixed_camera()` | 215 | 切换固定/自由视角，F12 快捷键 | 返回给 entry_runtime |
| `set_ui_root_visible(path, visible)` | 229 | 通过 pcall 安全设置 UI 控件的 `set_visible` | 内部 |
| `enforce_runtime_ui_phase(is_battle)` | 245 | 根据战斗/非战斗阶段隐藏对应 UI 组 | `_G.enforce_runtime_ui_phase` |

### 阶段4：英雄属性系统

| 函数 | 位置 | 职责 | 导出 |
|------|------|------|------|
| `sync_gear_runtime_effects(state, hero, config)` | 293 | 调用 GearUpgrades 同步装备词条运行时加成 | 内部 |
| `HeroAttrSystem.set_main_stat_attack_ratio(ratio)` | 304 | 根据配置设置主属性攻击加成系数 | 在模块表上调用 |
| `hero_model` require | 309 | 加载英雄模型系统 | `_G.hero_model` |
| `get_area(area_id)` | 316 | 按 ID 获取区域配置（优先取 debug 区域） | 内部 |
| `random_point_in_area(area_id)` | 326 | 在指定区域内随机选点 | `_G.random_point_in_area` |
| `set_attr_pack(unit, attr_pack)` | 337 | 批量设置单位属性（覆盖） | `_G.set_attr_pack` |
| `add_attr_pack(unit, attr_pack)` | 349 | 批量增加单位属性（累加） | `_G.add_attr_pack` |
| `snapshot_hero_attrs()` | 361 | 快照英雄当前属性 | 内部（事件回调） |
| `build_runtime_attr_dialog_chunks()` | 368 | 构建属性对话框文本片段 | 内部 |
| `show_runtime_attr_dialog()` | 376 | 切换属性面板显示，回退到文本消息 | `_G.show_runtime_attr_dialog` |
| `create_bond_env()` | 401 | 构造羁绊系统所需的依赖环境表（STATE, message, y3 等） | 内部 |
| `update_bond_effects(dt)` | 425 | 每帧更新羁绊效果 | `_G.update_bond_effects` |
| `get_bond_runtime_bonus(key)` | 432 | 获取羁绊+进化累计的运行时加成 | `_G.get_bond_runtime_bonus` |
| `is_active_enemy(unit)` | 451 | 通过 battlefield_system 判断单位是否为活跃敌人 | `_G.is_active_enemy` |
| `message(text)` | 474 | 战斗中推送 BattleEvent，局外调用 display_message | `_G.message` |
| `heal_hero(amount)` | 514 | 恢复英雄生命值，显示治疗消息 | `_G.heal_hero` |

### 阶段5：核心玩法系统

| 函数 | 位置 | 职责 | 导出 |
|------|------|------|------|
| `progression_system` require | 669 | 加载升级系统 | `_G.progression_system` |
| `get_current_wave()` | 531 | 获取当前波次信息 | 内部 |
| `get_boss_name(wave)` | 536 | 获取当前波次的 Boss 名称 | 内部 |
| `show_runtime_status()` | 541 | 打印完整运行时状态（波次/Boss/资源/挑战/奖励队列） | `_G.show_runtime_status` |
| `set_battle_hud_visible(visible)` | 603 | 控制战斗 HUD 显隐 | `_G.set_battle_hud_visible` |
| `handle_battle_finished(result)` | 615 | 战斗结束处理：清理单位、隐藏 HUD、转局外、显示结算面板 | `_G`（通过 EventBus） |
| `sync_basic_attack_ability()` | 659 | 同步基础攻击技能到引擎 | `_G` |
| `reward_system` require | 675 | 加载奖励系统 | `_G.reward_system` |
| `audio_system` require | 680 | 加载音频系统 | `_G.audio_system` |
| `debug_message(text)` | 685 | 分发调试消息到 debug_tools_system | `_G.debug_message` |
| `show_debug_hotkey_help()` | 691 | 显示调试快捷键帮助 | `_G.show_debug_hotkey_help` |
| `get_enemy_runtime_info(unit)` | 698 | 获取敌人的运行时信息表 | `_G` |
| `is_boss_runtime_enemy(info)` | 703 | 判断运行时信息是否为 Boss | `_G` |
| `is_elite_runtime_enemy(info)` | 708 | 判断运行时信息是否为精英 | `_G` |

### 阶段6：回合选择系统

| 函数 | 位置 | 职责 | 导出 |
|------|------|------|------|
| `get_pending_round_choice_kind()` | 714 | 按优先级检测当前待选择的类型（gear/attr/bond/evolution） | `_G.get_pending_round_choice_kind` |
| `get_pending_round_choice_label(kind)` | 735 | 返回选择类型的中文显示名 | 内部 |
| `show_pending_round_choice(kind)` | 751 | 展示对应类型的 UI 选择面板 | 内部 |
| `ensure_round_choice_available(allowed_kind)` | 771 | 检查是否可以操作该类型，不可用时提示并展示 | `_G.ensure_round_choice_available` |
| `apply_bond_choice(index)` | 783 | 应用羁绊选择结果，处理替换流程 | 内部 |
| `apply_round_choice(index)` | 796 | 按类型分发选择结果到对应系统 | `_G.apply_round_choice` |
| `try_bond_draw()` | 839 | 尝试 F 羁绊抽卡，检查木材和冲突 | `_G.try_bond_draw` |
| `try_start_challenge(challenge_id)` | 855 | 启动挑战模式 | `_G.try_start_challenge` |
| `use_attr_diamond()` | 865 | 使用属性钻石刷新四选一 | `_G.use_attr_diamond` |
| `show_attack_skill_loadout()` | 879 | 展示攻击技能装配面板 | `_G.show_attack_skill_loadout` |
| `unlock_attack_skill(skill_id)` | 885 | 解锁攻击技能，应用进化加成 | `_G.unlock_attack_skill` |
| `has_bond_route_tag(tag)` | 911 | 查询当前羁绊路线是否包含某 tag | `_G.has_bond_route_tag` |
| `is_debug_effect_mounted(effect_id)` | 916 | 检查调试特效是否已挂载 | `_G.is_debug_effect_mounted` |
| `notify_bond_attack_skill_cast(skill, target)` | 924 | 通知羁绊系统技能已施放 | `_G.notify_bond_attack_skill_cast` |
| `notify_auto_active_basic_attack(target)` | 929 | 通知自动激活系统普攻已施放 | `_G.notify_auto_active_basic_attack` |
| `notify_auto_active_skill_cast(skill, target)` | 937 | 通知自动激活系统技能已施放 | `_G.notify_auto_active_skill_cast` |

### 阶段6b：音频事件转发

| 函数 | 位置 | 职责 | 导出 |
|------|------|------|------|
| `play_basic_attack_sound(source_unit)` | 945 | 调用 audio_system 播放普攻音效 | `_G.play_basic_attack_sound` |
| `play_attack_skill_sound(skill, source_anchor, stage)` | 950 | 调用 audio_system 播放技能音效 | `_G.play_attack_skill_sound` |
| `play_ui_click()` | 956 | 调用 audio_system 播放 UI 点击音效 | `_G.play_ui_click` |
| `play_enemy_death_sound(unit, info, death_point)` | 1019 | 播放敌人死亡音效（按 Boss/普通分流） | `_G.play_enemy_death_sound` |

### 阶段6c：EventBus 事件订阅

| 事件 | 处理逻辑 | 触发时机 |
|------|----------|----------|
| `wave_started` | audio.handle_wave_started → reward.handle_wave_started | 波次开始 |
| `boss_spawned` | audio.handle_boss_spawned → reward.handle_boss_spawned | Boss 登场 |
| `boss_warning` | audio.handle_boss_warning | Boss 倒计时警告 |
| `challenge_started` | audio.handle_challenge_started → reward.handle_challenge_started | 挑战开始 |
| `challenge_finished` | audio.handle_challenge_finished → reward.handle_challenge_finished | 挑战结束 |
| `hero_be_hurt` | audio.handle_hero_be_hurt → reward.handle_hero_be_hurt | 英雄受伤 |
| `hero_damage` | trigger_td_skills_on_hit | 英雄造成伤害 |
| `formula_damage_override` | BootCombat.apply_formula_damage_override | 公式伤害覆写 |
| `hero_before_hurt` | handle_bond_hero_pre_hurt | 英雄受伤前（羁绊减伤） |
| `hero_attr_changed` | snapshot_hero_attrs | 英雄属性变更 |
| `finish_game` | handle_battle_finished | 游戏结束 |

### 阶段7：UI 系统

### 阶段7：技能系统

| 模块 | 导出 | 职责 |
|------|------|------|
| `skill_damage_templates` | `_G.td_damage_api` | 伤害模板（公式计算） |
| `skill_framework` | `_G.skill_framework_system` | 技能框架（循环/冷却/目标选择） |
| `sample_skills` | `_G.sample_skills_system` (+ 别名 `_G.sample_skill_system`) | 样本技能定义 |
| `generated_skills` | `_G.generated_skills_api` | 生成技能（批量注册） |
| `attack_skills` | `_G.attack_skills_system` | 攻击技能运行时 |

| 函数 | 位置 | 职责 | 导出 |
|------|------|------|------|
| `create_offset_point(_, base_point, angle, distance, z)` | 1079 | 从基准点按角度+距离计算偏移点，支持回退 | `_G.create_offset_point` |
| `register_all()` | 1096 | 批量注册生成技能，将 visual 配置同步到 AttackSkillObjects.vfx_by_id | 模块内部调用 |

| 模块 | 位置 | 导出 | 职责 |
|------|------|------|------|
| `battlefield` | 1125 | `_G.battlefield_system` | 战场系统（波次/敌人生成） |

### 阶段8：UI 系统

| 模块/函数 | 位置 | 导出 | 职责 |
|-----------|------|------|------|
| `runtime_hud` | 1135 | `_G.hud_system`（保留 `_G.runtime_hud_system` 别名） | HUD 主面板 |
| `attr_tips_panel` | 1139 | `STATE.attr_tips_panel` | 属性提示面板 |
| `runtime_ui_helpers` | 1144 | `_G.runtime_ui_helpers` | UI 辅助（被 BootUIEnhancements 补丁覆盖 refresh_choice_panel） |
| `result_panel` | 1152 | `_G.result_panel` | 战斗结算面板 |

### 阶段9：调试系统

| 模块/对象 | 位置 | 导出 | 职责 |
|-----------|------|------|------|
| `debug_actions` | 1156 | `_G.debug_actions_system` | 调试动作 |
| `debug_tools` | 1158 | `_G.debug_tools_system` | 调试工具 |
| `gm_bond_effects` | 1160 | `_G.gm_bond_effects`（保留 `_G.gm_bond_effects_system` 别名） | GM 羁绊效果面板（存根） |
| `battle_auto_acceptance` | 1166 | `_G.battle_auto_acceptance_system` | 战斗自动接受 |

### 阶段10：Session/Runtime 设置

| 属性 | 源模块 | 导出/用途 |
|------|--------|-----------|
| `RuntimeEntry._session_bundle` | `boot_session_setup` | session 级别状态管理 |
| `RuntimeEntry._runtime_bundle` | `boot_runtime_setup` | 运行时事件注册和循环 |
| `RuntimeEntry.register_runtime_events` | 委托到 `_runtime_bundle` | 注册运行时事件 |
| `RuntimeEntry.start_runtime_loops` | 委托到 `_runtime_bundle` | 启动运行时主循环 |
| `RuntimeEntry.run_bootstrap_sequence` | 委托到 `_runtime_bundle` | 运行启动序列 |
| `RuntimeEntry.bootstrap()` | 1184 | 启动入口（调用 run_bootstrap_sequence） |
| `_G.RuntimeEntry` | 模块返回值 | 返回给 entry_runtime.lua |
| `_G.reset_session_state` | 从 `_session_bundle` 提取 | 重置 Session 状态 |

