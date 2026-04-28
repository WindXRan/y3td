local HeroTujianPanelSystem = require 'runtime.hero_tujian_panel'

local M = {}

function M.create(args)
  return HeroTujianPanelSystem.create({
    STATE = args.STATE,
    y3 = args.y3,
    get_player = args.get_player,
    message = args.message,
    play_ui_click = function()
      local audio_system = args.get_audio_system and args.get_audio_system() or nil
      return audio_system and audio_system.play_ui_click and audio_system.play_ui_click() or nil
    end,
    get_all_hero_growth = function()
      local outgame_system = args.get_outgame_system and args.get_outgame_system() or nil
      return outgame_system and outgame_system.get_all_hero_growth and outgame_system.get_all_hero_growth() or {}
    end,
    get_hero_growth = function(hero_ref)
      local outgame_system = args.get_outgame_system and args.get_outgame_system() or nil
      return outgame_system and outgame_system.get_hero_growth and outgame_system.get_hero_growth(hero_ref) or nil
    end,
    try_hero_star_up = function(hero_ref)
      local outgame_system = args.get_outgame_system and args.get_outgame_system() or nil
      return outgame_system and outgame_system.try_hero_star_up and outgame_system.try_hero_star_up(hero_ref) or false,
          '升星接口未就绪'
    end,
    try_hero_awaken = function(hero_ref)
      local outgame_system = args.get_outgame_system and args.get_outgame_system() or nil
      return outgame_system and outgame_system.try_hero_awaken and outgame_system.try_hero_awaken(hero_ref) or false,
          '觉醒接口未就绪'
    end,
    get_awaken_stone = function()
      local outgame_system = args.get_outgame_system and args.get_outgame_system() or nil
      return outgame_system and outgame_system.get_awaken_stone and outgame_system.get_awaken_stone() or 0
    end,
  })
end

return M
