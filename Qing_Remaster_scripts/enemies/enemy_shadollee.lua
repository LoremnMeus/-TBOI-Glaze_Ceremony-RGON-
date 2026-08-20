local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local danger = require("Qing_Remaster_scripts.others.Danger_Data")

local item = {
	ToCall = {},
	entity = enums.Entities.Shadollee,
}

local function add_flip(npc)
	local v = npc.Velocity
    if v.X < -0.0005 then
        npc:GetSprite().FlipX = true
    elseif v.X > 0.0005 then
        npc:GetSprite().FlipX = false
    end
end

--l local q = Isaac.Spawn(835,0,0,Vector(2000,2000),Vector(0,0),nil):ToNPC() local s = q:GetSprite() q:ClearEntityFlags(EntityFlag.FLAG_APPEAR) q:Update() print(s:GetFrame()) print(s:GetAnimation().." "..s:GetOverlayAnimation().." "..s:GetDefaultAnimation().." "..s:GetDefaultAnimationName()) q:Remove()

local function remove_linked(ent)
	local target = {}
	local id = ent:ToNPC()
	while(id.ParentNPC) do
		table.insert(target,id.ParentNPC)
		id = id.ParentNPC
	end
	while(id.ChildNPC) do
		table.insert(target,id.ChildNPC)
		id = id.ChildNPC
	end
	table.insert(target,id)
	for u,v in pairs(target) do
		if v:Exists() then 
			print(v.Type.." "..v.Variant.." "..v.SubType)
			v:Remove() 
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = item.entity,	--初始化
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local q = Isaac.Spawn(16,0,0,Vector(2000,2000),Vector(0,0),nil):ToNPC()--danger.random_add_ent()
	q:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	local s2 = q:GetSprite()
	s:Load(s2:GetFilename(),true)
	d.shadoll_overlay_filter = s2:GetOverlayAnimation()
	--print(d.shadoll_overlay_filter)
	if d.shadoll_overlay_filter == nil then
		if s2:GetAnimation() == "Appear" then
			s2:SetLastFrame()
		else
			s:PlayRandom()
		end
	else
		s:SetAnimation(s2:GetAnimation())
		s:SetOverlayAnimation(d.shadoll_overlay_filter)
	end
	remove_linked(q)
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	ent.GridCollisionClass = GridCollisionClass.COLLISION_NONE
	ent:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = item.entity,		--速度、位移调整
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	if s:IsFinished(s:GetAnimation()) then
		if d.shadoll_overlay_filter then
			s:PlayRandom()
		else
			s:Play(s:GetAnimation(),true)
			s:PlayOverlay(s:GetOverlayAnimation(),true)
		end
		d.shadoll_sprite_repeater = nil
	elseif s:GetFrame() == 1 then
		if d.shadoll_sprite_repeater == nil then
			d.shadoll_sprite_repeater = true
		else
			if d.shadoll_overlay_filter then
				s:PlayRandom()
			else
				s:Play(s:GetAnimation(),true)
				s:PlayOverlay(s:GetOverlayAnimation(),true)
			end
			d.shadoll_sprite_repeater = nil
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = item.entity,		--行为、战斗控制
Function = function(_,ent)
	if ent.Variant == item.entity then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local player = Game():GetPlayer(0)
		local hud = Game():GetHUD()
	end
end,
})

return item