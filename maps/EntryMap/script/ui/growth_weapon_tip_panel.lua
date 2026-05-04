local a=require'ui.ui_root'
local b=require'data.tables.outgame.marks'
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
local function t(u)return a.is_alive(u)end;

local ui_res=a.ui_res or{}
local function Z(_)
local a0=runtime_hud or{}
local nodes=a0.nodes or{}
local a1=nodes[_]if t(a1)then return a1 end;
local a2=get_player and get_player()or nil;
if not a2 then return nil end;
local u=a.resolve_ui(y,a2,_)nodes[_]=u;
return u end;

local function a3(a4)
local a0=runtime_hud or{}
local nodes=a0.nodes or{}
local a5='__first__:'..table.concat(a4 or{},'|')
local a1=nodes[a5]if t(a1)then return a1 end;
local a2=get_player and get_player()or nil;
if not a2 then return nil end;
local u=a.resolve_first_ui(y,a2,a4)nodes[a5]=u;
return u end;

local function a6(u,a7,...)
if not t(u)then return false end;
local a8=u[a7]if type(a8)~='function'then return false end;
return pcall(a8,u,...)end;
local get_player
local y
local runtime_hud
local w
local function aa()
w.ui_preferences=w.ui_preferences or{}
local X=w.ui_preferences;
if X.hide_damage_text==nil then X.hide_damage_text=false end;
if X.hide_hit_effects==nil then X.hide_hit_effects=false end;
if X.big_cursor==nil then X.big_cursor=false end;
if X.soft_paused==nil then X.soft_paused=false end;
return X end;

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

local growth_weapon_tip_hover_token=0
local growth_weapon_tip_visible=false

local function hide_growth_weapon_tip()
growth_weapon_tip_hover_token=(growth_weapon_tip_hover_token or 0)+1
local token=growth_weapon_tip_hover_token
local hover_tip_panel=a3({'BattleBottomHUD.layout.right_station.hover_tip_panel','BattleBottomHUD.layout.hover_tip_panel'})
set_ui_visible(hover_tip_panel,false)
growth_weapon_tip_visible=false
end

