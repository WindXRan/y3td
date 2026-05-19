---不依赖编辑器本体的物编数据结构（自走棋适配版）
---纯 Lua 实现，用于在代码中定义游戏对象，无需 GUI 编辑器。
---
--- 使用方式：
---   local od = require 'object_data'
---   local skill = od.ability { key=2001, name='剑气波', ... }

local E = require 'object_data.enums'

local M = {}

-- 导出所有枚举
M.UnitType           = E.UnitType
M.AttackType         = E.AttackType
M.ArmorType          = E.ArmorType
M.MoveType           = E.MoveType
M.ViewType           = E.ViewType
M.AbilityCastType    = E.AbilityCastType
M.AbilityType        = E.AbilityType
M.AbilityPointerType = E.AbilityPointerType
M.FilterCamp         = E.FilterCamp
M.FilterType         = E.FilterType
M.ModifierType       = E.ModifierType
M.ModifierCoverType  = E.ModifierCoverType
M.ModifierEffectType = E.ModifierEffectType
M.StackType          = E.StackType
M.SlotType           = E.SlotType
M.ShieldType         = E.ShieldType
M.TargetAllow        = E.TargetAllow
M.BloodBarType       = E.BloodBarType
M.BloodShowType      = E.BloodShowType
M.BarNameShowType    = E.BarNameShowType
M.CommonAttackType   = E.CommonAttackType
M.DamageType         = E.DamageType
M.UnitState          = E.UnitState
M.DefaultBehaviour   = E.DefaultBehaviour
M.ProjectileMoveType = E.ProjectileMoveType
M.CollisionLayers    = E.CollisionLayers
M.AbilityStage       = E.AbilityStage
M.CoverChange        = E.CoverChange
M.ItemBillboardType  = E.ItemBillboardType
M.Element            = E.Element
M.DamageForm         = E.DamageForm
M.BondTrigger        = E.BondTrigger
M.EnemyType          = E.EnemyType

-- ===================== 辅助函数 =====================

local function shallow_copy(v)
    if type(v) == 'table' then
        local cp = {}
        for k2, v2 in pairs(v) do
            cp[k2] = v2
        end
        return cp
    end
    return v
end

local function merge(defaults, user_data)
    local t = {}
    for k, v in pairs(defaults) do
        t[k] = shallow_copy(v)
    end
    if user_data then
        for k, v in pairs(user_data) do
            if v ~= nil then
                t[k] = v
            end
        end
    end
    return t
end

-- ===================== 模板系统 =====================

M.templates = {
    unit       = {},
    ability    = {},
    item       = {},
    buff       = {},
    projectile = {},
}

function M.define_template(type_name, template_name, data)
    if not M.templates[type_name] then
        error('未知的物编类型: ' .. tostring(type_name))
    end
    M.templates[type_name][template_name] = data
end

function M.extend(type_name, template_name, overrides)
    local defaults = M.templates[type_name] and M.templates[type_name][template_name]
    if not defaults then
        error(('模板 %s.%s 不存在'):format(type_name, template_name))
    end
    return merge(defaults, overrides)
end

-- ===================== 单位 =====================

