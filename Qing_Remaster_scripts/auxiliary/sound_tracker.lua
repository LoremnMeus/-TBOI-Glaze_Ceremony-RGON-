local g = require("Qing_Remaster_scripts.core.globals")
local enums = require("Qing_Remaster_scripts.core.enums")
local sound_tracker = {}

local SFX_CACHE = {}
local SFX_CACHE_INDEX = 1
for i=1,16,1 do
	SFX_CACHE[i] = SFXManager()
end

function sound_tracker.PlayStackedSound(id, volume, pitch, loop, pan, frameDelay)		--pan似乎是左右声道，-1,0,1
	if id ~= nil then
		if frameDelay == nil then frameDelay = 2 end
		SFX_CACHE[SFX_CACHE_INDEX]:Play(id, volume, frameDelay, loop, pitch, pan)
		SFX_CACHE_INDEX = SFX_CACHE_INDEX + 1
		if SFX_CACHE_INDEX > #SFX_CACHE then
			SFX_CACHE_INDEX = 1
		end
	end
end

--l SFXManager():Play(7, 1, 1, false, 1, 0)

return sound_tracker