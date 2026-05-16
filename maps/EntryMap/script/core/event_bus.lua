
--[[
    事件总线 (Event Bus)
    提供发布/订阅模式的事件系统，支持中间件、一次性订阅等功能
    
    使用方式:
        local EventBus = require 'core.event_bus'
        local bus = EventBus.create({ debug = true })
        
        -- 订阅事件
        local unsubscribe = bus.on('player.join', function(payload)
            print('Player joined:', payload.name)
        end)
        
        -- 一次性订阅
        bus.once('game.start', function()
            print('Game started!')
        end)
        
        -- 发布事件
        bus.publish('player.join', { name = 'Alice' })
        
        -- 使用预定义事件
        bus.on(bus.events.WAVE_START, function(data)
            print('Wave started:', data.wave_index)
        end)
        
        -- 注册中间件
        bus.register_middleware(function(event_name, payload, next)
            print('Before event:', event_name)
            local result = next()
            print('After event:', event_name)
            return result
        end)
]]

local M = {}

---
-- 创建事件总线实例
-- @param options table 配置选项
-- @param options.debug boolean 是否启用调试模式（输出事件日志）
-- @param options.error_handler table ErrorHandler实例（可选）
-- @return table 事件总线实例
---
function M.create(options)
    options = options or {}
    
    -- 事件处理器存储
    local handlers = {}           -- 普通事件处理器
    local once_handlers = {}      -- 一次性事件处理器
    local global_middlewares = {} -- 全局中间件
    
    -- 错误处理器（如果未提供，使用降级方案）
    local error_handler = options.error_handler
    local logger = error_handler and error_handler.logger('EventBus')
    
    ---
    -- 验证事件名称
    -- @param name string 事件名称
    -- @return string 验证后的事件名称
    ---
    local function validate_event_name(name)
        if type(name) ~= 'string' or name == '' then
            error('Event name must be a non-empty string')
        end
        return name
    end
    
    ---
    -- 执行中间件链
    -- @param event_name string 事件名称
    -- @param payload any 事件负载
    -- @param handler function 最终处理器
    -- @return any 处理器返回值
    ---
    local function invoke_middlewares(event_name, payload, handler)
        local index = 1
        local function next_middleware()
            -- 如果中间件全部执行完毕，调用最终处理器
            if index > #global_middlewares then
                return handler(payload)
            end
            
            -- 获取当前中间件并执行
            local middleware = global_middlewares[index]
            index = index + 1
            
            -- 安全执行中间件，出错时跳过继续执行
            local result
            if error_handler then
                result = error_handler.safe_call(middleware, event_name, payload, next_middleware)
                if not result.success then
                    if logger then logger.error(string.format('Middleware error for "%s": %s', event_name, result.error)) end
                    return next_middleware()
                end
                result = result.value
            else
                -- 降级到 pcall
                local ok, err = pcall(middleware, event_name, payload, next_middleware)
                if not ok then
                    print(string.format('[EventBus] Middleware error for "%s": %s', event_name, err))
                    return next_middleware()
                end
                result = err
            end
            return result
        end
        
        return next_middleware()
    end
    
    ---
    -- 通知所有事件处理器
    -- @param event_name string 事件名称
    -- @param payload any 事件负载
    ---
    local function notify_handlers(event_name, payload)
        local event_handlers = handlers[event_name] or {}
        local event_once_handlers = once_handlers[event_name] or {}
        
        -- 清空一次性处理器（它们只执行一次）
        once_handlers[event_name] = {}
        
        -- 执行普通处理器
        for _, handler in ipairs(event_handlers) do
            if error_handler then
                local result = error_handler.safe_call(function()
                    invoke_middlewares(event_name, payload, handler)
                end)
                if not result.success then
                    if logger then logger.error(string.format('Handler error for "%s": %s', event_name, result.error)) end
                end
            else
                -- 降级到 pcall
                local ok, err = pcall(function()
                    invoke_middlewares(event_name, payload, handler)
                end)
                if not ok then
                    print(string.format('[EventBus] Handler error for "%s": %s', event_name, err))
                end
            end
        end
        
        -- 执行一次性处理器
        for _, handler in ipairs(event_once_handlers) do
            if error_handler then
                local result = error_handler.safe_call(function()
                    invoke_middlewares(event_name, payload, handler)
                end)
                if not result.success then
                    if logger then logger.error(string.format('Once handler error for "%s": %s', event_name, result.error)) end
                end
            else
                -- 降级到 pcall
                local ok, err = pcall(function()
                    invoke_middlewares(event_name, payload, handler)
                end)
                if not ok then
                    print(string.format('[EventBus] Once handler error for "%s": %s', event_name, err))
                end
            end
        end
    end
    
    ---
    -- 订阅事件
    -- @param event_name string 事件名称
    -- @param handler function 事件处理器
    -- @param options table 选项
    -- @param options.once boolean 是否为一次性订阅
    -- @return function 取消订阅函数
    ---
    local function subscribe(event_name, handler, options)
        validate_event_name(event_name)
        
        -- 验证处理器类型
        if type(handler) ~= 'function' then
            error('Handler must be a function')
        end
        
        options = options or {}
        
        -- 选择处理器存储（普通或一次性）
        local target_handlers = options.once and once_handlers or handlers
        
        -- 创建事件处理器列表
        if not target_handlers[event_name] then
            target_handlers[event_name] = {}
        end
        
        -- 添加处理器
        table.insert(target_handlers[event_name], handler)
        
        -- 返回取消订阅函数
        return function()
            unsubscribe(event_name, handler, options.once)
        end
    end
    
    ---
    -- 取消订阅
    -- @param event_name string 事件名称
    -- @param handler function 要移除的处理器
    -- @param is_once boolean 是否为一次性处理器
    ---
    local function unsubscribe(event_name, handler, is_once)
        validate_event_name(event_name)
        local target_handlers = is_once and once_handlers or handlers
        
        local event_handlers = target_handlers[event_name]
        if not event_handlers then return end
        
        -- 查找并移除处理器
        for i, h in ipairs(event_handlers) do
            if h == handler then
                table.remove(event_handlers, i)
                break
            end
        end
    end
    
    ---
    -- 发布事件（同步）
    -- @param event_name string 事件名称
    -- @param payload any 事件负载
    ---
    local function publish(event_name, payload)
        validate_event_name(event_name)
        
        -- 调试模式下输出日志
        if options.debug then
            print(string.format('[EventBus] Publishing "%s" with payload: %s', 
                event_name, type(payload) == 'table' and require('inspect')(payload) or tostring(payload)))
        end
        
        -- 通知所有处理器
        notify_handlers(event_name, payload)
    end
    
    ---
    -- 发布事件（异步）
    -- 使用 y3.ltimer.wait(0) 实现异步执行
    -- @param event_name string 事件名称
    -- @param payload any 事件负载
    ---
    local function publish_async(event_name, payload)
        validate_event_name(event_name)
        
        if y3 and y3.ltimer and y3.ltimer.wait then
            y3.ltimer.wait(0, function()
                notify_handlers(event_name, payload)
            end)
        else
            -- 回退到同步执行
            notify_handlers(event_name, payload)
        end
    end
    
    ---
    -- 注册全局中间件
    -- 中间件可以在事件处理前后执行逻辑
    -- @param middleware function 中间件函数，签名: (event_name, payload, next)
    ---
    local function register_middleware(middleware)
        if type(middleware) ~= 'function' then
            error('Middleware must be a function')
        end
        table.insert(global_middlewares, middleware)
    end
    
    ---
    -- 获取事件处理器数量
    -- @param event_name string 事件名称
    -- @return number 处理器总数
    ---
    local function get_handler_count(event_name)
        local regular_count = #(handlers[event_name] or {})
        local once_count = #(once_handlers[event_name] or {})
        return regular_count + once_count
    end
    
    ---
    -- 清空事件处理器
    -- @param event_name string 可选，指定事件名称，不传则清空所有
    ---
    local function clear(event_name)
        if event_name then
            validate_event_name(event_name)
            handlers[event_name] = nil
            once_handlers[event_name] = nil
        else
            handlers = {}
            once_handlers = {}
        end
    end
    
    -- 返回事件总线 API
    return {
        -- === 订阅相关 ===
        subscribe = subscribe,     -- 订阅事件
        unsubscribe = unsubscribe, -- 取消订阅
        
        -- === 便捷订阅方法 ===
        on = subscribe,            -- 订阅事件（同 subscribe）
        once = function(event_name, handler)
            ---
            -- 一次性订阅（只触发一次）
            -- @param event_name string 事件名称
            -- @param handler function 事件处理器
            -- @return function 取消订阅函数
            ---
            return subscribe(event_name, handler, { once = true })
        end,
        
        -- === 发布相关 ===
        publish = publish,         -- 发布事件（同步）
        emit = publish,            -- 别名：发布事件
        trigger = publish,         -- 别名：触发事件
        
        publish_async = publish_async, -- 发布事件（异步）
        emit_async = publish_async,   -- 别名：异步发布
        
        -- === 中间件 ===
        register_middleware = register_middleware,
        
        -- === 工具方法 ===
        get_handler_count = get_handler_count,
        clear = clear,
        
        -- === 预定义事件常量 ===
        events = {
            BATTLE_START = 'battle.start',       -- 战斗开始
            BATTLE_END = 'battle.end',           -- 战斗结束
            WAVE_START = 'wave.start',           -- 波次开始
            WAVE_END = 'wave.end',               -- 波次结束
            ENEMY_KILL = 'enemy.kill',           -- 敌人击杀
            HERO_HURT = 'hero.hurt',             -- 英雄受伤
            HERO_HEAL = 'hero.heal',             -- 英雄治疗
            SKILL_CAST = 'skill.cast',           -- 技能释放
            REWARD_GRANTED = 'reward.granted',   -- 奖励发放
            CHOICE_MADE = 'choice.made',         -- 选择完成
            CHALLENGE_START = 'challenge.start', -- 挑战开始
            CHALLENGE_END = 'challenge.end'      -- 挑战结束
        }
    }
end

---
-- 创建对象装饰器
-- 自动为对象的方法调用发布事件
-- @param event_bus table 事件总线实例
-- @return function 装饰器函数
---
function M.create_decorator(event_bus)
    return function(target)
        local original = target
        
        return setmetatable({}, {
            __index = function(_, key)
                local value = original[key]
                if type(value) == 'function' then
                    return function(...)
                        local result = {value(...)}
                        event_bus.publish('method.call', {
                            object = tostring(target),
                            method = key,
                            args = {...}
                        })
                        return unpack(result)
                    end
                end
                return value
            end
        })
    end
end

return M
