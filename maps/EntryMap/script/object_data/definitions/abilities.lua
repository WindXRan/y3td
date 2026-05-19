---攻击技能物编定义
---从 runtime_editor_ids.lua 的 ability 表迁移，所有 key 与编辑器中一致。
---模板 attack_skill_base 定义了 16 个技能的共用默认值。

local od = require 'object_data'
local E = od

-- ===================== 共用模板 =====================

od.define_template('ability', 'attack_skill_base', {
    ability_type        = E.AbilityType.COMMON,
    ability_max_level   = 1,
    ability_cast_point  = 0.3,
    ability_bw_point    = 0.3,
    can_ps_interrupt    = false,
    can_cast_interrupt  = true,
    can_interrupt_others = true,
    influenced_by_move  = false,
    need_turn_to_target = true,
    is_immediate        = false,
    can_cache           = false,
    is_autocast         = false,
    release_immediately_out_of_range = false,
    cold_down_time      = '{5}',
    ability_cost        = '{0}',
    ability_damage      = '{0}',
    filter_condition_camp = E.FilterCamp.ENEMY,
    filter_condition_type = E.FilterType.UNIT,
    influenced_by_cd_reduce = true,
    kv = {},
})

-- ===================== 技能定义 =====================

local abilities = {

    -- ---------- 普攻 ----------
    basic_attack = od.extend('ability', 'attack_skill_base', {
        key  = 201390001,
        name = '普攻',
        ability_cast_type   = E.AbilityCastType.UNIT_TARGET,
        pointer_channel     = E.AbilityPointerType.NONE,
        is_autocast         = true,
        can_autocast_when_attack_target = true,
        attack_range        = '{820}',
        cold_down_time      = '{1.05}',
        sight_type          = E.AbilityPointerType.NONE,
        kv = {
            element         = 'metal',
            damage_form     = 'weapon',
            damage_label    = '金行箭矢',
            category        = '弓箭普攻',
            cast_family     = 'basic_projectile',
            tactical_tags   = { 'single', 'projectile', 'basic_attack', 'archery', 'arrow' },
        },
    }),

    -- ---------- 直线贯穿型 ----------
    sword_wave = od.extend('ability', 'attack_skill_base', {
        key  = 201390002,
        name = '剑气波',
        ability_cast_type   = E.AbilityCastType.LINE_TARGET,
        pointer_channel     = E.AbilityPointerType.LINE,
        arrow_length        = '{900}',
        arrow_width         = '{128}',
        kv = {
            element         = 'metal',
            damage_form     = 'weapon',
            damage_label    = '金行剑气',
            category        = '直线贯穿',
            cast_family     = 'line_pierce',
            tactical_tags   = { 'line', 'pierce', 'clear' },
        },
    }),

    arcane_ray = od.extend('ability', 'attack_skill_base', {
        key  = 201390004,
        name = '奥术射线',
        ability_cast_type   = E.AbilityCastType.LINE_TARGET,
        pointer_channel     = E.AbilityPointerType.LINE,
        arrow_length        = '{1200}',
        arrow_width         = '{96}',
        kv = {
            element         = 'water',
            damage_form     = 'spell',
            damage_label    = '水行射线',
            category        = '长线爆发',
            cast_family     = 'line_pierce',
            tactical_tags   = { 'line', 'burst', 'pierce' },
        },
    }),

    moon_blade = od.extend('ability', 'attack_skill_base', {
        key  = 201390013,
        name = '月刃',
        ability_cast_type   = E.AbilityCastType.LINE_TARGET,
        pointer_channel     = E.AbilityPointerType.LINE,
        arrow_length        = '{800}',
        arrow_width         = '{160}',
        kv = {
            element         = 'wood',
            damage_form     = 'weapon',
            damage_label    = '木行月刃',
            category        = '往返轮斩',
            cast_family     = 'line_return',
            tactical_tags   = { 'line', 'return', 'bounce' },
        },
    }),

    -- ---------- 持续照射型 ----------
    arcane_laser = od.extend('ability', 'attack_skill_base', {
        key  = 201390003,
        name = '奥术激光',
        ability_cast_type   = E.AbilityCastType.UNIT_TARGET,
        pointer_channel     = E.AbilityPointerType.NONE,
        ability_channel_time = 1.5,
        kv = {
            element         = 'water',
            damage_form     = 'spell',
            damage_label    = '水行激光',
            category        = '持续照射',
            cast_family     = 'beam',
            tactical_tags   = { 'beam', 'sustain', 'aoe' },
        },
    }),

    -- ---------- 近身/自身爆发型 ----------
    frost_nova = od.extend('ability', 'attack_skill_base', {
        key  = 201390005,
        name = '冰霜新星',
        ability_cast_type   = E.AbilityCastType.SELF,
        pointer_channel     = E.AbilityPointerType.CIRCLE,
        circle_radius       = '{400}',
        kv = {
            element         = 'water',
            damage_form     = 'spell',
            damage_label    = '水行冰霜',
            category        = '近身爆发',
            cast_family     = 'nova',
            tactical_tags   = { 'nova', 'aoe', 'control' },
        },
    }),

    -- ---------- 连锁弹射型 ----------
    chain_lightning = od.extend('ability', 'attack_skill_base', {
        key  = 201390006,
        name = '连锁闪电',
        ability_cast_type   = E.AbilityCastType.UNIT_TARGET,
        pointer_channel     = E.AbilityPointerType.NONE,
        kv = {
            element         = 'fire',
            damage_form     = 'spell',
            damage_label    = '火行闪电',
            category        = '连锁弹射',
            cast_family     = 'chain',
            tactical_tags   = { 'chain', 'bounce', 'clear' },
        },
    }),

    -- ---------- 区域爆发型 ----------
    earthquake = od.extend('ability', 'attack_skill_base', {
        key  = 201390007,
        name = '地震冲击',
        ability_cast_type   = E.AbilityCastType.AREA_TARGET,
        pointer_channel     = E.AbilityPointerType.CIRCLE,
        circle_radius       = '{350}',
        kv = {
            element         = 'earth',
            damage_form     = 'weapon',
            damage_label    = '土行冲击',
            category        = '区域爆发',
            cast_family     = 'area_burst',
            tactical_tags   = { 'aoe', 'burst', 'ground' },
        },
    }),

    fireball = od.extend('ability', 'attack_skill_base', {
        key  = 201390012,
        name = '火球',
        ability_cast_type   = E.AbilityCastType.AREA_TARGET,
        pointer_channel     = E.AbilityPointerType.CIRCLE,
        circle_radius       = '{280}',
        kv = {
            element         = 'fire',
            damage_form     = 'spell',
            damage_label    = '火行爆炸',
            category        = '点爆炸裂',
            cast_family     = 'area_burst',
            tactical_tags   = { 'burst', 'aoe', 'fire' },
        },
    }),

    meteor = od.extend('ability', 'attack_skill_base', {
        key  = 201390010,
        name = '陨石',
        ability_cast_type   = E.AbilityCastType.AREA_TARGET,
        pointer_channel     = E.AbilityPointerType.CIRCLE,
        circle_radius       = '{400}',
        ability_prepare_time = 0.8,
        kv = {
            element         = 'earth',
            damage_form     = 'spell',
            damage_label    = '土行星陨',
            category        = '延迟终结',
            cast_family     = 'delayed_area_burst',
            tactical_tags   = { 'delayed', 'burst', 'aoe' },
        },
    }),

    demon_seal = od.extend('ability', 'attack_skill_base', {
        key  = 201390015,
        name = '恶魔封印',
        ability_cast_type   = E.AbilityCastType.UNIT_TARGET,
        pointer_channel     = E.AbilityPointerType.CIRCLE,
        circle_radius       = '{300}',
        kv = {
            element         = 'earth',
            damage_form     = 'spell',
            damage_label    = '土行封印',
            category        = '封镇爆发',
            cast_family     = 'seal_burst',
            tactical_tags   = { 'seal', 'control', 'burst' },
        },
    }),

    -- ---------- 移动场域型 ----------
    tornado = od.extend('ability', 'attack_skill_base', {
        key  = 201390008,
        name = '龙卷风',
        ability_cast_type   = E.AbilityCastType.POINT,
        pointer_channel     = E.AbilityPointerType.CIRCLE,
        circle_radius       = '{250}',
        kv = {
            element         = 'wood',
            damage_form     = 'spell',
            damage_label    = '木行风卷',
            category        = '移动场域',
            cast_family     = 'moving_field',
            tactical_tags   = { 'field', 'moving', 'pull' },
        },
    }),

    -- ---------- 持续/控制场域型 ----------
    electro_net = od.extend('ability', 'attack_skill_base', {
        key  = 201390009,
        name = '电网',
        ability_cast_type   = E.AbilityCastType.AREA_TARGET,
        pointer_channel     = E.AbilityPointerType.CIRCLE,
        circle_radius       = '{320}',
        kv = {
            element         = 'fire',
            damage_form     = 'spell',
            damage_label    = '火行电网',
            category        = '控制场域',
            cast_family     = 'control_field',
            tactical_tags   = { 'field', 'control', 'aoe' },
        },
    }),

    hurricane = od.extend('ability', 'attack_skill_base', {
        key  = 201390011,
        name = '飓风',
        ability_cast_type   = E.AbilityCastType.AREA_TARGET,
        pointer_channel     = E.AbilityPointerType.CIRCLE,
        circle_radius       = '{350}',
        kv = {
            element         = 'wood',
            damage_form     = 'spell',
            damage_label    = '木行飓风',
            category        = '聚怪场域',
            cast_family     = 'persistent_field',
            tactical_tags   = { 'field', 'pull', 'sustain' },
        },
    }),

    lotus_flame = od.extend('ability', 'attack_skill_base', {
        key  = 201390014,
        name = '莲火',
        ability_cast_type   = E.AbilityCastType.AREA_TARGET,
        pointer_channel     = E.AbilityPointerType.CIRCLE,
        circle_radius       = '{300}',
        kv = {
            element         = 'fire',
            damage_form     = 'spell',
            damage_label    = '火行莲焰',
            category        = '火域持续',
            cast_family     = 'ignite_field',
            tactical_tags   = { 'field', 'ignite', 'aoe' },
        },
    }),

    -- ---------- 追踪飞剑型 ----------
    flying_swords = od.extend('ability', 'attack_skill_base', {
        key  = 201390016,
        name = '飞剑',
        ability_cast_type   = E.AbilityCastType.UNIT_TARGET,
        pointer_channel     = E.AbilityPointerType.NONE,
        kv = {
            element         = 'metal',
            damage_form     = 'weapon',
            damage_label    = '金行飞剑',
            category        = '追击飞剑',
            cast_family     = 'seeking_swords',
            tactical_tags   = { 'projectile', 'seek', 'bounce' },
        },
    }),
}

return abilities
