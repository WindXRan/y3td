---@class ECAHelper
---@field call fun(name: '界面初始化', 玩家: Player)
---@field call fun(name: '单选英雄_选中英雄', 英雄: Unit, 玩家: Player)
---@field call fun(name: '更新玩家选中状态', 玩家: Player)
---@field call fun(name: '多选单位_选中单位', 选中单位组: UnitGroup, 玩家: Player)
---@field call fun(name: '多选单位_选择分组', 玩家: Player, 组号: integer)
---@field call fun(name: '单选生物_选中生物_普通', 生物: Unit, 玩家: Player)
---@field call fun(name: '单选生物_选中生物_召唤物', 生物: Unit, 玩家: Player)
---@field call fun(name: '单选单位_选中商店', 商店: Unit, 玩家: Player)
---@field call fun(name: '单选商店_更新商店物品栏绑定单位', 商店: Unit, 玩家: Player)
---@field call fun(name: '单选单位_选中建筑', 建筑: Unit, 玩家: Player)
---@field call fun(name: '更新系统提示', 提示信息: string, 存在时长: number)
---@field call fun(name: 'get_code_reward', code: string, player: Player, hero: Unit)
---@field call fun(name: '【高级消息】添加消息', 目标控件: any, 消息文字: string, 消息优先级: integer, 立即显示: boolean)
---@field call fun(name: '【跑马灯公告】添加消息', 目标控件: any, 消息文字: string, 消息优先级: integer, 立即显示: boolean)
---@field call fun(name: '【高级消息】添加消息_2', 目标控件: any, 消息文字: string, 消息优先级: integer, 立即显示: boolean)
---@field call fun(name: '【跑马灯公告】添加消息_2', 目标控件: any, 消息文字: string, 消息优先级: integer, 立即显示: boolean)
---@field call fun(name: '【高级消息】清空消息', 目标控件: any)
---@field call fun(name: 'HUD同步', 玩家id: integer, 界面id: integer)
---@field call fun(name: '玩家加载操作', 玩家id: integer, 加载项id: integer)
---@field call fun(name: '[悬浮信息]通用详情', 玩家id: integer, 标题: string, 小标题: string, 描述: string, 一句话: string, 玩家属性图标: any, 属性价格: string, 待对齐控件: any, 方向: integer, 显隐: boolean)
---@field call fun(name: '打开签到页面', 玩家: Player)

---@diagnostic disable: invisible

y3.eca = y3.eca or {}
y3.eca.register_custom_event_impl = y3.eca.register_custom_event_impl or function (name, impl) end
y3.eca.register_custom_event_resolve = y3.eca.register_custom_event_resolve or function (name, resolve) end

y3.eca.register_custom_event_impl('界面初始化', function (_, 玩家)
    y3.game.send_custom_event(1202296270, {
        ["玩家"] = y3.py_converter.lua_to_py_by_lua_type('Player', 玩家)
    })
end)

y3.eca.register_custom_event_impl('单选英雄_选中英雄', function (_, 英雄, 玩家)
    y3.game.send_custom_event(1695746711, {
        ["英雄"] = y3.py_converter.lua_to_py_by_lua_type('Unit', 英雄),
        ["玩家"] = y3.py_converter.lua_to_py_by_lua_type('Player', 玩家)
    })
end)

y3.eca.register_custom_event_impl('更新玩家选中状态', function (_, 玩家)
    y3.game.send_custom_event(1460986851, {
        ["玩家"] = y3.py_converter.lua_to_py_by_lua_type('Player', 玩家)
    })
end)

y3.eca.register_custom_event_impl('多选单位_选中单位', function (_, 选中单位组, 玩家)
    y3.game.send_custom_event(1902559067, {
        ["选中单位组"] = y3.py_converter.lua_to_py_by_lua_type('UnitGroup', 选中单位组),
        ["玩家"] = y3.py_converter.lua_to_py_by_lua_type('Player', 玩家)
    })
end)

y3.eca.register_custom_event_impl('多选单位_选择分组', function (_, 玩家, 组号)
    y3.game.send_custom_event(2053950930, {
        ["玩家"] = y3.py_converter.lua_to_py_by_lua_type('Player', 玩家),
        ["组号"] = 组号
    })
end)

