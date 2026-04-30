y3.const.UnitAttr = y3.const.UnitAttr or {}

-- 项目自定义属性（保留稳定 GUID）
y3.const.UnitAttr["每秒攻击"] = "vPjmOECQEfGNKa+mTm-Qh9"
y3.const.UnitAttr["物理暴率(%)"] = "EgTi7UCPEfG4da+mTm-Qh3"
y3.const.UnitAttr["物理暴伤(%)"] = "HIQO3ECPEfGP0a+mTm-Qh4"
y3.const.UnitAttr["杀敌金币"] = "s7JReUCPEfG-fK+mTm-Qh4"
y3.const.UnitAttr["攻击力"] = "lvEINECQEfGzu6+mTm-Qh0"
y3.const.UnitAttr["攻击加成(%)"] = "0ySlikCREfG5ba+mTm-Qhx"
y3.const.UnitAttr["金币"] = "agrpV0CSEfGF9a+mTm-Qh8"
y3.const.UnitAttr["木头"] = "auiW6UCSEfGQ7a+mTm-Qh9"
y3.const.UnitAttr["杀敌"] = "a03Tl0CSEfG-Gq+mTm-Qhw"
y3.const.UnitAttr["射箭伤害(%)"] = "d+czJUCkEfGjbJNJUD+NS7"
y3.const.UnitAttr["物理伤害(%)"] = "DPWiRUCqEfGqR5NJUD+NS5"
y3.const.UnitAttr["多重数量"] = "QNqDJkClEfGYcZNJUD+NS7"
y3.const.UnitAttr["护甲穿透(%)"] = "ZlSKk0ClEfGUfJNJUD+NS0"
y3.const.UnitAttr["攻击成长"] = "hs6TFUCrEfGnzJNJUD+NSz"
y3.const.UnitAttr["生命成长"] = "jREzvECrEfGvTpNJUD+NS6"
y3.const.UnitAttr["力量成长"] = "j-69u0CrEfGbeJNJUD+NS+"
y3.const.UnitAttr["敏捷成长"] = "kZMysUCrEfGvFZNJUD+NS+"
y3.const.UnitAttr["智力成长"] = "kvx8jECrEfGshpNJUD+NSw"
y3.const.UnitAttr["护甲加成(%)"] = "T9BK1kCsEfG-PJNJUD+NS3"
y3.const.UnitAttr["生命加成(%)"] = "TNqVZkCsEfGcCpNJUD+NS4"
y3.const.UnitAttr["移速马甲"] = "bk+jnkZsEe+VkzDQQukOhb"
y3.const.UnitAttr["韧性"] = "custom_1"

-- 基础主属性
y3.const.UnitAttr["力量"] = "strength"
y3.const.UnitAttr["敏捷"] = "agility"
y3.const.UnitAttr["智力"] = "intelligence"
y3.const.UnitAttr["主属性"] = "main"

-- 项目常用别名（仅别名，不新增 GUID）
y3.const.UnitAttr["攻击"] = y3.const.UnitAttr["攻击力"]
y3.const.UnitAttr["物理攻击"] = y3.const.UnitAttr["攻击力"]
y3.const.UnitAttr["物理暴击"] = y3.const.UnitAttr["物理暴率(%)"]
y3.const.UnitAttr["物理暴伤"] = y3.const.UnitAttr["物理暴伤(%)"]
y3.const.UnitAttr["护甲穿透"] = y3.const.UnitAttr["护甲穿透(%)"]
y3.const.UnitAttr["物理伤害"] = y3.const.UnitAttr["物理伤害(%)"]
y3.const.UnitAttr["攻击加成"] = y3.const.UnitAttr["攻击加成(%)"]
y3.const.UnitAttr["护甲加成"] = y3.const.UnitAttr["护甲加成(%)"]
y3.const.UnitAttr["生命加成"] = y3.const.UnitAttr["生命加成(%)"]

---@enum(key, partial) y3.Const.UnitAttr
---@diagnostic disable-next-line: inject-field
y3.const.CustomUnitAttr = {
    ["每秒攻击"] = "vPjmOECQEfGNKa+mTm-Qh9",
    ["物理暴率(%)"] = "EgTi7UCPEfG4da+mTm-Qh3",
    ["物理暴伤(%)"] = "HIQO3ECPEfGP0a+mTm-Qh4",
    ["杀敌金币"] = "s7JReUCPEfG-fK+mTm-Qh4",
    ["攻击力"] = "lvEINECQEfGzu6+mTm-Qh0",
    ["攻击加成(%)"] = "0ySlikCREfG5ba+mTm-Qhx",
    ["金币"] = "agrpV0CSEfGF9a+mTm-Qh8",
    ["木头"] = "auiW6UCSEfGQ7a+mTm-Qh9",
    ["杀敌"] = "a03Tl0CSEfG-Gq+mTm-Qhw",
    ["射箭伤害(%)"] = "d+czJUCkEfGjbJNJUD+NS7",
    ["物理伤害(%)"] = "DPWiRUCqEfGqR5NJUD+NS5",
    ["多重数量"] = "QNqDJkClEfGYcZNJUD+NS7",
    ["护甲穿透(%)"] = "ZlSKk0ClEfGUfJNJUD+NS0",
    ["攻击成长"] = "hs6TFUCrEfGnzJNJUD+NSz",
    ["生命成长"] = "jREzvECrEfGvTpNJUD+NS6",
    ["力量成长"] = "j-69u0CrEfGbeJNJUD+NS+",
    ["敏捷成长"] = "kZMysUCrEfGvFZNJUD+NS+",
    ["智力成长"] = "kvx8jECrEfGshpNJUD+NSw",
    ["护甲加成(%)"] = "T9BK1kCsEfG-PJNJUD+NS3",
    ["生命加成(%)"] = "TNqVZkCsEfGcCpNJUD+NS4",
    ["移速马甲"] = "bk+jnkZsEe+VkzDQQukOhb",
    ["韧性"] = "custom_1",
    ["力量"] = "strength",
    ["敏捷"] = "agility",
    ["智力"] = "intelligence",
    ["主属性"] = "main",
    ["攻击"] = "lvEINECQEfGzu6+mTm-Qh0",
    ["物理攻击"] = "lvEINECQEfGzu6+mTm-Qh0",
    ["物理暴击"] = "EgTi7UCPEfG4da+mTm-Qh3",
    ["物理暴伤"] = "HIQO3ECPEfGP0a+mTm-Qh4",
    ["护甲穿透"] = "ZlSKk0ClEfGUfJNJUD+NS0",
    ["物理伤害"] = "DPWiRUCqEfGqR5NJUD+NS5",
    ["攻击加成"] = "0ySlikCREfG5ba+mTm-Qhx",
    ["护甲加成"] = "T9BK1kCsEfG-PJNJUD+NS3",
    ["生命加成"] = "TNqVZkCsEfGcCpNJUD+NS4",
}

