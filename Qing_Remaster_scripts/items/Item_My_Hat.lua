local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	entity = enums.Items.My_Hat,
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = EntityType.ENTITY_PLAYER,
Function = function(_,ent, amt, flag, source, cooldown)
	if ent.Type == 1 then
		local player = ent:ToPlayer()
		if auxi.has_have_coll(player,item.entity) then
			if source ~= nil and source.Type == 9 and source.Entity and source.Entity.PositionOffset then
				local proj = source.Entity:ToProjectile()
				if proj.FallingSpeed > 1 and proj.FallingAccel > 0.2 then
					player:SetColor(Color(1,1,1,1,0.5,0.5,0.5),20,30,true,false)
					return false
				end
			end
			if source ~= nil and source.Entity ~= nil and auxi.isenemies(source.Entity) then
				local col = source.Entity
				local d = source.Entity:GetData()
				if d.is_jumpping and d.is_jumpping > 0 then
					--print("hit1")
					col.Velocity = (player.Position - col.Position):Normalized() * (-30)
					local dmg = player.Damage + 3
					col:TakeDamage(dmg,0,EntityRef(player),10)
					col:SetColor(Color(2,0,0,1,0,0,0),10,30,true,false)
					return false
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_,npc)
	local s = npc:GetSprite()
	--print(s:GetFrame())
	local check = false
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			check = true
		end
	end
	if check == true then
		local d = npc:GetData()
		if s:IsEventTriggered ("Jump") or ((s:IsPlaying("JumpDown") or s:IsPlaying("Land")) and (s:WasEventTriggered ("Land") == false and s:WasEventTriggered ("Landed") == false and s:WasEventTriggered("Hit") == false and s:WasEventTriggered("Shoot") == false)) then
			--print("jump")
			d.is_land = false
			d.is_jumpping = 5
		end
		if s:IsEventTriggered ("Land") or s:IsEventTriggered ("Landed") or (npc.Type == 209 and s:IsEventTriggered("Hit")) or (npc.Type == 68 and s:IsEventTriggered("Shoot")) then
			--print("land")
			d.is_land = true
		end
		if d.is_land and d.is_land == true and d.is_jumpping and d.is_jumpping > 0 then d.is_jumpping = d.is_jumpping - 1 end
	end
end,
})

return item