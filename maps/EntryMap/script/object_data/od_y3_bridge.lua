---object_data → Y3 运行时桥接层（自走棋适配版）
---
---将 object_data 定义的物编数据注入到 y3.object 系统中。
---回调注册使用 Y3 官方 :event() API（来源：y3/meta/event.lua 及 .y3maker 知识库）。
---
---用法:
---   local bridge = require 'object_data.od_y3_bridge'
---   bridge.install_definitions({
---       abilities   = require 'object_data.definitions.abilities',
---       projectiles = require 'object_data.definitions.projectiles',
---   }, { verbose = true })

local M = {}

-- ========== object_data 回调字段 → Y3 :event() 事件名映射 ==========
--
-- 映射来源：.y3maker/skills/y3-lua-pipeline/SKILL.md Part 2.2
--          .y3maker/knowledge/物编系统/ 各子系统文档
--          y3/meta/event.lua（引擎事件定义权威源）
--
-- 标记 ⚠ 表示无 Y3 事件对应：install 时跳过并输出 warning。

local Y3_EVENT_MAP = {
    unit = {
        on_create    = '单位-创建',
        on_dead      = '单位-死亡',
        -- ⚠ on_remove: Y3 无"单位移除"事件；用 on_dead + destroy_after_die 替代
    },
    ability = {
        on_add        = '技能-获得',
        on_lose       = '技能-失去',
        on_cooldown   = '技能-冷却结束',
        on_cast_shot  = '施法-出手',
        on_cast_finish = '施法-完成',
        -- ⚠ on_upgrade:       无直接事件，需在 '技能-获得' handler 中判断等级
        -- ⚠ on_can_cast:      无事件，由技能系统的 is_autocast + precondition 替代
        -- ⚠ on_cast_start:    挂在 unit 上 ('单位-施放技能')，非 ability 自身
        -- ⚠ on_cast_channel:  无事件
        -- ⚠ on_cast_stop:     无事件
    },
    item = {
        on_add   = '物品-获得',
        on_lose  = '物品-失去',
        on_use   = '物品-使用',
        -- ⚠ on_create:      无事件；物品创建时自动绑定 on_add 即触发
        -- ⚠ on_remove:      无事件
        -- ⚠ on_add_to_pkg:  无事件
        -- ⚠ on_add_to_bar:  无事件
    },
    buff = {
        on_add         = '效果-获得',
        on_lose        = '效果-失去',
        on_pulse       = '效果-心跳',
        on_stack_change = '效果-层数变化',
        -- ⚠ on_can_add: 无事件；施加前校验走 modifier_cover_type 引擎规则
    },
    projectile = {
        on_create = '投射物-创建',
        on_remove = '投射物-死亡',
    },
}

local UNSUPPORTED_CALLBACKS = {
    unit       = { 'on_remove' },
    ability    = { 'on_upgrade', 'on_can_cast', 'on_cast_start', 'on_cast_channel', 'on_cast_stop' },
    item       = { 'on_create', 'on_remove', 'on_add_to_pkg', 'on_add_to_bar' },
    buff       = { 'on_can_add' },
    projectile = {},
}

-- ========== 主安装逻辑 ==========