local function show_growth_weapon_tip(anchor_ui)
if not anchor_ui or not env.build_growth_weapon_tip_payload then
hide_growth_weapon_tip()
return
end
local payload=env.build_growth_weapon_tip_payload('weapon')
if not payload then
hide_growth_weapon_tip()
return
end
local hover_tip_panel=a3({'BattleBottomHUD.layout.right_station.hover_tip_panel','BattleBottomHUD.layout.hover_tip_panel'})
local hover_tip_title=a3({'BattleBottomHUD.layout.right_station.hover_tip_panel.title','BattleBottomHUD.layout.hover_tip_panel.title'})
local hover_tip_subtitle=a3({'BattleBottomHUD.layout.right_station.hover_tip_panel.subtitle','BattleBottomHUD.layout.hover_tip_panel.subtitle'})
local hover_tip_body=a3({'BattleBottomHUD.layout.right_station.hover_tip_panel.body','BattleBottomHUD.layout.hover_tip_panel.body'})
local hover_tip_icon=a3({'BattleBottomHUD.layout.right_station.hover_tip_panel.icon','BattleBottomHUD.layout.hover_tip_panel.icon'})
local hover_tip_icon_bg=a3({'BattleBottomHUD.layout.right_station.hover_tip_panel.icon_bg','BattleBottomHUD.layout.hover_tip_panel.icon_bg'})
if not t(hover_tip_panel)or not t(hover_tip_title)then
hide_growth_weapon_tip()
return
end
local body_lines={}
if payload.attr_lines and #payload.attr_lines>0 then
body_lines[#body_lines+1]='当前属性增幅'
for _,line in ipairs(payload.attr_lines)do
body_lines[#body_lines+1]=line
end
end
if payload.affix_lines and #payload.affix_lines>0 then
body_lines[#body_lines+1]=''
body_lines[#body_lines+1]='当前词缀'
for _,line in ipairs(payload.affix_lines)do
body_lines[#body_lines+1]=line
end
end
if payload.cost_text then
body_lines[#body_lines+1]=''
body_lines[#body_lines+1]=payload.cost_text
end
local subtitle_text=payload.subtitle_text or''
if subtitle_text==''and payload.cost_text then
subtitle_text=payload.cost_text
end
set_ui_text(hover_tip_title,payload.title_text or'成长武器')
set_ui_text(hover_tip_subtitle,subtitle_text)
set_ui_text(hover_tip_body,table.concat(body_lines,'\n'))
set_ui_font_size(hover_tip_title,16)
set_ui_font_size(hover_tip_subtitle,13)
set_ui_font_size(hover_tip_body,14)
set_ui_text_color(hover_tip_title,{204,226,255,255})
set_ui_text_color(hover_tip_subtitle,{255,213,96,255})
set_ui_text_color(hover_tip_body,{222,232,244,255})
set_ui_text_alignment(hover_tip_title,'左','中')
set_ui_text_alignment(hover_tip_subtitle,'左','中')
set_ui_text_alignment(hover_tip_body,'左','中')
set_ui_visible(hover_tip_subtitle,subtitle_text~=nil and subtitle_text~='')
set_ui_visible(hover_tip_icon_bg,payload.icon_res~=nil)
set_ui_visible(hover_tip_icon,payload.icon_res~=nil)
if payload.icon_res then
set_ui_image(hover_tip_icon,payload.icon_res)
end
set_ui_visible(hover_tip_panel,true)
growth_weapon_tip_visible=true
end

e.create=function(v)
get_player=v.get_player
y=v.y3
runtime_hud=v.STATE and v.STATE.runtime_hud or{}
w=v.STATE or{}
set_ui_visible=v.set_ui_visible
set_ui_text=v.set_ui_text
set_ui_text_color=v.set_ui_text_color
set_ui_font_size=v.set_ui_font_size
set_ui_text_alignment=v.set_ui_text_alignment
set_ui_image=v.set_ui_image
set_ui_image_color=v.set_ui_image_color
set_ui_size=v.set_ui_size
set_ui_anchor=v.set_ui_anchor
set_ui_pos=v.set_ui_pos
set_ui_progress=v.set_ui_progress
return e
end

e.show_for_anchor=function(anchor_ui,payload)
if not payload then
hide_growth_weapon_tip()
return
end
local hover_tip_panel=a3({'BattleBottomHUD.layout.right_station.hover_tip_panel','BattleBottomHUD.layout.hover_tip_panel'})
local hover_tip_title=a3({'BattleBottomHUD.layout.right_station.hover_tip_panel.title','BattleBottomHUD.layout.hover_tip_panel.title'})
local hover_tip_subtitle=a3({'BattleBottomHUD.layout.right_station.hover_tip_panel.subtitle','BattleBottomHUD.layout.hover_tip_panel.subtitle'})
local hover_tip_body=a3({'BattleBottomHUD.layout.right_station.hover_tip_panel.body','BattleBottomHUD.layout.hover_tip_panel.body'})
local hover_tip_icon=a3({'BattleBottomHUD.layout.right_station.hover_tip_panel.icon','BattleBottomHUD.layout.hover_tip_panel.icon'})
local hover_tip_icon_bg=a3({'BattleBottomHUD.layout.right_station.hover_tip_panel.icon_bg','BattleBottomHUD.layout.hover_tip_panel.icon_bg'})
if not t(hover_tip_panel)or not t(hover_tip_title)then
return
end
local body_lines={}
if payload.attr_lines and #payload.attr_lines>0 then
body_lines[#body_lines+1]='当前属性增幅'
for _,line in ipairs(payload.attr_lines)do
body_lines[#body_lines+1]=line
end
end
if payload.affix_lines and #payload.affix_lines>0 then
body_lines[#body_lines+1]=''
body_lines[#body_lines+1]='当前词缀'
for _,line in ipairs(payload.affix_lines)do
body_lines[#body_lines+1]=line
end
end
if payload.cost_text then
body_lines[#body_lines+1]=''
body_lines[#body_lines+1]=payload.cost_text
end
local subtitle_text=payload.subtitle_text or''
if subtitle_text==''and payload.cost_text then
subtitle_text=payload.cost_text
end
set_ui_text(hover_tip_title,payload.title_text or'成长武器')
set_ui_text(hover_tip_subtitle,subtitle_text)
set_ui_text(hover_tip_body,table.concat(body_lines,'\n'))
set_ui_font_size(hover_tip_title,16)
set_ui_font_size(hover_tip_subtitle,13)
set_ui_font_size(hover_tip_body,14)
set_ui_text_color(hover_tip_title,{204,226,255,255})
set_ui_text_color(hover_tip_subtitle,{255,213,96,255})
set_ui_text_color(hover_tip_body,{222,232,244,255})
set_ui_text_alignment(hover_tip_title,'左','中')
set_ui_text_alignment(hover_tip_subtitle,'左','中')
set_ui_text_alignment(hover_tip_body,'左','中')
set_ui_visible(hover_tip_subtitle,subtitle_text~=nil and subtitle_text~='')
set_ui_visible(hover_tip_icon_bg,payload.icon_res~=nil)
set_ui_visible(hover_tip_icon,payload.icon_res~=nil)
if payload.icon_res then
set_ui_image(hover_tip_icon,payload.icon_res)
end
set_ui_visible(hover_tip_panel,true)
growth_weapon_tip_visible=true
end

e.hide=function()
hide_growth_weapon_tip()
end

e.get_visible=function()
return growth_weapon_tip_visible==true
end

return e