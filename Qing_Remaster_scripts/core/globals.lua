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

-- Canonical gameplay-world lifecycle. Prefer is_gameplay_world_active() over
-- Started / GetFrameCount() when guarding native world queries in teardown.
item.gameplay_world_active = false
item.Started = false

item.TempestaFont = Font()
--item.TempestaFont:Load("font/pftempestasevencondensed.fnt")

function item.is_gameplay_world_active()
	return item.gameplay_world_active == true
end

item.Init = function(modReference)
	item.MODREFERENCE = modReference
end

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.gameplay_world_active = true
	item.Started = true -- legacy alias; prefer is_gameplay_world_active()
end,
})

-- pre_ToCall + very early priority so other PRE_GAME_EXIT handlers see inactive world.
table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
priority = -10000,
Function = function(_,shouldSave)		--离开游戏：尽早关闭 gameplay world
	item.gameplay_world_active = false
	item.Started = false
	item.last_player_type = nil
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_INIT, params = nil,
Function = function(_,player)
	item.last_player_type = player:GetPlayerType()
end,
})

return item
