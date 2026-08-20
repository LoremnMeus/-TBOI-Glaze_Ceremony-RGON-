local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Knife_holder_",
}

local function try_craft_haemo_knife(ent, at_pos)
	local d = ent:GetData()
	local params = d.params
	if not params or not params.craft_haemo or params.craft_haemo_done then return end
	local profile = params.craft_profile
	if not profile or not CraftProfile.profile_has_haemolacria(profile) then return end
	params.craft_haemo_done = true
	local mods = params.craft_atk_mods or {}
	local player = params.player
	local dir = ent.Velocity
	if not dir or dir:Length() < 0.01 then dir = Vector(1, 0) end
	CraftProfile.spawn_craft_haemolacria_burst(
		profile,
		at_pos or ent.Position,
		dir,
		player,
		{
			player = player,
			damage_mul = 0.45 * (mods.damage_mul or 1),
			size_mul = mods.size_mul or 1,
			tear_flags = params.tearflags,
		}
	)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_KNIFE_COLLISION, params = nil,
Function = function(_,ent,colli,low)
	if colli and colli:IsVulnerableEnemy() then
		try_craft_haemo_knife(ent, colli.Position)
	end
end,
})

--- Shoot 飞到最大距离后引擎会反转 PathFollowSpeed（回程），与 MeusNil Accerate 叠加会造成 PathOffset/PositionOffset 跳变。
--- hold_knife_path：在顶点锁住 PathOffset，继续随父体前飞。
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_KNIFE_UPDATE, params = nil,
Function = function(_, ent)
	local d = ent:GetData()
	local flight = d.knife_flight
	if not flight then return end
	local k = ent:ToKnife()
	if not k then return end

	if flight.PosOffset then
		ent.PositionOffset = flight.PosOffset
		local parent = ent.Parent
		if parent and parent:Exists() then
			parent.PositionOffset = flight.PosOffset
		end
	end

	if not flight.hold_knife_path then return end
	local po = k.PathOffset or 0
	if po > (flight.peak_path or 0) then
		flight.peak_path = po
	end
	local peak = flight.peak_path or 0
	local maxd = k.MaxDistance or 0
	local hold = math.max(peak, maxd)
	if hold <= 1 then return end

	local spd = k.PathFollowSpeed or 0
	-- 接近顶点或已开始回程：锁在最远点，避免 PathOffset 反向跳变
	if spd < 0 or po >= hold - math.max(1, math.abs(spd)) then
		if k.SetPathFollowSpeed then
			k:SetPathFollowSpeed(0)
		else
			k.PathFollowSpeed = 0
		end
		k.PathOffset = hold
		flight.locked = true
	elseif flight.locked then
		if k.SetPathFollowSpeed then
			k:SetPathFollowSpeed(0)
		else
			k.PathFollowSpeed = 0
		end
		k.PathOffset = hold
	end

	-- 飞出房间：供刀桥激光等兼容结束；收刀/出房时血泪兜底一次
	local room = Game():GetRoom()
	if room and not room:IsPositionInRoom(ent.Position, -24) then
		flight.out_of_room = true
		try_craft_haemo_knife(ent, ent.Position)
	end
	if not ent:Exists() or ent:IsDead() then
		try_craft_haemo_knife(ent, ent.Position)
	end
end,
})

return item