---安装物编数据到 y3.object 系统，回调通过 :event() 注册
---@param objects table  build_all 的返回值 {units={}, abilities={}, ...}
---@param opts?    table 可选配置 {auto_create=false, verbose=false}
---@return table   各类型安装计数
function M.install(objects, opts)
    opts = opts or {}
    local counts = {}
    local warnings = {}

    local type_names = {'units', 'abilities', 'items', 'buffs', 'projectiles'}
    local type_singular = {
        units = 'unit', abilities = 'ability', items = 'item',
        buffs = 'buff', projectiles = 'projectile',
    }

    for _, plural in ipairs(type_names) do
        local obj_map = objects[plural]
        if obj_map then
            local singular = type_singular[plural]
            local n = 0
            for key, data in pairs(obj_map) do
                local warn_list = M._install_one(singular, key, data, opts)
                n = n + 1
                if warn_list and #warn_list > 0 then
                    for _, w in ipairs(warn_list) do
                        warnings[#warnings + 1] = w
                    end
                end
            end
            if n > 0 then
                counts[plural] = n
            end
        end
    end

    if opts.verbose then
        local parts = {}
        for _, plural in ipairs(type_names) do
            if counts[plural] then
                parts[#parts + 1] = plural .. '=' .. counts[plural]
            end
        end
        if #parts > 0 then
            print('[od_y3_bridge] 安装: ' .. table.concat(parts, ', '))
        end
        if #warnings > 0 then
            for _, w in ipairs(warnings) do
                print('[od_y3_bridge] ⚠ ' .. w)
            end
        end
    end
    return counts
end

---安装单个对象（内部用）
---@param type_name string  'unit'|'ability'|'item'|'buff'|'projectile'
---@param key       integer
---@param data      table
---@param opts      table
---@return table|nil  warning 列表
function M._install_one(type_name, key, data, opts)
    local accessors = {
        unit       = function() return y3.object.unit[key] end,
        ability    = function() return y3.object.ability[key] end,
        item       = function() return y3.object.item[key] end,
        buff       = function() return y3.object.buff[key] end,
        projectile = function() return y3.object.projectile[key] end,
    }

    local get_obj = accessors[type_name]
    if not get_obj then
        return nil
    end

    local obj = get_obj()
    local event_map = Y3_EVENT_MAP[type_name]
    local unsupported = UNSUPPORTED_CALLBACKS[type_name] or {}
    local label = data.name or tostring(key)
    local warns = {}

    if event_map then
        for cb_name, y3_event in pairs(event_map) do
            local fn = data[cb_name]
            if type(fn) == 'function' then
                obj:event(y3_event, fn)
            end
        end
    end

    -- 检查不被支持的 on_xxx 回调
    for _, cb_name in ipairs(unsupported) do
        if type(data[cb_name]) == 'function' then
            warns[#warns + 1] = string.format(
                '%s %d (%s): %s 无对应的 Y3 事件，未注册',
                type_name, key, label, cb_name
            )
        end
    end

    -- auto_create: 把数据写入编辑器（默认关闭）
    if opts.auto_create then
        local data_keys = {
            unit       = 'editor_unit',
            ability    = 'ability_all',
            item       = 'editor_item',
            buff       = 'modifier_all',
            projectile = 'projectile_all',
        }
        local dk = data_keys[type_name]
        if dk and not GameAPI.api_get_editor_type_data(dk, key) then
            M.create_new(type_name, data)
        end
    end

    return warns
end

-- ========== 便捷安装：从 definitions 文件批量加载 ==========

---从 definitions/*.lua 文件加载并安装到 y3.object
---@param registry table  {abilities=require'...', projectiles=require'...', ...}
---@param opts?    table  传递给 install 的选项
---@return table   install 的返回值
function M.install_definitions(registry, opts)
    local od = require 'object_data'
    local built = od.build_all(registry)
    return M.install(built, opts)
end

-- ========== 投射物 Hook 协作 ==========

---安装投射物 name→key 反向索引
---@param projectile_map table  {key = projectile_def} 投射物定义表
function M.install_projectile_resolver(projectile_map)
    if not projectile_map then
        return
    end

    local name_to_key = {}
    for key, def in pairs(projectile_map) do
        if def.name and key then
            name_to_key[def.name] = key
        end
    end

    _G.object_data_projectile_map = projectile_map
    _G.object_data_projectile_by_name = name_to_key

    if #name_to_key > 0 then
        print('[od_y3_bridge] 投射物解析器已安装: ' .. tostring(#name_to_key) .. ' 个具名投射物')
    end
end

-- ========== 从数据创建新物编 ==========

---基于我们的数据在编辑器中创建新的物编对象（运行时）
---@param type_name    string   'unit'|'ability'|'item'|'buff'|'projectile'
---@param data         table    物编数据（必须含 key 字段）
---@param template_key? integer 模板 key（默认从 data.template_key 取，兜底用 data.key）
---@return integer? new_key
function M.create_new(type_name, data, template_key)
    local configs = {
        unit = {
            data_key = 'editor_unit',
            create_with_data = function(tk, nk, d)
                return GameAPI.create_unit_editor_data_lua(tk, nk, d)
            end,
        },
        ability = {
            data_key = 'ability_all',
            create_with_data = function(tk, nk, d)
                return GameAPI.create_ability_editor_data_lua(tk, nk, d)
            end,
        },
        item = {
            data_key = 'editor_item',
            create_clone = function(tk)
                return GameAPI.create_item_editor_data(tk)
            end,
        },
        buff = {
            data_key = 'modifier_all',
            create_clone = function(tk)
                return GameAPI.create_modifier_editor_data(tk)
            end,
        },
        projectile = {
            data_key = 'projectile_all',
            create_clone = function(tk)
                return GameAPI.create_projectile_editor_data(tk)
            end,
        },
    }

    local cfg = configs[type_name]
    if not cfg then
        error('未知的物编类型: ' .. tostring(type_name))
    end

    local tkey = template_key or data.template_key or data.key
    if not tkey then
        error('需要 template_key 或 data.key 作为模板')
    end

    local new_key
    if cfg.create_with_data then
        new_key = data.key
        cfg.create_with_data(tkey, new_key, data)
    elseif cfg.create_clone then
        new_key = cfg.create_clone(tkey)
        local new_obj = M._get_editor_obj(type_name, new_key)
        if new_obj and new_obj.lua_data then
            for k, v in pairs(data) do
                if type(v) ~= 'function' and not tostring(k):match('^on_') then
                    new_obj.lua_data[k] = v
                end
            end
        end
    end

    return new_key
end

---获取编辑器对象实例（内部用）
function M._get_editor_obj(type_name, key)
    if type_name == 'unit' then
        return y3.object.unit[key]
    elseif type_name == 'ability' then
        return y3.object.ability[key]
    elseif type_name == 'item' then
        return y3.object.item[key]
    elseif type_name == 'buff' then
        return y3.object.buff[key]
    elseif type_name == 'projectile' then
        return y3.object.projectile[key]
    end
end

-- ========== 验证/诊断 ==========

---检查 object_data 定义与编辑器现有数据是否一致
---@param type_name string
---@param key       integer
---@param our_data  table
---@return table    差异报告 {match=true/false, diffs={}, editor_data=...}
function M.verify(type_name, key, our_data)
    local data_keys = {
        unit       = 'editor_unit',
        ability    = 'ability_all',
        item       = 'editor_item',
        buff       = 'modifier_all',
        projectile = 'projectile_all',
    }

    local dk = data_keys[type_name]
    if not dk then
        return {match = false, error = '未知类型: ' .. tostring(type_name)}
    end

    local editor_data = GameAPI.api_get_editor_type_data(dk, key)
    if not editor_data then
        return {match = false, error = '编辑器中无 key=' .. tostring(key)}
    end

    local diffs = {}
    for k, our_v in pairs(our_data) do
        if type(our_v) ~= 'function' and not tostring(k):match('^on_') then
            local editor_v = editor_data[k]
            local our_empty = (our_v == nil or our_v == '' or our_v == 0 or our_v == 0.0)
            local ed_empty = (editor_v == nil or editor_v == '' or editor_v == 0 or editor_v == 0.0)
            if our_empty and ed_empty then
                -- 双方都为空，跳过
            elseif tostring(our_v) ~= tostring(editor_v) then
                diffs[#diffs + 1] = {
                    field = k,
                    our_value = our_v,
                    editor_value = editor_v,
                }
            end
        end
    end

    return {
        match = #diffs == 0,
        diffs = diffs,
        editor_data = editor_data,
    }
end

---批量校验一个注册表，打印差异报告
---@param registry table  {abilities={}, projectiles={}, ...}
---@return boolean  all_match
function M.verify_all(registry)
    local od = require 'object_data'
    local built = od.build_all(registry)

    local singular_map = {
        units = 'unit', abilities = 'ability', items = 'item',
        buffs = 'buff', projectiles = 'projectile',
    }

    local all_match = true
    local total_checked = 0
    local total_mismatch = 0

    for plural, singular in pairs(singular_map) do
        local obj_map = built[plural]
        if obj_map then
            for key, data in pairs(obj_map) do
                total_checked = total_checked + 1
                local report = M.verify(singular, key, data)
                if not report.match then
                    total_mismatch = total_mismatch + 1
                    all_match = false
                    print(string.format('[verify] %s %d (%s): 不一致', singular, key, data.name or '?'))
                    for _, diff in ipairs(report.diffs) do
                        print(string.format('  %s: object_data=%s, editor=%s',
                            diff.field, tostring(diff.our_value), tostring(diff.editor_value)))
                    end
                end
            end
        end
    end

    print(string.format('[verify] 检查 %d 项, 一致 %d, 不一致 %d',
        total_checked, total_checked - total_mismatch, total_mismatch))
    return all_match
end

return M
