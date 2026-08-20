local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Dark_Mysticism,
	own_key = "Item_Dark_Mysticism_",
}
auxi.add_to_seija(item.entity)

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,priority = -10,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if player and auxi.has_have_coll(player,item.entity) then
		local rng = player:GetCollectibleRNG(item.entity)
		if rng:RandomFloat() < 0.5 then
			player:SetMinDamageCooldown(cooldown)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2)
			local e1 = Isaac.Spawn(1000,16,2,player.Position,Vector(0,0),player)
			e1:GetSprite().Color = Color(-1,-1,-1,1)
			local e2 = Isaac.Spawn(1000,16,1,player.Position,Vector(0,0),player)
			e2:GetSprite().Color = Color(-1,-1,-1,1)
			for i = 1,4 do 
				local q = Isaac.Spawn(2,0,0,player.Position,auxi.get_by_rotate(nil,i * 90,5),player):ToTear()
				q.TearFlags = q.TearFlags | BitSet128(1<<0,0) | BitSet128(1<<1,0) | BitSet128(1<<2,0) | BitSet128(1<<20,0) --| BitSet128(0,1<<(83-64))
				q.CollisionDamage = player.Damage * 5
				local d2 = q:GetData()
				d2[item.own_key.."effect"] = {}
				local s = q:GetSprite()
				auxi.load_item(item.entity,{sprite = s,})
			end
			if auxi.should_do_Seija(player) then
				player:AddFear(EntityRef(player),3 * 60)
			end
			return false
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = 0,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		--for i = 1,2 do
		if ent.FrameCount % 2 == 1 then
			local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.HAEMO_TRAIL,0,ent.Position,auxi.get_by_rotate(ent.Velocity,-180 + auxi.random_2() * 60,5 + auxi.random_1() * 10),ent):ToEffect()
			d.tail = q
			q.MinRadius = 0.15
			q.MaxRadius = 0.15
			--q:GetSprite().Scale = Vector(0.5,0.5)
			q.Parent = ent
			q.PositionOffset = Vector(0,auxi.height2offset(ent.Height,ent.FallingAcceleration)) + Vector(0,-10)
			q.Color = Color(0.2,0,0.6,1 * auxi.random_1(),0.3,0,0.3)
		end
		--end
		ent.Height = -10
		ent.FallingSpeed = 0
		if ent:IsDead() or ent.FrameCount > 30 * 5 then ent:Remove() end
	end
end,
})

return item