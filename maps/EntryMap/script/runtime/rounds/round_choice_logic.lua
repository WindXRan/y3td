local M = {}

function M.create(dependencies)
    local STATE = dependencies.STATE
    local CONFIG = dependencies.CONFIG
    local BondSystem = dependencies.bond_system
    local GearUpgrades = dependencies.gear_upgrades
    local attr_choice_system = dependencies.attr_choice_system
    local reward_system = dependencies.reward_system
    local message = dependencies.message
    local logger = dependencies.logger('RoundChoiceLogic')
    
    local function create_bond_env()
        return {
            STATE = STATE,
            message = message,
            round_number = dependencies.round_number,
            y3 = dependencies.y3,
            hero_attr_system = dependencies.hero_attr_system,
            heal_hero = dependencies.heal_hero,
            sync_basic_attack_ability = dependencies.sync_basic_attack_ability,
            is_active_enemy = dependencies.is_active_enemy,
            get_enemy_runtime_info = dependencies.get_enemy_runtime_info,
            is_boss_runtime_enemy = dependencies.is_boss_runtime_enemy,
            is_elite_runtime_enemy = dependencies.is_elite_runtime_enemy,
            get_enemies_in_range = dependencies.get_enemies_in_range,
            deal_skill_damage = dependencies.deal_skill_damage,
            emit_damage_debug = function(visual)
                dependencies.emit_damage_debug_visual(visual, nil)
            end,
            reserve_formula_damage = dependencies.reserve_formula_damage,
            basic_attack_damage_type = dependencies.basic_attack_damage_type,
            get_player = dependencies.get_player,
        }
    end
    
    local function get_pending_round_choice_kind()
        local round_manager = dependencies.round_manager
        
        if round_manager and round_manager.get_pending_round_choice_kind then
            return round_manager.get_pending_round_choice_kind()
        end
        
        if STATE.gear_state and STATE.gear_state.awaiting_choice and STATE.gear_state.current_choices then
            return 'gear'
        end
        
        if attr_choice_system and attr_choice_system.get_pending_choice_kind then
            local attr_kind = attr_choice_system.get_pending_choice_kind()
            if attr_kind then
                return attr_kind
            end
        end
        
        if STATE.subsystems.bond and STATE.subsystems.bond.awaiting_choice and STATE.subsystems.bond.current_choices then
            return 'bond'
        end
        
        local evolution_runtime = STATE.subsystems.evolution
        if evolution_runtime and evolution_runtime.awaiting_choice and evolution_runtime.current_choices then
            return 'evolution'
        end
        
        return nil
    end
    
    local function get_pending_round_choice_label(kind)
        local round_manager = dependencies.round_manager
        
        if round_manager and round_manager.get_pending_round_choice_label then
            return round_manager.get_pending_round_choice_label(kind)
        end
        
        if kind == 'bond' then return 'F 战术抽卡' end
        if kind == 'gear' then return '成长武器词条' end
        if kind == 'attr' then return '属性四选一' end
        if kind == 'evolution' then return '英雄' end
        return '当前选择'
    end
    
    local function show_pending_round_choice(kind)
        local round_manager = dependencies.round_manager
        
        if round_manager and round_manager.show_pending_round_choice then
            return round_manager.show_pending_round_choice(kind)
        end
        
        local current_kind = kind or get_pending_round_choice_kind()
        STATE.ui.choice_panel_hidden = false
        
        if current_kind == 'bond' then
            BondSystem.try_draw(create_bond_env())
            return
        end
    end
    
    local function ensure_round_choice_available(allowed_kind)
        local round_manager = dependencies.round_manager
        
        if round_manager and round_manager.ensure_round_choice_available then
            return round_manager.ensure_round_choice_available(allowed_kind)
        end
        
        local kind = get_pending_round_choice_kind()
        if not kind or kind == allowed_kind then
            return true
        end
        
        message('请先完成当前' .. get_pending_round_choice_label(kind) .. '。')
        show_pending_round_choice(kind)
        return false
    end
    
    local function apply_bond_choice(index)
        local round_manager = dependencies.round_manager
        
        if round_manager and round_manager.apply_bond_choice then
            return round_manager.apply_bond_choice(index)
        end
        
        local result = BondSystem.apply_choice(create_bond_env(), index)
        
        if result == 'replace' then
            STATE.ui.choice_panel_hidden = false
            
            local runtime_hud_system = dependencies.runtime_hud_system
            if runtime_hud_system and runtime_hud_system.show_bond_replacement_panel then
                runtime_hud_system.show_bond_replacement_panel()
            end
            
            return 'replace'
        end
        
        STATE.ui.choice_panel_hidden = true
        return true
    end
    
    local function apply_round_choice(index)
        local round_manager = dependencies.round_manager
        
        if round_manager and round_manager.apply_round_choice then
            return round_manager.apply_round_choice(index)
        end
        
        local round_choice_sm = dependencies.round_choice_state_machine
        if round_choice_sm and round_choice_sm.apply_round_choice then
            return round_choice_sm.apply_round_choice(index)
        end
        
        local kind = get_pending_round_choice_kind()
        
        if kind == 'gear' then
            if GearUpgrades.apply_affix_choice({
                STATE = STATE,
                CONFIG = CONFIG,
                message = message,
            }, index) then
                if STATE.battle.hero and dependencies.sync_gear_runtime_effects then
                    dependencies.sync_gear_runtime_effects(STATE, STATE.battle.hero, CONFIG.gear_upgrade_config)
                end
                STATE.ui.choice_panel_hidden = true
                return true
            end
            return false
        end
        
        if kind == 'attr' then
            local ok = attr_choice_system and attr_choice_system.apply_choice and 
                attr_choice_system.apply_choice(index) or false
            if ok then
                STATE.ui.choice_panel_hidden = true
            end
            return ok
        end
        
        if kind == 'bond' then
            apply_bond_choice(index)
            STATE.ui.choice_panel_hidden = true
            return true
        end
        
        if kind == 'evolution' then
            reward_system.apply_evolution_choice(index)
            STATE.ui.choice_panel_hidden = true
            return true
        end
        
        return false
    end
    
    local function refresh_current_choice()
        STATE.ui.choice_panel_hidden = false
        local kind = get_pending_round_choice_kind()
        
        if kind == 'gear' then
            return GearUpgrades.refresh_affix_choices({
                STATE = STATE,
                CONFIG = CONFIG,
                message = message,
            })
        end
        
        if kind == 'attr' then
            message('属性四选一不支持刷新。')
            return false
        end
        
        if kind == 'bond' then
            return BondSystem.refresh_choice(create_bond_env())
        end
        
        if kind == 'evolution' then
            message('当前猎手专精不支持刷新。')
            return false
        end
        
        return false
    end
    
    local function try_bond_draw()
        STATE.ui.choice_panel_hidden = false
        
        if not ensure_round_choice_available('bond') then
            return
        end
        
        local BondDrawConfig = dependencies.bond_draw_config
        local cost = BondDrawConfig and BondDrawConfig.draw_cost or 100
        
        if not STATE.battle.resources or (STATE.battle.resources.wood or 0) < cost then
            local runtime_hud_system = dependencies.runtime_hud_system
            if runtime_hud_system and runtime_hud_system.show_center_tip then
                runtime_hud_system.show_center_tip('木头不足，无法抽卡！')
            end
            return
        end
        
        BondSystem.try_draw(create_bond_env())
    end
    
    return {
        get_pending_round_choice_kind = get_pending_round_choice_kind,
        get_pending_round_choice_label = get_pending_round_choice_label,
        show_pending_round_choice = show_pending_round_choice,
        ensure_round_choice_available = ensure_round_choice_available,
        apply_bond_choice = apply_bond_choice,
        apply_round_choice = apply_round_choice,
        refresh_current_choice = refresh_current_choice,
        try_bond_draw = try_bond_draw,
        create_bond_env = create_bond_env
    }
end

return M