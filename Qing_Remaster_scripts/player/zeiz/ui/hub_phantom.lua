local enums = require("Qing_Remaster_scripts.core.enums")

-- 管理员虚影：角色贴图 + 头顶名字 + EID 愚见。走进碰撞以任命。
local M = {
	ToCall = {},
	core = nil,
	own_key = "zeiz_hub_phantom_",
	font = nil,
}

local SKIN_FALLBACK = {
	[PlayerType.PLAYER_CAIN] = "gfx/characters/costumes/character_003_cain.png",
	[PlayerType.PLAYER_BLUEBABY] = "gfx/characters/costumes/character_004_bluebaby.png",
	[PlayerType.PLAYER_EDEN] = "gfx/characters/costumes/character_009_eden.png",
	[PlayerType.PLAYER_KEEPER] = "gfx/characters/costumes/character_014_keeper.png",
	[PlayerType.PLAYER_BETHANY] = "gfx/characters/costumes/character_018_bethany.png",
}

local APPOINT_GRACE = 12
local NAME_OFFSET = Vector(0, -44)

function M.bind(core)
	M.core = core
end

local function font()
	if M.font then return M.font end
	M.font = Font()
	M.font:Load("font/cjk/lanapixel.fnt")
	return M.font
end

local function skin_path(player_type)
	if player_type and EntityConfig and EntityConfig.GetPlayer then
		local cfg = EntityConfig.GetPlayer(player_type)
		if cfg and cfg.GetSkinPath then
			local path = cfg:GetSkinPath()
			if path and path ~= "" then return path end
		end
	end
	return SKIN_FALLBACK[player_type]
end

local function apply_player_sprite(spr, player_type)
	spr:Load("gfx/001.000_player.anm2", true)
	local path = skin_path(player_type)
	if path then
		for i = 0, 14 do
			spr:ReplaceSpritesheet(i, path)
		end
		spr:LoadGraphics()
	end
	spr:Play("WalkDown", true)
	spr:SetFrame("WalkDown", 0)
	spr:PlayOverlay("HeadDown", true)
	spr:SetOverlayFrame("HeadDown", 0)
	spr.Color = Color(1, 1, 1, 0.62, 0.12, 0.14, 0.22)
end

function M.clear()
	local n_entity = Isaac.GetRoomEntities()
	for i = 1, #n_entity do
		local ent = n_entity[i]
		if ent and ent:Exists() and ent:GetData()[M.own_key.."effect"] then
			ent:Remove()
		end
	end
end

local function phantom_slots(count)
	local room = Game():GetRoom()
	local center = room:GetCenterPos() + Vector(0, -20)
	if count <= 0 then return {} end
	if count == 1 then
		return { center }
	end
	local span = 80
	local list = {}
	for i = 1, count do
		local t = (i - 1) / math.max(1, count - 1)
		list[i] = center + Vector((t - 0.5) * 2 * span, 0)
	end
	return list
end

function M.spawn_candidates()
	local core = M.core
	if not core.hub_room or not core.hub_room.is_current() then return end
	M.clear()
	local data = core.save.data()
	local raw = data.hub.currentCandidates or {}
	local cands = {}
	for i = 1, #raw do
		local id = raw[i]
		if id and not core.admins.is_appointed(id) then
			cands[#cands + 1] = id
		end
	end
	local slots = phantom_slots(#cands)
	for i = 1, #cands do
		local id = cands[i]
		local info = core.admins.get(id)
		local pos = slots[i] or Game():GetRoom():GetCenterPos()
		local q = Isaac.Spawn(1000, enums.Entities.EID_Descriptier, 0, pos, Vector(0, 0), nil)
		q.SortingLayer = 1
		q.DepthOffset = 2
		q.Size = 24
		q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
		local s = q:GetSprite()
		apply_player_sprite(s, info and info.player_type)
		local d = q:GetData()
		local eid = core.admins.folly_eid(id)
		d.EID_Description = { Name = eid.Name, Description = eid.Description }
		d[M.own_key.."effect"] = {
			id = id,
			name = core.admins.display_name(id),
			slot = i,
			ready_frame = Game():GetFrameCount() + APPOINT_GRACE,
		}
	end
end

local function overlapping_phantom(player)
	if not player then return nil end
	local best, best_dist
	local n_entity = Isaac.GetRoomEntities()
	for i = 1, #n_entity do
		local ent = n_entity[i]
		local info = ent and ent:Exists() and ent:GetData()[M.own_key.."effect"]
		if info then
			if (info.ready_frame or 0) <= Game():GetFrameCount() then
				local reach = (player.Size or 13) + (ent.Size or 24) + 6
				local dist = player.Position:Distance(ent.Position)
				if dist <= reach and (best_dist == nil or dist < best_dist) then
					best = ent
					best_dist = dist
				end
			end
		end
	end
	return best, best_dist
end

function M.try_appoint(player)
	local core = M.core
	if not core.hub_room or not core.hub_room.is_current() then return false end
	if not player or not core.util.is_zeiz(player) then return false end
	local data = core.save.data().hub
	if data.transitionLock or data.appointedThisVisit then return false end
	local ent = overlapping_phantom(player)
	if not ent then return false end
	local info = ent:GetData()[M.own_key.."effect"]
	if not info or not info.id then return false end
	if core.hub.appoint_id(info.id) then
		local poof = Isaac.Spawn(1000, EffectVariant.POOF01, 0, ent.Position, Vector(0, 0), nil)
		if poof then poof:GetSprite().Color = Color(1, 1, 1, 0.7, 0.2, 0.2, 0.35) end
		ent:Remove()
		return true
	end
	return false
end

table.insert(M.ToCall, #M.ToCall + 1, {CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.EID_Descriptier,
Function = function(_, ent)
	local info = ent:GetData()[M.own_key.."effect"]
	if not info then return end
	ent.Velocity = Vector(0, 0)
	local s = ent:GetSprite()
	if s:GetAnimation() ~= "WalkDown" then
		s:SetFrame("WalkDown", 0)
		s:SetOverlayFrame("HeadDown", 0)
	end
end,
})

table.insert(M.ToCall, #M.ToCall + 1, {CallBack = ModCallbacks.MC_POST_EFFECT_RENDER, params = enums.Entities.EID_Descriptier,
Function = function(_, ent, offset)
	local info = ent:GetData()[M.own_key.."effect"]
	if not info then return end
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local f = font()
	offset = offset or Vector(0, 0)
	local pos = Isaac.WorldToScreen(ent.Position + NAME_OFFSET) + offset
	local name = info.name or "?"
	f:DrawStringUTF8(name, pos.X - 80, pos.Y, KColor(1, 0.9, 0.55, 0.95), 160, true)
end,
})

table.insert(M.ToCall, #M.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	M.try_appoint(player)
end,
})

return M
