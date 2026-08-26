local item = RegisterMod("QING_REBIRTH",1)
item.Version = "1.0.3"
___QING_REBIRTH___ = {MOD = item,}		--如果需要唯一标识符，请使用该变量

-- math.random 是整个 Lua 环境共享的非确定随机流；必须在任何业务模块加载前播种。
-- os 默认不可用；混合系统启动毫秒与引擎全局 Random()，避免依赖单一熵源。
do
	local time_part = math.floor((Isaac.GetTime and Isaac.GetTime()) or 0) & 0xffffffff
	local engine_part = math.floor((Random and Random()) or 0) & 0xffffffff
	local seed = (time_part ~ engine_part ~ 0x51494e47) & 0xffffffff -- "QING"
	seed = seed ~ (seed >> 16)
	seed = (seed * 0x7feb352d) & 0xffffffff
	seed = seed ~ (seed >> 15)
	seed = (seed * 0x846ca68b) & 0xffffffff
	seed = seed ~ (seed >> 16)
	seed = seed & 0x7fffffff
	if seed == 0 then seed = 1 end
	math.randomseed(seed)
	-- 丢弃最初几个值，规避部分 Lua 实现低质量的初始输出。
	math.random(); math.random(); math.random()
end

if not REPENTOGON then
	local notice_started = false
	local notice_frames = 0
	local notice_duration = 15 * 30
	local notice_font = Font()
	notice_font:Load("font/cjk/lanapixel.fnt")
	local notice_text = Options.Language == "zh" and {
		"[琉璃圣典：应许之地] 未检测到 REPENTOGON",
		"已进入 Vanilla 兼容模式，部分功能将不可用",
	} or {
		"[Glaze Ceremony: Promised Land] REPENTOGON was not detected",
		"Vanilla compatibility mode is active; some features are unavailable",
	}
	item:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,function()
		if notice_started then return end
		notice_started = true
		notice_frames = notice_duration
	end)
	item:AddCallback(ModCallbacks.MC_POST_RENDER,function()
		if not notice_started or notice_frames <= 0 then return end
		local width = Isaac.GetScreenWidth()
		local y = Isaac.GetScreenHeight() * 0.5 - 12
		local color = KColor(1,0.35,0.25,1)
		for index,line in ipairs(notice_text) do
			notice_font:DrawStringUTF8(line,0,y + (index - 1) * 18,color,width,true)
		end
		notice_frames = notice_frames - 1
	end)
	-- 不要在这里停止加载：Vanilla 仍需要注册普通 Lua 与 shader 的中性参数回调。
	-- RGON 专用模块和回调由各 manager 内既有的 REPENTOGON 判断跳过。
	if Options.Language == "zh" then
		print("[琉璃圣典：应许之地] 未检测到 REPENTOGON，已进入 Vanilla 兼容模式。")
	else
		print("[Glaze Ceremony: Promised Land] REPENTOGON was not detected; loading Vanilla compatibility mode.")
	end
end

require("Qing_Remaster_scripts.core.preload_manager").Init()
local manager = require("Qing_Remaster_scripts.core.manager_manager") manager.Init(item)

if Options.Language == "zh" then
	print("[琉璃圣典：应许之地] 已加载 (v"..item.Version..")")
else
	print("[Glaze Ceremony: Promised Land] Loaded (v"..item.Version..")")
end


