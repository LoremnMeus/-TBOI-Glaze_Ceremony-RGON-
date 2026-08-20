local enums = require("Qing_Remaster_scripts.core.enums")

local util = {}

function util.mix32(n)
	n = math.floor(tonumber(n) or 1) % 4294967296
	n = n ~ math.floor(n / 65536)
	n = (n * 2246822519) % 4294967296
	n = n ~ math.floor(n / 8192)
	n = (n * 3266489917) % 4294967296
	n = n ~ math.floor(n / 16)
	if n == 0 then n = 1 end
	return n
end

function util.rng(seed, salt)
	local rng = RNG()
	rng:SetSeed(util.mix32((tonumber(seed) or 1) + (tonumber(salt) or 0)), 35)
	return rng
end

function util.zh()
	return Options.Language == "zh"
end

function util.is_zeiz(player)
	return player and player:GetPlayerType() == enums.Players.Zeiz
end

function util.each_zeiz(fn)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if util.is_zeiz(player) then fn(player) end
	end
end

function util.any_zeiz()
	local found = false
	util.each_zeiz(function() found = true end)
	return found
end

function util.zeiz_player()
	local result = nil
	util.each_zeiz(function(player)
		if result == nil then result = player end
	end)
	return result
end

function util.floor_id()
	local level = Game():GetLevel()
	return (level:GetStage() or 0) * 10 + (level:GetStageType() or 0)
end

function util.room_index()
	return Game():GetLevel():GetCurrentRoomIndex()
end

function util.pickup_id(ent)
	if not ent then return nil end
	local seed = ent.InitSeed
	if seed and seed ~= 0 then return tostring(seed) end
	return tostring(GetPtrHash(ent))
end

return util
