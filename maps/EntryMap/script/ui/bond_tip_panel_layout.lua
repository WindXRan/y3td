local M = {}

M.panel_name = 'CardSetEffectTipPanel'

M.nodes = {
  panel = 'CardSetEffectTipPanel.panel_card_set_tip',
  quality_badge = 'label_quality_badge',
  set_name = 'label_set_name',
  set_progress = 'label_set_progress',
  item_icon = 'image_item_icon',
  item_name = 'label_item_name',
  effect_area = 'layout_effect_area',
  effect_index = 'label_effect_index',
  effect_name = 'label_effect_name',
  effect_body = 'label_effect_body',
  set_title = 'label_set_title',
  set_body = 'label_set_body',
  set_body_2 = 'label_set_body_2',
  set_body_3 = 'label_set_body_3',
  bonus = {
    'label_bonus_1',
    'label_bonus_2',
    'label_bonus_3',
  },
}

M.effect_area_y_by_bonus_count = {
  [0] = 272,
  [1] = 272,
  [2] = 286,
  [3] = 302,
}

return M