y3.eca.register_custom_event_impl('单选生物_选中生物_普通', function (_, 生物, 玩家)
    y3.game.send_custom_event(1708434595, {
        ["生物"] = y3.py_converter.lua_to_py_by_lua_type('Unit', 生物),
        ["玩家"] = y3.py_converter.lua_to_py_by_lua_type('Player', 玩家)
    })
end)

y3.eca.register_custom_event_impl('单选生物_选中生物_召唤物', function (_, 生物, 玩家)
    y3.game.send_custom_event(2000364876, {
        ["生物"] = y3.py_converter.lua_to_py_by_lua_type('Unit', 生物),
        ["玩家"] = y3.py_converter.lua_to_py_by_lua_type('Player', 玩家)
    })
end)

y3.eca.register_custom_event_impl('单选单位_选中商店', function (_, 商店, 玩家)
    y3.game.send_custom_event(1512146893, {
        ["商店"] = y3.py_converter.lua_to_py_by_lua_type('Unit', 商店),
        ["玩家"] = y3.py_converter.lua_to_py_by_lua_type('Player', 玩家)
    })
end)

y3.eca.register_custom_event_impl('单选商店_更新商店物品栏绑定单位', function (_, 商店, 玩家)
    y3.game.send_custom_event(1216731266, {
        ["商店"] = y3.py_converter.lua_to_py_by_lua_type('Unit', 商店),
        ["玩家"] = y3.py_converter.lua_to_py_by_lua_type('Player', 玩家)
    })
end)

y3.eca.register_custom_event_impl('单选单位_选中建筑', function (_, 建筑, 玩家)
    y3.game.send_custom_event(1245810636, {
        ["建筑"] = y3.py_converter.lua_to_py_by_lua_type('Unit', 建筑),
        ["玩家"] = y3.py_converter.lua_to_py_by_lua_type('Player', 玩家)
    })
end)

y3.eca.register_custom_event_impl('更新系统提示', function (_, 提示信息, 存在时长)
    y3.game.send_custom_event(1950545891, {
        ["提示信息"] = 提示信息,
        ["存在时长"] = 存在时长
    })
end)

y3.eca.register_custom_event_impl('get_code_reward', function (_, code, player, hero)
    y3.game.send_custom_event(1778700091, {
        ["code"] = code,
        ["player"] = y3.py_converter.lua_to_py_by_lua_type('Player', player),
        ["hero"] = y3.py_converter.lua_to_py_by_lua_type('Unit', hero)
    })
end)

y3.eca.register_custom_event_impl('【高级消息】添加消息', function (_, 目标控件, 消息文字, 消息优先级, 立即显示)
    y3.game.send_custom_event(1048899873, {
        ["目标控件"] = y3.py_converter.lua_to_py_by_lua_type('any', 目标控件),
        ["消息文字"] = 消息文字,
        ["消息优先级"] = 消息优先级,
        ["立即显示"] = 立即显示
    })
end)

y3.eca.register_custom_event_impl('【跑马灯公告】添加消息', function (_, 目标控件, 消息文字, 消息优先级, 立即显示)
    y3.game.send_custom_event(2036245900, {
        ["目标控件"] = y3.py_converter.lua_to_py_by_lua_type('any', 目标控件),
        ["消息文字"] = 消息文字,
        ["消息优先级"] = 消息优先级,
        ["立即显示"] = 立即显示
    })
end)

y3.eca.register_custom_event_impl('【高级消息】添加消息_2', function (_, 目标控件, 消息文字, 消息优先级, 立即显示)
    y3.game.send_custom_event(1948197137, {
        ["目标控件"] = y3.py_converter.lua_to_py_by_lua_type('any', 目标控件),
        ["消息文字"] = 消息文字,
        ["消息优先级"] = 消息优先级,
        ["立即显示"] = 立即显示
    })
end)

y3.eca.register_custom_event_impl('【跑马灯公告】添加消息_2', function (_, 目标控件, 消息文字, 消息优先级, 立即显示)
    y3.game.send_custom_event(1024373425, {
        ["目标控件"] = y3.py_converter.lua_to_py_by_lua_type('any', 目标控件),
        ["消息文字"] = 消息文字,
        ["消息优先级"] = 消息优先级,
        ["立即显示"] = 立即显示
    })
end)

