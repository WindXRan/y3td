local theme = require 'ui.theme'
local Factory = require 'ui.factory'
local skin = require 'ui.skin'

local M = {}

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local factory = Factory.create(env)

  local create_panel = factory.create_panel
  local create_text = factory.create_text
  local create_button = factory.create_button
  local set_percent_pos = factory.set_percent_pos
  local get_hud_metrics = factory.get_hud_metrics
  local get_hud_scale = factory.get_hud_scale
  local scaled = factory.scaled
  local overview_skin = skin.images.overview or {}

  local function get_hud_root()
    local ok, hud = pcall(y3.ui.get_ui, env.get_player(), 'GameHUD')
    if not ok or not hud then
      return nil
    end
    return hud
  end

  local function is_panel_alive(panel)
    return panel
      and panel.root
      and not panel.root:is_removed()
  end

  local function create_section(parent, x, y, width, height, title)
    local bg = create_panel(
      parent,
      x,
      y,
      width,
      height,
      theme.palette.panel_alt,
      theme.insets.normal,
      9821,
      overview_skin.section
    )
    local line = create_panel(
      bg,
      scaled(16, 1),
      height - scaled(24, 1),
      width - scaled(32, 1),
      scaled(4, 1),
      theme.palette.accent,
      { 8, 8, 8, 8 },
      9822
    )
    local title_text = create_text(
      bg,
      scaled(18, 1),
      height - scaled(14, 1),
      width - scaled(36, 1),
      scaled(18, 1),
      scaled(12, 1),
      theme.palette.text,
      '左',
      '中',
      9823
    )
    title_text:set_text(title)
    local body_text = create_text(
      bg,
      scaled(18, 1),
      height - scaled(42, 1),
      width - scaled(36, 1),
      height - scaled(56, 1),
      scaled(11, 1),
      theme.palette.text_soft,
      '左',
      '上',
      9823
    )
    return {
      bg = bg,
      line = line,
      title = title_text,
      body = body_text,
    }
  end

  local function create_overview_panel()
    local hud = get_hud_root()
    if not hud then
      return nil
    end

    if is_panel_alive(STATE.runtime_overview) then
      return STATE.runtime_overview
    end

    local _, _ = get_hud_metrics(hud, y3)
    local scale = get_hud_scale(hud, y3)

    local root = create_panel(
      hud,
      0,
      0,
      scaled(1300, scale),
      scaled(760, scale),
      { 8, 14, 24, 228 },
      { 26, 26, 26, 26 },
      9810,
      overview_skin.root
    )
    root:set_anchor(0.5, 0.5)
    root:set_intercepts_operations(true)
    set_percent_pos(env.get_player(), root, 50, 52)

    local glow = create_panel(
      root,
      scaled(650, scale),
      scaled(716, scale),
      scaled(1120, scale),
      scaled(42, scale),
      { 58, 108, 178, 48 },
      { 10, 10, 10, 10 },
      9811,
      overview_skin.glow
    )
    glow:set_anchor(0.5, 0.5)

    local title = create_text(
      root,
      scaled(36, scale),
      scaled(722, scale),
      scaled(480, scale),
      scaled(28, scale),
      scaled(22, scale),
      theme.palette.text,
      '左',
      '中',
      9812
    )
    title:set_text('局内构筑总览')

    local subtitle = create_text(
      root,
      scaled(36, scale),
      scaled(694, scale),
      scaled(720, scale),
      scaled(18, scale),
      scaled(11, scale),
      theme.palette.text_muted,
      '左',
      '中',
      9812
    )
    subtitle:set_text('按 B 可展开 / 收起，战斗不会暂停')

    local close_button = create_button(
      root,
      scaled(1170, scale),
      scaled(700, scale),
      scaled(90, scale),
      scaled(32, scale),
      '关闭 B',
      function()
        if env.toggle_overview then
          env.toggle_overview(false)
        end
      end,
      {
        font_size = scaled(12, scale),
        style = 'overview_close',
      }
    )

    local sections = {
      summary = create_section(root, scaled(36, scale), scaled(494, scale), scaled(592, scale), scaled(178, scale), '战况摘要'),
      skills = create_section(root, scaled(36, scale), scaled(260, scale), scaled(592, scale), scaled(214, scale), '攻击技能'),
      bonds = create_section(root, scaled(36, scale), scaled(34, scale), scaled(592, scale), scaled(206, scale), '链式羁绊'),
      treasures = create_section(root, scaled(672, scale), scaled(494, scale), scaled(592, scale), scaled(178, scale), '宝物与进化'),
      pending = create_section(root, scaled(672, scale), scaled(260, scale), scaled(592, scale), scaled(214, scale), '待处理轮次'),
      progress = create_section(root, scaled(672, scale), scaled(34, scale), scaled(592, scale), scaled(206, scale), '链路进度'),
    }

    local panel = {
      root = root,
      glow = glow,
      title = title,
      subtitle = subtitle,
      close_button = close_button,
      sections = sections,
      visible = false,
    }

    root:set_visible(false)
    STATE.runtime_overview = panel
    return panel
  end

  local function join_lines(lines)
    if not lines or #lines == 0 then
      return '暂无。'
    end
    return table.concat(lines, '\n')
  end

  local function refresh_overview()
    local panel = STATE.runtime_overview
    if not is_panel_alive(panel) or panel.visible ~= true then
      return
    end

    local model = env.get_runtime_overview_model and env.get_runtime_overview_model() or nil
    if not model then
      return
    end

    panel.title:set_text(model.title or '局内构筑总览')
    panel.subtitle:set_text(model.subtitle or '')

    if panel.close_button and panel.close_button.button then
      panel.close_button.button:set_text(model.close_label or '关闭 B')
    end

    for key, section in pairs(panel.sections) do
      local data = model.sections and model.sections[key] or nil
      if data then
        section.title:set_text(data.title or '')
        section.body:set_text(join_lines(data.lines))
      else
        section.body:set_text('暂无。')
      end
    end
  end

  local function set_visible(visible)
    local panel = create_overview_panel()
    if not panel then
      return
    end

    panel.visible = visible == true
    panel.root:set_visible(panel.visible)
    if panel.visible then
      refresh_overview()
    end
  end

  local function toggle_overview(force_visible)
    local panel = create_overview_panel()
    if not panel then
      return false
    end

    local next_visible = force_visible
    if next_visible == nil then
      next_visible = not (panel.visible == true)
    end
    set_visible(next_visible)
    return next_visible
  end

  return {
    ensure_panel = create_overview_panel,
    refresh_overview = refresh_overview,
    set_visible = set_visible,
    toggle_overview = toggle_overview,
  }
end

return M
