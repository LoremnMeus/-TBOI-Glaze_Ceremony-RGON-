-- Flight 十二宫（392）：每 craft_uid 每层用 Isaac RNG 抽一次已完成星座，写入 counts 虚拟叠加。
-- 不读 GetZodiacEffect()，不临时 AddCollectible；与玩家原版十二宫独立。
local CraftProfile = nil

local item = {
	ToCall = {},
	own_key = "craft_zodiac_",
}

local ZODIAC_ID = CollectibleType.COLLECTIBLE_ZODIAC or 392

-- 只收录已完成且 Flight-safe 的星座（见批次计划批次 5 审计）。
-- Gemini：材料三层已通；抽中时临时 +counts[318] 触发宝宝绑定，换层重抽后自动解绑。
item.ZODIAC_IMPL = {
	[299] = {key = "taurus", zh = "金牛座", en = "Taurus"},
	[304] = {key = "libra", zh = "天平座", en = "Libra"},
	[305] = {key = "scorpio", zh = "天蝎座", en = "Scorpio"},
	[306] = {key = "sagittarius", zh = "射手座", en = "Sagittarius"},
	[307] = {key = "capricorn", zh = "摩羯座", en = "Capricorn"},
	[309] = {key = "pisces", zh = "双鱼座", en = "Pisces"},
	[318] = {key = "gemini", zh = "双子座", en = "Gemini"},
}

local function get_craft_profile()
	if CraftProfile == nil then
		CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
	end
	return CraftProfile
end

function item.get_pool()
	local pool = {}
	for id in pairs(item.ZODIAC_IMPL) do
		pool[#pool + 1] = id
	end
	table.sort(pool)
	return pool
end

function item.stage_key()
	local level = Game() and Game():GetLevel()
	if not level then return 0 end
	local abs = 0
	pcall(function()
		abs = level:GetAbsoluteStage() or 0
	end)
	if abs == 0 then
		pcall(function()
			abs = (level:GetStage() or 0) * 10 + (level:GetStageType() or 0)
		end)
	end
	return abs
end

local function start_seed()
	local s = 1
	pcall(function()
		s = Game():GetSeeds():GetStartSeed() or 1
	end)
	return tonumber(s) or 1
end

function item.roll_effect(craft_uid, stage)
	local pool = item.get_pool()
	if #pool == 0 then return nil end
	local CP = get_craft_profile()
	local uid = tonumber(craft_uid) or 0
	local st = tonumber(stage) or 0
	local rng = CP.derived_rng(start_seed(), uid * 1009 + st * 7919 + ZODIAC_ID)
	local idx = 1
	if rng and rng.RandomInt then
		idx = 1 + rng:RandomInt(#pool)
	end
	return pool[idx]
end

--- 确保 rec 上有本层抽取结果；换 AbsoluteStage 时重抽。
function item.ensure_effect(rec)
	if not rec then return nil end
	local pool = item.get_pool()
	if #pool == 0 then return nil end
	local stage = item.stage_key()
	local effect = tonumber(rec.zodiac_effect)
	if rec.zodiac_abs_stage == stage and effect and item.ZODIAC_IMPL[effect] then
		return effect
	end
	effect = item.roll_effect(rec.uid, stage)
	rec.zodiac_effect = effect
	rec.zodiac_abs_stage = stage
	return effect
end

function item.clear_effect(rec)
	if not rec then return end
	rec.zodiac_effect = nil
	rec.zodiac_abs_stage = nil
end

--- 在 build_profile 中调用：有 392 且可提交时虚拟 +1 抽中星座。
--- 返回 effect_id 或 nil。
function item.apply_to_counts(counts, ctx)
	if not counts then return nil end
	local CP = get_craft_profile()
	if CP.count_of(counts, ZODIAC_ID) <= 0 then return nil end
	local rec = ctx and ctx.rec
	local commit = ctx and (ctx.air ~= nil or ctx.commit_state == true)
	local effect = nil
	if rec and commit then
		effect = item.ensure_effect(rec)
	elseif rec then
		local stage = item.stage_key()
		local e = tonumber(rec.zodiac_effect)
		if rec.zodiac_abs_stage == stage and e and item.ZODIAC_IMPL[e] then
			effect = e
		end
	end
	if not effect then return nil end
	counts[effect] = (tonumber(counts[effect]) or 0) + 1
	return effect
end

function item.effect_label(effect_id, zh)
	local info = item.ZODIAC_IMPL[tonumber(effect_id)]
	if not info then return nil end
	if zh == false then return info.en end
	return info.zh
end

return item
