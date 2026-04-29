local a={}
local b=5;
local c=60;
local d={hp='生命',
hp_regen='生命恢复',
armor='护甲',
block='格挡',
attack='攻击',
attack_range='攻击范围',
attack_speed_pct='攻击速度',
strength='力量',
agility='敏捷',
intelligence='智力',
all_attributes='全属性',
strength_growth_pct='力量增幅',
agility_growth_pct='敏捷增幅',
intelligence_growth_pct='智力增幅',
attack_growth_pct='攻击增幅',
physical_damage_pct='物理伤害',
magic_damage_pct='魔法伤害',
basic_attack_damage_pct='普攻伤害',
skill_damage_pct='技能伤害',
all_damage_pct='所有伤害',
physical_crit_pct='物理暴击',
physical_crit_damage_pct='物理暴伤',
magic_crit_pct='魔法暴击',
magic_crit_damage_pct='魔法暴伤',
}
local e={gold_per_sec='每秒金币',
wood_per_sec='每秒木材',
exp_per_sec='每秒经验',
kill_count='杀敌数',
kill_per_sec='每秒杀敌',
strength_per_sec='每秒力量',
agility_per_sec='每秒敏捷',
intelligence_per_sec='每秒智力',
kill_gold_pct='杀敌金币',
kill_exp_pct='杀敌经验',
kill_wood_pct='杀敌木材',
kill_material_pct='杀敌木材',
basic_attack_damage_pct='普攻伤害',
skill_damage_pct='技能伤害',
all_damage_pct='所有伤害',
elite_damage_pct='精控伤害',
boss_damage_pct='挑战伤害',
challenge_damage_pct='挑战伤害'}
local f={gold='金币',
wood='木材',
exp='经验'}
local g={[0]='零',[1]='一',[2]='二',[3]='三',[4]='四',[5]='五',[6]='六',[7]='七',[8]='八',[9]='九'}
local function h(i)
local j=math.max(0,math.floor(tonumber(i)or 0))
if j<=10 then
if j==10 then return'十'end;

return g[j]or tostring(j)end;

if j<20 then return'十'..(g[j%10]or'')end;

if j<100 then local k=math.floor(j/10)
local l=j%10;
local m=(g[k]or tostring(k))..'十'if l>0 then m=m..(g[l]or tostring(l))end;

return m end;

return tostring(j)end;

local function n(o)
if not o then return nil end;

local p=tonumber(o.chapter_id)
local q=tonumber(o.order_index)
if p and q and p>0 and q>0 then return(p-1)*10+q end;

local r,
s=tostring(o.id or''):match('^(%d+)%-(%d+)$')
if r and s then return(tonumber(r)-1)*10+tonumber(s)end;

return nil end;

local function t(o)
local u=n(o)
if not u or u<=0 then return nil end;

return string.format('第%s层',h(u))end;

local function v(o)return t(o)or o and o.title_text or o and o.id end;

local function w(x)
local y={}for z,i in ipairs(x or{})
do y[z]=i end;

return y end;

function a.create(A)
local B=A.STATE;
local C=A.CONFIG;
local D=A.round_number;
local E=A.message;
local F=A.add_hero_attr_pack;
local G=A.award_rewards;
local H=A.queue_treasure_round;
local I=A.start_mainline_task_challenge;
local J={}
local function K()return C.mainline_task_rewards and C.mainline_task_rewards.by_id or{}end;

local function L()return C.mainline_task_rewards and C.mainline_task_rewards.list or{}end;

local function M(N)
if not N then return nil end;

for z,o in ipairs(L())do
if o and o.id==N then return z end end;

return nil end;

local function O()return L()[1]end;

local function P(N)
local Q=M(N)
if not Q then return nil end;

return L()[Q+1]end;

local function R()
if type(C.waves)=='table'and#C.waves>0 then return#C.waves end;

return b end;

