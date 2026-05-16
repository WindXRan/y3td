
--[[
    依赖注入容器 (Dependency Injection Container)
    提供服务注册、解析和依赖注入功能
    
    使用方式:
        local DI = require 'core.di_container'
        local container = DI.create()
        
        -- 注册服务
        container.register('logger', function()
            return { info = function(msg) print(msg) end }
        end, { singleton = true })
        
        -- 注册实例
        container.register_instance('config', { debug = true })
        
        -- 获取服务
        local logger = container.get('logger')
        logger.info('Hello')
        
        -- 依赖注入
        local my_module = container.factory({'logger', 'config'}, function(logger, config)
            return {
                start = function() logger.info('Started with config:', config) end
            }
        end)
]]

local M = {}

---
-- 创建服务注册表
-- 内部函数，管理服务的注册和生命周期
-- @param error_handler table ErrorHandler实例（可选）
-- @return table 服务注册表对象
---
local function create_service_registry(error_handler)
    local services = {}   -- 服务元数据
    local singletons = {} -- 单例实例缓存
    local factories = {}  -- 工厂函数缓存
    local logger = error_handler and error_handler.logger('DI')
    
    ---
    -- 获取服务实例
    -- @param name string 服务名称
    -- @return any 服务实例
    ---
    local function get_service(name)
        -- 如果已缓存单例，直接返回
        if singletons[name] then
            return singletons[name]
        end
        
        -- 获取工厂函数
        local factory = factories[name]
        if not factory then
            error(string.format('Service "%s" not registered', name))
        end
        
        -- 创建实例并缓存（如果是单例）
        local instance = factory()
        singletons[name] = instance
        return instance
    end
    
    ---
    -- 注册服务
    -- @param name string 服务名称
    -- @param factory function 服务工厂函数
    -- @param options table 选项
    -- @param options.singleton boolean 是否为单例（默认 true）
    -- @param options.auto_instantiate boolean 是否立即实例化
    ---
    local function register(name, factory, options)
        options = options or {}
        
        -- 检查是否已注册
        if services[name] then
            error(string.format('Service "%s" already registered', name))
        end
        
        -- 保存服务元数据
        services[name] = {
            name = name,
            factory = factory,
            singleton = options.singleton ~= false -- 默认单例
        }
        
        -- 如果设置了自动实例化，则立即创建
        if options.singleton == true and options.auto_instantiate then
            singletons[name] = factory()
        end
        
        -- 缓存工厂函数
        factories[name] = factory
    end
    
    ---
    -- 注册已存在的实例
    -- @param name string 服务名称
    -- @param instance any 服务实例
    ---
    local function register_instance(name, instance)
        -- 检查是否已注册
        if services[name] then
            error(string.format('Service "%s" already registered', name))
        end
        
        -- 保存实例
        services[name] = {
            name = name,
            singleton = true
        }
        singletons[name] = instance
        factories[name] = function() return instance end
    end
    
    ---
    -- 注销服务
    -- @param name string 服务名称
    ---
    local function unregister(name)
        services[name] = nil
        singletons[name] = nil
        factories[name] = nil
    end
    
    ---
    -- 检查服务是否已注册
    -- @param name string 服务名称
    -- @return boolean 是否已注册
    ---
    local function has_service(name)
        return services[name] ~= nil
    end
    
    ---
-- 重置注册表（清理所有服务）
---
    local function reset()
        -- 尝试调用服务的 dispose 方法进行清理
        for name in pairs(singletons) do
            local service = services[name]
            if service and service.dispose then
                if error_handler then
                    local result = error_handler.safe_call(service.dispose)
                    if not result.success then
                        if logger then logger.warn(string.format('Error disposing service "%s": %s', name, result.error)) end
                    end
                else
                    -- 降级到 pcall
                    local ok, err = pcall(service.dispose)
                    if not ok then
                        print(string.format('[DI] Error disposing service "%s": %s', name, err))
                    end
                end
            end
        end
        services = {}
        singletons = {}
        factories = {}
    end
    
    -- 返回注册表 API
    return {
        get = get_service,
        register = register,
        register_instance = register_instance,
        unregister = unregister,
        has = has_service,
        reset = reset,
        list = function() return services end
    }
end

---
-- 创建依赖注入器
-- 内部函数，提供依赖解析和注入功能
-- @param registry table 服务注册表
-- @return table 注入器对象
---
local function create_injector(registry)
    ---
    -- 同步注入依赖
    -- @param dependencies table 依赖名称列表
    -- @param callback function 回调函数，接收解析后的依赖作为参数
    -- @return any 回调函数的返回值
    ---
    local function inject(dependencies, callback)
        local resolved = {}
        for _, dep_name in ipairs(dependencies) do
            resolved[#resolved + 1] = registry.get(dep_name)
        end
        return callback(unpack(resolved))
    end
    
    ---
    -- 异步注入依赖（延迟执行）
    -- 返回一个函数，调用时会自动注入依赖
    -- @param dependencies table 依赖名称列表
    -- @param callback function 回调函数
    -- @return function 包装后的函数
    ---
    local function inject_async(dependencies, callback)
        local resolved = {}
        for _, dep_name in ipairs(dependencies) do
            resolved[#resolved + 1] = registry.get(dep_name)
        end
        return function(...)
            return callback(unpack(resolved), ...)
        end
    end
    
    -- 返回注入器 API
    return {
        inject = inject,
        inject_async = inject_async
    }
end

---
-- 创建依赖注入容器
-- @param options table 配置选项（可选）
-- @param options.error_handler table ErrorHandler实例（可选）
-- @return table DI容器实例
---
function M.create(options)
    options = options or {}
    local error_handler = options.error_handler
    local registry = create_service_registry(error_handler)
    local injector = create_injector(registry)
    
    return {
        -- === Registry API ===
        register = registry.register,           -- 注册服务工厂
        register_instance = registry.register_instance, -- 注册实例
        unregister = registry.unregister,       -- 注销服务
        has = registry.has,                     -- 检查服务是否存在
        get = registry.get,                     -- 获取服务实例
        reset = registry.reset,                 -- 重置容器
        list = registry.list,                   -- 获取所有服务列表
        
        -- === Injector API ===
        inject = injector.inject,               -- 同步注入依赖
        inject_async = injector.inject_async,   -- 异步注入依赖
        
        -- === Decorator API ===
        decorate = function(name, decorator)
            ---
            -- 装饰器模式：包装现有服务
            -- @param name string 服务名称
            -- @param decorator function 装饰函数，接收原实例并返回新实例
            ---
            local original = registry.get(name)
            registry.register_instance(name, decorator(original))
        end,
        
        -- === Factory Helper ===
        factory = function(dependencies, constructor)
            ---
            -- 创建工厂函数，自动注入依赖
            -- @param dependencies table 依赖列表
            -- @param constructor function 构造函数，接收依赖作为参数
            -- @return function 工厂函数
            ---
            return function()
                return injector.inject(dependencies, constructor)
            end
        end
    }
end

---
-- 创建模块注册器
-- 方便批量注册模块及其依赖
-- @param name string 模块名称
-- @param dependencies table 依赖列表
-- @param module_def function 模块定义函数
-- @return function 模块注册函数，接收容器作为参数
---
function M.create_module(name, dependencies, module_def)
    return function(container)
        local resolved_deps = {}
        for _, dep_name in ipairs(dependencies) do
            resolved_deps[#resolved_deps + 1] = container.get(dep_name)
        end
        local module_instance = module_def(unpack(resolved_deps))
        container.register_instance(name, module_instance)
        return module_instance
    end
end

return M
