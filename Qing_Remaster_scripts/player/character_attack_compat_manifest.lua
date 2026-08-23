-- 只描述兼容覆盖，不生成攻击。状态用于审计，禁止据此自动触发道具效果。
local Compat = require("Qing_Remaster_scripts.player.character_attack_compat")

local function effect(id, key, category, status, note)
	Compat.register_effect(id, {key = key, category = category, status = status, note = note})
end

local ALL_IMPLEMENTED = {qing="implemented", tecro="implemented", tainted_tecro="implemented", anna="implemented", tainted_anna="implemented"}
local ALL_NEEDS_PROBE = {qing="needs_probe", tecro="needs_probe", tainted_tecro="needs_probe", anna="needs_probe", tainted_anna="needs_probe"}

-- volley / projectile
effect(55,  "moms_eye",       "volley",     ALL_IMPLEMENTED)
effect(87,  "lokis_horns",    "volley",     ALL_IMPLEMENTED)
effect(558, "eye_sore",       "volley",     ALL_IMPLEMENTED)
effect(444, "lead_pencil",    "cycle",      {qing="implemented", tecro="implemented", tainted_tecro="implemented", anna="implemented", tainted_anna="implemented"})
effect(450, "eye_of_greed",   "cycle",      {qing="implemented", tecro="implemented", tainted_tecro="needs_probe", anna="implemented", tainted_anna="needs_probe"})
effect(373, "dead_eye",       "hit_cycle",  {qing="needs_probe", tecro="implemented", tainted_tecro="implemented", anna="needs_probe", tainted_anna="implemented"})
effect(150, "tough_love",     "projectile", ALL_NEEDS_PROBE, "verify GetTearHitParams versus custom projectile path")
effect(443, "apple",          "projectile", ALL_NEEDS_PROBE, "verify per-projectile RNG and familiar-copy serial")
effect(461, "parasitoid",     "projectile", ALL_NEEDS_PROBE, "verify per-projectile RNG and familiar-copy serial")

-- charge / continuous
effect(69,  "chocolate_milk", "charge",     ALL_IMPLEMENTED)
effect(316, "cursed_eye",     "charge",     {qing="implemented", tecro="implemented", tainted_tecro="implemented", anna="implemented", tainted_anna="implemented"})
effect(440, "kidney_stone",   "charge",     ALL_NEEDS_PROBE)
effect(597, "neptunus",       "charge",     {qing="implemented", tecro="implemented", tainted_tecro="implemented", anna="implemented", tainted_anna="implemented"})
effect(368, "epiphora",       "continuous", ALL_NEEDS_PROBE)
effect(399, "maw_of_void",    "charge",     {qing="needs_probe", tecro="implemented", tainted_tecro="implemented", anna="implemented", tainted_anna="implemented"})
effect(643, "revelation",     "charge",     ALL_NEEDS_PROBE)

-- spawned / on-hurt
effect(410, "evil_eye",       "spawned",    {qing="implemented", tecro="implemented", tainted_tecro="implemented", anna="implemented", tainted_anna="implemented"})
effect(378, "number_two",     "cycle",      ALL_NEEDS_PROBE)
effect(502, "large_zit",      "spawned",    ALL_NEEDS_PROBE)
effect(447, "linger_bean",    "spawned",    ALL_NEEDS_PROBE)
effect(214, "anemic",         "on_hurt",    {qing="inherited", tecro="inherited", tainted_tecro="inherited", anna="inherited", tainted_anna="inherited"})
effect(452, "varicose_veins", "on_hurt",    {qing="inherited", tecro="inherited", tainted_tecro="inherited", anna="inherited", tainted_anna="inherited"})
effect(560, "it_hurts",       "on_hurt",    {qing="inherited", tecro="inherited", tainted_tecro="inherited", anna="inherited", tainted_anna="inherited"})

return Compat
