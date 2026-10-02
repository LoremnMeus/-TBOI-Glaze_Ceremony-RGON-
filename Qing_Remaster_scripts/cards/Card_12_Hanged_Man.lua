local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local r_Hanged_Man = require("Qing_Remaster_scripts.cards.Card_12r_Hanged_Man")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")
local screen_desync = require("Qing_Remaster_scripts.auxiliary.screen_desync")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Hanged_Man,
	own_key = "Thoth_cd12_Han_",
}

-- Vanilla tarot/card pickups: gfx/005.301_tarot card.anm2 Appear FrameNum="35".
-- False recovery = exactly two full Appears: jump to opposite, then return to initial.
local APPEAR_LEN = 35

-- Relative to the frame we enter UNSTABLE (after the return Appear finishes).
local AFTER_UNSTABLE = {
	DESYNC = 14,
	GLITCH = 22,
	CRITICAL = 32,
	FREEZE = 42,
	HARD_ERROR = 44,
	TRANSITION = 47,
	OVERLAP_A = 35, -- CRITICAL + 3
	OVERLAP_B = 38, -- CRITICAL + 6
}

local FALSE_STEP = {
	JUMP = 1,   -- full Appear on opposite face
	RETURN = 2, -- full Appear back on initial face
}

local RED_GHOST = Color(1, 0.35, 0.35, 0.22)
local CYAN_GHOST = Color(0.35, 0.9, 1, 0.22)
local JITTER = {
	Vector(-3, 1),
	Vector(2, -2),
	Vector(-1, -3),
	Vector(4, 1),
	Vector(-3, 2),
	Vector(1, -1),
}
local CRITICAL_SCALES = {0.94, 1.06, 0.98, 1.09}
local CRITICAL_ROTS = {-4, 3, -2, 5}

-- false = initial face, true = opposite face
local UNSTABLE_PATTERN = {
	false, false, false,
	true, true,
	false, false,
	true,
	false, false, false,
	true, true, true,
}

-- Room-local: at most one conflict presentation.
local conflict = nil

local function clear_conflict()
	conflict = nil
end

local function both_rules_active()
	return save.elses[item.own_key.."effect"]
		and save.elses[r_Hanged_Man.own_key.."effect"]
end

local function clear_both_rules()
	save.elses[item.own_key.."effect"] = nil
	save.elses[r_Hanged_Man.own_key.."effect"] = nil
end

local function make_face_sprite(path)
	local sprite = Sprite()
	sprite:Load(path, true)
	sprite:Play("Idle", true)
	if sprite:GetAnimation() ~= "Idle" then
		sprite:Play("Appear", true)
		if sprite.SetLastFrame then
			sprite:SetLastFrame()
		end
	end
	sprite.Scale = Vector.One
	sprite.Rotation = 0
	sprite.Color = Color(1, 1, 1, 1)
	return sprite
end

local function get_initial_face(c)
	return c.initial_reversed and c.reversed or c.upright
end

local function get_opposite_face(c)
	return c.initial_reversed and c.upright or c.reversed
end

local function begin_conflict(ent)
	if conflict or not ent then
		return false
	end

	local current_id = ent.SubType
	local other_id = auxi.get_reversed_card(ent, ent:GetDropRNG())
	if not other_id or other_id == 0 or other_id == current_id then
		return false
	end

	local native = ent:GetSprite()
	local path_a = native and native:GetFilename() or nil
	if not path_a or path_a == "" then
		return false
	end

	local initial_reversed = auxi.is_reversed_card(current_id) == true

	ent:Morph(5, 300, other_id, true, true, true)
	local path_b = ent:GetSprite():GetFilename()
	if not path_b or path_b == "" then
		return false
	end

	local upright_path, reversed_path
	if initial_reversed then
		reversed_path, upright_path = path_a, path_b
	else
		upright_path, reversed_path = path_a, path_b
	end

	local upright = make_face_sprite(upright_path)
	local reversed = make_face_sprite(reversed_path)
	local original_visible = ent.Visible

	-- False recovery: one full Appear to opposite, one full Appear back.
	-- Do not spend a third Appear settling on the initial face first.
	Attribute_holder.try_hold_attribute(ent, "EntityCollisionClass", EntityCollisionClass.ENTCOLL_NONE)
	ent.Visible = true

	conflict = {
		entity = ent,
		entity_hash = GetPtrHash(ent),
		position = Vector(ent.Position.X, ent.Position.Y),
		upright = upright,
		reversed = reversed,
		initial_id = current_id,
		opposite_id = other_id,
		initial_reversed = initial_reversed,
		age = 0,
		phase = "FALSE_RECOVERY",
		false_step = FALSE_STEP.JUMP,
		step_age = 0,
		unstable_at = nil,
		native_visible = true,
		hard_error = false,
		rules_cleared = false,
		transition_started = false,
		original_visible = original_visible,
	}

	-- Appear #1: jump to the opposite face (already Morphed while capturing path_b).
	Attribute_holder.try_hold_attribute(ent, "EntityCollisionClass", EntityCollisionClass.ENTCOLL_NONE)
	ent.Visible = true
	ent:GetSprite():Play("Appear", true)
	return true
