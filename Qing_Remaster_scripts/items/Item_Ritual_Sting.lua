local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local item_color_holder = require("Qing_Remaster_scripts.others.Item_color_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")

local item = {
	ToCall = {}, pre_ToCall = {}, myToCall = {}, post_ToCall = {},
	entity = enums.Items.Ritual_Sting,
	own_key = "Item_Ritual_Sting_",
	data_version = 2, threshold = 100, cap = 200, dir_time_limit = 20,
	colors = {
		{R=1,G=.12,B=.12},{R=1,G=.52,B=.05},{R=1,G=.95,B=.08},
		{R=.15,G=.9,B=.2},{R=.15,G=.45,B=1},{R=.65,G=.18,B=.85},
	},
	color_names = {zh={"红","橙","黄","绿","蓝","紫"},en={"Red","Orange","Yellow","Green","Blue","Purple"}},
	effect_names = {
		zh={"+3攻击","额外清房奖励","颜色获取×1.5","飞行、+0.15移速","+1.5射速、水迹","25%免伤、更多精英"},
		en={"+3 Damage","Extra clear reward","Color gain x1.5","Flight, +0.15 Speed","+1.5 Tears, creep","25% block, more champions"},
	},
	-- Brighter built-in EID colors keep all six status lines readable on its dark panel.
	eid_color_tags = {"ColorRed","ColorOrange","ColorYellow","ColorLime","ColorPastelBlue","ColorLavender"},
}

local QUALITY_GAIN = {[0]=35,[1]=50,[2]=70,[3]=100,[4]=140}
local COLOR_WEIGHTS = {
	red={1,.5,0,0,0,.5}, orange={.5,1,.5,0,0,0}, yellow={0,.5,1,.5,0,0},
	green={0,0,.5,1,.5,0}, blue={0,0,0,.5,1,.5}, purple={.5,0,0,0,.5,1},
	pink={.5,0,0,0,0,.5}, brown={.35,.65,0,0,0,0}, black={.2,0,0,0,.3,.5},
	white={.5,.5,.5,.5,.5,.5}, grey={.25,.25,.25,.25,.25,.25},
	others={.25,.25,.25,.25,.25,.25},
}
local ffont = Font()
ffont:Load("font/luaminioutlined.fnt")

local function lang() return Options.Language == "zh" and "zh" or "en" end
local function true_num(player,id)
	local ok,n = pcall(function() return player:GetCollectibleNum(id,true,true) end)
	if ok and type(n) == "number" then return n end
	return player:GetCollectibleNum(id,true)
end
local function store()
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	return save.elses[item.own_key.."effect"]
end
function item.get_values(player)
	local idx = player:GetData().__Index
	local values = store()[idx]
	-- Old values used 0..30 and five thresholds. They are intentionally not migrated.
	if type(values) ~= "table" or values._version ~= item.data_version then
		values = {_version=item.data_version,0,0,0,0,0,0}
		store()[idx] = values
	end
	for i=1,6 do values[i]=math.max(0,math.min(item.cap,tonumber(values[i]) or 0)) end
	return values
end
local function active(values,id) return (values[id] or 0) >= item.threshold end
local function signature(values)
	local t={}
	for i=1,6 do t[i]=active(values,i) and "1" or "0" end
	return table.concat(t,":")
end
function item.refresh_effects(player,force)
	local d=player:GetData()
	local sig=signature(item.get_values(player))
	if force or d[item.own_key.."effect_signature"]~=sig then
		d[item.own_key.."effect_signature"]=sig
		player:AddCacheFlags(CacheFlag.CACHE_DAMAGE|CacheFlag.CACHE_SPEED|CacheFlag.CACHE_FIREDELAY|CacheFlag.CACHE_FLYING)
		player:EvaluateItems()
	end
end

local function map_weights(labels)
	local result={0,0,0,0,0,0}
	for label,amount in pairs(labels or {}) do
		local source=COLOR_WEIGHTS[label]
		if source then for i=1,6 do result[i]=math.min(1,result[i]+source[i]*amount) end end
	end
	return result
end
function item.get_color_counts(id)
	return map_weights(item_color_holder.get_label_weights(id,true) or {})