------------------------------------------------PASTE_BINS----------------------------------------------------------
--l local player = Game():GetPlayer(0) local familiar = Isaac.Spawn(3,1,0,player.Position + Vector(10,10),Vector(0,0),nil):ToFamiliar() familiar:RemoveFromFollowers() familiar:RemoveFromDelayed() familiar:RemoveFromOrbit() local q = Isaac.Spawn(966,0,0,player.Position + Vector(10,10),Vector(0,0),nil) q.Target = familiar q.Parent = player
--l local player = Game():GetPlayer(0) local q = Isaac.Spawn(1000, EffectVariant.GENERIC_TRACER, 0, Vector(200,200), Vector(0,0), player):ToEffect() q:FollowParent(player) q.LifeSpan = 10 q.TargetPosition = Vector(100,100)		--瞄准轨迹
--l local ent = Isaac.Spawn(20, 0, 0, Vector(200,200),Vector(0,0), nil) local player = Game():GetPlayer(0) local q = Isaac.Spawn(865, 10, 0, Vector(200,200),Vector(0,0), nil) q.Parent = player q.Target = ent local s = q:GetSprite() for i = 0,1 do s:ReplaceSpritesheet(i,"gfx/effects/linkers/dark_linker.png") end s:LoadGraphics()		--连接线
--l local e1 = Isaac.Spawn(1000,2338,0,Vector(200,0),Vector(0,0),nil) local e2 = Isaac.Spawn(1000,2338,0,Vector(200,400),Vector(0,0),nil) local q = Isaac.Spawn(865, 10, 0, Vector(200,200),Vector(0,0), nil) q.Parent = e1 q.Target = e2 local s = q:GetSprite() for i = 0,1 do s:ReplaceSpritesheet(i,"gfx/effects/linkers/dark_linker.png") end s:LoadGraphics()
--l local entities = Isaac.GetRoomEntities() for _,entity in pairs(entities) do if entity.Type == 1000 then print(entity.Type.."-"..entity.Variant.."-"..entity.SubType) end end
--l local desc = Game():GetLevel():GetRoomByIdx(84) desc.Data.Type = 5
--l local desc = Game():GetCurrentRoomDesc()
--l local hw = RegisterMod("HelloWord",1) hw:AddCallback(ModCallbacks.MC_PRE_ROOM_ENTITY_SPAWN, function(_,tp,vr,st,gid,seed) print(seed) end)
--l local hw = RegisterMod("HelloWord",1) local ignoreFlags = DamageFlag.DAMAGE_DEVIL | DamageFlag.DAMAGE_IV_BAG | DamageFlag.DAMAGE_FAKE | DamageFlag.DAMAGE_CURSED_DOOR | DamageFlag.DAMAGE_NO_PENALTIES hw:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,function(_,ent,amt,flag,source,cooldown) if ent:ToPlayer() then local player = ent:ToPlayer() if amt > 0 and ((source and source.Type ~= EntityType.ENTITY_SLOT and source.Type ~= EntityType.ENTITY_PLAYER) or not source) and (flag & ignoreFlags) == 0 then player:UseActiveItem(636) end end end,1)
--l local player = Game():GetPlayer(0) player:UseActiveItem(CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE,UseFlag.USE_NOANIM) Game():StartRoomTransition(80, Direction.LEFT, RoomTransitionAnim.WALK, player,2)
--l Isaac.ExecuteCommand("goto s.boss.1010") local desc = Game():GetLevel():GetCurrentRoomDesc() print(desc.SafeGridIndex) local desc = Game():GetLevel():GetCurrentRoomDesc() print(desc.SafeGridIndex)
--l local player = Game():GetPlayer(0) q = Isaac.Spawn(5,100,33,player.Position,Vector(0,0),nil):ToPickup() for i = 1,30 do q:Update() end Game():GetRoom():Update() for i = 1,120 do player:Update() end for lev = 1,6 do Isaac.ExecuteCommand("stage "..tostring(lev)) local rooms = Game():GetLevel():GetRooms() for i = 1, rooms.Size do local targ = rooms:Get(i - 1) if targ.Data.Type == 12 then print(lev) end end end
--l local seed = Game():GetSeeds() seed:SetStartSeed("") seed:Restart(0) for i = 1,20 do Game():GetRoom():Update() end for lev = 1,6 do Isaac.ExecuteCommand("stage "..tostring(lev)) local rooms = Game():GetLevel():GetRooms() for i = 1, rooms.Size do local targ = rooms:Get(i - 1) if targ.Data.Type == 12 then print(lev) end end end local player = Game():GetPlayer(0) q = Isaac.Spawn(5,100,33,player.Position,Vector(0,0),nil):ToPickup() for i = 1,30 do q:Update() end Game():GetRoom():Update() for i = 1,120 do player:Update() end for lev = 1,6 do Isaac.ExecuteCommand("stage "..tostring(lev)) local rooms = Game():GetLevel():GetRooms() for i = 1, rooms.Size do local targ = rooms:Get(i - 1) if targ.Data.Type == 12 then print(lev) end end end
--l local player = Game():GetPlayer(0) local oldchallenge = Game().Challenge Game().Challenge = 6 player:UpdateCanShoot() Game().Challenge = oldchallenge
--l local oldGridSpawn = Isaac.GridSpawn local function newGridSpawn(...) print(1) oldGridSpawn(...) end rawset(Isaac,"GridSpawn",newGridSpawn)
--l local oldprint = print local function newprint(...) Game():GetPlayer(0):AnimateHappy() oldprint(...) end rawset(_G,"print",newprint)
--l local oldRandom = Random local function newRandom(...) local ret = oldRandom(...) print(ret) return ret end rawset(_G,"Random",newRandom)
--l local oldGame = Game local ret = {} ret = setmetatable(ret,{__index = function(t,key) print(key) local ret = oldGame()[key] if type(ret) == "function" then return function(_,...) return ret(oldGame(),...) end else return ret end end,}) local function newGame(...) return ret end rawset(_G,"Game",newGame)
--l local n_entity = Isaac.GetRoomEntities() for u,v in pairs(n_entity) do if v.Type == 1000 then v:Remove() end end


function item:Init(continued)
	if continued then
		if Options.Language == "zh" then
			print("[琉璃圣典：应许之地] 已继续 (v"..item.Version..")")
		else
			print("[Glaze Ceremony: Promised Land] Continued (v"..item.Version..")")
		end
	end
end
item:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, item.Init)
