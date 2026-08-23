local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
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

local HUD_ANIM = "Glazed Dice Shard"
local HUD_ANIM_LEN = 36
local hud_spr = nil
local hud_anim_logic_frame = -1
local default_hidden = false

local function ensure_hud_spr()
	if hud_spr == nil then
		hud_spr = Sprite()
		hud_spr:Load("gfx/ui/content/ui_cardfronts.anm2", true)
	end
	return hud_spr
end

local function sync_hud_anim(spr)
	local logic_frame = Game():GetFrameCount()
	if hud_anim_logic_frame == logic_frame then return end
	hud_anim_logic_frame = logic_frame
	spr:SetFrame(HUD_ANIM, logic_frame % HUD_ANIM_LEN)
end

local function set_default_hidden(hidden)
	if not REPENTOGON then return end
	local cfg = Isaac.GetItemConfig():GetCard(item.pickup)
	local front = cfg and cfg.ModdedCardFront
	if front == nil then return end
	if hidden then
		front:Stop()
		front:SetFrame(HUD_ANIM, 0)
		front.PlaybackSpeed = 0
		front.Scale = Vector(0, 0)
		front.Color = Color(1, 1, 1, 0)
	else
		front.PlaybackSpeed = 1
		front.Scale = Vector(1, 1)
		front.Color = Color(1, 1, 1, 1)
	end
	default_hidden = hidden
end

local function player_dice_slots(player)
	local slots = {}
	if player == nil or player.Parent then return slots end
	if player.Variant ~= 0 then return slots end
	for slot = 0, 1 do
		if player:GetCard(slot) == item.pickup then
			slots[#slots + 1] = slot
		end
	end
	return slots
end

local function any_player_holds_dice()
	local game = Game()
	for i = 0, game:GetNumPlayers() - 1 do
		local player = game:GetPlayer(i)
		if player and #player_dice_slots(player) > 0 then
			return true
		end
	end
	return false
end

local function card_hud_state(player)
	if auxi.is_double_player() then
		if player:GetPlayerType() == PlayerType.PLAYER_ESAU then
			return 3
		end
		return 2
	end
	return 1
end

local function sprite_snapshot(spr)
	if spr == nil then return nil end
	local col = spr.Color
	local tint = auxi.color2table(col)
	local playing_hud = false
	local playing_any = false
	local finished_hud = false
	pcall(function()
		playing_hud = spr:IsPlaying(HUD_ANIM)
		playing_any = spr:IsPlaying()
		finished_hud = spr:IsFinished(HUD_ANIM)
	end)
	return {
		hash = GetPtrHash(spr),
		anim = spr:GetAnimation(),
		frame = spr:GetFrame(),
		playing_hud = playing_hud,
		playing_any = playing_any,
		finished_hud = finished_hud,
		speed = spr.PlaybackSpeed,
		scale_x = spr.Scale and spr.Scale.X,
		scale_y = spr.Scale and spr.Scale.Y,
		tint_r = tint.R, tint_g = tint.G, tint_b = tint.B, tint_a = tint.A,
		off_r = tint.RO, off_g = tint.GO, off_b = tint.BO,
		cz_r = tint.RC, cz_g = tint.GC, cz_b = tint.BC, cz_a = tint.AC,
	}
end

function item.debug_hud_snapshot()
	local front = nil
	if REPENTOGON then
		local cfg = Isaac.GetItemConfig():GetCard(item.pickup)
		front = cfg and cfg.ModdedCardFront
	end
	local game_frame = Game():GetFrameCount()
	local custom = sprite_snapshot(hud_spr)
	local default_front = sprite_snapshot(front)
	local same_sprite = false
	if custom and default_front then
		same_sprite = custom.hash == default_front.hash
	end
	return {
		holds = any_player_holds_dice(),
		hud_visible = Game():GetHUD():IsVisible(),
		default_hidden = default_hidden,
		logic_latch = hud_anim_logic_frame,
		target_frame = game_frame % HUD_ANIM_LEN,
		anim_len = HUD_ANIM_LEN,
		same_sprite = same_sprite,
		custom = custom,
		default_front = default_front,
	}
end

if REPENTOGON and ModCallbacks.MC_POST_HUD_UPDATE and ModCallbacks.MC_POST_HUD_RENDER then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_HUD_UPDATE, params = nil,
	Function = function(_)
		if any_player_holds_dice() then
			set_default_hidden(true)
		elseif default_hidden then
			set_default_hidden(false)
		end
	end,
	})

	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_HUD_RENDER, params = nil,
	Function = function(_)
		if not Game():GetHUD():IsVisible() then return end
		if not any_player_holds_dice() then return end
		local spr = ensure_hud_spr()
		sync_hud_anim(spr)
		local game = Game()
		for i = 0, game:GetNumPlayers() - 1 do
			local player = game:GetPlayer(i)
			if player then
				local slots = player_dice_slots(player)
				if #slots > 0 then
					local pos = ui.UICardPos(card_hud_state(player))
					for _, slot in ipairs(slots) do
						local draw_pos = pos
						if slot > 0 then
							draw_pos = pos + Vector(-12, 1)
						end
						spr:Render(draw_pos, Vector(0, 0), Vector(0, 0))
					end
				end
			end
		end
	end,
	})

	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
	Function = function(_)
		if default_hidden then set_default_hidden(false) end
	end,
	})
end

return item