y3.eca.register_custom_event_impl('【高级消息】清空消息', function (_, 目标控件)
    y3.game.send_custom_event(1098456899, {
        ["目标控件"] = y3.py_converter.lua_to_py_by_lua_type('any', 目标控件)
    })
end)

y3.eca.register_custom_event_impl('HUD同步', function (_, 玩家id, 界面id)
    y3.game.send_custom_event(2065862999, {
        ["玩家id"] = 玩家id,
        ["界面id"] = 界面id
    })
end)

y3.eca.register_custom_event_impl('玩家加载操作', function (_, 玩家id, 加载项id)
    y3.game.send_custom_event(1336439815, {
        ["玩家id"] = 玩家id,
        ["加载项id"] = 加载项id
    })
end)

y3.eca.register_custom_event_impl('[悬浮信息]通用详情', function (_, 玩家id, 标题, 小标题, 描述, 一句话, 玩家属性图标, 属性价格, 待对齐控件, 方向, 显隐)
    y3.game.send_custom_event(2030583941, {
        ["玩家id"] = 玩家id,
        ["标题"] = 标题,
        ["小标题"] = 小标题,
        ["描述"] = 描述,
        ["一句话"] = 一句话,
        ["玩家属性图标"] = y3.py_converter.lua_to_py_by_lua_type('any', 玩家属性图标),
        ["属性价格"] = 属性价格,
        ["待对齐控件"] = y3.py_converter.lua_to_py_by_lua_type('any', 待对齐控件),
        ["方向"] = 方向,
        ["显隐"] = 显隐
    })
end)

y3.eca.register_custom_event_impl('打开签到页面', function (_, 玩家)
    y3.game.send_custom_event(1598002187, {
        ["玩家"] = y3.py_converter.lua_to_py_by_lua_type('Player', 玩家)
    })
end)

y3.const.CustomEventName = y3.const.CustomEventName or {}

y3.const.CustomEventName['界面初始化'] = 1202296270
y3.const.CustomEventName['单选英雄_选中英雄'] = 1695746711
y3.const.CustomEventName['更新玩家选中状态'] = 1460986851
y3.const.CustomEventName['多选单位_选中单位'] = 1902559067
y3.const.CustomEventName['多选单位_选择分组'] = 2053950930
y3.const.CustomEventName['单选生物_选中生物_普通'] = 1708434595
y3.const.CustomEventName['单选生物_选中生物_召唤物'] = 2000364876
y3.const.CustomEventName['单选单位_选中商店'] = 1512146893
y3.const.CustomEventName['单选商店_更新商店物品栏绑定单位'] = 1216731266
y3.const.CustomEventName['单选单位_选中建筑'] = 1245810636
y3.const.CustomEventName['更新系统提示'] = 1950545891
y3.const.CustomEventName['get_code_reward'] = 1778700091
y3.const.CustomEventName['【高级消息】添加消息'] = 1048899873
y3.const.CustomEventName['【跑马灯公告】添加消息'] = 2036245900
y3.const.CustomEventName['【高级消息】添加消息_2'] = 1948197137
y3.const.CustomEventName['【跑马灯公告】添加消息_2'] = 1024373425
y3.const.CustomEventName['【高级消息】清空消息'] = 1098456899
y3.const.CustomEventName['HUD同步'] = 2065862999
y3.const.CustomEventName['玩家加载操作'] = 1336439815
y3.const.CustomEventName['[悬浮信息]通用详情'] = 2030583941
y3.const.CustomEventName['打开签到页面'] = 1598002187

