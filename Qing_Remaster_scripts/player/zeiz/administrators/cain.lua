return function(core)
	core.admins.register({
		id = "CAIN",
		name = "Cain",
		name_zh = "该隐",
		player_type = PlayerType.PLAYER_CAIN,
		folly = "CAIN_LOCK_BIAS",
		proposal_item = nil,
		candidate = true,
		eid_folly = {
			zh = "#{{Player2}} 身上至少有{{Key}} 3把钥匙时，房间里的无锁掉落物有几率被锁上#被锁上的掉落物需要再花1把钥匙才能拾取",
			en = "#{{Player2}} With at least {{Key}} 3 keys, unlocked pickups in the room may become locked#Locked pickups cost 1 key to take",
		},
		interest = {
			LOCK = 1.0,
			DENY = 0.5,
		},
	})

	local KEY_NEED = 3
	local LOCK_CHANCE = 0.4
	local SKIP_VARIANT = {
		[PickupVariant.PICKUP_LOCKEDCHEST] = true,
		[PickupVariant.PICKUP_MIMICCHEST] = true,
		[PickupVariant.PICKUP_SPIKEDCHEST] = true,
		[PickupVariant.PICKUP_ETERNALCHEST] = true,
		[PickupVariant.PICKUP_OLDCHEST] = true,
	}

	local function eligible(pickup)
		if not pickup or pickup.Type ~= EntityType.ENTITY_PICKUP then return false end
		if pickup:IsShopItem() then return false end
		if (pickup.Price or 0) ~= 0 then return false end
		if SKIP_VARIANT[pickup.Variant] then return false end
		local d = pickup:GetData()
		if d.zeiz_cain_lock then return false end
		return true
	end

	local function key_count()
		local n = 0
		core.util.each_zeiz(function(player)
			n = n + (player:GetNumKeys() or 0)
		end)
		return n
	end

	core.folly.register("CAIN_LOCK_BIAS", {
		owner = "CAIN",
		OnPickupUpdate = function(ctx)
			local pickup = ctx and ctx.pickup
			if not eligible(pickup) then return end
			if pickup.FrameCount < 2 then return end
			if core.hub.is_open() then return end
			if key_count() < KEY_NEED then return end
			local st = core.admins.state("CAIN")
			st.follyData.locked = st.follyData.locked or {}
			local pid = core.util.pickup_id(pickup)
			if pid and st.follyData.locked[pid] then return end
			local rng = core.util.rng(pickup.InitSeed, 14011)
			if rng:RandomFloat() > LOCK_CHANCE then
				if pid then st.follyData.locked[pid] = "skip" end
				return
			end
			pickup:GetData().zeiz_cain_lock = true
			if pid then st.follyData.locked[pid] = true end
			core.events.emit("LOCK", {
				source = "CAIN",
				targetId = pid,
				room = core.util.room_index(),
			})
		end,
	})
end
