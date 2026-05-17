local M = {}
local SessionStateSystem = require 'runtime.session_state'
local OutgameSystem = require 'ui.outgame'
local BootHelpers = require 'runtime.boot_helpers'

function M.create()
  _G.RuntimeEntry.validate_config = function()
    local bfs = _G.battlefield_system
    return bfs and bfs.validate_config and bfs.validate_config()
  end

  local session_state_system = SessionStateSystem.create({
    SkillRuntime = _G.SkillRuntime,
    SkillState = _G.SkillState,
    create_hero = function()
      local bfs = _G.battlefield_system
      local hero = bfs and bfs.create_hero(_G.ATTACK_SKILL_DEFS.basic_attack.base_range or 250)
      if _G.STATE.fixed_camera_enabled == true then
        _G.RuntimeEntry.sync_fixed_camera_mode()
      end
      return hero
    end,
  })

  local outgame_system = OutgameSystem.create({
    STATE = _G.STATE,
    CONFIG = _G.CONFIG,
    y3 = y3,
    message = _G.message,
    play_ui_click = function()
      local audio = _G.audio_system
      return audio and audio.play_ui_click and audio.play_ui_click() or nil
    end,
    ensure_music_loop = function()
      local audio = _G.audio_system
      return audio and audio.ensure_music_loop and audio.ensure_music_loop() or nil
    end,
    get_player = BootHelpers.get_player,
    set_battle_hud_visible = _G.set_battle_hud_visible,
    stage_runtime = {
      get_current_stage_text = function()
        local def = _G.STATE.current_stage_def
        if def and (def.display_label or def.display_name) then
          return def.display_label or def.display_name
        end
        return '第1关'
      end,
      start_selected_stage = session_state_system.start_selected_stage,
    },
  })

  _G.outgame_system = outgame_system
  _G.session_state_system = session_state_system

  return {
    session_state_system = session_state_system,
    outgame_system = outgame_system,
    is_battle_active = session_state_system.is_battle_active,
    reset_battle_state = session_state_system.reset_battle_state,
    reset_session_state = session_state_system.reset_session_state,
  }
end

return M
