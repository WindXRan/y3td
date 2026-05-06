local a=require'ui.ui_root'
local b=require'data.tables.outgame.hero_evolutions'
local c=(require'data.game_tables').hero_roster
local d=require'data.tables.hero.hero_form_skills'
local e={}
local f=8;
local g=8;
local h=5;
local i=5;
local j={'battle_power_row','hero_attack_row','hero_defense_row','hero_power_row','hero_intelligence_row','hero_agility_row'}
local k={width=108,
height=122,
x=92,
y=142}
local l={focus={0,0,88},
fov=32,
camera_pos={156,-108,88},
camera_rot={0,0,0},
background={0,0,0,0}}
local m=260;
local n=12;
local o=122;
local p={common='普通',
rare='稀有',
epic='史诗'}
local q=b.by_id or{}
local r=c.by_unit_id or{}
local s=d.by_hero_id or{}
local function is_ui_alive(u)return a.is_alive(u)end;

function e.create(v)
local w=v.STATE;
local x=v.CONFIG or{}
local bond_label_cfg=(x.bond_skill_runtime_tuning and x.bond_skill_runtime_tuning.labels)
or(x.skill_runtime_tuning and x.skill_runtime_tuning.bond and x.skill_runtime_tuning.bond.labels)
or{}
local bond_ui_cfg=(x.bond_skill_runtime_tuning and x.bond_skill_runtime_tuning.ui)
or(x.skill_runtime_tuning and x.skill_runtime_tuning.bond and x.skill_runtime_tuning.bond.ui)
or{}
local bond_skill_label=tostring(bond_ui_cfg.hud_skill_title or bond_label_cfg.effect_name or'羁绊技能')
local y=v.y3;
local z=math.max(1,tonumber(v.attack_skill_slot_count)or 5)
local A=v.get_player;
local B=v.hero_attr_system;
local C=v.message or function()end;

local E=v.try_bond_draw;
local G=v.try_evolution_entry;
local H=nil;
local I=v.try_start_challenge;
local J=v.open_save_panel;
local K=v.try_upgrade_growth_weapon;
local L=v.show_runtime_status;
local M=v.build_runtime_attr_dialog_chunks;
local N=v.build_growth_weapon_tip_payload;
local O=v.build_bond_slot_tip_payload;
local P=math.max(0,tonumber(v.bond_draw_cost)or 100)
local Q=v.get_bond_slot_icon;
local R=v.get_bottom_status_effect_entries;
local S=v.play_ui_click;
local safe_ui_call
local set_ui_visible
local set_ui_text
local set_ui_text_color
local set_ui_font_size
local set_ui_text_alignment
local set_ui_image
local set_ui_image_color
local set_ui_size
local set_ui_anchor
local set_ui_pos
local set_ui_progress
local bind_ui_model_unit
local apply_ui_model_camera
local set_ui_pos_percent
local toggle_big_cursor
local toggle_damage_text_visible
local toggle_hit_effects_visible
local toggle_soft_pause
local toggle_runtime_attr_panel
local ensure_hud
local refresh_hud
local set_hud_visible
local show_runtime_tip_panel
local function get_player()return A and A()or nil end;

local function ensure_ui_preferences()w.ui_preferences=w.ui_preferences or{}
local X=w.ui_preferences;
if X.hide_damage_text==nil then X.hide_damage_text=false end;

if X.hide_hit_effects==nil then X.hide_hit_effects=false end;

if X.big_cursor==nil then X.big_cursor=false end;

if X.soft_paused==nil then X.soft_paused=false end;

return X end;

local function get_hud_state()w.runtime_hud=w.runtime_hud or{nodes={},
bound_events={},
visible=true,
attr_panel_visible=false,
tip_title_text='',
tip_body_text='',
tip_panel=nil,
tip_panel_title=nil,
tip_panel_body=nil,
tip_expires_at=0,
hover_tip_panel=nil,
hover_tip_panel_icon_bg=nil,
hover_tip_panel_icon=nil,
hover_tip_panel_title=nil,
hover_tip_panel_subtitle=nil,
hover_tip_panel_body=nil,
hover_tip_visible=false,
bond_tip_panel=nil,
bond_tip_root=nil,
bond_tip_icon=nil,
bond_tip_title=nil,
bond_tip_have=nil,
bond_tip_swallow=nil,
bond_tip_detail_body=nil,
bond_tip_special_title=nil,
bond_tip_special_body=nil,
bond_tip_skill_title=nil,
bond_tip_skill_body=nil,
bond_tip_set_title=nil,
bond_tip_visible=false,
attr_panel=nil,
attr_panel_title=nil,
attr_panel_body=nil,
attr_panel_hint=nil,
big_cursor=nil,
hero_model_ui=nil,
buff_prefab=nil,
buff_prefab_root=nil,
buff_list_comp=nil}return w.runtime_hud end;

local function resolve_ui_node(_)
local a0=get_hud_state()
local a1=a0.nodes[_]if is_ui_alive(a1)then return a1 end;

local a2=get_player()
if not a2 then return nil end;

local u=a.resolve_ui(y,a2,_)a0.nodes[_]=u;
return u end;

local function resolve_first_ui_node(a4)
local a0=get_hud_state()
local a5='__first__:'..table.concat(a4 or{},'|')
local a1=a0.nodes[a5]if is_ui_alive(a1)then return a1 end;

local a2=get_player()
if not a2 then return nil end;

local u=a.resolve_first_ui(y,a2,a4)a0.nodes[a5]=u;
return u end;

local function safe_ui_call(u,a7,...)
if not is_ui_alive(u)then return false end;

local a8=u[a7]if type(a8)~='function'then return false end;

return pcall(a8,u,...)end;

local function set_ui_visible(u,aa)
safe_ui_call(u,'set_visible',
aa==true)end;

local function set_ui_text(u,ac)
safe_ui_call(u,'set_text',ac or'')end;

local function set_ui_text_color(u,ae)
if ae then safe_ui_call(u,'set_text_color',ae[1],ae[2],ae[3],ae[4]or 255)end end;

local function set_ui_font_size(u,ag)
if ag then safe_ui_call(u,'set_font_size',ag)end end;

local function set_ui_text_alignment(u,ai,aj)
if ai and aj then safe_ui_call(u,'set_text_alignment',ai,aj)end end;

local function set_ui_image(u,al)
if al~=nil then safe_ui_call(u,'set_image',al)end end;

local function set_ui_image_color(u,ae)
if ae then safe_ui_call(u,'set_image_color',ae[1],ae[2],ae[3],ae[4]or 255)end end;

local function set_ui_size(u,ao,ap)
if ao and ap then safe_ui_call(u,'set_ui_size',ao,ap)end end;

local function set_ui_anchor(u,ar,as)
if ar~=nil and as~=nil then safe_ui_call(u,'set_anchor',ar,as)end end;

local function set_ui_pos(u,ar,as)
if ar~=nil and as~=nil then safe_ui_call(u,'set_pos',ar,as)end end;

local function set_ui_progress(u,av,aw)
if not is_ui_alive(u)then return end;

local ax=math.max(1,math.floor((tonumber(aw)or 1)+0.5))
local ay=math.max(0,math.min(ax,math.floor((tonumber(av)or 0)+0.5)))
safe_ui_call(u,'set_max_progress_bar_value',ax)
safe_ui_call(u,'set_current_progress_bar_value',ay,0)end;

local function bind_ui_model_unit(u,aA,aB,aC,aD)
if aA and aA.is_exist and not aA:is_exist()then aA=nil end;

if not is_ui_alive(u)or not aA then return end;
safe_ui_call(u,'set_ui_model_unit',aA,
aB==true,
aC==true,
aD==true)end;

local function apply_ui_model_camera(u,aF)
if not is_ui_alive(u)or not aF then return end;

if aF.focus then safe_ui_call(u,'set_ui_model_focus_pos',aF.focus[1],aF.focus[2],aF.focus[3])end;

if aF.fov then safe_ui_call(u,'change_showroom_fov',aF.fov)end;

if aF.camera_pos then safe_ui_call(u,'change_showroom_cposition',aF.camera_pos[1],aF.camera_pos[2],aF.camera_pos[3])end;

if aF.camera_rot then safe_ui_call(u,'change_showroom_crotation',aF.camera_rot[1],aF.camera_rot[2],aF.camera_rot[3])end;

if aF.background then safe_ui_call(u,'set_show_room_background_color',aF.background[1],aF.background[2],aF.background[3],aF.background[4]or 0)end end;

local function set_ui_pos_percent(u,ar,as)
local a2=get_player()
if not a2 or not is_ui_alive(u)or not GameAPI or not GameAPI.set_ui_comp_pos_percent then return end;
pcall(GameAPI.set_ui_comp_pos_percent,a2.handle,u.handle,ar,as)end;

local function format_short_number(aI)
local aJ=tonumber(aI)or 0;
local aK=math.abs(aJ)
if aK>=1000000 then local ac=string.format('%.1fm',aJ/1000000)return ac:gsub('%.0m$','m')end;

if aK>=10000 then local ac=string.format('%.1fk',aJ/1000)return ac:gsub('%.0k$','k')end;

return tostring(math.floor(aJ+0.5))end;

local function format_time_mmss(aM)
local aN=math.max(0,math.floor((tonumber(aM)or 0)+0.5))
local aO=aN//60;
local aP=aN%60;
return string.format('%02d:%02d',aO,aP)end;

local function normalize_percent_value(aI)
local aJ=tonumber(aI)or 0;
if math.abs(aJ)<=1 then aJ=aJ*100 end;

return aJ end;