---@enum(key, partial) y3.Const.CustomEventName
local CustomEventName = {
    ['界面初始化'] = 1202296270,
    ['单选英雄_选中英雄'] = 1695746711,
    ['更新玩家选中状态'] = 1460986851,
    ['多选单位_选中单位'] = 1902559067,
    ['多选单位_选择分组'] = 2053950930,
    ['单选生物_选中生物_普通'] = 1708434595,
    ['单选生物_选中生物_召唤物'] = 2000364876,
    ['单选单位_选中商店'] = 1512146893,
    ['单选商店_更新商店物品栏绑定单位'] = 1216731266,
    ['单选单位_选中建筑'] = 1245810636,
    ['更新系统提示'] = 1950545891,
    ['get_code_reward'] = 1778700091,
    ['【高级消息】添加消息'] = 1048899873,
    ['【跑马灯公告】添加消息'] = 2036245900,
    ['【高级消息】添加消息_2'] = 1948197137,
    ['【跑马灯公告】添加消息_2'] = 1024373425,
    ['【高级消息】清空消息'] = 1098456899,
    ['HUD同步'] = 2065862999,
    ['玩家加载操作'] = 1336439815,
    ['[悬浮信息]通用详情'] = 2030583941,
    ['打开签到页面'] = 1598002187,
}