end

-- Drive early false jumps with the real pickup Morph + Appear.
local function show_native_face(c, opposite)
	local ent = c.entity
	if not ent or not ent:Exists() then
		return
	end
	local id = opposite and c.opposite_id or c.initial_id
	if not id then
		return
	end
	if ent.SubType ~= id then
		ent:Morph(5, 300, id, true, true, true)
	end
	-- Morph can restore default collision; keep the conflict pickup untouchable.
	Attribute_holder.try_hold_attribute(ent, "EntityCollisionClass", EntityCollisionClass.ENTCOLL_NONE)
	ent.Visible = true
	ent:GetSprite():Play("Appear", true)
	c.position = Vector(ent.Position.X, ent.Position.Y)
	c.step_age = 0
end

local function hide_native_entity(c)
	local ent = c.entity
	if ent and ent:Exists() then
		c.position = Vector(ent.Position.X, ent.Position.Y)
		ent.Visible = false
	end
	c.native_visible = false
end

local function native_appear_done(c)
	local ent = c.entity
	if not ent or not ent:Exists() then
		return true
	end
	local spr = ent:GetSprite()
	if spr:IsFinished("Appear") then
		return true
	end
	-- Tarot Appear FrameNum is 35; never hang if IsFinished stalls.
	return (c.step_age or 0) >= APPEAR_LEN
end

local function begin_unstable(c)
	c.phase = "UNSTABLE"
	c.false_step = nil
	c.unstable_at = c.age
	hide_native_entity(c)
end

local function update_false_recovery(c)
	local step = c.false_step
	if step == FALSE_STEP.JUMP then
		if native_appear_done(c) then
			-- Appear #2: return to the initial face.
			show_native_face(c, false)
			c.false_step = FALSE_STEP.RETURN
		end
	elseif step == FALSE_STEP.RETURN then
		if native_appear_done(c) then
			begin_unstable(c)
		end
	end
end

local function unstable_t(c)
	if not c.unstable_at then
		return -1
	end
	return c.age - c.unstable_at
end

local function unstable_face_is_opposite(c)
	local t = unstable_t(c)
	if t < 0 then
		return false
	end
	local idx = t % #UNSTABLE_PATTERN
	return UNSTABLE_PATTERN[idx + 1] == true
end

