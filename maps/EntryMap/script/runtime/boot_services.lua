local M = {}

local services = {}

local function create_service_slot(name)
    local value = nil
    services[name] = function()
        return value
    end
    return function(new_value)
        value = new_value
    end
end

M.heal_hero_setter = create_service_slot('heal_hero')
M.progression_system_setter = create_service_slot('progression_system')
M.battlefield_system_setter = create_service_slot('battlefield_system')
M.debug_tools_system_setter = create_service_slot('debug_tools_system')
M.debug_actions_system_setter = create_service_slot('debug_actions_system')
M.gm_bond_effects_system_setter = create_service_slot('gm_bond_effects_system')
M.runtime_hud_system_setter = create_service_slot('runtime_hud_system')
M.overview_model_system_setter = create_service_slot('overview_model_system')
M.outgame_system_setter = create_service_slot('outgame_system')
M.reward_system_setter = create_service_slot('reward_system')
M.attr_choice_system_setter = create_service_slot('attr_choice_system')
M.audio_system_setter = create_service_slot('audio_system')
M.hero_selection_range_system_setter = create_service_slot('hero_selection_range_system')
M.skill_framework_system_setter = create_service_slot('skill_framework_system')
M.sample_skills_system_setter = create_service_slot('sample_skills_system')
M.message_setter = create_service_slot('message')
M.ensure_round_choice_available_setter = create_service_slot('ensure_round_choice_available')
M.get_enemies_in_range_setter = create_service_slot('get_enemies_in_range')
M.deal_skill_damage_setter = create_service_slot('deal_skill_damage')

function M.sync_services(RuntimeEntry)
    RuntimeEntry._services = {}
    RuntimeEntry._services.heal_hero = services.heal_hero()
    RuntimeEntry._services.progression_system = services.progression_system()
    RuntimeEntry._services.battlefield_system = services.battlefield_system()
    RuntimeEntry._services.debug_tools_system = services.debug_tools_system()
    RuntimeEntry._services.debug_actions_system = services.debug_actions_system()
    RuntimeEntry._services.gm_bond_effects_system = services.gm_bond_effects_system()
    RuntimeEntry._services.runtime_hud_system = services.runtime_hud_system()
    RuntimeEntry._services.overview_model_system = services.overview_model_system()
    RuntimeEntry._services.outgame_system = services.outgame_system()
    RuntimeEntry._services.reward_system = services.reward_system()
    RuntimeEntry._services.attr_choice_system = services.attr_choice_system()
    RuntimeEntry._services.audio_system = services.audio_system()
    RuntimeEntry._services.hero_selection_range_system = services.hero_selection_range_system()
    RuntimeEntry._services.skill_framework_system = services.skill_framework_system()
    RuntimeEntry._services.sample_skills_system = services.sample_skills_system()
    RuntimeEntry._services.message = services.message()
    RuntimeEntry._services.ensure_round_choice_available = services.ensure_round_choice_available()
    RuntimeEntry._services.get_enemies_in_range = services.get_enemies_in_range()
    RuntimeEntry._services.deal_skill_damage = services.deal_skill_damage()
end

function M.get_service(name)
    return services[name] and services[name]() or nil
end

return M