local function format_percent(aI)return string.format('%d%%',math.floor(normalize_percent_value(aI)+0.5))end;

local function format_percent_delta(aT,aU)
local aN=normalize_percent_value(aT)+normalize_percent_value(aU)return string.format('%+d%%',math.floor(aN+(aN>=0 and 0.5 or-0.5)))end;

local function format_signed_number(aI)
local aJ=tonumber(aI)or 0;
local aW=aJ>=0 and'+'or'-'return aW..format_short_number(math.abs(aJ))end;

local function table_count(aY)
if type(aY)~='table'then return 0 end;

local aZ=0;
for a_ in pairs(aY)do aZ=aZ+1 end;

return aZ end;

local function get_hero_attr(b1,b2)
if not w.hero or not w.hero.is_exist or not w.hero:is_exist()then return 0 end;

local aI=B and B.get_attr(w.hero,b1)or w.hero:get_attr(b1)
aI=tonumber(aI)or 0;
if aI~=0 or not b2 then return aI end;

local b3=B and B.get_attr(w.hero,b2)or w.hero:get_attr(b2)return tonumber(b3)or 0 end;

local function get_hero_level()return math.max(1,math.floor(tonumber(w.hero_progress and w.hero_progress.level)or 1))end;

local function get_hero_name()
if w.hero and w.hero.get_name and w.hero:is_exist()then local b1=w.hero:get_name()
if b1 and b1~=''then return b1 end end;

return'英雄'end;

local function get_hero_icon()
if w.hero and w.hero.get_icon and w.hero:is_exist()then return w.hero:get_icon()end;

return nil end;

local function get_unit_type_icon(b8)
if b8 and y and y.unit and y.unit.get_icon_by_key then return y.unit.get_icon_by_key(b8)end;

return nil end;

local function get_hero_unit()
if w.hero and w.hero.is_exist and w.hero:is_exist()then return w.hero end;

return nil end;

local function get_player_name()
local a2=get_player()
if a2 and a2.get_name then local b1=a2:get_name()
if b1 and b1~=''then return b1 end end;

return'玩家'end;

local function get_hero_hp_info()
local bc=w.hero and w.hero.is_exist and w.hero:is_exist()
and(tonumber(w.hero:get_hp())or 0)or 0;
local bd=math.max(1,get_hero_attr('生命结算值','生命'))return bc,bd end;

local function get_hero_exp_info()
local bf=tonumber(w.hero_progress and w.hero_progress.exp)or 0;
local bg=tonumber(w.hero_progress and w.hero_progress.exp_to_next)or 1;
if bg<=0 then bg=math.max(1,bf)end;

return bf,bg end;

local function has_pending_evolution_choice()
local a0=w.evolution_runtime;
return a0 and a0.awaiting_choice==true and a0.current_choices and#a0.current_choices>0 or false end;

local function get_weapon_level()return w.gear_state and w.gear_state.items and w.gear_state.items.weapon and w.gear_state.items.weapon.level or 0 end;

local function get_weapon_item_key()
local bk=x.gear_upgrade_config and x.gear_upgrade_config.slots and x.gear_upgrade_config.slots.weapon or nil;
return bk and bk.item_key or nil end;

local function bk_icon_fallback()
local item_key = get_weapon_item_key()
if item_key and y and y.item and y.item.get_icon_id_by_key then
local ok, icon = pcall(y.item.get_icon_id_by_key, item_key)
if ok and icon and tonumber(icon) and tonumber(icon) ~= 0 then
return icon
end
end
return 999
end;

local function get_hero_item_by_slot(bm)
if not w.hero or not w.hero.is_exist or not w.hero:is_exist()or not w.hero.get_item_by_slot then return nil end;

local bn,
bo=pcall(w.hero.get_item_by_slot,w.hero,'物品栏',bm)
if not bn then return nil end;

return bo end;

local function is_weapon_item(bo)
if not bo or not bo.get_key then return false end;

local bq=get_weapon_item_key()
if not bq then return false end;

return tostring(bo:get_key())==tostring(bq)end;

local function format_gear_upgrade_tip(bs)
if not bs then return'当前没有成长武器数据。'end;

