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
