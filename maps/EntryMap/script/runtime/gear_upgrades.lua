local a={}

local b=require'data.tables.economy.gear_upgrade_config'

local c={'weapon'}

local d={weapon='成长武器'}

local e={

['物理攻击']={is_percent=false},

['法术攻击']={is_percent=false},

['攻击速度']={is_percent=true},

['暴击率']={is_percent=true},

['暴击伤害']={is_percent=true},

['生命值']={is_percent=false},

['生命恢复']={is_percent=false},

['护甲']={is_percent=false},

['魔法抗性']={is_percent=false},

['移动速度']={is_percent=false}

}

local f=100;

local g=10;

local h=3;

local i=3;

local j={'common','rare','epic'}local k={common='普通',rare='稀有',epic='史诗'}local function l(m)return m or b end;

local function n(o)local p={}for q,r in pairs(o or{})do if r~=0 then p[q]=r end end;

return p end;

local function s(t,o)for q,r in pairs(o or{})do local u=tonumber(r)or 0;

if u~=0 then t[q]=(t[q]or 0)+u end end;

return t end;

local function v(w,m)local x=l(m)return x.slots and x.slots[w]or nil end;

local function y(w,m)local z=v(w,m)if z and z.weapon_id and z.weapon_id~=''then return z.weapon_id end;

return w end;

local function A(w,B,m,C)local x=l(m)local D=C or y(w,x)if x.levels_by_weapon and x.levels_by_weapon[D]then return x.levels_by_weapon[D][B]or nil end;

if x.levels_by_level then return x.levels_by_level[B]or nil end;

return nil end;

local function E(F,m)if not F then return{}end;

local x=l(m)if x.affixes_by_pool and x.affixes_by_pool[F]then return x.affixes_by_pool[F]end;

return{}end;

local function G(w,m)local z=v(w,m)if z and z.max_level and z.max_level>0 then return z.max_level end;

return f end;

local function H(w,B,m,C)local I=A(w,B,m,C)if I~=nil then return I.is_affix_node==true end;

return B%g==0 end;

local function J(K,w)local z=K.config and K.config.slots and K.config.slots[w]or nil;

local L=z and tonumber(z.init_level)or 1;

K.items[w]=K.items[w]or{slot=w,level=math.max(1,L or 1),affixes={},item_key=z and z.item_key or nil,weapon_id=z and z.weapon_id or w}

K.items[w].level=math.max(1,tonumber(K.items[w].level)or L or 1)

K.items[w].affixes=K.items[w].affixes or{}

if K.items[w].item_key==nil and z and z.item_key~=nil then K.items[w].item_key=z.item_key end;

if(K.items[w].weapon_id==nil or K.items[w].weapon_id=='')and z and z.weapon_id~=nil then K.items[w].weapon_id=z.weapon_id end;

return K.items[w]end;

local function M(r)if math.type and math.type(r)=='integer'then return tostring(r)end;

if r==math.floor(r)then return tostring(math.floor(r))end;

return string.format('%.2f',r):gsub('0+$',''):gsub('%.+$','')end;

local function N(r,O)if O and O.is_percent then return string.format('%s%%',M(r*100))end;

return M(r)end;

local function P(Q,R)if not Q or not R or not R.attr_pick_by_key or not R.get_attribute_by_key then return{'当前无直接属性增幅'}end;

local S=R.attr_pick_by_key(Q)or{}local T={}for U,V in ipairs(S)do local O=e[V]if O then local r=tonumber(R.get_attribute_by_key(Q,V))or 0;

