
--[[
    Core 模块初始化器
    负责初始化所有核心系统并提供统一的访问接口
    
    使用方式:
        local Core = require 'core.init'
        Core.initialize({
            log_level = 'DEBUG',
            strict_config = false,
            debug_events = true
        })
        
        -- 获取服务
        local container = Core.get_container()
        local event_bus = Core.get_event_bus()
        local config = Core.get_config()
        local logger = Core.get_logger('MyModule')
]]

local M = {}

-- 导入核心模块
local DI = require 'core.di_container'
local EventBus = require 'core.event_bus'
local EventBusAdapter = require 'core.event_bus_adapter'
local EventSubscriber = require 'core.event_subscriber'
local ConfigManager = require 'core.config_manager'
local ConfigLoader = require 'core.config_loader'
local ErrorHandler = require 'core.error_handler'

-- 全局单例实例
local container = nil           -- 依赖注入容器
local event_bus = nil           -- 事件总线
local event_bus_adapter = nil   -- 事件总线适配器（兼容旧API）
local event_subscriber = nil    -- 事件订阅器
local config = nil              -- 配置管理器
local config_loader = nil       -- 配置加载器
local error_handler = nil       -- 错误处理器

---
-- 初始化核心系统
-- @param options table 初始化选项
-- @param options.log_level string 日志级别 'DEBUG' | 'INFO' | 'WARN' | 'ERROR'
-- @param options.strict_config boolean 是否启用严格配置模式
-- @param options.debug_events boolean 是否启用事件调试
-- @param options.log_to_file boolean 是否输出日志到文件
-- @param options.enable_trace boolean 是否启用错误追踪
-- @return table 包含所有核心服务的对象
---
function M.initialize(options)
    options = options or {}
    
    -- 1. 初始化错误处理器（最先初始化，其他模块依赖它）
    error_handler = ErrorHandler.create({
        log_level = options.log_level or (y3 and y3.game and y3.game.is_debug_mode and y3.game.is_debug_mode() and 'DEBUG' or 'INFO'),
        log_to_file = options.log_to_file or false,
        enable_trace = options.enable_trace ~= false
    })
    
    -- 创建核心日志器
    local logger = error_handler.logger('Core')
    
    logger.info('Initializing core systems...')
    
    -- 2. 初始化依赖注入容器（传入错误处理器）
    container = DI.create({
        error_handler = error_handler
    })
    
    -- 3. 初始化事件总线（传入错误处理器）
    event_bus = EventBus.create({
        debug = options.debug_events or false,
        error_handler = error_handler
    })
    
    -- 4. 初始化事件总线适配器（传入错误处理器）和订阅器
    event_bus_adapter = EventBusAdapter.create(event_bus, {
        error_handler = error_handler
    })
    event_subscriber = EventSubscriber.create(event_bus)
    
    -- 5. 初始化配置管理系统
    config = ConfigManager.create({
        strict = options.strict_config or false
    })
    
    -- 6. 初始化配置加载器（注入错误处理器）
    config_loader = ConfigLoader.create(config, error_handler)
    
    -- 7. 注册所有核心服务到DI容器
    container.register_instance('event_bus', event_bus)
    container.register_instance('event_bus_adapter', event_bus_adapter)
    container.register_instance('event_subscriber', event_subscriber)
    container.register_instance('config', config)
    container.register_instance('config_loader', config_loader)
    container.register_instance('error_handler', error_handler)
    
    logger.info('Registering core services...')
    
    -- 8. 注册便捷服务
    container.register('logger', function()
        return function(name)
            return error_handler.logger(name)
        end
    end, { singleton = true })
    
    container.register('safe_call', function()
        return error_handler.safe_call
    end, { singleton = true })
    
    logger.info('Core systems initialized')
    
    -- 返回所有核心服务的引用
    return {
        container = container,
        event_bus = event_bus,
        event_bus_adapter = event_bus_adapter,
        event_subscriber = event_subscriber,
        config = config,
        config_loader = config_loader,
        error_handler = error_handler
    }
end

---
-- 获取依赖注入容器
-- @return DI 容器实例
---
function M.get_container()
    if not container then
        error('Core not initialized. Call initialize() first.')
    end
    return container
end

---
-- 获取事件总线
-- @return EventBus 实例
---
function M.get_event_bus()
    if not event_bus then
        error('Core not initialized. Call initialize() first.')
    end
    return event_bus
end

---
-- 获取事件总线适配器
-- @return EventBusAdapter 实例
---
function M.get_event_bus_adapter()
    if not event_bus_adapter then
        error('Core not initialized. Call initialize() first.')
    end
    return event_bus_adapter
end

---
-- 获取事件订阅器
-- @return EventSubscriber 实例
---
function M.get_event_subscriber()
    if not event_subscriber then
        error('Core not initialized. Call initialize() first.')
    end
    return event_subscriber
end

---
-- 获取配置加载器
-- @return ConfigLoader 实例
---
function M.get_config_loader()
    if not config_loader then
        error('Core not initialized. Call initialize() first.')
    end
    return config_loader
end

---
-- 获取配置管理器
-- @return ConfigManager 实例
---
function M.get_config()
    if not config then
        error('Core not initialized. Call initialize() first.')
    end
    return config
end

---
-- 获取错误处理器
-- @return ErrorHandler 实例
---
function M.get_error_handler()
    if not error_handler then
        error('Core not initialized. Call initialize() first.')
    end
    return error_handler
end

---
-- 获取日志器
-- @param name string 模块名称
-- @return Logger 实例
---
function M.get_logger(name)
    if not error_handler then
        error('Core not initialized. Call initialize() first.')
    end
    return error_handler.logger(name)
end

-- 导出核心模块类（供扩展使用）
M.DI = DI
M.EventBus = EventBus
M.ConfigManager = ConfigManager
M.ErrorHandler = ErrorHandler

return M
