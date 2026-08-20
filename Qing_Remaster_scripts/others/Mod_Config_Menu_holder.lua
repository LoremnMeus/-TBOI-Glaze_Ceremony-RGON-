local g = require("Qing_Remaster_scripts.core.globals")
local enums = require("Qing_Remaster_scripts.core.enums")
local save = require("Qing_Remaster_scripts.core.savedata")

local item
item = {
	post_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Mod_config_holder_",
	saver = {
		["thor_key"] = "Qing\'s key",
		["thor_controller"] = "Qing\'s controllerkey",
		["On_air_key"] = "Tainted W.Qing\'s key1",
		["Off_air_key"] = "Tainted W.Qing\'s key2",
	},
	ModConfigSettings = {},
}

function item.get_initlist()
	return {
		Items_allow = true,
		Trinkets_allow = true,
		Pickup_allow = true,
		Boss_allow = true,
		Achievement_allow = true,
		Achievement_pool_gating = false,
		Achievement_trinket_gating = false,
		Achievement_card_gating = false,
		Achievement_pickup_gating = false,
		allow_mouse_control = true,
		thor_key = Keyboard.KEY_LEFT_ALT,
		thor_controller = 12,
		On_air_key = Keyboard.KEY_LEFT_ALT,
		Off_air_key = Keyboard.KEY_LEFT_CONTROL,
		mouseSupport = 2,
		mouseSupport1 = true,
		mouseSupport2 = false,
		Auto_Live = false,
		Trigger_LaserStart = true,
		Trigger_LaserEnd = true,
		Trigger_BrimStart = true,
		Trigger_BrimEnd = true,
	}
end
item.ModConfigSettings = item.get_initlist()

function item.get_setting(key)
	if item.ModConfigSettings[key] == nil then
		local defaults = item.get_initlist()
		item.ModConfigSettings[key] = defaults[key]
	end
	return item.ModConfigSettings[key]
end

function item.boolean_setting_display(label,key)
	return label .. ":" .. (item.get_setting(key) and "Yes" or "No")
end

function item.boolean_setting(key)
	return {
		Type = ModConfigMenu.OptionType.BOOLEAN,
		CurrentSetting = function() return item.get_setting(key) end,
		OnChange = function(currentBool) item.ModConfigSettings[key] = currentBool end,
	}
end

local ModConfigQingCategory = ".W.Q."

if ModConfigMenu then