end
local function raw_gain(player,id,color)
	local cfg=Isaac.GetItemConfig():GetCollectible(id)
	if not cfg then return 0 end
	local gain=(QUALITY_GAIN[cfg.Quality] or 35)*(item.get_color_counts(id)[color] or 0)
	if active(item.get_values(player),3) then gain=gain*1.5 end
	return gain
end
local function preview_gain(player,id,color)
	local current=item.get_values(player)[color]
	return math.max(0,math.min(item.cap,current+raw_gain(player,id,color))-current)
end
local function can_sacrifice(player,id)
	if not id or id<=0 or id==item.entity then return false end
	local cfg=Isaac.GetItemConfig():GetCollectible(id)
	return cfg~=nil and not cfg.Hidden and not cfg:HasTags(ItemConfig.TAG_QUEST) and true_num(player,id)>0
end
function item.makeitemlist(player)
	local cfg=Isaac.GetItemConfig()
	local list={}
	for id=1,cfg:GetCollectibles().Size do
		if can_sacrifice(player,id) then
			local shown=cfg:GetCollectible(id)
			if id==enums.Items.It_s_a_trick then shown=cfg:GetCollectible(save.elses.glazed_trick or 32) or shown end
			list[#list+1]={id=id,spritename=shown.GfxFileName}
		end
	end
	return list
end

local function close_menu(player)
	if player:IsHoldingItem() then player:AnimateCollectible(item.entity,"HideItem","PlayerPickup") end
	selection_holder.remove_select(player,item.own_key)
	player:GetData()[item.own_key.."menu"]=nil
end
local function feedback(player,color_id)
	local color=auxi.UpColor(auxi.table2color(item.colors[color_id]))
	for subtype=1,2 do
		local e=Isaac.Spawn(EntityType.ENTITY_EFFECT,16,subtype,player.Position,Vector(0,0),player):ToEffect()
		if e then e:GetSprite().Color=color end
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2)
end
local function commit(player,entry,color_id,slot)
	if not entry or not can_sacrifice(player,entry.id) then return false end
	local before=true_num(player,entry.id)
	local gain=raw_gain(player,entry.id,color_id)
	player:RemoveCollectible(entry.id,true)
	if true_num(player,entry.id)>=before then return false end
	local values=item.get_values(player)
	values[color_id]=math.min(item.cap,values[color_id]+gain)
	item.refresh_effects(player,true)
	player:AnimateCollectible(entry.id,"UseItem","PlayerPickup")
	feedback(player,color_id)
	local ritual_slot=auxi.check_slot_with_item(player,item.entity)
	if not ritual_slot or ritual_slot<0 then ritual_slot=slot or ActiveSlot.SLOT_PRIMARY end
	player:SetActiveCharge(0,ritual_slot)
	close_menu(player)
	return true
end

local function columns(player,count)
	local n=math.max(3,math.ceil(math.sqrt(math.max(1,count))))
	local top=Isaac.WorldToScreen(player.Position)+Vector(0,-97.5)
	return math.max(math.ceil(math.max(1,count)/math.max(1,math.ceil(top.Y/20))),n)
end
local function draw(pos,text,color,center)
	gui.draw_ch(pos,text,1,1,color,center==true,ffont)
end
local function progress_sprites()
	if item.progress_sprites then return item.progress_sprites end
	local base=Sprite(); base:Load("gfx/mimics/Ritual_Sting/Colorinfo.anm2",true); base:Play("Idle",true)
	local bar=Sprite(); bar:Load("gfx/mimics/Ritual_Sting/Colorinfo.anm2",true)
	item.progress_sprites={base=base,bar=bar}
	return item.progress_sprites
end
local function selector_icon(gfx)
	local sprite=Sprite()
	sprite:Load("gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2",true)
	sprite:Play("Idle",true); sprite:ReplaceSpritesheet(0,gfx); sprite:LoadGraphics()
	return sprite
