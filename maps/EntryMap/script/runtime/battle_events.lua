local M = {}

function M.create(dependencies)
    local event_bus = dependencies.event_bus
    local audio_system = dependencies.audio_system
    local reward_system = dependencies.reward_system
    local battlefield_system = dependencies.battlefield_system
    local message = dependencies.message
    
    local logger = dependencies.logger('BattleEvents')
    
    local function on_wave_started(wave_index)
        logger.info('Wave started', { wave_index = wave_index })
        
        if audio_system and audio_system.handle_wave_started then
            audio_system.handle_wave_started(wave_index)
        end
        
        if reward_system and reward_system.handle_wave_started then
            reward_system.handle_wave_started(wave_index)
        end
        
        event_bus.publish('wave.start', { wave_index = wave_index })
    end
    
    local function on_boss_spawned(boss_info)
        logger.info('Boss spawned', { boss_info = boss_info })
        
        if audio_system and audio_system.handle_boss_spawned then
            audio_system.handle_boss_spawned(boss_info)
        end
        
        if reward_system and reward_system.handle_boss_spawned then
            reward_system.handle_boss_spawned()
        end
        
        event_bus.publish('boss.spawn', boss_info)
    end
    
    local function on_boss_warning(wave, remain)
        logger.info('Boss warning', { wave = wave, remain = remain })
        
        if audio_system and audio_system.handle_boss_warning then
            return audio_system.handle_boss_warning(wave, remain)
        end
        
        event_bus.publish('boss.warning', { wave = wave, remain = remain })
        return nil
    end
    
    local function on_hero_be_hurt(data)
        logger.info('Hero hurt', data)
        
        if audio_system and audio_system.handle_hero_be_hurt then
            audio_system.handle_hero_be_hurt()
        end
        
        if reward_system and reward_system.handle_hero_be_hurt then
            reward_system.handle_hero_be_hurt()
        end
        
        event_bus.publish('hero.hurt', data)
    end
    
    local function on_enemy_killed(info)
        logger.info('Enemy killed', info)
        
        event_bus.publish('enemy.kill', info)
    end
    
    local function on_challenge_started(instance)
        logger.info('Challenge started', { challenge_id = instance.id })
        
        if audio_system and audio_system.handle_challenge_started then
            audio_system.handle_challenge_started(instance)
        end
        
        if reward_system and reward_system.handle_challenge_started then
            reward_system.handle_challenge_started(instance)
        end
        
        event_bus.publish('challenge.start', instance)
    end
    
    local function on_challenge_finished(instance, is_success)
        logger.info('Challenge finished', { challenge_id = instance.id, success = is_success })
        
        if audio_system and audio_system.handle_challenge_finished then
            audio_system.handle_challenge_finished(instance, is_success)
        end
        
        if reward_system and reward_system.handle_challenge_finished then
            reward_system.handle_challenge_finished(instance, is_success)
        end
        
        event_bus.publish('challenge.end', { instance = instance, success = is_success })
    end
    
    local function on_skill_cast(skill, target)
        logger.debug('Skill cast', { skill_id = skill.id, target = target and target:is_exist() and 'valid' or 'invalid' })
        
        if audio_system and audio_system.play_attack_skill then
            audio_system.play_attack_skill(skill, target)
        end
        
        event_bus.publish('skill.cast', { skill = skill, target = target })
    end
    
    local function on_battle_finish(result)
        logger.info('Battle finished', { is_win = result.is_win })
        
        if audio_system and audio_system.handle_battle_finished then
            audio_system.handle_battle_finished(result)
        end
        
        event_bus.publish('battle.end', result)
    end
    
    local function on_reward_granted(reward)
        logger.info('Reward granted', reward)
        
        event_bus.publish('reward.granted', reward)
    end
    
    return {
        on_wave_started = on_wave_started,
        on_boss_spawned = on_boss_spawned,
        on_boss_warning = on_boss_warning,
        on_hero_be_hurt = on_hero_be_hurt,
        on_enemy_killed = on_enemy_killed,
        on_challenge_started = on_challenge_started,
        on_challenge_finished = on_challenge_finished,
        on_skill_cast = on_skill_cast,
        on_battle_finish = on_battle_finish,
        on_reward_granted = on_reward_granted,
        
        subscribe = function()
            event_bus.on('wave.start', on_wave_started)
            event_bus.on('boss.spawn', on_boss_spawned)
            event_bus.on('hero.hurt', on_hero_be_hurt)
            event_bus.on('enemy.kill', on_enemy_killed)
            event_bus.on('challenge.start', on_challenge_started)
            event_bus.on('challenge.end', function(data)
                on_challenge_finished(data.instance, data.success)
            end)
            event_bus.on('skill.cast', function(data)
                on_skill_cast(data.skill, data.target)
            end)
            event_bus.on('battle.end', on_battle_finish)
            event_bus.on('reward.granted', on_reward_granted)
        end
    }
end

return M