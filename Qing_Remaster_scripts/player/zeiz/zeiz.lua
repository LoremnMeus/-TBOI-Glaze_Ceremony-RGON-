local g = require("Qing_Remaster_scripts.core.globals")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Players.Zeiz,
	own_key = "Player_Zeiz_",
	Special_Des = {
		["zh"] = { ["Item"] = {}, },
		["en"] = { ["Item"] = {}, },
	},
}

local core = {}
item.core = core
core.util = require("Qing_Remaster_scripts.player.zeiz.core.util")
core.save = require("Qing_Remaster_scripts.player.zeiz.core.save_manager")
core.hooks = require("Qing_Remaster_scripts.player.zeiz.core.hooks")
core.energy = require("Qing_Remaster_scripts.player.zeiz.core.hub_energy")
core.events = require("Qing_Remaster_scripts.player.zeiz.core.management_events")
core.admins = require("Qing_Remaster_scripts.player.zeiz.core.administrator_manager")
core.folly = require("Qing_Remaster_scripts.player.zeiz.core.folly_manager")
core.interest = require("Qing_Remaster_scripts.player.zeiz.core.interest_manager")
core.proposal = require("Qing_Remaster_scripts.player.zeiz.core.proposal_manager")
core.hub = require("Qing_Remaster_scripts.player.zeiz.core.control_hub")
core.hub_room = require("Qing_Remaster_scripts.player.zeiz.core.hub_room")
core.hub_phantom = require("Qing_Remaster_scripts.player.zeiz.ui.hub_phantom")
local hub_ui = require("Qing_Remaster_scripts.player.zeiz.ui.hub_ui")

core.save.bind(core)
core.hooks.bind(core)
core.energy.bind(core)
core.events.bind(core)
core.admins.bind(core)
core.folly.bind(core)
core.interest.bind(core)
core.proposal.bind(core)
core.hub.bind(core)
core.hub_room.bind(core)
core.hub_phantom.bind(core)
hub_ui.bind(core)

require("Qing_Remaster_scripts.player.zeiz.administrators.cain")(core)
require("Qing_Remaster_scripts.player.zeiz.administrators.keeper")(core)
require("Qing_Remaster_scripts.player.zeiz.administrators.blue_baby")(core)
require("Qing_Remaster_scripts.player.zeiz.administrators.bethany")(core)
require("Qing_Remaster_scripts.player.zeiz.administrators.eden")(core)
require("Qing_Remaster_scripts.player.zeiz.administrators.meta")(core)
core.admins.ensure_all()

local function absorb(mod)
	if not mod then return end
	local fields = {"pre_ToCall", "ToCall", "post_ToCall", "pre_myToCall", "myToCall", "post_myToCall"}
	for i = 1, #fields do
		local field = fields[i]
		item[field] = item[field] or {}
		local list = mod[field]
		if list then
			for j = 1, #list do
				item[field][#item[field] + 1] = list[j]
			end
		end
	end
end

absorb(core.hub)
absorb(core.hub_room)
absorb(core.hub_phantom)
absorb(hub_ui)

local lock_spr = Sprite()
lock_spr:Load("gfx/005.150_shop item.anm2", true)

function item.is_zeiz_run()
	return core.util.any_zeiz()
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_, ent)
	if not core.util.any_zeiz() then return end
	local pickup = ent:ToPickup()
	if not pickup then return end
	core.folly.dispatch("OnPickupUpdate", { pickup = pickup })
end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = nil,
Function = function(_, ent, col, low)
	local pickup = ent:ToPickup()
	local player = col and col:ToPlayer()
	if not pickup or not player then return end
	if not pickup:GetData().zeiz_cain_lock then return end
	if not auxi.will_pick_up(player, pickup) then return end
	if player:GetNumKeys() > 0 then
		player:AddKeys(-1)
		pickup:GetData().zeiz_cain_lock = nil
		return
	end
	return true
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_RENDER, params = nil,
Function = function(_, ent, offset)
	local pickup = ent:ToPickup()
	if not pickup or not pickup:GetData().zeiz_cain_lock then return end
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	offset = offset or Vector(0, 0)
	local pos = Isaac.WorldToScreen(pickup.Position + pickup.PositionOffset) + offset + Vector(0, 12)
	lock_spr:SetFrame("Hearts", 0)
	lock_spr.Color = Color(1, 1, 1, 1)
	lock_spr.Scale = Vector(0.7, 0.7)
	lock_spr:Render(pos, Vector(0, 0), Vector(0, 0))
	Isaac.RenderText("KEY", pos.X - 10, pos.Y - 6, 1, 0.85, 0.3, 1)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	core.folly.dispatch("OnNewRoom", {})
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function()
	core.folly.dispatch("OnRoomClear", {})
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = nil,
Function = function(_, player, tp, id, value)
	if player:GetPlayerType() ~= item.entity then return end
	local language = Options.Language
	local infos = (item.Special_Des[language] or {})[tp]
	if infos == nil then return end
	local info = infos[id]
	if info == nil then return end
	return { Name = info.Name or value.Name, Description = info.Description or value.Description }
end,
})

function item.debug_snapshot()
	local data = core.save.data()
	local admins = {}
	for i = 1, #core.admins.order do
		local id = core.admins.order[i]
		local st = core.admins.state(id)
		admins[id] = {
			appointed = st.appointed,
			interest = st.interest,
			interestState = st.interestState,
			proposal = st.proposal,
			follyEnabled = st.follyEnabled,
		}
	end
	return {
		isZeiz = core.util.any_zeiz(),
		pending = data.hub.pendingEntry,
		open = data.hub.open,
		inHub = core.hub_room and core.hub_room.is_current() or false,
		hubIndex = data.hub.hub_index,
		candidates = data.hub.currentCandidates,
		appointed = core.admins.appointed_ids(),
		admins = admins,
		events = data.management.eventHistory,
		chain = data.management.currentChain,
		energy = data.hub.energy,
		meta = data.meta,
	}
end

item.api = core

return item