end
local function render_grid(player,menu,origin)
	local list=menu.list or {}
	if #list==0 then draw(origin,lang()=="zh" and "没有可献祭道具" or "No eligible collectible",KColor(1,1,1,1),true) return end
	local cols=columns(player,#list)
	local rows=math.ceil(#list/cols)
	local start=origin-Vector(15*(cols-1)/2,15*(rows-1)/2)
	for ii,info in ipairs(list) do
		local sprite=auxi.load_item(info.id,{Anm="gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2"})
		if sprite then
			sprite.Scale=Vector(.5,.5)
			local index=ii-1
			local pos=start+Vector(15*(index%cols),15*math.floor(index/cols))
			sprite:Render(pos,Vector(0,0),Vector(0,0))
			if index==(menu.sel or 0) then
				local mark=Sprite()
				mark:Load("gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2",true)
				mark:Play("Idle",true)
				mark:ReplaceSpritesheet(0,"gfx/ui/math/catch_mark.png")
				mark:LoadGraphics(); mark.Scale=Vector(.5,.5); mark:Render(pos,Vector(0,0),Vector(0,0))
			end
		end
	end
end
local function render_menu(player)
	local menu=player:GetData()[item.own_key.."menu"]
	local values=item.get_values(player)
	local sprites=progress_sprites()
	local bar=sprites.bar
	local center=Isaac.WorldToScreen(player.Position)+Vector(0,-40)
	local ring_rotation=menu.ang or 0
	sprites.base.Rotation=ring_rotation; sprites.base.Scale=Vector(1,1)
	sprites.base.Color=Color(.18,.18,.18,.72,0,0,0)
	sprites.base:Render(center,Vector(0,0),Vector(0,0))
	for i=1,6 do
		local angle=ring_rotation+(i-1)*60+180
		local step=math.max(0,math.min(30,math.ceil(values[i]/item.cap*30)))
		local c=auxi.table2color(item.colors[i])
		bar:SetFrame("Step",30); bar.Rotation=angle; bar.Scale=Vector(1,1)
		bar.Color=Color(c.R*.12,c.G*.12,c.B*.12,.82,0,0,0)
		bar:Render(center,Vector(0,0),Vector(0,0))
		bar:SetFrame("Step",step); bar.Color=auxi.UpColor(c)
		bar:Render(center,Vector(0,0),Vector(0,0))
		local label_pos=center+auxi.get_by_rotate(Vector(0,62),angle)
		draw(label_pos+Vector(-12,-4),string.format("%.0f%%",values[i]),KColor(c.R,c.G,c.B,1),true)
	end
	local color_id=menu.color
	local color_angle=ring_rotation+(color_id-1)*60+180
	local selector_angle=180
	local current_step=math.max(0,math.min(30,math.ceil(values[color_id]/item.cap*30)))
	local c=auxi.table2color(item.colors[color_id])
	local icon_pos=center+auxi.get_by_rotate(Vector(0,current_step+20),selector_angle)
	local icon
	if menu.seled then
		local gain=preview_gain(player,menu.seled.id,color_id)
		local preview_step=math.max(0,math.min(30,math.ceil((values[color_id]+gain)/item.cap*30)))
		bar:SetFrame("Step",preview_step); bar.Rotation=color_angle
		bar.Color=auxi.MulColor(auxi.UpColor(c),Color(1,1,1,.5,1,1,1))
		bar:Render(center,Vector(0,0),Vector(0,0))
		icon_pos=center+auxi.get_by_rotate(Vector(0,preview_step+20),selector_angle)
		icon=auxi.load_item(menu.seled.id,{Anm="gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2"})
		draw(icon_pos+Vector(15,-15),string.format("+%.1f%%",gain),KColor(c.R,c.G,c.B,1),true)
	else icon=selector_icon("gfx/items/collectibles/questionmark.png") end
	if icon then
		icon.Rotation=selector_angle+180; icon.Color=auxi.AddColor(c,auxi.UpColor(c),.7,.3)
		icon:Render(icon_pos,Vector(0,0),Vector(0,0))
	end
	local mark=selector_icon("gfx/ui/math/catch_mark.png"); mark.Rotation=selector_angle+180
	mark:Render(icon_pos,Vector(0,0),Vector(0,0))
	if menu.toselect then render_grid(player,menu,icon_pos+Vector(0,35)) end
end
local function enter_items(player,menu)
	menu.list=item.makeitemlist(player)
	if #menu.list==0 then menu.toselect=nil; return false end
	menu.toselect=true
	menu.sel=math.min(menu.sel or 0,math.max(0,#menu.list-1))
	return true
end
local function move(player,dir)
	local menu=player:GetData()[item.own_key.."menu"]
	if not menu.toselect then
		if dir==4 then menu.color=menu.color%6+1
		elseif dir==5 then menu.color=(menu.color+4)%6+1
		elseif dir==6 or dir==7 then if not enter_items(player,menu) then return -1 end
		elseif dir==9 then
			if menu.seled then
				if commit(player,menu.seled,menu.color,menu.slot) then return -2 end
				menu.seled=nil; return -1
			end
			if not enter_items(player,menu) then return -1 end
		end
		return
	end
	local count=#(menu.list or {})
	if count==0 then menu.toselect=nil; return -1 end
	local cols=columns(player,count)
	local rows=math.ceil(count/cols)
	local index=menu.sel or 0
	local x,y=index%cols,math.floor(index/cols)
	if dir==5 then x=(x+1)%cols elseif dir==4 then x=(x+cols-1)%cols
	elseif dir==7 then y=(y+1)%rows elseif dir==6 then y=(y+rows-1)%rows
	elseif dir==9 then
		menu.seled=menu.list[index+1]; menu.toselect=nil; return
	end
	menu.sel=math.min(count-1,x+y*cols)
end

local function active_holder(color_id)
	for i=0,Game():GetNumPlayers()-1 do
		local player=Game():GetPlayer(i)
		if player:HasCollectible(item.entity) and active(item.get_values(player),color_id) then return player end
	end
end
local function add_progress(player,color_id,amount)
	local values=item.get_values(player)
	values[color_id]=math.min(item.cap,values[color_id]+amount)
	item.refresh_effects(player,false)
end
local function champion_gains(npc)
	local idx=npc:GetChampionColorIdx()
	if idx==25 then return {3,3,3,3,3,3} end
	if idx==6 then return {2,2,2,2,2,2} end
	local simple={[0]=1,[1]=3,[2]=4,[3]=2,[4]=5,[11]=6,[12]=1,[13]=5,[15]=4,[20]=1,[22]=3,[24]=2}
	if simple[idx] then local t={0,0,0,0,0,0}; t[simple[idx]]=10; return t end
	local sources={
		[5]={black=1},[7]={grey=1},[8]={white=.5,others=.5},[9]={others=1},[10]={pink=1},
		[14]={green=.5,brown=.5},[16]={grey=1},[17]={yellow=.5,others=.5},[18]={others=1},
		[19]={others=1},[21]={others=1},[23]={black=1},
	}
	local weights=map_weights(sources[idx] or {others=1})
	local total=0 for i=1,6 do total=total+weights[i] end
	local gains={0,0,0,0,0,0}
	if total>0 then for i=1,6 do gains[i]=weights[i]/total*12 end end
	return gains
end
local function champion_feedback(npc,player,gains)
	local r,g,b,total=0,0,0,0
	for i=1,6 do local n=gains[i] or 0; r=r+item.colors[i].R*n; g=g+item.colors[i].G*n; b=b+item.colors[i].B*n; total=total+n end
	if total<=0 then return end
	local rng=npc:GetDropRNG()
	for _=1,3 do
		local e=Isaac.Spawn(EntityType.ENTITY_EFFECT,16,2,npc.Position,Vector.FromAngle(rng:RandomInt(360)):Resized(2+rng:RandomFloat()*3),player):ToEffect()
		if e then e:GetSprite().Color=Color(r/total,g/total,b/total,1,.2,.2,.2) end
	end
end

table.insert(item.ToCall,{CallBack=ModCallbacks.MC_EVALUATE_CACHE,params=nil,Function=function(_,player,flag)
	if not player:HasCollectible(item.entity) then return end
	local values=item.get_values(player)
	if flag==CacheFlag.CACHE_DAMAGE and active(values,1) then player.Damage=player.Damage+3
	elseif flag==CacheFlag.CACHE_SPEED and active(values,4) then player.MoveSpeed=player.MoveSpeed+.15
	elseif flag==CacheFlag.CACHE_FLYING and active(values,4) then player.CanFly=true
	elseif flag==CacheFlag.CACHE_FIREDELAY and active(values,5) then
		local tears=30/(player.MaxFireDelay+1); player.MaxFireDelay=30/math.max(.1,tears+1.5)-1
	end
end})
table.insert(item.pre_ToCall,{CallBack=ModCallbacks.MC_ENTITY_TAKE_DMG,params=EntityType.ENTITY_PLAYER,priority=-50,Function=function(_,ent)
	local player=ent:ToPlayer()
	if player and player:HasCollectible(item.entity) and active(item.get_values(player),6) and player:GetCollectibleRNG(item.entity):RandomFloat()<.25 then return false end
end})
table.insert(item.myToCall,{CallBack=enums.Callbacks.POST_ATTACK_DPS_SAMPLE,params=nil,Function=function(_,event)
	local player,ent=event and event.player,event and event.member
	if not player or not ent or not player:HasCollectible(item.entity) or not active(item.get_values(player),5) then return end
	-- One sample → one three-puddle trail. Continuous weapons rely on DPS sampler cadence; no per-member lock.
	local origin=event.position or ent.Position or player.Position
	local direction=event.direction or ent.Velocity or Vector(0,0)
	if direction:Length()>.01 then direction=direction:Normalized() else direction=Vector(0,0) end
	for distance=0,40,20 do
		local creep=Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.PLAYER_CREEP_HOLYWATER_TRAIL,0,origin+direction*distance,Vector(0,0),player):ToEffect()
		if creep then creep.Timeout=45; creep.Scale=.7; creep.CollisionDamage=player.Damage*.66; creep:Update() end
	end
end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_NPC_UPDATE,params=nil,Function=function(_,npc)
	local data=npc:GetData(); if data[item.own_key.."champion_roll"] or npc.FrameCount<2 then return end
	data[item.own_key.."champion_roll"]=true
	if not active_holder(6) or npc:IsChampion() or npc:IsBoss() or not npc:IsVulnerableEnemy() or not npc:IsActiveEnemy(false) or npc.CanShutDoors~=true or npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY|EntityFlag.FLAG_CHARM|EntityFlag.FLAG_NO_TARGET) then return end
	if npc:GetDropRNG():RandomFloat()<1/3 then npc:MakeChampion(npc.InitSeed,-1,true) end
end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_POST_NPC_DEATH,params=nil,Function=function(_,npc)
	if not npc:IsChampion() then return end
	local gains=champion_gains(npc)
	for p=0,Game():GetNumPlayers()-1 do
		local player=Game():GetPlayer(p)
		if player:HasCollectible(item.entity) then
			for i=1,6 do if gains[i]>0 then add_progress(player,i,gains[i]) end end
			champion_feedback(npc,player,gains)
		end
	end
end})

local CLEAR_REWARD_VARIANTS = {
	[PickupVariant.PICKUP_HEART]=true,[PickupVariant.PICKUP_COIN]=true,[PickupVariant.PICKUP_KEY]=true,
	[PickupVariant.PICKUP_BOMB]=true,[PickupVariant.PICKUP_GRAB_BAG]=true,[PickupVariant.PICKUP_PILL]=true,
	[PickupVariant.PICKUP_LIL_BATTERY]=true,[PickupVariant.PICKUP_TAROTCARD]=true,
}
local function duplicate_rewards(old)
	for _,entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP)) do
		local pickup=entity:ToPickup()
		if pickup and not old[pickup.InitSeed] and CLEAR_REWARD_VARIANTS[pickup.Variant] and not pickup:GetData()[item.own_key.."reward_copy"] then
			local pos=Game():GetRoom():FindFreePickupSpawnPosition(pickup.Position+Vector(20,0),10,true)
			local copy=Isaac.Spawn(pickup.Type,pickup.Variant,pickup.SubType,pos,Vector(0,0),pickup)
			if copy then copy:GetData()[item.own_key.."reward_copy"]=true end
		end
	end