y3.eca.register_custom_event_resolve("界面初始化", function (data)
    data.name = "界面初始化"
    data.data = {
        ["玩家"] = y3.py_converter.py_to_lua_by_lua_type('Player', data.c_param_dict["玩家"]),
    }
    return data
end)
y3.eca.register_custom_event_resolve("单选英雄_选中英雄", function (data)
    data.name = "单选英雄_选中英雄"
    data.data = {
        ["英雄"] = y3.py_converter.py_to_lua_by_lua_type('Unit', data.c_param_dict["英雄"]),
        ["玩家"] = y3.py_converter.py_to_lua_by_lua_type('Player', data.c_param_dict["玩家"]),
    }
    return data
end)
y3.eca.register_custom_event_resolve("更新玩家选中状态", function (data)
    data.name = "更新玩家选中状态"
    data.data = {
        ["玩家"] = y3.py_converter.py_to_lua_by_lua_type('Player', data.c_param_dict["玩家"]),
    }
    return data
end)
y3.eca.register_custom_event_resolve("多选单位_选中单位", function (data)
    data.name = "多选单位_选中单位"
    data.data = {
        ["选中单位组"] = y3.py_converter.py_to_lua_by_lua_type('UnitGroup', data.c_param_dict["选中单位组"]),
        ["玩家"] = y3.py_converter.py_to_lua_by_lua_type('Player', data.c_param_dict["玩家"]),
    }
    return data
end)
y3.eca.register_custom_event_resolve("多选单位_选择分组", function (data)
    data.name = "多选单位_选择分组"
    data.data = {
        ["玩家"] = y3.py_converter.py_to_lua_by_lua_type('Player', data.c_param_dict["玩家"]),
        ["组号"] = data.c_param_dict["组号"],
    }
    return data
end)
y3.eca.register_custom_event_resolve("单选生物_选中生物_普通", function (data)
    data.name = "单选生物_选中生物_普通"
    data.data = {
        ["生物"] = y3.py_converter.py_to_lua_by_lua_type('Unit', data.c_param_dict["生物"]),
        ["玩家"] = y3.py_converter.py_to_lua_by_lua_type('Player', data.c_param_dict["玩家"]),
    }
    return data
end)
y3.eca.register_custom_event_resolve("单选生物_选中生物_召唤物", function (data)
    data.name = "单选生物_选中生物_召唤物"
    data.data = {
        ["生物"] = y3.py_converter.py_to_lua_by_lua_type('Unit', data.c_param_dict["生物"]),
        ["玩家"] = y3.py_converter.py_to_lua_by_lua_type('Player', data.c_param_dict["玩家"]),
    }
    return data
end)
y3.eca.register_custom_event_resolve("单选单位_选中商店", function (data)
    data.name = "单选单位_选中商店"
    data.data = {
        ["商店"] = y3.py_converter.py_to_lua_by_lua_type('Unit', data.c_param_dict["商店"]),
        ["玩家"] = y3.py_converter.py_to_lua_by_lua_type('Player', data.c_param_dict["玩家"]),
    }
    return data
end)
y3.eca.register_custom_event_resolve("单选商店_更新商店物品栏绑定单位", function (data)
    data.name = "单选商店_更新商店物品栏绑定单位"
    data.data = {
        ["商店"] = y3.py_converter.py_to_lua_by_lua_type('Unit', data.c_param_dict["商店"]),
        ["玩家"] = y3.py_converter.py_to_lua_by_lua_type('Player', data.c_param_dict["玩家"]),
    }
    return data
end)
y3.eca.register_custom_event_resolve("单选单位_选中建筑", function (data)
    data.name = "单选单位_选中建筑"
    data.data = {
        ["建筑"] = y3.py_converter.py_to_lua_by_lua_type('Unit', data.c_param_dict["建筑"]),
        ["玩家"] = y3.py_converter.py_to_lua_by_lua_type('Player', data.c_param_dict["玩家"]),
    }
    return data
end)
y3.eca.register_custom_event_resolve("更新系统提示", function (data)
    data.name = "更新系统提示"
    data.data = {
        ["提示信息"] = data.c_param_dict["提示信息"],
        ["存在时长"] = data.c_param_dict["存在时长"],
    }
    return data
end)
y3.eca.register_custom_event_resolve("get_code_reward", function (data)
    data.name = "get_code_reward"
    data.data = {
        ["code"] = data.c_param_dict["code"],
        ["player"] = y3.py_converter.py_to_lua_by_lua_type('Player', data.c_param_dict["player"]),
        ["hero"] = y3.py_converter.py_to_lua_by_lua_type('Unit', data.c_param_dict["hero"]),
    }
    return data
end)
y3.eca.register_custom_event_resolve("【高级消息】添加消息", function (data)
    data.name = "【高级消息】添加消息"
    data.data = {
        ["目标控件"] = y3.py_converter.py_to_lua_by_lua_type('any', data.c_param_dict["目标控件"]),
        ["消息文字"] = data.c_param_dict["消息文字"],
        ["消息优先级"] = data.c_param_dict["消息优先级"],
        ["立即显示"] = data.c_param_dict["立即显示"],
    }
    return data
end)
y3.eca.register_custom_event_resolve("【跑马灯公告】添加消息", function (data)
    data.name = "【跑马灯公告】添加消息"
    data.data = {
        ["目标控件"] = y3.py_converter.py_to_lua_by_lua_type('any', data.c_param_dict["目标控件"]),
        ["消息文字"] = data.c_param_dict["消息文字"],
        ["消息优先级"] = data.c_param_dict["消息优先级"],
        ["立即显示"] = data.c_param_dict["立即显示"],
    }
    return data
end)
y3.eca.register_custom_event_resolve("【高级消息】添加消息_2", function (data)
    data.name = "【高级消息】添加消息_2"
    data.data = {
        ["目标控件"] = y3.py_converter.py_to_lua_by_lua_type('any', data.c_param_dict["目标控件"]),
        ["消息文字"] = data.c_param_dict["消息文字"],
        ["消息优先级"] = data.c_param_dict["消息优先级"],
        ["立即显示"] = data.c_param_dict["立即显示"],
    }
    return data
end)
y3.eca.register_custom_event_resolve("【跑马灯公告】添加消息_2", function (data)
    data.name = "【跑马灯公告】添加消息_2"
    data.data = {
        ["目标控件"] = y3.py_converter.py_to_lua_by_lua_type('any', data.c_param_dict["目标控件"]),
        ["消息文字"] = data.c_param_dict["消息文字"],
        ["消息优先级"] = data.c_param_dict["消息优先级"],
        ["立即显示"] = data.c_param_dict["立即显示"],
    }
    return data
end)
y3.eca.register_custom_event_resolve("【高级消息】清空消息", function (data)
    data.name = "【高级消息】清空消息"
    data.data = {
        ["目标控件"] = y3.py_converter.py_to_lua_by_lua_type('any', data.c_param_dict["目标控件"]),
    }
    return data
end)
y3.eca.register_custom_event_resolve("HUD同步", function (data)
    data.name = "HUD同步"
    data.data = {
        ["玩家id"] = data.c_param_dict["玩家id"],
        ["界面id"] = data.c_param_dict["界面id"],
    }
    return data
end)
y3.eca.register_custom_event_resolve("玩家加载操作", function (data)
    data.name = "玩家加载操作"
    data.data = {
        ["玩家id"] = data.c_param_dict["玩家id"],
        ["加载项id"] = data.c_param_dict["加载项id"],
    }
    return data
end)
y3.eca.register_custom_event_resolve("[悬浮信息]通用详情", function (data)
    data.name = "[悬浮信息]通用详情"
    data.data = {
        ["玩家id"] = data.c_param_dict["玩家id"],
        ["标题"] = data.c_param_dict["标题"],
        ["小标题"] = data.c_param_dict["小标题"],
        ["描述"] = data.c_param_dict["描述"],
        ["一句话"] = data.c_param_dict["一句话"],
        ["玩家属性图标"] = y3.py_converter.py_to_lua_by_lua_type('any', data.c_param_dict["玩家属性图标"]),
        ["属性价格"] = data.c_param_dict["属性价格"],
        ["待对齐控件"] = y3.py_converter.py_to_lua_by_lua_type('any', data.c_param_dict["待对齐控件"]),
        ["方向"] = data.c_param_dict["方向"],
        ["显隐"] = data.c_param_dict["显隐"],
    }
    return data
end)
y3.eca.register_custom_event_resolve("打开签到页面", function (data)
    data.name = "打开签到页面"
    data.data = {
        ["玩家"] = y3.py_converter.py_to_lua_by_lua_type('Player', data.c_param_dict["玩家"]),
    }
    return data
end)