local UNIT_DEFAULTS = {
    key = 0,            name = '',              suffix = '',
    uid = '',           type = 1,
    description = '',   tags = {},

    -- 模型/表现
    model = 0,          body_size = 1.0,       model_height = 0,
    model_opacity = 1.0, icon = 0,            mini_map_icon = 0,
    mini_map_icon_scale = 1.0, separate_enemy_icon = false,
    enemy_mini_map_icon = 0,
    use_base_tint_color = false, base_tint_color = nil,
    use_fresnel = false, fresnel_color = nil, fresnel_exp = 0,
    fresnel_emissive_color_strength = 0,
    use_virtual_light = false,
    base_color_mod = nil, material_color = nil,
    material_color_intensity = 0, material_alpha = 1.0,
    material_change = nil,

    -- 基础属性
    level = 1,          hp_max = 100,          hp_max_grow = 0,
    hp_rec = 0,         hp_rec_grow = 0,
    mp_max = 0,         mp_max_grow = 0,
    mp_rec = 0,         mp_rec_grow = 0,
    mp_key = 'mp',

    -- 战斗属性
    attack_phy = 0,     attack_phy_grow = 0,
    attack_mag = 0,     attack_mag_grow = 0,
    attack_range = 300, attack_range_grow = 0,
    attack_interval = 1.0, attack_interval_grow = 0,
    attack_speed = 100, attack_speed_grow = 0,
    attack_type = 0,    armor_type = 0,

    -- 防御属性
    defense_phy = 0,    defense_phy_grow = 0,
    defense_mag = 0,    defense_mag_grow = 0,
    pene_phy = 0,       pene_phy_grow = 0,
    pene_mag = 0,       pene_mag_grow = 0,
    pene_phy_ratio = 0, pene_phy_ratio_grow = 0,
    pene_mag_ratio = 0, pene_mag_ratio_grow = 0,

    -- 战斗特殊
    critical_chance = 0,    critical_chance_grow = 0,
    critical_dmg = 150,     critical_dmg_grow = 0,
    dodge_rate = 0,         dodge_rate_grow = 0,
    hit_rate = 100,         hit_rate_grow = 0,
    dmg_reduction = 0,      dmg_reduction_grow = 0,
    extra_dmg = 0,          extra_dmg_grow = 0,
    heal_effect = 0,        heal_effect_grow = 0,
    cd_reduce = 0,          cd_reduce_grow = 0,
    vampire_phy = 0,        vampire_phy_grow = 0,
    vampire_mag = 0,        vampire_mag_grow = 0,

    -- 移动
    ori_speed = 300,        ori_speed_grow = 0,
    rotate_speed = 360,     speed_ratio_in_turn = 0.5,

    -- 碰撞
    collision_radius_2 = 0, dynamic_collision_r = 0,

    -- 视野
    view_type = nil,       vision_rng = 800,    vision_rng_grow = 0,

    -- AI
    alarm_range = 300,     cancel_alarm_range = 500,
    counterattack_range = 0,
    can_flee = false,      keep_target = false,
    default_behaviour_type = nil,

    -- 技能
    common_ability_list = {},   hero_ability_list = {},
    passive_ability_list = {},
    common_atk = nil,           common_atk_type = 0,
    simple_common_atk = nil,

    -- 物品栏
    bar_slot_size = 6,         pkg_slot_size = 0,
    enable_item_slots = true,

    -- 死亡/复活
    destroy_after_die = false, keep_dead_body_time = 10,
    drop_items_tuple = {},

    -- 动画
    idle_anim = '',       walk_anim = '',
    die_anim = '',        special_idle_anim = '',

    -- 血条/名称
    blood_bar = nil,      blood_show_type = nil,
    bar_show_name = nil,  bar_show_scale = false,
    billboard_offset = nil,
    billboard_scale_x = 1.0, billboard_scale_y = 1.0,

    -- 显示
    is_mini_map_show = true,
    is_open_Xray = false, is_open_outline_pass = false,
    outline_pass_color = nil, outline_pass_width = 0,
    is_apply_role_color = true, role_color_scale = 1.0,

    -- 状态
    state_init = nil,     state_list = {},

    -- 其他
    poolable = false,     reward_exp = 0,
    height_offset = 0,    width_offset = 0,

    kv = {},

    -- 回调
    on_create = nil, on_remove = nil, on_dead = nil,
}

function M.unit(data)
    local defaults = UNIT_DEFAULTS
    if data and data.extends then
        local tmpl = M.templates.unit[data.extends]
        if tmpl then
            defaults = merge(UNIT_DEFAULTS, tmpl)
        end
    end
    return merge(defaults, data)
end

function M.unit_options(data)
    return data or {}
end

-- ===================== 技能 =====================

local ABILITY_DEFAULTS = {
    key = 0,            name = '',          suffix = '',
    uid = '',           description = '',   tags = {},

    ability_icon = nil,

    -- 施法阶段
    ability_cast_point = 0.3,      ability_channel_time = 0,
    ability_bw_point = 0.3,        ability_prepare_time = 0,

    -- 打断
    can_ps_interrupt = true,       can_cast_interrupt = true,
    can_prepare_interrupt = false, can_bs_interrupt = false,
    can_interrupt_others = true,

    -- 释放
    ability_cast_type = 0,         sight_type = nil,
    ability_cast_range = '{0}',    ability_break_cast_range = '{0}',
    is_immediate = false,
    influenced_by_move = true,     need_turn_to_target = true,
    release_immediately_out_of_range = false,
    can_cache = false,

    -- 冷却/充能
    cold_down_time = '{0}',
    ability_max_stack_count = '{0}',
    ability_stack_cd = '{0}',
    influenced_by_cd_reduce = true,

    -- 等级
    ability_max_level = 1,

    -- 消耗
    ability_cost = '{0}',
    can_cost_hp = false,           ability_hp_cost = '{0}',
    cost_hp_can_die = false,
    can_cast_when_hp_insufficient = false,

    -- 伤害
    ability_damage = '{0}',        ability_damage_range = '{0}',

    -- 指示器
    pointer_channel = 0,
    pointer_can_block = false,
    circle_radius = '{0}',         sector_radius = '{0}',
    sector_angle = '{0}',          arrow_length = '{0}',
    arrow_width = '{0}',
    enable_customized_pointer_sfx = false,
    customized_pointer_sfx = nil,

    -- 目标筛选
    filter_condition_camp = 0,
    filter_condition_type = 0,
    filter_unit_tags = {},
    forbid_unit_tags = {},

    -- 自动施法
    is_autocast = false,
    can_autocast_when_attack_target = false,

    -- 特效/音效
    ps_sfx_list = {},              ps_sound_effect = {},
    cst_sfx_list = {},             cst_sound_effect = {},
    bs_sfx_list = {},              bs_sound_effect = {},
    sp_sfx_list = {},              sp_sound_effect = {},
    hit_sfx_list = {},             hit_sound_effect = {},
    end_sfx_list = {},             end_sound_effect = {},

    -- 魔法书
    magicbook_list = {},

    -- 其他
    is_charge_ability = false,      is_meele = false,
    sp_count_down = false,
    precondition_list = {},
    kv = {},

    -- 回调
    on_add = nil, on_lose = nil, on_cooldown = nil,
    on_upgrade = nil, on_can_cast = nil,
    on_cast_start = nil, on_cast_channel = nil,
    on_cast_shot = nil, on_cast_finish = nil,
    on_cast_stop = nil,
}

