local a=require'ui.ui_root'local bt=require'runtime.bond_tip_model_builder'local QualityImageTable=require'data.object_tables.quality_image_table'local SkillRuntimeTuning=require'data.object_tables.skill_runtime_tuning'local BondUiText=SkillRuntimeTuning and SkillRuntimeTuning.bond and SkillRuntimeTuning.bond.ui or{}local BondUiSkillBlockTitle=tostring(BondUiText.skill_block_title or'[羁绊技能]')local BondUiSkillSectionTemplate=tostring(BondUiText.skill_section_template or'【%s】羁绊技能：')local BondUiSkillSectionFallback=tostring(BondUiText.skill_section_fallback or'【羁绊】羁绊技能：')local b={}function b.create(c)local d=c.STATE;
local e=c.y3;
local f=c.get_player;
local g=c.get_runtime_hud_system;
local h=c.get_runtime_overview_model;
local i=c.get_pending_round_choice_kind;
local j=c.refresh_current_choice;
local k=c.apply_round_choice;
local l=c.defer_choice_panel;
local m=c.get_growth_weapon_item_key;
local n=c.build_treasure_slot_text;
local o=c.get_treasure_quality_label;
local p=c.get_treasure_def;
local q=c.get_evolution_quality_label;
local r=c.build_bond_swallow_panel_model;
local s;
local t;
local u;
local v;
local w;
local x;
local y;
local z;
local A;
local B;
local C={BondChoice2=nil,BondChoice3=nil,BondChoice4=nil}local D=nil;
local E=false;
local F;
local G={}local H=9500;
local I=9560;
local J=9570;
local K=9540;
local L=999;
local M={40,80,100}
local function resolve_quality_frame_image_for_bond_card(q)
if QualityImageTable and QualityImageTable.get_frame_image then
local img=QualityImageTable.get_frame_image(q)
if img and img~=0 then return img end
end
return nil
end
local function N()d.message_prompt_system=nil;d.talk_panel_system=nil;d.inventory_panel_system=nil end;
s=function(O)return O and(not O.is_removed or not O:is_removed())end;
t=function(O,P)if s(O)and O.set_visible then O:set_visible(P==true)end end;
u=function(O,Q)if s(O)and O.set_text then O:set_text(Q or'')end end;
v=function(O,Q)local R=tostring(Q or'')if not s(O)then return end;
if O.set_text then O:set_text(R)end;
if O.set_btn_status_string then O:set_btn_status_string('常态',R)O:set_btn_status_string('悬浮',R)O:set_btn_status_string('按下',R)O:set_btn_status_string('禁用',R)end end;
w=function(O,S)if s(O)and O.set_font_size and S then O:set_font_size(S)end end;
x=function(O,T)if s(O)and O.set_image and T and T~=0 then O:set_image(T)end end;
y=function(O,U)if s(O)and O.set_image_color and U then O:set_image_color(U[1]or 255,U[2]or 255,U[3]or 255,U[4]or 255)end end;
z=function(O,V)if s(O)and O.set_button_enable then O:set_button_enable(V==true)end end;
A=function(O,W)if s(O)and O.set_intercepts_operations then O:set_intercepts_operations(W==true)end end;
B=function(O,X)if s(O)and O.set_z_order and X then O:set_z_order(X)end end;
local function Y(Z)local _=C[Z]if s(_)then return _ end;
local a0=f and f()or nil;
if not a0 then return nil end;
local a1=a.resolve_ui(e,a0,Z)C[Z]=a1;
return a1 end;
local function a2(Z,a3)local a1=Y(Z)if not a1 then return nil end;
if not a3 or a3==''then return a1 end;
return a.resolve_child(a1,a3)end;
local function a4()t(Y('BondChoice2'),false)t(Y('BondChoice3'),false)t(Y('BondChoice4'),false)end;
local function a5(a6)if tonumber(a6)and a6<=2 then return'BondChoice2'end;
if tonumber(a6)and a6>=4 then return'BondChoice4'end;
return'BondChoice3'end;
local function a7(Z)if Z=='BondChoice2'then return'bond_choice_2'end;
if Z=='BondChoice4'then return'bond_choice_4'end;
return'bond_choice_3'end;
local function a8(Z)if Z=='BondChoice2'then return'2'end;
if Z=='BondChoice4'then return'4'end;
return'3'end;
local function a9(Q)if Q==nil then return''end;
return tostring(Q):gsub('^%s+',''):gsub('%s+$','')end;
local function aa(ab,ac)if ac=='treasure'and o then return o(ab)end;
if ac=='evolution'and q then return q(ab)end;
if ab=='legendary'then return'传说'end;
if ab=='epic'then return'史诗'end;
if ab=='rare'or ab=='excellent'then return'稀有'end;
return'普通'end;
local function ad(ae)local af=math.min((tonumber(ae)or 0)+1,#M)return M[af]or M[#M]end;
local function ag(ah)if ah and e and e.item and e.item.get_icon_id_by_key then return e.item.get_icon_id_by_key(ah)end;
return L end;
local function ai(aj)if aj and e and e.unit and e.unit.get_icon_by_key then return e.unit.get_icon_by_key(aj)end;
return L end;
local function ak()local ah=m and m()or nil;
if ah and e and e.item and e.item.get_name_by_key then return e.item.get_name_by_key(ah)end;
return'成长武器'end;
local function al()return ag(m and m()or nil)end;
local function am(Q,an)local ao={}local ap=tostring(Q or'')
ap=ap:gsub('\r\n','\n'):gsub('\r','\n')
if string.find(ap,'\n',1,true)==nil then ap=ap:gsub('。%s*','。\n')ap=ap:gsub('；%s*','\n')ap=ap:gsub(';%s*','\n')ap=ap:gsub('，','\n')ap=ap:gsub(',%s*','\n')end;
ap=ap:gsub('\n+','\n')
for aq in string.gmatch(ap,'[^\n]+')do local ar=a9(aq)if ar~=''then ao[#ao+1]=ar end;if#ao>=(an or 2)then break end end;
return ao end;
local function as(at,au,av,aw,ab,V)local ao=type(av)=='table'and av or am(av,2)return{title_text=a9(at),subtitle_text=a9(au),body_lines=ao,icon=aw or L,quality=ab or'common',enabled=V~=false}end;
local function ax(ay)local az=aa(ay and ay.quality or nil)local aA=a9(ay and ay.tag or'')
if aA==''or aA:find('流派',1,true)then aA='羁绊技能'end;
aA=string.format('[%s] %s',az,aA)
local aB=a9(ay and ay.name or'')
if aB==''then aB=a9(ay and ay.display_name or'')end;
return as(aB,aA,ay and(ay.desc or ay.summary)or'',ay and(ay.ui_icon or ay.icon)or L,ay and ay.quality or'common')end;
local function aC(ay)local ao=am(ay and ay.current_text or'',2)local aD=am(ay and ay.desc_text or'',2)local aE={}local aF={}
for aG,aq in ipairs(ao)do local aH=a9(aq):gsub('^当前：',''):gsub('。$','')if aH~=''and not aF[aH]then aF[aH]=true;aE[#aE+1]=aH end end;
if#aE<2 then for aG,aq in ipairs(aD)do if#aE>=2 then break end;
local aH=a9(aq):gsub('^当前：',''):gsub('。$','')if aH~=''and not aF[aH]then aF[aH]=true;aE[#aE+1]=aH end end end;ao=aE;
local aI=a9(ay and ay.bond_root_name or'')local aJ=a9(ay and ay.bond_root_progress_text or'')local aA=''
if aI~=''then if aJ~=''then aA=string.format('羁绊： %s (%s)',aI,aJ)else aA='羁绊： '..aI end else aA=a9(ay and ay.title_text or'')if aA~=''then aA='羁绊： '..aA end end;
local aB=a9(ay and(ay.pretty_display_name or ay.display_name or ay.title_text)or'')if aB==''then aB='未命名战术卡'end;
local ret=as(aB,aA,ao,ay and(ay.ui_icon or ay.icon)or L,ay and ay.quality or'common')ret.source_choice=ay;ret.tip_model=bt.build_from_choice(ay)return ret end;
local function aH(ay)local aI=d and d.gear_state or nil;
local aJ=aI and aI.pending_affix_choice or nil;
local aK=aJ and tonumber(aJ.level)or 0;
local aA=aK>0 and string.format('[%s] %s Lv.%d',aa(ay and ay.quality or nil),ak(),aK)or string.format('[%s] %s词缀',aa(ay and ay.quality or nil),ak())
return as(ay and(ay.display_name or ay.id)or'',aA,ay and ay.summary or'',al(),ay and ay.quality or'common')end;
local function aL(aM)local aI=d and(d.evolution_runtime or d.mark_runtime)or nil;
local aN=aI and aI.current_round or nil;
return as(aM and aM.name or'未命名专精',string.format('[%s] %s',aa(aM and aM.quality or nil,'evolution'),aN and aN.ui_title or'专精进阶'),aM and aM.summary or'',ai(aM and aM.hero_unit_id or nil),aM and aM.quality or'common')end;
local function aO()local aI=d and d.treasure_runtime or nil;
if not aI or not aI.active_slots then return 0 end;
local aP=0;
for aQ=1,3,1 do if aI.active_slots[aQ]then aP=aP+1 end end;
return aP end;
local function aR(aM)local az=aa(aM and aM.quality or nil,'treasure')local aS=aO()>=3 and'·需替换'or''
return as(aM and aM.name or'未命名宝物',string.format('[%s] 宝物%s',az,aS),aM and aM.summary or'',ag(aM and aM.editor_item_key or nil),aM and aM.quality or'common')end;
local function aT(aQ)local aI=d and d.treasure_runtime or nil;
local aU=aI and aI.active_slots and aI.active_slots[aQ]or nil;
local aV=p and p(aU)or nil;
local aW=aI and aI.pending_replace_choice or nil;
local ao=am(aV and aV.summary or'',2)if#ao==0 and n then ao=am(n(aQ),2)end;if#ao<2 and aW and aW.name and aW.name~=''then ao[#ao+1]='换入：'..tostring(aW.name)end;
local az=aa(aV and aV.quality or nil,'treasure')
local aA=az~=''and string.format('[%s] 替换位 %d',az,aQ)or string.format('替换位 %d',aQ)
return as(aV and aV.name or string.format('宝物位 %d',aQ),aA,ao,ag(aV and aV.editor_item_key or nil),aV and aV.quality or'common',aU~=nil)end;
local function aX()if d.choice_panel_hidden==true then return nil end;
local ac=i and i()or nil;
if ac=='gear'then local aI=d and d.gear_state or nil;
if not aI or aI.awaiting_choice~=true or not aI.current_choices or#aI.current_choices==0 then return nil end;
local aY={}for aE,ay in ipairs(aI.current_choices)do aY[#aY+1]=aH(ay)end;
local aZ=aI.current_round or aI.pending_affix_choice or{}local a_=tonumber(aZ.free_refresh_left or 0)or 0;
return{kind=ac,panel_name=a5(#aY),choices=aY,current_round=aZ,can_refresh=a_>0,disabled_refresh_text='刷新已用尽'}end;
if ac=='bond'then local aI=d and d.bond_runtime or nil;
if not aI or aI.awaiting_choice~=true or not aI.current_choices or#aI.current_choices==0 then return nil end;
local aY={}for aE,ay in ipairs(aI.current_choices)do aY[#aY+1]=aC(ay)end;
return{kind=ac,panel_name=a5(#aY),choices=aY,current_round=aI.current_round or aI.current_offer_round,can_refresh=true}end;
if ac=='evolution'or ac=='mark'then local aI=d and(d.evolution_runtime or d.mark_runtime)or nil;
if not aI or aI.awaiting_choice~=true or not aI.current_choices or#aI.current_choices==0 then return nil end;
local aY={}for aE,ay in ipairs(aI.current_choices)do aY[#aY+1]=aL(ay)end;
return{kind='evolution',panel_name=a5(#aY),choices=aY,current_round=aI.current_round,can_refresh=false,disabled_refresh_text='当前不可刷新'}end;
if ac=='treasure'then local aI=d and d.treasure_runtime or nil;
if not aI then return nil end;
if aI.awaiting_replace and aI.pending_replace_choice then local aY={}for aQ=1,3,1 do aY[#aY+1]=aT(aQ)end;
return{kind='treasure_replace',panel_name=a5(#aY),choices=aY,current_round=aI.current_round,can_refresh=false,disabled_refresh_text='已进入替换'}end;
if not aI.awaiting_choice or not aI.current_choices or#aI.current_choices==0 then return nil end;
local aY={}for aE,ay in ipairs(aI.current_choices)do aY[#aY+1]=aR(ay)end;
return{kind=ac,panel_name=a5(#aY),choices=aY,current_round=aI.current_round,can_refresh=true}end;
return nil end;
local function b0(Z,af,ay)local b1=string.format('bond_choice_%s.cards_row.card_%d',a8(Z),af)local b2=a2(Z,b1)
if not b2 then return end;
t(b2,ay~=nil)
if not ay then return end;
u(a2(Z,b1 ..string.format('.title_%d',af)),ay.title_text)
u(a2(Z,b1 ..string.format('.bond_%d',af)),ay.subtitle_text)
x(a2(Z,b1 ..string.format('.icon_%d',af)),ay.icon or L)
local b3=ay.body_lines or{}
u(a2(Z,b1 ..string.format('.value_1_%d',af)),b3[1]or'')
u(a2(Z,b1 ..string.format('.value_2_%d',af)),b3[2]or'')
t(a2(Z,b1 ..string.format('.value_2_%d',af)),b3[2]~=nil)
local aB=a2(Z,b1 ..string.format('.title_%d',af))
if ay.quality=='legendary'then
if s(aB)and aB.set_text_color then aB:set_text_color(255,184,64,255)end
elseif ay.quality=='epic'then
if s(aB)and aB.set_text_color then aB:set_text_color(208,62,255,255)end
elseif s(aB)and aB.set_text_color then
aB:set_text_color(45,176,255,255)
end;
local b4=a2(Z,b1 ..string.format('.pick_btn_%d',af))A(b4,true)z(b4,ay.enabled~=false)end;
local function b4b(ay)local aI=ay and(ay.tip_model or bt.build_from_choice(ay.source_choice or ay))or nil;
if not aI then return nil end;
local aJ={}local aK=tostring(aI.set_name_text or ay.bond_root_name or'')local aL=tostring(aI.progress_text or ay.bond_root_progress_text or'')local aM=tonumber(string.match(aL,'/%s*(%d+)'))or tonumber(string.match(aL,'/([0-9]+)'))or 0;
if aI.bonus_lines and#aI.bonus_lines>0 then aJ[#aJ+1]=BondUiSkillBlockTitle for aE,aq in ipairs(aI.bonus_lines)do aJ[#aJ+1]=tostring(aq)end end;
if#aJ>0 then aJ[#aJ+1]=''end;
aJ[#aJ+1]='[吞噬条件]'
if aK~=''and aM>0 then aJ[#aJ+1]=string.format('集齐%d个 %s 卡牌自动吞噬',aM,aK)elseif aK~=''then aJ[#aJ+1]=string.format('集齐同羁绊的 %s 卡牌自动吞噬',aK)else aJ[#aJ+1]='集齐相同羁绊的卡牌自动吞噬'end;
local aN={}
if aI.set_body_lines and#aI.set_body_lines>0 then
for aE,aq in ipairs(aI.set_body_lines)do aN[#aN+1]=tostring(aq)end
elseif aI.effect_body_text and aI.effect_body_text~=''then
for aq in tostring(aI.effect_body_text):gmatch('[^\n]+')do aN[#aN+1]=aq end
elseif ay and ay.advanced_text and ay.advanced_text~=''then
for aq in tostring(ay.advanced_text):gmatch('[^\n]+')do aN[#aN+1]=aq end
end;
if#aN>0 then aJ[#aJ+1]=''if aK~=''then aJ[#aJ+1]=string.format(BondUiSkillSectionTemplate,aK)else aJ[#aJ+1]=BondUiSkillSectionFallback end;
for aE,aq in ipairs(aN)do aJ[#aJ+1]=tostring(aq)end end;
local aO={}if aK~=''then aO[#aO+1]='羁绊：'..aK..aL end;
return{kind='bond',title=tostring(aI.item_name_text or ay.title_text or'流派卡牌'),subtitle=table.concat(aO,'  '),body=table.concat(aJ,'\n'),icon=aI.icon_res or ay.icon}end;
local function b4c(Z,af)local bq=aX()if not bq or bq.kind~='bond'then return end;
local ay=bq.choices and bq.choices[af]or nil;
local bn=g and g()or nil;
if bn and bn.show_hover_tip_panel then bn.show_hover_tip_panel(b4b(ay))end end;
local function b4d()local bn=g and g()or nil;
if bn and bn.hide_hover_tip_panel then bn.hide_hover_tip_panel()end end;
local function b5(Z,a6)G[Z]=G[Z]or{}local b6=G[Z]local b7=a7(Z)
for af=1,a6 do
local b8='pick_btn_'..tostring(af)
if b6[b8]~=true then
local b1=string.format('%s.cards_row.card_%d.pick_btn_%d',b7,af,af)local b9=a2(Z,b1)
if s(b9)and b9.add_fast_event then
A(b9,true)
b9:add_fast_event('左键-点击',function()if k then k(af)end end)
b9:add_fast_event('鼠标-移入',function()b4c(Z,af)end)
b9:add_fast_event('鼠标-移出',function()b4d()end)
b6[b8]=true
end
end
end;
if b6.refresh_btn~=true then local ba=a2(Z,b7 ..'.refresh_btn')if s(ba)and ba.add_fast_event then A(ba,true)ba:add_fast_event('左键-点击',function()if j then j()end end)b6.refresh_btn=true end end;
if b6.later_btn~=true then local bb=a2(Z,b7 ..'.later_btn')if s(bb)and bb.add_fast_event then A(bb,true)bb:add_fast_event('左键-点击',function()if l then l()end end)b6.later_btn=true end end end;
local function bc(Z)B(Y(Z),K)end;
local function bd(P)local a0=f and f()or nil;
if not a0 then return end;
local be=a.resolve_ui(e,a0,'BattleBottomHUD')
local bf=a.resolve_ui(e,a0,'GameHUD')
local bg=a.resolve_ui(e,a0,'GameHUD.main')
local bh=a.resolve_ui(e,a0,'GameHUD.setting_btn')
local bi=a.resolve_ui(e,a0,'GameHUD.exit_btn')
local bj=a.resolve_ui(e,a0,'GameHUD.setting_panel')
B(bf,H)B(bj,I)B(bh,J)B(bi,J)t(be,P)
if P==true then
t(bf,true)t(bg,true)t(bh,true)t(bi,true)
t(a.resolve_ui(e,a0,'bottom_bg.bottom_bg'),false)t(a.resolve_ui(e,a0,'bottom_bg'),false)
if be then
local bk={
'GameHUD.main.main_unit',
'GameHUD.main.main_unit_name',
'GameHUD.main.attr_list',
'GameHUD.main.skill_list',
'GameHUD.main.main_hp_bar',
'GameHUD.main.main_mp_bar',
'GameHUD.main.inventory',
'GameHUD.main.bag_btn',
'GameHUD.player_attr_list',
'GameHUD.main.player_attr_list'
}
for aE,a3 in ipairs(bk)do t(a.resolve_ui(e,a0,a3),false)end
end;
return end;t(bj,false)local bl={'GameHUD.main','GameHUD','bottom_bg.bottom_bg','bottom_bg'}for aE,a3 in ipairs(bl)do t(a.resolve_ui(e,a0,a3),false)end end;
local function bm()local bn=g and g()or nil;
return bn and bn.ensure_hud and bn.ensure_hud()or nil end;
local function bo()local bn=g and g()or nil;
return bn and bn.refresh_hud and bn.refresh_hud()or nil end;
local function bp()local bq=aX()if not bq then a4()return nil end;
local Z=bq.panel_name or a5(#bq.choices)local a1=Y(Z)
if not a1 then return nil end;
b5('BondChoice2',2)b5('BondChoice3',3)b5('BondChoice4',4)
bc('BondChoice2')bc('BondChoice3')bc('BondChoice4')
t(Y('BondChoice2'),Z=='BondChoice2')t(Y('BondChoice3'),Z=='BondChoice3')t(Y('BondChoice4'),Z=='BondChoice4')
return a1,bq end;
local function br()local a1,bq=bp()if not a1 or not bq then return nil end;
local Z=bq.panel_name or a5(#bq.choices)for af=1,4 do b0(Z,af,bq.choices[af])end;
local ba=a2(Z,a7(Z)..'.refresh_btn')local aZ=bq.current_round or{}local a_=tonumber(aZ.free_refresh_left or 0)or 0;
if bq.can_refresh~=true then v(ba,bq.disabled_refresh_text or'当前不可刷新')else if a_>0 then v(ba,string.format('免费刷新候选（剩余%d次）',a_))else local ae=tonumber(aZ.refresh_paid_count or 0)or 0;v(ba,string.format('刷新候选（%d木材）',ad(ae)))end end;
z(ba,bq.can_refresh==true)
w(ba,15)
return a1 end;
local function bs()a4()return nil end;
local function bt()local bu=d.runtime_overview_mode;d.runtime_overview_mode='attr'local bq=h and h()or nil;d.runtime_overview_mode=bu;
if not bq or not bq.sections then return'属性面板暂不可用'end;
local ao={}local bv={'summary','skills','bonds','treasures'}
for aE,bw in ipairs(bv)do
local bx=bq.sections[bw]
if bx and bx.title and bx.lines and#bx.lines>0 then
ao[#ao+1]=string.format('[%s]',tostring(bx.title))
for aE,aq in ipairs(bx.lines)do ao[#ao+1]=tostring(aq)if#ao>=8 then break end end
end
if#ao>=8 then break end
end;
if#ao==0 then return'当前没有可显示的属性面板'end;
return table.concat(ao,'\n')end;
local function by(bz)local bn=g and g()or nil;
if bn and bn.ensure_hud then bn.ensure_hud()end;
if bn and bn.show_tip_panel then bn.show_tip_panel(bt(),bz or 8)end end;
local function bA(P)bd(P)local bn=g and g()or nil;
if bn and bn.set_visible then bn.set_visible(P)end;
if d.message_prompt_system and d.message_prompt_system.set_visible then d.message_prompt_system.set_visible(P)end;
if d.talk_panel_system and d.talk_panel_system.set_visible then d.talk_panel_system.set_visible(P)end;
if d.inventory_panel_system and d.inventory_panel_system.set_visible then d.inventory_panel_system.set_visible(P)end end;
local function bB()return nil end;
local function bC()return nil end;
local function bD()return nil end;
local function bE()if s(D)then return D end;
local a0=f and f()or nil;
if not a0 then return nil end;D=a.resolve_ui(e,a0,'BondSwallowPanel')return D end;
local function bF(a3)local a0=f and f()or nil;
if not a0 or not a3 then return nil end;
return a.resolve_ui(e,a0,'BondSwallowPanel.'..a3)end;
local function bG()if E then return end;
local bH=bF('layout.main_frame.close_button')
if not s(bH)or not bH.add_fast_event then return end;
E=true;
A(bF('layout.dim_bg'),true)A(bF('layout.main_frame'),true)
bH:add_fast_event('左键-点击',function()d.bond_swallow_panel_visible=false;t(bF('layout'),false)t(bE(),false)b4d()end)
end;
local function bI(bJ,bK,bL,bM,bN,bO)local bP=bJ and bJ.create_child and bJ:create_child(bK)or nil;
if s(bP)then if bP.set_ui_size then bP:set_ui_size(bL or 0,bM or 0)end;
if bP.set_pos then bP:set_pos(bN or 0,bO or 0)end end;
return bP end;
local function bJ(bP,bQ,bR,bS,bT,bU,bV,bW)local bX=bI(bP,'文本',bT,bU,bR,bS)u(bX,bQ)w(bX,bV)if s(bX)and bX.set_text_color and bW then bX:set_text_color(bW[1]or 255,bW[2]or 255,bW[3]or 255,bW[4]or 255)end;
if s(bX)and bX.set_text_alignment then bX:set_text_alignment(0,8)end;
return bX end;
local function bK(bP,bY,bR,bS,bT,bU,bW)local bX=bI(bP,'图片',bT,bU,bR,bS)x(bX,bY)if bW then y(bX,bW)end;
return bX end;
local function bL()local bZ=G.bond_swallow_dynamic or{}for aE,bX in ipairs(bZ)do if s(bX)and bX.remove then bX:remove()end end;G.bond_swallow_dynamic={}end;
local function bM(bX)G.bond_swallow_dynamic=G.bond_swallow_dynamic or{}if s(bX)then G.bond_swallow_dynamic[#G.bond_swallow_dynamic+1]=bX end;
return bX end;
local function bN(bO,b_,ca)if not s(bO)then return end;
if bO.set_ui_gridview_count then bO:set_ui_gridview_count(math.max(1,b_),ca)end;
if bO.set_ui_gridview_size then bO:set_ui_gridview_size(ca==2 and 184 or 84,ca==2 and 42 or 82)end;
if bO.set_ui_gridview_space then bO:set_ui_gridview_space(8,8)end;
if bO.set_ui_gridview_scroll then bO:set_ui_gridview_scroll(true)end end;
local function bO(bP,bq,af,cb)local cc=bM(bI(bP,'空节点',184,42,0,0))
if not s(cc)then return end;
A(cc,true)
bK(cc,999,92,21,184,42,cb and{255,212,76,110}or{72,126,190,88})
bJ(cc,bq.pretty_display_name or bq.display_name or bq.title or'羁绊',10,22,118,18,14,cb and{255,235,135,255}or{224,238,255,255})
bJ(cc,bq.progress_text or'0/0',130,22,46,18,13,bq.consumed and{255,214,90,255}or{168,198,230,255})
if cc.add_fast_event then cc:add_fast_event('左键-点击',function()d.bond_swallow_selected_root_index=af;d.bond_swallow_panel_visible=true;
if F then F()end end)end;
if bP and bP.insert_ui_gridview_comp then bP:insert_ui_gridview_comp(cc,af)end end;
local function bQ(bP,bq,af)local cc=bM(bI(bP,'空节点',76,76,0,0))
if not s(cc)then return end;
A(cc,true)
bK(cc,999,38,38,76,76,{255,255,255,95})
local cd=bK(cc,bq and bq.icon or nil,38,44,48,48,bq and bq.unlocked and{255,255,255,255}or{98,108,122,150})
t(cd,bq~=nil and bq.icon~=nil)
A(cd,false)
local frame_img=resolve_quality_frame_image_for_bond_card(bq and bq.quality or nil)
local ce_frame=bK(cc,frame_img,38,44,56,56,nil)
t(ce_frame,frame_img~=nil)
A(ce_frame,false)
bK(cc,999,38,38,76,76,bq and bq.consumed and{255,204,78,110}or bq and bq.unlocked and{70,165,255,85}or{255,204,78,0})
bJ(cc,bq and(bq.pretty_display_name or bq.display_name or bq.title)or'',4,10,68,16,11,bq and bq.unlocked and{230,238,248,255}or{128,142,160,255})
if cc.add_fast_event then cc:add_fast_event('鼠标-移入',function()local bn=g and g()or nil;
if bn and bn.show_hover_tip_panel then bn.show_hover_tip_panel(b4b(bq))end end)cc:add_fast_event('鼠标-移出',function()b4d()end)end;
if bP and bP.insert_ui_gridview_comp then bP:insert_ui_gridview_comp(cc,af)end end;F=function()local a1=bE()if not s(a1)then return nil end;bG()if d.bond_swallow_panel_visible~=true then bL()t(bF('layout'),false)t(a1,false)return a1 end;
local bq=r and r(d,d.bond_swallow_selected_root_index or 1)or nil;
if not bq then bL()t(bF('layout'),false)t(a1,false)return a1 end;
d.bond_swallow_selected_root_index=bq.selected_root_index or 1;
t(a1,true)t(bF('layout'),true)t(bF('layout.dim_bg'),true)t(bF('layout.main_frame'),true)
B(a1,9560)u(bF('layout.main_frame.total_value'),tostring(bq.total_consumed or 0))
bL()
local ce=bF('layout.main_frame.group_panel.group_grid')local cf=bF('layout.main_frame.card_grid.card_list')local cg=bq.root_entries or{}local ch=bq.card_entries or{}
bN(ce,math.max(1,math.ceil(#cg/2)),2)bN(cf,math.max(1,math.ceil(#ch/5)),5)
for af,bR in ipairs(cg)do bO(ce,bR,af,af==(bq.selected_root_index or 1))end;
for af,bR in ipairs(ch)do bQ(cf,bR,af)end;
local bS=bq.detail or{}
u(bF('layout.main_frame.detail_panel.detail_title'),bS.title or'未选择羁绊')
u(bF('layout.main_frame.detail_panel.detail_status'),string.format('%s  %s',tostring(bS.status or'未激活'),tostring(bS.progress or'0/0')))
u(bF('layout.main_frame.detail_panel.detail_body'),bS.body or'')
return a1 end;
local function bP()d.bond_swallow_panel_visible=true;d.bond_swallow_selected_root_index=d.bond_swallow_selected_root_index or 1;
return F()end;
return{
destroy_choice_panel=bs,
ensure_choice_panel=bp,
ensure_runtime_hud=bm,
install_panel_systems=N,
refresh_choice_panel=br,
refresh_inventory_panel=bD,
refresh_bond_swallow_panel=F,
refresh_runtime_hud=bo,
refresh_runtime_overview=function()end,
set_battle_hud_visible=bA,
show_bond_swallow_panel=bP,
show_runtime_attr_tip_panel=by,
toggle_inventory_panel=bC,
toggle_talk_input=bB
}
end;
return b






