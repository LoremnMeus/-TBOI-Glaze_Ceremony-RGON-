-- Zennith P1 common helpers / constants
-- Behavior-equivalent extract from combat_p1.lua (structural only).

local function register(Env)

	Env.M = Env.M or {}
	Env.M.own_key = Env.M.own_key or "Enemies_Zennith_p1_"
	Env.M.P1_FLOOR = Env.M.P1_FLOOR or 0.65
	Env.M.BLOOD_ANM2 = Env.M.BLOOD_ANM2 or "gfx/boss/Zennith/zennith_blood_tear.anm2"
	Env.M.HOLD_HEIGHT = Env.M.HOLD_HEIGHT or -23

	Env.PHASES = {"wind_shift", "form", "release", "dissolve", "rest"}
	Env.ATTACK = {
		wind_sweep = {
			id = "wind_sweep",
			wind_shift = 24,
			form = 24,
			release = 65,
			dissolve = 22,
			rest = 24,
			anim = "AttackSide1",
			label = "风幕横扫",
		},
		wind_split = {
			id = "wind_split",
			wind_shift = 20,
			-- Retreat (~28) + AttackDown1 through Shoot(16) with buffer.
			form = 50,
			-- Flight + hold + three sequential cuts (~12f apart).
			release = 90,
			dissolve = 36,
			rest = 24,
			anim = "AttackDown1",
			label = "风切血雨",
		},
		wind_gust = {
			id = "wind_gust",
			wind_shift = 20,
			form = 60,
			-- Batch flow through most of RELEASE (~100f total spawn window).
			release = 100,
			dissolve = 40,
			rest = 24,
			anim = "AttackDown2",
			label = "骤风弹幕",
		},
	}
	Env.ORDER = {"wind_sweep", "wind_split", "wind_gust"}
	Env.RATE_KEY = Env.wind.own_key .. "rate"
	Env.OBJ_KEY = "qing_zennith_p1_obj"
	Env.HOLD_KEY = Env.M.own_key .. "hold_h"
	Env.HIT_CD = Env.M.own_key .. "hit_cd"
	Env.GUST_SAFE = 80
	Env.GUST_RISE_FROM = -8
	Env.GUST_RATE_TRACTION = 7
	Env.GUST_RATE_BURST = 28
	Env.GUST_ROAR_FRAME = 38
	-- Batch flow window (no live-count gate). Stop new batches late RELEASE.
	Env.GUST_SPAWN_RELEASE_END = 78
	-- Gust V2.6: screen-edge entry + broad visible rise; light player bias only.
	Env.GUST_SCREEN_EXTERNAL_RATIO = 0.30
	Env.GUST_ARENA_VISIBLE_RATIO = 0.60
	Env.GUST_PLAYER_BIAS_RATIO = 0.10
	-- Soft player-bias offset (not a primary corridor length).
	Env.GUST_PLAYER_BIAS_L_MIN = 100
	Env.GUST_PLAYER_BIAS_L_MAX = 170
	Env.GUST_EXTERNAL_MARGIN_MIN = 22
	Env.GUST_EXTERNAL_MARGIN_MAX = 56
	Env.GUST_BURST_MIN = 12
	Env.GUST_BURST_MAX = 18
	Env.GUST_BURST_SUBS = 3
	Env.GUST_BURST_INTERVAL = 3
	Env.GUST_BATCH_INTERVAL = 5
	Env.GUST_BATCH_MIN = 4
	Env.GUST_BATCH_MAX = 5
	Env.GUST_LAT_SPAN = 0.48
	-- Slash templates (Isaac deg: 0=right, 90=down). Shuffled per attack.
	Env.SPLIT_CUT_TEMPLATES = {-45, 45, -90}
	Env.SPLIT_WIND_RATE = 8.5
	Env.SPLIT_AIM_CENTER_W = 0.7
	Env.SPLIT_AIM_PLAYER_W = 0.3
	Env.SPLIT_AIM_BOX = 0.55
	Env.SPLIT_SAFE_PLAYER = 52
	-- Whole-triangle layout: min edge / area before accept.
	Env.SPLIT_TRI_MIN_EDGE = 55
	Env.SPLIT_TRI_MIN_AREA = 1200
	Env.SPLIT_TRI_BASE_SCALE = 62
	-- Minimum hover before a main becomes cut-eligible.
	Env.SPLIT_HOLD_FRAMES = 10
	Env.SPLIT_CUT_GAP = 12
	Env.SPLIT_CHILD_HARMLESS = 4
	Env.SPLIT_ACCEL_FRAMES = 10
	Env.SPLIT_SPEED_START = 4.4
	Env.SPLIT_SPEED_END = 11.0
	Env.SPLIT_FAN_DEG = 82
	Env.SPLIT_MAIN_SCALE = 1.12
	Env.SPLIT_SHOOT_FALLBACK_FRAME = 18
	-- High-speed slash: tip crosses visual center; short blade + trail.
	Env.SPLIT_CUT_DURATION = 5
	Env.SPLIT_CUT_TRAIL = 4
	Env.SPLIT_CUT_APPROACH = 72
	Env.SPLIT_CUT_EXIT = 80
	Env.SPLIT_CUT_BLADE_LEN = 38
	Env.SPLIT_CUT_SHARD_N = 5
	Env.STANCE_DIST_MIN = 80
	Env.STANCE_DIST_MAX = 110
	Env.STANCE_FRAMES = 28
	Env.GUST_SAFE_BOSS = 70
	Env.WALL_OVERSCAN = 110
	Env.ROOM_EXIT_MARGIN = 48
	Env.sessions = Env.sessions or {}

	function Env.ptr(ent)
		if not ent then return nil end
		return GetPtrHash(ent)
	end

	function Env.living(ent)
		return Env.auxi.check_all_exists(ent) and not ent:IsDead() and not ent:HasMortalDamage()
	end

	function Env.hp_ratio(ent)
		if not ent or not ent.MaxHitPoints or ent.MaxHitPoints <= 0 then return 1 end
		return ent.HitPoints / ent.MaxHitPoints
	end

	function Env.room_bounds()
		local room = Game():GetRoom()
		return room:GetTopLeftPos(), room:GetBottomRightPos(), room:GetCenterPos()
	end

	function Env.boss_rand(sess)
		sess.rng = (sess.rng * 1103515245 + 12345) % 2147483648
		return sess.rng / 2147483648
	end

	function Env.angle_lerp(from, to, t)
		local d = to - from
		while d > 180 do d = d - 360 end
		while d < -180 do d = d + 360 end
		return from + d * t
	end

	-- Runtime Env.wind ang uses wind_blow_dir(ang) = FromAngle(ang + 90).
	function Env.wind_dir_vec(ang)
		return Env.wind_physics.wind_blow_dir(ang or 0)
	end

	-- Convert a world travel / aim angle (0 = right) into Env.boss_wind runtime ang.
	function Env.travel_to_wind_ang(travel_deg)
		return (travel_deg or 0) - 90
	end

	function Env.play_anim(boss, name)
		local s = boss:GetSprite()
		if not s then return end
		if s:GetAnimation() ~= name or not s:IsPlaying(name) then
			s:Play(name, true)
		end
	end

	function Env.ensure_idle(boss)
		local s = boss:GetSprite()
		if s and not s:IsPlaying("Idle") then
			s:Play("Idle", true)
		end
	end


end

return {
	register = register,
}
