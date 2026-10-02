local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local CompletionMarks = require("Qing_Remaster_scripts.core.completion_marks_manager")

local item = {
	ToCall = {},
	entity = enums.Enemies.Prince_Glaze,
	own_key = "Boss_Glaze_",
	Swapper = {
		["Appear"] = "Idle",
	},
	AnimInfo = {
		["Appear"] = {
			{frame = 0,offset = -300,},
			{frame = 5,offset = -150,},
			{frame = 10,offset = -85,},
			{frame = 15,offset = -38,},
			{frame = 18,offset = -12,},
			{frame = 21,offset = -6,},
			{frame = 24,offset = -3,},
			{frame = 27,offset = 0,},
			total = 27,
		},
		["Idle"] = {
			{frame = 0,offset = 0,},
			{frame = 2,offset = 5,},
			{frame = 4,offset = 5,},
			{frame = 9,offset = 2,},
			{frame = 10,offset = -3,},
			{frame = 11,offset = -8,},
			{frame = 13,offset = -12,},
			{frame = 21,offset = -12,},
			{frame = 29,offset = 0,},
			total = 29,
		},
		["Attack1"] = {
			{frame = 0,offset = 0,},
			{frame = 2,offset = 5,},
			{frame = 4,offset = 5,},
			{frame = 9,offset = 2,},
			{frame = 10,offset = -3,},
			{frame = 11,offset = -8,},
			{frame = 13,offset = -12,},
			{frame = 21,offset = -12,},
			{frame = 41,offset = 0,},
			total = 41,
		},
		["Attack2"] = {
			{frame = 0,offset = 0,},
			{frame = 2,offset = 5,},
			{frame = 4,offset = 0,},
			{frame = 9,offset = -5,},
			{frame = 13,offset = -7,},
			{frame = 21,offset = -12,},
			{frame = 29,offset = -11,},
			{frame = 34,offset = 5,},
			{frame = 39,offset = 0,},
			{frame = 41,offset = 0,},
			total = 41,
		},
	},
	Allow_Offset = {
		["Attack2"] = {},
	},
	AttackInfo = {
		["Attack1"] = {},
	},
	word_list = {
		zh = {
			[1] = {
				{
					"琉璃王子：",
					{word = "光明..",colorful = 0,doublerender = Vector(1,-1),},
				},
			},
		},
		en = {

		},
	},
}
item.AnimInfo["Idle_Speaking"] = item.AnimInfo["Idle"] item.AnimInfo["Idle_Shake_Head"] = item.AnimInfo["Idle"]

-- Runtime is driven by one 30 Hz MC_POST_UPDATE clock, not NPC interpolation ticks.
local Controller = require("Qing_Remaster_scripts.bosses.glaze.glaze_controller")
local Placeholder = require("Qing_Remaster_scripts.bosses.glaze.glaze_placeholder")
local StoryAdapter = require("Qing_Remaster_scripts.bosses.glaze.glaze_story_adapter")
local Debug = require("Qing_Remaster_scripts.bosses.glaze.glaze_debug")
local Palace = require("Qing_Remaster_scripts.bosses.glaze.glaze_palace")
local Assets = require("Qing_Remaster_scripts.bosses.glaze.glaze_visual_assets")
local DevEnvironment = require("Qing_Remaster_scripts.core.dev_environment")
Placeholder.labels = not DevEnvironment.is_public_release()
local cracked_color = Color(1, 1, 1, 1)
cracked_color:SetColorize(.45, .8, 1, .6)
local normal_color = Color(1, 1, 1, 1)

local function play_music()
	local music = MusicManager()
	if music:GetCurrentMusicID() ~= enums.Music.Light_and_Dark then
		music:Play(enums.Music.Light_and_Dark, 0)
		music:UpdateVolume()
	end
end

function item.start(ent, opts)
	opts = opts or {}
	if not ent or not ent:Exists() then
		for _, ctx in pairs(Controller.active) do
			if ctx.boss:Exists() then return ctx.boss end
		end
		ent = Isaac.Spawn(996, item.entity, 0, Game():GetRoom():GetCenterPos(), Vector.Zero, nil):ToNPC()
	end
	local ctx = Controller.init(ent)
	ctx.practice = opts.practice == true
	ctx.story_owned = opts.story_owned == true
	ctx.story_test = opts.story_test == true
	if ctx.practice and opts.story_owned ~= true then
		ctx.story_owned = false
	end
	ent:GetData().glaze_practice = ctx.practice
	ent:GetData().glaze_story_owned = ctx.story_owned
	play_music()
	return ent
end

