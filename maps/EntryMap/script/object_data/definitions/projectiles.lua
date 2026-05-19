---投射物物编定义
---从 runtime_editor_ids.lua 的 projectile 表迁移，所有 key 与编辑器中一致。
---多个技能可能共享同一个投射物 key（如 arcane_laser 和 bow_sniper 共用 201392031）。

local od = require 'object_data'

-- ===================== 共用模板 =====================

od.define_template('projectile', 'basic_projectile', {
    move_channel    = nil,
    max_duration    = 5,
    poolable        = false,
    async_effect    = false,
    sfx_loop        = false,
    effect_destroy_way_is_immediately = false,
})

-- ===================== 投射物定义 =====================

local projectiles = {

    -- 普攻箭矢（独立 key）
    basic_attack = od.extend('projectile', 'basic_projectile', {
        key  = 134244467,
        name = '普攻箭矢',
    }),

    -- 月刃（独立 key）
    moon_blade = od.extend('projectile', 'basic_projectile', {
        key  = 201392001,
        name = '月刃',
    }),

    -- 剑气波
    sword_wave = od.extend('projectile', 'basic_projectile', {
        key  = 201392002,
        name = '剑气波',
    }),

    -- 地震冲击
    earthquake = od.extend('projectile', 'basic_projectile', {
        key  = 201392003,
        name = '地震冲击',
    }),

    -- 莲火
    lotus_flame = od.extend('projectile', 'basic_projectile', {
        key  = 201392011,
        name = '莲火',
    }),

    -- 火球
    fireball = od.extend('projectile', 'basic_projectile', {
        key  = 201392012,
        name = '火球',
    }),

    -- 陨石
    meteor = od.extend('projectile', 'basic_projectile', {
        key  = 201392013,
        name = '陨石',
    }),

    -- 冰霜新星
    frost_nova = od.extend('projectile', 'basic_projectile', {
        key  = 201392022,
        name = '冰霜新星',
    }),

    -- 恶魔封印
    demon_seal = od.extend('projectile', 'basic_projectile', {
        key  = 201392023,
        name = '恶魔封印',
    }),

    -- 狙击箭（arcanelaser 共用）
    sniper_arrow = od.extend('projectile', 'basic_projectile', {
        key  = 201392031,
        name = '狙击箭',
    }),

    -- 疾风箭（arcane_ray 共用）
    gale_arrow = od.extend('projectile', 'basic_projectile', {
        key  = 201392032,
        name = '疾风箭',
    }),

    -- 多重箭（flying_swords 共用）
    multishot = od.extend('projectile', 'basic_projectile', {
        key  = 201392033,
        name = '多重箭',
    }),

    -- 电网
    electro_net = od.extend('projectile', 'basic_projectile', {
        key  = 201392042,
        name = '电网',
    }),

    -- 连锁闪电
    chain_lightning = od.extend('projectile', 'basic_projectile', {
        key  = 201392043,
        name = '连锁闪电',
    }),

    -- 龙卷风
    tornado = od.extend('projectile', 'basic_projectile', {
        key  = 201392062,
        name = '龙卷风',
    }),

    -- 飓风
    hurricane = od.extend('projectile', 'basic_projectile', {
        key  = 201392063,
        name = '飓风',
    }),
}

return projectiles
