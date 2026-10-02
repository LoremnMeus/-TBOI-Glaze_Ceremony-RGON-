-- Death Field shared constants (XIII - Death?)
local enums = require("Qing_Remaster_scripts.core.enums")

local C = {
	OWN_KEY = "Thoth_cd13r_Dea_",
	SAVE_KEY = "Thoth_cd13r_Dea_field",
	TRINKET_GROUP = "Death_r", -- legacy GroupKey only；新路径走 imitate Qing_Remaster_Imitate_Trinket
	-- 虚影实体：enums.Entities.Death_Field_Proxy（勿用 MeusNil）

	MAX_FIELD_SLOTS = 6,
	MAX_FIELD_SLOTS_CLOTH = 8,

	-- 交互半径：ghost / absorb 统一，不做 Pickup 额外优先圈
	INTERACT_RADIUS = 110,
	ABSORB_RADIUS = 110,

	FOCUS_DIRECTION_BONUS = 20, -- 朝向目标移动时降低 score（更容易接管）
	FOCUS_SWITCH_BIAS = 10, -- 旧目标仍合法时，新目标须明显更优才切换

	HOLD_DROP_FRAMES = 40, -- MC_POST_PLAYER_UPDATE = 60 Hz → ~0.67 s
	MIN_SPACING = 48,
	ROOM_MARGIN = 48, -- norm↔world 可用区 inset，避免贴墙
	INITIAL_RADIUS = 84, -- 首次进场确定性环形半径
	INITIAL_BASE_ANGLE = 22.5, -- 度；半格旋转，减轻挡门

	ALPHA_IDLE = 0.62,
	ALPHA_FOCUS = 1.0,
	ALPHA_FOCUS_UNUSABLE = 0.82, -- soft focus：选中但不可立即发动
	ALPHA_UNCHARGED = 0.42,

	FOCUS_SCALE = 1.12, -- 聚焦且可发动：平滑放大
	FOCUS_LIFT = 0.35, -- 可发动选中：Offset 提亮（无 Colorize）
	FOCUS_LIFT_UNUSABLE = 0.12, -- soft focus：轻度提亮，不放大
	FOCUS_BLEND_SPEED = 0.45, -- 仅 30Hz EFFECT update 推进一次（勿在 render 再 tick）
	ABSORB_FOCUS_BLEND_SPEED = 0.25, -- MC_POST_PLAYER_UPDATE ≈60Hz；紫色进入/离开过渡

	-- 主动格条：相对虚影贴图可见中心的侧向偏移（勿相对实体 pivot / 底座）
	-- OFFSET 为屏幕 px；实际 Render 点还会扣掉条自身 visual-center，使条中心与道具齐平
	UI_CHARGEBAR_ANM2 = "gfx/ui/ui_chargebar.anm2",
	UI_CHARGEBAR_OFFSET = Vector(22, 0),
	-- The Battery 黄色过充层（Offset 叠在 BarFull 上；非 Car Battery）
	BATTERY_YELLOW = Color(1, 1, 1, 1, 0.85, 0.55, 0),
	CHARGE_PULSE_BOOST = 0.45,
	-- 解除长按仍用实体旁 timed 圆条作进度反馈
	HOLD_CHARGEBAR_ANM2 = "gfx/chargebar.anm2",
	HOLD_BAR_OFFSET = Vector(-22, 0),

	-- 虚影可被实体挡住；充能/长按条走 POST_RENDER 队列，不受此值影响
	PROXY_DEPTH_OFFSET = -8,

	CHARGE_PULSE_DECAY = 0.88,

	FOCUS_KEY = "Thoth_cd13r_Dea_focus_uid",
	HOLD_KEY = "Thoth_cd13r_Dea_hold_drop",
	HOLD_UID_KEY = "Thoth_cd13r_Dea_hold_uid",
	FOCUS_BLEND_KEY = "Thoth_cd13r_Dea_focus_blend",
	ABSORB_FOCUS_BLEND_KEY = "Thoth_cd13r_Dea_absorb_focus_blend",

	DATA_UID = "death_field_uid",
	DATA_OWNER = "death_field_owner",
	DATA_TAG = "death_field_proxy",

	-- PRIMARY vanilla 拾取后：待 POST_GAIN 修正主/黄充能
	PENDING_PRIMARY_CHARGE_KEY = "Thoth_cd13r_Dea_pending_primary_charge",

	-- 开场输入保护：隔断打出死神卡的同一次 ACTION_PILLCARD / ITEM / DROP
	-- MC_POST_PLAYER_UPDATE ≈ 60 Hz；4 帧 ≈ 67 ms
	INPUT_GUARD_FRAMES = 4,
	INPUT_GUARD_KEY = "Thoth_cd13r_Dea_input_guard_until",
}

C.ENTITY = enums.Cards.Death_r

return C