local function critical_transform(age)
	local ji = (age % #JITTER) + 1
	local si = (age % #CRITICAL_SCALES) + 1
	local ri = (age % #CRITICAL_ROTS) + 1
	return JITTER[ji], CRITICAL_ROTS[ri], CRITICAL_SCALES[si]
end

local function render_face(sprite, pos, opts)
	opts = opts or {}
	local old_color = sprite.Color
	local old_scale = sprite.Scale
	local old_rot = sprite.Rotation
	local old_flags = (sprite.GetRenderFlags and sprite:GetRenderFlags()) or 0

	if opts.color then sprite.Color = opts.color end
	if opts.scale then sprite.Scale = Vector(opts.scale, opts.scale) end
	if opts.rotation then sprite.Rotation = opts.rotation end
	if opts.glitch and AnimRenderFlags and sprite.SetRenderFlags then
		sprite:SetRenderFlags(old_flags | AnimRenderFlags.GLITCH)
	end

	sprite:Render(pos + (opts.offset or Vector.Zero), Vector.Zero, Vector.Zero)

	sprite.Color = old_color
	sprite.Scale = old_scale
	sprite.Rotation = old_rot
	if sprite.SetRenderFlags then
		sprite:SetRenderFlags(old_flags)
	end
end

local function render_unstable(c, pos)
	local opposite = unstable_face_is_opposite(c)
	local primary = opposite and get_opposite_face(c) or get_initial_face(c)
	local ghost = opposite and get_initial_face(c) or nil

	render_face(primary, pos, {
		scale = 1,
		rotation = 0,
	})

	-- Soft initial ghost only while showing the wrong answer.
	if opposite and ghost then
		local sign = (c.age % 2 == 0) and 1 or -1
		render_face(ghost, pos, {
			color = Color(1, 1, 1, 0.18),
			offset = Vector(sign, 0),
			scale = 1,
			rotation = 0,
		})
	end
end

local function render_desync(c, pos)
	local t = unstable_t(c)
	-- 2–3 frame face cadence during DESYNC.
	local opposite = math.floor(t / 2) % 2 == 1
	local primary = opposite and get_opposite_face(c) or get_initial_face(c)
	local ghost = opposite and get_initial_face(c) or get_opposite_face(c)
	local glitch = t >= AFTER_UNSTABLE.GLITCH
	local ji = (c.age % #JITTER) + 1
	local j = JITTER[ji]

	render_face(primary, pos, {
		offset = Vector(j.X * 0.4, j.Y * 0.4),
		rotation = (c.age % 2 == 0) and -2 or 2,
		scale = (c.age % 2 == 0) and 0.99 or 1.04,
		glitch = glitch,
	})
	render_face(ghost, pos, {
		color = Color(1, 1, 1, 0.28),
		offset = Vector(2, 0),
		glitch = glitch,
	})
	render_face(primary, pos, {
		color = RED_GHOST,
		offset = Vector(-2, 1),
		glitch = glitch,
	})
	render_face(primary, pos, {
		color = CYAN_GHOST,
		offset = Vector(2, -1),
		glitch = glitch,
	})
end

local function render_critical(c, pos)
	local t = unstable_t(c)
	local opposite = c.age % 2 == 1
	local primary = opposite and get_opposite_face(c) or get_initial_face(c)
	local secondary = opposite and get_initial_face(c) or get_opposite_face(c)
	local off, rot, scale = critical_transform(c.age)
	local overlap = t == AFTER_UNSTABLE.OVERLAP_A or t == AFTER_UNSTABLE.OVERLAP_B

	if overlap then
		render_face(c.upright, pos, {
			color = Color(1, 1, 1, 0.95),
			offset = off,
			rotation = rot,
			scale = scale,
			glitch = true,
		})
		render_face(c.reversed, pos, {
			color = Color(1, 1, 1, 0.9),
			offset = Vector(-off.X, -off.Y),
			rotation = -rot,
			scale = scale,
			glitch = true,
		})
	else
		render_face(primary, pos, {
			offset = off,
			rotation = rot,
			scale = scale,
			glitch = true,
		})
		render_face(secondary, pos, {
			color = Color(1, 1, 1, 0.35),
			offset = Vector(off.X * 1.4, -off.Y * 1.2),
			rotation = -rot,
			scale = scale,
			glitch = true,
		})
	end

	render_face(primary, pos, {
		color = RED_GHOST,
		offset = Vector(off.X - 4, off.Y + 2),
		rotation = rot,
		scale = scale,
		glitch = true,
	})
	render_face(secondary, pos, {
		color = CYAN_GHOST,
		offset = Vector(off.X + 4, off.Y - 2),
		rotation = -rot,
		scale = scale,
		glitch = true,
	})
end

local function render_freeze(c, pos)
	-- Both answers fully true: no jitter, no RGB, no GLITCH.
	render_face(c.upright, pos, {
		scale = 1,
		rotation = 0,
	})
	render_face(c.reversed, pos, {
		scale = 1,
		rotation = 0,
	})
end

local function render_conflict()
	local c = conflict
	if not c or c.hard_error then
		return
	end
	-- Early false recovery is the live pickup Appear animation.
	if c.native_visible or not c.unstable_at then
		return
	end
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		return
	end

	local pos = Isaac.WorldToScreen(c.position)
	local t = unstable_t(c)
	if t < AFTER_UNSTABLE.DESYNC then
		render_unstable(c, pos)
	elseif t < AFTER_UNSTABLE.CRITICAL then
		render_desync(c, pos)
	elseif t < AFTER_UNSTABLE.FREEZE then
		render_critical(c, pos)
	elseif t < AFTER_UNSTABLE.HARD_ERROR then
		render_freeze(c, pos)
	end
end

local function hard_error_conflict(c)
	if c.hard_error then
		return
	end
	c.hard_error = true
	c.phase = "HARD_ERROR"

	if not c.rules_cleared then
		clear_both_rules()
		c.rules_cleared = true
	end

	sound_tracker.PlayStackedSound(SoundEffect.SOUND_EDEN_GLITCH, 0.72, 0.72, false, 0, 2)
	Game():ShakeScreen(6)
	screen_desync.trigger(4, false)

	local ent = c.entity
	if ent and ent:Exists() then
		ent:Remove()
	end
	c.entity = nil
end

local function transition_conflict(c)
	if c.transition_started then
		return
	end
	c.transition_started = true

	-- Let PIXELATION own the transition; do not stack desync on top.
	screen_desync.reset()

	Room_holder.Trans_to(
		-2,
		Direction.NO_DIRECTION,
		RoomTransitionAnim.PIXELATION,
		Game():GetPlayer(0)
	)
	conflict = nil
end

local function update_conflict()
	local c = conflict
	if not c then
		return
	end

	c.age = c.age + 1
	c.step_age = (c.step_age or 0) + 1

	-- Keep cached position synced while the live pickup is still the visual.
	if c.native_visible and c.entity and c.entity:Exists() then
		c.position = Vector(c.entity.Position.X, c.entity.Position.Y)
	end

	if c.false_step then
		update_false_recovery(c)
		return
	end

	local t = unstable_t(c)
	if t < 0 then
		return
	end

	if t == AFTER_UNSTABLE.DESYNC then
		c.phase = "DESYNC"
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_EDEN_GLITCH, 0.35, 0.92, false, 0, 2)
		screen_desync.trigger(5, false)
	elseif t == AFTER_UNSTABLE.CRITICAL then
		c.phase = "CRITICAL"
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_EDEN_GLITCH, 0.58, 1.10, false, 0, 2)
		screen_desync.trigger(9, false)
	elseif t == AFTER_UNSTABLE.FREEZE then
		c.phase = "FREEZE"
		screen_desync.reset()
	elseif t == AFTER_UNSTABLE.HARD_ERROR then
		hard_error_conflict(c)
	elseif t >= AFTER_UNSTABLE.TRANSITION then
		transition_conflict(c)
	end
end

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	Function = function(_, continue)
		if not continue then
			save.elses[item.own_key.."effect"] = nil
		end
		clear_conflict()
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	Function = function()
		save.elses[item.own_key.."effect"] = nil
		clear_conflict()
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_ROOM,
	Function = function()
		clear_conflict()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	Function = function()
		update_conflict()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	Function = function()
		render_conflict()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE,
	params = 300,
	Function = function(_, ent)
		if not auxi.is_maped_card(ent) then
			return
		end

		-- Global conflict lock: no second show, no more flips while ERROR plays.
		if conflict then
			return
		end

		if both_rules_active() then
			if not conflict then
				begin_conflict(ent)
			end
			return
		end

		if auxi.is_reversed_card(ent) ~= true then
			if save.elses[item.own_key.."effect"] then
				ent:Morph(5, 300, auxi.get_reversed_card(ent, ent:GetDropRNG()), true, true, true)
			end
		elseif save.elses[r_Hanged_Man.own_key.."effect"] then
			ent:Morph(5, 300, auxi.get_reversed_card(ent, ent:GetDropRNG()), true, true, true)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_CARD,
	params = item.entity,
	Function = function(_, cardtype, player, useFlags)
		local room = Game():GetRoom()
		local d = player:GetData()

		if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
			return
		end
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			local q = Isaac.Spawn(
				5,
				300,
				item.entity,
				room:FindFreePickupSpawnPosition(player.Position, 10, true),
				Vector(0, 0),
				player
			):ToPickup()
			q:Morph(5, 300, item.entity, true, true, true)
		end
		save.elses[item.own_key.."effect"] = true
	end,
})

return item