local function S()B.mainline_task_runtime=B.mainline_task_runtime or{active_task_id=nil,
state='idle',
chain_exhausted=false,
completed_task_ids={},
rewarded_task_ids={},
hero_card_count=0,
progress_by_task_id={},
auto_track_enabled=true,
pinned_task_id=nil,
snapshot_summary=nil,
last_result='none',
last_result_reason=nil,
active_challenge=nil}
local T=B.mainline_task_runtime;
T.state=T.state or'idle'
T.completed_task_ids=T.completed_task_ids or{}
T.rewarded_task_ids=T.rewarded_task_ids or{}
T.progress_by_task_id=T.progress_by_task_id or{}
T.auto_track_enabled=T.auto_track_enabled~=false;
T.last_result=T.last_result or'none'
T.last_result_reason=T.last_result_reason;
T.active_challenge=T.active_challenge;
return T end;

local function U(T)
if T.active_task_id~=nil or T.chain_exhausted==true then return end;

local V=O()
if V then T.active_task_id=V.id;T.state=T.state or'idle'return end;
T.chain_exhausted=true;T.state='exhausted'end;

local function W()
if B.session_phase~=nil then return B.session_phase=='battle'end;

return B.current_mode_def~=nil end;

local function X(o)
if not o then return nil end;

local q=tonumber(o.order_index)
if not q or q<=0 then local Y,
s=tostring(o.id or''):match('^(%d+)%-(%d+)$')
q=tonumber(s)end;

if not q or q<=0 then return nil end;

local Z=math.max(1,tonumber(R())or b)
return(q-1)%Z+1 end;

local function _(a0)
local i=a0;
if D and math.abs(a0%1)<=0.0001 then i=D(a0)end;

return i end;

local function a1(a0,a2)
local i=_(a0)
local a3=tostring(i)
if a0>=0 then a3='+'..a3 end;

if a2 then a3=a3 ..'%'end;

return a3 end;

local function a4(a5)
if not a5 then return nil end;

local a0=tonumber(a5.value)or 0;
if a5.type=='resource'then local a6=f[a5.key]or tostring(a5.key or'?')return string.format('%s %s',a6,a1(a0,false))end;

if a5.type=='special'then local i=_(a0)
if a5.key=='treasure_choice'then return string.format('获得 %s 次宝物',tostring(i))end;

if a5.key=='hero_card'then return string.format('英雄卡 %s',a1(a0,false))end end;

local a6=d[a5.key]or e[a5.key]or tostring(a5.key or'?')return string.format('%s %s',a6,a1(a0,tostring(a5.key or''):match('_pct$')~=nil))end;

