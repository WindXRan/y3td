
--[[
    配置加载器 (Config Loader)
    负责从多个来源加载配置数据到 ConfigManager
    
    使用方式:
        local ConfigLoader = require 'core.config_loader'
        local loader = ConfigLoader.create(config_manager, error_handler)
        
        -- 加载所有配置
        loader.load_all()
        
        -- 或单独加载特定配置
        loader.load_entry_config()
        loader.load_game_tables()
        loader.load_skill_tables()
        loader.load_hero_tables()
        loader.load_audio_tables()
        
        -- 检查加载状态
        local status = loader.get_status()
]]

local M = {}

---
-- 创建配置加载器实例
-- @param config_manager table ConfigManager实例
-- @param error_handler table ErrorHandler实例（可选）
-- @return table 配置加载器实例
---
function M.create(config_manager, error_handler)
    local loader = {
        config_manager = config_manager,  -- 配置管理器引用
        error_handler = error_handler,    -- 错误处理器引用
        logger = error_handler and error_handler.logger('ConfigLoader') or nil,  -- 日志器
        loaded_modules = {}               -- 已加载模块记录
    }

    ---
    -- 安全加载模块（带错误处理）
    -- @param module_path string 模块路径
    -- @return any 模块内容或nil
    ---
    local function safe_require(module_path)
        if loader.logger then
            -- 使用ErrorHandler进行安全调用
            local result = loader.error_handler.safe_call(function()
                return require(module_path)
            end)
            if not result.success then
                return nil
            end
            return result.value
        else
            -- 降级到pcall
            local ok, result = pcall(require, module_path)
            if not ok then
                print('[ConfigLoader] Failed to load', module_path, ':', result)
                return nil
            end
            return result
        end
    end

    ---
    -- 加载入口配置
    -- 从 config.entry_config 加载配置并映射到对应命名空间
    ---
    function loader.load_entry_config()
        local entry_config = safe_require('config.entry_config')
        if not entry_config then
            print('[ConfigLoader] entry_config not found')
            return
        end

        -- 加载整个entry_config到entry命名空间
        loader.config_manager.load_from_table('entry', entry_config)

        -- 映射到具体命名空间
        if entry_config.debug_time_scale then
            loader.config_manager.set('game.time_scale', entry_config.debug_time_scale)
        end

        if entry_config.unit_ids then
            loader.config_manager.set('unit.ids', entry_config.unit_ids)
        end

        if entry_config.points then
            loader.config_manager.set('scene.points', entry_config.points)
        end

        if entry_config.areas then
            loader.config_manager.set('scene.areas', entry_config.areas)
        end

        if entry_config.waves then
            loader.config_manager.set('battle.waves', entry_config.waves)
        end

        if entry_config.challenges then
            loader.config_manager.set('battle.challenges', entry_config.challenges)
        end

        loader.loaded_modules.entry_config = true
        print('[ConfigLoader] Loaded entry_config')
    end

    ---
    -- 加载游戏基础表
    -- 从 data.game_tables 加载配置并映射到对应命名空间
    ---
    function loader.load_game_tables()
        local game_tables = safe_require('data.game_tables')
        if not game_tables then
            print('[ConfigLoader] game_tables not found')
            return
        end

        -- 加载整个game_tables到game_tables命名空间
        loader.config_manager.load_from_table('game_tables', game_tables)

        -- 映射到具体命名空间
        if game_tables.battle_base_config then
            loader.config_manager.set('battle.base', game_tables.battle_base_config)
        end

        if game_tables.battlefield_scene_config then
            loader.config_manager.set('scene.config', game_tables.battlefield_scene_config)
        end

        if game_tables.battlefield_unit_config then
            loader.config_manager.set('unit.config', game_tables.battlefield_unit_config)
        end

        if game_tables.waves then
            loader.config_manager.set('battle.waves', game_tables.waves)
        end

        if game_tables.challenges then
            loader.config_manager.set('battle.challenges', game_tables.challenges)
        end

        if game_tables.hero_roster then
            loader.config_manager.set('hero.roster', game_tables.hero_roster)
        end

        loader.loaded_modules.game_tables = true
        print('[ConfigLoader] Loaded game_tables')
    end

    ---
    -- 加载技能表
    -- 从 data.tables.skill 目录下加载各类技能配置
    ---
    function loader.load_skill_tables()
        local skill_tables = {
            attack_skills = safe_require('data.tables.skill.attack_skills'),
            buff_templates = safe_require('data.tables.skill.buff_templates'),
            skill_visuals = safe_require('data.tables.skill.skill_visuals'),
            skill_damage_templates = safe_require('data.tables.skill.skill_damage_templates'),
            auto_active_effects = safe_require('data.tables.skill.auto_active_effects'),
            skill_runtime_tuning = safe_require('data.tables.skill.skill_runtime_tuning')
        }

        -- 将每个技能表加载到对应的命名空间
        for name, table_data in pairs(skill_tables) do
            if table_data then
                loader.config_manager.load_from_table('skill.' .. name, table_data)
            end
        end

        loader.loaded_modules.skill_tables = true
        print('[ConfigLoader] Loaded skill_tables')
    end

    ---
    -- 加载英雄表
    -- 从 data.tables.hero 目录下加载英雄相关配置
    ---
    function loader.load_hero_tables()
        local hero_tables = {
            hero_attr_config = safe_require('data.tables.hero.hero_attr_config'),
            hero_level_progression = safe_require('data.tables.hero.hero_level_progression')
        }

        -- 将每个英雄表加载到对应的命名空间
        for name, table_data in pairs(hero_tables) do
            if table_data then
                loader.config_manager.load_from_table('hero.' .. name, table_data)
            end
        end

        loader.loaded_modules.hero_tables = true
        print('[ConfigLoader] Loaded hero_tables')
    end

    ---
    -- 加载音频表
    -- 从 data.tables 目录下加载音频资源配置
    ---
    function loader.load_audio_tables()
        local audio_tables = {
            audio_resources = safe_require('data.tables.audio_resources')
        }

        -- 将每个音频表加载到对应的命名空间
        for name, table_data in pairs(audio_tables) do
            if table_data then
                loader.config_manager.load_from_table('audio.' .. name, table_data)
            end
        end

        loader.loaded_modules.audio_tables = true
        print('[ConfigLoader] Loaded audio_tables')
    end

    ---
    -- 加载所有配置
    -- 按照预定顺序加载所有配置模块
    ---
    function loader.load_all()
        print('[ConfigLoader] Starting to load all configurations...')

        -- 加载顺序：基础表 -> 入口配置 -> 技能表 -> 英雄表 -> 音频表
        -- 注意：game_tables 需要先于 entry_config 加载，因为 entry_config 可能覆盖部分配置
        local load_order = {
            'load_game_tables',
            'load_entry_config',
            'load_skill_tables',
            'load_hero_tables',
            'load_audio_tables'
        }

        -- 按顺序加载每个模块
        for _, load_func in ipairs(load_order) do
            if loader.logger then
                -- 使用ErrorHandler进行安全调用
                local result = loader.error_handler.safe_call(function()
                    loader[load_func]()
                end)
                if not result.success then
                    loader.logger.error('Error in', load_func, ':', result.error)
                end
            else
                -- 降级到pcall
                local ok, err = pcall(function()
                    loader[load_func]()
                end)
                if not ok then
                    print('[ConfigLoader] Error in', load_func, ':', err)
                end
            end
        end

        print('[ConfigLoader] Configuration loading complete')
    end

    ---
    -- 获取加载状态
    -- @return table 加载状态信息
    ---
    function loader.get_status()
        -- 计算已加载模块数量
        local total_loaded = 0
        for _ in pairs(loader.loaded_modules) do
            total_loaded = total_loaded + 1
        end
        
        return {
            loaded_modules = loader.loaded_modules,
            total_loaded = total_loaded
        }
    end

    return loader
end

return M
