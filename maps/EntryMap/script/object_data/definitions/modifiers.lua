---魔法效果（Buff/Modifier）物编定义
---从 runtime_editor_ids.lua 的 modifier 表迁移，所有 key 与编辑器中一致。
---分为三类：attack_status（攻击附加状态）、auto_active_effect（自动触发效果）、bond_status（羁绊状态）。

local od = require 'object_data'
local E = od

-- ===================== 共用模板 =====================

od.define_template('buff', 'attack_status_base', {
    modifier_type       = E.ModifierType.DEBUFF,
    modifier_effect     = E.ModifierEffectType.GENERAL,
    modifier_cover_type = E.ModifierCoverType.REFRESH,
    layer_max           = 1,
    cycle_time          = 1.0,
    disappear_when_dead = true,
    show_on_ui          = true,
    target_allow        = E.TargetAllow.ENEMY,
})

od.define_template('buff', 'auto_active_base', {
    modifier_type       = E.ModifierType.BUFF,
    modifier_effect     = E.ModifierEffectType.GENERAL,
    modifier_cover_type = E.ModifierCoverType.REFRESH,
    layer_max           = 1,
    disappear_when_dead = true,
    show_on_ui          = true,
    target_allow        = E.TargetAllow.SELF,
})

od.define_template('buff', 'bond_status_base', {
    modifier_type       = E.ModifierType.NEUTRAL,
    modifier_effect     = E.ModifierEffectType.GENERAL,
    modifier_cover_type = E.ModifierCoverType.REFRESH,
    layer_max           = 1,
    disappear_when_dead = true,
    show_on_ui          = true,
})

-- ===================== 攻击附加状态 =====================

local modifiers = {

    -- ---------- attack_status ----------
    ignite = od.extend('buff', 'attack_status_base', {
        key  = 201390101,
        name = '点燃',
        modifier_icon = nil,
        kv = {
            category    = 'attack_status',
            status_type = 'ignite',
            description = '持续灼烧伤害',
        },
    }),

    armor_break = od.extend('buff', 'attack_status_base', {
        key  = 201390102,
        name = '破甲',
        modifier_icon = nil,
        kv = {
            category    = 'attack_status',
            status_type = 'armor_break',
            description = '降低物理防御',
        },
    }),

    shock = od.extend('buff', 'attack_status_base', {
        key  = 201390103,
        name = '感电',
        modifier_icon = nil,
        kv = {
            category    = 'attack_status',
            status_type = 'shock',
            description = '额外连锁伤害',
        },
    }),

    -- ---------- auto_active_effect ----------
    rapid_overdrive = od.extend('buff', 'auto_active_base', {
        key  = 201390104,
        name = '急速超载',
        kv = {
            category    = 'auto_active_effect',
            effect_id   = 'rapid_overdrive',
            description = '攻速爆发',
        },
    }),

    charge_breaker_rally = od.extend('buff', 'auto_active_base', {
        key  = 201390105,
        name = '破军集结',
        kv = {
            category    = 'auto_active_effect',
            effect_id   = 'charge_breaker_rally',
            description = '破军效果集结',
        },
    }),

    fighting_spirit_field = od.extend('buff', 'auto_active_base', {
        key  = 201365014,
        name = '斗魂领域',
        kv = {
            category    = 'auto_active_effect',
            effect_id   = 'fighting_spirit_field',
            description = '持续斗魂光环',
        },
    }),

    -- ---------- bond_status（复用 auto_active 的编辑器 key，运行时重命名）----------
    berserker_frenzy = od.extend('buff', 'bond_status_base', {
        key  = 201390104,
        name = '狂战士之怒',
        kv = {
            category    = 'bond_status',
            bond_name   = 'berserker',
            reuse_key_of = 'rapid_overdrive',
            description = '狂战士羁绊状态',
        },
    }),

    magic_swordsman_demon = od.extend('buff', 'bond_status_base', {
        key  = 201390105,
        name = '魔剑士恶魔',
        kv = {
            category    = 'bond_status',
            bond_name   = 'magic_swordsman',
            reuse_key_of = 'charge_breaker_rally',
            description = '魔剑士羁绊状态',
        },
    }),
}

return modifiers