local function a7(o)
local a8={}for Y,a5 in ipairs(o and o.reward_lines or{})
do a8[#a8+1]=a4(a5)end;

return a8 end;

local function a9(T)T.active_challenge=nil end;

local function aa(o)
local i=tonumber(o and o.time_limit)
if i and i>0 then return i end;

return c end;

function J.get_current_task_id()
if not W()then return nil end;

local T=S()
U(T)
if T.chain_exhausted then return nil end;

return T.active_task_id end;

function J.get_current_task()
local N=J.get_current_task_id()
if not N then return nil end;

return K()[N]end;

function J.get_current_progress_count(N)
local T=S()
local ab=T.progress_by_task_id or{}return tonumber(ab[N or J.get_current_task_id()]or 0)or 0 end;

function J.is_task_completed(N)
local T=S()return T.completed_task_ids[N]==true end;

function J.is_task_rewarded(N)
local T=S()return T.rewarded_task_ids[N]==true end;

function J.sync_current_task()
if not W()then return nil end;

local T=S()
U(T)return J.get_current_task()end;

function J.handle_wave_started()return J.sync_current_task()end;

local function ac(a5,ad)
local ae=d[a5.key]if not ae then return false end;
ad[ae]=(ad[ae]or 0)+(tonumber(a5.value)or 0)return true end;

local function af(a5,ad)
local ae=e[a5.key]if not ae then return false end;
ad[ae]=(ad[ae]or 0)+(tonumber(a5.value)or 0)return true end;

function J.apply_task_rewards(o)
o=o or J.get_current_task()
if not o then return false end;

local ad={}
local ag={gold=0,
wood=0,
exp=0}
local T=S()
if o.id and T.rewarded_task_ids[o.id]then return false end;

for Y,a5 in ipairs(o.reward_lines or{})
do
if a5.type=='attr'then ac(a5,ad)
elseif a5.type=='runtime'then af(a5,ad)
elseif a5.type=='resource'then ag[a5.key]=(ag[a5.key]or 0)+(tonumber(a5.value)or 0)
elseif a5.type=='special'then
if a5.key=='treasure_choice'and H then
for Y=1,tonumber(a5.value)or 0 do H('mainline_task',v(o))end
elseif a5.key=='hero_card'then
T.hero_card_count=(T.hero_card_count or 0)+(tonumber(a5.value)or 0)
if E then E(string.format('%s：英雄卡 %+d。',v(o),tonumber(a5.value)or 0))end end end end;

if next(ad)and F and B.hero then F(B.hero,ad)end;
if(ag.gold or 0)~=0 or(ag.wood or 0)~=0 or(ag.exp or 0)~=0 then G(ag,v(o),false)end;

if o.id then T.completed_task_ids[o.id]=true;T.rewarded_task_ids[o.id]=true end;

if E then E(string.format('%s 奖励已发放。',v(o)))end;

return true end;

function J.can_start_current_task()
local T=S()
U(T)
if T.chain_exhausted or T.state=='exhausted'then return false end;

if T.state=='running'then return false end;

return J.get_current_task()~=nil end;

function J.start_current_task_challenge()
local T=S()
U(T)
if T.chain_exhausted or T.state=='exhausted'then return false,'all_tasks_completed'end;

if T.state=='running'then return false,'task_already_running'end;

local o=J.get_current_task()
if not o then return false,'task_not_found'end;

local ah=I and I(o)or nil;
if not ah then return false,'challenge_start_failed'end;
T.progress_by_task_id[o.id]=0;T.active_challenge={task_id=o.id,
instance_id=ah.id,
elapsed=0,
time_limit=aa(o),
target_count=tonumber(o.target_count)or 0,
kill_count=0,
alive_count=tonumber(o.target_count)or 0}T.state='running'T.last_result='none'T.last_result_reason=nil;
return true end;

function J.fail_current_task(ai)
local T=S()
if T.state~='running'then return false,'task_not_running'end;

local o=J.get_current_task()
if o and o.id then T.progress_by_task_id[o.id]=0 end;
a9(T)T.state='idle'T.last_result='failed'T.last_result_reason=ai or'unknown'return true end;

function J.complete_current_task()
local T=S()
if T.state~='running'then return false,'task_not_running'end;

local o=J.get_current_task()
local aj=T.active_challenge;
if not o or not aj then return false,'missing_active_task'end;

if aj.alive_count>0 then return false,'task_not_cleared'end;
T.state='completed'T.completed_task_ids[o.id]=true;
if E then E(string.format('%s 已完成。',v(o)))end;
J.apply_task_rewards(o)
a9(T)
local ak=P(o.id)
if ak then T.active_task_id=ak.id;T.state='idle'T.last_result='success'T.last_result_reason=nil else T.active_task_id=nil;T.chain_exhausted=true;T.state='exhausted'T.last_result='success'T.last_result_reason=nil end;

return true end;

function J.handle_enemy_killed(al)
local T=S()
if T.state~='running'then return false end;

local o=J.get_current_task()
local aj=T.active_challenge;
if not o or not aj then return false end;

if aj.task_id~=o.id then return false end;

if type(al)~='table'or al.kind~='challenge'then return false end;

local am=al.owner;
if not am or tostring(am.id)~=tostring(aj.instance_id)then return false end;

local an=tonumber(o.target_count or aj.target_count or 0)or 0;aj.kill_count=math.min(an,(aj.kill_count or 0)+1)aj.alive_count=math.max(0,an-aj.kill_count)T.progress_by_task_id[o.id]=aj.kill_count;
return true end;

function J.update(ao)
local T=S()
if T.state~='running'then return false end;

local aj=T.active_challenge;
if not aj then return false end;
aj.elapsed=math.max(0,tonumber(aj.elapsed)or 0)+(tonumber(ao)or 0)return false end;

function J.handle_challenge_finished(ah,ap)
local T=S()
local aj=T.active_challenge;
if not aj or not ah then return false end;

if tostring(aj.instance_id)~=tostring(ah.id)then return false end;

if ap==true then aj.alive_count=0;aj.kill_count=aj.target_count or aj.kill_count or 0;T.progress_by_task_id[aj.task_id]=aj.kill_count;
return J.complete_current_task()end;

return J.fail_current_task('timeout')end;

function J.handle_wave_cleared()return false end;

function J.handle_task_cleared()return false end;

function J.get_current_task_summary()
local T=S()
U(T)
local o=J.get_current_task()
if not o then
if T.chain_exhausted or T.state=='exhausted'then return{id=nil,
title_text='爬塔挑战',
objective_text='已完成全部层数挑战',
current_count=0,
target_count=0,
progress_text='爬塔挑战全部完成',
timer_text='',
reward_lines={},
reward_line_texts={},
state='exhausted',
state_text='全部完成',
can_start=false,
is_running=false,
is_completed=true,
is_failed=false}end;

return nil end;

local aj=T.active_challenge;
local aq=J.get_current_progress_count(o.id)
local an=tonumber(o.target_count)or 0;
local ar=aa(o)
local as=T.state or'idle'
local at;
local au;
local av;
if as=='running'and aj then aq=tonumber(aj.kill_count or aq)or 0;
local aw=math.max(0,math.ceil((aj.time_limit or ar)-(aj.elapsed or 0)))
at=string.format('%s(%d/%d)',o.objective_text or'任务',aq,an)
au=string.format('剩余 %d 秒',aw)
av='挑战中'elseif as=='exhausted'or T.chain_exhausted==true then at='爬塔挑战全部完成'
au=''
av='全部完成'
as='exhausted'elseif T.last_result=='failed'then at='本层挑战失败，可再次开启'
au='请重新开始当前层挑战'
av='可挑战'
aq=0 else at='按 C 开启当前层挑战'
au=string.format('限时 %d 秒',ar)
av='可挑战'
aq=0 end;

return{id=o.id,
chapter_text=t(o)or'第'..tostring(o.id)..'层',
title_text=o.title_text or t(o),
objective_text=o.objective_text,
current_count=aq,
target_count=an,
progress_text=at,
timer_text=au,
reward_lines=w(o.reward_lines),
reward_line_texts=a7(o),
state=as,
state_text=av,
can_start=J.can_start_current_task(),
is_running=as=='running',
is_completed=T.completed_task_ids[o.id]==true,
is_failed=T.last_result=='failed',
remaining_seconds=aj and math.max(0,math.ceil((aj.time_limit or ar)-(aj.elapsed or 0)))or ar}end;

function J.get_tracker_state()
local T=S()
local ax=J.get_current_task_summary()
local ay=ax;
if T.auto_track_enabled==false and T.snapshot_summary then ay=T.snapshot_summary end;

return{auto_track_enabled=T.auto_track_enabled~=false,
pinned_task_id=T.pinned_task_id,
snapshot_summary=T.snapshot_summary,
state=ay and ay.state or T.state,
can_start=ay and ay.can_start or false,
last_result=T.last_result,
last_result_reason=T.last_result_reason}end;

function J.toggle_auto_track()
local T=S()T.auto_track_enabled=not(T.auto_track_enabled~=false)
if T.auto_track_enabled then T.pinned_task_id=nil;T.snapshot_summary=nil else local ax=J.get_current_task_summary()T.pinned_task_id=ax and ax.id or nil;T.snapshot_summary=ax end;

return J.get_tracker_state()end;

return J end;

return a




