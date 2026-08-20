local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Acrotomophilia,
	own_key = "Item_Acrotomophilia_",
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_BASIC, params = nil,
Function = function(_,player,changetype,count,info1,info2)
	if auxi.has_have_coll(player,item.entity) then
		if player:GetBrokenHearts() > 0 and player:GetRottenHearts() > 0 and string.sub(changetype,-6) == "_heart" then 
			local mincnt = math.min(player:GetBrokenHearts(),player:GetRottenHearts())
			player:AddBrokenHearts(-mincnt)
			player:AddRottenHearts(-mincnt)
			player:AddHearts(-mincnt)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEATH_CARD,1,1,false,0,2)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP,1,1,false,0,2)
			local e1 = Isaac.Spawn(1000,16,2,player.Position,Vector(0,0),player) e1:GetSprite().Color = Color(1,1,1,1,-1,-1,-1)
			local e2 = Isaac.Spawn(1000,16,1,player.Position,Vector(0,0),player) e2:GetSprite().Color = Color(1,1,1,1,-1,-1,-1)
			if auxi.will_die(player) then player:AddHearts(1) end
		end
		if changetype == "rd_heart" and count < 0 then
			local cnt = count - (info1["rt_heart"].counter - info2["rt_heart"].counter) * 2
			if cnt < 0 and not auxi.will_die(player) then 
				if cnt % 2 == 1 and player:GetHearts() % 2 == 0 then cnt = cnt - 1 end
				player:AddRottenHearts(math.floor(-cnt/2))
				player:AddHearts(math.floor(-cnt/2))
				if cnt < -1 then sound_tracker.PlayStackedSound(SoundEffect.SOUND_VAMP_GULP,1,1,false,0,2) end
			end
		end
		if changetype == "mx_heart" then
			if count < 0 then 
				player:AddBrokenHearts(math.floor(-count/2)) 
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_POT_BREAK_2,1,1,false,0,2)
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEATH_CARD,1,1,false,0,2)
			end
		end
	end
end,
})

return item