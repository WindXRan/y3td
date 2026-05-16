
--[[
    错误处理器 (Error Handler)
    提供统一的错误处理、日志记录和安全调用功能
    
    使用方式:
        local ErrorHandler = require 'core.error_handler'
        local error_handler = ErrorHandler.create({
            log_level = 'DEBUG',
            log_to_file = true,
            enable_trace = true
        })
        
        -- 创建模块日志器
        local logger = error_handler.logger('MyModule')
        logger.info('Hello World')
        logger.warn('Something might be wrong')
        logger.error('Something went wrong')
        
        -- 安全调用
        local result = error_handler.safe_call(function()
            return risky_operation()
        end)
        if not result.success then
            logger.error('Operation failed:', result.error)
        end
        
        -- 断言
        error_handler.assert(something ~= nil, 'Something cannot be nil')
        error_handler.assert_type(value, 'table', 'value')
]]

local M = {}

-- 日志级别常量
local LOG_LEVELS = {
    DEBUG = 1,  -- 调试信息
    INFO = 2,   -- 常规信息
    WARN = 3,   -- 警告信息
    ERROR = 4,  -- 错误信息
    FATAL = 5   -- 致命错误
}

-- 日志级别名称映射
local LOG_LEVEL_NAMES = {
    [1] = 'DEBUG',
    [2] = 'INFO',
    [3] = 'WARN',
    [4] = 'ERROR',
    [5] = 'FATAL'
}

