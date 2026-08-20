local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Tianyi,
	familiar = enums.Familiars.Tiandian,
	familiar2 = FamiliarVariant.GUARDIAN_ANGEL,
	familiar3 = FamiliarVariant.TWISTED_BABY,
	BarRenderOffset = Vector(-10,-30),
}


table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_FAMILIAR_RENDER, params = item.familiar,
Function = function(_,ent,offset)
	local room = Game():GetRoom()
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		local s = ent:GetSprite()
		local d = ent:GetData()
		if d.shoot_cont == nil then d.shoot_cont = 0 end
		if (d.shoot_cont > 0) then
			if d.sprite == nil then
				d.sprite = Sprite()
				d.sprite:Load("gfx/effects/chargebar/chargebar_Tiandian.anm2",true)
				d.sprite:Play("Charging")
			end
			if d.shoot_cont > 100 then
				if d.sprite:IsPlaying("Charging") or d.sprite:IsFinished("Charging") then
					d.sprite:Play("StartCharged",true)
				elseif d.sprite:IsFinished("StartCharged") then
					d.sprite:Play("Charged",true)
				end
			else
				d.sprite:SetFrame("Charging",d.shoot_cont)
			end
		else
			if d.sprite == nil then
				d.sprite = Sprite()
				d.sprite:Load("gfx/effects/chargebar/chargebar_Tiandian.anm2",true)
				d.sprite:SetFrame("Disappear",8)
			end
			if d.sprite:IsPlaying("Disappear") == false and d.sprite:IsFinished("Disappear") == false then
				d.sprite:Play("Disappear",true)
			end
		end
		d.sprite:Render(room:WorldToScreenPosition(ent.Position) + item.BarRenderOffset - Game().ScreenShakeOffset,Vector(0,0),Vector(0,0))
		d.sprite:Update()
	end
end,
})

local function attack(ent,player)
	local q = Isaac.Spawn(7,5,0,ent.Position,Vector(0,0),player):ToLaser()
	local d = ent:GetData()
	q.Parent = ent
	d.now_laser = q
	if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_BFFS) then
		q.CollisionDamage = 5.5
		q:SetTimeout(30)
		ent.HeadFrameDelay = 30
	else
		q.CollisionDamage = 3.5
		q:SetTimeout(20)
		ent.HeadFrameDelay = 20			--设定的圣光时长为20帧
	end
	if player:HasTrinket(TrinketType.TRINKET_BABY_BENDER) then
		q.TearFlags = q.TearFlags | BitSet128(1<<2,0)
	end
	q.Angle = d.lst_dir:GetAngleDegrees()
	q.DepthOffset = 100
	q.PositionOffset = Vector(0,-20)
	return q
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local room = Game():GetRoom()
	local player = ent.Player
	if (player == nil or player:Exists() == false) and ent.SpawnerEntity and ent.SpawnerEntity:ToPlayer() then
		player = ent.SpawnerEntity:ToPlayer()
	end
	local dir = player:GetFireDirection()
	
	if (not d.IsFollowing) then
        ent:AddToFollowers()
        d.IsFollowing = true
    end
	
	if ent.HeadFrameDelay >= 0 then
		ent.HeadFrameDelay = ent.HeadFrameDelay - 1
	end
	
	local dr = auxi.GetfamiliarDir(ent,dir)
	if d.lst_dir == nil then d.lst_dir = Vector(1,0) end
	if dir ~= Direction.NO_DIRECTION and (player == nil or player:IsExtraAnimationFinished()) and ent.HeadFrameDelay < 0 then
		if d.shoot_cont == nil then d.shoot_cont = 0 end
		if d.shoot_cont > 100 then		--蓄力3秒
			if (player:HasCollectible(CollectibleType.COLLECTIBLE_KING_BABY) or player:GetEffects():GetCollectibleEffectNum(CollectibleType.COLLECTIBLE_KING_BABY) > 0) and d.should_attack and d.should_attack == true then
				local q = attack(ent,player)
				d.shoot_cont = 0
			end
		else
			d.shoot_cont = d.shoot_cont + 1
			if player:HasTrinket(TrinketType.TRINKET_FORGOTTEN_LULLABY) and d.shoot_cont <= 100 then
				d.shoot_cont = d.shoot_cont + 1
			end
		end
		d.lst_dir = dr		--记录最后一次射击方向
	else
		if d.shoot_cont == nil then d.shoot_cont = 0 end
		if d.shoot_cont > 100 then		--蓄力3秒
			local q = attack(ent,player)
		end
		d.shoot_cont = 0
		if ent.HeadFrameDelay < 0 then
			d.lst_dir = Vector(0,0)
		end
	end
	
	if d.now_laser and d.now_laser:Exists() and (player:HasCollectible(CollectibleType.COLLECTIBLE_KING_BABY) or player:GetEffects():GetCollectibleEffectNum(CollectibleType.COLLECTIBLE_KING_BABY) > 0) and dr:Length() > 1e-4 then
		d.now_laser.Angle = dr:GetAngleDegrees()
	end
	
	local direction = auxi.GetDirectionByAngle(90)
	if d.lst_dir:Length() > 1e-4 then
		direction = auxi.GetDirectionByAngle(d.lst_dir:GetAngleDegrees())
	end
	if (ent.HeadFrameDelay > 0) then
		local name = "FloatShoot"
		if (direction ~= Direction.NO_DIRECTION) then
			s:Play(name..auxi.GetDirName(direction))
			ent.FlipX = (direction == Direction.LEFT)
		end
    else
		if (d.shoot_cont > 0) then
			local name = "FloatCharge"
			if (direction ~= Direction.NO_DIRECTION) then
				s:Play(name..auxi.GetDirName(direction))
				s:SetFrame(name..auxi.GetDirName(direction),math.floor(d.shoot_cont/3))
				ent.FlipX = (direction == Direction.LEFT)
			end
		else
			local name = "Float"
			if (direction ~= Direction.NO_DIRECTION) then
				s:Play(name..auxi.GetDirName(direction))
				ent.FlipX = (direction == Direction.LEFT)
			end
		end
    end
	
	ent:FollowParent()
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = item.familiar,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
end,
})

return item