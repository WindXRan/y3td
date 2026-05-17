
--[[
    事件总线适配器 (Event Bus Adapter)
    提供与 Y3 引擎事件系统的兼容层，将旧版 y3.game:event() 调用桥接到新的事件总线
    
    使用方式:
        local EventBusAdapter = require 'core.event_bus_adapter'
        local adapter = EventBusAdapter.create(event_bus)
        
        -- 使用默认事件桥接
        local bridge = adapter.bridge
        
        -- 使用便捷订阅方法
        local subscribe = adapter.subscribe
        subscribe.on_battle_event('start', function(data)
            print('Battle started')
        end)
        
        -- 创建自定义事件桥接
        local custom_bridge = adapter.create_event_bridge()
        custom_bridge.register('单位-受到伤害', 'unit.damaged', function(unit, damage)
            return { unit = unit, damage = damage }
        end)
]]

local M = {}

---
-- 创建事件总线适配器实例
-- @param event_bus table EventBus实例
-- @param options table 配置选项（可选）
-- @param options.error_handler table ErrorHandler实例（可选）
-- @return table 适配器实例
---
function M.create(event_bus, options)
    options = options or {}
    
    -- Y3事件处理器缓存（用于去重）
    local y3_game_event_cache = {}
    local is_initialized = false
    
    -- 错误处理器（如果未提供，使用降级方案）
    local error_handler = options.error_handler
    local logger = error_handler and error_handler.logger('EventBusAdapter')

    ---
    -- 包装 y3.game.event 函数
    -- 将旧版事件订阅自动桥接到新的事件总线
    ---
    local function wrap_y3_game_event()
        if is_initialized then return end
        is_initialized = true

        -- 保存原始的 y3.game.event
        local original_event = y3.game.event

        -- 重写 y3.game.event
        y3.game.event = function(event_name, handler)
            -- 参数校验
            if type(event_name) ~= 'string' or type(handler) ~= 'function' then
                return original_event(event_name, handler)
            end

            -- 如果是第一次订阅该事件，创建桥接
            if not y3_game_event_cache[event_name] then
                y3_game_event_cache[event_name] = {}

                -- 订阅原始事件
                original_event(event_name, function(...)
                    local args = {...}
                    
                    -- 将 Y3 事件转发到事件总线
                    event_bus.publish(event_name, {
                        source = 'y3',
                        args = args,
                        timestamp = os.clock()
                    })

                    -- 通知所有缓存的处理器
                    for _, h in ipairs(y3_game_event_cache[event_name]) do
                        if error_handler then
                            local result = error_handler.safe_call(function() h(unpack(args)) end)
                        else
                            -- 降级到 pcall
                            pcall(function() h(unpack(args)) end)
                        end
                    end
                end)
            end

            -- 添加到缓存
            table.insert(y3_game_event_cache[event_name], handler)

            -- 返回取消订阅函数
            return function()
                local handlers = y3_game_event_cache[event_name]
                if handlers then
                    for i, h in ipairs(handlers) do
                        if h == handler then
                            table.remove(handlers, i)
                            break
                        end
                    end
                end
            end
        end
    end

    ---
    -- 创建事件桥接器
    -- 将 Y3 事件映射到事件总线事件
    -- @param event_mapping table 事件映射表（可选）
    -- @return table 桥接器实例
    ---
    local function create_event_bridge(event_mapping)
        event_mapping = event_mapping or {}

        local bridge = {}

        ---
        -- 注册单个事件映射
        -- @param y3_event_name string Y3事件名称
        -- @param bus_event_name string 事件总线事件名称
        -- @param transform function 参数转换函数（可选）
        ---
        bridge.register = function(y3_event_name, bus_event_name, transform)
            if type(y3_event_name) ~= 'string' or type(bus_event_name) ~= 'string' then
                error('Event names must be strings')
            end

            -- 订阅 Y3 事件并转发到事件总线
            y3.game:event(y3_event_name, function(...)
                local args = {...}
                -- 如果提供了转换函数，使用转换后的负载
                local payload = transform and transform(unpack(args)) or { args = args }
                
                event_bus.publish(bus_event_name, payload)
            end)
        end

        ---
        -- 批量映射事件
        -- @param mappings table 映射配置表
        ---
        bridge.map = function(mappings)
            for y3_name, config in pairs(mappings) do
                -- 支持字符串格式（直接映射）或对象格式（带转换）
                local bus_name = type(config) == 'string' and config or config.bus_event
                local transform = type(config) == 'table' and config.transform or nil
                bridge.register(y3_name, bus_name, transform)
            end
        end

        return bridge
    end

    ---
    -- 创建便捷订阅辅助函数
    -- 提供按事件类型分类的订阅方法
    -- @return table 订阅辅助函数集
    ---
    local function create_subscribe_helpers()
        local helpers = {}

        ---
        -- 订阅战斗事件
        -- @param event_type string 事件类型（如 'start', 'end'）
        -- @param handler function 事件处理器
        -- @return function 取消订阅函数
        ---
        helpers.on_battle_event = function(event_type, handler)
            local event_name = 'battle.' .. event_type
            return event_bus.on(event_name, handler)
        end

        ---
        -- 订阅波次事件
        -- @param event_type string 事件类型（如 'start', 'end'）
        -- @param handler function 事件处理器
        -- @return function 取消订阅函数
        ---
        helpers.on_wave_event = function(event_type, handler)
            local event_name = 'wave.' .. event_type
            return event_bus.on(event_name, handler)
        end

        ---
        -- 订阅英雄事件
        -- @param event_type string 事件类型（如 'hurt', 'heal', 'death'）
        -- @param handler function 事件处理器
        -- @return function 取消订阅函数
        ---
        helpers.on_hero_event = function(event_type, handler)
            local event_name = 'hero.' .. event_type
            return event_bus.on(event_name, handler)
        end

        ---
        -- 订阅UI事件
        -- @param event_type string 事件类型（如 'panel_open', 'panel_close'）
        -- @param handler function 事件处理器
        -- @return function 取消订阅函数
        ---
        helpers.on_ui_event = function(event_type, handler)
            local event_name = 'ui.' .. event_type
            return event_bus.on(event_name, handler)
        end

        ---
        -- 订阅系统事件
        -- @param event_type string 事件类型（如 'pause', 'resume'）
        -- @param handler function 事件处理器
        -- @return function 取消订阅函数
        ---
        helpers.on_system_event = function(event_type, handler)
            local event_name = 'system.' .. event_type
            return event_bus.on(event_name, handler)
        end

        return helpers
    end

    ---
    -- 设置默认事件桥接
    -- 将常用的 Y3 事件自动映射到事件总线
    -- @return table 桥接器实例
    ---
    local function setup_default_event_bridge()
        local bridge = create_event_bridge()

        -- 默认事件映射配置
        bridge.map({
            -- 游戏生命周期事件
            ['游戏-初始化'] = {
                bus_event = event_bus.events.BATTLE_START,
                transform = function()
                    return { timestamp = os.clock() }
                end
            },

            ['游戏-暂停'] = {
                bus_event = 'system.pause',
                transform = function()
                    return { timestamp = os.clock() }
                end
            },

            ['游戏-恢复'] = {
                bus_event = 'system.resume',
                transform = function()
                    return { timestamp = os.clock() }
                end
            },

            -- 单位事件
            ['单位-受到伤害'] = {
                bus_event = 'unit.damaged',
                transform = function(unit, damage)
                    return {
                        unit = unit,
                        damage = damage,
                        timestamp = os.clock()
                    }
                end
            },

            ['单位-死亡'] = {
                bus_event = 'unit.death',
                transform = function(unit)
                    return {
                        unit = unit,
                        timestamp = os.clock()
                    }
                end
            },

            -- 技能事件
            ['技能-释放'] = {
                bus_event = event_bus.events.SKILL_CAST,
                transform = function(skill, caster)
                    return {
                        skill = skill,
                        caster = caster,
                        timestamp = os.clock()
                    }
                end
            },

            -- 回合/波次事件
            ['回合-开始'] = {
                bus_event = event_bus.events.WAVE_START,
                transform = function(round)
                    return {
                        round = round,
                        timestamp = os.clock()
                    }
                end
            },

            ['回合-结束'] = {
                bus_event = event_bus.events.WAVE_END,
                transform = function(round)
                    return {
                        round = round,
                        timestamp = os.clock()
                    }
                end
            }
        })

        return bridge
    end

    -- 初始化 Y3 事件包装
    wrap_y3_game_event()

    -- 返回适配器 API
    return {
        bridge = setup_default_event_bridge(),           -- 默认事件桥接器
        subscribe = create_subscribe_helpers(),          -- 便捷订阅辅助函数
        
        -- === 调试方法 ===
        get_y3_event_cache = function()
            return y3_game_event_cache
        end,
        
        is_initialized = function()
            return is_initialized
        end,

        -- === 工厂方法 ===
        create_event_bridge = create_event_bridge,       -- 创建自定义事件桥接器
        create_subscribe_helpers = create_subscribe_helpers  -- 创建订阅辅助函数
    }
end

return M
