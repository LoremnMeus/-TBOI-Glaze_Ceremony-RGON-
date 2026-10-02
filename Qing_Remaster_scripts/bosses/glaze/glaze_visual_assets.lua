-- Shared Glaze visual asset paths only. No Boss/Item gameplay state.
-- Paths taken from Item_Crown_of_the_Glaze + Boss palace placeholder.
-- Boss and Item may both read this table; neither may require the other's module.

local Assets = {}

Assets.Crown = {
	anm2 = "gfx/mimics/Glaze Crown/crown_of_glaze.anm2",
	animation = "Float0",
	idle = "Idle",
}

-- Same sheet as the player crown companions / shatter debris.
Assets.CrownShards = {
	{anm2 = "gfx/mimics/Glaze Crown/glaze_shard.anm2", animation = "Shard0"},
	{anm2 = "gfx/mimics/Glaze Crown/glaze_shard.anm2", animation = "Shard1"},
	{anm2 = "gfx/mimics/Glaze Crown/glaze_shard.anm2", animation = "Shard2"},
	{anm2 = "gfx/mimics/Glaze Crown/glaze_shard.anm2", animation = "Shard3"},
}

Assets.Palace = {
	anm2 = "gfx/boss/Glaze/glaze_palace_placeholder.anm2",
	animations = {
		block = "Block",
		long = "Long",
		diamond = "Diamond",
		triangle = "Triangle",
		window = "Window",
		crown_tip = "CrownTip",
	},
}

function Assets.crown_shard(index)
	local list = Assets.CrownShards
	return list[((index - 1) % #list) + 1]
end

return Assets