item.Work = {
	["en"] = {
		{name = "UpdateCategory",params = {{Info = {"Settings for the W.Q. character mod.",},},},},
		{name = "AddText",params = {"Options", function() return "Others Options can be altered here." end,},},
		{name = "AddSetting",params = {"Options",{		--一键锁定
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return true end,
			Display = function() return "Use This to Lock All Achievements" end,
			OnChange = function(currentBool) save.LockAll() end,
			Info = {"Caution:There is no room to regret once you press it.",},
		},},},
		{name = "AddSpace",params = {"Options",},},
		{name = "AddSetting",params = {"Options",{		--一键解锁
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return true end,
			Display = function() return 'Use This to Unlock All Achievements' end,
			OnChange = function(currentBool) save.UnLockAll() end,
			Info = {"Caution:There is no room to regret once you press it.",},
		},},},
		{name = "AddSpace",params = {"Options",},},
		{name = "AddSetting",params = {"Options",{		--Mod道具
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return item.ModConfigSettings.Items_allow end,
			Display = function() return 'Allow Mod items to natually appear:' .. (item.ModConfigSettings.Items_allow and "Yes" or "No")	end,
			OnChange = function(currentBool) item.ModConfigSettings.Items_allow = currentBool end,
			Info = {"If true, unlocked items will appear by chance in the basement.(Remember this won't work until next run!) ",},
		},},},
		{name = "AddSetting",params = {"Options",{		--基础掉落
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return item.ModConfigSettings.Pickup_allow end,
			Display = function() return 'Allow Mod pickups to natually appear:' .. (item.ModConfigSettings.Pickup_allow and "Yes" or "No") end,
			OnChange = function(currentBool) item.ModConfigSettings.Pickup_allow = currentBool end,
			Info = {"If true, unlocked pickups will appear in the basement. ",},
		},},},
		{name = "AddSetting",params = {"Options",{		--Boss
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return item.ModConfigSettings.Boss_allow end,
			Display = function() return 'Allow Mod Boss to appear:' .. (item.ModConfigSettings.Boss_allow and "Yes" or "No") end,
			OnChange = function(currentBool) item.ModConfigSettings.Boss_allow = currentBool end,
			Info = {"If true, special Bosses will appear in the basement. ",},
		},},},
		{name = "AddSetting",params = {"Options",{		--允许解锁成就
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return item.ModConfigSettings.Achievement_allow end,
			Display = function() return 'Allow Achievements to be Unlocked:' .. (item.ModConfigSettings.Achievement_allow and "Yes" or "No") end,
			OnChange = function(currentBool) item.ModConfigSettings.Achievement_allow = currentBool end,
			Info = {"If true, Achievements will be unlocked after require satisfied. ",},
		},},},
		{name = "AddSpace",params = {"Options",},},
		{name = "AddText",params = {"Options",function() return "Attack callback trigger points" end,},},
		{name = "AddSetting",params = {"Options",{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return item.get_setting("Trigger_LaserStart") end,
			Display = function() return item.boolean_setting_display("Laser start trigger","Trigger_LaserStart") end,
			OnChange = function(currentBool) item.ModConfigSettings.Trigger_LaserStart = currentBool end,
			Info = {"Controls POST_FIRE_TRIGGER for LaserStart.",},
		},},},
		{name = "AddSetting",params = {"Options",{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return item.get_setting("Achievement_pool_gating") end,
			Display = function() return item.boolean_setting_display("Apply achievement unlocks to item pools","Achievement_pool_gating") end,
			OnChange = function(currentBool) item.ModConfigSettings.Achievement_pool_gating = currentBool end,
			Info = {"Locked achievement-board collectibles are removed from natural item-pool selection on the next new run.",},
		},},},
		{name = "AddSetting",params = {"Options",{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return item.get_setting("Trinkets_allow") end,
			Display = function() return item.boolean_setting_display("Allow mod trinkets to naturally appear","Trinkets_allow") end,
			OnChange = function(currentBool) item.ModConfigSettings.Trinkets_allow = currentBool end,
			Info = {"When disabled, all Qing Remaster trinkets are removed from the trinket pool on the next new run.",},
		},},},
		{name = "AddSetting",params = {"Options",{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return item.get_setting("Achievement_card_gating") end,
			Display = function() return item.boolean_setting_display("Apply achievement unlocks to cards","Achievement_card_gating") end,
			OnChange = function(currentBool) item.ModConfigSettings.Achievement_card_gating = currentBool end,
			Info = {"Locked achievement-board cards remain unavailable without rerolling or changing card weights.",},
		},},},
		{name = "AddSetting",params = {"Options",{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return item.get_setting("Achievement_trinket_gating") end,
			Display = function() return item.boolean_setting_display("Apply achievement unlocks to trinkets","Achievement_trinket_gating") end,
			OnChange = function(currentBool) item.ModConfigSettings.Achievement_trinket_gating = currentBool end,
			Info = {"Locked achievement-board trinkets are removed from the trinket pool on the next new run.",},
		},},},
		{name = "AddSetting",params = {"Options",{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return item.get_setting("Achievement_pickup_gating") end,
			Display = function() return item.boolean_setting_display("Apply achievement unlocks to pickups","Achievement_pickup_gating") end,
			OnChange = function(currentBool) item.ModConfigSettings.Achievement_pickup_gating = currentBool end,
			Info = {"Locked achievement-board glazed pickups will not be generated.",},
		},},},
		{name = "AddSetting",params = {"Options",{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return item.get_setting("Trigger_LaserEnd") end,
			Display = function() return item.boolean_setting_display("Laser end trigger","Trigger_LaserEnd") end,
			OnChange = function(currentBool) item.ModConfigSettings.Trigger_LaserEnd = currentBool end,
			Info = {"Controls POST_FIRE_TRIGGER for LaserEnd.",},
		},},},
		{name = "AddSetting",params = {"Options",{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return item.get_setting("Trigger_BrimStart") end,
			Display = function() return item.boolean_setting_display("Brimstone start trigger","Trigger_BrimStart") end,
			OnChange = function(currentBool) item.ModConfigSettings.Trigger_BrimStart = currentBool end,
			Info = {"Controls POST_FIRE_TRIGGER for BrimStart.",},
		},},},
		{name = "AddSetting",params = {"Options",{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return item.get_setting("Trigger_BrimEnd") end,
			Display = function() return item.boolean_setting_display("Brimstone end trigger","Trigger_BrimEnd") end,
			OnChange = function(currentBool) item.ModConfigSettings.Trigger_BrimEnd = currentBool end,
			Info = {"Controls POST_FIRE_TRIGGER for BrimEnd.",},
		},},},
		{name = "AddSpace",params = {"Options",},},
		{name = "AddSetting",params = {"Options",{		--全部重置
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return true end,
			Display = function() return "Reset All" end,
			OnChange = function(currentBool) item.ModConfigSettings = item.get_initlist() end,
			Info = {"Reset all options back to default.",},
		},},},
		----Setting----
		{name = "AddText",params = {"Settings",function() return "You can customize Key Board Setting here." end,},},
		{name = "AddSpace",params = {"Settings",},},
		{name = "AddText",params = {"Settings",function() return "W.Qing now teleports" end,},},
		{name = "AddKeyboardSetting",params = {"Settings","Qing\'s key",item.ModConfigSettings.thor_key,"By Pressing",false,"Choose which button on your keyboard will lead to the final attack from W.Q.",},},
		{name = "AddControllerSetting",params = {"Settings","Qing\'s controllerkey",item.ModConfigSettings.thor_controller,"Or by controller",false,"Choose which button on your controller will lead to the final attack from W.Q.",},},
		{name = "AddSetting",params = {"Options",{		--鼠标控制
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return item.ModConfigSettings.allow_mouse_control end,
			Display = function() return 'Mouse Support On Qing:' .. (item.ModConfigSettings.allow_mouse_control and "Yes" or "No") end,
			OnChange = function(currentBool) item.ModConfigSettings.allow_mouse_control = currentBool end,
			Info = {"If true, You can use your mouse to control W.Qing. ",},
		},},},
		{name = "AddText",params = {"Settings",function() return "Tainted W.Qing: toggle Cruise / Guard" end,},},
		{name = "AddKeyboardSetting",params = {"Settings","Tainted W.Qing\'s key2",item.ModConfigSettings.Off_air_key,"By Pressing",false,"Toggle Cruise / Guard formation for Tainted W.Qing.",},},
		{name = "AddSpace",params = {"Options",},},
		{name = "AddSetting",params = {"Options",{		--鼠标控制
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return true end,
			Display = function() return 'Mouse Support:' .. (item.ModConfigSettings.mouseSupport1 and (item.ModConfigSettings.mouseSupport2 and 'Always Follow' or 'Only On Click') or 'Disabled') end,
			OnChange = function(currentBool) item.ModConfigSettings.mouseSupport = item.ModConfigSettings.mouseSupport + 1
				if item.ModConfigSettings.mouseSupport > 3 then item.ModConfigSettings.mouseSupport = 1 end
				item.ModConfigSettings.mouseSupport1 = ((item.ModConfigSettings.mouseSupport & 2) == 2)
				item.ModConfigSettings.mouseSupport2 = ((item.ModConfigSettings.mouseSupport & 1) == 1)
			end,
			Info = {"If true,Tainted W.Q.'s mark will follow your mouse.",},
		},},},
		----Others----
		{name = "AddSetting",params = {"Others",{		--自动开启
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return item.ModConfigSettings.Auto_Live end,
			Display = function() return 'Automatically open broadcast:' .. (item.ModConfigSettings.Auto_Live and "Yes" or "No") end,
			OnChange = function(currentBool) item.ModConfigSettings.Auto_Live = currentBool end,
			Info = {"If true, Live Broadcast will be automatically opened without item.",},
		},},},
	},
}

local language = Options.Language
if not item.Work[language] then language = "en" end
for u,v in pairs(item.Work[language]) do
	ModConfigMenu[v.name](ModConfigQingCategory,v.params[1],v.params[2],v.params[3],v.params[4],v.params[5],v.params[6])
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function()
	for u,v in pairs(item.saver) do
		if (ModConfigMenu.Config[ModConfigQingCategory] or {})[v] ~= nil then item.ModConfigSettings[u] = (ModConfigMenu.Config[ModConfigQingCategory] or {})[v] end
	end
end,
})

end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,countiue)
	-- 只挂差分表；缺省值由 rgon_imgui_options 的 defaults_proxy 补齐
	item.ModConfigSettings = save.ModConfigSettings or {}
	save.ModConfigSettings = item.ModConfigSettings
	if ModConfigMenu then
		local defaults = item.get_initlist()
		for u,v in pairs(item.saver) do
			local value = item.ModConfigSettings[u]
			if value == nil then value = defaults[u] end
			(ModConfigMenu.Config[ModConfigQingCategory] or {})[v] = value
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldsave)
	save.ModConfigSettings = item.ModConfigSettings
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	save.ModConfigSettings = item.ModConfigSettings
end,
})

return item
