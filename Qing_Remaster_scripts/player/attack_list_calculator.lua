local enums = require("Qing_Remaster_scripts.core.enums")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local calc = {}
local auxi_module

local function get_auxi()
	auxi_module = auxi_module or require("Qing_Remaster_scripts.auxiliary.functions")
	return auxi_module
end

local auxi = setmetatable({}, {
	__index = function(_, key)
		return get_auxi()[key]
	end,
})

local function get_rgon_multishot_info(player,weapon)
	if not player then return nil end
	local ok, params = pcall(function()
		return player:GetMultiShotParams(weapon or WeaponType.WEAPON_TEARS)
	end)
	if not ok or not params then return nil end
	local info = {params = params,rgon = true,}
	ok, info.numTears = pcall(function() return params:GetNumTears() end)
	if not ok then info.numTears = 1 end
	ok, info.numEyes = pcall(function() return params:GetNumEyesActive() end)
	if not ok then info.numEyes = 1 end
	ok, info.randomDirTears = pcall(function() return params:GetNumRandomDirTears() end)
	if not ok then info.randomDirTears = 0 end
	ok, info.sideways = pcall(function() return params:IsShootingSideways() end)
	if not ok then info.sideways = false end
	ok, info.backwards = pcall(function() return params:IsShootingBackwards() end)
	if not ok then info.backwards = false end
	ok, info.crossEyed = pcall(function() return params:IsCrossEyed() end)
	if not ok then info.crossEyed = false end
	info.numTears = math.max(1,info.numTears or 1)
	info.numEyes = math.max(1,info.numEyes or 1)
	info.randomDirTears = math.max(0,info.randomDirTears or 0)
	return info
end

local multishots_list = {68,52,114,168,395,579,}
local function add_manual_vanilla_multishots(player,cnt1,allowrand,wiz_count)
	if player:HasCollectible(153) or player:HasCollectible(2) or player:GetPlayerType() == 14 or player:GetPlayerType() == 33 or player:GetEffects():HasNullEffect(NullItemID.ID_REVERSE_HANGED_MAN) then	--四眼、三眼、店长、里店长的特效：眼泪固定加1发，二者不叠加。有趣的是，对于眼泪而言，三、四眼和多个20/20叠加不完全一致，但科技的激光、妈刀等等却并非如此，说明程序员偷懒了（
		cnt1 = cnt1 + 1
	end
	for i = 1,#multishots_list do
		cnt1 = cnt1 + math.max(0,player:GetCollectibleNum(multishots_list[i]) - 1)
	end
	local inner_eye_effe = player:GetCollectibleNum(2)
	local mutant_effe = player:GetCollectibleNum(153)
	local perfect_eye_effe = player:GetCollectibleNum(245)
	if player:GetEffects():HasNullEffect(NullItemID.ID_REVERSE_HANGED_MAN) then inner_eye_effe = inner_eye_effe + 1 end
	if inner_eye_effe > 0 or mutant_effe > 0 then perfect_eye_effe = perfect_eye_effe - 1 end
	cnt1 = cnt1 + math.max(0,mutant_effe * 2) + math.max(0,inner_eye_effe) + math.max(0,perfect_eye_effe) + math.max(0,wiz_count or player:GetCollectibleNum(358))	--二、三、四眼与巫师帽
	if player:HasPlayerForm(PlayerForm.PLAYERFORM_BABY) and math.max(0,player:GetCollectibleNum(358)) < 2 then cnt1 = cnt1 + 2 end
	if allowrand then
		if player:HasPlayerForm(PlayerForm.PLAYERFORM_BOOK_WORM) and math.max(0,player:GetCollectibleNum(358)) < 2 then		--书套：随机加1发
			if math.random(4) > 3 then cnt1 = cnt1 + 1 end
		end
	end
	return cnt1
end

local function get_vanilla_multishot_count(player,params,default_cnt,allowrand,wiz_count)
	params = params or {}
	local info = get_rgon_multishot_info(player,params.weapon or WeaponType.WEAPON_TEARS)
	if info then
		local base = params.cnt1
		if base == nil then base = default_cnt end
		local effective_num_tears = math.max(info.numTears or 1,info.numEyes or 1)
		local count = effective_num_tears + (base or 1) - 1 + (params.extraTears or 0)
		return math.max(0,count),info
	end
	return add_manual_vanilla_multishots(player,params.cnt1 or default_cnt,allowrand,wiz_count) + (params.extraTears or 0) + (params.extraTearsFallback or 0),nil
end

function calc.getmultishots(player,allowrand)
	player = player or Game():GetPlayer(0)
	local cnt1 = get_vanilla_multishot_count(player,{weapon = WeaponType.WEAPON_TEARS},1,allowrand)
	return cnt1
end

function calc.getQingshots(player,allowrand)
	local ret = (calc.getmultishots(player,allowrand) + 1 + player:GetCollectibleNum(619) * 3) or 0 
	return ret
end

