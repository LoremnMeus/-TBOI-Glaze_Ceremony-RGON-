local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local dropping_holder = require("Qing_Remaster_scripts.others.Dropping_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Achievement_Display_holder = require("Qing_Remaster_scripts.others.Achievement_Display_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Fool,
	own_key = "Thoth_cd0_Foo_",
	q2c = {
		[0] = Color(1,1,1,1),
		[1] = Color(0,1,0.5,1),
		[2] = Color(0,0.5,1,1),
		[3] = Color(0.5,0,1,1),
		[4] = Color(1,0.5,0,1),
		[5] = Color(1,0,0,1),
	},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local cnt = 5
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then cnt = 8 end
		local itempool = Game():GetItemPool()
		local config = Isaac:GetItemConfig()
		local typ = itempool:GetPoolForRoom(Game():GetRoom():GetType(),Game():GetLevel():GetCurrentRoomDesc().SpawnSeed)
		if typ == -1 then typ = 0 end
		local mx_col = nil
		for i = 1,cnt do
			local seed = rng:GetSeed()
			local colid = itempool:GetCollectible(typ,true,seed)
			rng:Next()
			--itempool:RemoveCollectible(colid)
			local collectibleinfo = config:GetCollectible(colid)
			if collectibleinfo and (collectibleinfo.Tags & ItemConfig.TAG_SUMMONABLE == ItemConfig.TAG_SUMMONABLE) and (mx_col == nil or config:GetCollectible(mx_col).Quality < collectibleinfo.Quality) then
				mx_col = colid
			end
			local pos = player.Position + auxi.MakeVector(i*360/cnt) * 50
			local color1 = item.q2c[config:GetCollectible(colid).Quality]
			auxi.spawn_item_dust(player,pos,colid,color1,Color(0.1,0.1,0.1,1,0.2,0.2,0.2))
		end
		if mx_col then player:AddItemWisp(mx_col,player.Position,true)
		else player:AnimateSad() end
	end
end,
})


return item