local M = {}

M.common = {
  empty = 999,
}

M.win = {
  bg = 106330,
  confirm_btn = 100372,
}

M.loss = {
  bg = 106331,
  confirm_btn = 100372,
}

M.loading = {
  logo = 110020,
  progress_bg = 106409,
  progress_fill = 106408,
}

M.common_tip = {
  btn_blue_normal = 107525,
  btn_blue_hover = 107526,
  btn_blue_press = 107527,
  btn_blue_disabled = 107528,
  btn_red_normal = 107529,
  btn_red_hover = 107530,
  btn_red_press = 107531,
  btn_red_disabled = 107532,
  panel_bg = 109589,
}

M.logo_panel = {
  logo = 903956,
}

M.game_hud = {
  unit_slot_bg = 107333,
  unit_icon = 133028,
  hp_bar_bg = 133786,
  hp_bar_fill = 133787,
  mp_bar_fill = 133816,
  unit_highlight = 133783,
  exit_btn_normal = 903408,
  exit_btn_hover = 903407,
  exit_btn_press = 903406,
}

M.hero_prefab = {
  skill_disable = 106391,
  skill_normal = 108536,
  skill_press = 106390,
  skill_hover = 106388,
  panel_bg = 133829,
  panel_frame = 133828,
  panel_frame_alt = 133830,
  panel_decor = 133831,
  icon_1 = 133819,
}

-- Semantic UI skin slots.
-- Replace image ids here to swap the shipped look without touching UI logic files.
M.skin = {
  buttons = {
    primary = {
      normal = M.common_tip.btn_blue_normal,
      hover = M.common_tip.btn_blue_hover,
      press = M.common_tip.btn_blue_press,
      disabled = M.common_tip.btn_blue_disabled,
    },
    secondary = {
      normal = M.common_tip.btn_blue_normal,
      hover = M.common_tip.btn_blue_hover,
      press = M.common_tip.btn_blue_press,
      disabled = M.common_tip.btn_blue_disabled,
    },
    success = {
      normal = M.common_tip.btn_blue_normal,
      hover = M.common_tip.btn_blue_hover,
      press = M.common_tip.btn_blue_press,
      disabled = M.common_tip.btn_blue_disabled,
    },
  },
  images = {
    outgame = {
      backdrop = M.hero_prefab.panel_bg,
      vignette = M.hero_prefab.panel_frame_alt,
      header_band = M.hero_prefab.panel_frame_alt,
      footer_band = M.common_tip.panel_bg,
      edge_decor = M.hero_prefab.panel_decor,
      side_glow = M.common_tip.panel_bg,
      content_root = M.hero_prefab.panel_frame_alt,
      left_strip = M.hero_prefab.panel_decor,
      top_glow = M.common_tip.panel_bg,
      top_line = M.hero_prefab.panel_decor,
      title_logo = M.logo_panel.logo,
      stage_list_panel = M.hero_prefab.panel_frame,
      stage_list_icon = M.hero_prefab.icon_1,
      detail_panel = M.hero_prefab.panel_frame_alt,
      detail_hero = M.hero_prefab.panel_frame,
      detail_mode_block = M.hero_prefab.panel_bg,
      detail_footer = M.common_tip.panel_bg,
      stage_badge = M.common_tip.panel_bg,
      stage_badge_icon = M.hero_prefab.icon_1,
      detail_badge_decor = M.hero_prefab.panel_decor,
      mode_icon = M.hero_prefab.icon_1,
      start_button_bg = M.common_tip.btn_blue_normal,
      start_button_shadow = M.hero_prefab.panel_frame_alt,
      start_button_decor = M.logo_panel.logo,
      stage_card_bg = M.hero_prefab.panel_bg,
      stage_card_frame = M.hero_prefab.panel_frame,
      stage_card_icon = M.hero_prefab.icon_1,
      stage_card_badge = M.common_tip.panel_bg,
    },
    runtime_hud = {
      top_bar = M.hero_prefab.panel_frame_alt,
      top_bar_icon = M.hero_prefab.icon_1,
      left_bar = M.hero_prefab.panel_frame,
      bottom_bar = M.hero_prefab.panel_frame_alt,
      decision_root = M.hero_prefab.panel_frame_alt,
      decision_header_line = M.hero_prefab.panel_decor,
      decision_logo = M.logo_panel.logo,
      decision_option_shadow = M.hero_prefab.panel_frame_alt,
      decision_option_bg = M.hero_prefab.panel_bg,
      decision_option_badge = M.common_tip.panel_bg,
      decision_option_emblem = M.hero_prefab.icon_1,
      action_button_bg = M.hero_prefab.panel_frame,
      action_button_shadow = M.hero_prefab.panel_frame_alt,
      trial_button_bg = M.hero_prefab.panel_frame,
      trial_button_shadow = M.hero_prefab.panel_frame_alt,
    },
    choice_panel = {
      overlay = M.common_tip.panel_bg,
      panel_bg = M.common_tip.panel_bg,
      card_bg = M.hero_prefab.panel_bg,
      card_frame_common = M.hero_prefab.panel_frame,
      card_frame_rare = M.hero_prefab.panel_frame_alt,
      card_frame_epic = M.hero_prefab.panel_decor,
      badge_bg_common = M.common_tip.panel_bg,
      badge_bg_rare = M.common_tip.panel_bg,
      badge_bg_epic = M.common_tip.panel_bg,
      icon_frame = M.hero_prefab.panel_frame,
      action_button_bg = M.hero_prefab.panel_frame_alt,
      action_button_shadow = M.hero_prefab.panel_frame,
    },
    overview = {
      root = M.hero_prefab.panel_frame_alt,
      glow = M.common_tip.panel_bg,
      section = M.hero_prefab.panel_frame,
    },
  },
}

return M