---@alias EventParam.游戏-消息.界面初始化 { c_param_1: 1202296270, c_param_dict: py.Dict, event: "界面初始化", data: { ["玩家"]: Player } }
---@alias EventParam.游戏-消息.单选英雄_选中英雄 { c_param_1: 1695746711, c_param_dict: py.Dict, event: "单选英雄_选中英雄", data: { ["英雄"]: Unit, ["玩家"]: Player } }
---@alias EventParam.游戏-消息.更新玩家选中状态 { c_param_1: 1460986851, c_param_dict: py.Dict, event: "更新玩家选中状态", data: { ["玩家"]: Player } }
---@alias EventParam.游戏-消息.多选单位_选中单位 { c_param_1: 1902559067, c_param_dict: py.Dict, event: "多选单位_选中单位", data: { ["选中单位组"]: UnitGroup, ["玩家"]: Player } }
---@alias EventParam.游戏-消息.多选单位_选择分组 { c_param_1: 2053950930, c_param_dict: py.Dict, event: "多选单位_选择分组", data: { ["玩家"]: Player, ["组号"]: integer } }
---@alias EventParam.游戏-消息.单选生物_选中生物_普通 { c_param_1: 1708434595, c_param_dict: py.Dict, event: "单选生物_选中生物_普通", data: { ["生物"]: Unit, ["玩家"]: Player } }
---@alias EventParam.游戏-消息.单选生物_选中生物_召唤物 { c_param_1: 2000364876, c_param_dict: py.Dict, event: "单选生物_选中生物_召唤物", data: { ["生物"]: Unit, ["玩家"]: Player } }
---@alias EventParam.游戏-消息.单选单位_选中商店 { c_param_1: 1512146893, c_param_dict: py.Dict, event: "单选单位_选中商店", data: { ["商店"]: Unit, ["玩家"]: Player } }
---@alias EventParam.游戏-消息.单选商店_更新商店物品栏绑定单位 { c_param_1: 1216731266, c_param_dict: py.Dict, event: "单选商店_更新商店物品栏绑定单位", data: { ["商店"]: Unit, ["玩家"]: Player } }
---@alias EventParam.游戏-消息.单选单位_选中建筑 { c_param_1: 1245810636, c_param_dict: py.Dict, event: "单选单位_选中建筑", data: { ["建筑"]: Unit, ["玩家"]: Player } }
---@alias EventParam.游戏-消息.更新系统提示 { c_param_1: 1950545891, c_param_dict: py.Dict, event: "更新系统提示", data: { ["提示信息"]: string, ["存在时长"]: number } }
---@alias EventParam.游戏-消息.get_code_reward { c_param_1: 1778700091, c_param_dict: py.Dict, event: "get_code_reward", data: { ["code"]: string, ["player"]: Player, ["hero"]: Unit } }
---@alias EventParam.游戏-消息.【高级消息】添加消息 { c_param_1: 1048899873, c_param_dict: py.Dict, event: "【高级消息】添加消息", data: { ["目标控件"]: any, ["消息文字"]: string, ["消息优先级"]: integer, ["立即显示"]: boolean } }
---@alias EventParam.游戏-消息.【跑马灯公告】添加消息 { c_param_1: 2036245900, c_param_dict: py.Dict, event: "【跑马灯公告】添加消息", data: { ["目标控件"]: any, ["消息文字"]: string, ["消息优先级"]: integer, ["立即显示"]: boolean } }
---@alias EventParam.游戏-消息.【高级消息】添加消息_2 { c_param_1: 1948197137, c_param_dict: py.Dict, event: "【高级消息】添加消息_2", data: { ["目标控件"]: any, ["消息文字"]: string, ["消息优先级"]: integer, ["立即显示"]: boolean } }
---@alias EventParam.游戏-消息.【跑马灯公告】添加消息_2 { c_param_1: 1024373425, c_param_dict: py.Dict, event: "【跑马灯公告】添加消息_2", data: { ["目标控件"]: any, ["消息文字"]: string, ["消息优先级"]: integer, ["立即显示"]: boolean } }
---@alias EventParam.游戏-消息.【高级消息】清空消息 { c_param_1: 1098456899, c_param_dict: py.Dict, event: "【高级消息】清空消息", data: { ["目标控件"]: any } }
---@alias EventParam.游戏-消息.HUD同步 { c_param_1: 2065862999, c_param_dict: py.Dict, event: "HUD同步", data: { ["玩家id"]: integer, ["界面id"]: integer } }
---@alias EventParam.游戏-消息.玩家加载操作 { c_param_1: 1336439815, c_param_dict: py.Dict, event: "玩家加载操作", data: { ["玩家id"]: integer, ["加载项id"]: integer } }
---@alias EventParam.游戏-消息._悬浮信息_通用详情 { c_param_1: 2030583941, c_param_dict: py.Dict, event: "[悬浮信息]通用详情", data: { ["玩家id"]: integer, ["标题"]: string, ["小标题"]: string, ["描述"]: string, ["一句话"]: string, ["玩家属性图标"]: any, ["属性价格"]: string, ["待对齐控件"]: any, ["方向"]: integer, ["显隐"]: boolean } }
---@alias EventParam.游戏-消息.打开签到页面 { c_param_1: 1598002187, c_param_dict: py.Dict, event: "打开签到页面", data: { ["玩家"]: Player } }

