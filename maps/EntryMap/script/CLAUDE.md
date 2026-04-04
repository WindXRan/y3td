# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此代码库中工作时提供指导。

## 语言要求

**始终使用中文回复用户。**

## 项目概述

这是一个使用 **y3-lualib** 框架（版本 250804）的 Y3 编辑器 Lua 游戏地图项目。Y3 是一个类似魔兽争霸3世界编辑器的游戏编辑器，多人同步机制为帧同步，此框架为纯 Lua 开发提供接口绑定。

**重要提示**：Lua 虚拟机版本为 5.4，有以下定制：
- 实数使用定点数（非浮点数）以保证跨平台一致性
- `math.random` 使用引擎提供的实现以保证玩家间同步
- `os.clock` 返回逻辑游戏时间
- 许多 `debug`、`io` 和 `os` 函数在生产环境（平台模式）中被禁用

## 常用命令

### 运行和调试
- **启动游戏并附加调试器**：在安装了 `sumneko.y3-helper` 扩展的 VSCode 中，按 `Shift+F5` 或点击 Y3 侧边栏的"启动游戏并附加调试器"
- **游戏内快速重启**：在游戏聊天中输入 `.rr`，快速重启游戏

### 作弊指令（仅开发模式有效）
在游戏聊天中输入以 `.` 开头的指令：
- `.rd` - 重载脚本（热重载）
- 可通过 `y3.develop.command.register()` 注册自定义指令

### 日志
```lua
log.info('消息')    -- 信息级别
log.debug('消息')   -- 调试级别
log.error('消息')   -- 错误级别
print('消息')       -- 快速调试（显示在游戏中，上传前记得删除）
```
日志在开发模式下写入 `.log/lua_player01.log`（文件名中的数字为玩家编号）。
s
## 架构

### 入口文件
- `main.lua` - 游戏入口，启动时执行。在此配置日志。
- `可重载的代码.lua` - 可热重载的代码。对需要支持热重载的文件使用 `include 'module'`（而非 `require`）。

### y3 全局对象
`y3` 全局对象提供所有框架 API。主要命名空间：

| 命名空间 | 用途 |
|----------|------|
| `y3.game` | 核心游戏 API、事件、调试模式检查 |
| `y3.unit`、`y3.item`、`y3.ability`、`y3.buff` | 游戏对象类型（可编辑对象） |
| `y3.player`、`y3.timer`、`y3.selector` | 运行时对象 |
| `y3.point`、`y3.area`、`y3.camera`、`y3.ui` | 场景对象 |
| `y3.config` | 运行时配置（日志、同步等） |
| `y3.reload` | 热重载系统 |
| `y3.class` | 面向对象类系统 |

### 类系统
全局类辅助函数：
```lua
Class   = y3.class.declare   -- 声明类
New     = y3.class.new       -- 创建实例
Extends = y3.class.extends   -- 继承
Delete  = y3.class.delete    -- 销毁实例
IsValid = y3.class.isValid   -- 检查有效性
```

### 事件系统
在游戏对象上注册事件：
```lua
y3.game:event('游戏-初始化', function(trg, data)
    -- 游戏初始化
end)

y3.game:event('键盘-按下', 'R', function()
    -- R 键被按下
end)
```

### 模块加载
- `require 'module'` - 标准 require，不可热重载
- `include 'module'` - 可重载的 require，用于需要支持热重载的游戏逻辑

### 目录结构（y3/）
```
y3/
├── game/       # 核心游戏 API（game.lua、config.lua、const.lua）
├── object/
│   ├── editable_object/   # 单位、物品、技能、Buff 等
│   ├── runtime_object/    # 玩家、计时器、选择器等
│   └── scene_object/      # 点、区域、镜头、UI 等
├── tools/      # 工具类（class、json、reload、proxy 等）
├── util/       # 框架工具（event、trigger、sync 等）
├── develop/    # 开发工具（command、console、helper）
├── doc/        # API 文档
└── 演示/       # 演示代码示例
```

## 配置

### 日志配置（在 main.lua 中）
```lua
y3.config.log.toGame = true/false   -- 是否在游戏窗口显示日志
y3.config.log.level = 'debug'/'info'/'error'
y3.config.log.toFile = true/false   -- 是否写入日志文件
```