end
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD,params=nil,Function=function(_,rng)
	local duplicate=false
	for p=0,Game():GetNumPlayers()-1 do
		local player=Game():GetPlayer(p)
		if player:HasCollectible(item.entity) then
			local values=item.get_values(player)
			if active(values,2) and rng:RandomFloat()<.5 then duplicate=true end
			local copies=math.max(1,true_num(player,item.entity)); local drain=math.max(4,10-(copies-1)*2)
			for i=1,6 do if active(values,i) then values[i]=math.max(0,values[i]-drain) end end
			item.refresh_effects(player,false)
		end
	end
	if duplicate then
		local old={} for _,entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP)) do old[entity.InitSeed]=true end
		delay_buffer.addeffe(duplicate_rewards,old,1)
	end
end})

table.insert(item.ToCall,{CallBack=ModCallbacks.MC_USE_ITEM,params=enums.Items.Ritual_Sting,Function=function(_,_,_,player,flags,slot)
	if flags&UseFlag.USE_CARBATTERY==UseFlag.USE_CARBATTERY then return {Discharge=false,ShowAnim=false} end
	local d=player:GetData()
	if d[item.own_key.."menu"] then close_menu(player); return {Discharge=false,ShowAnim=false} end
	d[item.own_key.."menu"]={Lift=true,Render=false,color=1,sel=0,slot=slot}
	item.last_open_dir=9; item.last_open_dir_counter=0
	return {Discharge=false,ShowAnim=false}
end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_INPUT_ACTION,params=nil,Function=function(_,ent,hook,button)
	local player=ent and ent:ToPlayer()
	if player and player:GetData()[item.own_key.."menu"] and selection_holder.check_select(player,item.own_key) then
		for _,action in ipairs({4,5,6,7,9,11}) do if button==action and (hook==InputHook.IS_ACTION_TRIGGERED or hook==InputHook.IS_ACTION_PRESSED) then return false end end
	end
end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_POST_PLAYER_UPDATE,params=nil,Function=function(_,player)
	if player:HasCollectible(item.entity) then item.refresh_effects(player,false) end
	local menu=player:GetData()[item.own_key.."menu"]; if not menu then return end
	if menu.Lift then
		if player:IsExtraAnimationFinished() then player:AnimateCollectible(item.entity,"LiftItem","PlayerPickup"); selection_holder.check_and_try_select(player,item.own_key); menu.Lift=nil; menu.Render=true end
		return
	end
	if not player:IsHoldingItem() then close_menu(player) return end
	if not selection_holder.check_select(player,item.own_key) or Game():IsPaused() then return end
	local target_angle=-(menu.color-1)*60
	menu.ang=auxi.checkrounded(menu.ang or target_angle,target_angle,.75,.25,360)
	local dir
	for _,action in ipairs({4,5,6,7,9,11}) do if Input.IsActionTriggered(action,player.ControllerIndex) or Input.IsActionPressed(action,player.ControllerIndex) then dir=action end end
	if not dir then item.last_open_dir=nil return end
	if dir==11 then close_menu(player) return end
	local go=false
	if dir==item.last_open_dir then item.last_open_dir_counter=(item.last_open_dir_counter or 0)+1; go=item.last_open_dir_counter>item.dir_time_limit and item.last_open_dir_counter%8==1
	else item.last_open_dir_counter=0; go=true end
	item.last_open_dir=dir
	if go then
		local result=move(player,dir)
		if result==-1 then sound_tracker.PlayStackedSound(187,1,1,false,0,2)
		elseif result~=-2 then
			if dir==5 or dir==6 then sound_tracker.PlayStackedSound(195,1,1,false,0,2)
			elseif dir==4 or dir==7 then sound_tracker.PlayStackedSound(194,1,1,false,0,2)
			elseif dir==9 then sound_tracker.PlayStackedSound(285,1,1,false,0,2) end
		end
	end
end})
table.insert(item.ToCall,{CallBack=ModCallbacks.MC_POST_PLAYER_RENDER,params=nil,Function=function(_,player)
	local menu=player:GetData()[item.own_key.."menu"]
	if Game():GetRoom():GetRenderMode()~=RenderMode.RENDER_WATER_REFLECT and menu and menu.Render and player:IsHoldingItem() and selection_holder.check_select(player,item.own_key) then render_menu(player) end
end})

function item.check_EID_info(player)
	local values=item.get_values(player)
	local language=auxi.get_EID_language()=="zh_cn" and "zh" or "en"
	local lines={}
	for id=1,6 do
		local text=item.color_names[language][id].." "..string.format("%.1f%%",values[id])
		if active(values,id) then text=text..": "..item.effect_names[language][id] end
		lines[#lines+1]="#{{Blank}} {{"..item.eid_color_tags[id].."}}"..text.."{{CR}}"
	end
	return table.concat(lines)
end
if EID then
	EID:addDescriptionModifier("qing_item_sync"..tostring(item.entity),function() return true end,function(desc)
		if desc.ObjType==5 and desc.ObjVariant==100 and desc.ObjSubType==item.entity then
			local player=auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0)
			EID:appendToDescription(desc,item.check_EID_info(player))
		end
		return desc
	end)
end

return item