---@class Game
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "界面初始化", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.界面初始化))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "单选英雄_选中英雄", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.单选英雄_选中英雄))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "更新玩家选中状态", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.更新玩家选中状态))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "多选单位_选中单位", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.多选单位_选中单位))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "多选单位_选择分组", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.多选单位_选择分组))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "单选生物_选中生物_普通", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.单选生物_选中生物_普通))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "单选生物_选中生物_召唤物", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.单选生物_选中生物_召唤物))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "单选单位_选中商店", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.单选单位_选中商店))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "单选商店_更新商店物品栏绑定单位", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.单选商店_更新商店物品栏绑定单位))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "单选单位_选中建筑", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.单选单位_选中建筑))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "更新系统提示", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.更新系统提示))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "get_code_reward", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.get_code_reward))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "【高级消息】添加消息", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.【高级消息】添加消息))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "【跑马灯公告】添加消息", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.【跑马灯公告】添加消息))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "【高级消息】添加消息_2", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.【高级消息】添加消息_2))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "【跑马灯公告】添加消息_2", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.【跑马灯公告】添加消息_2))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "【高级消息】清空消息", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.【高级消息】清空消息))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "HUD同步", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.HUD同步))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "玩家加载操作", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.玩家加载操作))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "[悬浮信息]通用详情", callback: fun(trigger: Trigger, data: EventParam.游戏-消息._悬浮信息_通用详情))
---@diagnostic disable-next-line: duplicate-doc-field
---@field event fun(self: Game, event: "游戏-消息", event_id: "打开签到页面", callback: fun(trigger: Trigger, data: EventParam.游戏-消息.打开签到页面))
