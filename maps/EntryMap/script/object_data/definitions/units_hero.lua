---英雄单位物编定义
---
---注意：英雄的实际 unit_id 和 model_id 由 CSV 配表在运行时决定
---（battlefield_unit_config.fixed_unit_ids.hero / fixed_model_ids.hero）。
---本文件的模板定义了英雄单位的结构骨架，用于文档、校验和未来新建英雄。

local od = require 'object_data'
local E = od

-- ===================== 英雄基础模板 =====================

od.define_template('unit', 'hero_base', {
    type                = E.UnitType.HERO,
    level               = 1,
    main_attr           = E.MainAttr.STR,

    -- 核心属性（实际值由 CSV hero_attr_growth 覆盖）
    hp_max              = 500,
    hp_rec              = 1.0,
    mp_max              = 100,
    mp_rec              = 1.0,
    mp_key              = 'mp',

    -- 战斗属性
    attack_phy          = 50,
    attack_mag          = 0,
    attack_range        = 250,
    attack_interval     = 1.7,
    attack_speed        = 100,
    attack_type         = E.AttackType.HERO,
    armor_type          = E.ArmorType.HERO,

    -- 防御
    defense_phy         = 10,
    defense_mag         = 5,

    -- 战斗特殊
    critical_chance     = 5,
    critical_dmg        = 150,
    dodge_rate          = 0,
    hit_rate            = 100,

    -- 移动
    ori_speed           = 300,
    rotate_speed        = 360,
    speed_ratio_in_turn = 0.5,

    -- 视野
    vision_rng          = 800,
    view_type           = E.ViewType.NORMAL,

    -- 物品栏
    bar_slot_size       = 6,
    pkg_slot_size       = 0,
    enable_item_slots   = true,

    -- AI
    alarm_range         = 300,
    cancel_alarm_range  = 500,
    can_flee            = false,
    keep_target         = false,
    default_behaviour_type = E.DefaultBehaviour.ATTACK,

    -- 技能槽位
    hero_ability_list   = {},  -- 由 CSV 配置运行时注入
    common_ability_list = {},
    passive_ability_list = {},

    -- 死亡
    destroy_after_die   = false,
    keep_dead_body_time = 10,

    -- 血条
    blood_bar           = E.BloodBarType.DEFAULT,
    blood_show_type     = E.BloodShowType.ALWAYS,
    bar_show_name       = E.BarNameShowType.NAME_LV,

    -- 显示
    is_mini_map_show    = true,
    is_apply_role_color = true,
    role_color_scale    = 1.0,

    -- 碰撞
    collision_radius_2  = 0,
    dynamic_collision_r = 0,

    -- 回调标记（实际绑定通过 y3.object.unit[key]:event() 完成）
    on_create           = nil,
    on_remove           = nil,
    on_dead             = nil,
})

-- ===================== 英雄定义 =====================

-- 当前项目的英雄 unit_id 由 CSV battlefield_unit_config 动态决定，
-- 不走硬编码。此处保留定义骨架供文档和未来迁移使用。
--
-- 示例（当 CSV 迁移到 object_data 时启用）：
--   hero = od.extend('unit', 'hero_base', {
--       key  = CONFIG.unit_ids.hero,
--       name = '英雄',
--       model = CONFIG.unit_ids.hero_model,
--   })

local units = {}
return units
