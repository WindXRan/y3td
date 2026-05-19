---敌人单位物编定义
---
---敌人的 spawn unit_id 由 CSV battlefield_unit_config.fixed_unit_ids.enemy 决定，
---属性倍率由 monster_types.csv 按类型（normal/elite/boss/challenge）缩放。
---本文件定义敌人模板的结构骨架，用于文档、校验和未来新建敌人类型。

local od = require 'object_data'
local E = od

-- ===================== 敌人基础模板 =====================

od.define_template('unit', 'enemy_base', {
    type                = E.UnitType.CREATURE,
    level               = 1,

    -- 核心属性（基础值，实际由 monster_type_config 缩放）
    hp_max              = 200,
    hp_rec              = 0,
    mp_max              = 0,
    mp_rec              = 0,

    -- 战斗属性
    attack_phy          = 20,
    attack_mag          = 0,
    attack_range        = 150,
    attack_interval     = 1.5,
    attack_speed        = 100,
    attack_type         = E.AttackType.NORMAL,
    armor_type          = E.ArmorType.LIGHT,

    -- 防御
    defense_phy         = 5,
    defense_mag         = 3,

    -- 移动
    ori_speed           = 250,
    rotate_speed        = 360,

    -- 视野
    vision_rng          = 500,
    view_type           = E.ViewType.NORMAL,

    -- AI
    alarm_range         = 500,
    cancel_alarm_range  = 700,
    can_flee            = false,
    keep_target         = true,
    default_behaviour_type = E.DefaultBehaviour.ATTACK,

    -- 技能
    common_ability_list = {},
    common_atk_type     = E.CommonAttackType.NORMAL,

    -- 死亡
    destroy_after_die   = true,
    keep_dead_body_time = 0,
    drop_items_tuple    = {},

    -- 血条
    blood_show_type     = E.BloodShowType.DAMAGED,
    bar_show_name       = E.BarNameShowType.NAME_LV,

    -- 显示
    is_mini_map_show    = false,
    is_apply_role_color = true,
    role_color_scale    = 1.0,

    -- 池化
    poolable            = true,
    reward_exp          = 10,
})

-- ===================== 敌人类型变体模板 =====================

od.define_template('unit', 'enemy_normal', od.extend('unit', 'enemy_base', {
    kv = {
        enemy_type  = 'normal',
        hp_scale    = 1.0,
        atk_scale   = 1.0,
        armor_scale = 1.0,
        speed_scale = 1.0,
    },
}))

od.define_template('unit', 'enemy_elite', od.extend('unit', 'enemy_base', {
    hp_max          = 400,
    attack_phy      = 35,
    defense_phy     = 10,
    reward_exp      = 30,
    blood_show_type = E.BloodShowType.ALWAYS,
    kv = {
        enemy_type  = 'elite',
        hp_scale    = 2.0,
        atk_scale   = 1.75,
        armor_scale = 2.0,
        speed_scale = 1.0,
    },
}))

od.define_template('unit', 'enemy_boss', od.extend('unit', 'enemy_base', {
    hp_max          = 2000,
    attack_phy      = 80,
    defense_phy     = 30,
    attack_range    = 200,
    body_size       = 1.5,
    reward_exp      = 100,
    blood_show_type = E.BloodShowType.ALWAYS,
    bar_show_name   = E.BarNameShowType.NAME,
    is_mini_map_show = true,
    poolable        = false,
    kv = {
        enemy_type  = 'boss',
        hp_scale    = 10.0,
        atk_scale   = 4.0,
        armor_scale = 6.0,
        speed_scale = 0.8,
    },
}))

od.define_template('unit', 'enemy_challenge', od.extend('unit', 'enemy_base', {
    hp_max          = 3000,
    attack_phy      = 100,
    defense_phy     = 40,
    attack_range    = 200,
    body_size       = 1.6,
    reward_exp      = 150,
    blood_show_type = E.BloodShowType.ALWAYS,
    bar_show_name   = E.BarNameShowType.NAME,
    is_mini_map_show = true,
    poolable        = false,
    kv = {
        enemy_type  = 'challenge',
        hp_scale    = 15.0,
        atk_scale   = 5.0,
        armor_scale = 8.0,
        speed_scale = 0.7,
    },
}))

-- ===================== 敌人实例 =====================

-- 与 hero 类似，敌人的实际 unit_id 由 CSV battlefield_unit_config 在运行时决定。
-- 以下保留骨架供文档和未来迁移。
--
-- 注意：monster_maintask 表中的 spawn_unit_id（如 400000+）是另一套独立 ID，
-- 用于波次任务中的特殊敌人。它们暂不纳入 object_data，继续走 CSV 驱动。

local units = {}
return units