function calc.get_Qing_multishots(player,list,params)
	params = params or {}
	list = list or calc.get_qing_list(player)
	local cnt1,multi_info = get_vanilla_multishot_count(player,params,1,params.allowrand,list.wiz)
	local cnt2 = params.cnt2 or (multi_info and multi_info.numEyes) or (list.wiz + 1)
	local cnt3 = 0
	if player:HasPlayerForm(PlayerForm.PLAYERFORM_BABY) then cnt3 = 1 end
	local ret = {}
	local cnt = math.ceil(cnt1/cnt2)
	if cnt3 == 1 and cnt2 == 1 then cnt = math.ceil((cnt1-2)/cnt2) end
	if cnt2 > 2 then cnt3 = 0 end
	local dir = 180 /(cnt2+1)
	local inv3 = 5
	if cnt3 == 1 then			--存在宝宝套
		if cnt2 == 1 then		--单弹道
			table.insert(ret,#ret + 1,{dir = -45,})
			table.insert(ret,#ret + 1,{dir = 45,})
			for i = 1,cnt do table.insert(ret,#ret + 1,{dir = -(cnt-1)/2 * inv3 + (i-1) * inv3,}) end
		else					--巫师帽
			for i = 1,cnt do table.insert(ret,#ret + 1,{dir = 45 -(cnt-1)/2 * inv2 + (i - 1) * inv2,}) end
			for i = 1,cnt do table.insert(ret,#ret + 1,{dir = -45 -(cnt-1)/2 * inv2 + (i - 1) * inv2,})	end
		end
	else
		local inv = 30
		if cnt2 == 1 then inv = 5 + cnt end
		for j = 1,cnt2 do
			for i = 1,cnt do
				table.insert(ret,#ret + 1,{dir = j * dir - 90 - (cnt-1)/2 * inv + (i-1) * inv,})
			end
		end
	end
	local multitar = 0
	if (list.lung or 0) > 0 then for i = 1,list.lung do multitar = multitar + math.random(3) - 1 end end
	if multi_info then
		multitar = multitar + (multi_info.randomDirTears or 0)
	elseif (list.eye or 0) > 0 then
		for i = 1,list.eye do multitar = multitar + auxi.choose(0,0,1) end
	end
	for i = 1,multitar do table.insert(ret,#ret + 1,{dir = math.random(360),Anim = "IdleUp",}) end
	local backdir = 0
	if multi_info and multi_info.sideways then
		table.insert(ret,#ret + 1,{dir = -90,})
		table.insert(ret,#ret + 1,{dir = 90,})
		backdir = backdir + 1
	elseif list.loki and list.loki > 0 then 
		if auxi.check_rand(player.Luck,100,3,15) then
			table.insert(ret,#ret + 1,{dir = -90,})
			table.insert(ret,#ret + 1,{dir = 90,})
			backdir = backdir + 1
		end
	end
	if multi_info and multi_info.backwards then backdir = backdir + 1
	elseif (list.momeye or 0) > 0 then if auxi.check_rand(player.Luck,100,10,5) then backdir = backdir + 1 end end
	for i = 1,backdir do table.insert(ret,#ret + 1,{dir = -180 -(backdir-1)/2 * inv3 + (i-1) * inv3,}) end
	if (list.pencil or 0) > 0 then
		player:GetData().Qing_pencil_counter = (player:GetData().Qing_pencil_counter or 0) + 1
		if player:GetData().Qing_pencil_counter >= 7 then 
			player:GetData().Qing_pencil_counter = 0
			for i = 1,4 do table.insert(ret,#ret + 1,{dir = -50 + i * 20,}) end
		end
	end
	if (list.immu or 0) > 0 then
		if auxi.check_rand(player.Luck,60,30,4) then table.insert(ret,#ret + 1,{dir = 0,Anim = "IdleUp",tearflag = BitSet128(0,1<<(69-64)),color = Color(1,1,1,1,0.3,0.3,0.3),}) end
	end
	if (list.greed_head or 0) > 0 then 
		player:GetData().Qing_greed_head_counter = (player:GetData().Qing_greed_head_counter or 0) + 1
		if player:GetData().Qing_greed_head_counter >= 10 then
			table.insert(ret,#ret + 1,{dir = 0,Anim = "GreedHead",tearflag = BitSet128(1<<53,0),color = Color(1,0.69,0,1,1,0.69,0),})
			player:GetData().Qing_greed_head_counter = nil
		end
	end
	return ret
end

function calc.get_Tecro_multishots(player,list,params)
	params = params or {}
	list = list or calc.get_Tecro_list(player)
	local cnt1,multi_info = get_vanilla_multishot_count(player,params,0,params.allowrand,list.wiz)
	local cnt2 = params.cnt2 or (multi_info and multi_info.numEyes) or (list.wiz + 1)
	local cnt3 = 0
	if player:HasPlayerForm(PlayerForm.PLAYERFORM_BABY) then cnt3 = 1 end
	local ret = {}
	local cnt = math.ceil(cnt1/cnt2)
	if cnt3 == 1 and cnt2 == 1 then cnt = math.ceil((cnt1-2)/cnt2) end
	if cnt2 > 2 then cnt3 = 0 end
	local dir = 180 /(cnt2+1)
	local inv1 = 30
	local inv2 = 5 + cnt
	local inv3 = 5
	if cnt3 == 1 then			--存在宝宝套
		if cnt2 == 1 then		--单弹道
			table.insert(ret,#ret + 1,{dir = -45,})
			table.insert(ret,#ret + 1,{dir = 45,})
			for i = 1,cnt do table.insert(ret,#ret + 1,{dir = -(cnt-1)/2 * inv3 + (i-1) * inv3,}) end
		else					--巫师帽
			for i = 1,cnt do table.insert(ret,#ret + 1,{dir = 45 -(cnt-1)/2 * inv2 + (i - 1) * inv2,}) end
			for i = 1,cnt do table.insert(ret,#ret + 1,{dir = -45 -(cnt-1)/2 * inv2 + (i - 1) * inv2,})	end
		end
	else
		if cnt2 ~= 1 then
			for j = 1,cnt2 do
				for i = 1,cnt do
					table.insert(ret,#ret + 1,{dir = j * dir - 90 - (cnt-1)/2 * inv1 + (i-1) * inv1,})
				end
			end
		else
			for j = 1,cnt2 do
				for i = 1,cnt do
					table.insert(ret,#ret + 1,{dir = j * dir - 90 - (cnt-1)/2 * inv2 + (i-1) * inv2,})
				end
			end
		end
	end
	local multitar = 0
	if (list.lung and list.lung > 0) or (list.eye and list.eye > 0) then
		for i = 1,list.lung do multitar = multitar + math.random(3)	end
		if multi_info then
			multitar = multitar + (multi_info.randomDirTears or 0)
		else
			for i = 1,list.eye do multitar = multitar + math.random(1) end
		end
	end
	for i = 1,multitar do table.insert(ret,#ret + 1,{dir = math.random(360),}) end
	local backdir = 0
	if multi_info and multi_info.sideways then
		table.insert(ret,#ret + 1,{dir = -90,})
		table.insert(ret,#ret + 1,{dir = 90,})
		backdir = backdir + 1
	elseif list.loki and list.loki > 0 then 
		if auxi.check_rand(player.Luck,100,3,15) then
			table.insert(ret,#ret + 1,{dir = -90,})
			table.insert(ret,#ret + 1,{dir = 90,})
			backdir = backdir + 1
		end
	end
	if multi_info and multi_info.backwards then backdir = backdir + 1
	elseif list.momeye and list.momeye > 0 then 
		if auxi.check_rand(player.Luck,100,10,5) then backdir = backdir + 1 end
	end
	for i = 1,backdir do table.insert(ret,#ret + 1,{dir = -180 -(backdir-1)/2 * inv3 + (i-1) * inv3,}) end
	if list.pencil and list.pencil > 0 then
		player:GetData().Tecro_pencil_counter = (player:GetData().Tecro_pencil_counter or 0) + 1
		if player:GetData().Tecro_pencil_counter >= 7 then 
			player:GetData().Tecro_pencil_counter = 0
			for i = 1,4 do table.insert(ret,#ret + 1,{dir = -50 + i * 20,}) end
		end
	end
	if list.immu and list.immu > 0 then
		if auxi.check_rand(player.Luck,30,10,5) then table.insert(ret,#ret + 1,{dir = 0,tearflag = BitSet128(0,1<<(69-64)),}) end
	end
	return ret
end

function calc.get_Tecrorun_multishots(player,list,params)
	params = params or {}
	list = list or calc.get_Tecro_list(player)
	local cnt1,multi_info = get_vanilla_multishot_count(player,params,0,params.allowrand,list.wiz)
	local cnt2 = params.cnt2 or (multi_info and multi_info.numEyes) or (list.wiz + 1)
	local cnt3 = 0
	if player:HasPlayerForm(PlayerForm.PLAYERFORM_BABY) then cnt3 = 1 end
	local ret = {}
	local cnt = auxi.random_c(cnt1/cnt2)	--math.ceil(cnt1/cnt2)
	if cnt3 == 1 and cnt2 == 1 then cnt = math.ceil((cnt1-2)/cnt2) end if cnt2 > 2 then cnt3 = 0 end
	local dir = 180/(cnt2+1) local inv1 = 30 local inv2 = 5 + cnt local inv3 = 5
	if cnt3 == 1 then			--存在宝宝套
		if cnt2 == 1 then		--单弹道
			table.insert(ret,#ret + 1,{dir = -45,})
			table.insert(ret,#ret + 1,{dir = 45,})
			for i = 1,cnt do table.insert(ret,#ret + 1,{dir = -(cnt-1)/2 * inv3 + (i-1) * inv3,}) end
		else					--巫师帽
			for i = 1,cnt do table.insert(ret,#ret + 1,{dir = 45 -(cnt-1)/2 * inv2 + (i - 1) * inv2,}) end
			for i = 1,cnt do table.insert(ret,#ret + 1,{dir = -45 -(cnt-1)/2 * inv2 + (i - 1) * inv2,})	end
		end
	else
		if cnt2 ~= 1 then for j = 1,cnt2 do for i = 1,cnt do table.insert(ret,#ret + 1,{dir = j * dir - 90 - (cnt-1)/2 * inv1 + (i-1) * inv1,}) end end
		else for j = 1,cnt2 do for i = 1,cnt do table.insert(ret,#ret + 1,{dir = j * dir - 90 - (cnt-1)/2 * inv2 + (i-1) * inv2,}) end end end
	end
	local multitar = 0
	if (list.lung and list.lung > 0) or (list.eye and list.eye > 0) then
		for i = 1,list.lung do multitar = multitar + math.random(3)	end
		if multi_info then
			multitar = multitar + (multi_info.randomDirTears or 0)
		else
			for i = 1,list.eye do multitar = multitar + math.random(1) end
		end
	end
	for i = 1,multitar do table.insert(ret,#ret + 1,{dir = math.random(360),}) end
	local backdir = 0
	if multi_info and multi_info.sideways then
		table.insert(ret,#ret + 1,{dir = -90,})
		table.insert(ret,#ret + 1,{dir = 90,})
		backdir = backdir + 1
	elseif list.loki and list.loki > 0 then 
		if auxi.check_rand(player.Luck,100,3,15) then
			table.insert(ret,#ret + 1,{dir = -90,})
			table.insert(ret,#ret + 1,{dir = 90,})
			backdir = backdir + 1
		end
	end
	if multi_info and multi_info.backwards then backdir = backdir + 1
	elseif list.momeye and list.momeye > 0 then if auxi.check_rand(player.Luck,100,10,5) then backdir = backdir + 1 end end
	for i = 1,backdir do table.insert(ret,#ret + 1,{dir = -180 -(backdir-1)/2 * inv3 + (i-1) * inv3,}) end
	if (list.pencil or 0) > 0 then
		if auxi.inner_tick(player:GetData(),"Tecrorun_pencil",7,{Update = true,}) then
			for i = 1,4 do table.insert(ret,#ret + 1,{dir = -50 + i * 20,}) end
		end
	end
	if (list.immu or 0) > 0 then if auxi.check_rand(player.Luck,30,10,5) then table.insert(ret,#ret + 1,{dir = 0,tearflags = BitSet128(0,1<<(69-64)) | BitSet128(1<<16,0),}) end end
	if (list.greed_head or 0) > 0 then 
		if auxi.inner_tick(player:GetData(),"Tecrorun_greed_head",5,{Update = true,}) then
			player:AddCoins(-1)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_CASH_REGISTER,1,1,false,0,2)
			table.insert(ret,#ret + 1,{dir = 0,tearflags = BitSet128(1<<53,0),cross = "GoldInfo",})
		end
	end
	return ret
end

function calc.get_Anna_multishots(player,list,params)
	params = params or {}
	local d = player:GetData()
	list = list or calc.get_Anna_list(player)
	local cnt1,multi_info = get_vanilla_multishot_count(player,params,1,params.notallowrand ~= true,list.wiz)
	local cnt2 = params.cnt2 or (multi_info and multi_info.numEyes) or (list.wiz + 1)
	local cnt3 = 0
	local charge = params.charge or 1
	if player:HasPlayerForm(PlayerForm.PLAYERFORM_BABY) then cnt3 = 1 end
	local ret = {}
	local cnt = math.ceil(cnt1/cnt2)
	if cnt3 == 1 and cnt2 == 1 then cnt = math.ceil((cnt1-2)/cnt2) end
	if cnt2 > 2 then cnt3 = 0 end
	local dir = 180 /(cnt2+1)
	local inv1 = 30
	local inv2 = 5 + cnt
	local inv3 = 5
	if cnt3 == 1 then			--存在宝宝套
		if cnt2 == 1 then		--单弹道
			table.insert(ret,#ret + 1,{dir = -45,})
			table.insert(ret,#ret + 1,{dir = 45,})
			for i = 1,cnt do table.insert(ret,#ret + 1,{dir = -(cnt-1)/2 * inv3 + (i-1) * inv3,}) end
		else					--巫师帽
			for i = 1,cnt do table.insert(ret,#ret + 1,{dir = 45 -(cnt-1)/2 * inv2 + (i - 1) * inv2,}) end
			for i = 1,cnt do table.insert(ret,#ret + 1,{dir = -45 -(cnt-1)/2 * inv2 + (i - 1) * inv2,})	end
		end
	else
		if cnt2 ~= 1 then for j = 1,cnt2 do for i = 1,cnt do table.insert(ret,#ret + 1,{dir = j * dir - 90 - (cnt-1)/2 * inv1 + (i-1) * inv1,}) end end
		else for j = 1,cnt2 do for i = 1,cnt do table.insert(ret,#ret + 1,{dir = j * dir - 90 - (cnt-1)/2 * inv2 + (i-1) * inv2,}) end end end
	end
	if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CURSED_EYE) then
		local mult = math.floor(charge) - 1
		local bk = auxi.deepCopy(ret)
		for i = 1,mult do
			for u,v in pairs(bk) do
				table.insert(ret,{dir = v.dir,Posoffset = function(dir) return dir * (-10) * i end,})
			end
		end
	end
	local backdir = 0
	if multi_info and multi_info.sideways then
		table.insert(ret,#ret + 1,{dir = -90,Ignore = true})
		table.insert(ret,#ret + 1,{dir = 90,Ignore = true})
		backdir = backdir + 1
	elseif (list.loki or 0) > 0 then 
		if auxi.check_rand(player.Luck,100,3,15) then
			table.insert(ret,#ret + 1,{dir = -90,Ignore = true})
			table.insert(ret,#ret + 1,{dir = 90,Ignore = true})
			backdir = backdir + 1
		end
	end
	if multi_info and multi_info.backwards then backdir = backdir + 1
	elseif (list.momeye or 0) > 0 then if auxi.check_rand(player.Luck,100,10,5) then backdir = backdir + 1 end end
	for i = 1,backdir do table.insert(ret,#ret + 1,{dir = -180 -(backdir-1)/2 * inv3 + (i-1) * inv3,Ignore = true,}) end
	if (list.pencil or 0) > 0 then
		d["Player_Anna_Pencil_counter"] = (d["Player_Anna_Pencil_counter"] or 0) + 1
		if d["Player_Anna_Pencil_counter"] >= 7 then 
			d["Player_Anna_Pencil_counter"] = 0
			for i = 1,4 do table.insert(ret,#ret + 1,{dir = -50 + i * 20,Ignore = true}) end
		end
	end
	if (list.immu or 0) > 0 then if auxi.check_rand(player.Luck,30,10,5) then table.insert(ret,#ret + 1,{dir = 0,shotspeed = 5,tearflag = BitSet128(0,1<<(69-64)),}) end end
	if (list.greed_head or 0) > 0 then 
		d["Player_Anna_Greed_head_counter"] = (d["Player_Anna_Greed_head_counter"] or 0) + 1
		if d["Player_Anna_Greed_head_counter"] >= 10 then
			table.insert(ret,#ret + 1,{dir = 0,Posoffset = function(dir) return auxi.get_by_rotate(dir,90,-5) end,shotspeed = 5,tearflag = BitSet128(1<<53,0),color = Color(1,0.69,0,1,1,0.69,0),Function = function(_,player)
				player:AddCoins(-1)
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_CASH_REGISTER,1,1,false,0,2)
			end,})
			d["Player_Anna_Greed_head_counter"] = 0
		end
	end
	local multitar = 0
	--if (list.lung or 0) > 0 then for i = 1,list.lung do multitar = multitar + math.random(8) + 5 end end
	if multi_info then
		multitar = multitar + (multi_info.randomDirTears or 0)
	elseif (list.eye or 0) > 0 then
		for i = 1,list.eye do multitar = multitar + math.random(2) + 1 end
	end
	for i = 1,multitar do table.insert(ret,#ret + 1,{dir = math.random(360),Ignore = true,}) end
	table.sort(ret,function(a,b) if a.Ignore ~= true and b.Ignore then return true end end)
	return ret
end

local anna_cnt_list = {
	{frame = 1,cnt = 0,},
	{frame = 2,cnt = 40,},
	{frame = 4,cnt = 80,},
	{frame = 8,cnt = 120,},
	{frame = 16,cnt = 160,},
}

function calc.step_faster(cnt)		--加速旋转
	if cnt <= 2 then return 1 end
	return math.ceil(math.sqrt(cnt))
end

local cascade_info = {}
function calc.get_cascade_info(i,tot)
	cascade_info[tot] = cascade_info[tot] or {}
	if cascade_info[tot] and cascade_info[tot][i] then return cascade_info[tot][i] end
	local mmxn = tot
	local ret = {row = 1,col = 1,low = 1,}
	local mcnt = 1
	local id = i
	while(id > mcnt) do
		ret.col = ret.col + 1
		id = id - mcnt
		mmxn = mmxn - mcnt
		mcnt = mcnt + 2
		if mmxn < mcnt * 2 + 2 then mcnt = mmxn break end
	end
	ret.row = id
	ret.low = mcnt
	cascade_info[tot][i] = ret
	return ret
end

function calc.get_Anna2_multishots(player,list,params)
	params = params or {}
	local d = player:GetData()
	list = list or calc.get_Anna_list(player)
	local cnt1,multi_info = get_vanilla_multishot_count(player,params,1,params.notallowrand ~= true,list.wiz)
	local cnt2 = params.cnt2 or (multi_info and multi_info.numEyes) or (list.wiz + 1)
	local cnt3 = 0
	local charge = params.charge or 1
	if player:HasPlayerForm(PlayerForm.PLAYERFORM_BABY) then cnt3 = 1 end
	local ret = {main = {},phantom = {},}
	local cnt = math.ceil(cnt1/cnt2)
	if cnt3 == 1 and cnt2 == 1 then cnt = math.ceil((cnt1-2)/cnt2) end
	if cnt2 > 2 then cnt3 = 0 end
	local dir = 180 /(cnt2+1)
	local inv1 = 30
	local inv2 = math.min(1 + 120/cnt,5 + cnt)
	local inv3 = 5
	local rnd = auxi.random_1() * 360
	local col = 1
	if cnt3 == 1 then			--存在宝宝套
		if cnt2 == 1 then		--单弹道
			table.insert(ret.phantom,#ret.phantom + 1,{dir = -45,})
			table.insert(ret.phantom,#ret.phantom + 1,{dir = 45,})
			--for i = 1,cnt do table.insert(ret.main,#ret.main + 1,{dir = -(cnt-1)/2 * inv3 + (i-1) * inv3,}) end
			for i = cnt,1,-1 do 
				local ccinfo = calc.get_cascade_info(i,cnt) if ccinfo.col ~= col then rnd = auxi.random_1() * 360 col = ccinfo.col end
				table.insert(ret.main,#ret.main + 1,{dir = 0,leg = auxi.get_by_rotate(nil,rnd + calc.step_faster(ccinfo.low) * 360 * ccinfo.row/ccinfo.low,auxi.check_lerp(ccinfo.col,anna_cnt_list).cnt),}) 
			end
		else					--巫师帽
			for i = cnt,1,-1 do 
				local ccinfo = calc.get_cascade_info(i,cnt) if ccinfo.col ~= col then rnd = auxi.random_1() * 360 col = ccinfo.col end
				table.insert(ret.main,#ret.main + 1,{dir = 45,leg = auxi.get_by_rotate(nil,rnd + calc.step_faster(ccinfo.low) * 360 * ccinfo.row/ccinfo.low,auxi.check_lerp(ccinfo.col,anna_cnt_list).cnt),}) end
			for i = cnt,1,-1 do 
				local ccinfo = calc.get_cascade_info(i,cnt) if ccinfo.col ~= col then rnd = auxi.random_1() * 360 col = ccinfo.col end
				table.insert(ret.main,#ret.main + 1,{dir = -45,leg = auxi.get_by_rotate(nil,rnd + calc.step_faster(ccinfo.low) * 360 * ccinfo.row/ccinfo.low,auxi.check_lerp(ccinfo.col,anna_cnt_list).cnt),}) end
		end
	else
		if cnt2 ~= 1 then for j = 1,cnt2 do for i = cnt,1,-1 do 
			local ccinfo = calc.get_cascade_info(i,cnt) if ccinfo.col ~= col then rnd = auxi.random_1() * 360 col = ccinfo.col end
			table.insert(ret.main,#ret.main + 1,{dir = j * dir - 90,leg = auxi.get_by_rotate(nil,rnd + calc.step_faster(ccinfo.low) * 360 * ccinfo.row/ccinfo.low,auxi.check_lerp(ccinfo.col,anna_cnt_list).cnt),}) end end
		else for j = 1,cnt2 do for i = cnt,1,-1 do 
			local ccinfo = calc.get_cascade_info(i,cnt) if ccinfo.col ~= col then rnd = auxi.random_1() * 360 col = ccinfo.col end
			table.insert(ret.main,#ret.main + 1,{dir = j * dir - 90,leg = auxi.get_by_rotate(nil,rnd + calc.step_faster(ccinfo.low) * 360 * ccinfo.row/ccinfo.low,auxi.check_lerp(ccinfo.col,anna_cnt_list).cnt),}) end end end
	end
	if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CURSED_EYE) then
		local mult = math.floor(charge) - 1
		ret.phantom.mult = mult
	end
	local backdir = 0
	if multi_info and multi_info.sideways then
		table.insert(ret.phantom,#ret.phantom + 1,{dir = -90,Ignore = true})
		table.insert(ret.phantom,#ret.phantom + 1,{dir = 90,Ignore = true})
		backdir = backdir + 1
	elseif (list.loki or 0) > 0 then 
		if auxi.check_rand(player.Luck,100,3,15) then
			table.insert(ret.phantom,#ret.phantom + 1,{dir = -90,Ignore = true})
			table.insert(ret.phantom,#ret.phantom + 1,{dir = 90,Ignore = true})
			backdir = backdir + 1
		end
	end
	if multi_info and multi_info.backwards then backdir = backdir + 1
	elseif (list.momeye or 0) > 0 then if auxi.check_rand(player.Luck,100,10,5) then backdir = backdir + 1 end end
	for i = 1,backdir do table.insert(ret.phantom,#ret.phantom + 1,{dir = -180 -(backdir-1)/2 * inv3 + (i-1) * inv3,Ignore = true,}) end
	if (list.pencil or 0) > 0 then
		d["Player_Anna_Pencil_counter"] = (d["Player_Anna_Pencil_counter"] or 0) + 1
		if d["Player_Anna_Pencil_counter"] >= 7 then 
			d["Player_Anna_Pencil_counter"] = 0
			for i = 1,4 do table.insert(ret.phantom,#ret.phantom + 1,{dir = -50 + i * 20,Ignore = true}) end
		end
	end
	if (list.immu or 0) > 0 then if auxi.check_rand(player.Luck,30,10,5) then table.insert(ret.phantom,#ret.phantom + 1,{dir = 0,legmul = auxi.random_1(),tearflag = BitSet128(0,1<<(69-64)),color = Color(1,1,1,0.5,0.2,0.2,0.2),}) end end
	if (list.greed_head or 0) > 0 then 
		d["Player_Anna_Greed_head_counter"] = (d["Player_Anna_Greed_head_counter"] or 0) + 1
		if d["Player_Anna_Greed_head_counter"] >= 5 then
			table.insert(ret.phantom,#ret.phantom + 1,{dir = 0,tearflag = BitSet128(1<<53,0),color = Color(1,0.69,0,0.5,1,0.69,0),Function = function(_,player)
				player:AddCoins(-1)
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_CASH_REGISTER,1,1,false,0,2)
			end,})
			d["Player_Anna_Greed_head_counter"] = 0
		end
	end
	local multitar = 0
	local weap = params.weapon or auxi.get_weapon(player)
	if (list.lung or 0) > 0 then for i = 1,list.lung do 
		if weap == 7 then multitar = multitar + math.floor(charge * (math.random(8) + 5)) 
		else multitar = multitar + math.floor(charge * (math.random(5) + 1))  end
	end end
	if multi_info then
		multitar = multitar + (multi_info.randomDirTears or 0)
	elseif (list.eye or 0) > 0 then
		for i = 1,list.eye do multitar = multitar + math.random(2) + 1 end
	end
	for i = 1,multitar do table.insert(ret.phantom,#ret.phantom + 1,{dir = math.random(360),legmul = auxi.random_1(),Ignore = true,}) end
	--ret.main = auxi.randomTable(ret.main)
	return ret
end


function calc.get_Tecro_list(player)
	player = player or Game():GetPlayer(0)
	local tab = {		--重要道具数量
		brimstone = player:GetCollectibleNum(118),
		tech = player:GetCollectibleNum(68),
		techX = player:GetCollectibleNum(395),
		knife = player:GetCollectibleNum(114),
		lung = player:GetCollectibleNum(229),
		wiz = player:GetCollectibleNum(358),
		eye = player:GetCollectibleNum(558),
		dr = player:GetCollectibleNum(52),
		epic = player:GetCollectibleNum(168),
		sword = player:GetCollectibleNum(579),
		ludo = player:GetCollectibleNum(329),
		sec = player:GetCollectibleNum(678),
		
		pencil = player:GetCollectibleNum(444),
		loki = player:GetCollectibleNum(87),
		momeye = player:GetCollectibleNum(55),
		immu = player:GetCollectibleNum(573),
		greed_head = player:GetCollectibleNum(450),
		
		cho = player:GetCollectibleNum(69),
		soy = player:GetCollectibleNum(330),
		soy2 = player:GetCollectibleNum(561),
		nepton = player:GetCollectibleNum(597),
		
		tech2 = player:GetCollectibleNum(152),
		tech_5 = player:GetCollectibleNum(244),
		redfire = player:GetCollectibleNum(616),
		bluefire = player:GetCollectibleNum(495),
		
		godhead = player:GetCollectibleNum(331),
		--tri = player:GetCollectibleNum(533),
		--pol = player:GetCollectibleNum(169),
		--paraegg = player:GetCollectibleNum(461),
		--ice = player:GetCollectibleNum(596),
		--coal = player:GetCollectibleNum(132),
		--pro = player:GetCollectibleNum(261),
		--hae = player:GetCollectibleNum(531),
		anti = player:GetCollectibleNum(222),
		ipec = player:GetCollectibleNum(149),
		occu = player:GetCollectibleNum(572),
		deadeye = player:GetCollectibleNum(373),
		wavereye = player:GetCollectibleNum(enums.Items.Wavering_Eyes),
		--divi = player:GetCollectibleNum(453) + player:GetCollectibleNum(224) + player:GetCollectibleNum(104),
		tech_0 = player:GetCollectibleNum(524),
		--tech9 = player:GetCollectibleNum(enums.Items.Tech_9),
		--poision = player:GetCollectibleNum(103) + player:GetCollectibleNum(305) + player:GetCollectibleNum(393),
		--slow = player:GetCollectibleNum(89),
		--freeze = player:GetCollectibleNum(110),
		--charm = player:GetCollectibleNum(200),
		--confuse = player:GetCollectibleNum(201),
		--godflesh = player:GetCollectibleNum(398),
		--glaucoma = player:GetCollectibleNum(460),
		sulfur = player:GetCollectibleNum(463),
		rock = player:GetCollectibleNum(592),
		--ledo = player:GetCollectibleNum(617),
		--rotten_tomato = player:GetCollectibleNum(618),
		--rift = player:GetCollectibleNum(606),
		--tar = player:GetCollectibleNum(231),
		--horn = player:GetCollectibleNum(503),
		--ladd = player:GetCollectibleNum(494),
		--keeper_head = player:GetCollectibleNum(429),
		--holy_light = player:GetCollectibleNum(374),
		--euthanasia = player:GetCollectibleNum(496),
		--fist = player:GetCollectibleNum(637),
		--planet = player:GetCollectibleNum(233),
		--fear = player:GetCollectibleNum(259) + player:GetCollectibleNum(230),
		assassin = player:GetCollectibleNum(enums.Items.Assassin_s_Eye),
		
		--repel_effect = math.max(-10,(player:GetCollectibleNum(4) + player:GetCollectibleNum(309) + player:GetCollectibleNum(359)) * 4 - player:GetCollectibleNum(330) * 6 - 3 + player.TearRange/200),
		--larger = player:GetCollectibleNum(659) + player:GetCollectibleNum(336) + player:GetCollectibleNum(309),
		birthright = player:GetCollectibleNum(619),
		
		--urn = player:GetCollectibleNum(640),
		krampus = player:GetCollectibleNum(293),
		damo = player:GetCollectibleNum(577) + player:GetCollectibleNum(656),
		--dual = player:GetCollectibleNum(498) + player:GetCollectibleNum(304),
		--finger = player:GetCollectibleNum(467),
		--spear = player:GetCollectibleNum(400),
		--backstab = player:GetCollectibleNum(506) + player:GetCollectibleNum(enums.Items.Assassin_s_Eye),
		--bone = player:GetCollectibleNum(453) + player:GetCollectibleNum(544) + player:GetCollectibleNum(549) + player:GetCollectibleNum(541) + player:GetCollectibleNum(542) + player:GetCollectibleNum(548) + player:GetCollectibleNum(683),
		--bloody = player:GetCollectibleNum(157) + player:GetCollectibleNum(695) + player:GetCollectibleNum(411) + player:GetCollectibleNum(614) + player:GetCollectibleNum(724) + player:GetCollectibleNum(214) + player:GetCollectibleNum(254) + player:GetCollectibleNum(531) + player:GetCollectibleNum(475) * 3,
		--holy = player:GetCollectibleNum(313) + player:GetCollectibleNum(178) + player:GetCollectibleNum(184) + player:GetCollectibleNum(374),
		--eye_ball = player:GetCollectibleNum(558) + player:GetCollectibleNum(529) * 2 + player:GetCollectibleNum(261) + player:GetCollectibleNum(410) + player:GetCollectibleNum(462),
		--dea = player:GetCollectibleNum(237) + player:GetCollectibleNum(446),
		--lemon = player:GetCollectibleNum(56) + player:GetCollectibleNum(578),
		--onlaser = player:GetCollectibleNum(524) + player:GetCollectibleNum(68) + player:GetCollectibleNum(152) + player:GetCollectibleNum(244) + player:GetCollectibleNum(494),
		--saga = player:GetCollectibleNum(enums.Items.Squiresaga),
	}
	local save = auxi.get_save()
	local idx = player:GetData().__Index
	if (save.elses.Tecro_ludo_buff or {})[idx] then tab.ludo = tab.ludo - 1 end
	if (save.elses.Tecro_knife_buff or {})[idx] then tab.knife = tab.knife - 1 end
	return tab
end

function calc.get_Anna_list(player)
	player = player or Game():GetPlayer(0)
	local tab = {		--重要道具数量
		brimstone = player:GetCollectibleNum(118),
		tech = player:GetCollectibleNum(68),
		techX = player:GetCollectibleNum(395),
		knife = player:GetCollectibleNum(114),
		lung = player:GetCollectibleNum(229),
		wiz = player:GetCollectibleNum(358),
		eye = player:GetCollectibleNum(558),
		dr = player:GetCollectibleNum(52),
		epic = player:GetCollectibleNum(168),
		sword = player:GetCollectibleNum(579),
		ludo = player:GetCollectibleNum(329),
		sec = player:GetCollectibleNum(678),
		
		pencil = player:GetCollectibleNum(444),
		loki = player:GetCollectibleNum(87),
		momeye = player:GetCollectibleNum(55),
		immu = player:GetCollectibleNum(573),
		greed_head = player:GetCollectibleNum(450),
		
		cho = player:GetCollectibleNum(69),
		soy = player:GetCollectibleNum(330),
		soy2 = player:GetCollectibleNum(561),
		nepton = player:GetCollectibleNum(597),
		
		tech2 = player:GetCollectibleNum(152),
		tech_5 = player:GetCollectibleNum(244),
		redfire = player:GetCollectibleNum(616),
		bluefire = player:GetCollectibleNum(495),
		
		--godhead = player:GetCollectibleNum(331),
		--tri = player:GetCollectibleNum(533),
		--pol = player:GetCollectibleNum(169),
		--paraegg = player:GetCollectibleNum(461),
		--ice = player:GetCollectibleNum(596),
		--coal = player:GetCollectibleNum(132),
		--pro = player:GetCollectibleNum(261),
		--hae = player:GetCollectibleNum(531),
		anti = player:GetCollectibleNum(222),
		ipec = player:GetCollectibleNum(149),
		--occu = player:GetCollectibleNum(572),
		--deadeye = player:GetCollectibleNum(373),
		--wavereye = player:GetCollectibleNum(enums.Items.Wavering_Eyes),
		--divi = player:GetCollectibleNum(453) + player:GetCollectibleNum(224) + player:GetCollectibleNum(104),
		--tech_0 = player:GetCollectibleNum(524),
		--tech9 = player:GetCollectibleNum(enums.Items.Tech_9),
		--poision = player:GetCollectibleNum(103) + player:GetCollectibleNum(305) + player:GetCollectibleNum(393),
		--slow = player:GetCollectibleNum(89),
		--freeze = player:GetCollectibleNum(110),
		--charm = player:GetCollectibleNum(200),
		--confuse = player:GetCollectibleNum(201),
		--godflesh = player:GetCollectibleNum(398),
		--glaucoma = player:GetCollectibleNum(460),
		sulfur = player:GetCollectibleNum(463),
		rock = player:GetCollectibleNum(592),
		--ledo = player:GetCollectibleNum(617),
		--rotten_tomato = player:GetCollectibleNum(618),
		--rift = player:GetCollectibleNum(606),
		--tar = player:GetCollectibleNum(231),
		--horn = player:GetCollectibleNum(503),
		--ladd = player:GetCollectibleNum(494),
		--keeper_head = player:GetCollectibleNum(429),
		--holy_light = player:GetCollectibleNum(374),
		--euthanasia = player:GetCollectibleNum(496),
		--fist = player:GetCollectibleNum(637),
		--planet = player:GetCollectibleNum(233),
		--fear = player:GetCollectibleNum(259) + player:GetCollectibleNum(230),
		--assassin = player:GetCollectibleNum(enums.Items.Assassin_s_Eye),
		
		--repel_effect = math.max(-10,(player:GetCollectibleNum(4) + player:GetCollectibleNum(309) + player:GetCollectibleNum(359)) * 4 - player:GetCollectibleNum(330) * 6 - 3 + player.TearRange/200),
		--larger = player:GetCollectibleNum(659) + player:GetCollectibleNum(336) + player:GetCollectibleNum(309),
		--birthright = player:GetCollectibleNum(619),
		
		--urn = player:GetCollectibleNum(640),
		--krampus = player:GetCollectibleNum(293),
		--damo = player:GetCollectibleNum(577) + player:GetCollectibleNum(656),
		--dual = player:GetCollectibleNum(498) + player:GetCollectibleNum(304),
		--finger = player:GetCollectibleNum(467),
		--spear = player:GetCollectibleNum(400),
		--backstab = player:GetCollectibleNum(506) + player:GetCollectibleNum(enums.Items.Assassin_s_Eye),
		--bone = player:GetCollectibleNum(453) + player:GetCollectibleNum(544) + player:GetCollectibleNum(549) + player:GetCollectibleNum(541) + player:GetCollectibleNum(542) + player:GetCollectibleNum(548) + player:GetCollectibleNum(683),
		--bloody = player:GetCollectibleNum(157) + player:GetCollectibleNum(695) + player:GetCollectibleNum(411) + player:GetCollectibleNum(614) + player:GetCollectibleNum(724) + player:GetCollectibleNum(214) + player:GetCollectibleNum(254) + player:GetCollectibleNum(531) + player:GetCollectibleNum(475) * 3,
		--holy = player:GetCollectibleNum(313) + player:GetCollectibleNum(178) + player:GetCollectibleNum(184) + player:GetCollectibleNum(374),
		--eye_ball = player:GetCollectibleNum(558) + player:GetCollectibleNum(529) * 2 + player:GetCollectibleNum(261) + player:GetCollectibleNum(410) + player:GetCollectibleNum(462),
		--dea = player:GetCollectibleNum(237) + player:GetCollectibleNum(446),
		--lemon = player:GetCollectibleNum(56) + player:GetCollectibleNum(578),
		--onlaser = player:GetCollectibleNum(524) + player:GetCollectibleNum(68) + player:GetCollectibleNum(152) + player:GetCollectibleNum(244) + player:GetCollectibleNum(494),
		--saga = player:GetCollectibleNum(enums.Items.Squiresaga),
	}
	local save = auxi.get_save()
	local idx = player:GetData().__Index
	if (save.elses.Anna_ludo_buff or {})[idx] then tab.ludo = tab.ludo - 1 end
	if (save.elses.Anna_knife_buff or {})[idx] then tab.knife = tab.knife - 1 end
	return tab
end


function calc.get_qing_list(player)
	if player == nil then player = Game():GetPlayer(0) end
	local tab = {		--重要道具数量
		brimstone = player:GetCollectibleNum(118),
		tech = player:GetCollectibleNum(68),
		techX = player:GetCollectibleNum(395),
		knife = player:GetCollectibleNum(114),
		lung = player:GetCollectibleNum(229),
		dr = player:GetCollectibleNum(52),
		epic = player:GetCollectibleNum(168),
		sword = player:GetCollectibleNum(579),
		ludo = player:GetCollectibleNum(329),
		pol = player:GetCollectibleNum(169),
		immu = player:GetCollectibleNum(573),
		cho = player:GetCollectibleNum(69),
		soy = player:GetCollectibleNum(330),
		soy2 = player:GetCollectibleNum(561),
		para = player:GetCollectibleNum(461),
		damo = player:GetCollectibleNum(577) + player:GetCollectibleNum(656),
		ice = player:GetCollectibleNum(596),
		dual = player:GetCollectibleNum(498) + player:GetCollectibleNum(304),
		redfire = player:GetCollectibleNum(616),
		bluefire = player:GetCollectibleNum(495),
		loki = player:GetCollectibleNum(87),
		momeye = player:GetCollectibleNum(55),
		wiz = player:GetCollectibleNum(358),
		eye = player:GetCollectibleNum(558),
		coal = player:GetCollectibleNum(132),
		pro = player:GetCollectibleNum(261),
		hae = player:GetCollectibleNum(531),
		sec = player:GetCollectibleNum(678),
		ipec = player:GetCollectibleNum(149),
		deadeye = player:GetCollectibleNum(373),
		wavereye = player:GetCollectibleNum(enums.Items.Wavering_Eyes),
		finger = player:GetCollectibleNum(467),
		spear = player:GetCollectibleNum(400),
		backstab = player:GetCollectibleNum(506) + player:GetCollectibleNum(enums.Items.Assassin_s_Eye),
		divi = player:GetCollectibleNum(453) + player:GetCollectibleNum(224) + player:GetCollectibleNum(104),
		godhead = player:GetCollectibleNum(331),
		repel_effect = math.max(-10,(player:GetCollectibleNum(4) + player:GetCollectibleNum(309) + player:GetCollectibleNum(359)) * 4 - player:GetCollectibleNum(330) * 6 - 3 + player.TearRange/200),
		tri = player:GetCollectibleNum(533),
		bone = player:GetCollectibleNum(453) + player:GetCollectibleNum(544) + player:GetCollectibleNum(549) + player:GetCollectibleNum(541) + player:GetCollectibleNum(542) + player:GetCollectibleNum(548) + player:GetCollectibleNum(683),
		bloody = player:GetCollectibleNum(157) + player:GetCollectibleNum(695) + player:GetCollectibleNum(411) + player:GetCollectibleNum(614) + player:GetCollectibleNum(724) + player:GetCollectibleNum(214) + player:GetCollectibleNum(254) + player:GetCollectibleNum(531) + player:GetCollectibleNum(475) * 3,
		holy = player:GetCollectibleNum(313) + player:GetCollectibleNum(178) + player:GetCollectibleNum(184) + player:GetCollectibleNum(374),
		eye_ball = player:GetCollectibleNum(558) + player:GetCollectibleNum(529) * 2 + player:GetCollectibleNum(261) + player:GetCollectibleNum(410) + player:GetCollectibleNum(462),
		dea = player:GetCollectibleNum(237) + player:GetCollectibleNum(446),
		pencil = player:GetCollectibleNum(444),
		poision = player:GetCollectibleNum(103) + player:GetCollectibleNum(305) + player:GetCollectibleNum(393),
		slow = player:GetCollectibleNum(89),
		freeze = player:GetCollectibleNum(110),
		charm = player:GetCollectibleNum(200),
		confuse = player:GetCollectibleNum(201),
		godflesh = player:GetCollectibleNum(398),
		glaucoma = player:GetCollectibleNum(460),
		sulfur = player:GetCollectibleNum(463),
		lemon = player:GetCollectibleNum(56) + player:GetCollectibleNum(578),
		ledo = player:GetCollectibleNum(617),
		rotten_tomato = player:GetCollectibleNum(618),
		link_knife = player:GetCollectibleNum(enums.Items.Touchstone),
		rift = player:GetCollectibleNum(606),
		tar = player:GetCollectibleNum(231),
		horn = player:GetCollectibleNum(503),
		onlaser = player:GetCollectibleNum(524) + player:GetCollectibleNum(68) + player:GetCollectibleNum(152) + player:GetCollectibleNum(244) + player:GetCollectibleNum(494),
		should_on_laser = player:GetCollectibleNum(524),
		ladd = player:GetCollectibleNum(494),
		keeper_head = player:GetCollectibleNum(429),
		greed_head = player:GetCollectibleNum(450),
		holy_light = player:GetCollectibleNum(374),
		rock = player:GetCollectibleNum(592),
		euthanasia = player:GetCollectibleNum(496),
		nipton = player:GetCollectibleNum(597) + player:GetCollectibleNum(308),
		fist = player:GetCollectibleNum(637),
		fear = player:GetCollectibleNum(259) + player:GetCollectibleNum(230),
		larger = player:GetCollectibleNum(659) + player:GetCollectibleNum(336) + player:GetCollectibleNum(309),
		tech9 = player:GetCollectibleNum(enums.Items.Tech_9),
		saga = player:GetCollectibleNum(enums.Items.Squiresaga),
	}
	local idx = player:GetData().__Index
	local save = auxi.get_save()
	if (save.elses.Qing_ludo_buff or {})[idx] then tab.ludo = tab.ludo - 1 end
	if (save.elses.Qing_knife_buff or {})[idx] then tab.knife = tab.knife - 1 end
	return tab
end

function calc.get_epic_list(player)
	local ret = {
		brimstone = player:GetCollectibleNum(118),
		tech = player:GetCollectibleNum(68),
		techX = player:GetCollectibleNum(395),
		knife = player:GetCollectibleNum(114),
		NumRockets = calc.getmultishots(player,true),
	}
	return ret
end

return calc

