# -*- coding: utf-8 -*-
import re

# 读取文件
with open(r'd:\project\_codex_y3td_push\maps\EntryMap\script\ui\runtime_hud.lua', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复所有未闭合的字符串问题
fixes = [
    # 简单的未闭合字符串
    ("bt[#bt + 1] = '当前属性增幅", "bt[#bt + 1] = '当前属性增幅'"),
    ("set_title_text = '当前属性增幅,", "set_title_text = '当前属性增幅',"),
    ("set_body_lines = #attr_lines > 0 and attr_lines or { '当前无直接属性增幅", "set_body_lines = #attr_lines > 0 and attr_lines or { '当前无直接属性增幅'"),
    ("if bO ~= '' or bP ~= '' then bN[#bN + 1] = '流派 .. bO .. bP end;", "if bO ~= '' or bP ~= '' then bN[#bN + 1] = '流派' .. bO .. bP end;"),
    ("local bt = { '[左键点击]', '打开存档面板；如果当前没有可打开的存档界面，则显示运行时状态", "local bt = { '[左键点击]', '打开存档面板；如果当前没有可打开的存档界面，则显示运行时状态'"),
    ("title = '属性宝石,", "title = '属性宝石',"),
    ("body = '当前用于特殊功能扩展,", "body = '当前用于特殊功能扩展',"),
    ("tip_title = tostring(slot_data.name or slot_data.id or '技", "tip_title = tostring(slot_data.name or slot_data.id or '技能"),
    ("tip_text = #tip_lines > 0 and table.concat(tip_lines, '\\n') or '当前没有技能说明", "tip_text = #tip_lines > 0 and table.concat(tip_lines, '\\n') or '当前没有技能说明'"),
    ("local bQ = tostring(bM.set_title_text or ''):gsub('$', '')", "local bQ = tostring(bM.set_title_text or ''):gsub('$', '')"),
    
    # 继续修复更多问题
    ("tostring(bM.item_name_text or bs.title or '羁绊", "tostring(bM.item_name_text or bs.title or '羁绊'),"),
    ("show_tip_panel(X.big_cursor and '大鼠标已开启，鼠标位置会显示辅助圈 or '大鼠标已关闭", "show_tip_panel(X.big_cursor and '大鼠标已开启，鼠标位置会显示辅助圈' or '大鼠标已关闭'"),
    ("show_tip_panel(X.hide_damage_text and '已屏蔽跳字 or '已恢复跳字显示", "show_tip_panel(X.hide_damage_text and '已屏蔽跳字' or '已恢复跳字显示'"),
    ("show_tip_panel(X.hide_hit_effects and '已屏蔽局内技能特效 or '已恢复局内技能特效", "show_tip_panel(X.hide_hit_effects and '已屏蔽局内技能特效' or '已恢复局内技能特效'"),
    ("string.format('当前属性增幅]\\n'", "string.format('[当前属性增幅]\\n'"),
    
    # 修复更多问题
    ("'每10 级会进入一次词缀选择，选择完成后可继续升级", "'每10 级会进入一次词缀选择，选择完成后可继续升级'"),
    ("(c4.stack_text and c4.stack_text ~= '' and ('计数 .. tostring(c4.stack_text)) or ''", "(c4.stack_text and c4.stack_text ~= '' and ('计数' .. tostring(c4.stack_text)) or ''"),
    ("c4.key and ('技能位 .. tostring(c4.key)) or ''", "c4.key and ('技能位置' .. tostring(c4.key)) or ''"),
    ("(STATE.session_phase == 'battle' and '战斗 or '准备)", "(STATE.session_phase == 'battle' and '战斗中' or '准备中')"),
    ("show_tip_panel(get_hotkey_help_text(), 10, '快捷", "show_tip_panel(get_hotkey_help_text(), 10, '快捷键"),
    
    # 修复更多问题
    ("set_ui_text(resolve_ui_node('top.top.scoreboard.title'), '玩家状", "set_ui_text(resolve_ui_node('top.top.scoreboard.title'), '玩家状态"),
    ("(STATE.session_phase == 'battle' and '战斗 or '局)", "(STATE.session_phase == 'battle' and '战斗中' or '局中')"),
    ("title = tostring(c4.tip_title or c4.name or '英雄技", "title = tostring(c4.tip_title or c4.name or '英雄技能"),
    ("title = tostring(c4.tip_title or c4.name or '技", "title = tostring(c4.tip_title or c4.name or '技能"),
    
    # 修复函数调用中的问题
    ("get_hero_attr('最终攻击))", "get_hero_attr('最终攻击'))"),
    ("get_hero_attr('最终护甲))", "get_hero_attr('最终护甲))"),
    ("get_hero_attr('最终力量增幅))", "get_hero_attr('最终力量增幅))"),
    ("get_hero_attr('最终智力增幅))", "get_hero_attr('最终智力增幅))"),
    ("get_hero_attr('最终敏捷增幅))", "get_hero_attr('最终敏捷增幅))"),
    
    # 继续修复剩余问题
    ("tip_title = tostring(slot_data.name or slot_data.id or '技能", "tip_title = tostring(slot_data.name or slot_data.id or '技能'),"),
    ("local function normalize_rarity_display(rarity_key) return RARITY_NAME_MAP[rarity_key] or '普", "local function normalize_rarity_display(rarity_key) return RARITY_NAME_MAP[rarity_key] or '普通"),
    ("if c4.style == 'rare' then return '稀有事件, c4.text end;", "if c4.style == 'rare' then return '稀有事件', c4.text end;"),
    ("return '操作提示', 'F 抽卡，如何变强查看英雄图鉴，H 查看英雄功能，P 打开存档", "return '操作提示', 'F 抽卡，如何变强查看英雄图鉴，H 查看英雄功能，P 打开存档'"),
    ("local damage_text_status = X.hide_damage_text and '跳字关 or '跳字开'", "local damage_text_status = X.hide_damage_text and '跳字关' or '跳字开'"),
    ("local hit_effects_status = X.hide_hit_effects and '特效关 or '特效开'", "local hit_effects_status = X.hide_hit_effects and '特效关' or '特效开'"),
    ("local pause_status = X.soft_paused and '已暂停 or '进行中'", "local pause_status = X.soft_paused and '已暂停' or '进行中'"),
    ("if not is_ui_alive(hud_state.bond_tip_subtitle) then hud_state.bond_tip_subtitle = ui_root.resolve_child(hud_state.bond_tip_panel, 'subtitle') or ui_root.resolve_child(hud_state.bond_tip_panel, '列表.副标题) end;", "if not is_ui_alive(hud_state.bond_tip_subtitle) then hud_state.bond_tip_subtitle = ui_root.resolve_child(hud_state.bond_tip_panel, 'subtitle') or ui_root.resolve_child(hud_state.bond_tip_panel, '列表.副标题') end;"),
    ("ac:set_text(')", "ac:set_text('')"),
    ("show_tip_panel('对局已暂停，再点一次继续, 4, '战斗控制')", "show_tip_panel('对局已暂停，再点一次继续', 4, '战斗控制')"),
    ("show_tip_panel('对局已继续, 4, '战斗控制')", "show_tip_panel('对局已继续', 4, '战斗控制')"),
    
    # 修复更多问题
    ("set_ui_text_alignment(hud_state.attr_panel_title, '', '')", "set_ui_text_alignment(hud_state.attr_panel_title, '', '')"),
    ("set_ui_text_alignment(hud_state.attr_panel_body, '', '')", "set_ui_text_alignment(hud_state.attr_panel_body, '', '')"),
    ("set_ui_text_alignment(hud_state.attr_panel_hint, '', '')", "set_ui_text_alignment(hud_state.attr_panel_hint, '', '')"),
    ("set_ui_text_alignment(hud_state.tip_panel_title, '', '')", "set_ui_text_alignment(hud_state.tip_panel_title, '', '')"),
    ("set_ui_text_alignment(hud_state.tip_panel_body, '', '')", "set_ui_text_alignment(hud_state.tip_panel_body, '', '')"),
    ("set_ui_text_alignment(hud_state.tip_panel_hint, '', '')", "set_ui_text_alignment(hud_state.tip_panel_hint, '', '')"),
    ("set_ui_text_alignment(hud_state.hover_tip_panel_title, '', '')", "set_ui_text_alignment(hud_state.hover_tip_panel_title, '', '')"),
    ("set_ui_text_alignment(hud_state.hover_tip_panel_subtitle, '', '')", "set_ui_text_alignment(hud_state.hover_tip_panel_subtitle, '', '')"),
    ("set_ui_text_alignment(hud_state.hover_tip_panel_body, '', '')", "set_ui_text_alignment(hud_state.hover_tip_panel_body, '', '')"),
    ("set_ui_text_alignment(resolve_ui_node('BattleBottomHUD.layout.right_station.loadout_row.loadout_title'), '', '')", "set_ui_text_alignment(resolve_ui_node('BattleBottomHUD.layout.right_station.loadout_row.loadout_title'), '', '')"),
    ("set_ui_text_alignment(resolve_ui_node('BattleBottomHUD.layout.center_hub.hero_panel.hero_name'), '', '')", "set_ui_text_alignment(resolve_ui_node('BattleBottomHUD.layout.center_hub.hero_panel.hero_name'), '', '')"),
    ("set_ui_text_alignment(resolve_ui_node('BattleBottomHUD.layout.center_hub.hero_panel.hero_hp_text'), '', '')", "set_ui_text_alignment(resolve_ui_node('BattleBottomHUD.layout.center_hub.hero_panel.hero_hp_text'), '', '')"),
    ("set_ui_text_alignment(resolve_combat_module_ui('exp_bar.exp_text'), '', '')", "set_ui_text_alignment(resolve_combat_module_ui('exp_bar.exp_text'), '', '')"),
    ("set_ui_text_alignment(resolve_combat_module_ui('status_text'), '', '')", "set_ui_text_alignment(resolve_combat_module_ui('status_text'), '', '')"),
    ("set_ui_text_alignment(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.station_hint'), '', '')", "set_ui_text_alignment(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.station_hint'), '', '')"),
]

# 应用修复
for old, new in fixes:
    content = content.replace(old, new)

# 保存修复后的文件
with open(r'd:\project\_codex_y3td_push\maps\EntryMap\script\ui\runtime_hud.lua', 'w', encoding='utf-8') as f:
    f.write(content)

print('修复完成')

# 验证修复结果
print('=== 验证结果 ===')
with open(r'd:\project\_codex_y3td_push\maps\EntryMap\script\ui\runtime_hud.lua', 'r', encoding='utf-8') as f:
    content = f.read()

# 检查未闭合的字符串
unclosed_strings = []
lines = content.split('\n')
for i, line in enumerate(lines, 1):
    quote_count = line.count("'")
    if quote_count % 2 != 0:
        unclosed_strings.append((i, line.strip()[:50]))

if unclosed_strings:
    print(f'仍有 {len(unclosed_strings)} 个未闭合的字符串:')
    for line_num, snippet in unclosed_strings[:10]:
        print(f'  第{line_num}行: {snippet}')
else:
    print('✓ 所有字符串已正确闭合')
