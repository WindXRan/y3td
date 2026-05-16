local M = {}

function M.create(container, options)
    options = options or {}
    
    local logger = options.logger or function(msg) print('[BootDIAdapter] ' .. msg) end
    
    local registered_services = {}
    
    local function register_service(name, instance, description)
        if container.has(name) then
            logger('Service "' .. name .. '" already registered, skipping')
            return
        end
        
        container.register_instance(name, instance)
        registered_services[name] = description or 'No description'
        logger('Registered service: ' .. name .. ' - ' .. (description or ''))
    end
    
    local function register_factory(name, factory, description)
        if container.has(name) then
            logger('Service factory "' .. name .. '" already registered, skipping')
            return
        end
        
        container.register(name, factory, { singleton = true })
        registered_services[name] = description or 'No description'
        logger('Registered factory: ' .. name .. ' - ' .. (description or ''))
    end
    
    local function register_core_services(STATE, CONFIG)
        logger('Registering core services...')
        
        register_service('STATE', STATE, 'Global state object')
        register_service('CONFIG', CONFIG, 'Configuration object')
        
        register_factory('logger', function()
            return function(name)
                return {
                    debug = function(msg, context) print('[DEBUG] [' .. name .. '] ' .. msg) end,
                    info = function(msg, context) print('[INFO] [' .. name .. '] ' .. msg) end,
                    warn = function(msg, context) print('[WARN] [' .. name .. '] ' .. msg) end,
                    error = function(msg, context) print('[ERROR] [' .. name .. '] ' .. msg) end
                }
            end
        end, 'Logger factory')
    end
    
    local function register_battle_services(battle_services)
        logger('Registering battle services...')
        
        local battle_service_map = {
            ['battlefield_system'] = '战场系统',
            ['heal_hero'] = '英雄治疗函数',
            ['get_enemies_in_range'] = '获取范围内敌人',
            ['deal_skill_damage'] = '技能伤害处理',
            ['get_current_hero'] = '获取当前英雄',
            ['get_hero_attack'] = '获取英雄攻击力',
            ['is_active_enemy'] = '判断活跃敌人',
            ['get_enemies_on_line'] = '获取线上敌人',
            ['get_hero_point'] = '获取英雄位置',
            ['get_bond_runtime_bonus'] = '获取羁绊运行时加成',
            ['get_combat_bonus'] = '获取战斗加成',
        }
        
        for name, desc in pairs(battle_service_map) do
            if battle_services[name] then
                register_service(name, battle_services[name], desc)
            end
        end
    end
    
    local function register_ui_services(ui_services)
        logger('Registering UI services...')
        
        local ui_service_map = {
            ['runtime_hud_system'] = '运行时HUD系统',
            ['ui_phase_manager'] = 'UI阶段管理器',
            ['status_display_manager'] = '状态显示管理器',
            ['result_panel_system'] = '结果面板系统',
            ['runtime_ui_helpers'] = '运行时UI辅助工具',
            ['message'] = '消息显示函数',
            ['message_system'] = '消息系统',
            ['camera_manager'] = '相机管理器',
        }
        
        for name, desc in pairs(ui_service_map) do
            if ui_services[name] then
                register_service(name, ui_services[name], desc)
            end
        end
    end
    
    local function register_game_services(game_services)
        logger('Registering game services...')
        
        local game_service_map = {
            ['progression_system'] = '进度系统',
            ['reward_system'] = '奖励系统',
            ['reward_manager'] = '奖励管理器',
            ['attr_choice_system'] = '属性选择系统',
            ['audio_system'] = '音频系统',
            ['attack_skills_system'] = '攻击技能系统',
            ['auto_active_effects_system'] = '自动激活效果系统',
            ['effect_debug_system'] = '效果调试系统',
            ['round_manager'] = '回合管理器',
            ['round_choice_state_machine'] = '回合选择状态机',
            ['challenge_manager'] = '挑战管理器',
            ['battle_finish_handler'] = '战斗结束处理器',
            ['debug_tools_system'] = '调试工具系统',
            ['debug_actions_system'] = '调试动作系统',
            ['gm_bond_effects_system'] = 'GM羁绊效果系统',
            ['overview_model_system'] = '概览模型系统',
            ['outgame_system'] = '局外系统',
            ['hero_selection_range_system'] = '英雄选择范围系统',
            ['skill_framework_system'] = '技能框架系统',
            ['sample_skills_system'] = '示例技能系统',
            ['battle_auto_acceptance_system'] = '战斗自动接受系统',
            ['ensure_round_choice_available'] = '确保回合选择可用',
        }
        
        for name, desc in pairs(game_service_map) do
            if game_services[name] then
                register_service(name, game_services[name], desc)
            end
        end
    end
    
    local function register_helpers(helpers)
        logger('Registering helper functions...')
        
        local helper_map = {
            ['make_point'] = '创建点',
            ['round_number'] = '四舍五入',
            ['design_seconds'] = '设计秒转换',
            ['get_player'] = '获取玩家',
            ['get_enemy_player'] = '获取敌方玩家',
            ['sync_basic_attack_ability'] = '同步普攻能力',
            ['sync_gear_runtime_effects'] = '同步装备效果',
            ['add_hero_attr_pack'] = '添加英雄属性包',
            ['snapshot_hero_attrs'] = '快照英雄属性',
        }
        
        for name, desc in pairs(helper_map) do
            if helpers[name] then
                register_service(name, helpers[name], desc)
            end
        end
    end
    
    return {
        register_core_services = register_core_services,
        register_battle_services = register_battle_services,
        register_ui_services = register_ui_services,
        register_game_services = register_game_services,
        register_helpers = register_helpers,
        
        register_service = register_service,
        register_factory = register_factory,
        
        get_registered_services = function()
            return registered_services
        end,
        
        list_services = function()
            logger('=== Registered Services ===')
            for name, desc in pairs(registered_services) do
                logger('  ' .. name .. ': ' .. desc)
            end
            logger('=== End of Services ===')
        end
    }
end

return M