if r~=0 then T[#T+1]=string.format('%s +%s',V,N(r,O))end end end;if#T==0 then return{'当前无直接属性增幅'}end;

return T end;

local ITEM_EDITOR_PATHS={'maps/EntryMap/editor_table/editoritem/%d.json','editor_table/editoritem/%d.json','../editor_table/editoritem/%d.json'}

local ITEM_EDITOR_EXIST_CACHE={}

local FALLBACK_ITEM_KEY=nil;

local DEFAULT_FALLBACK_ITEM_KEY=100001;

local IO_OPEN=io and io.open or nil;

local function a_valid_item_key(Q)

Q=tonumber(Q)

if not Q or Q<=0 then return false end;

if ITEM_EDITOR_EXIST_CACHE[Q]~=nil then return ITEM_EDITOR_EXIST_CACHE[Q]==true end;

if not IO_OPEN then return true end;

for U,pattern in ipairs(ITEM_EDITOR_PATHS)do local path=string.format(pattern,Q)local h=IO_OPEN(path,'r')if h then h:close()ITEM_EDITOR_EXIST_CACHE[Q]=true;return true end end;

ITEM_EDITOR_EXIST_CACHE[Q]=false;return false end;

local function a_pick_fallback_item_key()

if FALLBACK_ITEM_KEY and a_valid_item_key(FALLBACK_ITEM_KEY)then return FALLBACK_ITEM_KEY end;

if a_valid_item_key(DEFAULT_FALLBACK_ITEM_KEY)then

FALLBACK_ITEM_KEY=DEFAULT_FALLBACK_ITEM_KEY

return FALLBACK_ITEM_KEY

end

return nil end;

local function a_resolve_safe_item_key(Q)

if a_valid_item_key(Q)then return tonumber(Q) end;

return a_pick_fallback_item_key() end;

local function a_safe_item_name(R,Q)

if not R or not R.get_name_by_key then return nil end;

local ok,name=pcall(R.get_name_by_key,Q)

if ok and name and tostring(name)~=''then return name end;

return nil end;

local function a_safe_item_icon(R,Q)

if not R or not R.get_icon_id_by_key then return nil end;

local ok,icon=pcall(R.get_icon_id_by_key,Q)

if ok and icon and tonumber(icon)and tonumber(icon)~=0 then return icon end;

return nil end;

local function W(X)local Y={}for U,Z in ipairs(X.affixes or{})do local _=Z.display_name or Z.id;

local a0=k[Z.quality]if a0 and _ then _=string.format('[%s] %s',a0,_)end;

if _ then Y[#Y+1]=tostring(_)end;if#Y>=3 then break end end;if#Y==0 then return{{title='当前词缀',body='暂无词缀'}}end;

local T={}for a1,a2 in ipairs(Y)do T[#T+1]={title=a1==1 and'当前词缀'or string.format('词缀%d',a1),body=a2}end;

return T end;

local function a3(X,a4)if not a4 then return false end;

local a5=a4.unique_group;

local a6=a4.is_unique==true;

if not a5 and not a6 then return false end;

for U,a7 in ipairs(X.affixes or{})do if a7.id==a4.affix_id then return true end;

if a5 and a7.unique_group==a5 then return true end;

if a6 and a7.id==a4.affix_id then return true end end;

return false end;

local function a8(a4,B)return{id=a4.affix_id,affix_id=a4.affix_id,level=B,display_name=a4.display_name,summary=a4.summary,bonus_pack=n(a4.bonus_pack),quality=a4.quality or'common',unique_group=a4.unique_group,is_unique=a4.is_unique==true}

end;

local function a9(w,B,aa)local ab=d[w]or tostring(w)local ac={

{id=w..'_affix_'..tostring(B)..'_1',display_name=ab..'锋芒',summary='攻击向词缀',bonus_pack={}},

{id=w..'_affix_'..tostring(B)..'_2',display_name=ab..'专注',summary='功能向词缀',bonus_pack={}},

{id=w..'_affix_'..tostring(B)..'_3',display_name=ab..'底蕴',summary='成长向词缀',bonus_pack={}}

}

while#ac>aa do ac[#ac]=nil end;

return ac end;

local function ad(w,X,B,m)local z=v(w,m)local aa=z and z.affix_choice_count or h;

if aa<1 then aa=h end;

local I=A(w,B,m,X and X.weapon_id or nil)local ae=E(I and I.affix_pool_id or nil,m)local ac={}local af={}local ag={}local function ah(ai)if not ai or ai.id==nil then return end;

for U,aj in ipairs(ac)do if aj.id==ai.id then return end end;ac[#ac+1]=ai end;

for U,a4 in ipairs(ae)do if not a3(X,a4)then local ak=a8(a4,B)local al=a4.quality or'common'af[al]=af[al]or{}af[al][#af[al]+1]=ak;ag[#ag+1]=ak end end;

for U,al in ipairs(j)do ah(af[al]and af[al][1]or nil)if#ac>=aa then break end end;if#ac<aa then for U,ak in ipairs(ag)do ah(ak)if#ac>=aa then break end end end;if#ac==0 then return a9(w,B,aa)end;

return ac end;

local function am(K,w,B)local X=J(K,w)K.awaiting_choice=true;

K.pending_affix_choice={slot=w,level=B,weapon_id=X.weapon_id}

K.current_choices=ad(w,X,B,K.config)

K.current_round={round_id=K.next_round_id or 1,slot=w,level=B,free_refresh_left=i,refresh_paid_count=0}

K.next_round_id=(K.next_round_id or 1)+1

end;

local function an(X,m)local ao={}local ap=tonumber(X and X.level)or 1;

for B=1,math.max(1,ap)-1,1 do local I=A(X.slot,B,m,X.weapon_id)if I and I.bonus_pack then s(ao,I.bonus_pack)end end;

for U,Z in ipairs(X.affixes or{})do s(ao,Z.bonus_pack)end;

return ao end;

local function aq(ar,as,at,au)local av=false;

local aw={}for q,r in pairs(au or{})do local u=tonumber(r)or 0;aw[q]=true;

local ax=tonumber(at and at[q])or 0;

local ay=u-ax;

if ay~=0 then as.add_attr(ar,q,ay)av=true end end;

for q,ax in pairs(at or{})do if not aw[q]and ax~=0 then as.add_attr(ar,q,-ax)av=true end end;

return av end;

function a.ensure_runtime(az,m)az.gear_state=az.gear_state or{items={},awaiting_choice=false,current_choices=nil,pending_affix_choice=nil,current_round=nil,applied_attr_bonuses={},next_round_id=1}

local K=az.gear_state;

K.config=l(m)

K.items=K.items or{}

K.current_round=K.current_round or nil;

K.applied_attr_bonuses=K.applied_attr_bonuses or{}

K.next_round_id=K.next_round_id or 1;

for U,w in ipairs(c)do J(K,w)end;

return K end;

function a.get_pending_choice_kind(az)local K=az and az.gear_state or nil;

if K and K.awaiting_choice==true then return'gear'end;

return nil end;

function a.get_upgrade_cost(w,ap,m)if not w or ap==nil then return nil end;

if ap>=G(w,m)then return 0 end;

local I=A(w,ap,m)if I then return I.gold_cost end;

local aA=math.floor(math.max(0,ap-1)/10)return 100+aA*50 end;

function a.try_upgrade_levels(aB,w,aC)local az=assert(aB and aB.STATE,'STATE is required')local m=aB and aB.CONFIG and aB.CONFIG.gear_upgrade_config or nil;

local K=a.ensure_runtime(az,m)local X=J(K,w)local aD=az.resources or{}local aE=math.max(1,math.floor(tonumber(aC)or 1))if K.awaiting_choice==true then return X.level end;

for U=1,aE do if X.level>=G(w,K.config)then return X.level end;

local aF=a.get_upgrade_cost(w,X.level,K.config)or 0;if(aD.gold or 0)<aF then return X.level end;aD.gold=(aD.gold or 0)-aF;X.level=X.level+1;

if H(w,X.level,K.config,X.weapon_id)then am(K,w,X.level)return X.level end end;

return X.level end;

function a.apply_affix_choice(aB,aG)local az=assert(aB and aB.STATE,'STATE is required')local m=aB and aB.CONFIG and aB.CONFIG.gear_upgrade_config or nil;

local aH=aB and aB.message or function()end;

local K=a.ensure_runtime(az,m)local aI=K.pending_affix_choice;

if K.awaiting_choice~=true or not aI then return false end;

local a1=math.max(1,math.floor(tonumber(aG)or 1))local ak=K.current_choices and K.current_choices[a1]or nil;

if not ak then return false end;

local X=J(K,aI.slot)

X.affixes[#X.affixes+1]={id=ak.id,level=aI.level,display_name=ak.display_name,summary=ak.summary,bonus_pack=n(ak.bonus_pack),quality=ak.quality or'common',unique_group=ak.unique_group,is_unique=ak.is_unique==true}

local a0=k[ak.quality or'common']or'普通'

local _=ak.display_name or ak.id or'未命名词条'

K.awaiting_choice=false;

K.current_choices=nil;

K.pending_affix_choice=nil;

K.current_round=nil;

aH(string.format('成长武器获得 [%s] 词条：%s。',a0,tostring(_)))

return true end;

function a.refresh_affix_choices(aB)local az=assert(aB and aB.STATE,'STATE is required')local m=aB and aB.CONFIG and aB.CONFIG.gear_upgrade_config or nil;

local aH=aB and aB.message or function()end;

local K=a.ensure_runtime(az,m)local aI=K.pending_affix_choice;

if K.awaiting_choice~=true or not aI then return false end;

local aJ=K.current_round or{round_id=K.next_round_id or 1,slot=aI.slot,level=aI.level,free_refresh_left=i,refresh_paid_count=0}if(aJ.free_refresh_left or 0)<=0 then aH('当前成长武器词缀轮次的免费刷新次数已用尽。')return false end;

local X=J(K,aI.slot)

local ac=ad(aI.slot,X,aI.level,K.config)

if#ac==0 then aH('当前没有可刷新的成长武器词缀候选。')return false end;

aJ.free_refresh_left=aJ.free_refresh_left-1;

K.current_choices=ac;

K.current_round=aJ;

aH(string.format('已免费刷新成长武器词缀，剩余免费次数 %d。',aJ.free_refresh_left))

return true end;

function a.sync_runtime_bonuses(az,ar,m,as)if not az or not ar or not as or not as.add_attr then return false end;

local K=a.ensure_runtime(az,m)local av=false;

for U,w in ipairs(c)do local X=J(K,w)local au=an(X,K.config)local at=K.applied_attr_bonuses[w]or{}if aq(ar,as,at,au)then av=true end;K.applied_attr_bonuses[w]=n(au)end;

if av and as.rebuild_derived_attrs then as.rebuild_derived_attrs(ar)end;

return av end;

function a.build_slot_text(az,w)local K=a.ensure_runtime(az)local X=J(K,w)local aK=d[w]or tostring(w)local aL=G(w,K.config)local aM=a.get_upgrade_cost(w,X.level,K.config)or 0;

return string.format('%s Lv.%d / %d  词缀 %d  下级花费 %d',aK,X.level,aL,#X.affixes,aM)end;

function a.build_tip_payload(az,w,m,R)local K=a.ensure_runtime(az,m)local X=J(K,w)local z=v(w,K.config)local Q=a_resolve_safe_item_key(X.item_key or z and z.item_key or nil);

if Q and X then X.item_key=Q end;

local aF=a.get_upgrade_cost(w,X.level,K.config)or 0;

local a2=Q and a_safe_item_name(R,Q)or nil;

local aN=Q and a_safe_item_icon(R,Q)or nil;

return{title_text=a2 or(d[w]or tostring(w)),subtitle_text=string.format('%s Lv.%d',d[w]or tostring(w),X.level),cost_text=aF>0 and string.format('升级所需：%d 金币',aF)or'升级所需：已满级',icon_res=aN,attr_lines=P(Q,R),affix_lines=W(X)}end;

function a.sync_items_to_hero(az,ar,m)if not az or not ar then return false end;

local K=a.ensure_runtime(az,m)local aO=false;

for U,w in ipairs(c)do local X=J(K,w)local z=v(w,K.config)local Q=X.item_key or z and z.item_key or nil;

Q=a_resolve_safe_item_key(Q);if Q and X then X.item_key=Q end;

if Q~=nil then if ar.get_bar_cnt and ar.set_bar_cnt then local aP=tonumber(ar:get_bar_cnt())or 0;

if aP<1 then ar:set_bar_cnt(1)end end;

local aQ=ar.has_item_by_key and ar:has_item_by_key(Q)or false;

if not aQ and ar.add_item then ar:add_item(Q,'物品栏')aO=true end end end;

return aO end;

return a





