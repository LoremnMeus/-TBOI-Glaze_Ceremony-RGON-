local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	challange = enums.Challenges.Invisible,
	own_key = "Challange_Invisible_",
	room_counter = Color(1, 1, 1, 1),
	trail = {},
	trail_radius = 80,
	reveal_frames = 90,
}

local function in_dark_arts(player)
	if not player then return false end
	local effects = player:GetEffects()
	if effects and effects:HasCollectibleEffect(CollectibleType.COLLECTIBLE_DARK_ARTS) then
		return true
	end
	local ok, playing = pcall(function()
		return player:GetSprite():IsPlaying("DarkArts")
	end)
	return ok and playing == true
end

local function prune_trail(now)
	local keep = {}
	for i = 1, #item.trail do
		local node = item.trail[i]
		if node and now <= (node.until_frame or 0) then
			keep[#keep + 1] = node
		end
	end
	item.trail = keep
end

local function near_trail(pos)
	for i = 1, #item.trail do
		local node = item.trail[i]
		if node and (pos - node.pos):Length() <= item.trail_radius then
			return true
		end
	end
	return false
end

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	if Game().Challenge == item.challange then
		item.room_counter = Color(1, 1, 1, 1)
		item.trail = {}
	end
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	if Game().Challenge ~= item.challange then return end
	if not in_dark_arts(player) then return end
	local now = Game():GetFrameCount()
	item.trail[#item.trail + 1] = {
		pos = Vector(player.Position.X, player.Position.Y),
		until_frame = now + 8,
	}
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if Game().Challenge ~= item.challange then return end
	local now = Game():GetFrameCount()
	prune_trail(now)
	local n_entity = Isaac.GetRoomEntities()
	for _, v in pairs(n_entity) do
		local d = v:GetData()
		if near_trail(v.Position) then
			d[item.own_key.."reveal"] = now + item.reveal_frames
		end
		local s = v:GetSprite()
		local revealed = (d[item.own_key.."reveal"] or 0) > now
		if revealed then
			s.Color = auxi.AddColor(s.Color, Color(1, 1, 1, 1), 0.65, 0.35)
		else
			s.Color = auxi.AddColor(s.Color, Color(1, 1, 1, 0), 0.9, 0.1)
		end
	end
	local room = Game():GetRoom()
	if item.room_counter == nil then item.room_counter = Color(1, 1, 1, 1) end
	local floor_revealed = false
	for i = 0, Game():GetNumPlayers() - 1 do
		if in_dark_arts(Game():GetPlayer(i)) then
			floor_revealed = true
			break
		end
	end
	if floor_revealed then
		item.room_counter = auxi.AddColor(item.room_counter, Color(1, 1, 1, 0.85), 0.7, 0.3)
	else
		item.room_counter = auxi.AddColor(item.room_counter, Color(1, 1, 1, 0), 0.9, 0.1)
	end
	room:SetFloorColor(item.room_counter)
	room:SetWallColor(item.room_counter)
	for i = 0, room:GetGridSize() - 1 do
		local grid = room:GetGridEntity(i)
		if grid then
			local s = grid:GetSprite()
			if s then
				local pos = room:GetGridPosition(i)
				if near_trail(pos) then
					s.Color = auxi.AddColor(s.Color, Color(1, 1, 1, 1), 0.65, 0.35)
				else
					s.Color = auxi.AddColor(s.Color, Color(1, 1, 1, 0), 0.9, 0.1)
				end
			end
		end
	end
end,
})

return item
