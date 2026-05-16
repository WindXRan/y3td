
--[[
    配置管理器 (Config Manager)
    提供中心化的配置管理，支持命名空间、Schema验证、多源加载
    
    使用方式:
        local ConfigManager = require 'core.config_manager'
        local config = ConfigManager.create({ strict = true })
        
        -- 设置配置
        config.set('game.max_enemies', 40)
        config.set('hero.health', 100)
        
        -- 获取配置
        local max_enemies = config.get('game.max_enemies')
        local health = config.get('hero.health', 100)  -- 带默认值
        
        -- 加载配置表
        config.load_from_table('game', {
            max_enemies = 40,
            debug_mode = true
        })
        
        -- 加载Lua模块
        config.load_from_lua('data.game_tables', 'game_tables')
        
        -- 使用Schema验证
        config.register_schema('game', {
            max_enemies = { type = 'number', min = 1, required = true },
            debug_mode = { type = 'boolean' }
        })
        local valid, errors = config.validate_namespace('game')
]]

local M = {}

---
-- 创建配置管理器实例
-- @param options table 配置选项
-- @param options.strict boolean 是否启用严格模式（验证失败时抛出错误）
-- @return table 配置管理器实例
---
function M.create(options)
    options = options or {}
    
    -- 配置存储
    local config_store = {}   -- 配置数据 { namespace = { key = value } }
    local schema_store = {}  -- Schema定义 { namespace = { field = schema } }
    local sources = {}       -- 来源记录 { namespace = { type, path } }
    
    ---
    -- 验证配置值
    -- @param key string 配置键名
    -- @param value any 配置值
    -- @param schema table Schema定义
    -- @return boolean, string 是否验证通过，错误信息
    ---
    local function validate_config(key, value, schema)
        if not schema then return true, nil end
        
        -- 类型验证
        if schema.type then
            if type(value) ~= schema.type then
                return false, string.format('Expected type "%s" for "%s", got "%s"', 
                    schema.type, key, type(value))
            end
        end
        
        -- 最小值验证
        if schema.min and type(value) == 'number' and value < schema.min then
            return false, string.format('Value for "%s" is below minimum (%s < %s)', 
                key, value, schema.min)
        end
        
        -- 最大值验证
        if schema.max and type(value) == 'number' and value > schema.max then
            return false, string.format('Value for "%s" is above maximum (%s > %s)', 
                key, value, schema.max)
        end
        
        -- 枚举值验证
        if schema.enum and not schema.enum[value] then
            return false, string.format('Value "%s" for "%s" is not in allowed values', 
                tostring(value), key)
        end
        
        -- 必填验证
        if schema.required and value == nil then
            return false, string.format('Required config "%s" is missing', key)
        end
        
        -- 自定义验证函数
        if schema.validate and type(schema.validate) == 'function' then
            local ok, err = schema.validate(value)
            if not ok then
                return false, string.format('Validation failed for "%s": %s', key, err)
            end
        end
        
        return true, nil
    end
    
    ---
    -- 在命名空间内设置配置
    -- @param namespace string 命名空间
    -- @param key string 配置键
    -- @param value any 配置值
    -- @param schema table Schema定义（可选）
    -- @return boolean 是否设置成功
    ---
    local function set_with_namespace(namespace, key, value, schema)
        -- 创建命名空间（如果不存在）
        if not config_store[namespace] then
            config_store[namespace] = {}
        end
        
        -- 如果提供了Schema，进行验证
        if schema then
            local ok, err = validate_config(key, value, schema)
            if not ok then
                print(string.format('[ConfigManager] Validation error in "%s.%s": %s', 
                    namespace, key, err))
                if options.strict then
                    error(err)
                end
                return false
            end
        end
        
        -- 设置配置值
        config_store[namespace][key] = value
        return true
    end
    
    ---
    -- 在命名空间内获取配置
    -- @param namespace string 命名空间
    -- @param key string 配置键
    -- @param default any 默认值
    -- @return any 配置值
    ---
    local function get_with_namespace(namespace, key, default)
        if not config_store[namespace] then
            return default
        end
        local value = config_store[namespace][key]
        return value ~= nil and value or default
    end
    
    ---
    -- 从表加载配置
    -- @param namespace string 命名空间
    -- @param data table 配置数据
    -- @param schema table Schema定义（可选）
    -- @return boolean, table 是否加载成功，错误列表
    ---
    local function load_from_table(namespace, data, schema)
        if not namespace or namespace == '' then
            error('Namespace is required')
        end
        
        -- 创建命名空间（如果不存在）
        if not config_store[namespace] then
            config_store[namespace] = {}
        end
        
        local errors = {}
        
        -- 遍历数据并验证
        for key, value in pairs(data) do
            local field_schema = schema and schema[key]
            local ok, err = validate_config(key, value, field_schema)
            if not ok then
                table.insert(errors, string.format('%s.%s: %s', namespace, key, err))
            else
                config_store[namespace][key] = value
            end
        end
        
        -- 严格模式下，验证失败抛出错误
        if #errors > 0 and options.strict then
            error(table.concat(errors, '\n'))
        end
        
        return #errors == 0, errors
    end
    
    ---
    -- 从CSV文件加载配置
    -- @param csv_path string CSV文件路径
    -- @param namespace string 命名空间
    -- @param schema table Schema定义（可选）
    -- @return boolean, table 是否加载成功，错误列表
    ---
    local function load_from_csv(csv_path, namespace, schema)
        local CsvLoader = require 'data.csv_loader'
        local rows = CsvLoader.read_rows({path = csv_path})
        
        local data = {}
        for _, row in ipairs(rows) do
            local key = row['key']
            if key and key ~= '' and key ~= '__字段说明__' then
                local value = row['value']
                -- 尝试转换为数字
                local num_value = tonumber(value)
                data[key] = num_value ~= nil and num_value or value
            end
        end
        
        -- 记录来源
        sources[namespace] = { type = 'csv', path = csv_path }
        return load_from_table(namespace, data, schema)
    end
    
    ---
    -- 从Lua模块加载配置
    -- @param module_path string Lua模块路径
    -- @param namespace string 命名空间
    -- @param schema table Schema定义（可选）
    -- @return boolean, table 是否加载成功，错误列表
    ---
    local function load_from_lua(module_path, namespace, schema)
        local ok, data = pcall(require, module_path)
        if not ok then
            print(string.format('[ConfigManager] Failed to load module "%s": %s', module_path, data))
            return false, {data}
        end
        
        -- 记录来源
        sources[namespace] = { type = 'lua', path = module_path }
        return load_from_table(namespace, data, schema)
    end
    
    ---
    -- 获取命名空间的所有配置
    -- @param namespace string 命名空间
    -- @return table 配置表
    ---
    local function get_namespace(namespace)
        return config_store[namespace] or {}
    end
    
    ---
    -- 合并命名空间配置
    -- @param namespace string 命名空间
    -- @param data table 要合并的数据
    -- @param overwrite boolean 是否覆盖已存在的配置
    ---
    local function merge_namespace(namespace, data, overwrite)
        if not config_store[namespace] then
            config_store[namespace] = {}
        end
        
        for key, value in pairs(data) do
            if overwrite or config_store[namespace][key] == nil then
                config_store[namespace][key] = value
            end
        end
    end
    
    ---
    -- 导出配置
    -- @param namespace string 可选，指定命名空间
    -- @return table 配置数据
    ---
    local function dump(namespace)
        if namespace then
            return config_store[namespace] or {}
        end
        return config_store
    end
    
    ---
    -- 注册Schema
    -- @param namespace string 命名空间
    -- @param schema table Schema定义
    ---
    local function register_schema(namespace, schema)
        schema_store[namespace] = schema
    end
    
    ---
    -- 验证命名空间配置
    -- @param namespace string 命名空间
    -- @return boolean, table 是否验证通过，错误列表
    ---
    local function validate_namespace(namespace)
        local schema = schema_store[namespace]
        local config = config_store[namespace]
        if not schema or not config then return true, {} end
        
        local errors = {}
        for key, field_schema in pairs(schema) do
            -- 检查必填字段
            if field_schema.required and config[key] == nil then
                table.insert(errors, string.format('Missing required field "%s.%s"', namespace, key))
            end
            
            -- 验证已存在的字段
            if config[key] ~= nil then
                local ok, err = validate_config(key, config[key], field_schema)
                if not ok then
                    table.insert(errors, string.format('%s.%s: %s', namespace, key, err))
                end
            end
        end
        
        return #errors == 0, errors
    end
    
    ---
    -- 获取Schema定义
    -- @param namespace string 命名空间
    -- @return table Schema定义
    ---
    local function get_schema(namespace)
        return schema_store[namespace]
    end
    
    -- 返回配置管理器 API
    return {
        ---
        -- 设置配置（支持点号分隔的键名）
        -- @param key string 配置键（支持 namespace.key 格式）
        -- @param value any 配置值
        -- @param schema table Schema定义（可选）
        -- @return boolean 是否设置成功
        ---
        set = function(key, value, schema)
            local parts = {}
            for part in key:gmatch('[^.]+') do
                table.insert(parts, part)
            end
            
            -- 如果只有一个部分，使用 global 命名空间
            if #parts == 1 then
                return set_with_namespace('global', key, value, schema)
            end
            
            -- 分离命名空间和键名
            local namespace = table.remove(parts, 1)
            local inner_key = table.concat(parts, '.')
            return set_with_namespace(namespace, inner_key, value, schema)
        end,
        
        ---
        -- 获取配置（支持点号分隔的键名）
        -- @param key string 配置键（支持 namespace.key 格式）
        -- @param default any 默认值
        -- @return any 配置值
        ---
        get = function(key, default)
            local parts = {}
            for part in key:gmatch('[^.]+') do
                table.insert(parts, part)
            end
            
            -- 如果只有一个部分，使用 global 命名空间
            if #parts == 1 then
                return get_with_namespace('global', key, default)
            end
            
            -- 分离命名空间和键名
            local namespace = table.remove(parts, 1)
            local inner_key = table.concat(parts, '.')
            return get_with_namespace(namespace, inner_key, default)
        end,
        
        -- === 加载方法 ===
        load_from_table = load_from_table,  -- 从表加载
        load_from_csv = load_from_csv,      -- 从CSV加载
        load_from_lua = load_from_lua,      -- 从Lua模块加载
        
        -- === 命名空间操作 ===
        get_namespace = get_namespace,      -- 获取命名空间
        merge_namespace = merge_namespace,  -- 合并命名空间
        
        -- === Schema管理 ===
        register_schema = register_schema,     -- 注册Schema
        validate_namespace = validate_namespace, -- 验证命名空间
        get_schema = get_schema,               -- 获取Schema
        
        -- === 工具方法 ===
        dump = dump,           -- 导出配置
        sources = function() return sources end  -- 获取来源信息
    }
end

---
-- 创建默认Schema模板
-- @return table 默认Schema定义
---
function M.create_default_schema()
    return {
        debug = {
            time_scale = { type = 'number', min = 0.1, max = 10 },
            enabled = { type = 'boolean' },
            show_debug_ui = { type = 'boolean' }
        },
        
        battle = {
            max_enemies = { type = 'number', min = 1, required = true },
            wave_interval = { type = 'number', min = 0 },
            difficulty = { type = 'string', enum = { easy = true, normal = true, hard = true } }
        },
        
        hero = {
            initial_hp = { type = 'number', min = 1, required = true },
            initial_attack = { type = 'number', min = 1 },
            max_level = { type = 'number', min = 1 }
        },
        
        resources = {
            gold_per_second = { type = 'number', min = 0 },
            wood_per_second = { type = 'number', min = 0 },
            initial_gold = { type = 'number', min = 0 },
            initial_wood = { type = 'number', min = 0 }
        }
    }
end

return M
