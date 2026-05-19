-- object_data 枚举常量（适配自走棋/羁绊玩法，精简自 xunhuanquan）
-- 所有枚举值均可在纯 Lua 环境中使用

local M = {}

-- ===================== 单位相关 =====================

M.UnitType = {
    HERO      = 0,
    BUILDING  = 1,
    CREATURE  = 2,
}

M.AttackType = {
    NORMAL  = 0,
    PIERCED = 1,
    SIEGE   = 2,
    MAGIC   = 3,
    CHAOS   = 4,
    HERO    = 5,
}

M.ArmorType = {
    LIGHT    = 0,
    MEDIUM   = 1,
    HEAVY    = 2,
    FORT     = 3,
    HERO     = 4,
    UNARMORED = 5,
}

M.MoveType = {
    LAND  = 0,
}

M.ViewType = {
    NORMAL    = 0,
    FLYING    = 1,
    INVISIBLE = 2,
}

M.DefaultBehaviour = {
    ATTACK = 0,
    HOLD   = 1,
    PATROL = 2,
    STAND  = 3,
    WANDER = 4,
}

M.BloodBarType = {
    DEFAULT = 0,
    CUSTOM1 = 1,
    CUSTOM2 = 2,
}

M.BloodShowType = {
    NEVER    = 0,
    SELECTED = 1,
    HOVER    = 2,
    ALWAYS   = 3,
    DAMAGED  = 4,
}

M.BarNameShowType = {
    NONE    = 0,
    NAME    = 1,
    LEVEL   = 2,
    NAME_LV = 3,
}

M.UnitState = {
    STUN      = 0,
    INVINCIBLE = 1,
    SILENCE   = 2,
    DISARM    = 3,
    ROOT      = 4,
    INVISIBLE = 5,
    UNSELECT  = 6,
}

-- ===================== 技能相关 =====================

M.AbilityType = {
    HERO    = 0,
    COMMON  = 1,
    PASSIVE = 2,
    ITEM    = 3,
}

M.AbilityCastType = {
    INSTANT     = 0,
    UNIT_TARGET = 1,
    POINT       = 2,
    UNIT_POINT  = 3,
    LINE_TARGET = 4,
    AREA_TARGET = 5,
    SELF        = 6,
    PASSIVE     = 7,
}

M.AbilityPointerType = {
    NONE      = 0,
    ARROW     = 1,
    CIRCLE    = 2,
    SECTOR    = 3,
    DOUBLE_C  = 4,
    LINE      = 5,
}

M.FilterCamp = {
    ALL      = 0,
    ENEMY    = 1,
    FRIENDLY = 2,
    SELF     = 3,
    ALLY     = 4,
}

M.FilterType = {
    ALL      = 0,
    UNIT     = 1,
    ITEM     = 2,
    DEST     = 3,
    BUILDING = 4,
    HERO     = 5,
}

M.AbilityStage = {
    PREPARE   = 0,
    CHANNEL   = 1,
    SHOOT     = 2,
    BACKSWING = 3,
}

-- ===================== 魔法效果相关 =====================

M.ModifierType = {
    BUFF    = 0,
    DEBUFF  = 1,
    NEUTRAL = 2,
}

M.ModifierEffectType = {
    GENERAL = 0,
    SHIELD  = 1,
    HALO    = 2,
    STATE   = 3,
}

M.ModifierCoverType = {
    COVER    = 0,
    STACK    = 1,
    REFRESH  = 2,
    NO_COVER = 3,
}

M.CoverChange = {
    KEEP_OLD = 0,
    USE_NEW  = 1,
}

M.ShieldType = {
    GENERAL  = 0,
    PHYSICAL = 1,
    MAGIC    = 2,
}

M.TargetAllow = {
    ALL      = 0,
    ENEMY    = 1,
    FRIENDLY = 2,
    SELF     = 3,
    ALLY     = 4,
    PLAYER   = 5,
}

-- ===================== 物品相关 =====================

M.StackType = {
    NONE   = 0,
    CHARGE = 1,
    STACK  = 2,
}

M.ItemBillboardType = {
    NONE = 0,
    NAME = 1,
    ICON = 2,
}

M.SlotType = {
    BAR = 0,
    PKG = 1,
}

-- ===================== 投射物相关 =====================

M.ProjectileMoveType = {
    LINEAR   = 0,
    PARABOLA = 1,
    TRACKING = 2,
    INSTANT  = 3,
}

-- ===================== 普攻类型 =====================

M.CommonAttackType = {
    NORMAL    = 0,
    CUSTOM    = 1,
    INSTANT   = 2,
    PROJECTILE = 3,
}

-- ===================== 碰撞 =====================

M.CollisionLayers = {
    LAND_UNIT    = 1,
    AIR_UNIT     = 2,
    WATER_UNIT   = 4,
    ITEM         = 8,
    BUILDING     = 16,
    DESTRUCTIBLE = 32,
}

-- ===================== 伤害 =====================

M.DamageType = {
    PHYSICAL = 0,
    MAGICAL  = 1,
    PURE     = 2,
}

-- ===================== 自走棋专用枚举（新增） =====================

---技能元素属性（五行）
M.Element = {
    METAL = 'metal',
    WOOD  = 'wood',
    WATER = 'water',
    FIRE  = 'fire',
    EARTH = 'earth',
    NONE  = 'none',
}

---技能伤害形式
M.DamageForm = {
    WEAPON = 'weapon',
    SPELL  = 'spell',
    PURE   = 'pure',
}

---羁绊触发类型
M.BondTrigger = {
    ON_HIT   = 'on_hit',
    ON_KILL  = 'on_kill',
    ON_CAST  = 'on_cast',
    PASSIVE  = 'passive',
}

---敌人类型
M.EnemyType = {
    NORMAL    = 'normal',
    ELITE     = 'elite',
    BOSS      = 'boss',
    CHALLENGE = 'challenge',
}

return M
