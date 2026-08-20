local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
}

item.ZeroV = Vector.Zero
item.CenterV = Vector(320, 280)
item.CenterVBig = Vector(640, 560)

item.game = Game()
item.sound = SFXManager()
item.Randomizer = RNG()
item.Randomizer:SetSeed(Random() + 1, 35)
item.ItemConfig = Isaac.GetItemConfig()
item.ItemPool = item.game:GetItemPool()
item.HUD = item.game:GetHUD()

item.TempestaFont = Font()
--item.TempestaFont:Load("font/pftempestasevencondensed.fnt")

item.Init = function(modReference)
	item.MODREFERENCE = modReference
end

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.Started = true
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldSave)		--离开游戏
	item.Started = nil
	item.last_player_type = nil
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_INIT, params = nil,
Function = function(_,player)
	item.last_player_type = player:GetPlayerType()
end,
})

return item