local bt={}if bs.subtitle_text and bs.subtitle_text~=''then bt[#bt+1]=tostring(bs.subtitle_text)end;

if bs.cost_text and bs.cost_text~=''then bt[#bt+1]=tostring(bs.cost_text)end;

local bu=bs.attr_lines or{}if#bu>0 then if#bt>0 then bt[#bt+1]=''end;
bt[#bt+1]='当前属性增幅'for a_,bv in ipairs(bu)do bt[#bt+1]=tostring(bv)end end;

local bw=bs.affix_lines or{}if#bw>0 then if#bt>0 then bt[#bt+1]=''end;

for a_,bx in ipairs(bw)do
if bx.title and bx.title~=''then bt[#bt+1]=tostring(bx.title)end;

if bx.body and bx.body~=''then bt[#bt+1]=tostring(bx.body)end end end;
if#bt==0 then return'当前没有成长武器数据。'end;

return table.concat(bt,'\n')end;

local function get_item_display_info(bo)
if not bo then return nil,nil end;

local bz=bo.get_name and bo:get_name()or'物品'
local bt={}
local bA=bo.get_description and bo:get_description()or nil;
if bA and bA~=''then bt[#bt+1]=tostring(bA)end;

local bB=bo.get_stack and tonumber(bo:get_stack())or 0;
if bB and bB>1 then bt[#bt+1]=string.format('层数：%d',bB)end;

local bC=bo.get_charge and tonumber(bo:get_charge())or 0;
if bC and bC>0 then bt[#bt+1]=string.format('充能：%d',bC)end;
if#bt==0 then bt[#bt+1]='当前没有额外说明。'end;

return tostring(bz),table.concat(bt,'\n')end;

local function append_line(bE,ac)
local aI=tostring(ac or'')
if aI~=''then bE[#bE+1]=aI end end;

local function append_lines(bE,bt)for a_,bv in ipairs(bt or{})
do append_line(bE,bv)end end;

local function append_multiline_text(bE,ac)
local aI=tostring(ac or'')
if aI==''then return end;

for bv in aI:gmatch('[^\n]+')do append_line(bE,bv)end end;

local function build_weapon_tooltip()
local bs=N and N()or nil;
if not bs then return nil end;

local bt={}if bs.cost_text and bs.cost_text~=''then bt[#bt+1]=tostring(bs.cost_text)end;

local bu=bs.attr_lines or{}if#bu>0 then if#bt>0 then bt[#bt+1]=''end;
bt[#bt+1]='[武器属性]'append_lines(bt,bu)end;

local bw=bs.affix_lines or{}if#bw>0 then if#bt>0 then bt[#bt+1]=''end;

for a_,bx in ipairs(bw)do
if bx.title and bx.title~=''then bt[#bt+1]='['..tostring(bx.title)..']'end;

if bx.body and bx.body~=''then bt[#bt+1]=tostring(bx.body)end end end;
if#bt==0 then bt[#bt+1]='当前没有成长武器数据。'end;

return{title=tostring(bs.title_text or'成长武器'),
subtitle=tostring(bs.subtitle_text or''),
body=table.concat(bt,'\n'),
icon=bs.icon_res}end;

local function build_slot_tooltip(bm)
local bo=get_hero_item_by_slot(bm)
if bo and is_weapon_item(bo)then return build_weapon_tooltip()end;

local bz,
bJ=get_item_display_info(bo)
if not bz or not bJ then return nil end;

return{title=bz,
subtitle='',
body=bJ,
icon=bo and bo.get_icon and bo:get_icon()or nil}end;

local function build_bond_slot_tooltip(bL)
local bs=nil
if O then
local ok,payload=pcall(O,bL)
if ok then bs=payload
elseif C then C(string.format('[runtime_hud] build_bond_slot_tip_payload(%s) failed: %s',tostring(bL),tostring(payload)))end
end;
if not bs then return nil end;

local bM=bs.tip_model or{}
local bz=tostring(bM.item_name_text or bs.title_text or'流派')
local bN={}if bM.quality_text and bM.quality_text~=''then bN[#bN+1]=tostring(bM.quality_text)end;

local bO=tostring(bM.set_name_text or'')
local bP=tostring(bM.progress_text or'')
if bO~=''or bP~=''then bN[#bN+1]='流派：'..bO..bP end;

local bt={}if bM.bonus_lines and#bM.bonus_lines>0 then bt[#bt+1]='[流派效果]'append_lines(bt,bM.bonus_lines)end;

if bM.effect_body_text and bM.effect_body_text~=''then if#bt>0 then bt[#bt+1]=''end;
bt[#bt+1]='[收录条件]'append_multiline_text(bt,bM.effect_body_text)end;

if bM.set_body_lines and#bM.set_body_lines>0 then if#bt>0 then bt[#bt+1]=''end;

local bQ=tostring(bM.set_title_text or''):gsub('：+$','')bt[#bt+1]='['..(bQ~=''and bQ or bond_skill_label)..']'append_lines(bt,bM.set_body_lines)end;
if#bt==0 then bt[#bt+1]='当前没有流派说明。'end;

return{title=bz,
subtitle=table.concat(bN,'  '),
body=table.concat(bt,'\n'),
icon=bM.icon_res or bs.icon_res,
tip_model=bM}end;

local function build_draw_tooltip()
local bt={'[左键点击]',string.format('本次消耗 %d 个木材',P),string.format('当前拥有 %s 木材',format_short_number(w.resources and w.resources.wood or 0)),'','抽取流派卡牌，相同流派会自动收录进卡册。'}return{title='抽卡 - [快捷键：F]',
subtitle='',
body=table.concat(bt,'\n'),
icon=nil}end;

local function build_hero_catalog_tooltip()
local bt={'[左键点击]','打开英雄图鉴面板。','可查看英雄定位、核心技能与星级。'}return{title='如何变强',
subtitle='',
body=table.concat(bt,'\n'),
icon=nil}end;

local function build_evolution_entry_tooltip()
local bt={'[左键点击]','已改为新英雄功能入口。','请点击“如何变强”进入英雄图鉴。'}return{title='英雄进阶入口 - [快捷键：H]',
subtitle='',
body=table.concat(bt,'\n'),
icon=nil}end;

local function build_save_panel_tooltip()
local bt={'[左键点击]','打开存档面板；如果当前没有可打开的存档界面，则显示运行时状态。'}return{title='存档 - [快捷键：P]',
subtitle='',
body=table.concat(bt,'\n'),
icon=nil}end;

local function build_consumable_tooltip(bm)
if bm==1 then return{title='属性宝石',
subtitle='类型：消耗品',
body=table.concat({'[点击使用]','可选择一条随机属性强化。','英雄每升 5 级，或完成宝石挑战时，可获得 1 颗。'},'\n'),
icon=300540000}end;

if bm==2 then return{title='快捷道具 2',
subtitle='特殊栏位',
body='当前用于特殊功能扩展。',
icon=nil}end;

if bm==3 then return{title='快捷道具 3',
subtitle='特殊栏位',
body='当前用于特殊功能扩展。',
icon=nil}end;

return nil end;

local function build_attack_skill_entry(bX,bY)
if not bX then return nil end;

local bt={}if bX.summary and bX.summary~=''then bt[#bt+1]=tostring(bX.summary)end;

local bZ=tonumber(bX.damage_ratio)or 0;
if bZ>0 then bt[#bt+1]=string.format('倍率：%.0f%%',bZ*100)end;

local b_=math.max(0,tonumber(bX.cast_range or 0)+tonumber(bX.range_bonus or 0))
if b_>0 then bt[#bt+1]=string.format('射程：%d',math.floor(b_+0.5))end;

local c0=tonumber(bX.base_cooldown)or 0;
if c0>0 and bX.id~='basic_attack'then bt[#bt+1]=string.format('基础冷却：%.1fs',c0)end;

if bX.id=='basic_attack'then bt[#bt+1]=string.format('攻速：%s',format_short_number(get_hero_attr('攻击速度')))end;

local c1=tonumber(bX.cooldown_remaining)or 0;
return{id=tostring(bX.id or'skill_'..tostring(bY)),
name=tostring(bX.name or bX.id or'技能'..tostring(bY)),
icon=bX.ui_icon or bX.icon,
key=bY==1 and'普'or tostring(bY),
cooldown_text=c1>0 and string.format('%.1fs',c1)or'就绪',
legacy_cooldown_text=c1>0 and string.format('%.1f',c1)or'',
badge_text=bX.level and'Lv.'..tostring(bX.level)or'',
stack_text='',
tip_title=tostring(bX.name or bX.id or'技能'),
tip_text=#bt>0 and table.concat(bt,'\n')or'当前没有技能说明。'}end;

local function build_hero_form_skill_entry(bY)
local c3=w.hero_form_skills_system;
if not c3 or not c3.get_active_skill then return nil end;

local bX=c3.get_active_skill()
if not bX then return nil end;

local c4=c3.get_active_entry and c3.get_active_entry()or nil;
local a0=w.hero_form_skill_runtime or{}
local c1=tonumber(a0.cooldowns and a0.cooldowns[bX.id])or 0;
local c5=tonumber(a0.counters and a0.counters[bX.id])or 0;
local c6=math.max(0,math.floor(tonumber(bX.trigger_value)or 0))
local bt={}if c4 and c4.title and c4.title~=''then bt[#bt+1]='专精：'..tostring(c4.title)end;

if bX.subtitle and bX.subtitle~=''then bt[#bt+1]=tostring(bX.subtitle)end;

if bX.summary and bX.summary~=''then bt[#bt+1]=tostring(bX.summary)end;

if bX.item_desc and bX.item_desc~=''then bt[#bt+1]=tostring(bX.item_desc)end;

if tonumber(bX.cooldown)and tonumber(bX.cooldown)>0 then bt[#bt+1]=string.format('冷却：%.1fs',tonumber(bX.cooldown))end;

return{id=tostring(bX.id or'form_skill_'..tostring(bY)),
name=tostring(bX.name or'猎手专精'),
icon=bX.ui_icon or bX.icon or get_hero_icon(),
key='专',
cooldown_text=c1>0 and string.format('%.1fs',c1)or'就绪',
legacy_cooldown_text=c1>0 and string.format('%.1f',c1)or'',
badge_text=c4 and c4.rarity or'',
stack_text=c6>1 and string.format('%d/%d',math.min(c5,c6),c6)or'',
tip_title=tostring(bX.name or'猎手专精'),
tip_text=#bt>0 and table.concat(bt,'\n')or'当前没有专精说明。'}end;

local function normalize_rarity_display(c8)return p[c8]or'普通'end;

local function get_evolution_runtime()return w.evolution_runtime end;

local function get_hero_roster_by_unit(cb)
local cc=cb and cb.hero_unit_id or nil;
if cc==nil then return nil end;

return r[cc]end;

local function get_form_skill_and_roster_entry(cb)
local c4=get_hero_roster_by_unit(cb)
if not c4 then return nil,nil end;

return s[c4.id],c4 end;

local function build_evolution_skill_entry(cb,bY)
if not cb then return nil end;

local bX,c4=get_form_skill_and_roster_entry(cb)
local cf=c4 and c4.name or cb.name or'专精'..tostring(bY)
local cg=c4 and c4.title or bX and bX.subtitle or'英雄真身'
local ch=bX and bX.summary or c4 and c4.summary or cb.summary or''
local bt={string.format('[%s] %s',normalize_rarity_display(cb.quality),cg)}if bX and bX.name and bX.name~=''then bt[#bt+1]='技能：'..tostring(bX.name)end;

if ch~=''then bt[#bt+1]=tostring(ch)end;

local icon_from_skill = bX and bX.icon
return{id=tostring(cb.id or'evolution_'..tostring(bY)),
name=tostring(cf),
icon=icon_from_skill or c4.icon or get_unit_type_icon(cb.hero_unit_id) or get_hero_icon(),
key=tostring(bY),
cooldown_text='',
legacy_cooldown_text='',
badge_text=normalize_rarity_display(cb.quality),
stack_text='',
tip_title=string.format('%s·%s',tostring(cf),tostring(cg)),
tip_text=table.concat(bt,'\n')}end;

local function get_skill_slot_entries(cj)
local ck={}
local cl=w.attack_skill_state and w.attack_skill_state.slots or nil;
for bL=1,math.min(z,cj or z)do local bX=cl and cl[bL]or nil;
if bX then ck[#ck+1]=build_attack_skill_entry(bX,bL)end end;
if#ck<cj then local cm=build_hero_form_skill_entry(#ck+1)
if cm then ck[#ck+1]=cm end end;

return ck end;

local function get_evolution_slot_entries(cj)
local ck={}
local co=math.max(1,tonumber(cj)or h)
local a0=get_evolution_runtime()
local cp=a0 and(a0.ordered_evolution_ids)or nil;
for bL=1,co,1 do local cq=cp and cp[bL]or nil;
local cb=cq and q[cq]or nil;
if cb then local c4=build_evolution_skill_entry(cb,bL)
if c4 then ck[#ck+1]=c4 end end end;

return ck end;

local function get_skill_entry_by_slot(bL)
if bL<1 or bL>z then return nil end;

local cl=w.attack_skill_state and w.attack_skill_state.slots or nil;
local bX=cl and cl[bL]or nil;
return build_attack_skill_entry(bX,bL)end;

local function get_pending_choice_status()
if w.gear_state and w.gear_state.awaiting_choice and w.gear_state.current_choices then return'武器待选','成长武器词缀候选已出现，请点击面板完成选择。'end;

if w.bond_runtime and w.bond_runtime.awaiting_choice and w.bond_runtime.current_choices then return'流派待选','流派候选已生成，请点击面板完成选择。'end;

local ct=w.evolution_runtime;
if ct and ct.awaiting_choice and ct.current_choices then return'英雄功能提示','进阶已迁移到新英雄功能，请打开英雄图鉴查看。'end;

return nil,nil end;

local function get_current_tip_text()
local a0=get_hud_state()
if a0.tip_panel and a0.tip_expires_at and a0.tip_expires_at>(w.runtime_elapsed or 0)then return a0.tip_title_text~=''and a0.tip_title_text or'系统提示',a0.tip_body_text or''end;

local cv,
cw=get_pending_choice_status()
if cv and cw then return cv,cw end;

local ck=w.battle_event_feed and w.battle_event_feed.entries or nil;
if ck and#ck>0 then local c4=ck[#ck]if c4 and c4.text and c4.text~=''then
if c4.style=='reward'then return'奖励提示',c4.text end;

if c4.style=='warning'then return'战斗警报',c4.text end;

if c4.style=='rare'then return'稀有事件',c4.text end;

if c4.style=='positive'then return'进度更新',c4.text end;

return'系统消息',c4.text end end;

return'操作提示','F 抽卡，如何变强查看英雄图鉴，H 查看英雄功能，P 打开存档。'end;

local function get_status_bar_text()
local X=ensure_ui_preferences()
local cv,
a_=get_pending_choice_status()
if cv then return'状态：'..cv end;

local cy=X.hide_damage_text and'跳字关'or'跳字开'
local cz=X.hide_hit_effects and'特效关'or'特效开'
local cA=X.soft_paused and'已暂停'or'进行中'return string.format('状态：%s | %s | %s',cA,cy,cz)end;

local function get_station_hint_text()return'按F抽卡；点击如何变强查看英雄图鉴'end;

local function get_hotkey_help_text()return table.concat({'F / 抽卡：流派三选一','如何变强：查看英雄图鉴','H / 英雄功能：查看图鉴与成长','Q / W / E：试炼入口','TAB / T：属性面板','SPACE：打印状态概览','P：打开存档'},'\n')end;

local function resolve_static_ui_panels()
local a0=get_hud_state()a0.attr_panel=resolve_first_ui_node({'BattleBottomHUD.layout.attr_panel','BattleBottomHUD.layout.right_station.attr_panel'})
a0.attr_panel_title=resolve_first_ui_node({'BattleBottomHUD.layout.attr_panel.title','BattleBottomHUD.layout.right_station.attr_panel.title'})
a0.attr_panel_body=resolve_first_ui_node({'BattleBottomHUD.layout.attr_panel.body','BattleBottomHUD.layout.right_station.attr_panel.body'})
a0.attr_panel_hint=resolve_first_ui_node({'BattleBottomHUD.layout.attr_panel.hint','BattleBottomHUD.layout.right_station.attr_panel.hint'})
set_ui_visible(a0.attr_panel,false)
safe_ui_call(a0.attr_panel,'set_intercepts_operations',true)
set_ui_text_alignment(a0.attr_panel_title,'左','中')
set_ui_text_alignment(a0.attr_panel_body,'左','中')
set_ui_text_alignment(a0.attr_panel_hint,'右','中')
if a0.bound_events.static_attr_panel_close~=a0.attr_panel and is_ui_alive(a0.attr_panel)then a0.bound_events.static_attr_panel_close=a0.attr_panel;a0.attr_panel:add_fast_event('左键-点击',function()
local cE=get_hud_state()cE.attr_panel_visible=false;set_ui_visible(cE.attr_panel,false)end)end;
a0.tip_panel=resolve_first_ui_node({'BattleBottomHUD.layout.tip_panel','BattleBottomHUD.layout.right_station.tip_panel'})
a0.tip_panel_title=resolve_first_ui_node({'BattleBottomHUD.layout.tip_panel.title','BattleBottomHUD.layout.right_station.tip_panel.title'})
a0.tip_panel_body=resolve_first_ui_node({'BattleBottomHUD.layout.tip_panel.body','BattleBottomHUD.layout.right_station.tip_panel.body'})
a0.tip_panel_hint=resolve_first_ui_node({'BattleBottomHUD.layout.tip_panel.hint','BattleBottomHUD.layout.right_station.tip_panel.hint'})
set_ui_visible(a0.tip_panel,false)
safe_ui_call(a0.tip_panel,'set_intercepts_operations',true)
set_ui_text_alignment(a0.tip_panel_title,'左','中')
set_ui_text_alignment(a0.tip_panel_body,'左','中')
set_ui_text_alignment(a0.tip_panel_hint,'右','中')
if a0.bound_events.static_tip_panel_close~=a0.tip_panel and is_ui_alive(a0.tip_panel)then a0.bound_events.static_tip_panel_close=a0.tip_panel;a0.tip_panel:add_fast_event('左键-点击',function()
local cE=get_hud_state()cE.tip_expires_at=0;set_ui_visible(cE.tip_panel,false)end)end;
a0.hover_tip_panel=resolve_first_ui_node({'BattleBottomHUD.layout.right_station.hover_tip_panel','BattleBottomHUD.layout.hover_tip_panel'})
a0.hover_tip_panel_icon_bg=resolve_first_ui_node({'BattleBottomHUD.layout.right_station.hover_tip_panel.icon_bg','BattleBottomHUD.layout.hover_tip_panel.icon_bg'})
a0.hover_tip_panel_icon=resolve_first_ui_node({'BattleBottomHUD.layout.right_station.hover_tip_panel.icon','BattleBottomHUD.layout.hover_tip_panel.icon'})
a0.hover_tip_panel_title=resolve_first_ui_node({'BattleBottomHUD.layout.right_station.hover_tip_panel.title','BattleBottomHUD.layout.hover_tip_panel.title'})
a0.hover_tip_panel_subtitle=resolve_first_ui_node({'BattleBottomHUD.layout.right_station.hover_tip_panel.subtitle','BattleBottomHUD.layout.hover_tip_panel.subtitle'})
a0.hover_tip_panel_body=resolve_first_ui_node({'BattleBottomHUD.layout.right_station.hover_tip_panel.body','BattleBottomHUD.layout.hover_tip_panel.body'})
set_ui_visible(a0.hover_tip_panel,false)
safe_ui_call(a0.hover_tip_panel,'set_intercepts_operations',false)
set_ui_text_alignment(a0.hover_tip_panel_title,'左','中')
set_ui_text_alignment(a0.hover_tip_panel_subtitle,'左','中')
set_ui_text_alignment(a0.hover_tip_panel_body,'左','中')
a0.bond_tip_root=resolve_ui_node('TipsPanel')
a0.bond_tip_panel=resolve_first_ui_node({'TipsPanel.BondTips','BondTips'})
a0.bond_tip_icon=resolve_first_ui_node({'TipsPanel.BondTips.scroll_view.layout_3.image_1','BondTips.scroll_view.layout_3.image_1'})
a0.bond_tip_set_title=resolve_first_ui_node({'TipsPanel.BondTips.scroll_view.layout_3.标题_1','BondTips.scroll_view.layout_3.标题_1'})
a0.bond_tip_title=resolve_first_ui_node({'TipsPanel.BondTips.scroll_view.标题','BondTips.scroll_view.标题'})
a0.bond_tip_have=resolve_first_ui_node({'TipsPanel.BondTips.scroll_view.是否拥有','BondTips.scroll_view.是否拥有'})
a0.bond_tip_swallow=resolve_first_ui_node({'TipsPanel.BondTips.scroll_view.吞噬条件','BondTips.scroll_view.吞噬条件'})
a0.bond_tip_detail_body=resolve_first_ui_node({'TipsPanel.BondTips.scroll_view.详情效果内容','BondTips.scroll_view.详情效果内容'})
a0.bond_tip_special_title=resolve_first_ui_node({'TipsPanel.BondTips.scroll_view.特殊效果标题','BondTips.scroll_view.特殊效果标题'})
a0.bond_tip_special_body=resolve_first_ui_node({'TipsPanel.BondTips.scroll_view.特殊效果内容','BondTips.scroll_view.特殊效果内容'})
a0.bond_tip_skill_title=resolve_first_ui_node({'TipsPanel.BondTips.scroll_view.技能效果','BondTips.scroll_view.技能效果'})
a0.bond_tip_skill_body=resolve_first_ui_node({'TipsPanel.BondTips.scroll_view.技能效果内容','BondTips.scroll_view.技能效果内容'})
if not is_ui_alive(a0.bond_tip_panel)then local cE=a0.bond_tip_root or resolve_ui_node('TipsPanel')if is_ui_alive(cE)then a0.bond_tip_panel=a.resolve_child(cE,'BondTips')end end;
if is_ui_alive(a0.bond_tip_panel)then
if not is_ui_alive(a0.bond_tip_icon)then a0.bond_tip_icon=a.resolve_child(a0.bond_tip_panel,'scroll_view.layout_3.image_1')end;
if not is_ui_alive(a0.bond_tip_set_title)then a0.bond_tip_set_title=a.resolve_child(a0.bond_tip_panel,'scroll_view.layout_3.标题_1')end;
if not is_ui_alive(a0.bond_tip_title)then a0.bond_tip_title=a.resolve_child(a0.bond_tip_panel,'scroll_view.标题')end;
if not is_ui_alive(a0.bond_tip_have)then a0.bond_tip_have=a.resolve_child(a0.bond_tip_panel,'scroll_view.是否拥有')end;
if not is_ui_alive(a0.bond_tip_swallow)then a0.bond_tip_swallow=a.resolve_child(a0.bond_tip_panel,'scroll_view.吞噬条件')end;
if not is_ui_alive(a0.bond_tip_detail_body)then a0.bond_tip_detail_body=a.resolve_child(a0.bond_tip_panel,'scroll_view.详情效果内容')end;
if not is_ui_alive(a0.bond_tip_special_title)then a0.bond_tip_special_title=a.resolve_child(a0.bond_tip_panel,'scroll_view.特殊效果标题')end;
if not is_ui_alive(a0.bond_tip_special_body)then a0.bond_tip_special_body=a.resolve_child(a0.bond_tip_panel,'scroll_view.特殊效果内容')end;
if not is_ui_alive(a0.bond_tip_skill_title)then a0.bond_tip_skill_title=a.resolve_child(a0.bond_tip_panel,'scroll_view.技能效果')end;
if not is_ui_alive(a0.bond_tip_skill_body)then a0.bond_tip_skill_body=a.resolve_child(a0.bond_tip_panel,'scroll_view.技能效果内容')end;
end;
set_ui_visible(a0.bond_tip_panel,false)
if not is_ui_alive(a0.big_cursor)then local a2=get_player()
local cF=a2 and a.get_overlay_parent(y,a2)or nil;
if not cF then return end;

local ac=cF:create_child('文本')ac:set_ui_size(60,60)ac:set_text('◎')ac:set_font_size(28)ac:set_text_color(255,233,158,235)ac:set_text_alignment('中','中')ac:set_z_order(9380)ac:set_intercepts_operations(false)
safe_ui_call(ac,'set_follow_mouse',true,12,-10)a0.big_cursor=ac;set_ui_visible(ac,false)end end;

local function get_attr_row_components(cH)
local cI=j[cH]if not cI then return{}end;

local cJ='BattleBottomHUD.layout.left_station.player_attr_list.'..cI;
return{root=resolve_ui_node(cJ),
label=resolve_ui_node(cJ..'.label'),
value=resolve_ui_node(cJ..'.value'),
delta=resolve_ui_node(cJ..'.delta'),
icon=resolve_ui_node(cJ..'.icon')}end;

local function reset_tip_state()return end;

local function set_bond_tip_root_visible(dA0)
local a0=get_hud_state()
if not is_ui_alive(a0.bond_tip_root)then a0.bond_tip_root=resolve_ui_node('TipsPanel')end;
if not is_ui_alive(a0.bond_tip_root)then return end;
set_ui_visible(a0.bond_tip_root,dA0==true or w.attr_tips_panel_visible==true)end;

local function hide_all_tips()
local a0=get_hud_state()a0.hover_tip_visible=false;a0.bond_tip_visible=false;set_ui_visible(a0.hover_tip_panel,false)
set_ui_visible(a0.bond_tip_panel,false)set_bond_tip_root_visible(false)end;

local function schedule_tip_hide(dA0)
local a0=get_hud_state()a0.bond_tip_hover_token=(a0.bond_tip_hover_token or 0)+1;
local dA1=a0.bond_tip_hover_token;
if not dA0 or dA0<=0 or not y or not y.ltimer or not y.ltimer.wait then hide_all_tips()return end;
y.ltimer.wait(dA0,function()
local dA2=get_hud_state()
if dA2.bond_tip_hover_token==dA1 then hide_all_tips()end end)end;

local function show_hover_tip_payload(bs)
if not bs then hide_all_tips()return end;
ensure_hud()
local a0=get_hud_state()
reset_tip_state()a0.bond_tip_visible=false;set_ui_visible(a0.bond_tip_panel,false)set_bond_tip_root_visible(false)
if not is_ui_alive(a0.hover_tip_panel)then
local dA3=tostring(bs.title or'说明')
local dA4=tostring(bs.body or'')
local dA5=tostring(bs.subtitle or'')
if dA5~=''then
if dA4~=''then dA4=dA5..'\n'..dA4 else dA4=dA5 end
end;
a0.tip_expires_at=math.huge;
a0.tip_title_text=dA3;
a0.tip_body_text=dA4;
set_ui_text(a0.tip_panel_title,dA3)
set_ui_text(a0.tip_panel_body,dA4)
set_ui_visible(a0.tip_panel,a0.visible~=false)return end;
a0.hover_tip_visible=true;set_ui_text(a0.hover_tip_panel_title,bs.title or'说明')
set_ui_text(a0.hover_tip_panel_subtitle,bs.subtitle or'')
set_ui_text(a0.hover_tip_panel_body,bs.body or'')
set_ui_font_size(a0.hover_tip_panel_title,16)
set_ui_font_size(a0.hover_tip_panel_subtitle,13)
set_ui_font_size(a0.hover_tip_panel_body,14)
set_ui_text_color(a0.hover_tip_panel_title,{204,226,255,255})
set_ui_text_color(a0.hover_tip_panel_subtitle,{255,213,96,255})
set_ui_text_color(a0.hover_tip_panel_body,{222,232,244,255})
set_ui_visible(a0.hover_tip_panel_subtitle,bs.subtitle~=nil and bs.subtitle~='')
set_ui_visible(a0.hover_tip_panel_icon_bg,bs.icon~=nil)
set_ui_visible(a0.hover_tip_panel_icon,bs.icon~=nil)
set_ui_image(a0.hover_tip_panel_icon,bs.icon)
set_ui_visible(a0.hover_tip_panel,a0.visible~=false)end;

local function show_bond_tip_payload(bs)
if not bs then hide_all_tips()return end;
ensure_hud()
local a0=get_hud_state()
reset_tip_state()
if not is_ui_alive(a0.bond_tip_panel)or not is_ui_alive(a0.bond_tip_title)then resolve_static_ui_panels()end;
if not is_ui_alive(a0.bond_tip_panel)or not is_ui_alive(a0.bond_tip_title)then show_hover_tip_payload(bs)return end;

local bM=bs.tip_model or{}
local dA6={}append_lines(dA6,bM.set_body_lines or{})
if#dA6==0 then append_multiline_text(dA6,bs.body)end;
local dA7={}append_lines(dA7,bM.bonus_lines or{})
if#dA7==0 then append_multiline_text(dA7,bs.body)end;
local dA8=tostring(bM.effect_body_text or'')
if dA8==''then dA8=tostring(bs.subtitle or'')end;
if dA8==''then local dA9=tostring(bM.set_name_text or'')..tostring(bM.progress_text or'')if dA9~=''then dA8='收录进度：'..dA9 end end;
a0.hover_tip_visible=false;set_ui_visible(a0.hover_tip_panel,false)a0.bond_tip_visible=true;set_ui_text(a0.bond_tip_title,tostring(bM.item_name_text or bs.title or'羁绊卡'))
set_ui_text(a0.bond_tip_have,tostring(bM.quality_text or''))
set_ui_text(a0.bond_tip_swallow,dA8)
set_ui_text(a0.bond_tip_detail_body,dA8)
set_ui_text(a0.bond_tip_special_title,tostring(bM.set_title_text or bond_skill_label))
set_ui_text(a0.bond_tip_special_body,table.concat(dA6,'\n'))
set_ui_text(a0.bond_tip_skill_title,bond_skill_label)
set_ui_text(a0.bond_tip_skill_body,table.concat(dA7,'\n'))
set_ui_text(a0.bond_tip_set_title,tostring(bM.set_name_text or'')..tostring(bM.progress_text or''))
set_ui_visible(a0.bond_tip_special_title,#dA6>0)
set_ui_visible(a0.bond_tip_special_body,#dA6>0)
set_ui_visible(a0.bond_tip_detail_body,dA8~='')
set_ui_visible(a0.bond_tip_skill_title,#dA7>0)
set_ui_visible(a0.bond_tip_skill_body,#dA7>0)
set_ui_visible(a0.bond_tip_icon,bM.icon_res~=nil)
set_ui_image(a0.bond_tip_icon,bM.icon_res)
set_ui_visible(a0.bond_tip_panel,a0.visible~=false)set_bond_tip_root_visible(a0.visible~=false)end;

local function resolve_combat_module_ui(cO)return resolve_ui_node('BattleBottomHUD.layout.center_hub.combat_module.'..cO)end;

local function get_or_create_hero_model_ui()
local a0=get_hud_state()
if is_ui_alive(a0.hero_model_ui)then return a0.hero_model_ui end;

local cQ=resolve_ui_node('BattleBottomHUD.layout.center_hub.hero_panel')
if not is_ui_alive(cQ)or type(cQ.create_child)~='function'then return nil end;

local bn,
cR=pcall(cQ.create_child,cQ,'模型')
if not bn or not is_ui_alive(cR)then return nil end;
a0.hero_model_ui=cR;set_ui_anchor(cR,0.5,0.5)
set_ui_size(cR,k.width,k.height)
set_ui_pos(cR,k.x,k.y)
set_ui_visible(cR,true)
apply_ui_model_camera(cR,l)return cR end;

local function bind_click_handler(cT,u,cU)
local a0=get_hud_state()
if a0.bound_events[cT]==u and is_ui_alive(u)then return end;

if not is_ui_alive(u)or not u.add_fast_event then return end;
a0.bound_events[cT]=u;safe_ui_call(u,'set_intercepts_operations',true)u:add_fast_event('左键-点击',function()
if S then S()end;
cU()end)end;

local function bind_hover_handlers(cT,u,cW,cX)
local a0=get_hud_state()
if a0.bound_events[cT]==u and is_ui_alive(u)then return end;

if not is_ui_alive(u)or not u.add_fast_event then return end;
a0.bound_events[cT]=u;safe_ui_call(u,'set_intercepts_operations',true)u:add_fast_event('鼠标-移入',function()
if cW then cW(u)end end)u:add_fast_event('鼠标-移出',function()
if cX then cX(u)end end)end;

local function hide_tip_panel()
local a0=get_hud_state()a0.tip_expires_at=0;set_ui_visible(a0.tip_panel,false)end;

local function show_tip_panel(ac,c_,bz)
ensure_hud()
local a0=get_hud_state()
local d0=tonumber(c_)
if d0~=nil and d0<=0 then a0.tip_expires_at=math.huge else a0.tip_expires_at=(w.runtime_elapsed or 0)+math.max(1,d0 or f)end;
a0.tip_title_text=bz or'系统提示'a0.tip_body_text=tostring(ac or'')
set_ui_text(a0.tip_panel_title,bz or'系统提示')
set_ui_text(a0.tip_panel_body,tostring(ac or''))
set_ui_visible(a0.tip_panel,a0.visible~=false)end;

local function refresh_tip_panel_visibility()
local a0=get_hud_state()
local d2=a0.tip_expires_at and a0.tip_expires_at>(w.runtime_elapsed or 0)
set_ui_visible(a0.tip_panel,a0.visible~=false and d2)end;

local function refresh_hover_tip_visibility()
local a0=get_hud_state()
reset_tip_state()
set_ui_visible(a0.hover_tip_panel,a0.visible~=false and a0.hover_tip_visible==true)
set_ui_visible(a0.bond_tip_panel,a0.visible~=false and a0.bond_tip_visible==true)end;

local function toggle_big_cursor()
local X=ensure_ui_preferences()X.big_cursor=not X.big_cursor;
local a0=get_hud_state()
set_ui_visible(a0.big_cursor,a0.visible~=false and X.big_cursor)
show_tip_panel(X.big_cursor and'大鼠标已开启，鼠标位置会显示辅助圈。'or'大鼠标已关闭。',4,'鼠标辅助')end;

local function toggle_damage_text_visible()
local X=ensure_ui_preferences()X.hide_damage_text=not X.hide_damage_text;show_tip_panel(X.hide_damage_text and'已屏蔽跳字。'or'已恢复跳字显示。',4,'本地显示')end;

local function toggle_hit_effects_visible()
local X=ensure_ui_preferences()X.hide_hit_effects=not X.hide_hit_effects;show_tip_panel(X.hide_hit_effects and'已屏蔽局内技能特效。'or'已恢复局内技能特效。',4,'本地显示')end;

local function toggle_soft_pause()
local X=ensure_ui_preferences()X.soft_paused=not X.soft_paused;
if X.soft_paused then y.game.enable_soft_pause()
show_tip_panel('对局已暂停，再点一次继续。',4,'战斗控制')
else y.game.resume_soft_pause()
show_tip_panel('对局已继续。',4,'战斗控制')end end;

local function toggle_runtime_attr_panel()
ensure_hud()
local a0=get_hud_state()a0.attr_panel_visible=not a0.attr_panel_visible;
if a0.attr_panel_visible then
local d9=M and M()or{
string.format('等级：%d',get_hero_level()),
string.format('攻击：%s',format_short_number(get_hero_attr('攻击结算值','攻击'))),
string.format('护甲：%s',format_short_number(get_hero_attr('护甲结算值','护甲'))),
string.format('力量：%s',format_short_number(get_hero_attr('最终力量','力量'))),
string.format('智力：%s',format_short_number(get_hero_attr('最终智力','智力'))),
string.format('敏捷：%s',format_short_number(get_hero_attr('最终敏捷','敏捷'))),
}
set_ui_text(a0.attr_panel_title,'属性总览')
set_ui_text(a0.attr_panel_body,table.concat(d9,'\n\n'))end;
set_ui_visible(a0.attr_panel,a0.visible~=false and a0.attr_panel_visible)return a0.attr_panel_visible end;

local function set_static_labels()
local X=ensure_ui_preferences()
set_ui_text(resolve_ui_node('top.top.left_buttons.btn_exit'),'退出')
set_ui_text(resolve_ui_node('top.top.left_buttons.btn_setting'),'设置')
set_ui_text(resolve_ui_node('top.top.left_buttons.btn_save'),'存档')
set_ui_text(resolve_ui_node('top.top.left_buttons.btn_pause'),X.soft_paused and'继续'or'暂停')
set_ui_text(resolve_ui_node('top.top.left_buttons.btn_powerup'),'')
set_ui_visible(resolve_ui_node('top.top.left_buttons.btn_powerup'),false)
set_ui_text(resolve_ui_node('top.top.left_buttons.btn_hotkey'),'键位')
set_ui_visible(resolve_ui_node('BattleBottomHUD.layout.left_station.toggle_frame'),false)
set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.draw_button.button'),'抽卡')
set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.reward_button.button'),'如何变强')
set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.kill_reward_button.button'),'杀敌')
set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.fish_button.button'),'钓鱼')
set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.draw_button.hotkey'),'')
set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.reward_button.hotkey'),'')
set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.kill_reward_button.hotkey'),'')
set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.fish_button.hotkey'),'')end;

local function show_weapon_tip()
local bs=N and N()or nil;
if not bs then hide_tip_panel()return end;
show_tip_panel(format_gear_upgrade_tip(bs),0,bs.title_text or'成长武器')end;

local function show_slot_item_tip(bm)
local bo=get_hero_item_by_slot(bm)
if bo and is_weapon_item(bo)then show_weapon_tip()return end;

local bz,
bJ=get_item_display_info(bo)
if bz and bJ then show_tip_panel(bJ,0,bz)return end;
hide_tip_panel()end;

local function show_skill_tip(bm,cj)
local ck=get_skill_slot_entries(cj or 4)
local c4=ck[bm]if not c4 then hide_tip_panel()return end;
show_tip_panel(c4.tip_text or'当前没有技能说明。',0,c4.tip_title or c4.name or'技能')end;

local function show_evolution_tip(bm)
local c4=get_evolution_slot_entries(h)[bm]if not c4 then hide_tip_panel()return end;
show_tip_panel(c4.tip_text or'当前没有技能说明。',0,c4.tip_title or c4.name or'技能')end;

local function show_buff_tip(bm)
local ck=R and R(z)or{}
local c4=ck[bm]if not c4 then hide_tip_panel()return end;
show_tip_panel(c4.tip_text or'当前没有效果说明。',0,c4.tip_title or'魔法效果')end;

local function show_loadout_tip(bm)
show_hover_tip_payload(build_slot_tooltip(bm))end;

local function show_bond_slot_tip(bm)
local bs=build_bond_slot_tooltip(bm)
if bs then show_bond_tip_payload(bs)return end;
show_hover_tip_payload({title='羁绊位 '..tostring(bm),subtitle='',body='当前槽位暂无羁绊说明。',icon=nil})end;

local function show_draw_button_tip()
show_hover_tip_payload(build_draw_tooltip())end;

local function show_hero_catalog_tip()
show_hover_tip_payload(build_hero_catalog_tooltip())end;

local function show_evolution_entry_tip()
show_hover_tip_payload(build_evolution_entry_tooltip())end;

local function show_save_panel_tip()
show_hover_tip_payload(build_save_panel_tooltip())end;

local function show_consumable_tip(bm)
show_hover_tip_payload(build_consumable_tooltip(bm))end;

local function refresh_loadout_row()
local dp=N and N()or nil;set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.loadout_row.loadout_title'),'物品栏')
set_ui_size(resolve_ui_node('BattleBottomHUD.layout.right_station.loadout_row.loadout_title'),92,17)
set_ui_text_alignment(resolve_ui_node('BattleBottomHUD.layout.right_station.loadout_row.loadout_title'),'中','中')for bL=1,6 do local cJ=string.format('BattleBottomHUD.layout.right_station.loadout_row.loadout_slot_%d',bL)
local bo=get_hero_item_by_slot(bL)
local dq=bo and bo.get_icon and bo:get_icon()or nil;
local dr=resolve_ui_node(cJ..'.icon')
if not dq and bL==1 and dp then dq=dp.icon_res end;
if not dq and bL==1 then dq=bk_icon_fallback() end;
set_ui_visible(dr,dq~=nil)
set_ui_image(dr,dq)
if not dq then set_ui_image(dr,nil)end end end;

local function ensure_buff_prefab()
local a0=get_hud_state()
local a2=get_player()
if not a2 or not y or not y.ui_prefab or type(y.ui_prefab.create)~='function' then return end;
local buff_parent=resolve_combat_module_ui('buff_row') or resolve_ui_node('BattleBottomHUD.layout.center_hub.combat_module')

if not is_ui_alive(a0.buff_prefab_root) then
local ok,prefab=pcall(y.ui_prefab.create,a2,'bufflist',buff_parent)
if ok and prefab then
local root=prefab.get_child and prefab:get_child()or nil
if is_ui_alive(root) then
a0.buff_prefab=prefab
a0.buff_prefab_root=root
a0.buff_list_comp=a.resolve_child(root,'buff_list')or a.resolve_child(root,'bufflist')
safe_ui_call(root,'set_z_order',9570)
safe_ui_call(root,'set_intercepts_operations',false)
set_ui_visible(root,a0.visible~=false)
end
end
end
end;

local function refresh_buff_list()
local a0=get_hud_state()
local hero=get_hero_unit()
if is_ui_alive(a0.buff_list_comp)then
if hero and a0.buff_list_comp.set_buff_on_ui then
pcall(a0.buff_list_comp.set_buff_on_ui,a0.buff_list_comp,hero)
set_ui_visible(a0.buff_prefab_root,a0.visible~=false)
else
set_ui_visible(a0.buff_prefab_root,false)
end
end
end;

ensure_hud=function()
ensure_ui_preferences()
resolve_static_ui_panels()
ensure_buff_prefab()
bind_click_handler('top_pause',resolve_ui_node('top.top.left_buttons.btn_pause'),function()
toggle_soft_pause()
refresh_hud()end)
bind_click_handler('top_save',resolve_ui_node('top.top.left_buttons.btn_save'),function()
if J and J()~=false then return end;

if L then L()end end)
bind_click_handler('top_hotkey',resolve_ui_node('top.top.left_buttons.btn_hotkey'),function()
show_tip_panel(get_hotkey_help_text(),10,'快捷键')end)
bind_click_handler('toggle_damage',resolve_ui_node('BattleBottomHUD.layout.left_station.toggle_frame.toggle_damage.button'),function()
toggle_damage_text_visible()
refresh_hud()end)
bind_click_handler('toggle_effects',resolve_ui_node('BattleBottomHUD.layout.left_station.toggle_frame.toggle_sfx.button'),function()
toggle_hit_effects_visible()
refresh_hud()end)
bind_click_handler('toggle_cursor',resolve_ui_node('BattleBottomHUD.layout.left_station.toggle_frame.toggle_cursor.button'),function()
toggle_big_cursor()
refresh_hud()end)
bind_click_handler('draw_button',resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.draw_button.button'),function()
if E then E()end;
refresh_hud()end)
bind_click_handler('reward_button',resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.reward_button.button'),function()
refresh_hud()end)
bind_click_handler('kill_reward_button',resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.kill_reward_button.button'),function()
if G then G()end;
refresh_hud()end)
bind_click_handler('fish_button',resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.fish_button.button'),function()
if J and J()~=false then return end;

if L then L()end end)
bind_hover_handlers('draw_button_hover',resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.draw_button'),function()
show_draw_button_tip()end,function()
hide_all_tips()end)
bind_hover_handlers('reward_button_hover',resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.reward_button'),function()
show_hero_catalog_tip()end,function()
hide_all_tips()end)
bind_hover_handlers('kill_reward_button_hover',resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.kill_reward_button'),function()
show_evolution_entry_tip()end,function()
hide_all_tips()end)
bind_hover_handlers('fish_button_hover',resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.fish_button'),function()
show_save_panel_tip()end,function()
hide_all_tips()end)for bL=1,3 do bind_hover_handlers('battle_consumable_hover_'..tostring(bL),resolve_ui_node(string.format('BattleBottomHUD.layout.right_station.consumable_panel.slot_%d',bL)),function()
show_consumable_tip(bL)end,function()
hide_all_tips()end)end;
bind_click_handler('gold_trial',resolve_combat_module_ui('challenge_row.gold_trial'),function()
if I then I('gold_trial')end;
refresh_hud()end)
bind_click_handler('treasure_trial',resolve_combat_module_ui('challenge_row.treasure_trial'),function()
if I then I('wood_trial')end;
refresh_hud()end)
bind_click_handler('battle_loadout_slot_1',resolve_ui_node('BattleBottomHUD.layout.right_station.loadout_row.loadout_slot_1'),function()
if K then K('loadout_slot_click')end;
refresh_hud()end)for bL=1,6 do bind_hover_handlers('battle_loadout_hover_'..tostring(bL),resolve_ui_node(string.format('BattleBottomHUD.layout.right_station.loadout_row.loadout_slot_%d',bL)),function()
show_loadout_tip(bL)end,function()
hide_all_tips()end)end;

for bL=1,h do bind_hover_handlers('battle_skill_hover_'..tostring(bL),resolve_combat_module_ui(string.format('skill_bar.skill_slot_%d',bL)),function()
show_evolution_tip(bL)end,function()
hide_tip_panel()end)end;

for bL=1,i do bind_hover_handlers('battle_buff_hover_'..tostring(bL),resolve_combat_module_ui(string.format('buff_row.buff_slot_%d',bL)),function()
show_buff_tip(bL)end,function()
hide_tip_panel()end)end;

for bL=1,g do local dA3=string.format('BattleBottomHUD.layout.right_station.card_panel.card_slot_%d',bL)
local dA4=resolve_ui_node(dA3)
local function show_bond_tip_for_slot()
local a0=get_hud_state()a0.bond_tip_hover_token=(a0.bond_tip_hover_token or 0)+1;
show_bond_slot_tip(bL)end;
local function hide_bond_tip_after_delay()schedule_tip_hide(0.06)end;
bind_hover_handlers('battle_bond_hover_'..tostring(bL),dA4,show_bond_tip_for_slot,hide_bond_tip_after_delay)
bind_hover_handlers('battle_bond_hover_icon_'..tostring(bL),resolve_ui_node(dA3..'.icon'),show_bond_tip_for_slot,hide_bond_tip_after_delay)
bind_hover_handlers('battle_bond_hover_frame_'..tostring(bL),resolve_ui_node(dA3..'.frame'),show_bond_tip_for_slot,hide_bond_tip_after_delay)
bind_hover_handlers('battle_bond_hover_bg_'..tostring(bL),resolve_ui_node(dA3..'.card_slot_'..tostring(bL)..'_bg'),show_bond_tip_for_slot,hide_bond_tip_after_delay)
bind_click_handler('battle_bond_slot_'..tostring(bL),dA4,function()
show_tip_panel('bond_progress 功能已移除。',4,'提示')end)end;
bind_click_handler('battle_exp_bar_evolve',resolve_combat_module_ui('exp_bar.evolve_click_area'),function()
if G then G()end;
refresh_hud()end)
set_static_labels()return get_hud_state()end;

local function refresh_top_bar()
set_ui_text(resolve_ui_node('top.top.金币.image_3.label_2'),format_short_number(w.resources and w.resources.gold or 0))
set_ui_text(resolve_ui_node('top.top.木材.image_3.label_2'),format_short_number(w.resources and w.resources.wood or 0))
set_ui_text(resolve_ui_node('top.top.人口.image_3.label_2'),format_short_number(w.total_kills or 0))
set_ui_text(resolve_ui_node('top.top.金币.delta'),string.format('+%s/s',format_short_number(get_hero_attr('每秒金币'))))
set_ui_text(resolve_ui_node('top.top.木材.delta'),string.format('+%s/s',format_short_number(get_hero_attr('每秒木材'))))
set_ui_text(resolve_ui_node('top.top.人口.delta'),string.format('敌 %d',math.max(0,tonumber(w.total_enemy_alive)or 0)))
local dt,
du=get_current_tip_text()
set_ui_text(resolve_ui_node('top.top.system_notice.notice_title'),dt)
set_ui_text(resolve_ui_node('top.top.system_notice.notice_text'),du)
local dv=w.current_stage_def and(w.current_stage_def.display_label or w.current_stage_def.display_name)or'当前章节'
local dw=w.current_mode_def and w.current_mode_def.display_name or'战斗模式'
local dx=w.active_wave and w.active_wave.wave and w.active_wave.wave.name or(w.current_wave_index and w.current_wave_index>0 and string.format('第%d波',w.current_wave_index)or'未开始')
local dy=({get_pending_choice_status()})[1]or(w.session_phase=='battle'and'战斗中'or'准备中')
local dz;
if w.active_wave and w.active_wave.wave and w.active_wave.wave.boss_spawn_sec and w.active_wave.boss_spawned~=true then dz=string.format('Boss %.1fs',math.max(0,(w.active_wave.wave.boss_spawn_sec or 0)-(w.active_wave.elapsed or 0)))
else dz=string.format('敌人 %d',math.max(0,tonumber(w.total_enemy_alive)or 0))end;
set_ui_text(resolve_ui_node('top.tophud.layout_2.curlevel'),dv)
set_ui_text(resolve_ui_node('top.tophud.layout_2.curlevel_sub'),dw)
set_ui_text(resolve_ui_node('top.tophud.layout_2.gametime'),format_time_mmss(w.runtime_elapsed or 0))
set_ui_text(resolve_ui_node('top.tophud.layout_2.wave'),dx)
set_ui_text(resolve_ui_node('top.tophud.layout_2.phase_text'),dy)
set_ui_text(resolve_ui_node('top.tophud.layout_2.threat_text'),dz)
set_ui_text(resolve_ui_node('top.top.scoreboard.title'),'玩家状态')
set_ui_text(resolve_ui_node('top.top.scoreboard.player_name'),get_player_name())
set_ui_text(resolve_ui_node('top.top.scoreboard.player_power'),format_short_number(get_hero_attr('攻击结算值','攻击')))
set_ui_text(resolve_ui_node('top.top.scoreboard.player_state'),w.session_phase=='battle'and'战斗中'or'局外')
set_ui_text(resolve_ui_node('top.top.scoreboard.player_level'),tostring(get_hero_level()))
set_ui_text(resolve_ui_node('top.top.scoreboard.player_equip'),'0')
set_ui_text(resolve_ui_node('top.top.scoreboard.player_swallow'),tostring(w.bond_runtime and table_count(w.bond_runtime.completed_root_sets)or 0))for cH=2,4 do set_ui_text(resolve_ui_node(string.format('top.top.scoreboard.player_name_%d',cH)),'-')
set_ui_text(resolve_ui_node(string.format('top.top.scoreboard.player_power_%d',cH)),'-')
set_ui_text(resolve_ui_node(string.format('top.top.scoreboard.player_state_%d',cH)),'-')
set_ui_text(resolve_ui_node(string.format('top.top.scoreboard.player_level_%d',cH)),'-')
set_ui_text(resolve_ui_node(string.format('top.top.scoreboard.player_equip_%d',cH)),'-')
set_ui_text(resolve_ui_node(string.format('top.top.scoreboard.player_swallow_%d',cH)),'-')end end;

local function refresh_player_attr_list()
local dB=format_short_number(get_hero_attr('攻击结算值','攻击'))
local dC=format_short_number(get_hero_attr('护甲结算值','护甲'))
local dD={{label='战力',
value=dB,
delta=''},
{label='攻击',
value=dB,
delta=format_percent_delta(get_hero_attr('攻击增幅'),get_hero_attr('最终攻击'))},
{label='护甲',
value=dC,
delta=format_percent_delta(get_hero_attr('护甲增幅'),get_hero_attr('最终护甲'))},
{label='力量',
value=format_short_number(get_hero_attr('最终力量','力量')),
delta=format_percent_delta(get_hero_attr('力量增幅'),get_hero_attr('最终力量增幅'))},
{label='智力',
value=format_short_number(get_hero_attr('最终智力','智力')),
delta=format_percent_delta(get_hero_attr('智力增幅'),get_hero_attr('最终智力增幅'))},
{label='敏捷',
value=format_short_number(get_hero_attr('最终敏捷','敏捷')),
delta=format_percent_delta(get_hero_attr('敏捷增幅'),get_hero_attr('最终敏捷增幅'))}}for cH,dE in ipairs(dD)do local dF=get_attr_row_components(cH)
set_ui_visible(dF.root,true)
set_ui_text(dF.label,dE.label)
set_ui_text(dF.value,dE.value)
set_ui_text(dF.delta,dE.delta)
set_ui_text_color(dF.delta,{131,210,255,255})
end end;

local function refresh_hero_panel()
local bc,
bd=get_hero_hp_info()
local bf,
bg=get_hero_exp_info()
local dH=get_hero_unit()
local dI=resolve_ui_node('BattleBottomHUD.layout.center_hub.hero_panel.hero_portrait')
local cR=get_or_create_hero_model_ui()
local dJ=is_ui_alive(cR)and dH~=nil;set_ui_visible(dI,not dJ)
if dJ then set_ui_visible(cR,true)
bind_ui_model_unit(cR,dH,false,true,true)
apply_ui_model_camera(cR,l)
else set_ui_visible(cR,false)
set_ui_image(dI,get_hero_icon())end;
set_ui_text(resolve_ui_node('BattleBottomHUD.layout.center_hub.hero_panel.hero_name'),get_hero_name())
set_ui_text_alignment(resolve_ui_node('BattleBottomHUD.layout.center_hub.hero_panel.hero_name'),'中','中')
set_ui_progress(resolve_ui_node('BattleBottomHUD.layout.center_hub.hero_panel.hero_hp_fill'),bc,bd)
set_ui_text(resolve_ui_node('BattleBottomHUD.layout.center_hub.hero_panel.hero_hp_text'),string.format('%s/%s',format_short_number(bc),format_short_number(bd)))
set_ui_text_alignment(resolve_ui_node('BattleBottomHUD.layout.center_hub.hero_panel.hero_hp_text'),'中','中')
set_ui_visible(resolve_combat_module_ui('exp_bar'),true)
local dK=math.max(0,math.min(1,bf/math.max(1,bg)))
local dL=has_pending_evolution_choice()
local dM=math.max(1,math.floor(m*dK+0.5))
set_ui_text(resolve_combat_module_ui('exp_bar.level_label'),string.format('等级：%d',get_hero_level()))
set_ui_size(resolve_combat_module_ui('exp_bar.fill'),dM,n)
set_ui_pos(resolve_combat_module_ui('exp_bar.fill'),o+dM/2,12)
set_ui_image_color(resolve_combat_module_ui('exp_bar.fill'),dL and{255,177,37,255}or{210,38,178,255})
set_ui_image_color(resolve_combat_module_ui('exp_bar.fill_glow'),dL and{255,191,58,150}or{255,86,220,72})
set_ui_image_color(resolve_combat_module_ui('exp_bar.evolve_glow'),dL and{255,173,45,210}or{255,173,45,0})
set_ui_text_color(resolve_combat_module_ui('exp_bar.evolve_text'),dL and{255,226,58,255}or{255,226,58,0})
set_ui_visible(resolve_combat_module_ui('exp_bar.evolve_click_area'),dL)
set_ui_text(resolve_combat_module_ui('exp_bar.exp_text'),dL and''or string.format('%s/%s',format_short_number(bf),format_short_number(bg)))
set_ui_text_alignment(resolve_combat_module_ui('exp_bar.exp_text'),'中','中')end;

local function hide_challenge_row()
set_ui_visible(resolve_combat_module_ui('challenge_row'),false)
set_ui_visible(resolve_combat_module_ui('hero_level'),false)end;

local function refresh_challenge_row()
local dP=w.challenge_charge_map and w.challenge_charge_map.gold_trial or w.challenge_charges or 0;
local dQ=w.challenge_charge_map and w.challenge_charge_map.wood_trial or w.challenge_charges or 0;set_ui_text(resolve_combat_module_ui('challenge_row.gold_trial.title'),'金币挑战')
set_ui_text(resolve_combat_module_ui('challenge_row.gold_trial.count'),tostring(math.max(0,tonumber(dP)or 0)))
set_ui_text(resolve_combat_module_ui('challenge_row.treasure_trial.title'),'木材挑战')
set_ui_text(resolve_combat_module_ui('challenge_row.treasure_trial.count'),tostring(math.max(0,tonumber(dQ)or 0)))
set_ui_text(resolve_combat_module_ui('challenge_row.climb_layer.title'),'当前波次')
set_ui_text(resolve_combat_module_ui('challenge_row.climb_layer.count'),tostring(math.max(0,tonumber(w.current_wave_index)or 0)))
set_ui_text(resolve_combat_module_ui('challenge_row.realm_progress.title'),'存活敌人')
set_ui_text(resolve_combat_module_ui('challenge_row.realm_progress.count'),tostring(math.max(0,tonumber(w.total_enemy_alive)or 0)))end;

local function refresh_skill_bar()
local ck=get_evolution_slot_entries(h)for bL=1,h do local cJ=string.format('skill_bar.skill_slot_%d',bL)
local c4=ck[bL]
local dS=resolve_combat_module_ui(cJ)
local dr=resolve_combat_module_ui(cJ..'.icon')
set_ui_visible(dS,true)
set_ui_visible(dr,c4~=nil and c4.icon~=nil)
set_ui_image(dr,c4 and c4.icon or nil)
if not c4 or not c4.icon then set_ui_image(dr,nil)end end end;

local function refresh_buff_row()
local ck=R and R(i)or{}for bL=1,i do local cJ=string.format('buff_row.buff_slot_%d',bL)
local c4=ck[bL]
local dS=resolve_combat_module_ui(cJ)
local dr=resolve_combat_module_ui(cJ..'.icon')
set_ui_visible(dS,c4~=nil)
set_ui_visible(dr,c4~=nil and c4.icon~=nil)
set_ui_image(dr,c4 and c4.icon or nil)
set_ui_image_color(dr,{255,255,255,255})
if not c4 or not c4.icon then set_ui_image(dr,nil)end end end;

local function refresh_attr_list()
refresh_player_attr_list()end;

local function refresh_status_text()
set_ui_visible(resolve_combat_module_ui('status_text'),true)
set_ui_text(resolve_combat_module_ui('status_text'),'状态：')
set_ui_text_alignment(resolve_combat_module_ui('status_text'),'左','中')
set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.station_hint'),get_station_hint_text())
set_ui_text_alignment(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.station_hint'),'中','中')end;

local function refresh_bond_card_panel()for bL=1,g do local cJ=string.format('BattleBottomHUD.layout.right_station.card_panel.card_slot_%d',bL)
local dr=resolve_ui_node(cJ..'.icon')
local dq=Q and Q(bL)or nil;set_ui_visible(resolve_ui_node(cJ),bL<=7 or bL==8)
if dq then set_ui_visible(dr,true)
set_ui_image(dr,dq)
else set_ui_visible(dr,false)
set_ui_image(dr,nil)end end end;

refresh_hud=function()
ensure_hud()
local a0=get_hud_state()
ensure_buff_prefab()
refresh_buff_list()
set_static_labels()
refresh_top_bar()
refresh_attr_list()
refresh_hero_panel()
hide_challenge_row()
refresh_skill_bar()
refresh_buff_row()
refresh_status_text()
refresh_bond_card_panel()
refresh_loadout_row()
set_ui_visible(a0.big_cursor,a0.visible~=false and ensure_ui_preferences().big_cursor)
set_ui_visible(a0.attr_panel,a0.visible~=false and a0.attr_panel_visible)
set_ui_visible(a0.buff_prefab_root,a0.visible~=false)
refresh_tip_panel_visibility()
refresh_hover_tip_visibility()return a0 end;

local function set_hud_visible(aa)
local a0=get_hud_state()a0.visible=aa==true;set_ui_visible(resolve_ui_node('top'),aa)
set_ui_visible(resolve_ui_node('BattleBottomHUD'),aa)
set_ui_visible(resolve_ui_node('GameHUD'),false)
set_ui_visible(resolve_ui_node('bottom_bg'),false)
set_ui_visible(a0.attr_panel,
aa==true and a0.attr_panel_visible)
set_ui_visible(a0.tip_panel,
aa==true and a0.tip_expires_at>(w.runtime_elapsed or 0))
set_ui_visible(a0.hover_tip_panel,
aa==true and a0.hover_tip_visible==true)
set_ui_visible(a0.bond_tip_panel,
aa==true and a0.bond_tip_visible==true)
set_bond_tip_root_visible(aa==true and a0.bond_tip_visible==true)
set_ui_visible(a0.big_cursor,
aa==true and ensure_ui_preferences().big_cursor)
set_ui_visible(a0.buff_prefab_root,aa==true)end;

-- public api alias
	show_runtime_tip_panel=show_tip_panel

return{ensure_hud=ensure_hud,
refresh_hud=refresh_hud,
set_visible=set_hud_visible,
show_tip_panel=show_runtime_tip_panel,
toggle_attr_panel=toggle_runtime_attr_panel,
safe_ui_call=safe_ui_call,
set_ui_visible=set_ui_visible,
set_ui_text=set_ui_text,
set_ui_text_color=set_ui_text_color,
set_ui_font_size=set_ui_font_size,
set_ui_text_alignment=set_ui_text_alignment,
set_ui_image=set_ui_image,
set_ui_image_color=set_ui_image_color,
set_ui_size=set_ui_size,
set_ui_anchor=set_ui_anchor,
set_ui_pos=set_ui_pos,
set_ui_progress=set_ui_progress,
bind_ui_model_unit=bind_ui_model_unit,
apply_ui_model_camera=apply_ui_model_camera,
set_ui_pos_percent=set_ui_pos_percent,
toggle_big_cursor=toggle_big_cursor,
toggle_damage_text_visible=toggle_damage_text_visible,
toggle_hit_effects_visible=toggle_hit_effects_visible,
toggle_soft_pause=toggle_soft_pause}end;

return e













