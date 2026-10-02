-- 全局 Render Phase Holder：
-- MC_POST_UPDATE 作为 30Hz 逻辑锚点；
-- MC_POST_RENDER 计数自上次逻辑更新后的 render pass。
-- PRE_*_RENDER 读取：
--   renders_since_update == 0 -> phase 0 / alpha 0
--   renders_since_update >= 1 -> phase 1 / alpha 0.5
-- Player Update 与 phase 解耦（顺序不稳定，不得驱动 phase）。
-- 只提供只读 phase/alpha；不知道任何卡牌/实体业务。

local enums = require("Qing_Remaster_scripts.core.enums")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Render_phase_holder_",

	logic_frame = -1,
	renders_since_update = 0,
	valid = false,

	update_count = 0,
	render_count = 0,
	-- 兼容 debug snapshot；不再由 Player Update 推进。
	player_update_count = 0,
}

function item.reset_logic_frame(frame)
	item.logic_frame = tonumber(frame) or Game():GetFrameCount()
	item.renders_since_update = 0
	item.valid = true
end

function item.get_phase()
	if not item.valid then
		return 0
	end
	-- RSU>=1 一律 phase1（异常第三次 render 不另开 phase）
	if item.renders_since_update <= 0 then
		return 0
	end
	return 1
end

function item.get_alpha()
	if not item.valid then
		return 0
	end
	return item.get_phase() * 0.5
end

function item.is_mid_frame()
	return item.valid and item.renders_since_update >= 1
end

function item.invalidate()
	item.valid = false
	item.renders_since_update = 0
end

function item.get_debug_snapshot()
	return {
		logic_frame = item.logic_frame,
		renders_since_update = item.renders_since_update,
		phase = item.get_phase(),
		alpha = item.get_alpha(),
		valid = item.valid,
		update_count = item.update_count,
		player_update_count = item.player_update_count,
		render_count = item.render_count,
		game_frame = Game():GetFrameCount(),
	}
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	Function = function()
		item.update_count = item.update_count + 1
		item.reset_logic_frame(Game():GetFrameCount())
	end,
})

-- 推进 render pass 计数；PRE_*_RENDER 发生在对应 POST_RENDER 之前，故：
-- PRE #1 读到 RSU=0，PRE #2 读到 RSU=1。
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	Function = function()
		item.render_count = item.render_count + 1
		if item.valid then
			item.renders_since_update = item.renders_since_update + 1
		end
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_ROOM,
	Function = function()
		item.invalidate()
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	Function = function()
		item.invalidate()
		item.update_count = 0
		item.player_update_count = 0
		item.render_count = 0
		item.logic_frame = -1
	end,
})

return item
