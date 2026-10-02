-- Stone / Chess map-layer constants.

local defs = {}

defs.SCHEMA_VERSION = 2
defs.OWN_KEY = "Thread_Stone_"
defs.RUN_KEY = "StoneRun"

defs.ANTE_VARIANT = 23740
defs.FLORAINE_VARIANTS = {
	23752, 23753, 23754, 23755, 23756, 23757, 23758, 23759, 23760, 23761, 23762,
}

defs.DOOR_ANM2 = "gfx/grid/door_checkboarddoor.anm2"
defs.DOOR_STYLE = {
	ROUTE_GATE = "route",
	BOSS_GATE = "boss",
}

defs.ROUTE_DIST_MIN = 3
defs.ROUTE_DIST_MAX = 5
defs.ROUTE_DIST_ACCEPT = {2, 3, 4, 5}

defs.PHASE = {
	DORMANT = "dormant",
	LAYOUT_READY = "layout_ready",
	ORIGIN_FOUND = "origin_found",
	BOARD_ACTIVE = "board_active",
	APPROACHING = "approaching",
	BOSS_READY = "boss_ready",
	BOSS_ENTERED = "boss_entered",
	COMPLETED = "completed",
	ABORTED = "aborted",
	UNAVAILABLE = "unavailable",
}

defs.MARKER = {
	PLAYER_ENTRY = 1,
	RETURN_GATE = 2,
	BOSS_GATE = 3,
	CENTER = 4,
	FLORAINE_ENTRY = 5,
	ORIGIN_ANCHOR = 6,
}

-- Effect room markers: room XML / BR serialize as 999; runtime is ENTITY_EFFECT (1000).
defs.MARKER_ROOM_XML_TYPE = 999
defs.MARKER_RUNTIME_TYPE = EntityType.ENTITY_EFFECT
defs.ROOM_MARKER_NAME = "Stone Room Marker"

defs.BANISH_ROOM = {
	[RoomType.ROOM_SHOP] = true,
	[RoomType.ROOM_TREASURE] = true,
	[RoomType.ROOM_BOSS] = true,
	[RoomType.ROOM_MINIBOSS] = true,
	[RoomType.ROOM_SECRET] = true,
	[RoomType.ROOM_SUPERSECRET] = true,
	[RoomType.ROOM_ARCADE] = true,
	[RoomType.ROOM_CURSE] = true,
	[RoomType.ROOM_CHALLENGE] = true,
	[RoomType.ROOM_LIBRARY] = true,
	[RoomType.ROOM_SACRIFICE] = true,
	[RoomType.ROOM_ANGEL] = true,
	[RoomType.ROOM_DEVIL] = true,
	[RoomType.ROOM_DICE] = true,
	[RoomType.ROOM_ISAACS] = true,
	[RoomType.ROOM_BARREN] = true,
	[RoomType.ROOM_CHEST] = true,
	[RoomType.ROOM_ULTRASECRET] = true,
}

defs.BANISH_TRAVERSE = {
	[RoomType.ROOM_SECRET] = true,
	[RoomType.ROOM_SUPERSECRET] = true,
}

function defs.is_floraine_variant(variant)
	variant = tonumber(variant)
	return variant ~= nil and variant >= 23752 and variant <= 23762
end

function defs.is_ante_variant(variant)
	return tonumber(variant) == defs.ANTE_VARIANT
end

function defs.goto_default(variant)
	return "s.default." .. tostring(variant)
end

return defs
