local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local selector = require("Qing_Remaster_scripts.mimics.Familiar_Control_Selector")

local item = {ToCall={},entity=enums.Items.Brimstream,familiar=enums.Familiars.Brimstream,own_key="Item_Brimstream_"}
local OWNER,TRAIL="brimstream",item.own_key.."trail"
local PARTICLE_ANM2="gfx/global_particle.anm2"
local STREAM_SPEED=32
local TRAIL_STEP=20
local DEPART_MAX=10
local PREPARE_FRAMES=12
local WAIT_FRAMES=8
local ATTACK_FRAMES=4
local ANCHOR_RADIUS=90
local SPAWN_OUT=100
local CHARGE_POKE=10
local JET_BASE=28
local JET_BASE_BRIM=40
local JET_GROW=.62
local JET_CAP=120
local JET_CAP_BRIM=168
local FADER=item.own_key.."fade"

local function player_of(e) return auxi.check_spawner_player(e) or Game():GetPlayer(0) end
local function valid_enemies()
	local ret={}
	for _,e in ipairs(Isaac.GetRoomEntities()) do
		if auxi.isenemies(e) and e:IsActiveEnemy(false) and e:IsVulnerableEnemy() then ret[#ret+1]=e end
	end
	return ret
end
-- 画面四角 → 世界坐标（无 RGON 时退回房间框）
local function screen_bounds()
	if REPENTOGON and Isaac.RenderToWorld and Isaac.GetScreenWidth and Isaac.GetScreenHeight then
		local tl=Isaac.RenderToWorld(Vector(2,2))
		local br=Isaac.RenderToWorld(Vector(Isaac.GetScreenWidth()-2,Isaac.GetScreenHeight()-2))
		return Vector(math.min(tl.X,br.X),math.min(tl.Y,br.Y)),Vector(math.max(tl.X,br.X),math.max(tl.Y,br.Y))
	end
	return Game():GetRoom():GetTopLeftPos(),Game():GetRoom():GetBottomRightPos()
end
local function ray_exit(p,dir,tl,br)
	local best=math.huge
	if dir.X>0.001 then best=math.min(best,(br.X-p.X)/dir.X) elseif dir.X<-.001 then best=math.min(best,(tl.X-p.X)/dir.X) end
	if dir.Y>0.001 then best=math.min(best,(br.Y-p.Y)/dir.Y) elseif dir.Y<-.001 then best=math.min(best,(tl.Y-p.Y)/dir.Y) end
	if best==math.huge or best<=0 then return end
	return p+dir*best,best
end
-- 优先“附近敌人最多”的锚点，而不是全体质心（避免瞄空地）
local function pick_anchor(list,rng,tl,br)
	if not list or #list==0 then return (tl+br)*.5 end
	local best,best_score=list[1].Position,-1
	local tries=math.min(5,#list)
	for _=1,tries do
		local cand=list[rng:RandomInt(#list)+1]
		local score=0
		for _,e in ipairs(list) do
			if (e.Position-cand.Position):LengthSquared()<=ANCHOR_RADIUS*ANCHOR_RADIUS then score=score+1 end
		end
		if score>best_score then best,best_score=cand.Position,score end
	end
	return best
end
-- wall=画面边交点；spawn=场外远处；charge_point=边缘探头。不以房间边界改蓄力点。
local function make_route(wall,dir,finish,tl,br)
	return {
		wall=wall,
		spawn=wall-dir:Resized(SPAWN_OUT),
		charge_point=wall+dir:Resized(CHARGE_POKE),
		dir=dir,
		finish=finish,
		far=finish+dir:Resized(120),
		tl=tl,
		br=br,
	}
end
local function build_route(ent,list)
	local rng=ent:GetDropRNG()
	local tl,br=screen_bounds()
	local previous=ent:GetData()[item.own_key.."previous_route"]
	local target=pick_anchor(list,rng,tl,br)
	local minimum=math.min(br.X-tl.X,br.Y-tl.Y)*.48
	local function finish_route(wall,dir)
		local finish,len=ray_exit(wall+dir:Resized(2),dir,tl,br)
		if not finish or (len and len<minimum) then return end
		return make_route(wall,dir,finish,tl,br)
	end
	for _=1,16 do
		local side=rng:RandomInt(4) local wall
		if side==0 then wall=Vector(tl.X,tl.Y+(br.Y-tl.Y)*(.12+rng:RandomFloat()*.76))
		elseif side==1 then wall=Vector(br.X,tl.Y+(br.Y-tl.Y)*(.12+rng:RandomFloat()*.76))
		elseif side==2 then wall=Vector(tl.X+(br.X-tl.X)*(.12+rng:RandomFloat()*.76),tl.Y)
		else wall=Vector(tl.X+(br.X-tl.X)*(.12+rng:RandomFloat()*.76),br.Y) end
		local aim=target+Vector.FromAngle(rng:RandomFloat()*360):Resized(rng:RandomFloat()*28)
		local dir=(aim-wall):Rotated(rng:RandomFloat()*12-6):Normalized()
		local repeats=previous and math.abs(dir:Dot(previous.dir))>.94 and (wall-previous.wall):Length()<math.min(br.X-tl.X,br.Y-tl.Y)*.42
		local route=finish_route(wall,dir)
		if route and not repeats then return route end
	end
	local side=target.X<(tl.X+br.X)*.5 and tl.X or br.X local wall=Vector(side,(tl.Y+br.Y)*.5) local dir=(target-wall):Normalized()
	if previous and math.abs(dir:Dot(previous.dir))>.94 and (wall-previous.wall):Length()<math.min(br.X-tl.X,br.Y-tl.Y)*.42 then
		wall=Vector((tl.X+br.X)*.5,target.Y<(tl.Y+br.Y)*.5 and br.Y or tl.Y)
		dir=(target-wall):Normalized()
	end
	local route=finish_route(wall,dir)
	if route then return route end
	local finish=ray_exit(wall+dir*2,dir,tl,br) or target+dir*minimum
	return make_route(wall,dir,finish,tl,br)
end
local function remove_jet(ent)
	local d=ent:GetData() local laser=d[item.own_key.."jet"]
	if auxi.check_all_exists(laser) then laser:Remove() end d[item.own_key.."jet"]=nil
end
local function stop_laser_sound()
	local sfx=SFXManager()
	sfx:Stop(SoundEffect.SOUND_BLOOD_LASER)
	sfx:Stop(SoundEffect.SOUND_BLOOD_LASER_SMALL)
	sfx:Stop(SoundEffect.SOUND_BLOOD_LASER_LARGE)
	sfx:Stop(SoundEffect.SOUND_BLOOD_LASER_LARGER)
	sfx:Stop(SoundEffect.SOUND_BLOOD_LASER_LOOP)
end
-- RGON：SetInitSound(NULL)；否则 Spawn 当帧 + 延迟 1 帧 Stop。禁止每帧全局 Stop。
local function silence_spawned_laser(laser)
	if laser and laser.SetInitSound then
		pcall(function() laser:SetInitSound(SoundEffect.SOUND_NULL) end)
	end
	stop_laser_sound()
	delay_buffer.addeffe(stop_laser_sound,{},1)
end
-- mode: false=短装饰；"full"=随前进加长。压/准备阶段不调用（无尾迹）
local function ensure_jet(ent,player,dir,mode)
	local d=ent:GetData() local laser=d[item.own_key.."jet"]
	if not auxi.check_all_exists(laser) then
		local info=auxi.judge_by_brimstone(player)
		laser=Isaac.Spawn(EntityType.ENTITY_LASER,info.tp,0,ent.Position,Vector.Zero,ent):ToLaser()
		if not laser then return end
		laser.Parent=ent laser.Mass=0 laser.EntityCollisionClass=EntityCollisionClass.ENTCOLL_NONE laser:GetData().should_ignore_modifier=true
		d[item.own_key.."jet"]=laser
		silence_spawned_laser(laser)
	end
	laser.Position=ent.Position
	laser.Angle=dir:GetAngleDegrees()+180
	if mode=="full" then
		local brim=player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE)
		local grown=(brim and JET_BASE_BRIM or JET_BASE)+(d[item.own_key.."jet_dist"] or 0)*JET_GROW
		laser.MaxDistance=math.min(grown,brim and JET_CAP_BRIM or JET_CAP)
		laser.CollisionDamage=player.Damage*.38
	else
		laser.MaxDistance=28
		laser.CollisionDamage=0
	end
end
local function brim_color(alpha,glow)
	return Color(1.15,.22,.12,alpha or .9,glow or .42,.06,0)
end
local function apply_particle_sprite(e,anim,scale,color)
	local s=e:GetSprite()
	s:Load(PARTICLE_ANM2,true)
	s:Play(anim,true)
	s.Scale=Vector(scale,scale)
	s.Rotation=0
	s.Color=color
	e.Color=color
	e.EntityCollisionClass=EntityCollisionClass.ENTCOLL_NONE
	e.GridCollisionClass=EntityGridCollisionClass.GRIDCOLL_NONE
	return s
end
local function mark_fade(e,life,scale,alpha,glow)
	local d=e:GetData()
	d.skip_nil_distance_cull=true
	d[FADER]={life=life,scale0=scale,alpha0=alpha or .9,glow0=glow or .38}
end
-- 航迹：落在轨道上 → 向后+sin 侧向散开；大小不一；逐渐透明
local function spawn_trail_node(pos,dir,player,strong,phase,rng)
	rng=rng or player:GetCollectibleRNG(item.entity)
	local life=30+rng:RandomInt(22)
	local back=(-dir):Resized(1.5+(strong and .45 or 0)+rng:RandomFloat()*.4)
	local side=dir:Rotated(90):Resized(math.sin(phase)*(2.1+rng:RandomFloat()*.6))
	local e=auxi.fire_nil(pos,back+side,{cooldown=life,player=player})
	if not e then return end
	local sc=.32+rng:RandomFloat()*(strong and .62 or .48)
	local alpha=strong and .95 or .82
	local glow=.36
	apply_particle_sprite(e,strong and "RegularTear7" or "RegularTear5",sc,brim_color(alpha,glow))
	mark_fade(e,life,sc,alpha,glow)
	e:GetData()[TRAIL]={player=player,damage=player.Damage*(strong and .5 or .35),radius=8+sc*16}
end
-- 尾焰：只跟屁股，允许喷散；同样淡出
local function spawn_exhaust(ent,dir,player,strong)
	local rng=ent:GetDropRNG()
	local wave=math.sin(Game():GetFrameCount()*.55+ent.InitSeed*.01)*18
	local spray=(-dir):Rotated(wave+rng:RandomFloat()*16-8)
	local life=12+rng:RandomInt(10)
	local e=auxi.fire_nil(ent.Position-dir:Resized(10),spray:Resized(1.4+rng:RandomFloat()*2),{cooldown=life,player=player})
	if not e then return end
	local sc=.22+rng:RandomFloat()*(strong and .45 or .34)
	local alpha=.72
	apply_particle_sprite(e,"RegularTear3",sc,brim_color(alpha,.28))
	mark_fade(e,life,sc,alpha,.28)
end
local function emit_path_fx(ent,dir,player,strong,grow_jet)
	local d=ent:GetData()
	local moved=ent.Velocity:Length()
	if grow_jet then
		d[item.own_key.."jet_dist"]=(d[item.own_key.."jet_dist"] or 0)+moved
	end
	d[item.own_key.."trail_acc"]=(d[item.own_key.."trail_acc"] or 0)+moved
	while d[item.own_key.."trail_acc"]>=TRAIL_STEP do
		d[item.own_key.."trail_acc"]=d[item.own_key.."trail_acc"]-TRAIL_STEP
		d[item.own_key.."trail_phase"]=(d[item.own_key.."trail_phase"] or 0)+.85
		spawn_trail_node(ent.Position,dir,player,strong,d[item.own_key.."trail_phase"],ent:GetDropRNG())
	end
	d[item.own_key.."fx_cd"]=(d[item.own_key.."fx_cd"] or 0)-1
	if d[item.own_key.."fx_cd"]<=0 then
		spawn_exhaust(ent,dir,player,strong)
		d[item.own_key.."fx_cd"]=3
	end
end
local function burst_into_stream(ent)
	local d=ent:GetData()
	d[item.own_key.."jet_dist"]=0
	ent.SpriteScale=Vector(.82,1.22)
	ent.Visible=true
	if Game().ShakeScreen then Game():ShakeScreen(3) end
	if Game().MakeShockwave then Game():MakeShockwave(ent.Position,.028,.02,8) end
	SFXManager():Play(SoundEffect.SOUND_HELLBOSS_GROUNDPOUND,.55,0,false,1.35)
end
local function decay_stretch(ent)
	local sc=ent.SpriteScale
	ent.SpriteScale=Vector(1+(sc.X-1)*.72,1+(sc.Y-1)*.72)
	if math.abs(ent.SpriteScale.X-1)<.02 and math.abs(ent.SpriteScale.Y-1)<.02 then
		ent.SpriteScale=Vector.One
	end
end
-- 短促点火：边缘已憋足，进场立刻冲到 STREAM
local function attack_speed(t)
	if t<=1 then return 10 end
	if t==2 then return 18 end
	if t==3 then return 27 end
	return STREAM_SPEED
end
local function approach_speed(dist)
	if dist>40 then return 16 end
	if dist>20 then return 12 end
	return 7
end
local function reset(ent)
	remove_jet(ent)
	local d=ent:GetData()
	d[item.own_key.."state"]=nil
	d[item.own_key.."route"]=nil
	d[item.own_key.."previous_route"]=nil
	d[item.own_key.."depart_target"]=nil
	d[item.own_key.."trail_acc"]=0
	d[item.own_key.."trail_phase"]=0
	d[item.own_key.."jet_dist"]=0
	d[item.own_key.."hits"]={}
	d[item.own_key.."fx_cd"]=0
	ent.SpriteScale=Vector.One
	ent.Visible=true
end
-- 仅首次从玩家附近起飞：快速加速离场，不进入循环
local function begin_depart(ent,list)
	local d=ent:GetData()
	local r=build_route(ent,list)
	d[item.own_key.."route"]=r
	d[item.own_key.."previous_route"]={dir=Vector(r.dir.X,r.dir.Y),wall=Vector(r.wall.X,r.wall.Y)}
	d[item.own_key.."state"]="depart"
	d[item.own_key.."timer"]=0
	d[item.own_key.."trail_acc"]=0
	d[item.own_key.."trail_phase"]=0
	d[item.own_key.."jet_dist"]=0
	local tl,br=r.tl,r.br
	local center=(tl+br)*.5
	local out=(ent.Position-center)
	if out:Length()<1 then out=Vector(0,-1) end
	out=out:Normalized()
	local edge=ray_exit(ent.Position,out,tl,br) or ent.Position
	d[item.own_key.."depart_target"]=edge+out:Resized(140)
	ent.Visible=true
	ent.SpriteScale=Vector.One
end
-- wait 后：先清硫磺火，再瞬移到 spawn，飞向 charge_point
local function begin_approach(ent,list)
	remove_jet(ent)
	local d=ent:GetData()
	local nr=build_route(ent,list)
	d[item.own_key.."route"]=nr
	d[item.own_key.."previous_route"]={dir=Vector(nr.dir.X,nr.dir.Y),wall=Vector(nr.wall.X,nr.wall.Y)}
	ent.Position=nr.spawn
	ent.Velocity=Vector.Zero
	ent.SpriteScale=Vector.One
	ent.Visible=true
	d[item.own_key.."state"]="approach"
	d[item.own_key.."timer"]=0
	d[item.own_key.."trail_acc"]=0
	d[item.own_key.."trail_phase"]=0
	d[item.own_key.."jet_dist"]=0
	d[item.own_key.."fx_cd"]=0
end
-- approach 抵达后：边缘蓄力（不重建航线）
local function begin_prepare(ent)
	local d=ent:GetData()
	local r=d[item.own_key.."route"]
	if not r then return end
	remove_jet(ent)
	ent.Position=r.charge_point
	ent.Velocity=Vector.Zero
	ent.SpriteScale=Vector.One
	ent.Visible=true
	d[item.own_key.."state"]="prepare"
	d[item.own_key.."timer"]=0
	d[item.own_key.."fx_cd"]=0
end
local function begin_wait(ent)
	local d=ent:GetData()
	local r=d[item.own_key.."route"]
	remove_jet(ent)
	if r then ent.Position=r.far+r.dir:Resized(50) end
	ent.Velocity=Vector.Zero
	ent.Visible=false
	ent.SpriteScale=Vector.One
	d[item.own_key.."state"]="wait"
	d[item.own_key.."timer"]=0
end
-- 确认无下一轮攻击、飞回玩家身边：只拆掉身后硫磺火拖尾；粒子自然淡出
local function begin_return(ent)
	remove_jet(ent)
	local d=ent:GetData()
	d[item.own_key.."state"]="return"
	d[item.own_key.."timer"]=0
	ent.Visible=true
	ent.SpriteScale=Vector.One
end
local function idle_orbit(ent,p,d,s)
	remove_jet(ent)
	d[item.own_key.."state"]="idle"
	ent.SpriteScale=Vector.One
	ent.Visible=true
	local a=(ent.InitSeed%360)+Game():GetFrameCount()*1.5
	local wanted=p.Position+Vector.FromAngle(a):Resized(72)
	ent.Velocity=ent.Velocity*.72+(wanted-ent.Position)*.12
	s.Rotation=ent.Velocity:GetAngleDegrees()+90
end

selector.register(OWNER,20,function(f) return f and f.Type==EntityType.ENTITY_FAMILIAR and f.Variant==item.familiar end,{on_gain=reset,on_lost=function(f) reset(f) f.Velocity=Vector.Zero end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_EVALUATE_CACHE,Function=function(_,p,flag) if flag==CacheFlag.CACHE_FAMILIARS then p:CheckFamiliar(item.familiar,p:GetCollectibleNum(item.entity),p:GetCollectibleRNG(item.entity),Isaac.GetItemConfig():GetCollectible(item.entity)) end end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_FAMILIAR_INIT,params=item.familiar,Function=function(_,e) e:GetSprite():Play("Appear",true) reset(e) end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_POST_NEW_ROOM,Function=function() for _,e in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR,item.familiar)) do reset(e) end end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_FAMILIAR_UPDATE,params=item.familiar,Function=function(_,ent)
	if not selector.is_owner(ent,OWNER) then return end
	local p,d,s=player_of(ent),ent:GetData(),ent:GetSprite()
	ent.SpriteRotation=0
	if s:IsFinished("Appear") then s:Play("Idle",true) end
	local list=valid_enemies()
	local state=d[item.own_key.."state"]
	local strong=p:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE)

	-- 仅 idle：无敌人环绕；有敌人首次起飞。航线中途不因清怪立刻结束。
	if not state or state=="idle" then
		if #list==0 then idle_orbit(ent,p,d,s) return end
		begin_depart(ent,list)
		state="depart"
	elseif state=="return" then
		if #list>0 then
			begin_depart(ent,list)
			state="depart"
		else
			local to=p.Position-ent.Position
			ent.SpriteScale=Vector.One
			ent.Visible=true
			remove_jet(ent)
			if to:Length()<=72 then
				idle_orbit(ent,p,d,s)
				return
			end
			ent.Velocity=ent.Velocity*.55+to:Normalized():Resized(9)
			s.Rotation=ent.Velocity:GetAngleDegrees()+90
			return
		end
	end

	local r=d[item.own_key.."route"]
	if not r then begin_depart(ent,list) r=d[item.own_key.."route"] state="depart" end
	d[item.own_key.."timer"]=(d[item.own_key.."timer"] or 0)+1
	local dir=r.dir
	local t=d[item.own_key.."timer"]

	if state=="depart" then
		-- 8～10 帧明显加速离场；出屏后 wait → approach
		local target=d[item.own_key.."depart_target"] or (ent.Position+Vector(0,-140))
		local to=target-ent.Position
		local speed=10+22*math.min(1,t/DEPART_MAX)^1.4
		ent.Velocity=to:Length()>1 and to:Normalized():Resized(speed) or Vector.Zero
		ent.SpriteScale=Vector.One
		s.Rotation=ent.Velocity:Length()>.1 and (ent.Velocity:GetAngleDegrees()+90) or (dir:GetAngleDegrees()+90)
		if to:Length()<=28 or t>=DEPART_MAX then
			begin_wait(ent)
		end
	elseif state=="wait" then
		ent.Velocity=Vector.Zero
		ent.Visible=false
		if t>=WAIT_FRAMES then
			if #list==0 then
				begin_return(ent)
			else
				begin_approach(ent,list)
			end
		end
	elseif state=="approach" then
		-- 场外飞向画面边缘：减速贴近，仅短尾焰，无攻击航迹
		local charge=r.charge_point
		local to=charge-ent.Position
		local dist=to:Length()
		ent.Visible=true
		s.Rotation=dir:GetAngleDegrees()+90
		if dist<=8 or t>=90 then
			begin_prepare(ent)
		else
			ent.Velocity=to:Normalized():Resized(approach_speed(dist))
			d[item.own_key.."fx_cd"]=(d[item.own_key.."fx_cd"] or 0)-1
			if d[item.own_key.."fx_cd"]<=0 then
				spawn_exhaust(ent,dir,p,false)
				d[item.own_key.."fx_cd"]=4
			end
		end
	elseif state=="prepare" then
		-- 边缘蓄力：稳定 → 缓慢后缩 → 临界；无正式航迹/硫磺火
		local charge=r.charge_point
		local recoil=0
		local exhaust_cd=5
		ent.Visible=true
		s.Rotation=dir:GetAngleDegrees()+90
		if t<=4 then
			recoil=0
			ent.SpriteScale=Vector.One
			exhaust_cd=5
		elseif t<=9 then
			local u=(t-4)/5
			recoil=4*u
			ent.SpriteScale=Vector(1+.02*u,1-.04*u)
			exhaust_cd=3
		else
			recoil=4.5
			ent.SpriteScale=Vector(1.06,.9)
			exhaust_cd=2
			if t==10 then
				SFXManager():Play(SoundEffect.SOUND_BEAST_GHOST_DASH,.4,0,false,.7)
			end
		end
		local jitter=t>=5 and dir:Rotated(90):Resized(math.sin(t*2.3)*.55) or Vector.Zero
		ent.Position=charge-dir:Resized(recoil)+jitter
		ent.Velocity=Vector.Zero
		d[item.own_key.."fx_cd"]=(d[item.own_key.."fx_cd"] or 0)-1
		if d[item.own_key.."fx_cd"]<=0 then
			spawn_exhaust(ent,dir,p,t>=5)
			if t>=10 then spawn_exhaust(ent,dir,p,true) end
			d[item.own_key.."fx_cd"]=exhaust_cd
		end
		if t>=PREPARE_FRAMES then
			-- 点火瞬间：边缘爆发，再短促冲到 STREAM
			burst_into_stream(ent)
			d[item.own_key.."state"]="attack"
			d[item.own_key.."timer"]=0
			d[item.own_key.."trail_acc"]=0
			d[item.own_key.."trail_phase"]=0
			d[item.own_key.."jet_dist"]=0
			ent.Position=charge
			ent.Velocity=dir:Resized(attack_speed(1))
		end
	elseif state=="attack" or state=="stream" then
		local speed=STREAM_SPEED
		if state=="attack" then
			speed=attack_speed(t)
			ent.Velocity=dir:Resized(speed)
			ent.Visible=true
			s.Rotation=dir:GetAngleDegrees()+90
			emit_path_fx(ent,dir,p,strong,true)
			if t>=ATTACK_FRAMES then
				d[item.own_key.."state"]="stream"
				d[item.own_key.."timer"]=0
			end
		else
			decay_stretch(ent)
			ent.Velocity=dir:Resized(speed)
			ent.Visible=true
			s.Rotation=dir:GetAngleDegrees()+90
			emit_path_fx(ent,dir,p,strong,true)
			if (ent.Position-r.finish):Dot(dir)>=0 then
				d[item.own_key.."state"]="exit"
				d[item.own_key.."timer"]=0
			end
		end
	elseif state=="exit" then
		-- 不减速：极速穿出画面
		ent.Velocity=dir:Resized(STREAM_SPEED)
		s.Rotation=dir:GetAngleDegrees()+90
		decay_stretch(ent)
		emit_path_fx(ent,dir,p,strong,true)
		if (ent.Position-r.far):Dot(dir)>=0 or t>=20 then
			if #list==0 then
				begin_return(ent)
			else
				begin_wait(ent)
			end
		end
	end

	local now=d[item.own_key.."state"]
	local route=d[item.own_key.."route"]
	-- approach：短发动机焰；stream/exit/attack：正式硫磺尾迹；回程无拖尾（粒子自消）
	if now=="stream" or now=="exit" or now=="attack" then
		ensure_jet(ent,p,route and route.dir or Vector(0,-1),"full")
	elseif now=="approach" then
		ensure_jet(ent,p,route and route.dir or Vector(0,-1),false)
	else
		remove_jet(ent)
	end
end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_PRE_FAMILIAR_COLLISION,params=item.familiar,Function=function(_,ent,col)
	if not selector.is_owner(ent,OWNER) or not auxi.isenemies(col) then return end
	local d=ent:GetData() local st=d[item.own_key.."state"]
	if st~="attack" and st~="stream" and st~="exit" then return end
	local hits=d[item.own_key.."hits"] or {} d[item.own_key.."hits"]=hits
	local key,frame=GetPtrHash(col),Game():GetFrameCount()
	if (hits[key] or -99)+10<=frame then
		hits[key]=frame
		col:TakeDamage(player_of(ent).Damage*1.5,DamageFlag.DAMAGE_LASER,EntityRef(ent),0)
		col.Velocity=col.Velocity+d[item.own_key.."route"].dir:Resized(1.5)
		col:SetColor(Color(1.3,.75,.75,1,.15,0,0),3,8,true,false)
		if Game().ShakeScreen then Game():ShakeScreen(2) end
	end
end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_POST_EFFECT_UPDATE,params=enums.Entities.ID_EFFECT_MeusNIL,Function=function(_,e)
	local d=e:GetData()
	local fade=d[FADER]
	if fade then
		local rem=math.max(0,d.removecd or 0)
		local u=fade.life>0 and (rem/fade.life) or 0
		local a=fade.alpha0*u
		local sc=fade.scale0*(.55+.45*u)
		local c=brim_color(a,fade.glow0*u)
		local s=e:GetSprite()
		s.Color=c
		s.Scale=Vector(sc,sc)
		e.Color=c
	end
	local x=d[TRAIL]
	if not x or not x.player or not x.player:Exists() or e.FrameCount%8~=0 then return end
	for _,enemy in ipairs(Isaac.FindInRadius(e.Position,x.radius,EntityPartition.ENEMY)) do
		if auxi.isenemies(enemy) and enemy:IsVulnerableEnemy() then
			enemy:TakeDamage(x.damage,DamageFlag.DAMAGE_LASER,EntityRef(x.player),0)
		end
	end
end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_FAMILIAR_UPDATE,params=FamiliarVariant.ABYSS_LOCUST,Function=function(_,ent)
	if ent.SubType~=item.entity or ent.State~=-1 or ent.Velocity:Length()<6 then return end
	local d=ent:GetData()
	local dir=ent.Velocity:Normalized()
	local p=player_of(ent)
	d[item.own_key.."locust_cd"]=(d[item.own_key.."locust_cd"] or 0)-1
	d[item.own_key.."trail_acc"]=(d[item.own_key.."trail_acc"] or 0)+ent.Velocity:Length()
	while d[item.own_key.."trail_acc"]>=TRAIL_STEP do
		d[item.own_key.."trail_acc"]=d[item.own_key.."trail_acc"]-TRAIL_STEP
		d[item.own_key.."trail_phase"]=(d[item.own_key.."trail_phase"] or 0)+.85
		spawn_trail_node(ent.Position,dir,p,false,d[item.own_key.."trail_phase"],ent:GetDropRNG())
	end
	if d[item.own_key.."locust_cd"]<=0 then
		spawn_exhaust(ent,dir,p,false)
		d[item.own_key.."locust_cd"]=3
	end
end})
return item
