local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local glaze_curse = require("Qing_Remaster_scripts.pickups.pickup_glaze_curse")
local pickup_glaze_enemy = require("Qing_Remaster_scripts.pickups.pickup_glaze_enemy")
local item_color_holder = require("Qing_Remaster_scripts.others.Item_color_holder")
local glaze_crown = require("Qing_Remaster_scripts.items.Item_Crown_of_the_Glaze")

local item = {
	pickup = enums.Cards.Glaze_dice_shard,
	ToCall = {},
}

local function the_same(c1,c2,rg)
	if c1 - c2 < rg and c2 - c1 < rg then
		return true
	else
		return false
	end
end

local function check_col(idx)
	local s1 = Sprite()
	s1:Load("gfx/effects/nil_effect.anm2",false)
	local itemConfig = Isaac.GetItemConfig()
	local collectible = itemConfig:GetCollectible(idx)
	if (collectible and not collectible.Hidden) then
		local s = itemConfig:GetCollectible(idx).GfxFileName
		s1:ReplaceSpritesheet(0,s)
		s1:LoadGraphics()
		s1:SetFrame("Idle",0)
		local frame = 0
		local cnt = 0
		local cnt2 = 0
		local cnt3 = 0
		local cnt4 = 0
		local red = 0
		local blue = 0
		local green = 0
		for i = -6,6 do
			for j = -6,6 do
				local Kcol = s1:GetTexel(Vector(i,j),Vector(0,0))
				if Kcol.Red < 0.02 and Kcol.Blue < 0.02 and Kcol.Green < 0.02 then	--非颜色
				--	cnt = cnt + 1
				elseif Kcol.Red < 0.04 and Kcol.Blue < 0.02 and Kcol.Green < 0.02 then		--去掉黑色
					cnt = cnt + 1
				elseif Kcol.Red > 0.99 and Kcol.Blue > 0.99 and Kcol.Green > 0.99 then		--去掉白色
					cnt2 = cnt2 + 1
				else
					if the_same(Kcol.Red * 255,Kcol.Blue* 255,5) and the_same(Kcol.Red* 255,Kcol.Green* 255,5) and the_same(Kcol.Blue* 255,Kcol.Green* 255,5) then
						cnt3 = cnt3 + 1
					elseif the_same(Kcol.Red * 255,Kcol.Blue* 255,15) and the_same(Kcol.Red* 255,Kcol.Green* 255,15) and the_same(Kcol.Blue* 255,Kcol.Green* 255,15) then
						cnt3 = cnt3 + 0.75
						frame = frame + 0.25
						red = red + Kcol.Red/4
						blue = blue + Kcol.Blue/4
						green = green + Kcol.Green/4
					elseif the_same(Kcol.Red * 255,Kcol.Blue* 255,50) and the_same(Kcol.Red* 255,Kcol.Green* 255,50) and the_same(Kcol.Blue* 255,Kcol.Green* 255,50) then
						cnt3 = cnt3 + 0.5
						frame = frame + 0.5
						red = red + Kcol.Red/2
						blue = blue + Kcol.Blue/2
						green = green + Kcol.Green/2
					else
						if (Kcol.Red > Kcol.Blue + 80 and Kcol.Red > Kcol.Green + 80) or (Kcol.Blue > Kcol.Red + 80 and Kcol.Blue > Kcol.Green + 80) or (Kcol.Green > Kcol.Blue + 80 and Kcol.Green > Kcol.Red + 80) then
							cnt4 = cnt4 + 1
						end
						frame = frame + 1
						red = red + Kcol.Red
						blue = blue + Kcol.Blue
						green = green + Kcol.Green
					end
				end
			end
		end
		if frame > 0 then
			red = (red * 255)// frame
			blue = (blue * 255) // frame
			green = (green * 255) // frame
		end
		
		--print(tostring(cnt)..tostring(cnt2)..tostring(cnt3)..tostring(frame)..tostring(red)..tostring(blue)..tostring(green))
		if cnt > frame * 2 then
			return "black"
		end
		if cnt2 > frame * 2 then
			return "white"
		end
		if cnt3 > frame * 1.3 then
			return "grey"
		end
		
		if cnt4 < 0.5 * frame and (the_same(red,blue,30) and the_same(blue,green,30) and the_same(red,green,30) and blue + red + green > 255 * 2.5)  then
			return "white"
		end
		if cnt4 < 0.5 * frame and (the_same(red,blue,20) and the_same(blue,green,20) and the_same(red,green,20) and blue + red + green < 255) then
			return "black"
		end
		if cnt4 < 0.5 * frame and (the_same(red,blue,40) and the_same(blue,green,40) and the_same(red,green,40) and blue + red + green < 255 * 2.5 and blue + red + green > 255) then
			return "grey"
		end
		
		if red > 180 and ((red > green + 60 and green > blue + 60) or (red > green + 40 and green > blue + 80) or (red > green + 80 and green > blue + 40)) then
			return "orange"
		end
		if red > 180 and ((red > blue + 60 and blue > green + 60) or (red > blue + 40 and blue > green + 80) or (red > blue + 80 and blue > green + 40)) then
			return "pink"
		end
		if (red > blue + 150 and red > green + 100) or (red > blue + 100 and red > green + 150) or (red > blue + 200 and red > green + 80) or (red > blue + 80 and red > green + 200) or (the_same(green,blue,15) and red > green + 75 and red > blue + 75) then
			return "red"
		end
		if red > blue and the_same(red,blue,20) and (red > green + 80 or blue > green + 80) then
			return "pink"
		end
		if the_same(red,green,20) and (red > blue + 40 and green > blue + 40) and red + green > 400 then
			return "yellow"
		end
		if blue > red and the_same(red,blue,20) and (red > green + 80 or blue > green + 80) then
			return "purple"
		end
		if (green > blue + 40 and green > red + 25) or (green > blue + 25 and green > red + 40) or (green > blue + 60 and green > red + 15) or (green > blue + 15 and green > red + 60) then
			return "green"
		end
		if (blue > red + 40 and blue > green + 25) or (blue > red + 25 and blue > green + 40) or (blue > red + 60 and blue > green + 15) or (blue > red + 15 and blue > green + 60) then
			return "blue"
		end
		
		if the_same(red,blue,20) and (red > green + 40 and blue > green + 40) then
			if red + blue + green > 500 then
				return "pink"
			else
				return "purple"
			end
		end
		if the_same(green,blue,20) and (green > red + 40 and blue > red + 40) then
			return "blue"
		end
		if the_same(red,blue + 40,10) and the_same(red,green + 40,10) then
			return "pink"
		end
		
		if red > 180 and ((red > blue + 50 and blue > green + 50) or (red > blue + 30 and blue > green + 70) or (red > blue + 70 and blue > green + 30)) then
			return "pink"
		end
		if red > green + 20 and green > blue + 20 and blue + red + green > 255 then
			return "bright"
		end
		if red > green + 20 and green > blue + 20 and blue + red + green < 255 then
			return "brown"
		end
		if (red > blue + 60 and red > green + 60) then 
			return "red"
		end
		return "others"
	else
		return "black"
	end