function M.ability(data)
    local defaults = ABILITY_DEFAULTS
    if data and data.extends then
        local tmpl = M.templates.ability[data.extends]
        if tmpl then
            defaults = merge(ABILITY_DEFAULTS, tmpl)
        end
    end
    return merge(defaults, data)
end

function M.ability_options(data)
    return data or {}
end

-- ===================== 物品 =====================

local ITEM_DEFAULTS = {
    key = 0,            name = '',          suffix = '',
    uid = '',           description = '',   tags = {},

    icon = nil,         model = nil,
    body_size = 1.0,    model_opacity = 1.0,

    level = 1,          hp_max = 100,

    stack_type = 0,
    cur_stack = 1,      maximum_stacking = 1,
    cur_charge = 0,     maximum_charging = 0,
    use_consume = 1,

    attached_ability = nil,
    attached_passive_abilities = {},

    auto_use = false,
    discard_enable = true,      discard_when_dead = true,
    drop_stay_time = 60,        delete_on_discard = true,

    item_billboard_type = nil,

    kv = {},

    -- 回调
    on_add = nil, on_lose = nil, on_create = nil,
    on_remove = nil, on_add_to_pkg = nil,
    on_add_to_bar = nil, on_use = nil,
}

function M.item(data)
    local defaults = ITEM_DEFAULTS
    if data and data.extends then
        local tmpl = M.templates.item[data.extends]
        if tmpl then
            defaults = merge(ITEM_DEFAULTS, tmpl)
        end
    end
    return merge(defaults, data)
end

function M.item_options(data)
    return data or {}
end

-- ===================== 魔法效果 (Buff) =====================

local BUFF_DEFAULTS = {
    key = 0,            name = '',          suffix = '',
    uid = '',           description = '',   tags = {},

    modifier_icon = nil,   show_on_ui = true,

    cycle_time = 0,
    disappear_when_dead = true,

    layer_max = 1,
    modifier_cover_type = 0,
    layer_change_of_cover = 1,
    same_origin_cover = false,
    time_change_of_cover = 1,

    shield_value = 0,
    shield_type = 0,
    shield_change_of_cover = 1,

    halo_effect = nil,
    influence_rng = 0,
    is_influence_self = true,
    target_allow = 0,

    modifier_type = 0,
    modifier_effect = 0,

    attach_model_list = nil,
    get_effect_list = nil,
    lose_effect_list = nil,

    material_alpha = 1.0,
    material_change = nil,
    material_color = nil,
    material_color_intensity = 0,

    kv = {},

    -- 回调
    on_can_add = nil, on_add = nil, on_lose = nil,
    on_pulse = nil, on_stack_change = nil,
}

function M.buff(data)
    local defaults = BUFF_DEFAULTS
    if data and data.extends then
        local tmpl = M.templates.buff[data.extends]
        if tmpl then
            defaults = merge(BUFF_DEFAULTS, tmpl)
        end
    end
    return merge(defaults, data)
end

function M.buff_options(data)
    return data or {}
end

-- ===================== 投射物 =====================

local PROJECTILE_DEFAULTS = {
    key = 0,            name = '',          suffix = '',
    uid = '',           description = '',   tags = {},

    icon = nil,

    effect_friend = nil,        effect_foes = nil,
    async_effect = false,
    sfx_loop = false,
    effect_destroy_way_is_immediately = false,

    move_channel = nil,

    max_duration = 5,
    poolable = false,

    kv = {},

    -- 回调
    on_create = nil, on_remove = nil,
}

function M.projectile(data)
    local defaults = PROJECTILE_DEFAULTS
    if data and data.extends then
        local tmpl = M.templates.projectile[data.extends]
        if tmpl then
            defaults = merge(PROJECTILE_DEFAULTS, tmpl)
        end
    end
    return merge(defaults, data)
end

function M.projectile_options(data)
    return data or {}
end

-- ===================== 触发器绑定 =====================

function M.wire(obj, triggers)
    if not obj or not triggers then
        return obj
    end
    for k, v in pairs(triggers) do
        obj[k] = v
    end
    return obj
end

-- ===================== 批量注册 =====================

function M.build_all(registry)
    local result = {}
    local map = {
        units = M.unit, abilities = M.ability, items = M.item,
        buffs = M.buff, projectiles = M.projectile,
    }
    for plural, factory in pairs(map) do
        local list = registry[plural]
        if list then
            result[plural] = {}
            for _, data in ipairs(list) do
                result[plural][data.key] = factory(data)
            end
        end
    end
    return result
end

return M
