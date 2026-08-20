local g = require("Qing_Remaster_scripts.core.globals")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local GiantBook_holder = require("Qing_Remaster_scripts.others.GiantBook_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")

local item = {
	ToCall = {},
	post_ToCall = {},
}

function item.PlayAchievement(gfxroot,dur)
	local entries = gfxroot
	if type(entries) == "string" then
		entries = {{GfxRoot = entries}}
	elseif type(entries) == "table" and (entries.GfxRoot or entries.Text) then
		entries = {entries}
	end
	for _,entry in ipairs(entries or {}) do
		if type(entry) == "string" then entry = {GfxRoot = entry} end
		GiantBook_holder.PlayGiantBook({GfxRoot = entry.GfxRoot,Text = entry.Text,Duration = entry.Duration or dur or 90,
		work = function(s,info)
			if info.Appear ~= true then
				s:Play("Appear",true)
				info.Appear = true
				if info.GfxRoot then
					s:ReplaceSpritesheet(3,info.GfxRoot)
					s:LoadGraphics()
				end
			end
			if s:IsFinished("Appear") then
				if not info.SoundPlayed then
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOOK_PAGE_TURN_12, 1, 1, false, 0,2)
					info.SoundPlayed = true
				end
				if info.Duration <= 0 then s:Play("Dissapear", true)
				else info.Duration = info.Duration - 1 end
			end
			if s:IsFinished("Dissapear") then return true end
		end,
		render = function(_,info)
			if not info.Text or info.Text == "" then return end
			local lines = {}
			for line in string.gmatch(info.Text,"[^\n]+") do table.insert(lines,line) end
			local scale = 1
			local center = auxi.GetScreenCenter()
			local line_height = 12
			local top = center.Y - (#lines * line_height * scale) / 2
			for index,line in ipairs(lines) do
				local width = gui.f2:GetStringWidthUTF8(line) * scale
				gui.f2:DrawStringScaledUTF8(line,center.X - width / 2,top + (index - 1) * line_height * scale,scale,scale,KColor(0.2,0.12,0.08,1),0,false)
			end
		end,})
	end
end

function item.Is_Finished_playing()
	return GiantBook_holder.Is_Finished_playing()
end

return item
