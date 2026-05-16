
--[[
    事件订阅器 (Event Subscriber)
    提供按功能分组的事件订阅管理，支持批量订阅和统一取消订阅
    
    使用方式:
        local EventSubscriber = require 'core.event_subscriber'
        local subscriber = EventSubscriber.create(event_bus)
        
        -- 订阅战斗事件
        local battle_group = subscriber.battle({
            on_wave_start = function(data) print('Wave started:', data.round) end,
            on_wave_end = function(data) print('Wave ended') end,
            on_battle_start = function(data) print('Battle started') end
        })
        
        -- 订阅英雄事件
        local hero_group = subscriber.hero({
            on_hero_hurt = function(data) print('Hero hurt:', data.damage) end,
            on_hero_heal = function(data) print('Hero healed:', data.amount) end
        })
        
        -- 统一取消订阅
        battle_group.clear()
        hero_group.clear()
        
        -- 批量订阅多个类型
        local all_groups = subscriber.all({
            battle = { on_wave_start = handler1 },
            hero = { on_hero_hurt = handler2 },
            skill = { on_skill_cast = handler3 }
        })
        all_groups.clear_all()
]]

local M = {}

---
-- 创建事件订阅器实例
-- @param event_bus table EventBus实例
-- @return table 订阅器实例
---
function M.create(event_bus)
    local subscribers = {}

    ---
    -- 创建订阅组
    -- 用于管理一组相关的事件订阅
    -- @param name string 组名称
    -- @return table 订阅组实例
    ---
    local function create_subscription_group(name)
        local group = {
            handlers = {},  -- 已注册的处理器列表
            name = name     -- 组名称
        }

        ---
        -- 订阅事件
        -- @param event_name string 事件名称
        -- @param handler function 事件处理器
        -- @return function 取消订阅函数
        ---
        function group.on(event_name, handler)
            local unsubscribe = event_bus.on(event_name, handler)
            table.insert(group.handlers, {
                event_name = event_name,
                handler = handler,
                unsubscribe = unsubscribe
            })
            return unsubscribe
        end

        ---
        -- 一次性订阅事件
        -- @param event_name string 事件名称
        -- @param handler function 事件处理器
        -- @return function 取消订阅函数
        ---
        function group.once(event_name, handler)
            local unsubscribe = event_bus.once(event_name, handler)
            table.insert(group.handlers, {
                event_name = event_name,
                handler = handler,
                unsubscribe = unsubscribe
            })
            return unsubscribe
        end

        ---
        -- 取消特定事件的订阅
        -- @param event_name string 事件名称
        -- @param handler function 要移除的处理器
        ---
        function group.off(event_name, handler)
            for i, h in ipairs(group.handlers) do
                if h.event_name == event_name and h.handler == handler then
                    h.unsubscribe()
                    table.remove(group.handlers, i)
                    break
                end
            end
        end

        ---
        -- 清空所有订阅
        ---
        function group.clear()
            for _, h in ipairs(group.handlers) do
                h.unsubscribe()
            end
            group.handlers = {}
        end

        ---
        -- 获取订阅数量
        -- @return number 订阅数量
        ---
        function group.count()
            return #group.handlers
        end

        return group
    end

    ---
    -- 订阅战斗相关事件
    -- @param handlers table 事件处理器配置
    -- @param handlers.on_wave_start function 波次开始处理器
    -- @param handlers.on_wave_end function 波次结束处理器
    -- @param handlers.on_battle_start function 战斗开始处理器
    -- @param handlers.on_battle_end function 战斗结束处理器
    -- @param handlers.on_boss_spawn function Boss出现处理器
    -- @param handlers.on_enemy_kill function 敌人击杀处理器
    -- @return table 订阅组实例
    ---
    local function subscribe_to_battle_events(handlers)
        local group = create_subscription_group('battle')

        if handlers.on_wave_start then
            group.on(event_bus.events.WAVE_START, handlers.on_wave_start)
        end
        if handlers.on_wave_end then
            group.on(event_bus.events.WAVE_END, handlers.on_wave_end)
        end
        if handlers.on_battle_start then
            group.on(event_bus.events.BATTLE_START, handlers.on_battle_start)
        end
        if handlers.on_battle_end then
            group.on(event_bus.events.BATTLE_END, handlers.on_battle_end)
        end
        if handlers.on_boss_spawn then
            group.on('boss.spawn', handlers.on_boss_spawn)
        end
        if handlers.on_enemy_kill then
            group.on(event_bus.events.ENEMY_KILL, handlers.on_enemy_kill)
        end

        return group
    end

    ---
    -- 订阅英雄相关事件
    -- @param handlers table 事件处理器配置
    -- @param handlers.on_hero_hurt function 英雄受伤处理器
    -- @param handlers.on_hero_heal function 英雄治疗处理器
    -- @param handlers.on_hero_death function 英雄死亡处理器
    -- @param handlers.on_hero_level_up function 英雄升级处理器
    -- @return table 订阅组实例
    ---
    local function subscribe_to_hero_events(handlers)
        local group = create_subscription_group('hero')

        if handlers.on_hero_hurt then
            group.on(event_bus.events.HERO_HURT, handlers.on_hero_hurt)
        end
        if handlers.on_hero_heal then
            group.on(event_bus.events.HERO_HEAL, handlers.on_hero_heal)
        end
        if handlers.on_hero_death then
            group.on('hero.death', handlers.on_hero_death)
        end
        if handlers.on_hero_level_up then
            group.on('hero.level_up', handlers.on_hero_level_up)
        end

        return group
    end

    ---
    -- 订阅技能相关事件
    -- @param handlers table 事件处理器配置
    -- @param handlers.on_skill_cast function 技能释放处理器
    -- @param handlers.on_skill_hit function 技能命中处理器
    -- @param handlers.on_skill_end function 技能结束处理器
    -- @return table 订阅组实例
    ---
    local function subscribe_to_skill_events(handlers)
        local group = create_subscription_group('skill')

        if handlers.on_skill_cast then
            group.on(event_bus.events.SKILL_CAST, handlers.on_skill_cast)
        end
        if handlers.on_skill_hit then
            group.on('skill.hit', handlers.on_skill_hit)
        end
        if handlers.on_skill_end then
            group.on('skill.end', handlers.on_skill_end)
        end

        return group
    end

    ---
    -- 订阅奖励相关事件
    -- @param handlers table 事件处理器配置
    -- @param handlers.on_reward_granted function 奖励发放处理器
    -- @param handlers.on_choice_made function 选择完成处理器
    -- @return table 订阅组实例
    ---
    local function subscribe_to_reward_events(handlers)
        local group = create_subscription_group('reward')

        if handlers.on_reward_granted then
            group.on(event_bus.events.REWARD_GRANTED, handlers.on_reward_granted)
        end
        if handlers.on_choice_made then
            group.on(event_bus.events.CHOICE_MADE, handlers.on_choice_made)
        end

        return group
    end

    ---
    -- 订阅挑战相关事件
    -- @param handlers table 事件处理器配置
    -- @param handlers.on_challenge_start function 挑战开始处理器
    -- @param handlers.on_challenge_end function 挑战结束处理器
    -- @return table 订阅组实例
    ---
    local function subscribe_to_challenge_events(handlers)
        local group = create_subscription_group('challenge')

        if handlers.on_challenge_start then
            group.on(event_bus.events.CHALLENGE_START, handlers.on_challenge_start)
        end
        if handlers.on_challenge_end then
            group.on(event_bus.events.CHALLENGE_END, handlers.on_challenge_end)
        end

        return group
    end

    ---
    -- 订阅UI相关事件
    -- @param handlers table 事件处理器配置
    -- @param handlers.on_ui_phase_change function 阶段变更处理器
    -- @param handlers.on_ui_notify function 通知处理器
    -- @param handlers.on_ui_panel_open function 面板打开处理器
    -- @param handlers.on_ui_panel_close function 面板关闭处理器
    -- @return table 订阅组实例
    ---
    local function subscribe_to_ui_events(handlers)
        local group = create_subscription_group('ui')

        if handlers.on_ui_phase_change then
            group.on('ui.phase.change', handlers.on_ui_phase_change)
        end
        if handlers.on_ui_notify then
            group.on('ui.notify', handlers.on_ui_notify)
        end
        if handlers.on_ui_panel_open then
            group.on('ui.panel.open', handlers.on_ui_panel_open)
        end
        if handlers.on_ui_panel_close then
            group.on('ui.panel.close', handlers.on_ui_panel_close)
        end

        return group
    end

    -- === 公开 API ===

    ---
    -- 创建自定义订阅组
    -- @param name string 组名称
    -- @return table 订阅组实例
    ---
    function subscribers.create_group(name)
        return create_subscription_group(name)
    end

    ---
    -- 订阅战斗事件
    -- @param handlers table 事件处理器配置
    -- @return table 订阅组实例
    ---
    function subscribers.battle(handlers)
        return subscribe_to_battle_events(handlers)
    end

    ---
    -- 订阅英雄事件
    -- @param handlers table 事件处理器配置
    -- @return table 订阅组实例
    ---
    function subscribers.hero(handlers)
        return subscribe_to_hero_events(handlers)
    end

    ---
    -- 订阅技能事件
    -- @param handlers table 事件处理器配置
    -- @return table 订阅组实例
    ---
    function subscribers.skill(handlers)
        return subscribe_to_skill_events(handlers)
    end

    ---
    -- 订阅奖励事件
    -- @param handlers table 事件处理器配置
    -- @return table 订阅组实例
    ---
    function subscribers.reward(handlers)
        return subscribe_to_reward_events(handlers)
    end

    ---
    -- 订阅挑战事件
    -- @param handlers table 事件处理器配置
    -- @return table 订阅组实例
    ---
    function subscribers.challenge(handlers)
        return subscribe_to_challenge_events(handlers)
    end

    ---
    -- 订阅UI事件
    -- @param handlers table 事件处理器配置
    -- @return table 订阅组实例
    ---
    function subscribers.ui(handlers)
        return subscribe_to_ui_events(handlers)
    end

    ---
    -- 批量订阅所有类型事件
    -- @param handlers table 各类型事件处理器配置
    -- @return table 包含所有订阅组的对象
    ---
    function subscribers.all(handlers)
        local groups = {}

        if handlers.battle then
            groups.battle = subscribers.battle(handlers.battle)
        end
        if handlers.hero then
            groups.hero = subscribers.hero(handlers.hero)
        end
        if handlers.skill then
            groups.skill = subscribers.skill(handlers.skill)
        end
        if handlers.reward then
            groups.reward = subscribers.reward(handlers.reward)
        end
        if handlers.challenge then
            groups.challenge = subscribers.challenge(handlers.challenge)
        end
        if handlers.ui then
            groups.ui = subscribers.ui(handlers.ui)
        end

        ---
        -- 清空所有订阅组
        ---
        function groups.clear_all()
            for _, group in pairs(groups) do
                group.clear()
            end
        end

        return groups
    end

    return subscribers
end

return M