### 调试模式检查
```lua
if y3.game.is_debug_mode() then
    -- 开发环境
end
```

## 游戏对象 API

### 单位 (Unit)
```lua
-- 创建/获取
local unit = y3.unit.create_unit(owner, unit_id, point, direction)
local unit = y3.unit.get_by_id(id)

-- 常用方法
unit:set_attr('攻击', 100)          -- 设置属性
unit:add_hp(50)                      -- 增加生命值
unit:add_ability(ability_id)         -- 添加技能
unit:add_buff({ key = buff_id, time = 5.0 })  -- 添加魔法效果
unit:move_to_pos(point)              -- 移动到点
unit:mover_line({ angle = 0, distance = 500, speed = 300 })  -- 直线运动
```

### 物品 (Item)
```lua
-- 创建/获取
local item = y3.item.create_item(point, item_key, player)
local item = y3.item.get_by_id(id)

-- 常用方法
item:set_stack(5)                    -- 设置堆叠数
item:set_charge(3)                   -- 设置充能数
item:drop()                          -- 掉落物品
local owner = item:get_owner()       -- 获取持有单位
```

### 技能 (Ability)
```lua
-- 通过单位创建
local ability = unit:add_ability(ability_id)
local ability = unit:find_ability(ability_id)

-- 常用方法
ability:set_level(3)                 -- 设置等级
ability:set_cd(5.0)                  -- 设置冷却
ability:complete_cd()                -- 完成冷却
ability:set_float_attr('伤害', 100)  -- 设置浮点属性
```

### 投射物 (Projectile)
```lua
-- 创建
local proj = y3.projectile.create({
    key = projectile_id,
    target = point,                  -- 或 unit
    angle = 0,
    time = 3.0,
    owner = unit
})

-- 常用方法
proj:set_point(point)
proj:mover_target({ target = enemy, speed = 500 })
```

### 魔法效果 (Buff)
```lua
-- 通过单位创建
local buff = unit:add_buff({
    key = buff_id,
    source = caster,
    time = 10.0,
    stacks = 1
})

-- 常用方法
buff:set_stack(3)                    -- 设置层数
buff:add_time(5.0)                   -- 延长持续时间
buff:set_shield(100)                 -- 设置护盾值
buff:remove()                        -- 移除
```

### 运动器 (Mover)
运动器通过单位/投射物调用，用于控制物体运动轨迹：

```lua
-- 直线运动
unit:mover_line({
    angle = 0,                       -- 方向（度）
    distance = 500,                  -- 距离
    speed = 300,                     -- 速度
    acceleration = 50,               -- 加速度
    hit_radius = 100,                -- 碰撞范围
    hit_type = 0,                    -- 0:敌人 1:盟友 2:全部
    terrain_block = true,            -- 地形阻挡
    on_hit = function(mover, target) end,
    on_finish = function(mover) end
})

-- 追踪运动
unit:mover_target({
    target = enemy,                  -- 追踪目标
    speed = 400,
    on_hit = function(mover, target) end
})

-- 曲线运动
unit:mover_curve({
    path = { point1, point2, point3 },
    speed = 300
})

-- 环绕运动
unit:mover_round({
    target = center_point,           -- 或 unit
    radius = 200,
    angle_speed = 90,                -- 度/秒
    round_time = 5.0
})
```

## 开发验证流程
代码修改完成后，使用 y3-helper MCP 工具进行游戏内验证(如果未连接至该MCP则跳过)：
1. 启动游戏（如未运行）
2. 检查 `get_logs` 确认无报错
3. 如有错误，修复后重复验证
4. 用 `quick_restart` 或 `execute_lua` 加载新代码


## 重要注意事项

- **尽量不要直接调用 CAPI** - 始终使用 y3 框架封装，因为 CAPI 可能会变更
- **模型资源** - Lua 中使用的模型/特效必须在表格编辑器中声明才能触发下载
- 如果需要制作UI，请先查看@UI适配规则.md
- `y3/` 目录下的文件是框架库，修改时请谨慎
- 参考 `y3/演示/` 中的演示代码了解常见用法
- **定点数**：所有数值在底层使用定点数以保证帧同步一致性
- **事件系统**：所有游戏对象支持 `:event()` 方法注册事件回调
- **引用管理**：通过 `get_by_id()` 或 `get_by_handle()` 获取对象实例