end


table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.pickup,
Function = function(_,card,player,useflags)
	local n_entity = Isaac.GetRoomEntities()
	local n_col = auxi.getothers(n_entity,5,100)
	for col_id = 1,#n_col do
		local rng = n_col[col_id]:GetDropRNG()
		rng = auxi.rng_for_sake(rng)
		local idx = n_col[col_id].SubType
		if idx == 0 then 
		else
			local target = item_color_holder.choose_replacement(idx,rng)
			if not target and not REPENTOGON then
				local label = check_col(idx)
				local pool = item_color_holder.get_pool(label)
				local candidates = {}
				for _,candidate in ipairs(pool) do
					if candidate ~= idx then candidates[#candidates + 1] = candidate end
				end
				if #candidates > 0 then target = candidates[rng:RandomInt(#candidates) + 1] end
			end
			if target then
				n_col[col_id]:ToPickup():Morph(5,100,target,true,false,false)
			end
		end
	end
	local pu = enums.Pickups
	local n_penny = auxi.getothers(n_entity,5,20)
	for i = 1,#n_penny do
		if n_penny[i]:ToPickup().Price ~= -5 then
			auxi.special_morph(n_penny[i],pu.Glaze_coin)
		end
	end
	local n_heart = auxi.getothers(n_entity,5,10)
	for i = 1,#n_heart do
		local rng = n_heart[i]:GetDropRNG()
		if n_heart[i]:ToPickup().Price ~= -5 then
			if rng:RandomInt(10) > 2 then
				auxi.special_morph(n_heart[i],pu.Glaze_heart_half)
			else
				auxi.special_morph(n_heart[i],pu.Glaze_heart)
			end
		end
	end
	local n_key = auxi.getothers(n_entity,5,30)
	for i = 1,#n_key do
		if n_key[i]:ToPickup().Price ~= -5 then
			auxi.special_morph(n_key[i],pu.Glaze_key)
		end
	end
	local n_bomb = auxi.getothers(n_entity,5,40)
	for i = 1,#n_bomb do
		if n_bomb[i]:ToPickup().Price ~= -5 then
			auxi.special_morph(n_bomb[i],pu.Glaze_bomb)
		end
	end
	local n_bag = auxi.getothers(n_entity,5,69)
	for i = 1,#n_bag do
		if n_bag[i]:ToPickup().Price ~= -5 then
			auxi.special_morph(n_bag[i],pu.Glaze_grabbag)
		end
	end
	local n_battery = auxi.getothers(n_entity,5,90)
	for i = 1,#n_battery do
		if n_battery[i]:ToPickup().Price ~= -5 then
			auxi.special_morph(n_battery[i],pu.Glaze_battery)
		end
	end
	local n_poop = auxi.getothers(n_entity,5,42)
	for i = 1,#n_poop do
		if n_poop[i]:ToPickup().Price ~= -5 then
			auxi.special_morph(n_poop[i],pu.Glaze_big_poop)
		end
	end
	local n_chest = auxi.getothers(n_entity,5,nil,nil,
		function(ent)
			if ent.Variant >= 50 and ent.Variant < 69 then 
				return true 
			else 
				return false 
			end 
		end)
	for i = 1,#n_chest do
		auxi.special_morph(n_chest[i],pu.Glaze_chest)
	end
	local n_card = auxi.getothers(n_entity,5,300,item.pickup)
	for i = 1,#n_card do
		auxi.special_morph(n_card[i],pu.Glaze_dice_shard)
	end
	local n_card = auxi.getothers(n_entity,5,300,49)
	for i = 1,#n_card do
		auxi.special_morph(n_card[i],pu.Glaze_dice_shard)
	end
	local n_enemy = auxi.getenemies(n_entity)
	for i = 1,#n_enemy do
		local ent = n_enemy[i]
		if ent:IsVulnerableEnemy() and ent:IsActiveEnemy() and (not ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) and ent:CanShutDoors() == true and ent.Type ~= 996 then
			pickup_glaze_enemy.Make_Glazed_Enemy(ent)
			Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, ent.Position, Vector(0, 0), nil)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_GET_CARD, params = nil,
Function = function(_,rng,card,playing,rune,onlyrune)
	rng = auxi.rng_for_sake(rng)
	local rnd = rng:RandomInt(10)
	local set_true = glaze_crown.has_any()
	if card == item.pickup and set_true == false and rnd > 5 then		--相比于其他卡牌，仅有50%的概率生成，除非角色拥有琉璃的冠冕。
		rng:Next()
		local cd = Game():GetItemPool():GetCard(rng:GetSeed(), playing, rune, onlyrune)
		return cd
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_ADD_CARD, params = nil,
Function = function(_,player,card,slot)
	if card == item.pickup then
		glaze_crown.notify_pickup(player)
	end
end,
})

return item