item.debug = Debug.bind(item, Controller)
item.story_test = item.debug.story_test

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 996,
Function = function(_, ent)
	if ent.Variant ~= item.entity then return end
	Controller.init(ent)
	local d = ent:GetData()
	local wing = Sprite()
	wing:Load("gfx/boss/Glaze/Prince_glaze.anm2", true)
	wing:Play("Wing", true)
	d[item.own_key .. "WingSprite"] = wing
	-- Crown art shared with Item Crown path via glaze_visual_assets (not Item module).
	local crown = Sprite()
	crown:Load(Assets.Crown.anm2, true)
	crown:Play(Assets.Crown.animation, true)
	d[item.own_key .. "CrownSprite"] = crown
	play_music()
end})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,
Function = function(_, ent)
	if ent.Variant ~= item.entity then return end
	if ent:IsDead() then return end
	local ctx = Controller.init(ent)
	local d, s = ent:GetData(), ent:GetSprite()
	local frame = Game():GetFrameCount()
	if d.glaze_visual_frame == frame then return end
	d.glaze_visual_frame = frame
	local cracked = (ctx.phase == 3 or (ctx.transition == 2 and ctx.transition_frame >= 130)) and not ctx.perfect
	s.Color = cracked and cracked_color or normal_color
	if s:IsFinished(s:GetAnimation()) then s:Play("Idle", true) end
	for _, name in ipairs({"Wing", "Crown"}) do
		local sprite = d[item.own_key .. name .. "Sprite"]
		if sprite then sprite:Update() end
	end
	ent.EntityCollisionClass = (ctx.transition or ctx.state == "appear") and EntityCollisionClass.ENTCOLL_NONE or EntityCollisionClass.ENTCOLL_ALL
end})

local function render_pos(ent, offset)
	local s = ent:GetSprite()
	local info = auxi.check_lerp(s:GetFrame(), item.AnimInfo[s:GetAnimation()] or {{frame = 0, offset = 0}})
	return Isaac.WorldToScreen(ent.Position + ent.PositionOffset) + offset - Game():GetRoom():GetRenderScrollOffset(), info.offset
end

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_PRE_NPC_RENDER, params = 996,
Function = function(_, ent, offset)
	if ent.Variant ~= item.entity then return end
	local ctx = ent:GetData()[Controller.key]
	local wing = ent:GetData()[item.own_key .. "WingSprite"]
	if not ctx or not wing then return end
	-- Palace back layer once per Isaac render frame (PRE may run twice with interpolation).
	local frame = Isaac.GetFrameCount()
	if ctx._palace_draw_frame ~= frame then
		ctx._palace_draw_frame = frame
		Palace.render(ctx)
	end
	local pos, bob = render_pos(ent, offset)
	-- Existing Wing frames are 120px wide with XPivot=60: crop the right half for Finale.
	wing.Color = (ctx.phase == 3 and not ctx.perfect) and cracked_color or normal_color
	wing:Render(pos + Vector(0, bob + 3), Vector.Zero, ctx.final_state and Vector(60, 0) or Vector.Zero)
end})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_NPC_RENDER, params = 996,
Function = function(_, ent, offset)
	if ent.Variant ~= item.entity then return end
	local ctx = ent:GetData()[Controller.key]
	local crown = ent:GetData()[item.own_key .. "CrownSprite"]
	if not ctx or not crown or not (ctx.crown_visible or ctx.perfect) or ctx.final_state then return end
	local pos, bob = render_pos(ent, offset)
	crown:Render(pos + Vector(-6, bob - 26) + (ctx.crown_offset or Vector.Zero))
end})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 996,
Function = function(_, ent, amount)
	if ent.Variant ~= item.entity then return end
	return Controller.damage(Controller.init(ent), amount)
end})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_UPDATE, Function = Controller.tick_all})
table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_RENDER, Function = function()
	for _, ctx in pairs(Controller.active) do
		Placeholder.render(ctx)
		Controller.render_transition_shards(ctx)
	end
	item.debug.render_preview()
end})
table.insert(item.ToCall, {CallBack = ModCallbacks.MC_EXECUTE_CMD, Function = function(_, command, params)
	item.debug.command(command, params)
end})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = 996,
Function = function(_, ent)
	if ent.Variant ~= item.entity then return end
	local ctx = ent:GetData()[Controller.key]
	if not ctx then return end
	StoryAdapter.on_defeat(ctx)
	if not ctx.practice then CompletionMarks.complete_extra_all_players("boss.glaze") end
	Controller.cleanup(ctx)
end})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = 996,
Function = function(_, ent)
	local g = require("Qing_Remaster_scripts.core.globals")
	if not g.is_gameplay_world_active() then return end
	if ent.Variant ~= item.entity then return end
	local ctx = ent:GetData()[Controller.key]
	if ctx then Controller.cleanup(ctx) end
end})
for _, callback in ipairs({ModCallbacks.MC_POST_NEW_ROOM, ModCallbacks.MC_PRE_GAME_EXIT, ModCallbacks.MC_POST_GAME_STARTED}) do
	table.insert(item.ToCall, {CallBack = callback, Function = Controller.cleanup_all})
end

return item