---
-- 创建错误处理器实例
-- @param options table 配置选项
-- @param options.log_level string 日志级别 'DEBUG' | 'INFO' | 'WARN' | 'ERROR' | 'FATAL'
-- @param options.log_to_file boolean 是否输出日志到文件
-- @param options.log_file_path string 日志文件路径
-- @param options.enable_trace boolean 是否启用错误追踪
-- @return table 错误处理器实例
---
function M.create(options)
    options = options or {}
    
    -- 配置参数
    local log_level = LOG_LEVELS[(options.log_level or 'INFO'):upper()] or LOG_LEVELS.INFO
    local log_to_file = options.log_to_file or false
    local log_file_path = options.log_file_path or 'game.log'
    local enable_trace = options.enable_trace ~= false
    local error_handlers = {}  -- 全局错误处理器列表
    
    ---
    -- 获取当前时间戳
    -- @return string 格式化的时间戳
    ---
    local function get_timestamp()
        local now = os.date('*t')
        return string.format('%04d-%02d-%02d %02d:%02d:%02d',
            now.year, now.month, now.day, now.hour, now.min, now.sec)
    end
    
    ---
    -- 写入日志
    -- @param level number 日志级别
    -- @param message string 日志消息
    -- @param context table 上下文信息（可选）
    ---
    local function write_log(level, message, context)
        -- 如果日志级别低于设置的级别，不输出
        if level < log_level then return end
        
        local timestamp = get_timestamp()
        local level_name = LOG_LEVEL_NAMES[level]
        local log_line = string.format('[%s] [%s] %s', timestamp, level_name, message)
        
        -- 添加上下文信息
        if context and type(context) == 'table' and next(context) then
            local context_str = ''
            for k, v in pairs(context) do
                if type(v) == 'string' then
                    context_str = context_str .. string.format(' %s="%s"', k, v)
                else
                    context_str = context_str .. string.format(' %s=%s', k, tostring(v))
                end
            end
            log_line = log_line .. context_str
        end
        
        -- 输出到控制台
        print(log_line)
        
        -- 如果启用了文件日志，写入文件
        if log_to_file then
            local file = io.open(log_file_path, 'a')
            if file then
                file:write(log_line .. '\n')
                file:close()
            end
        end
    end
    
    ---
    -- 创建日志器（带前缀）
    -- @param prefix string 日志前缀（模块名称）
    -- @return table 日志器对象
    ---
    local function create_logger(prefix)
        return {
            debug = function(msg, context)
                write_log(LOG_LEVELS.DEBUG, prefix and ('[' .. prefix .. '] ' .. msg) or msg, context)
            end,
            info = function(msg, context)
                write_log(LOG_LEVELS.INFO, prefix and ('[' .. prefix .. '] ' .. msg) or msg, context)
            end,
            warn = function(msg, context)
                write_log(LOG_LEVELS.WARN, prefix and ('[' .. prefix .. '] ' .. msg) or msg, context)
            end,
            error = function(msg, context)
                write_log(LOG_LEVELS.ERROR, prefix and ('[' .. prefix .. '] ' .. msg) or msg, context)
            end,
            fatal = function(msg, context)
                write_log(LOG_LEVELS.FATAL, prefix and ('[' .. prefix .. '] ' .. msg) or msg, context)
            end
        }
    end
    
    ---
    -- 处理错误
    -- @param err any 错误信息
    -- @param context table 上下文信息
    -- @return table 错误信息对象
    ---
    local function handle_error(err, context)
        local error_info = {
            message = tostring(err),
            trace = enable_trace and debug.traceback() or nil,
            context = context or {},
            timestamp = get_timestamp()
        }
        
        -- 记录错误日志
        write_log(LOG_LEVELS.ERROR, 'Unhandled error: ' .. err, context)
        
        -- 通知所有注册的错误处理器
        for _, handler in ipairs(error_handlers) do
            pcall(handler, error_info)
        end
        
        return error_info
    end
    
    ---
    -- 安全调用（带错误处理）
    -- 使用 xpcall 包裹函数调用，自动处理错误
    -- @param callback function 要执行的函数
    -- @param ... any 函数参数
    -- @return table 结果对象 { success = boolean, value = any, error = any }
    ---
    local function safe_call(callback, ...)
        local args = {...}
        local ok, result = xpcall(function()
            return callback(unpack(args))
        end, function(err)
            return handle_error(err, {
                function_name = tostring(callback),
                args = args
            })
        end)
        
        if ok then
            return {
                success = true,
                value = result
            }
        else
            return {
                success = false,
                error = result
            }
        end
    end
    
    ---
    -- 安全调用（返回结果和错误分离）
    -- @param callback function 要执行的函数
    -- @param ... any 函数参数
    -- @return any, any 结果和错误
    ---
    local function safe_call_with_result(callback, ...)
        local result = safe_call(callback, ...)
        if not result.success then
            return nil, result.error
        end
        return result.value, nil
    end
    
    ---
    -- 尝试调用（带降级）
    -- @param callback function 要执行的函数
    -- @param fallback any 降级值或函数
    -- @param ... any 函数参数
    -- @return any 结果或降级值
    ---
    local function try_call(callback, fallback, ...)
        local ok, result = pcall(callback, ...)
        if not ok then
            if type(fallback) == 'function' then
                return fallback(result)
            end
            return fallback
        end
        return result
    end
    
    ---
    -- 注册全局错误处理器
    -- @param handler function 错误处理函数
    -- @return number 处理器索引
    ---
    local function register_error_handler(handler)
        if type(handler) ~= 'function' then
            error('Handler must be a function')
        end
        table.insert(error_handlers, handler)
        return #error_handlers
    end
    
    ---
    -- 注销全局错误处理器
    -- @param index number 处理器索引
    ---
    local function unregister_error_handler(index)
        table.remove(error_handlers, index)
    end
    
    ---
    -- 设置日志级别
    -- @param level string 日志级别
    -- @return boolean 是否设置成功
    ---
    local function set_log_level(level)
        local new_level = LOG_LEVELS[(level or 'INFO'):upper()]
        if new_level then
            log_level = new_level
            return true
        end
        return false
    end
    
    ---
    -- 断言条件
    -- @param condition boolean 条件
    -- @param message string 错误消息
    ---
    local function assert_that(condition, message)
        if not condition then
            error(message or 'Assertion failed')
        end
    end
    
    ---
    -- 断言类型
    -- @param value any 要检查的值
    -- @param expected_type string 期望的类型
    -- @param name string 值的名称（用于错误消息）
    ---
    local function assert_type(value, expected_type, name)
        if type(value) ~= expected_type then
            error(string.format('Expected "%s" to be %s, got %s', 
                name or 'value', expected_type, type(value)))
        end
    end
    
    ---
    -- 断言非空
    -- @param value any 要检查的值
    -- @param name string 值的名称（用于错误消息）
    ---
    local function assert_not_nil(value, name)
        if value == nil then
            error(string.format('"%s" cannot be nil', name or 'value'))
        end
    end
    
    -- 返回错误处理器 API
    return {
        -- === 直接日志方法 ===
        debug = function(msg, context) write_log(LOG_LEVELS.DEBUG, msg, context) end,
        info = function(msg, context) write_log(LOG_LEVELS.INFO, msg, context) end,
        warn = function(msg, context) write_log(LOG_LEVELS.WARN, msg, context) end,
        error = function(msg, context) write_log(LOG_LEVELS.ERROR, msg, context) end,
        fatal = function(msg, context) write_log(LOG_LEVELS.FATAL, msg, context) end,
        
        -- === 日志器创建 ===
        logger = create_logger,
        
        -- === 错误处理 ===
        handle_error = handle_error,
        safe_call = safe_call,
        safe_call_with_result = safe_call_with_result,
        try_call = try_call,
        
        -- === 错误处理器管理 ===
        register_error_handler = register_error_handler,
        unregister_error_handler = unregister_error_handler,
        
        -- === 日志级别控制 ===
        set_log_level = set_log_level,
        get_log_level = function() return LOG_LEVEL_NAMES[log_level] end,
        
        -- === 断言 ===
        assert = assert_that,
        assert_type = assert_type,
        assert_not_nil = assert_not_nil,
        
        -- === 函数包装 ===
        wrap = function(callback, context)
            ---
            -- 包装函数，自动安全调用
            -- @param callback function 要包装的函数
            -- @param context table 上下文信息
            -- @return function 包装后的函数
            ---
            return function(...)
                return safe_call(callback, ...)
            end
        end
    }
end

---
-- 创建错误对象
-- @param message string 错误消息
-- @param code string 错误代码
-- @param context table 上下文信息
-- @return table 错误对象
---
function M.create_error(message, code, context)
    return setmetatable({
        message = message,
        code = code,
        context = context or {},
        is_error = true
    }, {
        __tostring = function(self)
            return string.format('Error [%s]: %s', self.code or 'UNKNOWN', self.message)
        end
    })
end

---
-- 检查是否为错误对象
-- @param value any 要检查的值
-- @return boolean 是否为错误对象
---
function M.is_error(value)
    return type(value) == 'table' and value.is_error == true
end

return M
