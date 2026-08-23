local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local enums = require("Qing_Remaster_scripts.core.enums")
local g = require("Qing_Remaster_scripts.core.globals")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local displaying_data = require("Qing_Remaster_scripts.translations.data")
local consistance_holder
local Restock_holder
local save
local addeffe = delay_buffer.addeffe
local funct = {}
local auxi = funct		--

local QingsAirs = Isaac.GetEntityVariantByName("QingsAir")
local MeusLink = Isaac.GetEntityVariantByName("MeusLink")
local QingsMarks = Isaac.GetEntityVariantByName("QingsMark")
local MeusSword = Isaac.GetEntityVariantByName("MeusSword")
local ID_EFFECT_MeusFetus = Isaac.GetEntityVariantByName("MeusFetus")
local ID_EFFECT_MeusRocket = Isaac.GetEntityVariantByName("MeusRocket")
local ID_EFFECT_MeusNIL = Isaac.GetEntityVariantByName("MeusNil")

function funct.get_save()
	save = save or require("Qing_Remaster_scripts.core.savedata")
	return save
end

function funct.REPENTENCE_PLUS()
	return not not FontRenderSettings
end

function funct.GetPlayers()
	local ret = {}
	for i = 0,Game():GetNumPlayers() - 1 do table.insert(ret,#ret + 1,Game():GetPlayer(i)) end
	return ret
end

function funct.get_player_positions()
	local tbl = {}
	for u,v in pairs(auxi.GetPlayers()) do table.insert(tbl,v.Position) end
	return tbl
end

function funct.seed_rng(seed)
	if seed == 0 then seed = -1 end
	local rng = RNG()
	rng:SetSeed(seed,0)
	return rng
end

function funct.rng_for_sake(rng)
	if rng then
		if rng:GetSeed() == 0 then
			rng:SetSeed(-1,0)
		end
		return rng
	else
		return nil
	end
end

function funct.MakeBitSet(i)
	if i >= 64 then
		return BitSet128(0,1<<(i-64))
	else
		return BitSet128(1<<(i),0)
	end
end 

function funct.bitset_flag(x,i)	--获取x第i位是否含有1。
	if i >= 64 then
		return (x & BitSet128(0,1<<(i-64)) == BitSet128(0,1<<(i-64)))
	else
		return (x & BitSet128(1<<(i),0) == BitSet128(1<<(i),0))
	end
end

function funct.Bezier4(v1,v2,v3,v4,t)
	local rt = (1 - t)
	return v1 * rt * rt * rt + 3 * v2 * rt * rt * t + 3 * v3 * rt * rt * t + v4 * t * t * t
end
local Factorecord = {}
function funct.Factorial(val)
	val = math.ceil(val)
	if val <= 1 then return 1 end
	Factorecord[val] = Factorecord[val] or funct.Factorial(val - 1) * val
	return Factorecord[val]
end
function funct.Combination(i,tot) return auxi.Factorial(tot)/(auxi.Factorial(tot - i) * auxi.Factorial(i)) end
function funct.Bezier(vs,t)
	local ct = #vs if ct == 0 then return 0 end
	if t == 0 then return vs[1] elseif t == 1 then return vs[#vs] end
	local tmul = 1 
	local rt = (1 - t)
	local ret = vs[1] - vs[1]
	for i = 1,(ct - 1) do tmul = tmul * rt end
	for i = 1,ct do 
		ret = ret + vs[i] * auxi.Combination(i - 1,ct - 1) * tmul
		tmul = tmul * t/rt
	end
	return ret
end
function funct.Lerp(v1,v2,percent) return v1 * (1 - percent) + v2 * percent end
function funct.onLerp(v1,v2,percent) return v1 + (v2 - v1) * math.max(0,math.min(1,percent)) end
function funct.random_r() return auxi.MakeVector(math.random(3600)/10) end
function funct.random_c(val) if val - math.floor(val) > auxi.random_1() then return math.ceil(val) else return math.floor(val) end end
function funct.random_1() return math.random(1000)/1000 end
function funct.random_0() return math.random(2) * 2 - 3 end
function funct.random_2() return auxi.random_0() * auxi.random_1() * auxi.random_1() end
function funct.random_v() return Vector(auxi.random_1(),auxi.random_1()) end
function funct.random_v2() return Vector(auxi.random_2(),auxi.random_2()) end
function funct.sigmod(x,params) params = params or {} return 1/(1+math.exp(-((params.range2 or 5) * 2) * (x - (params.mid or 0.5))/(params.range or 1))) end

function funct.Count_Flags(x)
	local ret = 0
	for i = 0, math.floor(math.log(x)/math.log(2)) +1 do
		if x%2==1 then
			ret = ret + 1
		end
		x = (x-x%2)/2
	end
	return ret
end

function funct.Get_Flags(x,fl)	--从第0位开始计算flag
	if (math.floor(x/(1<<fl)) %2 == 1) then
		return true
	end
	return false
end

function funct.Get__cos(vec)		--获取Vector类型的角度
	local t = (vec + Vector(vec:Length(),0)):Length()/2
	local q = t/vec:Length()
	return 1 - 2 * q * q
end

function funct.Get__sin(vec)		--获取Vector类型的角度
	local t=(vec + Vector(0,vec:Length())):Length()/2
	q = t/vec:Length()
	return 1 - 2 * q * q
end

function funct.Get__trans(t)			--获取cos对应的sin
	if t > 1 or t < -1 then
		return 0
	end
	return math.sqrt(1-t*t) 
end

function funct.Get_rotate(t) return Vector(-t.Y,t.X) end
function funct.get_by_rotate(v,ang,length) v = v or Vector(0,1)	return funct.MakeVector(ang + v:GetAngleDegrees()) * (length or v:Length()) end

function funct.EqualTable(v1,v2) 
	for u,v in pairs(v1) do if v ~= v2[u] then return false end end
	for u,v in pairs(v2) do if v ~= v1[u] then return false end end
	return true
end
function funct.HasTable(tbl) if tbl == nil then return false end for u,v in pairs(tbl) do return true end return false end
function funct.Manhattan_Distance(v) return math.abs(v.X) + math.abs(v.Y) end
function funct.Manhattan_Distance_(v) return v.X + v.Y end
function funct.plu_s(v1,v2) return v1.X*v2.X+v1.Y*v2.Y end
function funct.mul_t(v1,v2) return Vector(v1.X*v2.X,v1.Y*v2.Y) end
function funct.rev_s(v) return Vector(1/v.X,1/v.Y) end
function funct.MakeVector(x) return Vector(math.cos(math.rad(x)),math.sin(math.rad(x))) end	
function funct.ab_s(v) return Vector(math.abs(v.X),math.abs(v.Y)) end
function funct.do_t(v1,v2) return v1.X * v2.X + v1.Y * v2.Y end
function funct.cros_s(v1,v2) return v1.X * v2.Y - v1.Y * v2.X end
function funct.ProtectVector(v) return Vector(v.X or 1,v.Y or 1) end
function funct.Vector2Table(v) return {X = v.X,Y = v.Y,} end
function funct.RoundVector(rng,leg,params)
	params = params or {}
	if rng then return funct.MakeVector(rng:RandomInt(params.ang or 360) + (params.ang2 or 0)) * (rng:RandomFloat() * (leg or 1) + (params.leg2 or 0))
	else return funct.MakeVector(math.random(params.ang or 360) + (params.ang2 or 0)) * (math.random(1000)/1000 * (leg or 1) + (params.leg2 or 0)) end
end
function funct.SafeVector(v)
	if math.abs(v.X) < 0.00001 then v.X = 0.00001 end
	if math.abs(v.Y) < 0.00001 then v.Y = 0.00001 end
	return v
end
function funct.EqualVector(v1,v2) return (v1 - v2):Length() < 0.001 end
function funct.AntiVector(v)
	local v1 = funct.SafeVector(v)
	return Vector(1/v1.X,1/v1.Y)
end
function funct.bit2table(b)
	local X,Y = 0,0
	for i = 0,63 do if b & BitSet128(1<<i,0) == BitSet128(1<<i,0) then X = X | 1<<i end end 
	for i = 0,63 do if b & BitSet128(0,1<<i) == BitSet128(0,1<<i) then Y = Y | 1<<i end end 
	return {X,Y,}
end
function funct.table2bit(tbl) return BitSet128(tbl[1],tbl[2]) end
local color_adder = {
	["R"] = true,
	["G"] = true,
	["B"] = true,
	["A"] = true,
	["RO"] = true,
	["GO"] = true,
	["BO"] = true,
}
-- RGON：豆浆等激光染色在 Colorize（如 Color.LaserSoy），不只 Tint/Offset
local function read_colorize(c)
	if not c then return 0,0,0,0 end
	if c.GetColorize then
		local t = c:GetColorize()
		if t then
			return t.R or t[1] or 0,t.G or t[2] or 0,t.B or t[3] or 0,t.A or t[4] or 0
		end
	end
	return c.RC or 0,c.GC or 0,c.BC or 0,c.AC or 0
end
local function colorize_empty(r,g,b,a)
	return r == 0 and g == 0 and b == 0 and a == 0
end
local function make_color_with_colorize(r,g,b,a,ro,go,bo,rc,gc,bc,ac)
	local col = Color(r,g,b,a,ro,go,bo)
	if col.SetColorize then
		col:SetColorize(rc or 0,gc or 0,bc or 0,ac or 0)
	end
	return col
end
function funct.get_colorize(c)
	return read_colorize(c)
end
function funct.color2table(c)
	local ret = {}
	for u,_ in pairs(color_adder) do ret[u] = c[u] end
	local rc,gc,bc,ac = read_colorize(c)
	ret.RC,ret.GC,ret.BC,ret.AC = rc,gc,bc,ac
	return ret
end
function funct.table2color(tbl)
	return make_color_with_colorize(
		tbl.R or 1,tbl.G or 1,tbl.B or 1,tbl.A or 1,
		tbl.RO or 0,tbl.GO or 0,tbl.BO or 0,
		tbl.RC or 0,tbl.GC or 0,tbl.BC or 0,tbl.AC or 0
	)
end
function funct.copy_color(c)
	if not c then return Color(1,1,1,1) end
	return funct.table2color(funct.color2table(c))
end
function funct.AddColor(col_1,col_2,x,y,isKColor)
	--local col_2 = {} for u,v in pairs(color_adder) do col_2[u] = col__2[u] or 0 end
	if isKColor then
		return KColor(col_1.R * x + col_2.R * y,col_1.G * x+ col_2.G * y,col_1.B * x+ col_2.B * y,col_1.A * x+ col_2.A * y,col_1.RO * x+ col_2.RO * y,col_1.GO * x+ col_2.GO * y,col_1.BO * x+ col_2.BO * y)
	else
		local r1,g1,b1,a1 = read_colorize(col_1)
		local r2,g2,b2,a2 = read_colorize(col_2)
		return make_color_with_colorize(
			col_1.R * x + col_2.R * y,col_1.G * x + col_2.G * y,col_1.B * x + col_2.B * y,col_1.A * x + col_2.A * y,
			col_1.RO * x + col_2.RO * y,col_1.GO * x + col_2.GO * y,col_1.BO * x + col_2.BO * y,
			r1 * x + r2 * y,g1 * x + g2 * y,b1 * x + b2 * y,a1 * x + a2 * y
		)
	end
end
function funct.MulColor(col_1,col_2)
	local r1,g1,b1,a1 = read_colorize(col_1)
	local r2,g2,b2,a2 = read_colorize(col_2)
	local rc,gc,bc,ac
	-- 一方无 Colorize 时保留另一方（避免 Color(1,1,1,1) 乘掉豆浆激光染色）
	if colorize_empty(r1,g1,b1,a1) then
		rc,gc,bc,ac = r2,g2,b2,a2
	elseif colorize_empty(r2,g2,b2,a2) then
		rc,gc,bc,ac = r1,g1,b1,a1
	else
		rc,gc,bc,ac = r1 * r2,g1 * g2,b1 * b2,a1 * a2
	end
	return make_color_with_colorize(
		col_1.R * col_2.R,col_1.G * col_2.G,col_1.B * col_2.B,col_1.A * col_2.A,
		col_1.RO * col_2.RO,col_1.GO * col_2.GO,col_1.BO * col_2.BO,
		rc,gc,bc,ac
	)
end
function funct.EqualColor(c1,c2) 
	local c = auxi.AddColor(c1,c2,1,-1) 
	local rc,gc,bc,ac = read_colorize(c)
	return c.R == 0 and c.G == 0 and c.B == 0 and c.A == 0 and c.RO == 0 and c.GO == 0 and c.BO == 0
		and colorize_empty(rc,gc,bc,ac)
end
function funct.UpColor(col,rate)
	rate = rate or 1
	local rc,gc,bc,ac = read_colorize(col)
	return make_color_with_colorize(
		col.R,col.G,col.B,col.A,
		col.RO + col.R * rate,col.GO + col.G * rate,col.BO + col.B * rate,
		rc,gc,bc,ac
	)
end
function funct.SimilarColor(c1,c2)
	return (c1.R * c2.R + c1.G * c2.G + c1.B * c2.B)/math.sqrt((c1.R * c1.R + c1.G * c1.G + c1.B * c1.B) * (c2.R * c2.R + c2.G * c2.G + c2.B * c2.B))
end

function funct.height2offset(val,acce) if (acce or 0) > 0.001 then return val else return (val + 25) * 0.4 - 25 end end
function funct.offset2height(val,acce) if (acce or 0) > 0.001 then return val.Y else return (val.Y + 25) / 0.4 - 25 end end

function funct.TearsUp(firedelay, val)
    local currentTears = 30 / (firedelay + 1)
    local newTears = math.max(0.0000001,currentTears + val)
    return (30 / newTears) - 1
end

local real_dir_list = {		--细节：同时按的时候有一个方向做主。
	[4] = Vector(-1.00001,0),
	[5] = Vector(1,0),
	[6] = Vector(0,-1.00001),
	[7] = Vector(0,1),
}

function funct.ggrealdir(player)
	player = player or Game():GetPlayer(0)
	local ret = Vector(0,0)
	local ctrlid = player.ControllerIndex
	for u,v in pairs({4,5,6,7}) do
		if Input.GetActionValue(v,ctrlid) > 0.7 or Input.IsActionTriggered(v,ctrlid) or Input.IsActionPressed(v,ctrlid) then ret = ret + real_dir_list[v] end
	end
	if Game():GetRoom():IsMirrorWorld() == true then ret = Vector(-ret.X,ret.Y) end
	return ret:Normalized()
end

function funct.getdir(player,real)
	player = player or Game():GetPlayer(0)
	if real ~= nil then return funct.ggrealdir(player) end
	local ret = player:GetShootingInput()
	if ret:Length() > 0.05 then
		ret = ret / ret:Length()
	end
	return ret
end

function funct.getmov(player)
	player = player or Game():GetPlayer(0)
	local ret = player:GetMovementInput()
	if ret:Length() > 0.05 then ret = ret / ret:Length() end
	return ret
end

function funct.splitvector(v)
	return {Vector(v.X,0),Vector(0,v.Y)}
end

function funct.g_dir_can_work(player)
	local anim = player:GetSprite():GetAnimation()
	return player:AreControlsEnabled() and player:GetData().should_not_attack ~= true and player:IsExtraAnimationFinished() and not string.match(anim,"PickupWalk")
	--and player.Visible ~= false		--不再检查角色是否可见
end

function funct.has_mark(player)
	local tgs = auxi.getothers(nil,1000)
	for u,v in pairs(tgs) do 
		if v.Variant == 153 or v.Variant == 30 then
			if auxi.check_for_the_same(v.SpawnerEntity,player) then return v end
		end
	end
end

function funct.ggdir(player,ignore_marked,allow_mouse,ignore_mouse_press,center,params)
	params = params or {}
	if params.ignore_canwork == nil and funct.g_dir_can_work(player) == false then return Vector(0,0) end
	if ignore_marked == false then
		if player:HasCollectible(394) or player:HasCollectible(572) then		--别忘了准星！
			local tgs = auxi.getothers(nil,1000)
			for u,v in pairs(tgs) do 
				if v.Variant == 153 or v.Variant == 30 then
					if auxi.check_for_the_same(v.SpawnerEntity,player) then
						local dir = (v.Position - player.Position):Normalized()
						return dir
					end
				end
			end
		end
	end
	local frdr = player:GetFireDirection()			--似乎应该用这个？
	if frdr == Direction.NO_DIRECTION and params.ignore_firedirection ~= true then return Vector(0,0) end		--检测无敌的方式。
	if center == nil then center = player.Position end
	local dir = funct.getdir(player,params.real)
	if dir:Length() < 0.05 then
		if allow_mouse and allow_mouse == true then
			if (player.ControllerIndex == 0) then
				if (Input.IsMouseBtnPressed(0) or ignore_mouse_press) then
					local mspos = funct.mouse_world_pos()
					local leg_pos = (mspos - center)
					if leg_pos:Length() > 10 then
						dir = leg_pos:Normalized()
					elseif ignore_mouse_press then
						if leg_pos:Length() > 1 then
							dir = leg_pos/10
						end
					end
				end
			end
		end
	end
	return dir
end

--- 世界坐标鼠标（含镜子房校正）；供准星追点，勿与 Screen 坐标混用。
function funct.mouse_world_pos()
	local mspos = Input.GetMousePosition(true)
	if Game():GetRoom():IsMirrorWorld() then
		local ui = require("Qing_Remaster_scripts.auxiliary.ui")
		mspos = auxi.mul_t(ui.myScreenToWorld(Isaac.WorldToRenderPosition(Input.GetMousePosition(true))), Vector(-1, 1))
			+ auxi.mul_t(Isaac.ScreenToWorld(auxi.GetScreenSize()), Vector(2, 0))
	end
	return mspos
end

--- 朝目标点追赶：靠近时线性减速，进入死区停稳。避免恒速冲刺在目标附近来回抽搐。
function funct.seek_point_velocity(from_pos, target_pos, max_speed, opts)
	opts = opts or {}
	if not from_pos or not target_pos then return Vector(0, 0) end
	max_speed = tonumber(max_speed) or 0
	if max_speed <= 0 then return Vector(0, 0) end
	local arrive = tonumber(opts.arrive) or 32
	local dead = tonumber(opts.deadzone) or 6
	local to = target_pos - from_pos
	local dist = to:Length()
	if dist <= dead then return Vector(0, 0) end
	local spd = max_speed
	if dist < arrive then
		spd = max_speed * (dist / math.max(arrive, 1e-3))
	end
	return to:Resized(spd)
end

--- 小青准星是否跟鼠标：Always Follow / 左键（原设置）/ 右键（不占用射击，只挪准星）。
function funct.qing_mark_mouse_follow(player, allow_mouse, always_follow, opts)
	opts = opts or {}
	if not player or player.ControllerIndex ~= 0 then return false end
	if opts.block_mouse then return false end
	-- 右键不再跟准星：教程里要拿它切自动/压制。左键仍可鼠标拖准星。
	if allow_mouse == true and (always_follow == true or Input.IsMouseBtnPressed(0)) then
		return true
	end
	return false
end

--- 中键是否按下。切巡航/护卫。只在 POST_RENDER / 准星 Effect 里采信；PLAYER_UPDATE 里 RGON 常读成 false。
function funct.qing_formation_mouse_down(player)
	if not player or player.ControllerIndex ~= 0 then return false end
	return Input.IsMouseBtnPressed(2) == true
end

--- 右键是否按下。切自动/压制；采样限制同中键。
function funct.qing_fire_mouse_down(player)
	if not player or player.ControllerIndex ~= 0 then return false end
	return Input.IsMouseBtnPressed(1) == true
end

--- Ctrl / 配置键 / ACTION_DROP：键盘必须走 controller 0，与蓝图退出键一致。
function funct.qing_formation_key_down(player, extra_key)
	if not player then return false end
	local ctrlp = player.ControllerIndex or 0
	local function key_held(code, idx)
		if code == nil then return false end
		return Input.IsButtonPressed(code, idx) == true
	end
	if Keyboard then
		if key_held(Keyboard.KEY_LEFT_CONTROL, 0) or key_held(Keyboard.KEY_RIGHT_CONTROL, 0) then
			return true
		end
		if ctrlp ~= 0 and (key_held(Keyboard.KEY_LEFT_CONTROL, ctrlp) or key_held(Keyboard.KEY_RIGHT_CONTROL, ctrlp)) then
			return true
		end
		if extra_key ~= nil and extra_key ~= Keyboard.KEY_LEFT_CONTROL and extra_key ~= Keyboard.KEY_RIGHT_CONTROL then
			if key_held(extra_key, 0) or key_held(extra_key, ctrlp) then
				return true
			end
		end
	end
	if Input.IsActionPressed(ButtonAction.ACTION_DROP, ctrlp) == true then
		return true
	end
	if ctrlp ~= 0 and Input.IsActionPressed(ButtonAction.ACTION_DROP, 0) == true then
		return true
	end
	return false
end

--- 中键按下沿：切巡航/护卫。
function funct.qing_mark_control_mouse_triggered(player, data, key)
	data = data or {}
	key = key or "qing_mark_mouse_ctrl"
	local down = funct.qing_formation_mouse_down(player)
	local prev = data[key] == true
	data[key] = down
	return down and not prev
end

--- 右键是否按住：切自动/压制，不走路、不开火。
function funct.qing_mark_middle_mouse_held(player)
	return player ~= nil and player.ControllerIndex == 0 and Input.IsMouseBtnPressed(1) == true
end

--- 小青准星鼠标操控：Always Follow / 按住时追鼠标世界点；否则退回键盘 ggdir。
--- 相对旧实现（方向×恒速、中心=准星自身）可消除贴鼠标偶发抖动。
function funct.qing_mark_velocity(player, mark, allow_mouse, always_follow, opts)
	opts = opts or {}
	if not player or not mark then return Vector(0, 0) end
	local max_spd = (tonumber(opts.max_speed) or (player.ShotSpeed * 15))
	local use_mouse = funct.qing_mark_mouse_follow(player, allow_mouse, always_follow, opts)
	if use_mouse then
		local want = funct.seek_point_velocity(mark.Position, funct.mouse_world_pos(), max_spd, {
			arrive = opts.arrive or 36,
			deadzone = opts.deadzone or 7,
		})
		local d = mark:GetData()
		local key = opts.smooth_key or "qing_mark_mouse_vel"
		local prev = d[key]
		local blend = tonumber(opts.blend)
		if blend == nil then blend = 0.4 end
		blend = math.max(0.05, math.min(1, blend))
		if prev then
			want = Vector(prev.X * (1 - blend) + want.X * blend, prev.Y * (1 - blend) + want.Y * blend)
		end
		d[key] = Vector(want.X, want.Y)
		return want
	end
	local dir = funct.ggdir(player, true, false, false, mark.Position, opts.ggdir_params)
	return dir * max_spd
end

function funct.ggmov_dir_is_zero(player,SPQinghelper,allow_mouse,upon_click,center)		--传入player与一个辅助参数。
	if SPQinghelper == nil then SPQinghelper = false end
	if player:AreControlsEnabled() == false and SPQinghelper == true then
		return false
	end
	if (player:IsExtraAnimationFinished() == false) and SPQinghelper == true then		--or player.Visible == false
		return false
	end
	local dir = funct.ggdir(player,false,allow_mouse,upon_click,center)
	local mov = funct.getmov(player)
	return (dir:Length() < 0.05 and mov:Length() < 0.05)
end

function funct.getpickups(ents,ignore_items)
	ents = ents or Isaac.GetRoomEntities()
	local pickups = {}
    for _, ent in pairs(ents) do
        if ent.Type == 5 and (ignore_items == false or ent.Variant ~= 100) then
            pickups[#pickups + 1] = ent
        end
    end
	return pickups
end

function funct.isenemies(ent)
	if ent and ent:IsVulnerableEnemy() and ent:IsActiveEnemy() and not ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return true end
	return false
end

function funct.is_friendly(ent)
	if ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return true end
	return false
end

function funct.protect_projectile(ent,q)
	local succ = auxi.is_friendly(ent)
	if ent:ToProjectile() then local pf = ent:ToProjectile().ProjectileFlags if pf & (1<<31) == (1<<31) then succ = true end end
	if succ and q:ToProjectile() then q = q:ToProjectile() q.ProjectileFlags = q.ProjectileFlags | 1<<31 end
	return succ
end

function funct.getenemies(ents,checker)
	checker = checker or true
	ents = ents or Isaac.GetRoomEntities()
	local enemies = {}
    for _, ent in pairs(ents) do
        if funct.isenemies(ent) and funct.check_if_any(checker,ent) then
            enemies[#enemies + 1] = ent
        end
    end
	return enemies
end

local movable_list = {
	[33] = true,
	[292] = true,
}

function funct.is_movable(ent)
	if funct.check_if_any(movable_list[ent.Type],ent) then return true 
	else return false end
end

function funct.getmovable(ents)
	local targs = {}
    for _, ent in pairs(ents) do
		if funct.is_movable(ent) then table.insert(targs,#targs + 1,ent) end
    end
	return targs
end

function funct.get_nearest_(tbl,pos_)		--pos_可以传入function作为距离计算函数		--似乎还应该传入比较函数
	tbl = tbl or {}
	pos_ = pos_ or function(tg) local tpos = tg.Position local pos = Game():GetPlayer(0).Position return (pos - tpos):Length() end
	local targ = tbl[1]
	local tu = 1
	if targ then 
		local dis = auxi.check_if_any(pos_,targ)
		for u,v in pairs(tbl) do
			local leg = auxi.check_if_any(pos_,v)
			if leg < dis then
				targ = v
				tu = u
				dis = leg
			end
		end
		return {tg = targ,tu = tu,dis = dis,}
	end
end

function funct.get_nearest(tbl,pos)
	tbl = tbl or {}
	pos = pos or Game():GetPlayer(0).Position
	local targ = tbl[1]
	local tu = 1
	if targ then 
		local dis = (targ.Position - pos):Length()
		for u,v in pairs(tbl) do
			local leg = (v.Position - pos):Length()
			if leg < dis then
				targ = v
				tu = u
				dis = leg
			end
		end
		return {tg = targ,tu = tu,dis = dis,}
	end
end

function funct.get_nearest_enemy(enemies,pos,val)
	enemies = enemies or funct.getenemies()
	pos = pos or Game():GetPlayer(0).Position
	local targ = enemies[1]
	if targ then 
		local dis = (targ.Position - pos):Length()
		for u,v in pairs(enemies) do
			local leg = (v.Position - pos):Length()
			if val then leg = auxi.check_if_any(val,leg,v) or leg end
			if leg < dis then
				targ = v
				dis = leg
			end
		end
	end
	return targ
end

function funct.get_farest_enemy(enemies,pos)
	if pos == nil or enemies == nil or #enemies == 0 then return nil end
	local targ = enemies[1]
	local dis = (targ.Position - pos):Length()
	for u,v in pairs(enemies) do
		local leg = (v.Position - pos):Length()
		if leg > dis then
			targ = v
			dis = leg
		end
	end
	return targ
end

function funct.get_by_nearest_enemy(pos,checker)
	return funct.get_nearest_enemy(funct.getenemies(Isaac.GetRoomEntities(),checker),pos)
end

function funct.get_by_farest_enemy(pos,checker)
	return funct.get_farest_enemy(funct.getenemies(Isaac.GetRoomEntities(),checker),pos)
end

function funct.getothers(ents,x,y,z,check_funct)
	if type(ents) == "number" then z = y y = x x = ents ents = nil end
	ents = ents or Isaac.GetRoomEntities()
	local targs = {}
    for _, ent in pairs(ents) do
        if x == nil or ent.Type == x then
			if y == nil or ent.Variant == y then
				if z == nil or ent.SubType == z then
					if check_funct == nil or check_funct(ent) == true then
						targs[#targs + 1] = ent
					end
				end
			end
        end
    end
	return targs
end

function funct.getothers_in_table(ents,x,y,z,check_funct)
	local tbl = {}
    for _, ent in pairs(ents) do
        if x == nil or ent.Type == x or x == 0 then
			local x_tbl = tbl
			if x == 0 then 
				if tbl[ent.Type] == nil then tbl[ent.Type] = {} end
				x_tbl = tbl[ent.Type] 
			end
			if y == nil or ent.Variant == y or y == 0 then
				local y_tbl = x_tbl
				if y == 0 then 
					if x_tbl[ent.Variant] == nil then x_tbl[ent.Variant] = {} end
					y_tbl = x_tbl[ent.Variant] 
				end
				if z == nil or ent.SubType == z or z == 0 then
					local z_tbl = y_tbl
					if z == 0 then 
						if y_tbl[ent.Variant] == nil then y_tbl[ent.Variant] = {} end
						z_tbl = y_tbl[ent.Variant] 
					end
					if check_funct == nil or check_funct(ent) == true then
						table.insert(z_tbl,ent)
					end
				end
			end
        end
    end
	return tbl
end

function funct.getmultishot(cnt1,cnt2,id,cnt3)		--cnt1:总数量；cnt2：巫师帽数量；cnt3：宝宝套
	local cnt = math.ceil(cnt1/cnt2)		--此为每一弹道发射的眼泪数。不计入宝宝套给予的额外2发。
	if cnt3 == 1 and cnt2 < 3 then
		cnt = math.ceil((cnt1-2)/cnt2)
	end
	if cnt2 > 2 then
		cnt3 = 0
	end
	local dir = 180 / (cnt2+1)
	local inv1 = 30			--非常奇怪，存在巫师帽的时候，那个间隔随着cnt增大而减小，并不是特别好测量，因此我也就意思一下了（，不存在的时候，大概是10到5度角左右。
	local inv2 = 5 + cnt
	local inv3 = 5
	if cnt3 == 1 then			--存在宝宝套
		if cnt2 == 1 then		--单弹道+宝宝套
			if id == 1 then			--冷知识：宝宝套两个方向的弹道实际上不对称！不过我才懒得做适配……
				return 45
			elseif id == cnt1 then
				return 135
			else
				return 90 - (cnt-1)/2 * inv3 + (id-2) * inv3			--考虑以5度为间隔，关于90度镜像阵列。
			end
		else		--巫师帽宝宝套，双弹道多发。
			if id - 1 > cnt then
				return 45 - (cnt-1)/2 * inv2 + (id - cnt - 1) * inv2
			else
				return 135 - (cnt-1)/2 *inv2 + (id - 1) * inv2
			end
		end
	else
		local grp = math.floor((id-1)/cnt)	--id号攻击属于的弹道数（0到cnt2-1）
		if cnt2 ~= 1 then
			return (grp + 1) * dir - (cnt-1)/2 * inv1 + (id-1 - grp * cnt) * inv1
		else
			return (grp + 1) * dir - (cnt-1)/2 * inv2 + (id-1 - grp * cnt) * inv2
		end
	end
end

function funct.trychangegrid(x)
	if x == nil or x.CollisionClass == nil then
		return
	end
	x.CollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
end

function funct.tryremovegrid(id,force)
	local room = Game():GetRoom()
	room:RemoveGridEntity(id,0,false)
	if force then
		delay_buffer.addeffe(function(params)
			room:SpawnGridEntity(id, 1, 0, 0, 0)
			local ggent = room:GetGridEntity(id)
			if ggent then
				local s2 = ggent:GetSprite()
				s2:ReplaceSpritesheet(0,"gfx/effects/nill.png")
				s2:LoadGraphics()
			end
		end,{},2)
	end
end

function funct.getdisenemies(enemies,pos,rang)
	local ret = nil
	local ran = rang
	if ran == nil then
		ran = 1000
	end
	for _,ent in pairs(enemies) do
		if ent ~= nil and (ent.Position - pos):Length()< ran then
			ran = (ent.Position - pos):Length()
			ret = ent
		end
	end
	return ret
end

function funct.getrandenemies(enemies) return auxi.random_in_table(enemies) end

function funct.check_rand(luck,maxum,zeroum,threshold)		--幸运；上限（0-100）；下限；幸运阈值
	local rand = math.random(10000)/10000
	if rand * 100 < math.exp(math.min(luck/5,threshold/5))/math.exp(threshold/5) * (maxum - zeroum) + zeroum then
		return true
	else
		return false
	end
end

function funct.check(ent)
	return ent ~= nil and ent:Exists() and (not ent:IsDead())
end

local solid_list = {
	[2] = true,
	[3] = true,
	[4] = true,
	[5] = true,
	[6] = true,
	[11] = true,
	[12] = true,
	[13] = true,
	[14] = true,
	[21] = true,
	[22] = true,
	[24] = true,
	[25] = true,
	[26] = true,
	[27] = true,
}

local destroy_list = {
	[1] = {
		[2] = true,
		[3] = true,
		[4] = true,
		[5] = true,
		[6] = true,
		[22] = true,
		[25] = true,
		[26] = true,
		[27] = true,
	},
	[2] = {
		[2] = true,
		[3] = true,
		[4] = true,
		[5] = true,
		[6] = true,
		[22] = true,
		[25] = true,
		[26] = true,
		[27] = true,
	},
	[3] = {
		[2] = true,
		[3] = true,
		[4] = true,
		[5] = true,
		[6] = true,
		[11] = true,
		[12] = true,
		[13] = true,
		[14] = true,
		[21] = true,
		[22] = true,
		[24] = true,
		[25] = true,
		[26] = true,
		[27] = true,
	},
}
local grid_remove_list = {
	[GridEntityType.GRID_ROCK] = 1,
	[GridEntityType.GRID_ROCKB] = 1,
	[GridEntityType.GRID_ROCKT] = 1,
	[GridEntityType.GRID_ROCK_BOMB] = 1,
	[GridEntityType.GRID_ROCK_ALT] = 1,
	[GridEntityType.GRID_LOCK] = 1,
	[GridEntityType.GRID_TNT] = 1,
	[GridEntityType.GRID_POOP] = 1,
	[GridEntityType.GRID_STATUE] = 1,
	[GridEntityType.GRID_ROCK_SS] = 1,
	[GridEntityType.GRID_ROCK_SPIKED] = 1,
	[GridEntityType.GRID_ROCK_ALT2] = 1,
	[GridEntityType.GRID_ROCK_GOLD] = 1,
	[GridEntityType.GRID_PIT] = 2,
	[GridEntityType.GRID_SPIKES] = 2,
	[GridEntityType.GRID_SPIKES_ONOFF] = 2,
	[GridEntityType.GRID_PILLAR] = 2,
	[GridEntityType.GRID_SPIDERWEB] = 2,
	[GridEntityType.GRID_GRAVITY] = 2,
}
local grid_remove_collision_list = {
	[GridCollisionClass.COLLISION_SOLID] = true,
	[GridCollisionClass.COLLISION_OBJECT] = true,
	[GridCollisionClass.COLLISION_PIT] = true,
}
function funct.is_removeable_grid(gent)
	local info = grid_remove_list[gent:GetType()]
	if (info == 1 and grid_remove_collision_list[gent.CollisionClass]) or info == 2 then return true end
	return false
end

local cannot_open_door = {
	[-10] = true,
	[-7] = true,
	[-1] = true,
}

function funct.issolid(grid)
	if grid == nil then return false end
	if solid_list[grid:GetType()] then
		return grid.CollisionClass ~= 0
	end
	return false
end

function funct.try_destroy_grid(grid,mode)
	if grid == nil then return false end
	local can_destroy = destroy_list[mode] or destroy_list[1]
	if funct.issolid(grid) and can_destroy[grid:GetType()] then
		grid:Destroy(true)
		if grid:GetType() == 5 then 
			Game():BombExplosionEffects(grid.Position,100,BitSet128(0,0))
		end
		return true
	end
	if grid:GetType() == 16 then		--试图开门
		if math.random(1000) > 800 then
			local door = grid:ToDoor()
			if door and door:CanBlowOpen() and door:IsOpen() == false and door:IsLocked() == false and cannot_open_door[door.TargetRoomIndex] ~= true then
				door:TryBlowOpen(false,nil)
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_ROCK_CRUMBLE,1,1,false,0,2)
				return true
			end
		end
	end
	return false
end

function funct.check_pos_for_door(dooridx,dir,inner)
	local room = Game():GetRoom()
	inner = inner or 18
	local pos = Game():GetRoom():GetGridPosition(dooridx)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		--if room:GetGridIndex(player.Position + dir * inner) == dooridx then	return player end
		if (player.Position - (pos - dir * inner)):Length() < 25 then return player end
	end
	return false
end
--l local player = Game():GetPlayer(0) print(player.Position) print(player.Size)

function funct.iswall(grident)
	if grident == nil then return false end
	if grident:GetType() == 15 then
		return grident.CollisionClass ~= 0
	end
	return false
end
function funct.copyColor(c) return auxi.AddColor(c,Color(0,0,0,0),1,0) end
function funct.copyVec(v) return Vector(v.X,v.Y) end
function funct.TryCopy(v)
	if type(v) == "userdata" and v.X and v.Y then return funct.copyVec(v) end
	if type(v) == "table" then return funct.deepCopy(v) end
	return v
end
function funct.copy(tbl)
    local ret = {}
    for key, val in pairs(tbl) do
        ret[key] = val
    end
    return ret
end

function funct.deepCopy(tb)
    if tb == nil then
        return nil
    end
	if type(tb) ~= "table" then return tb end
    local copy = {}
    for k, v in pairs(tb) do
        if type(v) == 'table' then
            copy[k] = funct.deepCopy(v)
        else
            copy[k] = v
        end
    end
    setmetatable(copy, funct.deepCopy(getmetatable(tb)))
    return copy
end
funct.deepcopy = funct.deepCopy

function funct.realdeepCopy(tb)			--此函数已被下方替代
    if tb == nil then
        return nil
    end
    local copy = {}
    for k, v in pairs(tb) do
        if type(v) == 'table' then
			if v._r == nil then 
				v._r = k
			end
            copy[v._r] = funct.realdeepCopy(v)
        else
            copy[k] = v
        end
    end
    setmetatable(copy, funct.realdeepCopy(getmetatable(tb)))
    return copy
end

function funct.realrealdeepCopy(tb)	
	if type(tb) ~= 'table' then return tb end
    local copy = {}
    for k, v in pairs(tb) do
		if type(k) == 'number' or type(v) == 'table' then
		else copy[k] = v end
    end
    for k, v in pairs(tb) do
		if type(k) == 'number' or type(v) == 'table' then
			table.insert(copy,#copy + 1,{_r = k,_v = funct.realrealdeepCopy(v),})
		end
    end
    setmetatable(copy, funct.realrealdeepCopy(getmetatable(tb)))
    return copy
end

function funct.irealrealdeepCopy(tb)
	if type(tb) ~= 'table' then return tb end
	-- 新格式混在旧树里时仍要展开，避免整树走 legacy 后 __f=m 原样残留
	if tb.__f == "m" or tb.__f == "cc" or tb.__f == "tc" then
		return funct.unpack_from_save(tb)
	end
    local copy = {}
    for k, v in pairs(tb) do
		if type(v) == 'table' then
			-- _r 可能为 0，不能用 `or`
			local val = v._r
			if val == nil then val = k end
			if type(val) == "string" then
				local n = tonumber(val)
				if n and n == math.floor(n) and tostring(n) == val then
					val = n
				end
			end
			copy[val] = funct.irealrealdeepCopy(v._v or v)
		else
			copy[k] = v
		end
    end
    setmetatable(copy, funct.irealrealdeepCopy(getmetatable(tb)))
    return copy
end

-- Isaac json 对象键一律是字符串；平行数组里的数字值偶发也会变成字符串。
-- 仅还原「纯整数字面量」键/值，保留 "01" / "1.5" 等非规范字符串。
local function save_restore_numkey(k)
	if type(k) == "number" then
		if k == math.floor(k) then return k end
		return k
	end
	if type(k) == "string" then
		local n = tonumber(k)
		if n and n == math.floor(n) and tostring(n) == k then
			return n
		end
	end
	return k
end

-- 兼容 k/v 被错误编成 {"1":x,"2":y} 时 #arr==0 的情况
local function save_parallel_len(arr)
	if type(arr) ~= "table" then return 0 end
	local n = #arr
	if n > 0 then return n end
	for k,_ in pairs(arr) do
		local idx = tonumber(k)
		if idx and idx == math.floor(idx) and idx > n then
			n = idx
		end
	end
	return n
end

local function save_parallel_at(arr, i)
	local v = arr[i]
	if v ~= nil then return v end
	return arr[tostring(i)]
end

local function save_is_dense_array(tb)
	local n = #tb
	if n <= 0 then return false end
	local count = 0
	for k,_ in pairs(tb) do
		if type(k) ~= "number" or k ~= math.floor(k) or k < 1 or k > n then
			return false
		end
		count = count + 1
	end
	return count == n
end

local function save_has_legacy_rv(tb)
	-- 叶子 {_r,_v} 自身也算 legacy（旧检测只看子表会漏）
	if tb._r ~= nil then return true end
	for _,v in pairs(tb) do
		if type(v) == "table" and v._r ~= nil then
			return true
		end
	end
	return false
end

-- 落盘用紧凑拷贝：稠密数组保持数组；仅 type(number) 键进平行 k/v。
-- 禁止把 "0"/"1" 等字符串整数字面量收进 map：蓝图 by_player/prototypes 等故意用 tostring 键，
-- 若被收成数字键，读档后运行时仍查 ["0"] 会整袋丢失。真正的数字键 JSON 进对象后由 unpack 的
-- __f=m 路径还原；遗留纯对象数字图留给各模块 heal（如 DVF）。
-- 旧存档仍由 unpack_from_save → irealrealdeepCopy 兼容。
function funct.pack_for_save(tb)
	if type(tb) ~= "table" then return tb end
	if save_is_dense_array(tb) then
		local arr = {}
		for i = 1,#tb do
			arr[i] = funct.pack_for_save(tb[i])
		end
		return arr
	end

	local obj = {}
	local map_k = {}
	local map_v = {}
	for k,v in pairs(tb) do
		if type(k) == "number" then
			map_k[#map_k + 1] = k
			map_v[#map_v + 1] = funct.pack_for_save(v)
		elseif type(v) == "table" then
			obj[k] = funct.pack_for_save(v)
		else
			obj[k] = v
		end
	end
	if #map_k > 0 then
		-- 稳定顺序，便于 diff / 压缩率
		local order = {}
		for i = 1,#map_k do order[i] = i end
		table.sort(order, function(a,b) return map_k[a] < map_k[b] end)
		local sk, sv = {}, {}
		for i = 1,#order do
			local idx = order[i]
			sk[i] = map_k[idx]
			sv[i] = map_v[idx]
		end
		obj.__f = "m"
		obj.k = sk
		obj.v = sv
	end
	return obj
end

local function sort_parallel_by_key(keys, vals)
	local order = {}
	for i = 1,#keys do order[i] = i end
	table.sort(order, function(a,b) return keys[a] < keys[b] end)
	local sk, sv = {}, {}
	for i = 1,#order do
		local idx = order[i]
		sk[i] = keys[idx]
		sv[i] = vals[idx]
	end
	return sk, sv
end

-- collectible_counter：运行时 { [player]={num,list={[id]=n}} } → 落盘平行数组
function funct.pack_collectible_counter(counter)
	local pk, pn, pi, pc = {}, {}, {}, {}
	local idxs = {}
	for idx,data in pairs(counter or {}) do
		local nidx = save_restore_numkey(idx)
		if type(nidx) == "number" and type(data) == "table" then
			idxs[#idxs + 1] = nidx
		end
	end
	table.sort(idxs)
	for _,idx in ipairs(idxs) do
		local data = counter[idx] or counter[tostring(idx)]
		pk[#pk + 1] = idx
		pn[#pn + 1] = data.num or 0
		local ids, counts = {}, {}
		for id,cnt in pairs(data.list or {}) do
			local nid = save_restore_numkey(id)
			if type(nid) == "number" and (cnt or 0) ~= 0 then
				ids[#ids + 1] = nid
				counts[#counts + 1] = cnt
			end
		end
		ids, counts = sort_parallel_by_key(ids, counts)
		pi[#pi + 1] = ids
		pc[#pc + 1] = counts
	end
	return {__f = "cc", k = pk, n = pn, i = pi, c = pc}
end

function funct.unpack_collectible_counter(blob)
	if type(blob) ~= "table" then return {} end
	if blob.__f ~= "cc" then
		return funct.unpack_from_save(blob)
	end
	local out = {}
	local keys = blob.k or {}
	local n = save_parallel_len(keys)
	for i = 1,n do
		local list = {}
		local ids = blob.i and save_parallel_at(blob.i, i) or {}
		local counts = blob.c and save_parallel_at(blob.c, i) or {}
		local idn = save_parallel_len(ids)
		for j = 1,idn do
			list[save_restore_numkey(save_parallel_at(ids, j))] = save_parallel_at(counts, j)
		end
		out[save_restore_numkey(save_parallel_at(keys, i))] = {
			num = blob.n and save_parallel_at(blob.n, i) or 0,
			list = list,
		}
	end
	return out
end

-- trinket_counter：{ [player]={[trinketId]=mult} }
function funct.pack_trinket_counter(counter)
	local pk, pi, pc = {}, {}, {}
	local idxs = {}
	for idx,data in pairs(counter or {}) do
		local nidx = save_restore_numkey(idx)
		if type(nidx) == "number" and type(data) == "table" then
			idxs[#idxs + 1] = nidx
		end
	end
	table.sort(idxs)
	for _,idx in ipairs(idxs) do
		local data = counter[idx] or counter[tostring(idx)]
		pk[#pk + 1] = idx
		local ids, counts = {}, {}
		for id,cnt in pairs(data) do
			local nid = save_restore_numkey(id)
			if type(nid) == "number" and (cnt or 0) ~= 0 then
				ids[#ids + 1] = nid
				counts[#counts + 1] = cnt
			end
		end
		ids, counts = sort_parallel_by_key(ids, counts)
		pi[#pi + 1] = ids
		pc[#pc + 1] = counts
	end
	return {__f = "tc", k = pk, i = pi, c = pc}
end

function funct.unpack_trinket_counter(blob)
	if type(blob) ~= "table" then return {} end
	if blob.__f ~= "tc" then
		return funct.unpack_from_save(blob)
	end
	local out = {}
	local keys = blob.k or {}
	local n = save_parallel_len(keys)
	for i = 1,n do
		local list = {}
		local ids = blob.i and save_parallel_at(blob.i, i) or {}
		local counts = blob.c and save_parallel_at(blob.c, i) or {}
		local idn = save_parallel_len(ids)
		for j = 1,idn do
			list[save_restore_numkey(save_parallel_at(ids, j))] = save_parallel_at(counts, j)
		end
		out[save_restore_numkey(save_parallel_at(keys, i))] = list
	end
	return out
end

-- 支持纯数字键映射，以及 {str..., __f="m", k=..., v=...} 混合表；兼容旧 {_r,_v}
-- 对象上的字符串键保持字符串（含 "0"/"1"）；只有 __f=m 的 k[] 才还原为数字键。
function funct.unpack_from_save(tb)
	if type(tb) ~= "table" then return tb end
	if tb.__f == "cc" then
		return funct.unpack_collectible_counter(tb)
	end
	if tb.__f == "tc" then
		return funct.unpack_trinket_counter(tb)
	end
	if tb.__f == "m" then
		local copy = {}
		for k,v in pairs(tb) do
			if k ~= "__f" and k ~= "k" and k ~= "v" then
				-- 混合表的字符串字段（prototypes/drafts/by_player 槽名）不得 tonumber
				if type(v) == "table" then
					copy[k] = funct.unpack_from_save(v)
				else
					copy[k] = v
				end
			end
		end
		local keys = tb.k or {}
		local vals = tb.v or {}
		local n = math.max(save_parallel_len(keys), save_parallel_len(vals))
		for i = 1,n do
			local key = save_restore_numkey(save_parallel_at(keys, i))
			copy[key] = funct.unpack_from_save(save_parallel_at(vals, i))
		end
		return copy
	end
	-- legacy {_r,_v} 放在 __f 之后：避免带 _r 字段的无关表误吞整个新格式树
	if save_has_legacy_rv(tb) then
		return funct.irealrealdeepCopy(tb)
	end
	if save_is_dense_array(tb) then
		local arr = {}
		for i = 1,#tb do
			arr[i] = funct.unpack_from_save(tb[i])
		end
		return arr
	end
	local copy = {}
	for k,v in pairs(tb) do
		-- 保持 JSON 对象键的字符串形态；数字图遗留由业务 heal（DVF 等）
		if type(v) == "table" then
			copy[k] = funct.unpack_from_save(v)
		else
			copy[k] = v
		end
	end
	return copy
end

function funct.fire_nil(position,velocity,params)		--可以传入的是cooldown和player，其他参数将在之后添加。
	params = params or {}
	if position == nil or velocity == nil then
		return nil
	end
	local q1 = Isaac.Spawn(EntityType.ENTITY_EFFECT, ID_EFFECT_MeusNIL, 0, position, velocity, nil)
	local d = q1:GetData()
    local s = q1:GetSprite()
    s:Play("Idle", true)
	
	d.removecd = params.cooldown or 60
	d.player = params.player
	d.Params = funct.copy(params)
	return q1
end

function funct.getshotinfo(player,params)
	params = params or {}
	local ret = {mx = 1,lw = 1,}
	if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CHOCOLATE_MILK) then ret.mx = 2 ret.lw = 1/5 end
	if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_MONSTROS_LUNG) and params.Extra then ret.lw = 1/5 end
	if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CURSED_EYE) then ret.mx = 5 end
	if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_NEPTUNUS) then ret.lw = math.min(ret.lw,1/2) end
	if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_SOY_MILK) or auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_ALMOND_MILK) then ret.lw = 1/10 end
	return ret
end

local attack_list_calculator
local function get_attack_list_calculator()
	-- 必须在 mod 初始化阶段已预加载；回调里再 require 会被 Isaac/MCM 中文的 require 包装成 not found
	if not attack_list_calculator then
		attack_list_calculator = package.loaded["Qing_Remaster_scripts.player.attack_list_calculator"]
			or require("Qing_Remaster_scripts.player.attack_list_calculator")
	end
	return attack_list_calculator
end

function funct.getmultishots(player,allowrand)
	return get_attack_list_calculator().getmultishots(player,allowrand)
end

function funct.getQingshots(player,allowrand)
	return get_attack_list_calculator().getQingshots(player,allowrand)
end

function funct.get_Qing_multishots(player,list,params)
	return get_attack_list_calculator().get_Qing_multishots(player,list,params)
end

function funct.get_Tecro_multishots(player,list,params)
	return get_attack_list_calculator().get_Tecro_multishots(player,list,params)
end

function funct.get_Tecrorun_multishots(player,list,params)
	return get_attack_list_calculator().get_Tecrorun_multishots(player,list,params)
end

function funct.get_Anna_multishots(player,list,params)
	return get_attack_list_calculator().get_Anna_multishots(player,list,params)
end

function funct.step_faster(cnt)
	return get_attack_list_calculator().step_faster(cnt)
end

function funct.get_cascade_info(i,tot)
	return get_attack_list_calculator().get_cascade_info(i,tot)
end

function funct.get_Anna2_multishots(player,list,params)
	return get_attack_list_calculator().get_Anna2_multishots(player,list,params)
end

function funct.get_Tecro_list(player)
	return get_attack_list_calculator().get_Tecro_list(player)
end

function funct.get_Anna_list(player)
	return get_attack_list_calculator().get_Anna_list(player)
end
function funct.fire_needle(position,velocity,params)
	params = params or {}
	local player = params.player or Game():GetPlayer(0)
	position = position or player.Position
	velocity = velocity or Vector(0.00001,0)
	local q1 = params.source or Isaac.Spawn(EntityType.ENTITY_EFFECT, enums.Entities.TecroNeedleNil, 0, position, velocity, player)
	local d1 = q1:GetData()
    local s1 = q1:GetSprite()
    s1:Play("Idle", true)
	d1.player = player
	
	local q2 = Isaac.Spawn(8,enums.Entities.Tecro_Needle,0,Vector(2000,0),velocity,player):ToKnife()
	local s2 = q2:GetSprite()
	local d2 = q2:GetData()
	q2.Parent = q1
	q1.Child = q2
	d1.needle = q2
	
	d2.Sec_this_spear = Isaac.Spawn(1000,enums.Entities.TecroThisNil,0,position, velocity, player)
	d2.Sec_this_spear.Parent = q2
	d2.Sec_this_spear:GetData().position_offset = Vector(0,20)
	
	q2.RotationOffset = params.dir or velocity:GetAngleDegrees()
	--print(q2.RotationOffset)
	d2.player = player
	d2.tearflags = player.TearFlags
	
	local tosetsize = {size1 = 5,size2 = Vector(1,4),size3 = 5,scale = Vector(1,1)}		--大小控制
	
	if params.size and params.size2 and params.size1 then
		tosetsize.size1 = params.size
		tosetsize.size2 = params.size1
		tosetsize.size3 = params.size2
	end
	if params.size_scale then
		tosetsize.scale = params.size_scale
	end
	
	if tosetsize then
		q2:SetSize(tosetsize.size1,tosetsize.size2,tosetsize.size3)
		d2.to_set_size = tosetsize
		s2.Scale = tosetsize.scale
	end
	d2.Tecro_needle_damage = params.dmg or player.Damage
	
	return q2
end

function funct.fire_spear(position,velocity,params)
	params = params or {}
	local player = params.player or Game():GetPlayer(0)
	position = position or player.Position
	velocity = velocity or Vector(0.00001,0)
	local q1 = params.source or Isaac.Spawn(EntityType.ENTITY_EFFECT, enums.Entities.TecroNil, 0, position, velocity, player)
	local d1 = q1:GetData()
    local s1 = q1:GetSprite()
    s1:Play("Idle", true)
	d1.player = player
	
	local q2 = Isaac.Spawn(8,enums.Entities.Tecro_Spear,0,Vector(2000,0),velocity,player):ToKnife()
	local s2 = q2:GetSprite()
	local d2 = q2:GetData()
	q2.Parent = q1
	q1.Child = q2
	d1.spear = q2
	
	d2.Sec_this_spear = Isaac.Spawn(1000,enums.Entities.TecroThisNil,0,position, velocity, player)
	d2.Sec_this_spear.Parent = q2
	d2.Sec_this_spear:GetData().position_offset = Vector(0,20)
	
	q2.RotationOffset = params.dir or velocity:GetAngleDegrees()
	d2.player = player
	d2.tearflags = player.TearFlags
	
	local tosetsize = {size1 = 5,size2 = Vector(1,4),size3 = 5,scale = Vector(1,1)}		--大小控制
	
	if params.size and params.size2 and params.size1 then
		tosetsize.size1 = params.size
		tosetsize.size2 = params.size1
		tosetsize.size3 = params.size2
	end
	if params.size_scale then
		tosetsize.scale = params.size_scale
	end
	
	if tosetsize then
		q2:SetSize(tosetsize.size1,tosetsize.size2,tosetsize.size3)
		d2.to_set_size = tosetsize
		s2.Scale = tosetsize.scale
	end
	
	d2.Tecro_spear_damage = params.dmg or player.Damage
	
	return q2
end

function funct.fire_laser_spear(position,velocity,params)
	params = params or {}
	local player = params.player or Game():GetPlayer(0)
	position = position or player.Position
	velocity = velocity or Vector(0.00001,0)
	local q1 = params.source or Isaac.Spawn(EntityType.ENTITY_EFFECT, enums.Entities.TecroLaserNil, 0, position, velocity, player)
	local d1 = q1:GetData()
    local s1 = q1:GetSprite()
    s1:Play("Idle", true)
	d1.player = player
	
	local q2 = Isaac.Spawn(8,enums.Entities.Tecro_Spear,0,Vector(2000,0),velocity,player):ToKnife()
	local s2 = q2:GetSprite()
	local d2 = q2:GetData()
	q2.Parent = q1
	q1.Child = q2
	d1.spear = q2
	
	q2.RotationOffset = params.dir or velocity:GetAngleDegrees()
	d2.player = player
	d2.tearflags = player.TearFlags
	
	local tosetsize = {size1 = 5,size2 = Vector(1,4),size3 = 5,scale = Vector(1,1)}		--大小控制
	
	if params.size and params.size2 and params.size1 then
		tosetsize.size1 = params.size
		tosetsize.size2 = params.size1
		tosetsize.size3 = params.size2
	end
	if params.size_scale then
		tosetsize.scale = params.size_scale
	end
	
	if tosetsize then
		q2:SetSize(tosetsize.size1,tosetsize.size2,tosetsize.size3)
		d2.to_set_size = tosetsize
		s2.Scale = tosetsize.scale
	end
	
	d2.Tecro_spear_damage = params.dmg or player.Damage
	
	return q2
end

function funct.fire_knife(position,velocity,dmg,targ,params)	--params可以传入：cooldown，player，tearflags，Color,Explosive,PosOffset,hold_knife_path
	local q1 = params.source or Isaac.Spawn(EntityType.ENTITY_EFFECT, ID_EFFECT_MeusNIL, 0, position, velocity, nil)
	local d = q1:GetData()
    local s = q1:GetSprite()
    local player = params.player or Game():GetPlayer(0)
	
	s:Play("Idle", true)
	q1.Parent = targ
	d.removecd = params.cooldown or 120
	d.player = player
	d.follower = params.follower
	d.Damage = dmg
    d.Params = funct.copy(params)
	if params.PosOffset then
		q1.PositionOffset = params.PosOffset
	end
	
	local q2 = params.knife or Isaac.Spawn(EntityType.ENTITY_KNIFE, 0, 0, Vector(2000,0),velocity:Normalized(), nil):ToKnife()
	local s2 = q2:GetSprite()
	local d2 = q2:GetData()
	s2:Play("Idle")
	q2.Parent = q1
	q1.Child = q2
	q1:GetData().fired_knife = q2
	q2.CollisionDamage = dmg
	q2.RotationOffset = velocity:GetAngleDegrees()
	if params.PosOffset then
		q2.PositionOffset = params.PosOffset
	end
	-- 供 POST_KNIFE_UPDATE 维持路径/高度（Shoot 回程会改 PathOffset）
	d2.knife_flight = {
		PosOffset = params.PosOffset,
		hold_knife_path = params.hold_knife_path == true,
		peak_path = 0,
	}
	if params.player then
		d2.player = params.player
	end
	if params.Explosive and params.Explosive > 0 then
		d2.Explosive_cnt = params.Explosive
	end
	if params.tearflags then
		q2.TearFlags = params.tearflags
	end
	if params.Color then
		q2:SetColor(params.Color,3,99,false,false)
	end
	if params.Brim then
		local q3 = player:FireBrimstone(-velocity,nil,0.4)
		q3.PositionOffset = params.PosOffset or Vector(0,0)
		q3.Parent = q2
		q3.Position = q2.Position
		q3.TearFlags = q3.TearFlags & (~TearFlags.TEAR_WAIT)
		q3:SetTimeout(params.cooldown)
		q3.MaxDistance = math.sqrt(player.TearRange) * 3
		d2.Knife_link_brimstone = q3
	end
	return q2
end

--- 飞行器妈刀：MeusNil 当独立刀柄，由 FireKnife 完成引擎武器初始化。
--- 锚点跟飞行器位置（不是把刀 Parent 到机体）；刀仍挂在 Nil 上。
--- 飞出期间飞行器停住，避免机体把刀带着飞、射程看起来过长。
--- CantOverwrite=false 且每把刀使用独立 Nil，不会覆写玩家或其他宝宝的刀。
--- 生成当帧先藏 2 帧；knife_flight 让宝宝武器压制跳过这把刀。
function funct.fire_engine_knife(parent, direction, dmg, params)
	params = params or {}
	local player = params.player or Game():GetPlayer(0)
	local dir = direction
	if not dir or dir:Length() < 0.01 then
		dir = Vector(1, 0)
	end
	dir = dir:Normalized()
	local ang = dir:GetAngleDegrees()
	local pos = params.position or (parent and parent.Position) or player.Position
	local q1 = Isaac.Spawn(EntityType.ENTITY_EFFECT, ID_EFFECT_MeusNIL, 0, pos, Vector.Zero, nil)
	local d = q1:GetData()
	d.player = player
	d.removecd = params.cooldown or 300
	d.Params = funct.copy(params)
	d.Params.Accerate = nil
	d.skip_nil_distance_cull = true
	if parent and parent.Exists and parent:Exists() then
		d.follower = parent
		d.ignore_follower_distance = true
		d.nw_follow_pos = Vector(0, 0)
		d.Params.remove_with_ent = parent
	end
	q1.Velocity = Vector.Zero
	if params.PosOffset then
		q1.PositionOffset = params.PosOffset
	end
	-- 裸 Spawn 的 ENTITY_KNIFE 缺少玩家武器内部状态，Shoot/IsFlying 会失效。
	-- FireKnife 的 RotationOffset 就是初始射击角；不要在 Update 再强写 Rotation。
	local q2 = player:FireKnife(q1, ang, false, 0, 0)
	if not q2 then
		q1:Remove()
		return nil
	end
	q2.Parent = q1
	q1.Child = q2
	d.fired_knife = q2
	q2.SpawnerEntity = parent or player
	q2.CollisionDamage = dmg
	-- FireKnife 已用 RotationOffset 参数初始化方向；不要再把它清零。
	local hide_coll = q2.EntityCollisionClass
	q2.Visible = false
	q2.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	q1.Visible = false
	if params.PathOffset ~= nil then
		q2.PathOffset = params.PathOffset
	end
	if params.PosOffset then
		q2.PositionOffset = params.PosOffset
	end
	local d2 = q2:GetData()
	d2.params = funct.copy(params)
	d2.knife_flight = {
		PosOffset = params.PosOffset,
		hold_knife_path = false,
		engine_throw = true,
		remove_after_return = params.remove_after_return ~= false,
		hide_frames = 2,
		coll_class = hide_coll,
		peak_path = 0,
		air = parent,
		craft_air = params.craft_air or parent,
		aim_ang = ang,
	}
	if params.player then
		d2.player = params.player
	end
	if params.Explosive and params.Explosive > 0 then
		d2.Explosive_cnt = params.Explosive
	end
	if params.tearflags then
		q2.TearFlags = params.tearflags
	end
	if params.Color then
		q2:SetColor(params.Color, 3, 99, false, false)
	end
	return q2
end

function funct.fire_lung(pos,vel,player,params)
	player = player or Game():GetPlayer(0)
	pos = pos or player.Position
	params = params or {}
	local shot_speed = params.shot_speed or player.ShotSpeed
	vel = vel or ((params.dir or Vector(1,0)) * shot_speed * 10)
	local ret = {}
	local cnt = params.cnt or (12 + math.random(8))
	for i = 1,cnt do 
		local q = player:FireTear(pos,auxi.get_by_rotate(vel,auxi.random_2() * 12,vel:Length() * (1 + auxi.random_2() * 0.3)),true,true,true)
		if params.dmg then q.CollisionDamage = params.dmg * (params.dmgrate or 1)
		else q.CollisionDamage = (params.dmg or q.CollisionDamage) * (params.dmgrate or 1) end
		q.FallingSpeed = -7.5 + auxi.random_2() * 5
		q.FallingAcceleration = 0.5
		q.Scale = q.Scale * (1.2 + auxi.random_2() * 0.3)
		q:ResetSpriteScale()
		if params.Posoffset then q.PositionOffset = params.Posoffset end
		table.insert(ret,#ret + 1,q)
	end
	return ret
end

function funct.fire_anti_lung(pos,vel,ent,params)
	pos = pos or player.Position
	params = params or {}
	vel = vel or ((params.dir or Vector(1,0)) * 10)
	local ret = {}
	local cnt = params.cnt or (12 + math.random(8))
	for i = 1,cnt do 
		local q = Isaac.Spawn(9,0,0,pos,auxi.get_by_rotate(vel,auxi.random_2() * 12,vel:Length() * (1 + auxi.random_2() * 0.3)),ent):ToProjectile() auxi.protect_projectile(ent,q)
		--q.CollisionDamage = (params.dmg or q.CollisionDamage) * (params.dmgrate or 1)
		q.FallingSpeed = -7.5 + auxi.random_2() * 5
		q.FallingAccel = 0.5
		q.Scale = q.Scale * (1.2 + auxi.random_2() * 0.3)
		--q:ResetSpriteScale()
		table.insert(ret,#ret + 1,q)
	end
	return ret
end

function funct.fire_lung_bomb(pos,vel,player,params)
	player = player or Game():GetPlayer(0)
	pos = pos or player.Position
	params = params or {}
	local shot_speed = params.shot_speed or player.ShotSpeed
	vel = vel or ((params.dir or Vector(1,0)) * shot_speed * 10)
	local Bomb_holder = require("Qing_Remaster_scripts.mimics.Bomb_holder")
	local ret = {}
	local cnt = params.cnt or (4 + math.random(2))
	for i = 1,cnt do 
		local q = player:FireBomb(pos,auxi.get_by_rotate(vel,auxi.random_2() * 24,vel:Length() * (1 + auxi.random_2() * 0.5)),player)
		q.RadiusMultiplier = 0.3 + auxi.random_1() * 0.5
		q.PositionOffset = params.PosOffset or params.Posoffset or Vector(0,0)
		if params.dmg and q.ExplosionDamage then
			q.ExplosionDamage = params.dmg * (params.dmgrate or 1)
		end
		local d = q:GetData()
		d[Bomb_holder.own_key.."effect"] = {
			Sprite = "gfx/items/pick ups/bombs/bomb"..tostring(auxi.choose(0,1))..".anm2",
			FVel = auxi.random_1() * 20,
			FAcce = auxi.random_2() * 0.5 + 2,
		}
		table.insert(ret,#ret + 1,q)
	end
	return ret
end
--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") auxi.fire_lung_bomb()
local buff_list = {BitSet128(1<<2,0),BitSet128(1<<16,0),BitSet128(1<<30,0),BitSet128(1<<19,0),BitSet128(1<<33,0),BitSet128(0,1<<5),}
function funct.fire_Tech_5_laser(player,pos,dir,params)
	params = params or {}
	player = player or params.player or Game():GetPlayer(0)
	pos = pos or player.Position
	dir = dir or Vector(1,0)
	local q = player:FireTechLaser(pos,params.id or 0,dir,false,true)
	for u,v in pairs(buff_list) do 
		if math.random(1000) > 800 then q:AddTearFlags(v) end
	end
	return q
end

function funct.fire_lung_Laser(player,pos,dir,params)
	params = params or {}
	player = player or params.player or Game():GetPlayer(0)
	pos = pos or player.Position
	dir = dir or Vector(1,0)
	local Lung_laser_holder = require("Qing_Remaster_scripts.mimics.Lung_laser_holder")
	local cnt = auxi.check_if_any(params.cnt) or auxi.choose(11,12,13)
	local ret = {}
	for i = 1,cnt do
		local q = Lung_laser_holder.fire_one_lung_laser(player,pos,0,auxi.get_by_rotate(auxi.check_if_any(dir),auxi.random_2() * (params.angle or 40)),(params.legth or 80) + auxi.random_2() * (params.leg2 or 50),params)
		local d = q:GetData()
		d[Lung_laser_holder.own_key.."effect"] = {
			mul = auxi.check_if_any(params.mul) or auxi.choose(1,2,3),
			ang = (params.angle or 40),
			leg = (params.legth or 80),
			leg2 = (params.leg2 or 50),
			player = player,
			Posoffset = params.Posoffset,
		}
		if params.dmg and q.CollisionDamage ~= nil then
			q.CollisionDamage = params.dmg * (params.dmgrate or 1)
		end
		table.insert(ret, #ret + 1, q)
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_REDLIGHTNING_ZAP_BURST,1,1,false,0,2)
	return ret
end
--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") auxi.fire_lung_Laser()
function funct.fire_Sword(position,velocity,dmg,targ,params)
	local q1 = funct.fire_knife(position,velocity,dmg,targ,params)
	local s = q1:GetSprite()
	if params.Tech then s:Load("gfx/player/qing/Qing_tech_Sword.anm2", true)
	else s:Load("gfx/player/qing/Qing_spirit_Sword.anm2",true) end
	if params.Qing then s:Load("gfx/player/daggers/store_it/008.2335_NormalSword.anm2", true) end
	q1.RotationOffset = params.RotationOffset or q1.RotationOffset
	if params.del_RotationOffset then
		q1.RotationOffset = q1.RotationOffset + params.del_RotationOffset
	end
	if q1.RotationOffset > 180 then q1.RotationOffset = q1.RotationOffset - 360 end
	if q1.RotationOffset < -180 then q1.RotationOffset = q1.RotationOffset + 360 end
	local initial_sz = 100
	if params.Attack then
		s:Play("AttackRight",true)
		if q1.RotationOffset < -90.0001 or q1.RotationOffset > 90.0001 then
			s:Play("AttackRight2",true)
		end
		initial_sz = 60
	else
		s:Play("SpinRight",true)
		if q1.RotationOffset < -90.0001 or q1.RotationOffset > 90.0001 then
			s:Play("SpinRight2",true)
		end
	end
	local tosetsize = {size1 = initial_sz,size2 = Vector(1,1),size3 = 5,scale = Vector(1,1)}
	
	if params.size and params.size2 and params.size1 then
		tosetsize.size1 = params.size
		tosetsize.size2 = params.size1
		tosetsize.size3 = params.size2
	end
	if params and params.list and params.list.pol and params.list.pol ~= 0 then
		local pol = params.list.pol
		tosetsize.size1 = tosetsize.size1 * (1 + pol)
		tosetsize.size2 = Vector(tosetsize.size2.X * 2,tosetsize.size2.Y * 2)
		tosetsize.size3 = tosetsize.size3 * (1 + pol)
		tosetsize.scale = Vector(2,(1 + pol))
	end
	if params and params.list and ((params.list.soy and params.list.soy ~= 0) or (params.list.soy2 and params.list.soy2 ~= 0))  then
		local rang = 1
		if (params.list.soy and params.list.soy ~= 0) then
			rang = 0.25
		end
		if (params.list.soy2 and params.list.soy2 ~= 0) then
			rang = 0.35
		end
		local cho_counter = params.list.cho_counter
		tosetsize.size1 = tosetsize.size1 * rang
		tosetsize.scale = tosetsize.scale * rang
	end
	if params and params.list and params.list.hae and params.list.hae ~= 0 then
		local hae = params.list.hae
		tosetsize.size1 = tosetsize.size1 * (1 + hae * 0.4)
		tosetsize.scale = tosetsize.scale * (1 + hae * 0.4)
	end
	
	if tosetsize then
		q1:SetSize(tosetsize.size1,tosetsize.size2,tosetsize.size3)
		s.Scale = tosetsize.scale
	end
	return q1
end

function funct.fire_rocket(pos,vel,player,params)
	local q
	local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
	if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_ROCKET_IN_A_JAR) == false then
		Imitate_item_holder.assign_fake_item(player,CollectibleType.COLLECTIBLE_ROCKET_IN_A_JAR,true)
		q = player:FireBomb(pos,vel)
		Imitate_item_holder.re_assign_fake_item()
	else
		q = player:FireBomb(pos,vel)
	end
	return q
end

function funct.tear_damage_to_fetus_scale(tear,player)
	local dmg = tear.CollisionDamage
	local scale = 3
	if dmg < 1 then scale = 1
	elseif dmg < 2.5 then scale = 2
	elseif dmg < 6 then scale = 3
	elseif dmg < 20 then scale = 4
	else scale = 5 end
	if player:HasCollectible(149) then scale = math.max(1,scale - 2) end
	if player:HasCollectible(659) or player:HasCollectible(336) or player:HasCollectible(309) then scale = math.min(5,scale + 1) end
	return tostring(scale)
end

local Sec_buffs = {
	[579] = {TearFlags = BitSet128(0,1<<(107-64)),},
	[704] = {check = function(player) if player:GetEffects():HasCollectibleEffect(704) then return true end end,TearFlags = BitSet128(0,1<<(108-64)),},
	[114] = {TearFlags = BitSet128(0,1<<(109-64)),},
	[395] = {TearFlags = BitSet128(0,1<<(110-64)),},
	[68] = {TearFlags = BitSet128(0,1<<(111-64)),},
	[118] = {TearFlags = BitSet128(0,1<<(112-64)),},
	[52] = {TearFlags = BitSet128(0,1<<(113-64)),},
}

function funct.fire_fetus(q,player,pos,vel,CanBeEye,CanTriggerStreakEnd,params)
	params = params or {}
	player = player or Game():GetPlayer(0)
	q = q or player:FireTear(pos or (player.Position + player.Velocity),vel or player.Velocity,CanBeEye or true,true,CanTriggerStreakEnd or true)
	q.TearFlags = q.TearFlags | BitSet128(0,1<<(114-64)) | (params.tearflags or BitSet128(0,0))
	q.CollisionDamage = params.dmg or q.CollisionDamage
	local s = q:GetSprite()
	local d = q:GetData()
	s:Load("gfx/mimics/Dr_Fetus/my_fetus tear.anm2",true)
	s:Play("Rotate"..funct.tear_damage_to_fetus_scale(q,player),true)
	if params.should_not_sound == nil then sound_tracker.PlayStackedSound(SoundEffect.SOUND_PLOP,1,1,false,0,2) end
	q.Variant = 50
	-- 制造路径：跳过玩家 Sec_buffs 采样，仅用显式 sec_flags（或稍后由 apply_fetus_sec_flags 补写）。
	if params.skip_player_sec_sample then
		if params.sec_flags then
			q.TearFlags = q.TearFlags | params.sec_flags
		end
	else
		for u,v in pairs(Sec_buffs) do if (v.check == nil and auxi.has_have_coll(player,u)) or auxi.check_if_any(v.check,player) then q.TearFlags = q.TearFlags | (v.TearFlags or BitSet128(0,0)) end end
	end
	return q
end

function funct.replace_dagger_graph(ent,replace_name)
	if replace_name == nil or ent == nil then return end
	local s = ent:GetSprite()
	local r_name = "gfx/player/daggers/"..replace_name..".png"
	for i = 0,2 do
		s:ReplaceSpritesheet(i,r_name)
	end
	s:ReplaceSpritesheet(4,r_name)
	s:LoadGraphics()
end

local sharp_time = {
	[CollectibleType.COLLECTIBLE_SPIRIT_OF_THE_NIGHT] = 1,
	[CollectibleType.COLLECTIBLE_DEAD_DOVE] = 1,
	[CollectibleType.COLLECTIBLE_THE_WIZ] = 1,
	[CollectibleType.COLLECTIBLE_CONTINUUM] = 1,
	[CollectibleType.COLLECTIBLE_TINY_PLANET] = 1,
	[CollectibleType.COLLECTIBLE_PUPULA_DUPLEX] = 1,
	[CollectibleType.COLLECTIBLE_DEAD_ONION] = 1,
	[CollectibleType.COLLECTIBLE_SPIRIT_SWORD] = 3,
}

local sharp_time_trinket = {
	[TrinketType.TRINKET_BRAIN_WORM] = 2,
	[TrinketType.TRINKET_OUROBOROS_WORM] = 1,
}

function funct.get_sharp_time(player)
	player = player or Game():GetPlayer(0)
	local ret = 0
	for u,v in pairs(sharp_time) do
		if player:HasCollectible(u) or player:GetEffects():HasCollectibleEffect(u) then
			if type(v) == "function" then v = v(player) end
			ret = ret + (v or 0)
		end
	end
	for u,v in pairs(sharp_time_trinket) do
		if player:HasTrinket(v) then
			if type(v) == "function" then v = v(player) end
			ret = ret + (v or 0)
		end
	end
	return ret
end

local sharp_rate = {	
	[CollectibleType.COLLECTIBLE_CUPIDS_ARROW] = 1,
	[CollectibleType.COLLECTIBLE_OUIJA_BOARD] = 1,
	[CollectibleType.COLLECTIBLE_MOMS_KNIFE] = 2,
	[CollectibleType.COLLECTIBLE_SACRIFICIAL_DAGGER] = 1,
	[CollectibleType.COLLECTIBLE_SMB_SUPER_FAN] = function(player) if player:GetMaxHearts() > 6 then return 1 end end,
	[CollectibleType.COLLECTIBLE_SHARP_PLUG] = function(player) if player:NeedsCharge() then return 1 end end,
	[CollectibleType.COLLECTIBLE_GUILLOTINE] = function(player) if player:GetData().damaged_sharp_rate then return 1 end end,
	[CollectibleType.COLLECTIBLE_DEATHS_TOUCH] = function(player) if player:NeedsCharge() then return 1 end end,
	[CollectibleType.COLLECTIBLE_SCREW] = function(player) if player.MaxFireDelay <= 5 then return 1 end end,
	[CollectibleType.COLLECTIBLE_SAGITTARIUS] = 1,
	[CollectibleType.COLLECTIBLE_DEAD_ONION] = 1,
	[CollectibleType.COLLECTIBLE_SAFETY_PIN] = function(player) if player.ShotSpeed >= 2 then return 1 end end,
	[CollectibleType.COLLECTIBLE_8_INCH_NAILS] = function(player) if player.Damage >= 10 then return 1 end end,
	[CollectibleType.COLLECTIBLE_SPEAR_OF_DESTINY] = 1,
	[CollectibleType.COLLECTIBLE_ATHAME] = function(player) if player:GetData().damaged_sharp_rate then return 1 end end,
	[CollectibleType.COLLECTIBLE_SHARD_OF_GLASS] = function(player) if player:GetData().damaged_sharp_rate then return 1 end end,
	[CollectibleType.COLLECTIBLE_EYE_OF_BELIAL] = 2,
	[CollectibleType.COLLECTIBLE_FINGER] = function(player) if player.Damage >= 10 then return 1 end end,
	[CollectibleType.COLLECTIBLE_BACKSTABBER] = function(player) if player.Luck >= 5 then return 1 end end,
	[CollectibleType.COLLECTIBLE_POINTY_RIB] = function(player) if player.Luck >= 5 then return 1 end end,
	[CollectibleType.COLLECTIBLE_BLOOD_OATH] = function(player) if player.Damage >= 10 then return 1 end end,
	[CollectibleType.COLLECTIBLE_DAMOCLES] = 1,
	[CollectibleType.COLLECTIBLE_DAMOCLES_PASSIVE] = 1,
	[CollectibleType.COLLECTIBLE_SHARP_KEY] = 1,
	[CollectibleType.COLLECTIBLE_KNIFE_PIECE_2] = 1,
	[CollectibleType.COLLECTIBLE_SANGUINE_BOND] = function(player) if player:GetSoulHearts() <= 4 then return 1 end end,
	[CollectibleType.COLLECTIBLE_TOOTH_AND_NAIL] = 1,
	[CollectibleType.COLLECTIBLE_DARK_ARTS] = function(player) if player.MoveSpeed >= 1.7 then return 1 end end,
	[CollectibleType.COLLECTIBLE_STAPLER] = 1,
	[CollectibleType.COLLECTIBLE_IV_BAG] = function(player) if player:GetHearts() == 0 then return 1 end end,
}

local sharp_rate_trinket = {
	[TrinketType.TRINKET_PUSH_PIN] = 1,
}

function funct.get_sharp_rate(player)
	player = player or Game():GetPlayer(0)
	local ret = 0
	for u,v in pairs(sharp_rate) do
		if player:HasCollectible(u) or player:GetEffects():HasCollectibleEffect(u) then
			if type(v) == "function" then v = v(player) end
			ret = ret + (v or 0)
		end
	end
	if player:HasPlayerForm(PlayerForm.PLAYERFORM_DRUGS) then
		ret = ret + 1
	end
	if player:HasPlayerForm(PlayerForm.PLAYERFORM_MOM) then
		if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_KNIFE) or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_MOMS_KNIFE) or player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_RAZOR) or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_MOMS_RAZOR) then
			ret = ret + 1
		end
	end
	for u,v in pairs(sharp_rate_trinket) do
		if player:HasTrinket(v) then
			if type(v) == "function" then v = v(player) end
			ret = ret + (v or 0)
		end
	end
	if ret < 0 then ret = 0 end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_POLYPHEMUS) or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_POLYPHEMUS) then
		if ret > 2 then
			ret = ret + 2
		end
	end
	return ret
end

function funct.get_qing_list(player)
	return get_attack_list_calculator().get_qing_list(player)
end

function funct.get_epic_list(player)
	return get_attack_list_calculator().get_epic_list(player)
end

function funct.launch_Missile(pos,vel,tearHitParams,targ,params)
	params = params or {}
	local player = params.player or Game():GetPlayer(0)
	local recipe_only = params.Dontautocheck == true or params.craft_profile ~= nil
	if tearHitParams == nil then
		if recipe_only then
			tearHitParams = {
				TearFlags = params.tearflags or params.tearflag or BitSet128(0, 0),
				TearColor = params.color or Color(1, 1, 1, 1),
				TearDamage = params.dmg or 3.5,
				TearVariant = params.tear_variant or TearVariant.BLUE,
			}
		else
			tearHitParams = player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1))
		end
	end
	if params.Dontautocheck ~= true then
		local tbl = auxi.get_epic_list(player)
		for u,v in pairs(tbl) do params[u] = params[u] or v end
	end
    local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,enums.Entities.ID_EFFECT_MeusFetus,0,pos,vel,nil)
    local d = q:GetData()
    local s = q:GetSprite()
	s.Scale = params.scale or Vector(1,1)
	if params.invisible then q.Visible = false end
    s:Play("Blink",true)
	local Epic_holder = require("Qing_Remaster_scripts.mimics.Epic_holder")
	d[Epic_holder.own_key.."targ"] = targ
	d[Epic_holder.own_key.."Cooldown"] = params.Cooldown or 0
	d[Epic_holder.own_key.."Damage"] = (params.dmgmul or 1/3) * (params.dmg or tearHitParams.TearDamage) * (params.charge or 1)
    d[Epic_holder.own_key.."Params"] = auxi.deepCopy(params)
	local flag_in = params.tearflags or params.tearflag or BitSet128(0,0)
	d[Epic_holder.own_key.."Tearflags"] = flag_in | (tearHitParams.TearFlags or BitSet128(0,0)) & ~(params.anti_tearflag or BitSet128(0,0))
	local pre_col = auxi.get_color_by_tearvariant(tearHitParams.TearVariant)
	d[Epic_holder.own_key.."Color"] = params.color or auxi.MulColor(tearHitParams.TearColor,pre_col)
	return q
end

local bomb_effe_list = {28,29,35,36,37,45,72,75,78}
local bomb_effe_map = {{75,20},{30,10},{20,20},{50,15},{50,10},{75,15},{100,5},{100,15},{100,7}}
function funct.get_bomb_flag(flag,player)
	local ret = BitSet128(0,0)
	for i = 1,#bomb_effe_list do
		local info = bomb_effe_map[i]
		if funct.bitset_flag(bfl,bomb_effe_list[i]) and funct.check_rand(player.Luck,info[1],0,info[2]) then
			ret = ret | funct.MakeBitSet(bomb_effe_list[i])
		end
	end
	return ret
end

local tear_color_map = {
	[1] = Color(1,0.3,0.3,1),
	[2] = Color(1,1,1,1,0.5,0.5,0.5),
	[3] = Color(0.5,0.5,0.5,1),
	[4] = Color(0.55,0.55,0.3,1),
	[5] = Color(1,0.55,0.3,1),
	[6] = Color(0.3,0.3,0.3,1),
	[7] = Color(0.6,1,0.6,1),
	[12] = Color(1,0.3,0.3,1),
	[15] = Color(1,0.3,0.3,1),
	[16] = Color(0.5,0,1,1),
	[17] = Color(1,0.3,1,1),
	[18] = Color(0.5,0.5,1,1),
	[20] = Color(1,0.7,0.2,1),
	[21] = Color(0,0,0,1,0.3,0.3,0.3),
	[23] = Color(1,0.3,0.3,1),
	[25] = Color(1,0.3,0.3,1),
	[32] = Color(1,0.3,0.3,1),
	[34] = Color(1,0.3,0.3,1),
	[37] = Color(1,0.3,0.3,1),
}

function funct.get_color_by_tearvariant(vr)
	return tear_color_map[vr] or Color(1,1,1,1)
end

local replace_stabberknife_name = {
	["spear"] = "Spear_Stabknife",
	["finger"] = "Finger_Stabknife",
	["bone"] = function(val) if val > 1 then return "bone_Stabknife" end end,
	["bloody"] = function(val) if val > 1 then return "Bloody_Stabknife" end end,
	["eye_ball"] = function(val) if val > 1 then return "Eye_Stabknife" end end,
	["dea"] = "Death_Stabknife",
	["tech"] = "tech_Stabknife",
	["rock"] = "Rock_Stabknife",
	["nipton"] = "Nipton_Stabknife",
	["tri"] = "Tri_Stabknife",
	["sulfur"] = "Sulfur_Stabknife",
	["lemon"] = "Sulfur_Stabknife",
	["damo"] = "Damo_Stabknife",
	["holy"] = function(val) if val > 1 then return "Holy_Stabknife" end end,
	["ice"] = "Ice_Stabknife",
	["godhead"] = "godh_Stabknife",
	["saga"] = "Saga_Stabknife",
	["spectral"] = "spectral_Stabknife",
	["dual"] = function(val,list,anim,tearflag,player) if (player:GetData().Dual_cnt or 0) == 0 then return "Yang_Stabknife" else return "Yin_Stabknife" end end,
}

local default_map = {
	["StabDown"] = {
		["cooldown"] = 10,
	},
	["AttackUp"] = {
		["cooldown"] = 8,
	},
	["SpinUp"] = {
		["cooldown"] = 14,
	},
	["IdleUp"] = {
		["cooldown"] = 60,
		["Accerate"] = 2,
		["size1"] = 5,
		["size2"] = Vector(1,3),
		["size3"] = 13,
		["shouldrotate"] = true,
	},
	[2] = {
		["Brim"] = 1,
	},
	[3] = {
		["Tech"] = 1,
	},
	[4] = {
		["Knife"] = 1,
	},
	[5] = {
		["Explosive"] = 1,
	},
	[6] = {
		["epic"] = 1,
	},
	[14] = {
		["sec"] = 1,
	},
	[15] = {
		["follow_hae"] = 1,
	},
}

local check_list = {
	["sec"] = {"sec",},
}

local dagger_size_controler = {
	["knife"] = function(val,ret,player) 
		ret.size1 = ret.size1 * (2 + val)
		ret.size2 = Vector(0.3,2)
		ret.size3 = ret.size3 * (1 + val)
		return ret
	end,
	["pol"] = function(val,ret,player) 
		ret.size1 = ret.size1 * (1 + val)
		ret.size2 = Vector(ret.size2.X * 2,ret.size2.Y * 2)
		ret.size3 = ret.size3 * (1 + val)
		ret.scale = Vector(2,(1 + val))
		return ret
	end,
	["larger"] = function(val,ret,player) 
		ret.size1 = ret.size1 * (1 + val * 0.15)
		ret.scale = ret.scale * (1 + val * 0.15)
		return ret
	end,
	["cho"] = function(val,ret,player) 		--!!
		if player:GetData().cho_counter then 
			local val = player:GetData().cho_counter
			ret.size1 = ret.size1 * (0.25 + val)
			ret.scale = ret.scale * (0.15 + val)
		end
	end,
	[1] = function(val,ret,player,params) 		--!!
		if ((params.list.soy or 0) > 0) or ((params.list.soy2 or 0) > 0) then
			local rang = 1
			if (params.list.soy or 0) > 0 then rang = 0.25 
			else rang = 0.35 end
			ret.size1 = ret.size1 * rang
			ret.scale = ret.scale * rang
			return ret
		end
	end,
	["hae"] = function(val,ret,player) 
		ret.size1 = ret.size1 * (1 + val * 0.4)
		ret.size3 = ret.size3 
		ret.scale = ret.scale * (1 + val * 0.4)
		return ret
	end,
}
--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") local col = Game():GetPlayer(0).TearColor auxi.PrintColor(col)
function funct.fire_dosome_knife(pos,vel,tearHitParams,anim,params,params2)
	local player_wq = require("Qing_Remaster_scripts.player.player_wq")
	if pos == nil or vel == nil or anim == nil then return end
	params = params or {}
	params2 = params2 or {}
	local player = params.player or Game():GetPlayer(0)
	tearHitParams = tearHitParams or player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,funct.choose(0,-1))
	params.list = params.list or player:GetData().Qing_list or funct.get_qing_list(player)
	for u,v in pairs(default_map[anim] or {}) do params[u] = params[u] or v end
	for u,v in pairs(default_map[(params2.weap or 1)] or {}) do params[u] = (params[u] or 0) + v end
	for u,v in pairs(check_list) do for uu,vv in pairs(v) do params[u] = (params[u] or 0) + (params.list[vv] or 0) end end
	local coold = params.cooldown or 8
	if params.sec then coold = coold + 2 end
	local source_pos = pos - vel * 3
	if anim == "IdleUp" then source_pos = pos end
	local source = params.source or funct.fire_nil(source_pos,vel,{cooldown = coold})
	local d2 = source:GetData()
	local dmg = (params.dmgmul or 1/3) * (params.dmg or tearHitParams.TearDamage) * (params2.charge or 1)
	local tearflag = ((params.tearflag or BitSet128(0,0))) | (params2.tearflag or BitSet128(0,0)) | tearHitParams.TearFlags & ~(params.anti_tearflag or BitSet128(0,0))
	tearflag = tearflag & ~ (BitSet128(1<<6,0) | BitSet128(1<<51,0))
	local pre_col = funct.get_color_by_tearvariant(tearHitParams.TearVariant)
	params.color = params.color or params2.color or funct.MulColor(tearHitParams.TearColor,pre_col)
	local scale = params.scale or tearHitParams.TearScale
	local q = Isaac.Spawn(8,enums.Entities.StabberKnife,0,Vector(2000,0),vel,player):ToKnife()
	local s = q:GetSprite()
	local d = q:GetData()
	q.Parent = source
	source.Child = q
	d.player = player
	
	local replace_name = nil
	local replace_name_cnt = 0
	if (params.list.dual or 0) > 0 then		--阴阳
		dmg = dmg * 0.75
		d[player_wq.own_key.."Dual"] = (player:GetData().Dual_cnt or 0)
		player:GetData().Dual_cnt = 1 - (player:GetData().Dual_cnt or 0)
	end
	for u,v in pairs(replace_stabberknife_name) do
		if ((params.list[u] or 0) > 0) or type(u) == "number" then
			replace_name = funct.check_if_any(v,(params.list[u] or 0),params.list,tearflag,anim,player) or replace_name
			replace_name_cnt = replace_name_cnt + 1
		end
	end
	if (params.list.redfire or 0) > 0 then		--辣椒
		if auxi.check_rand(player.Luck,50,1,11) then
			dmg = dmg * 1.7
			replace_name = "RedFire_Stabknife"
			replace_name_cnt = replace_name_cnt + 1
			d.fire_sound_effect = true
		end
	end
	if (params.list.bluefire or 0) > 0 then		--辣椒
		if auxi.check_rand(player.Luck,50,1,11) then
			dmg = dmg * 2.5
			replace_name = "BlueFire_Stabknife"
			replace_name_cnt = replace_name_cnt + 1
			d.fire_sound_effect = true
		end
	end
	if replace_name_cnt > 8 then
		player:GetData().mega_yinyang_stack_counter = (player:GetData().mega_yinyang_stack_counter or 0) % 3 + 1
		replace_name = "yinyang_Stabknife_"..tostring(player:GetData().mega_yinyang_stack_counter)
	end
	if replace_name then funct.replace_dagger_graph(q,replace_name) end
	
	if (params.list.divi or 0) > 0 and params.ignore_divi ~= true then		--分裂		--!!
		tearflag = tearflag | BitSet128(1<<18,0)
		d.divi_list = {}
		if player:GetCollectibleNum(453) > 0 then 
			for i = 1,math.random(3) + 1 do	table.insert(d.divi_list,{dir = math.random(3600)/10}) end
		end
		if player:GetCollectibleNum(104) > 0 then 
			for i = 1,2 do table.insert(d.divi_list,{dir = 90 + 180 * i}) end
		end
		if player:GetCollectibleNum(224) > 0 then
			local adder = (math.random(2) - 1) * 45
			for i = 1,4 do table.insert(d.divi_list,{dir = 90 * i + adder}) end
		end
	end
	if (params.list.should_on_laser or 0) > 0 then		--科技0
		tearflag = tearflag | BitSet128(1<<57,0)
		d.zero_stack = params.list.should_on_laser * 2 + 3
	end
	if (params.list.deadeye or 0) > 0 then d.deadeye = 1 end
	if (params.list.wavereye or 0) > 0 then d.wavereye = 1 end				
	local tosetsize = {size1 = 5,size2 = Vector(1,1),size3 = 5,scale = Vector(1,1)}	
	for u,v in pairs(tosetsize) do tosetsize[u] = params[u] or tosetsize[u] end
	if anim == "IdleUp" then tosetsize.size2.Y = tosetsize.size2.Y * 0.85 end
	params.Explosive = params.Explosive or params.list.ipec
	if (params.Explosive or 0) > 0 then
		d[player_wq.own_key.."Explosive_cnt"] = params.Explosive
		d[player_wq.own_key.."Explosive_DMG_self"] = false
		--d[player_wq.own_key.."Explosive_Flag"] = funct.get_bomb_flag(player:GetBombFlags(),player) or BitSet128(0,0)
	end
	for u,v in pairs(dagger_size_controler) do
		if (params.list[u] or 0) > 0 or type(u) == "number" then tosetsize = funct.check_if_any(v,params.list[u],tosetsize,player,params) or tosetsize end
	end
	if tosetsize then q:SetSize(math.ceil(tosetsize.size1),tosetsize.size2 * (params2.charge or 1),tosetsize.size3) s.Scale = tosetsize.scale * (params2.charge or 1) end
	if anim == "IdleUp" and tearflag & BitSet128(1<<2,0) == BitSet128(1<<2,0) then
		d2.Params.Homing = true
		d2.Params.HomingSpeed = 12
	end
	if type(params.Flip) == "number" then params.Flip = (params.Flip > 0) end
	if params.Flip then anim = anim.."2" end
	if anim == "IdleUp" and (params2.charge or 1) > 0.5 then
		d[player_wq.own_key.."holder"] = d[player_wq.own_key.."holder"] or {}
		if params.brim then 
			local q2 = player:FireBrimstone(-vel)
			q2.PositionOffset = Vector(0,0)
			q2.Parent = q
			q2.Position = q.Position
			q2:SetTimeout(13)
			if (params.list.brimstone or 0) > 1 then q2:SetTimeout(25) end
			table.insert(d[player_wq.own_key.."holder"],#d[player_wq.own_key.."holder"] + 1,{ent = q2,adder = 180,})
		elseif (params.list.brimstone or 0) > 0 and (params.knife or 0) == 0 then
			for k = 1,-1,-2 do
				local adder = 30 * k
				local q2 = player:FireBrimstone(auxi.get_by_rotate(vel,180 - 2 * adder),nil,0.3)
				q2.PositionOffset = Vector(0,0)
				q2:SetTimeout(10)
				q2.Parent = q
				q2.Position = q.Position
				table.insert(d[player_wq.own_key.."holder"],{ent = q2,adder = 180 - adder,})
			end
		end
		if params.knife then
		elseif (params.list.knife or 0) > 0 then
		end
	end
	d2.Params = funct.copy(params)
	d.params = funct.copy(params)
	q.TearFlags = tearflag
	d.tearflags = tearflag
	q.CollisionDamage = dmg
	q.RotationOffset = vel:GetAngleDegrees()
	q.Color = params.color
	s:Play(anim,true)
	return q
end

function funct.fire_dowhatknife(variant,position,velocity,dmg,dowhatstring1,dowhatstring2,params)
	dowhatstring2 = dowhatstring1
	params = params or {}
	params.list = params.list or {}
	
	local var = StabberKnife
	if variant ~= nil then
		var = variant
	end
	if position == nil or velocity == nil or dowhatstring1 == nil then	--直接解除
		return
	end
	local player = nil
	if params.player then
		player = params.player
	end
	local source = params.source
	local q1 = nil
	local coold = 8
	if params.cooldown then
		coold = params.cooldown
	end
	if params and params.list and params.list.sec and params.list.sec > 0 and (not params.no_sec) then
		if params.epic and params.epic == true then
			params.sec_effect2 = true		--史诗、剖腹产有特殊配合。
			dmg = dmg * 0.75
		else
			coold = coold * (3 + math.floor((params.list.sec - 1))) + 20
			params.sec_effect = true
		end
	end
	if params and params.list and params.list.ludo and params.list.ludo > 0 and (not params.ignore_ludo) then
		coold = coold * (2 + math.floor((params.list.ludo - 1)/3))
		params.continueafter = true
	end

	if source == nil then
		local t_pos = position - velocity * 3
		if dowhatstring1 == "IdleUp" then t_pos = position end
		q1 = funct.fire_nil(t_pos,velocity,{cooldown = coold})
		source = q1
		source:GetData().Params = params
	end
	local q1 = Isaac.Spawn(8,var,0,Vector(2000,0),velocity,player):ToKnife()		--q1被重新赋值了！！
	local s2 = q1:GetSprite()
	local d2 = q1:GetData()
	q1.Parent = source
	source.Child = q1
	q1.RotationOffset = velocity:GetAngleDegrees()
	if player then
		d2.player = player
		d2.tearflags = player.TearFlags
	end
	if params.tearflags then
		d2.tearflags = d2.tearflags | params.tearflags
		if params.tearflags & BitSet128(1<<2,0) == BitSet128(1<<2,0) and dowhatstring1 == "IdleUp" then		--弯勺
			source:GetData().Params.Homing = true
			source:GetData().Params.HomingSpeed = 12
		end
	end
	if params and params.list then			--特效控制
		if params.list.divi and params.list.divi ~= 0 and params.list.ignore_divi == nil then		--分裂
			d2.tearflags = d2.tearflags | BitSet128(1<<6,0)
			d2.divi_list = {}
			if player:GetCollectibleNum(453) > 0 then 
				for i = 1,math.random(3) + 1 do
					table.insert(d2.divi_list,{dir = math.random(3600)/10})
				end
			end
			if player:GetCollectibleNum(224) > 0 then 
				for i = 1,2 do
					table.insert(d2.divi_list,{dir = 90 + 180 * i})
				end
			end
			if player:GetCollectibleNum(104) > 0 then
				local adder = (math.random(2) - 1) * 45
				for i = 1,4 do
					table.insert(d2.divi_list,{dir = 90 * i + adder})
				end
			end
		end
		if params.list.para and params.list.para ~= 0 then		--中猫套
			d2.tearflags = d2.tearflags | BitSet128(1<<49,0)
		end
		if params.list.poision and params.list.poision > 0 then
			d2.tearflags = d2.tearflags | BitSet128(1<<4,0)
		end
		if params.list.slow and params.list.slow > 0 then
			d2.tearflags = d2.tearflags | BitSet128(1<<3,0)
		end
		if params.list.freeze and params.list.freeze > 0 then
			d2.tearflags = d2.tearflags | BitSet128(1<<5,0)
		end
		if params.list.charm and params.list.charm > 0 then
			d2.tearflags = d2.tearflags | BitSet128(1<<13,0)
		end
		if params.list.confuse and params.list.confuse > 0 then
			d2.tearflags = d2.tearflags | BitSet128(1<<14,0)
		end
		if params.list.godflesh and params.list.godflesh > 0 then
			d2.tearflags = d2.tearflags | BitSet128(1<<43,0)
		end
		if params.list.glaucoma and params.list.glaucoma > 0 then
			d2.tearflags = d2.tearflags | BitSet128(1<<47,0)
		end
		if params.list.ice and params.list.ice > 0 then
			d2.tearflags = d2.tearflags | BitSet128(0,1<<(65-64))
		end
		if params.list.ledo and params.list.ledo > 0 then
			d2.tearflags = d2.tearflags | BitSet128(0,1<<(66-64))
		end
		if params.list.rotten_tomato and params.list.rotten_tomato > 0 then
			d2.tearflags = d2.tearflags | BitSet128(0,1<<(67-64))
		end
		if params.list.rift and params.list.rift > 0 then
			d2.tearflags = d2.tearflags | BitSet128(0,1<<(76-64))
		end
		if params.list.tar and params.list.tar > 0 then
			d2.tearflags = d2.tearflags | BitSet128(1<<32,0)
		end
		if params.list.horn and params.list.horn > 0 then
			d2.tearflags = d2.tearflags | BitSet128(1<<56,0)
		end
		if params.list.should_on_laser and params.list.should_on_laser > 0 then
			d2.tearflags = d2.tearflags | BitSet128(1<<57,0)
			d2.zero_stack = params.list.should_on_laser * 2 + 3
		end
		if params.list.ladd and params.list.ladd > 0 then
			d2.tearflags = d2.tearflags | BitSet128(1<<55,0)
		end
		if params.list.keeper_head and params.list.keeper_head > 0 then
			d2.tearflags = d2.tearflags | BitSet128(1<<44,0)
		end
		if params.list.holy_light and params.list.holy_light > 0 then
			d2.tearflags = d2.tearflags | BitSet128(1<<39,0)
		end
		if params.list.fear and params.list.fear > 0 then
			d2.tearflags = d2.tearflags | BitSet128(1<<20,0)
		end
		if params.list.fist and params.list.fist > 0 then
			d2.tearflags = d2.tearflags | BitSet128(0,1<<(64-64))
		end
	end
	if params and params.room then
		d2.nowroom = params.room
	else
		d2.nowroom = Game():GetLevel():GetCurrentRoomIndex()
	end
	if params and params.knife2 and params.knife2 > 0 then
		if source ~= nil then
			source:AddVelocity(velocity:Normalized() * 10)
			if source:GetData().Params == nil then
				source:GetData().Params = {}
			end
			source:GetData().Params.Accerate = -1
		end
		d2.record_dir_for_knife_and_sword = velocity:GetAngleDegrees()
		d2.delta_dir_for_knife_and_sword = 0
		d2.record_knife2_delay = params.knife2_delay
	end
	if params and params.Explosive == nil and params.list then
		params.Explosive = params.list.ipec
	end
	
	if params and params.shouldrotate then
		params.shouldrotate = true
	end
	if params and params.follow_hae then
		params.follow_hae = true
		d2.hae_counter = 1
	end
	
	if params and params.Explosive and params.Explosive > 0 then
		d2.Explosive_cnt = params.Explosive
		params.bomb_knife_flag = BitSet128(0,0)
		local bfl = player:GetBombFlags()
		for i = 1,#bomb_effe_list do
			local list_1 = bomb_effe_map[i]
			if funct.bitset_flag(bfl,bomb_effe_list[i]) and funct.check_rand(player.Luck,list_1[1],0,list_1[2]) == true then
				params.bomb_knife_flag = params.bomb_knife_flag | funct.MakeBitSet(bomb_effe_list[i])
			end
		end
	end
	if params and params.repel and params.repel:Length() > 0.005 and params.list and params.list.repel_effect and params.list.repel_effect > 0 then		--附加的击退效果。
		params.repel = params.repel * (1 + params.list.repel_effect/10)
	end
	
	if params.color then
		local fadeout = false
		if params.color_fadeout then
			fadeout = params.color_fadeout
		end
		local duration = coold + 2
		if params.color_dur then
			duration = params.color_dur
		end
		q1:SetColor(params.color,duration,99,fadeout,false)
	end
	
	local tosetsize = {size1 = 5,size2 = Vector(1,1),size3 = 5,scale = Vector(1,1)}		--大小控制
	if params.size and params.size2 and params.size1 then
		tosetsize.size1 = params.size
		tosetsize.size2 = params.size1
		tosetsize.size3 = params.size2
	end
	if params.size_scale then
		tosetsize.scale = params.size_scale
	end
	if dowhatstring1 == "IdleUp" then tosetsize.size2.Y = tosetsize.size2.Y * 0.85 end		--稍微过长了
	if params and params.list then
		if params.list.knife and params.list.knife ~= 0 then
			local knife = params.list.knife
			tosetsize.size1 = tosetsize.size1 * (2 + knife)
			tosetsize.size2 = Vector(0.3,2)
			tosetsize.size3 = tosetsize.size3 * (1 + knife)
		end
		if params.list.pol and params.list.pol ~= 0 then
			local pol = params.list.pol
			tosetsize.size1 = tosetsize.size1 * (1 + pol)
			tosetsize.size2 = Vector(tosetsize.size2.X * 2,tosetsize.size2.Y * 2)
			tosetsize.size3 = tosetsize.size3 * (1 + pol)
			tosetsize.scale = Vector(2,(1 + pol))
		end
		if params.list.larger and params.list.larger ~= 0 then
			local cnt = params.list.larger
			tosetsize.size1 = tosetsize.size1 * (1 + cnt * 0.15)
			tosetsize.scale = tosetsize.scale * (1 + cnt * 0.15)
		end
		if params.list.cho and params.list.cho ~= 0 and params.list.cho_counter then
			local cho_counter = params.list.cho_counter
			tosetsize.size1 = tosetsize.size1 * (0.25 + cho_counter)
			tosetsize.scale = tosetsize.scale * (0.15 + cho_counter)
		end
		if ((params.list.soy and params.list.soy ~= 0) or (params.list.soy2 and params.list.soy2 ~= 0))  then
			local rang = 1
			if (params.list.soy and params.list.soy ~= 0) then
				rang = 0.25
			end
			if (params.list.soy2 and params.list.soy2 ~= 0) then
				rang = 0.35
			end
			local cho_counter = params.list.cho_counter
			tosetsize.size1 = tosetsize.size1 * rang
			tosetsize.scale = tosetsize.scale * rang
		end
		if params.list.hae and params.list.hae ~= 0 then
			local hae = params.list.hae
			tosetsize.size1 = tosetsize.size1 * (1 + hae * 0.4)
			tosetsize.size3 = tosetsize.size3 
			tosetsize.scale = tosetsize.scale * (1 + hae * 0.4)
		end
	end
	
	if tosetsize then
		q1:SetSize(tosetsize.size1,tosetsize.size2,tosetsize.size3)
		s2.Scale = tosetsize.scale
	end
	
	local replace_name = nil
	local replace_name_cnt = 0
	if params.tech and params.tech == true then		--换皮肤
		replace_name = "tech_Stabknife"
		replace_name_cnt = replace_name_cnt + 1
	end
	if params.Entitycollision then		--似乎没啥用
		q1.EntityCollisionClass = params.Entitycollision
	end
	
	q1.CollisionDamage = dmg
	local ang = velocity:GetAngleDegrees() + 360
	s2:Play(dowhatstring1,true)
	
	d2.damage = dmg
	d2.params = funct.copy(params)
	d2.TimeOut = coold		--调用了自动删除装置。
	return q1
end

function funct.thor_attack(player,list)		--飞雷神！！
	local room = Game():GetRoom()
	local d = player:GetData()
	if auxi.check_all_exists(player) ~= true or auxi.check_all_exists(d.thor_target) ~= true then return end
	local targ = d.thor_target
	local delay = 30
	if (list.backstab or 0) == 0 then
		local dis = targ.Position - player.Position
		local loop_cnt = math.max(3,math.min(10,math.ceil(dis:Length()/20)))
		player:SetColor(Color(-1,-1,-1,1,0,0,0),loop_cnt,99,false,true)
		local dir = dis:Normalized()
		for i = 1,loop_cnt do
			addeffe(function(params)
				if auxi.check_all_exists(player) and params.pos then
					local q1 = funct.fire_dosome_knife(player.Position + dir * 30 + funct.get_by_rotate(dir,120,60),funct.get_by_rotate(dir,-30),nil,"StabDown",{player = player,thor_effe = true,no_sec = true,dmgmul = 1/10})
					local q1 = funct.fire_dosome_knife(player.Position + dir * 30 + funct.get_by_rotate(dir,-120,60),funct.get_by_rotate(dir,30),nil,"StabDown",{player = player,thor_effe = true,no_sec = true,dmgmul = 1/10})
					player.Position = params.pos
					player.Velocity = Vector(0,0)
					player:AddControlsCooldown(1)
				end
			end,{player = player,pos = player.Position + i/loop_cnt * dis},i-1,{remove_now = true,})
		end
		addeffe(function(params)
			if auxi.check_all_exists(player) then
				player:SetColor(Color(1,1,1,0.5,1,1,1),15,30,true,true)
				player.Position = room:GetClampedPosition(player.Position,10)
			end
		end,{player = player},loop_cnt)
		delay = 25 + loop_cnt
	else
		local q1 = Isaac.Spawn(1000,MeusLink,0,player.Position/2 + targ.Position/2,Vector(0,0),player)
		local s1 = q1:GetSprite()
		local dir = (targ.Position - player.Position)
		local ang = dir:GetAngleDegrees()
		local leg = dir:Length() + 30
		s1.Rotation = ang - 90
		s1.Scale = Vector(leg/45,1/6)
		player.Position = player.Position + funct.MakeVector(ang) * (leg)
		player.Velocity = Vector(0,0)
		for i = 1,16 do funct.fire_dosome_knife(player.Position,funct.MakeVector(ang + i * 360/16) * 20 * player.ShotSpeed,nil,"IdleUp",{player = player,}) end
	end
	if player.CanFly == false then Attribute_holder.try_hold_and_rewind_attribute(player,"GridCollisionClass",GridCollisionClass.COLLISION_WALL,delay + 30) end
	if delay - player:GetDamageCooldown() > 0 then Attribute_holder.try_hold_and_rewind_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",true,delay - player:GetDamageCooldown(),Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK)) end
	player:SetMinDamageCooldown(delay)
	local player_wq = require("Qing_Remaster_scripts.player.player_wq")
	d[player_wq.own_key.."Thor"] = true
	addeffe(function(params)
		if auxi.check_all_exists(player) then d[player_wq.own_key.."Thor"] = nil end
	end,{player = player},math.max(0,delay - 20))
end

function funct.kill_them_all(player,pos,dmg)
	local room = Game():GetRoom()
	local q1 = Isaac.Spawn(1000,MeusLink,0,player.Position,Vector(0,0),player)
	local s1 = q1:GetSprite()
	
	local dir = pos - player.Position
	if player:GetData().last_attack_pos then
		 dir = player:GetData().last_attack_pos - player.Position
		 player:GetData().last_attack_pos = nil
	end
	if dir:Length() < 0.5 then
		dir = funct.MakeVector(math.random(36000)/100) * 1000
	end
	s1.Rotation = dir:GetAngleDegrees() - 90
	s1.Scale = Vector(dir:Length(),1/10)
	player.Position = room:GetClampedPosition(player.Position + dir:Normalized() * (dir:Length() + 50),10)
	if 20 - player:GetDamageCooldown() > 0 then
		Attribute_holder.try_hold_and_rewind_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",true,20 - player:GetDamageCooldown(),Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK))
	end
	player:SetMinDamageCooldown(20)
	local n_entity = Isaac.GetRoomEntities()
	local n_enemy = funct.getenemies(n_entity)
	for i = 1,#n_enemy do 
		if (n_enemy[i].Position - pos):Length() < 30 then
			n_enemy[i]:TakeDamage(dmg,0,EntityRef(player),0)
		end
	end
end

function funct.kill_them_all2(player,pos,dmg,max_hit,max_range)
	local target_enemy = {}
	local n_entity = Isaac.GetRoomEntities()
	local n_enemy = funct.getenemies(n_entity)
	max_range = max_range or 100
	for i = 1,#n_enemy do 
		if (n_enemy[i].Position - pos):Length() < max_range then
			target_enemy[#target_enemy + 1] = n_enemy[i]
		end
	end
	max_hit = max_hit or 5
	if #target_enemy < max_hit and #target_enemy > 0 then
		for i = #target_enemy,max_hit + 2 do 
			target_enemy[#target_enemy + 1] = target_enemy[math.random(#target_enemy)]
		end
	end
	if #target_enemy > 0 then
		Attribute_holder.try_hold_and_rewind_attribute(player,"Visible",false,#target_enemy * 1.5 + 2)
		if #target_enemy * 2 + 30 - player:GetDamageCooldown() > 0 then
			Attribute_holder.try_hold_and_rewind_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",true,#target_enemy * 2 + 30 - player:GetDamageCooldown(),Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK))
		end
		player:SetMinDamageCooldown(#target_enemy * 2 + 30)
		if player.CanFly == false then
			Attribute_holder.try_hold_and_rewind_attribute(player,"GridCollisionClass",GridCollisionClass.COLLISION_WALL,#target_enemy * 2 + 30)
		end
		player:GetData().bone_Position = player.Position
		player:AddControlsCooldown(#target_enemy * 2 + 10)
		for i = 1,#target_enemy do
			addeffe(function(params)
				local q1 = Isaac.Spawn(1000,MeusLink,0,params.player:GetData().bone_Position/2 + params.target_enemy.Position/2,Vector(0,0),player)
				local s1 = q1:GetSprite()
				local dir = (params.target_enemy.Position - params.player:GetData().bone_Position)
				local ang = dir:GetAngleDegrees() + math.random(60000)/1000 - 30
				local leg = dir:Length() + 30
				s1.Rotation = ang - 90
				s1.Scale = Vector(leg/90,1/10)
				params.player:GetData().bone_Position = params.player:GetData().bone_Position + funct.MakeVector(ang) * (leg)
				if params.target_enemy:Exists() then
					params.target_enemy:TakeDamage(dmg,0,EntityRef(player),0)
				end
			end,{target_enemy = target_enemy[i],player = player},i * 2)
		end
	end
end

function funct.PrintTable(tbl,level,filteDefault)
	if tbl == nil or type(tbl) ~= "table" then print(tbl) return end
	local msg = ""
	filteDefault = filteDefault or true --默认过滤关键字（DeleteMe, _class_type）
	level = level or 1
	local indent_str = ""
	for i = 1, level do
		indent_str = indent_str.."  "
	end

	print(indent_str .. "{")
	for k,v in pairs(tbl) do
		if filteDefault then
			if k ~= "_class_type" and k ~= "DeleteMe" and type(v) ~= "boolean" then
				local item_str = string.format("%s%s %s = %s", indent_str .. " ",tostring(type(k)),tostring(k), tostring(v))
				print(item_str)
				if type(v) == "table" then
					funct.PrintTable(v, level + 1)
				end
			elseif type(v) == "boolean" then
				local item_str = indent_str.." "..tostring(k).." = "
				if v == true then
					item_str = item_str.."True"
				else
					item_str = item_str.."False"
				end
				print(item_str)
			end
		else
			local item_str = string.format("%s%s %s = %s", indent_str .. " ",tostring(type(k)),tostring(k), tostring(v))
			print(item_str)
			if type(v) == "table" then
				funct.PrintTable(v, level + 1)
			end
		end
	end
	print(indent_str .. "}")
end

local random_pickup_list = {
	{Variant = 20,SubType = function(info,rng)
		return auxi.random_in_weighed_table(info.subtypes,rng).id
	end,subtypes = {
		{id = 1,weigh = 100,},
		{id = 2,weigh = 30,},
		{id = 3,weigh = 20,},
		{id = 4,weigh = 10,},
		{id = 5,weigh = 10,},
		{id = 7,weigh = 10,},
	},weigh = 100,},
	{Variant = 10,SubType = 0,weigh = 100,},
	{Variant = 30,SubType = 0,weigh = 100,},
	{Variant = 40,SubType = function(info,rng)
		return auxi.random_in_weighed_table(info.subtypes,rng).id
	end,subtypes = {
		{id = 1,weigh = 100,},
		{id = 2,weigh = 20,},
		{id = 4,weigh = 10,},
		{id = 7,weigh = 5,},
	},weigh = 100,},
	{Variant = 90,SubType = 0,weigh = 50,},
	{Variant = 70,SubType = 0,weigh = 50,},
	{Variant = 300,SubType = 0,weigh = 50,},
	{Variant = 42,SubType = 0,weigh = 10,},
}

function funct.get_random_pickup(rng)
	return auxi.random_in_weighed_table(random_pickup_list,rng)
end

local glazed_players = {
	"Isaac",
	"Maggy",
	"Cain",
	"Judas",
	"BlueBaby",
	"Eve",
	"Samson",
	"Azazel",
	"Lazarus",
	"Eden",
	"Lost",
	--"Lazarus2",	--11
	--"BlackJudas",--12
	"Lilith",
	"Keeper",
	"Apollyon",
	"Forgotten",
	--"The Soul",--17
	"Bethany",
	"Esau",
	"Jacob",
}

function funct.getplayer_glazed(player)
	local raw_pt = player:GetPlayerType()
	if raw_pt >= 0 then
		if raw_pt > 20 and raw_pt < 41 then
			if raw_pt == 38 then raw_pt = 29 end
			if raw_pt == 39 then raw_pt = 37 end
			if raw_pt == 40 then raw_pt = 35 end
			return glazed_players[raw_pt - 20]
		end
		if raw_pt < 21 then
			if raw_pt == 11 then raw_pt = 8 end
			if raw_pt == 12 then raw_pt = 3 end
			if raw_pt == 17 then raw_pt = 15 end
			if raw_pt > 17 then raw_pt = raw_pt - 1 end
			if raw_pt > 12 then raw_pt = raw_pt - 2 end
			return glazed_players[raw_pt + 1]
		end
		return player:GetName()
	else
		return ""
	end
end

function funct.get_player_name(player)
	local raw_pt = player:GetPlayerType()
	if raw_pt >= 0 then
		if raw_pt > 20 and raw_pt < 41 then
			if raw_pt == 38 then raw_pt = 29 end
			if raw_pt == 39 then raw_pt = 37 end
			if raw_pt == 40 then return nil end
			return glazed_players[raw_pt - 20]
		end
		if raw_pt < 21 then
			if raw_pt == 11 then raw_pt = 8 end
			if raw_pt == 12 then raw_pt = 3 end
			if raw_pt == 17 then return nil end
			if raw_pt > 17 then raw_pt = raw_pt - 1 end
			if raw_pt > 12 then raw_pt = raw_pt - 2 end
			return glazed_players[raw_pt + 1]
		end
		return player:GetName()
	else
		return ""
	end
end

function funct.get_players_name()
	local tbl = {}
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local name = funct.get_player_name(player)
		if name ~= nil then
			table.insert(tbl,#tbl + 1,name)
		end
	end
	if #tbl > 2 then
		local ret = ""
		for i = 1,#tbl - 2 do
			ret = ret .. tbl[i] .. ","
		end
		return ret..tbl[#tbl - 1].." and "..tbl[#tbl]
	else
		if #tbl == 2 then
			return tbl[1].." and "..tbl[2]
		elseif #tbl == 1 then
			return tbl[1]
		end
	end
end

function funct.get_players_counter()
	local tbl = {}
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local name = funct.get_player_name(player)
		if name ~= nil then
			table.insert(tbl,#tbl + 1,name)
		end
	end
	return #tbl
end

local player_mxdelay_mul = {
	[PlayerType.PLAYER_EVE_B] = 2/3,
}

local weapon_mxdelay_mul = {
	[WeaponType.WEAPON_TEARS] = function (player)
		local ret = 1
		if player:HasCollectible(CollectibleType.COLLECTIBLE_IPECAC) or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_IPECAC) then ret = ret * 1/3 end
		return ret
	 end,
	[WeaponType.WEAPON_BRIMSTONE] = 1/3,
	[WeaponType.WEAPON_LASER] = function (player)
		local ret = 1
		if player:HasCollectible(CollectibleType.COLLECTIBLE_IPECAC) or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_IPECAC) then ret = ret * 1/3 end
		return ret
	 end,
	[WeaponType.WEAPON_KNIFE] = 1,
	[WeaponType.WEAPON_BOMBS] = 0.4,
	[WeaponType.WEAPON_ROCKETS] = 1,
	[WeaponType.WEAPON_MONSTROS_LUNGS] = 10/43,
	[WeaponType.WEAPON_LUDOVICO_TECHNIQUE] = 1,
	[WeaponType.WEAPON_TECH_X] = 1,
	[WeaponType.WEAPON_BONE] = 0.5,
	[WeaponType.WEAPON_SPIRIT_SWORD] = 1,
	[WeaponType.WEAPON_FETUS] = 1,
	[WeaponType.WEAPON_UMBILICAL_WHIP] = 1,
}
 
local item_mxdelay_mul = {
	[CollectibleType.COLLECTIBLE_TECHNOLOGY_2] = 2/3,
	[CollectibleType.COLLECTIBLE_EVES_MASCARA] = 2/3,
	[CollectibleType.COLLECTIBLE_MUTANT_SPIDER] = function (player)
		if player:HasCollectible(CollectibleType.COLLECTIBLE_20_20) or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_20_20) then return 1 end
		return 0.42
	 end,
	[CollectibleType.COLLECTIBLE_INNER_EYE] = function (player)
		if player:HasCollectible(CollectibleType.COLLECTIBLE_20_20) or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_20_20) then return 1 end
		if player:HasCollectible(CollectibleType.COLLECTIBLE_MUTANT_SPIDER) or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_MUTANT_SPIDER) then return 1 end
		if player:HasCollectible(CollectibleType.COLLECTIBLE_POLYPHEMUS) or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_POLYPHEMUS) then return 1 end
		return 0.51
	 end,
	[CollectibleType.COLLECTIBLE_POLYPHEMUS] = function (player)
		if player:HasCollectible(CollectibleType.COLLECTIBLE_20_20) or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_20_20) then return 1 end
		if player:HasCollectible(CollectibleType.COLLECTIBLE_MUTANT_SPIDER) or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_MUTANT_SPIDER) then return 1 end
		return 0.42
	 end,
	[CollectibleType.COLLECTIBLE_SOY_MILK] = function (player)
		if player:HasCollectible(CollectibleType.COLLECTIBLE_ALMOND_MILK) or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_ALMOND_MILK) then return 1 end
		return 5.5
	 end,
	[CollectibleType.COLLECTIBLE_ALMOND_MILK] = 4,
	[CollectibleType.COLLECTIBLE_EYE_DROPS] = 1.2,
}

local null_item_mxdelay_mul = {
	[NullItemID.ID_REVERSE_CHARIOT] = 4,
	[NullItemID.ID_REVERSE_HANGED_MAN] = function (player)
		if player:HasCollectible(CollectibleType.COLLECTIBLE_INNER_EYE) or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_INNER_EYE) then return 1 end
		if player:HasCollectible(CollectibleType.COLLECTIBLE_20_20) or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_20_20) then return 1 end
		if player:HasCollectible(CollectibleType.COLLECTIBLE_MUTANT_SPIDER) or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_MUTANT_SPIDER) then return 1 end
		if player:HasCollectible(CollectibleType.COLLECTIBLE_POLYPHEMUS) or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_POLYPHEMUS) then return 1 end
		return 0.51
	 end,
}

--溢泪症有点小问题。圣地和启明星需要处理
--l local player = Game():GetPlayer(0);for i = 1,16 do if player:HasWeaponType(i) == true then print(i) end end
--l local player = Game():GetPlayer(0);local effects = player:GetEffects();for i = 1,999 do if effects:HasCollectibleEffect(i) then print(i) end end;
--l local player = Game():GetPlayer(0);local effects = player:GetEffects();for i = 1,999 do if effects:HasNullEffect(i) then print(i) end end;
--l local player = Game():GetPlayer(0);local effects = player:GetEffects();effects:RemoveCollectibleEffect(283)
--l local player = Game():GetPlayer(0);local effects = player:GetEffects();effects:AddNullEffect(29)
function funct.get_mxdelay_multiplier(player)
	local total_multiplier = player_mxdelay_mul[player:GetPlayerType()] or 1
	if type(total_multiplier) == "function" then total_multiplier = total_multiplier(player) end
	local weap = 1
	for i = 1,16 do if player:HasWeaponType(i) == true then	weap = i end end
	local multiplier1 = weapon_mxdelay_mul[weap] or 1
	if type(multiplier1) == "function" then multiplier1 = multiplier1(player) end
	total_multiplier = total_multiplier * multiplier1
	local effects = player:GetEffects()
	for collectible, multiplier in pairs(item_mxdelay_mul) do
		if player:HasCollectible(collectible) or effects:HasCollectibleEffect(collectible) then
			if type(multiplier) == "function" then multiplier = multiplier(player) end
			total_multiplier = total_multiplier * multiplier
		end
	end
	for collectible, multiplier in pairs(null_item_mxdelay_mul) do
		if effects:HasNullEffect(collectible) then
			if type(multiplier) == "function" then multiplier = multiplier(player) end
			total_multiplier = total_multiplier * multiplier
		end
	end
	--血泪需要最后计算
	if player:HasCollectible(CollectibleType.COLLECTIBLE_HAEMOLACRIA) or effects:HasCollectibleEffect(CollectibleType.COLLECTIBLE_HAEMOLACRIA) then
		if player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) or effects:HasCollectibleEffect(CollectibleType.COLLECTIBLE_BRIMSTONE) then
			total_multiplier = 1/(total_multiplier + 2)
		else
			total_multiplier = 1/(total_multiplier * 2/3 + 2)
		end
	end
	return total_multiplier
end

local player_dmg_mul = {
	[PlayerType.PLAYER_ISAAC] = 1,
	[PlayerType.PLAYER_MAGDALENA] = 1,
	[PlayerType.PLAYER_CAIN] = 1,
	[PlayerType.PLAYER_JUDAS] = 1,
	[PlayerType.PLAYER_XXX] = 1.05,
	[PlayerType.PLAYER_EVE] = function (player)
	if player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_WHORE_OF_BABYLON) then return 1 end
	return 0.75
	end,
	[PlayerType.PLAYER_SAMSON] = 1,
	[PlayerType.PLAYER_AZAZEL] = 1.5,
	[PlayerType.PLAYER_LAZARUS] = 1,
	[PlayerType.PLAYER_THELOST] = 1,
	[PlayerType.PLAYER_LAZARUS2] = 1.4,
	[PlayerType.PLAYER_BLACKJUDAS] = 2,
	[PlayerType.PLAYER_LILITH] = 1,
	[PlayerType.PLAYER_KEEPER] = 1.2,
	[PlayerType.PLAYER_APOLLYON] = 1,
	[PlayerType.PLAYER_THEFORGOTTEN] = 1.5,
	[PlayerType.PLAYER_THESOUL] = 1,
	[PlayerType.PLAYER_BETHANY] = 1,
	[PlayerType.PLAYER_JACOB] = 1,
	[PlayerType.PLAYER_ESAU] = 1,
	-- Tainted characters
	[PlayerType.PLAYER_ISAAC_B] = 1,
	[PlayerType.PLAYER_MAGDALENA_B] = 0.75,
	[PlayerType.PLAYER_CAIN_B] = 1,
	[PlayerType.PLAYER_JUDAS_B] = 1,
	[PlayerType.PLAYER_XXX_B] = 1,
	[PlayerType.PLAYER_EVE_B] = 1.2,
	[PlayerType.PLAYER_SAMSON_B] = 1,
	[PlayerType.PLAYER_AZAZEL_B] = 1.5,
	[PlayerType.PLAYER_LAZARUS_B] = 1,
	[PlayerType.PLAYER_EDEN_B] = 1,
	[PlayerType.PLAYER_THELOST_B] = 1.3,
	[PlayerType.PLAYER_LILITH_B] = 1,
	[PlayerType.PLAYER_KEEPER_B] = 1,
	[PlayerType.PLAYER_APOLLYON_B] = 1,
	[PlayerType.PLAYER_THEFORGOTTEN_B] = 1.5,
	[PlayerType.PLAYER_BETHANY_B] = 0.75,
	[PlayerType.PLAYER_JACOB_B] = 1,
	[PlayerType.PLAYER_LAZARUS2_B] = 1.5,
 }

local item_dmg_mul = {
	[CollectibleType.COLLECTIBLE_MAXS_HEAD] = 1.5,
	[CollectibleType.COLLECTIBLE_MAGIC_MUSHROOM] = function (player)
		if player:HasCollectible(CollectibleType.COLLECTIBLE_MAXS_HEAD) then return 1 end
		return 1.5
	end,
	[CollectibleType.COLLECTIBLE_BLOOD_MARTYR] = function (player)
		if not player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_BOOK_OF_BELIAL) then return 1 end
		if player:HasCollectible(CollectibleType.COLLECTIBLE_MAXS_HEAD) or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_MAGIC_MUSHROOM) then return 1 end
		return 1.5
	end,
	[CollectibleType.COLLECTIBLE_POLYPHEMUS] = 2,
	[CollectibleType.COLLECTIBLE_SACRED_HEART] = 2.3,
	[CollectibleType.COLLECTIBLE_EVES_MASCARA] = 2,
	[CollectibleType.COLLECTIBLE_ODD_MUSHROOM_RATE] = 0.9,
	[CollectibleType.COLLECTIBLE_20_20] = 0.8,
	--[CollectibleType.COLLECTIBLE_EVES_MASCARA] = 2,
	[CollectibleType.COLLECTIBLE_SOY_MILK] = function (player)
		if player:HasCollectible(CollectibleType.COLLECTIBLE_ALMOND_MILK) then return 1 end
		return 0.2
	end,
	[CollectibleType.COLLECTIBLE_CROWN_OF_LIGHT] = function (player)
		if player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_CROWN_OF_LIGHT) then return 2 end
		return 1
	end,
	[CollectibleType.COLLECTIBLE_ALMOND_MILK] = 0.33,
	[CollectibleType.COLLECTIBLE_IMMACULATE_HEART] = 1.2,
	[CollectibleType.COLLECTIBLE_MEGA_MUSH] = function (player)
		if not player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_MEGA_MUSH) then return 1 end
		return 4
	  end,
}
--需要计算魅魔的攻击倍率

function funct.get_damage_multiplier(player)
	local total_multiplier = player_dmg_mul[player:GetPlayerType()] or 1
	if type(total_multiplier) == "function" then total_multiplier = total_multiplier(player) end
	
	local effects = player:GetEffects()

	for collectible, multiplier in pairs(item_dmg_mul) do
		if player:HasCollectible(collectible) or effects:HasCollectibleEffect(collectible) then
			if type(multiplier) == "function" then multiplier = multiplier(player) end
			total_multiplier = total_multiplier * multiplier
		end
	end

	return total_multiplier
end

local soul_player = {
	[PlayerType.PLAYER_XXX] = true,
	[PlayerType.PLAYER_THELOST] = true,
	[PlayerType.PLAYER_BLACKJUDAS] = true,
	[PlayerType.PLAYER_THESOUL] = true,
	[PlayerType.PLAYER_XXX_B] = true,
	[PlayerType.PLAYER_THELOST_B] = true,
	[PlayerType.PLAYER_THEFORGOTTEN_B] = true,
	[PlayerType.PLAYER_BETHANY_B] = true,
}

function funct.is_soul_player(player)
	local tp = player:GetPlayerType()
	if soul_player[tp] ~= nil then
		return soul_player[tp]
	else
		return false
	end
end

local soul_dealer = {
	[PlayerType.PLAYER_XXX] = true,
}

function funct.is_special_soul_dealer(player)
	local tp = player:GetPlayerType()
	if soul_dealer[tp] ~= nil then
		return soul_dealer[tp]
	else
		return false
	end
end

local tainted_player = {
	[PlayerType.PLAYER_ISAAC_B] = "ISAAC_B",
	[PlayerType.PLAYER_MAGDALENA_B] = "MAGDALENE_B",
	[PlayerType.PLAYER_CAIN_B] = "CAIN_B",
	[PlayerType.PLAYER_JUDAS_B] = "JUDAS_B",
	[PlayerType.PLAYER_XXX_B] = "BLUEBABY_B",
	[PlayerType.PLAYER_EVE_B] = "EVE_B",
	[PlayerType.PLAYER_SAMSON_B] = "SAMSON_B",
	[PlayerType.PLAYER_AZAZEL_B] = "AZAZEL_B",
	[PlayerType.PLAYER_LAZARUS_B] = "LAZARUS_B",
	[PlayerType.PLAYER_EDEN_B] = "EDEN_B",
	[PlayerType.PLAYER_THELOST_B] = "THE_LOST_B",
	[PlayerType.PLAYER_LILITH_B] = "LILITH_B",
	[PlayerType.PLAYER_KEEPER_B] = "KEEPER_B",
	[PlayerType.PLAYER_APOLLYON_B] = "APOLLYON_B",
	[PlayerType.PLAYER_THEFORGOTTEN_B] = "THE_FORGOTTEN_B",
	[PlayerType.PLAYER_BETHANY_B] = "BETHANY_B",
	[PlayerType.PLAYER_JACOB_B] = "JACOB_B",
	[PlayerType.PLAYER_LAZARUS2_B] = "LAZARUS_B",
	[enums.Players.Spwq] = "W_QING",
}

function funct.is_player_tainted(tp)
	if tainted_player[tp] then return true end
end

local Copy_of_player_birthright_name = {
	[PlayerType.PLAYER_ISAAC] = "ISAAC",
	[PlayerType.PLAYER_MAGDALENA] = "MAGDALENE",
	[PlayerType.PLAYER_CAIN] = "CAIN",
	[PlayerType.PLAYER_JUDAS] = "JUDAS",
	[PlayerType.PLAYER_XXX] = "BLUEBABY",
	[PlayerType.PLAYER_EVE] = "EVE",
	[PlayerType.PLAYER_SAMSON] = "SAMSON",
	[PlayerType.PLAYER_AZAZEL] = "AZAZEL",
	[PlayerType.PLAYER_LAZARUS] = "LAZARUS",
	[PlayerType.PLAYER_EDEN] = "EDEN",
	[PlayerType.PLAYER_THELOST] = "THE_LOST",
	[PlayerType.PLAYER_LAZARUS2] = "LAZARUS2",
	[PlayerType.PLAYER_BLACKJUDAS] = "BLACK_JUDAS",
	[PlayerType.PLAYER_LILITH] = "LILITH",
	[PlayerType.PLAYER_KEEPER] = "KEEPER",
	[PlayerType.PLAYER_APOLLYON] = "APOLLYON",
	[PlayerType.PLAYER_THEFORGOTTEN] = "THE_FORGOTTEN",
	[PlayerType.PLAYER_THESOUL] = "THE_SOUL",
	[PlayerType.PLAYER_BETHANY] = "BETHANY",
	[PlayerType.PLAYER_JACOB] = "JACOB",
	[PlayerType.PLAYER_ESAU] = "ESAU",

	-- Tainted characters
	[PlayerType.PLAYER_ISAAC_B] = "ISAAC_B",
	[PlayerType.PLAYER_MAGDALENA_B] = "MAGDALENE_B",
	[PlayerType.PLAYER_CAIN_B] = "CAIN_B",
	[PlayerType.PLAYER_JUDAS_B] = "JUDAS_B",
	[PlayerType.PLAYER_XXX_B] = "BLUEBABY_B",
	[PlayerType.PLAYER_EVE_B] = "EVE_B",
	[PlayerType.PLAYER_SAMSON_B] = "SAMSON_B",
	[PlayerType.PLAYER_AZAZEL_B] = "AZAZEL_B",
	[PlayerType.PLAYER_LAZARUS_B] = "LAZARUS_B",
	[PlayerType.PLAYER_EDEN_B] = "EDEN_B",
	[PlayerType.PLAYER_THELOST_B] = "THE_LOST_B",
	[PlayerType.PLAYER_LILITH_B] = "LILITH_B",
	[PlayerType.PLAYER_KEEPER_B] = "KEEPER_B",
	[PlayerType.PLAYER_APOLLYON_B] = "APOLLYON_B",
	[PlayerType.PLAYER_THEFORGOTTEN_B] = "THE_FORGOTTEN_B",
	[PlayerType.PLAYER_BETHANY_B] = "BETHANY_B",
	[PlayerType.PLAYER_JACOB_B] = "JACOB_B",
	[PlayerType.PLAYER_LAZARUS2_B] = "LAZARUS_B",
}

function funct.get_birth_right_name(player)
	local tp = player:GetPlayerType()
	local ret = Copy_of_player_birthright_name[tp] or ""
	return ret
end

local Copy_of_player_display_name = {
	[PlayerType.PLAYER_ISAAC] = "ISAAC",
	[PlayerType.PLAYER_MAGDALENA] = "MAGDALENE",
	[PlayerType.PLAYER_CAIN] = "CAIN",
	[PlayerType.PLAYER_JUDAS] = "JUDAS",
	[PlayerType.PLAYER_XXX] = "BLUEBABY",
	[PlayerType.PLAYER_EVE] = "EVE",
	[PlayerType.PLAYER_SAMSON] = "SAMSON",
	[PlayerType.PLAYER_AZAZEL] = "AZAZEL",
	[PlayerType.PLAYER_LAZARUS] = "LAZARUS",
	[PlayerType.PLAYER_EDEN] = "EDEN",
	[PlayerType.PLAYER_THELOST] = "THE_LOST",
	[PlayerType.PLAYER_LAZARUS2] = "LAZARUS2",
	[PlayerType.PLAYER_BLACKJUDAS] = "BLACK_JUDAS",
	[PlayerType.PLAYER_LILITH] = "LILITH",
	[PlayerType.PLAYER_KEEPER] = "KEEPER",
	[PlayerType.PLAYER_APOLLYON] = "APOLLYON",
	[PlayerType.PLAYER_THEFORGOTTEN] = "THE_FORGOTTEN",
	[PlayerType.PLAYER_THESOUL] = "THE_SOUL",
	[PlayerType.PLAYER_BETHANY] = "BETHANY",
	[PlayerType.PLAYER_JACOB] = "JACOB",
	[PlayerType.PLAYER_ESAU] = "ESAU",

	-- Tainted characters
	[PlayerType.PLAYER_ISAAC_B] = "ISAAC",
	[PlayerType.PLAYER_MAGDALENA_B] = "MAGDALENE",
	[PlayerType.PLAYER_CAIN_B] = "CAIN",
	[PlayerType.PLAYER_JUDAS_B] = "JUDAS",
	[PlayerType.PLAYER_XXX_B] = "BLUEBABY",
	[PlayerType.PLAYER_EVE_B] = "EVE",
	[PlayerType.PLAYER_SAMSON_B] = "SAMSON",
	[PlayerType.PLAYER_AZAZEL_B] = "AZAZEL",
	[PlayerType.PLAYER_LAZARUS_B] = "LAZARUS",
	[PlayerType.PLAYER_EDEN_B] = "EDEN",
	[PlayerType.PLAYER_THELOST_B] = "THE_LOST",
	[PlayerType.PLAYER_LILITH_B] = "LILITH",
	[PlayerType.PLAYER_KEEPER_B] = "KEEPER",
	[PlayerType.PLAYER_APOLLYON_B] = "APOLLYON",
	[PlayerType.PLAYER_THEFORGOTTEN_B] = "THE_FORGOTTEN",
	[PlayerType.PLAYER_BETHANY_B] = "BETHANY",
	[PlayerType.PLAYER_JACOB_B] = "JACOB",
	[PlayerType.PLAYER_LAZARUS2_B] = "LAZARUS2",
	[PlayerType.PLAYER_THESOUL_B] = "THE_SOUL",
	[-100] = "FOUND_SOUL",
}

function funct.get_display_name(player)
	local tp = player:GetPlayerType()
	if auxi.is_found_soul(player) then tp = -100 end
	local ret = Copy_of_player_display_name[tp] or ""
	return ret
end

function funct.get_player_display_name(player)
	local ret = funct.get_display_name(player)
	if ret == "" then 
		local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder") 
		ret = item_displaying_holder.check_description("Player",player:GetPlayerType(),ret,"",player).Name
	end
	if ret == "" then ret = player:GetName() end
	return ret
end

function funct.get_players_display_name()
	local cname = auxi.get_player_display_name(Game():GetPlayer(0))
	local name = auxi.check_name_data("#"..cname.."_NAME",cname)
	local and_name = "+ "
	for playerNum = 2, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local cname = auxi.get_player_display_name(player)
		local ret = auxi.check_name_data("#"..cname.."_NAME",cname)
		name = name .. and_name .. ret
	end
	return name
end

function funct.move_in_sq(pos,col,raw)
	local i = pos//col
	local j = pos - i*col
	local ret = {}
	if i > 0 then
		table.insert(ret,#ret+1,{id = (i-1)*col+j,dir = 3,})
	end
	if j > 0 then
		table.insert(ret,#ret+1,{id = i*col+j-1,dir = 2,})
	end
	if i < col - 1 then
		table.insert(ret,#ret+1,{id = (i+1)*col+j,dir = 1,})
	end
	if j < raw - 1 then
		table.insert(ret,#ret+1,{id = i*col+j+1,dir = 0,})
	end
	return ret
end

function funct.move_in_rou(pos,col,raw)
	local i = pos//col
	local j = pos - i*col
	local ret = {}
	if i > 0 then
		table.insert(ret,#ret+1,(i-1)*col+j)
		if j > 0 then
			table.insert(ret,#ret+1,(i-1)*col+j-1)
		end
		if j < raw - 1 then
			table.insert(ret,#ret+1,(i-1)*col+j+1)
		end
	end
	if j > 0 then
		table.insert(ret,#ret+1,i*col+j-1)
	end
	if j < raw - 1 then
		table.insert(ret,#ret+1,i*col+j+1)
	end
	if i < col - 1 then
		table.insert(ret,#ret+1,(i+1)*col+j)
		if j > 0 then
			table.insert(ret,#ret+1,(i+1)*col+j-1)
		end
		if j < raw - 1 then
			table.insert(ret,#ret+1,(i+1)*col+j+1)
		end
	end
	return ret
end

local dir_vec = {
	[Direction.NO_DIRECTION] = Vector(0,0),
	[Direction.LEFT] = Vector(-1,0),
	[Direction.UP] = Vector(0,-1),
	[Direction.RIGHT] = Vector(1,0),
	[Direction.DOWN] = Vector(0,1),
}

function funct.GetDirVec(dir)
	return dir_vec[dir] or Vector(0,0)
end

function funct.GetfamiliarDir(ent, dir, allow_king)
	if allow_king == nil then allow_king = true end

    local player = ent.Player
    if (allow_king) then
        if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_KING_BABY) then
            local n_entity = Isaac.GetRoomEntities()
			local n_enemy = funct.getenemies(n_entity)
            if (#n_enemy > 0) then
                local dr = (n_enemy[1].Position - ent.Position):Normalized()
				local dis = (n_enemy[1].Position - ent.Position):Length()
				for i = 2,#n_enemy do
					if (n_enemy[i].Position - ent.Position):Length() < dis then
						dis = (n_enemy[i].Position - ent.Position):Length()
						dr = (n_enemy[i].Position - ent.Position):Normalized()
					end
				end
				ent:GetData().should_attack = true
                return dr
            end
			ent:GetData().should_attack = false
        end
    end
	return funct.GetDirVec(dir)
end

function funct.get_by_familiar_dir(ent,params)
	local player = params.player or ent.Player or Game():GetPlayer(0)
	params = params or {}
	local dgir = auxi.ggdir(player,false,true)		--?
	if gdir:Length() < 0.05 then return {dir = gdir,auto = false,} end
	if not params.ignore_king then
		if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_KING_BABY) then
			local tg = funct.get_nearest_enemy(nil,ent.Position)
			if tg then
				return {dir = (tg.Position - ent.Position):Normalized(),auto = true,}
			end
		end
	end
	return {dir = gdir,auto = false,}
end

local dir_name = {
	[Direction.NO_DIRECTION] = "Down",
	[Direction.LEFT] = "Side",
	[Direction.UP] = "Up",
	[Direction.RIGHT] = "Side",
	[Direction.DOWN] = "Down",
}

function funct.GetDirName(dir)
	return dir_name[dir]
end

local Dir_name = {
	[Direction.NO_DIRECTION] = "Up",
	[Direction.LEFT] = "Left",
	[Direction.UP] = "Up",
	[Direction.RIGHT] = "Right",
	[Direction.DOWN] = "Down",
}

function funct.Get_dir_name(dir,map)
	map = map or Dir_name
	return map[dir]
end

function funct.Get_direction_by_angle(angle)		--特殊的转法
    angle = angle % 360
    local dir = Direction.NO_DIRECTION
    if (math.abs(angle - 0) < 45 or math.abs(angle - 360) < 45) then
        dir = Direction.UP
    elseif (math.abs(angle - 270) < 45) then
        dir = Direction.LEFT
    elseif (math.abs(angle - 180) < 45) then
        dir = Direction.DOWN
    elseif (math.abs(angle - 90) < 45) then
        dir = Direction.RIGHT
    end
    return dir
end

function funct.Get_dir_name_by_vel(vel,map)
	return auxi.Get_dir_name(auxi.Get_direction_by_angle(vel:GetAngleDegrees()),map)
end

local Dir_ang = {
	Left = 270,
	Up = 0,
	Right = 90,
	Down = 180,
}

function funct.Get_Angle_by_Degree_Name(dir)
	return Dir_ang[dir]
end

function funct.Direction_Plus(dir1,dir2)
	if type(dir1) == "string" then dir1 = funct.Get_Angle_by_Degree_Name(dir1) end 
	if type(dir2) == "string" then dir2 = funct.Get_Angle_by_Degree_Name(dir2) end 
	return funct.Get_dir_name(funct.Get_direction_by_angle(dir1 + dir2))
end

function funct.GetDirectionByAngle(angle)
    angle = angle % 360
    local dir = Direction.NO_DIRECTION
    if (math.abs(angle - 0) < 45 or math.abs(angle - 360) < 45) then
        dir = Direction.RIGHT
    elseif (math.abs(angle - 270) <= 45) then
        dir = Direction.UP
    elseif (math.abs(angle - 180) < 45) then
        dir = Direction.LEFT
    elseif (math.abs(angle - 90) <= 45) then
        dir = Direction.DOWN
    end
    return dir
end

local RoomType_to_IconIDs = {
	nil,
    "Shop",
    nil,
    "TreasureRoom",
    "Boss",
    "Miniboss",
    "SecretRoom",
    "SuperSecretRoom",
    "Arcade",
    "CurseRoom",
    "AmbushRoom",
    "Library",
    "SacrificeRoom",
    nil,
    "AngelRoom",
    nil,
    "BossAmbushRoom",
    "IsaacsRoom",
    "BarrenRoom",
    "ChestRoom",
    "DiceRoom",
    nil, -- black market
    nil,-- "GreedExit",
	"Planetarium",
	nil, -- Teleporter
	nil, -- Teleporter_Exit
	nil, -- doesnt exist
	nil, -- doesnt exist
	"UltraSecretRoom"
}

function funct.GetNameByRoomType(name)
	return RoomType_to_IconIDs[name]
end

function funct.IsAmbushBoss()
	if Game():GetLevel():HasBossChallenge() then return true 
	else return false end
end

function funct.is_movable_enemy(ent,not_allow_boss)			--不可移动30、60、53、221、231、300、305、306、809、307、856、861、298		--特殊39.22、35.0、35.2、816、213、219、228、285、287		--水生311、825	--钻地244、58、59、56、255、276、829、881	--爬墙240	--会跳34、38、86、54、869、29、85、94、215、250	--值得实验882	--85号蜘蛛禁了
	if (ent.Type == 30) or (ent.Type == 85) or (ent.Type == 60) or (ent.Type == 39 and ent.Variant == 22) or (ent.Type == 35 and (ent.Variant == 0 or ent.Variant == 2)) or (ent.Type == 53) or (ent.Type == 231) or (ent.Type == 306) or (ent.Type == 298) or (ent.Type == 244) or (ent.Type == 816) or (ent.Type == 58) or (ent.Type == 59) or (ent.Type == 56) or (ent.Type == 213) or (ent.Type == 219) or (ent.Type == 240) or (ent.Type == 221) or (ent.Type == 228) or (ent.Type == 255) or (ent.Type == 276) or (ent.Type == 285) or (ent.Type == 287) or (ent.Type == 300) or (ent.Type == 805) or (ent.Type == 309) or (ent.Type == 307) or (ent.Type == 311) or (ent.Type == 825) or (ent.Type == 856) or (ent.Type == 861) or (ent.Type == 829) or (ent.Type == 881) or (ent.Type == 996) then
		return false
	end
	if not_allow_boss and not_allow_boss == true then		--不可移动36、45、78、84、101、262、266、263、270、274、275、273、906、911、914 --特殊407、412、403、411、406、903、912、951		--爬墙900 	--钻地62、269、401	 --会跳20、43、68、65、69、100、74-76、102、264、265、267、268、404、406
		if (ent.Type == 45) or (ent.Type == 62) or (ent.Type == 407) or (ent.Type == 406) or (ent.Type == 411) or (ent.Type == 403) or (ent.Type == 900) or (ent.Type == 412) or (ent.Type == 903) or (ent.Type == 906) or (ent.Type == 911) or (ent.Type == 912) or (ent.Type == 914) or (ent.Type == 951) or (ent.Type == 950) or (ent.Type == 78) or (ent.Type == 84) or (ent.Type == 101) or (ent.Type == 262) or (ent.Type == 269) or (ent.Type == 401) or (ent.Type == 273) or (ent.Type == 275) or (ent.Type == 274) or (ent.Type == 270) or (ent.Type == 263) or (ent.Type == 266) then
			return false
		end
	end
	return true
end

local ignoreFlags = DamageFlag.DAMAGE_DEVIL | DamageFlag.DAMAGE_IV_BAG | DamageFlag.DAMAGE_FAKE | DamageFlag.DAMAGE_CURSED_DOOR | DamageFlag.DAMAGE_NO_PENALTIES
function funct.is_damage_from_enemy(ent, amt, flag, source, cooldown)
	if amt > 0 and ((source and source.Type ~= EntityType.ENTITY_SLOT and source.Type ~= EntityType.ENTITY_PLAYER) or not source) and (flag & ignoreFlags) == 0	then return true
	else return false end
end

local FullRedHeartPlayers = {
    [PlayerType.PLAYER_KEEPER] = true,
    [PlayerType.PLAYER_BETHANY] = true,
    [PlayerType.PLAYER_KEEPER_B] = true,
}

local FullBoneHeartPlayers = {
    [PlayerType.PLAYER_THEFORGOTTEN] = true,
}

local KeeperPlayers = {
    [PlayerType.PLAYER_KEEPER] = true,
    [PlayerType.PLAYER_KEEPER_B] = true,
}

local LostPlayers = {
    [PlayerType.PLAYER_THELOST] = true,
    [PlayerType.PLAYER_THELOST_B] = true,
}

local FullCoinHeartPlayers = {
    [PlayerType.PLAYER_KEEPER] = true,
    [PlayerType.PLAYER_KEEPER_B] = true,
}

local FullSoulHeartPlayers = {
    [PlayerType.PLAYER_BETHANY_B] = true,
    [PlayerType.PLAYER_BLACKJUDAS] = true,		--其实黑犹大应该算黑心
    [PlayerType.PLAYER_BLUEBABY] = true,
    [PlayerType.PLAYER_BLUEBABY_B] = true,
    [PlayerType.PLAYER_THEFORGOTTEN_B] = true,
}

function funct.is_player_keeper(player)
	return KeeperPlayers[player:GetPlayerType()] ~= nil
end

function funct.has_keeper_player()
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if KeeperPlayers[player:GetPlayerType()] then return true end
	end
	return false
end

function funct.is_player_lost_(player)
	return (LostPlayers[player:GetPlayerType()] ~= nil) or (player:GetEffects():HasNullEffect(NullItemID.ID_LOST_CURSE))
end

function funct.is_player_lost(player)
	return LostPlayers[player:GetPlayerType()] ~= nil
end

function funct.is_player_only_bone_hearts(player)
	return FullBoneHeartPlayers[player:GetPlayerType()] ~= nil
end

function funct.is_player_only_coin_hearts(player)
	return FullCoinHeartPlayers[player:GetPlayerType()] ~= nil
end

function funct.is_player_only_red_hearts(player)
	return FullRedHeartPlayers[player:GetPlayerType()] ~= nil
end

function funct.is_player_only_soul_hearts(player)
	if FullSoulHeartPlayers[player:GetPlayerType()] ~= nil then
		return true 
	else
		if auxi.has_have_coll(player,enums.Items.Darkness) then
			return true
		end
	end
	return false
end

function funct.add_soul_heart(player,num)
	if (player:HasCollectible(CollectibleType.COLLECTIBLE_ALABASTER_BOX, true)) then
        local alabasterCharges = {}
        for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do   
            if (player:GetActiveItem(slot) == CollectibleType.COLLECTIBLE_ALABASTER_BOX) then
                alabasterCharges[slot] = player:GetActiveCharge (slot) + player:GetBatteryCharge (slot)
                if (num > 0) then
                    player:SetActiveCharge(12, slot)
                else
                    player:SetActiveCharge(0, slot)
                end
            end
        end
        player:AddSoulHearts(num)
        for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do   
            if (player:GetActiveItem(slot) == CollectibleType.COLLECTIBLE_ALABASTER_BOX) then
                player:SetActiveCharge(alabasterCharges[slot], slot)
            end
        end
    else
        player:AddSoulHearts(num)
    end
end

local LostPlayers = {
    [PlayerType.PLAYER_THESOUL] = true,
    [PlayerType.PLAYER_THELOST] = true,
    [PlayerType.PLAYER_THELOST_B] = true,
    [PlayerType.PLAYER_THESOUL_B] = true,
}

function funct.get_death_animation_to_play(player)
	local tp = player:GetPlayerType()
	if LostPlayers[tp] ~= nil then return "LostDeath" end
    if (player:GetEffects():HasNullEffect(NullItemID.ID_LOST_CURSE)) then return "LostDeath" end
	return "Death"
end

function funct.get_active_charge(player,params)
	params = params or {}
	player = player or Game():GetPlayer(0)
	local charge = 0
	for u,i in pairs(params.slots or {0,1,2,3,}) do
		if player:GetActiveCharge(i) > 0 and player:GetActiveCharge(i) <= 12 then
			charge = charge + player:GetActiveCharge(i) + player:GetBatteryCharge(i)
		elseif player:GetActiveCharge(i) > 0 then
			charge = charge + 1
		end
	end
	return charge
end

function funct.get_coll_full_charge(player,collid)
	local ret = false
	local mx_charge = Isaac:GetItemConfig():GetCollectible(collid).MaxCharges
	for i = 0,4 do if player:GetActiveItem(i) == collid and player:GetActiveCharge(i) >= mx_charge then ret = true break end end
	return ret
end

function funct.add_charge(player,cnt,params)
	params = params or {}
	local ccnt = cnt
	for u,i in pairs(params.slots or {0,1,2,3,}) do
		while (player:NeedsCharge(i) and cnt > 0) do
			player:SetActiveCharge(player:GetActiveCharge(i) + player:GetBatteryCharge(i) + 1,i)
			cnt = cnt - 1
		end
	end
	if ccnt ~= cnt and params.no_sound ~= true then sound_tracker.PlayStackedSound(SoundEffect.SOUND_ITEMRECHARGE,1.5,1,false,0,2) end
	return ccnt - cnt
end

function funct.have_player(pt)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if player:GetPlayerType() == pt then
			return true
		end
	end
	return false
end

function funct.get_player_have_trinket_num(val,real,params)
	params = params or {}
	val = val or 33
	local ret = 0
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		ret = ret + (auxi.check_if_any(params.counter,player,val) or player:GetTrinketMultiplier(val,real))
	end
	return ret
end

function funct.get_player_have_collectible_num(val,real,params)
	params = params or {}
	val = val or 33
	local ret = 0
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		ret = ret + (auxi.check_if_any(params.counter,player,val) or player:GetCollectibleNum(val,real))
	end
	return ret
end

function funct.have_player_queue_collectible(val)
	val = val or 33
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if (not player:IsItemQueueEmpty()) and player.QueuedItem.Item.ID == val then
			return player
		end
	end
end

function funct.have_player_has_collectible(val,real)
	val = val or 33
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if real then
			if player:HasCollectible(val,true) then return player end
		else
			if funct.has_have_coll(player,val) then return player end
		end
	end
	return nil
end

function funct.get_collectible_num_all(val,real)	--所有角色拥有val道具的数量
	val = val or 33
	local ret = 0
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		ret = ret + player:GetCollectibleNum(val,real)
	end
	return ret
end

function funct.has_and_have_coll(player,collid)
	if player == nil or collid == nil then return false end
	return player:HasCollectible(collid) or player:GetEffects():HasCollectibleEffect(collid)
end

function funct.has_have_coll_(player,collid)
	if player == nil or collid == nil then return false end
	player = player:ToPlayer() if player == nil then return false end
	return player:HasCollectible(collid,true)
end

function funct.has_have_coll(player,collid)
	if player == nil or collid == nil then return false end
	player = player:ToPlayer() if player == nil then return false end
	return player:HasCollectible(collid)
end

function funct.has_or_have_coll(player,collid)
	if auxi.has_have_coll(player,collid) then return player end
	if auxi.has_have_coll(player:GetOtherTwin(),collid) then return player:GetOtherTwin() end
end

function funct.has_or_have_coll_(player,collid)
	if auxi.has_have_coll_(player,collid) then return player end
	if auxi.has_have_coll_(player:GetOtherTwin(),collid) then return player:GetOtherTwin() end
end

function funct.have_player_has_trinket(val,real)
	val = val or 1
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if real then
			if player:HasTrinket(val,true) then return player end
		else
			if player:HasTrinket(val) then return player end
		end
	end
	return nil
end

local DifficultPlayers = {
    [PlayerType.PLAYER_KEEPER] = true,
    [PlayerType.PLAYER_KEEPER_B] = true,
    [PlayerType.PLAYER_THELOST] = true,
    [PlayerType.PLAYER_THELOST_B] = true,
}

function funct.is_player_lost(player)
	if player:GetPlayerType() == PlayerType.PLAYER_THELOST or player:GetPlayerType() == PlayerType.PLAYER_THELOST_B then return true end
	local effect = player:GetEffects()
	if (effect:HasNullEffect(NullItemID.ID_LOST_CURSE)) then
		return true
	end
end

function funct.is_player_has_mantle(player)
	return player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_HOLY_MANTLE)
end

function funct.is_player_difficult(player)
	return DifficultPlayers[player:GetPlayerType()] ~= nil
end

function funct.to_find_spawner(ent)
	local ret = ent
	if ent:GetData() and ent:GetData().to_find_spawner_marked == nil then
		ent:GetData().to_find_spawner_marked = true				--防止无限loop
		if ent:GetData().to_find_spawner_minder then
			ret = ent:GetData().to_find_spawner_minder
		else
			if ent.SpawnerEntity then
				ret = funct.to_find_spawner(ent.SpawnerEntity)
			end
		end
		ent:GetData().to_find_spawner_minder = ret
		ent:GetData().to_find_spawner_marked = nil
	end
	return ret
end

function funct.is_poop_player(player)
	return player:GetPlayerType() == 25
end

function funct.has_poop_player()
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if funct.is_poop_player(player) then
			return true
		end
	end
	return false
end

function funct.has_difficult_player()
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if funct.is_player_difficult(player) then
			return true
		end
	end
	return false
end

function funct.randomTable(_table, rng) 
	if rng then rng = funct.rng_for_sake(rng) end
	if type(_table)~= "table" then
        return {}
    end
	local tab = {}
    for i = 1,#_table do
		local id
		if rng then 
			id = (rng:RandomInt(#_table) + 1)
		else 
			id = math.random(#_table) 
		end
		tab[i] = _table[id]
		table.remove(_table,id)
	end
	return tab
end

function funct.randomOverTable(_table,rng)
	if rng then rng = funct.rng_for_sake(rng) end
	if type(_table)~= "table" then return {} end
	local tab = {}
	local tb = {}
    for u,v in pairs(_table) do table.insert(tb,#tb + 1,u) end
	local tb2 = auxi.deepCopy(tb)
	tb = auxi.randomTable(tb,rng)
    for u,v in pairs(tb) do	tab[tb2[u]] = _table[v] end
	return tab
end

function funct.is_double_player()		--似乎只有双子才会导致特殊的ui。
	local check_1 = false
	local check_2 = false
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local pt = player:GetPlayerType()
		if pt == PlayerType.PLAYER_JACOB then
			check_1 = true
		elseif pt == PlayerType.PLAYER_ESAU then
			check_2 = true
		end
	end
	return (check_1 and check_2)
end

function funct.check_empty_table(tbl)
	if type(tbl) ~= "table" then return false end
	if (#tbl == 0) then return true end	
	return false
end

local restock_roomtypes = {
	[RoomType.ROOM_SHOP] = true,
}

function funct.can_restock()
	if restock_roomtypes[Game():GetRoom():GetType()] ~= true then return false end
	if Game():IsGreedMode() then return true end
	if funct.have_player_has_collectible(CollectibleType.COLLECTIBLE_RESTOCK) then return true end
	return false
end

function funct.check_shop_pickup(ent,player)		--返回真为不购买
	--if ent.FrameCount == 0 then print(1) return false end		--取消第一帧
	if player:IsExtraAnimationFinished() ~= true then return true end
	if ent.Price > 0 and ent.Price > player:GetNumCoins() then return true end
end

function funct.buy_a_pickup(ent,player,params)
	params = params or {}
	if ent.Price > 0 then 
		player:AddCoins(-ent.Price)
		if funct.has_have_coll(player,CollectibleType.COLLECTIBLE_KEEPERS_SACK) then 
			player:GetData().Keeper_Sack_adder = (player:GetData().Keeper_Sack_adder or 0) + ent.Price
		end
		-- Flight 店长袋材料：未真实持有时独立累计消费（不依赖玩家持有道具）
		local Dyn = require("Qing_Remaster_scripts.others.craft_dynamic_stats")
		if Dyn and Dyn.on_player_spent_coins then
			Dyn.on_player_spent_coins(player, ent.Price)
		end
	end
	if ent.Price <= -1 and ent.Price >= -10 then Game():AddDevilRoomDeal() end
	if ent.Price == -1 then player:AddMaxHearts(-2) end
	if ent.Price == -2 then player:AddMaxHearts(-4) end
	if ent.Price == -3 then funct.add_soul_heart(player,-6) end
	if ent.Price == -4 then player:AddMaxHearts(-2) funct.add_soul_heart(player,-4) end
	if ent.Price == -5 then if not auxi.is_player_lost_(player) then player:TakeDamage(2,DamageFlag.DAMAGE_NO_PENALTIES | DamageFlag.DAMAGE_SPIKES,EntityRef(player),60) end end
	if ent.Price == -6 then local player = funct.have_player_has_trinket(TrinketType.TRINKET_YOUR_SOUL) if player then player:TryRemoveTrinket(TrinketType.TRINKET_YOUR_SOUL) end end
	if ent.Price == -7 then funct.add_soul_heart(player,-2) end
	if ent.Price == -8 then funct.add_soul_heart(player,-4) end
	if ent.Price == -9 then funct.add_soul_heart(player,-2) player:AddMaxHearts(-2) end
	if ent.Price == -1000 then local player = funct.have_player_has_trinket(TrinketType.TRINKET_STORE_CREDIT) if player then player:TryRemoveTrinket(TrinketType.TRINKET_STORE_CREDIT) end end
	if params.NoAnim ~= true then player:AnimatePickup(ent:GetSprite()) end
	local id = ent.ShopItemId
	if params.no_remove ~= true then 
		if auxi.can_restock() then 
			Restock_holder = Restock_holder or require("Qing_Remaster_scripts.mimics.Restock_holder")
			Restock_holder.Try_restock(ent)
		end
		ent:Remove() 
	end
end

function funct.can_buy(price,player)
	if type(price) == "userdata" then if price.Price then price = price.Price else return false end end
	player = player or Game():GetPlayer(0)
	if price == -1000 then return true end
	if price > 0 then return (price <= player:GetNumCoins()) end
	return true
end

function funct.remove_others_option_pickup(ent,effect)
	if ent.OptionsPickupIndex == 0 then return end
	effect = effect or true
	ent:GetData().OptionsPickupIndex_should_remove = true
	local n_entity = Isaac.GetRoomEntities()
	for u,v in pairs(n_entity) do
		if v:ToPickup() then
			local pickup = v:ToPickup()
			if pickup.OptionsPickupIndex == ent.OptionsPickupIndex and pickup:GetData().OptionsPickupIndex_should_remove ~= true then
				if effect then Isaac.Spawn(1000,15,0,pickup.Position,Vector(0,0),nil) end
				pickup:Remove()
			end
		end
	end
end

local questionMarkSprite = Sprite()
questionMarkSprite:Load("gfx/005.100_collectible.anm2", true)
questionMarkSprite:ReplaceSpritesheet(1,"gfx/items/collectibles/questionmark.png")
questionMarkSprite:LoadGraphics()

function funct.IsAltChoice(ent)
	--if EID then return EID:getEntityData(ent, "EID_DontHide") end
	local s = ent:GetSprite()
	local name = s:GetAnimation()
	if name ~= "Idle" and name ~= "ShopIdle" then
		ent:GetData()["EID_IsAltChoice"] = false
		return false
	end
	questionMarkSprite:SetFrame(name,s:GetFrame())
	for i = -1,1,1 do
		for j = -40,10,3 do
			local qcolor = questionMarkSprite:GetTexel(Vector(i,j),Vector(0,0),1,1)
			local ecolor = s:GetTexel(Vector(i,j),Vector(0,0),1,1)
			if qcolor.Red ~= ecolor.Red or qcolor.Green ~= ecolor.Green or qcolor.Blue ~= ecolor.Blue then
				ent:GetData()["EID_IsAltChoice"] = false
				return false
			end
		end
	end
	ent:GetData()["EID_IsAltChoice"] = true
	return true
end

function funct.isBlindPickup(ent)
	if type(ent) == "table" then return (Game():GetLevel():GetCurses() & LevelCurse.CURSE_OF_BLIND ~= 0) end
	return (Game():GetLevel():GetCurses() & LevelCurse.CURSE_OF_BLIND ~= 0 and not ent.Touched) or (not ent.Touched and funct.IsAltChoice(ent)) or (Game().Challenge == Challenge.CHALLENGE_APRILS_FOOL)
end

function funct.GetScreenSize()
	local room = Game():GetRoom()
	local pos = room:WorldToScreenPosition(Vector(0,0)) - room:GetRenderScrollOffset() - Game().ScreenShakeOffset
	local rx = pos.X + 60 * 26 / 40
	local ry = pos.Y + 140 * (26 / 40)
	return Vector(rx*2 + 13*26, ry*2 + 7*26)
end

function funct.GetWaterRenderOffset()
	return - (auxi.GetScreenSize() - Vector(442,288)) * 0.5
end

function funct.GetScreenCenter()
	return funct.GetScreenSize() / 2
end

function funct.myScreenToWorld(pos)
	local room = Game():GetRoom()
	local pos_z = Vector(0,0)
	local r_pos_z = Isaac.WorldToScreen(pos_z) - room:GetRenderScrollOffset() - Game().ScreenShakeOffset
	local pos_d = Vector(10,10)
	local r_pos_d = Isaac.WorldToScreen(pos_d) - r_pos_z - room:GetRenderScrollOffset() - Game().ScreenShakeOffset
	r_pos_d = r_pos_d / 10
	local ret = (pos - r_pos_z)
	if r_pos_d.X ~= 0 then ret.X = ret.X / r_pos_d.X end
	if r_pos_d.Y ~= 0 then ret.Y = ret.Y / r_pos_d.Y end
	return ret
end

function funct.real_ScreenToWorld(pos)
	return auxi.myScreenToWorld(pos) + Isaac.ScreenToWorld(Vector(0,0)) - auxi.myScreenToWorld(Vector(0,0))
end

local itemlist = nil
function funct.GetItemList()
	if itemlist == nil then
		itemlist = {}
		local config = Isaac:GetItemConfig()
		local collectibles = config:GetCollectibles()
		local size = collectibles.Size
		for i= 1, size do
			local collectible = config:GetCollectible(i)
			if collectible then
				table.insert(itemlist,#itemlist + 1,i)
			end
		end
	end
	return itemlist
end

function funct.get_heart_info(player)
	local ret = {}
	local mx_heart = player:GetMaxHearts()
	ret["mx_heart"] = mx_heart
	local gd_heart = player:GetGoldenHearts()
	ret["gd_heart"] = gd_heart
	local rt_heart = player:GetRottenHearts()
	ret["rt_heart"] = rt_heart
	local et_heart = player:GetEternalHearts()
	ret["et_heart"] = et_heart
	local bl_heart = funct.Count_Flags(player:GetBlackHearts())
	ret["bl_heart"] = bl_heart
	local rd_heart = player:GetHearts()
	ret["rd_heart"] = rd_heart
	local sl_heart = player:GetSoulHearts()
	ret["sl_heart"] = sl_heart
	local lim_heart = player:GetHeartLimit()
	ret["lim_heart"] = lim_heart
	local bone_heart = player:GetBoneHearts()
	ret["bone_heart"] = bone_heart
	return ret
end

function funct.get_basic_counter(player)
	local ret = {}
	local bomb_counter = player:GetNumBombs()
	table.insert(ret,#ret + 1,{counter = bomb_counter,name = "bomb",})
	local gbomb = 0
	if player:HasGoldenBomb() then gbomb = 1 end
	table.insert(ret,#ret + 1,{counter = gbomb,name = "gbomb",})
	local key_counter = player:GetNumKeys()
	table.insert(ret,#ret + 1,{counter = key_counter,name = "key",})
	local gkey = 0
	if player:HasGoldenKey() then gkey = 1 end
	table.insert(ret,#ret + 1,{counter = gkey,name = "gkey",})
	local coin_counter = player:GetNumCoins()
	table.insert(ret,#ret + 1,{counter = coin_counter,name = "coin",})
	local mx_heart = player:GetMaxHearts()
	table.insert(ret,#ret + 1,{counter = mx_heart,name = "mx_heart",})
	local gd_heart = player:GetGoldenHearts()
	table.insert(ret,#ret + 1,{counter = gd_heart,name = "gd_heart",})
	local rt_heart = player:GetRottenHearts()
	table.insert(ret,#ret + 1,{counter = rt_heart,name = "rt_heart",})
	local et_heart = player:GetEternalHearts()
	table.insert(ret,#ret + 1,{counter = et_heart,name = "et_heart",})
	local bl_heart = funct.Count_Flags(player:GetBlackHearts())
	table.insert(ret,#ret + 1,{counter = bl_heart,name = "bl_heart",})
	local rd_heart = player:GetHearts()
	if funct.is_player_keeper(player) then rd_heart = math.ceil(rd_heart * 0.5) end
	table.insert(ret,#ret + 1,{counter = rd_heart,name = "rd_heart",})
	local sl_heart = player:GetSoulHearts()
	table.insert(ret,#ret + 1,{counter = sl_heart,name = "sl_heart",})
	local bk_heart = player:GetBrokenHearts()
	table.insert(ret,#ret + 1,{counter = bk_heart,name = "bk_heart",})
	local lim_heart = player:GetHeartLimit()
	table.insert(ret,#ret + 1,{counter = lim_heart,name = "lim_heart",})
	local bone_heart = player:GetBoneHearts()
	table.insert(ret,#ret + 1,{counter = bone_heart,name = "bn_heart",})
	return auxi.move_table(ret)
end

function funct.move_table(tbl)
	local ret = {}
	for u,v in pairs(tbl) do ret[v.name] = v end
	return ret
end

function funct.will_die(player)
	return player:GetHearts() == 0 and player:GetSoulHearts() == 0 and player:GetBoneHearts() == 0
end

function funct.get_absolute_heart(player)
	local ret = player:GetBoneHearts() + player:GetSoulHearts() + player:GetEternalHearts() + player:GetHearts()
	if funct.is_player_difficult(player) then ret = ret / 2 end
	return ret
end

function funct.GetOffsetedGridIndex(index, offset)
	local room = Game():GetRoom()
    local roomWidth = room:GetGridWidth()
    local roomHeight = room:GetGridHeight()
    local roomSize = room:GetGridSize()
	local xoff = 0
	local yoff = 0
	if (offset == Direction.LEFT) then
		xoff = -1
	elseif (offset == Direction.UP) then
		yoff = -1
	elseif (offset == Direction.RIGHT) then
		xoff = 1
	elseif (offset == Direction.DOWN) then
		yoff = 1
	end
	local indexX = index % roomWidth
	local indexY = math.floor(index / roomWidth)
	if (indexX + xoff >= 0 and indexX + xoff < roomWidth and indexY + yoff >= 0 and indexY + yoff < roomHeight) then
		return index + yoff * roomWidth + xoff
	end
	return -1
end

function funct.reverse_the_dir(dir)
	if dir and dir >= 0 and dir < 4 then
		return (dir + 2)% 4
	end
	return -1
end

function funct.CanPassGrid(index,flying) 
	local room = Game():GetRoom()
	local grid = room:GetGridEntity(index)
	if (grid == nil) then
		return true
	end
	if (flying) then
		return grid.CollisionClass ~= GridCollisionClass.COLLISION_WALL
	else
		return grid.CollisionClass ~= GridCollisionClass.COLLISION_PIT and grid.CollisionClass ~= GridCollisionClass.COLLISION_WALL and not (grid:GetType() == 3 and grid:GetVariant() == 10)
	end
end

local reversed_card_map = {
	[enums.Cards.Fool] = enums.Cards.Fool_r,
	[enums.Cards.Witch] = enums.Cards.Sage_r,
	[enums.Cards.Invoker] = enums.Cards.Sage_r,
	[enums.Cards.Wizard] = enums.Cards.Sage_r,
	[enums.Cards.Priestess] = enums.Cards.Priestess_r,
	[enums.Cards.Empress] = enums.Cards.Empress_r,
	[enums.Cards.Emperor] = enums.Cards.Emperor_r,
	[enums.Cards.Hierophant] = enums.Cards.Hierophant_r,
	[enums.Cards.Lover] = enums.Cards.Lover_r,
	[enums.Cards.Chariot] = enums.Cards.Chariot_r,
	[enums.Cards.Adjustment] = enums.Cards.Adjustment_r,
	[enums.Cards.Hermit] = enums.Cards.Hermit_r,
	[enums.Cards.Wheel_of_Destiny] = enums.Cards.Wheel_of_Destiny_r,
	[enums.Cards.Lure] = enums.Cards.Lure_r,
	[enums.Cards.Hanged_Man] = enums.Cards.Hanged_Man_r,
	[enums.Cards.Faint] = function(rg) 
		local rng if rg then rng = RNG() rng:SetSeed(rg:GetSeed(),0) end
		return funct.random_in_table({enums.Cards.Faint_r,enums.Cards.Death_r,enums.Cards.Corpse_r},rng)
	end,
	[enums.Cards.Art] = enums.Cards.Art_r,
	[enums.Cards.Devil] = enums.Cards.Devil_r,
	[enums.Cards.Tower] = enums.Cards.Tower_r,
	[enums.Cards.Star] = enums.Cards.Star_r,
	[enums.Cards.Moon] = enums.Cards.Moon_r,
	[enums.Cards.Sun] = enums.Cards.Sun_r,
	[enums.Cards.Aeon] = enums.Cards.Aeon_r,
	[enums.Cards.Universe] = enums.Cards.Universe_r,
	
	[enums.Cards.Fool_r] = enums.Cards.Fool,
	[enums.Cards.Sage_r] = function(rg) 
		local rng if rg then rng = RNG() rng:SetSeed(rg:GetSeed(),0) end
		return funct.random_in_table({enums.Cards.Witch,enums.Cards.Invoker,enums.Cards.Wizard},rng)
	end,
	[enums.Cards.Priestess_r] = enums.Cards.Priestess,
	[enums.Cards.Empress_r] = enums.Cards.Empress,
	[enums.Cards.Emperor_r] = enums.Cards.Emperor,
	[enums.Cards.Hierophant_r] = enums.Cards.Hierophant,
	[enums.Cards.Lover_r] = enums.Cards.Lover,
	[enums.Cards.Chariot_r] = enums.Cards.Chariot,
	[enums.Cards.Adjustment_r] = enums.Cards.Adjustment,
	[enums.Cards.Hermit_r] = enums.Cards.Hermit,
	[enums.Cards.Wheel_of_Destiny_r] = enums.Cards.Wheel_of_Destiny,
	[enums.Cards.Lure_r] = enums.Cards.Lure,
	[enums.Cards.Hanged_Man_r] = enums.Cards.Hanged_Man,
	[enums.Cards.Faint_r] = enums.Cards.Faint,
	[enums.Cards.Death_r] = enums.Cards.Faint,
	[enums.Cards.Corpse_r] = enums.Cards.Faint,
	[enums.Cards.Art_r] = enums.Cards.Art,
	[enums.Cards.Devil_r] = enums.Cards.Devil,
	[enums.Cards.Tower_r] = enums.Cards.Tower,
	[enums.Cards.Star_r] = enums.Cards.Star,
	[enums.Cards.Moon_r] = enums.Cards.Moon,
	[enums.Cards.Sun_r] = enums.Cards.Sun,
	[enums.Cards.Aeon_r] = enums.Cards.Aeon,
	[enums.Cards.Universe_r] = enums.Cards.Universe,
	
	[enums.Cards.Eclipse] = enums.Cards.Eclipse_r,
	[enums.Cards.Eclipse_r] = enums.Cards.Eclipse,
	[enums.Cards.Profound] = enums.Cards.Profound_r,
	[enums.Cards.Profound_r] = enums.Cards.Profound,
	[enums.Cards.Sting] = enums.Cards.Sting_r,
	[enums.Cards.Sting_r] = enums.Cards.Sting,
}

function funct.get_reversed_card(card,rng)
	if type(card) == "userdata" and card.SubType then card = card.SubType end
	if card > 0 and card < 23 then
		return card + 55
	elseif card > 55 and card < 78 then
		return card - 55
	elseif reversed_card_map[card] then
		return funct.check_if_any(reversed_card_map[card],rng)
	end
	return 0
end

local origin_card_map = {
	[enums.Cards.Fool] = enums.Cards.Fool_r,
	[enums.Cards.Witch] = enums.Cards.Sage_r,
	[enums.Cards.Invoker] = enums.Cards.Corpse_r,
	[enums.Cards.Wizard] = enums.Cards.Death_r,
	[enums.Cards.Priestess] = enums.Cards.Priestess_r,
	[enums.Cards.Empress] = enums.Cards.Empress_r,
	[enums.Cards.Emperor] = enums.Cards.Emperor_r,
	[enums.Cards.Hierophant] = enums.Cards.Hierophant_r,
	[enums.Cards.Lover] = enums.Cards.Lover_r,
	[enums.Cards.Chariot] = enums.Cards.Chariot_r,
	[enums.Cards.Adjustment] = enums.Cards.Adjustment_r,
	[enums.Cards.Hermit] = enums.Cards.Hermit_r,
	[enums.Cards.Wheel_of_Destiny] = enums.Cards.Wheel_of_Destiny_r,
	[enums.Cards.Lure] = enums.Cards.Lure_r,
	[enums.Cards.Hanged_Man] = enums.Cards.Hanged_Man_r,
	[enums.Cards.Faint] = function(rg) 
		local rng if rg then rng = RNG() rng:SetSeed(rg:GetSeed(),0) end
		return funct.random_in_table({enums.Cards.Faint_r,enums.Cards.Death_r,enums.Cards.Corpse_r},rng)
	end,
	[enums.Cards.Art] = enums.Cards.Art_r,
	[enums.Cards.Devil] = enums.Cards.Devil_r,
	[enums.Cards.Tower] = enums.Cards.Tower_r,
	[enums.Cards.Star] = enums.Cards.Star_r,
	[enums.Cards.Moon] = enums.Cards.Moon_r,
	[enums.Cards.Sun] = enums.Cards.Sun_r,
	[enums.Cards.Aeon] = enums.Cards.Aeon_r,
	[enums.Cards.Universe] = enums.Cards.Universe_r,
	
	[enums.Cards.Eclipse] = enums.Cards.Eclipse_r,
	[enums.Cards.Profound] = enums.Cards.Profound_r,
	[enums.Cards.Sting] = enums.Cards.Sting_r,
}

function funct.is_origin_card_map(cd)
	if origin_card_map[cd] then return true end
end

function funct.get_origin_card_map(cd,rng)
	if origin_card_map[cd] then return auxi.check_if_any(origin_card_map[cd],rng) end
end

local maped_card_map = {
	[Card.CARD_FOOL] = enums.Cards.Fool,
	[Card.CARD_MAGICIAN] = function(rg) 
		local rng if rg then rng = RNG() rng:SetSeed(rg:GetSeed(),0) end
		return funct.random_in_table({enums.Cards.Witch,enums.Cards.Invoker,enums.Cards.Wizard},rng)
	end,
	[Card.CARD_HIGH_PRIESTESS] = enums.Cards.Priestess,
	[Card.CARD_EMPRESS] = enums.Cards.Empress,
	[Card.CARD_EMPEROR] = enums.Cards.Emperor,
	[Card.CARD_HIEROPHANT] = function(rg) 
		local rng if rg then rng = RNG() rng:SetSeed(rg:GetSeed(),0) end
		return funct.random_in_table({enums.Cards.Hierophant,enums.Cards.Sting,},rng)
	end,
	[Card.CARD_LOVERS] = enums.Cards.Lover,
	[Card.CARD_CHARIOT] = enums.Cards.Chariot,
	[Card.CARD_JUSTICE] = enums.Cards.Adjustment,
	[Card.CARD_HERMIT] = enums.Cards.Hermit,
	[Card.CARD_WHEEL_OF_FORTUNE] = enums.Cards.Wheel_of_Destiny,
	[Card.CARD_STRENGTH] = enums.Cards.Lure,
	[Card.CARD_HANGED_MAN] = enums.Cards.Hanged_Man,
	[Card.CARD_DEATH] = enums.Cards.Faint,
	[Card.CARD_TEMPERANCE] = enums.Cards.Art,
	[Card.CARD_DEVIL] = enums.Cards.Devil,
	[Card.CARD_TOWER] = enums.Cards.Tower,
	[Card.CARD_STARS] = enums.Cards.Star,
	[Card.CARD_MOON] = enums.Cards.Moon,
	[Card.CARD_SUN] = function(rg) 
		local rng if rg then rng = RNG() rng:SetSeed(rg:GetSeed(),0) end
		return funct.random_in_table({enums.Cards.Sun,enums.Cards.Eclipse,},rng)
	end,
	[Card.CARD_JUDGEMENT] = enums.Cards.Aeon,
	[Card.CARD_WORLD] = function(rg) 
		local rng if rg then rng = RNG() rng:SetSeed(rg:GetSeed(),0) end
		return funct.random_in_table({enums.Cards.Universe,enums.Cards.Profound,},rng)
	end,
	
	[Card.CARD_REVERSE_FOOL] = enums.Cards.Fool_r,
	[Card.CARD_REVERSE_MAGICIAN] = enums.Cards.Sage_r,
	[Card.CARD_REVERSE_HIGH_PRIESTESS] = enums.Cards.Priestess_r,
	[Card.CARD_REVERSE_EMPRESS] = enums.Cards.Empress_r,
	[Card.CARD_REVERSE_EMPEROR] = enums.Cards.Emperor_r,
	[Card.CARD_REVERSE_HIEROPHANT] = function(rg) 
		local rng if rg then rng = RNG() rng:SetSeed(rg:GetSeed(),0) end
		return funct.random_in_table({enums.Cards.Hierophant_r,enums.Cards.Sting_r,},rng)
	end,
	[Card.CARD_REVERSE_LOVERS] = enums.Cards.Lover_r,
	[Card.CARD_REVERSE_CHARIOT] = enums.Cards.Chariot_r,
	[Card.CARD_REVERSE_JUSTICE] = enums.Cards.Adjustment_r,
	[Card.CARD_REVERSE_HERMIT] = enums.Cards.Hermit_r,
	[Card.CARD_REVERSE_WHEEL_OF_FORTUNE] = enums.Cards.Wheel_of_Destiny_r,
	[Card.CARD_REVERSE_STRENGTH] = enums.Cards.Lure_r,
	[Card.CARD_REVERSE_HANGED_MAN] = enums.Cards.Hanged_Man_r,
	[Card.CARD_REVERSE_DEATH] = function(rg) 
		local rng if rg then rng = RNG() rng:SetSeed(rg:GetSeed(),0) end
		return funct.random_in_table({enums.Cards.Faint_r,enums.Cards.Death_r,enums.Cards.Corpse_r},rng)
	end,
	[Card.CARD_REVERSE_DEATH] = enums.Cards.Death_r,
	[Card.CARD_REVERSE_DEATH] = enums.Cards.Corpse_r,
	[Card.CARD_REVERSE_TEMPERANCE] = enums.Cards.Art_r,
	[Card.CARD_REVERSE_DEVIL] = enums.Cards.Devil_r,
	[Card.CARD_REVERSE_TOWER] = enums.Cards.Tower_r,
	[Card.CARD_REVERSE_STARS] = enums.Cards.Star_r,
	[Card.CARD_REVERSE_MOON] = enums.Cards.Moon_r,
	[Card.CARD_REVERSE_SUN] = function(rg) 
		local rng if rg then rng = RNG() rng:SetSeed(rg:GetSeed(),0) end
		return funct.random_in_table({enums.Cards.Sun_r,enums.Cards.Eclipse_r,},rng)
	end,
	[Card.CARD_REVERSE_JUDGEMENT] = enums.Cards.Aeon_r,
	[Card.CARD_REVERSE_WORLD] = function(rg) 
		local rng if rg then rng = RNG() rng:SetSeed(rg:GetSeed(),0) end
		return funct.random_in_table({enums.Cards.Universe_r,enums.Cards.Profound_r,},rng)
	end,
	
	[enums.Cards.Fool] = Card.CARD_FOOL,
	[enums.Cards.Witch] = Card.CARD_MAGICIAN,
	[enums.Cards.Invoker] = Card.CARD_MAGICIAN,
	[enums.Cards.Wizard] = Card.CARD_MAGICIAN,
	[enums.Cards.Priestess] = Card.CARD_HIGH_PRIESTESS,
	[enums.Cards.Empress] = Card.CARD_EMPRESS,
	[enums.Cards.Emperor] = Card.CARD_EMPEROR,
	[enums.Cards.Hierophant] = Card.CARD_HIEROPHANT,
	[enums.Cards.Lover] = Card.CARD_LOVERS,
	[enums.Cards.Chariot] = Card.CARD_CHARIOT,
	[enums.Cards.Adjustment] = Card.CARD_JUSTICE,
	[enums.Cards.Hermit] = Card.CARD_HERMIT,
	[enums.Cards.Wheel_of_Destiny] = Card.CARD_WHEEL_OF_FORTUNE,
	[enums.Cards.Lure] = Card.CARD_STRENGTH,
	[enums.Cards.Hanged_Man] = Card.CARD_HANGED_MAN,
	[enums.Cards.Faint] = Card.CARD_DEATH,
	[enums.Cards.Art] = Card.CARD_TEMPERANCE,
	[enums.Cards.Devil] = Card.CARD_DEVIL,
	[enums.Cards.Tower] = Card.CARD_TOWER,
	[enums.Cards.Star] = Card.CARD_STARS,
	[enums.Cards.Moon] = Card.CARD_MOON,
	[enums.Cards.Sun] = Card.CARD_SUN,
	[enums.Cards.Aeon] = Card.CARD_JUDGEMENT,
	[enums.Cards.Universe] = Card.CARD_WORLD,
	
	[enums.Cards.Fool_r] = Card.CARD_REVERSE_FOOL,
	[enums.Cards.Sage_r] = Card.CARD_REVERSE_MAGICIAN,
	[enums.Cards.Priestess_r] = Card.CARD_REVERSE_HIGH_PRIESTESS,
	[enums.Cards.Empress_r] = Card.CARD_REVERSE_EMPRESS,
	[enums.Cards.Emperor_r] = Card.CARD_REVERSE_EMPEROR,
	[enums.Cards.Hierophant_r] = Card.CARD_REVERSE_HIEROPHANT,
	[enums.Cards.Lover_r] = Card.CARD_REVERSE_LOVERS,
	[enums.Cards.Chariot_r] = Card.CARD_REVERSE_CHARIOT,
	[enums.Cards.Adjustment_r] = Card.CARD_REVERSE_JUSTICE,
	[enums.Cards.Hermit_r] = Card.CARD_REVERSE_HERMIT,
	[enums.Cards.Wheel_of_Destiny_r] = Card.CARD_REVERSE_WHEEL_OF_FORTUNE,
	[enums.Cards.Lure_r] = Card.CARD_REVERSE_STRENGTH,
	[enums.Cards.Hanged_Man_r] = Card.CARD_REVERSE_HANGED_MAN,
	[enums.Cards.Faint_r] = Card.CARD_REVERSE_DEATH,
	[enums.Cards.Death_r] = Card.CARD_REVERSE_DEATH,
	[enums.Cards.Corpse_r] = Card.CARD_REVERSE_DEATH,
	[enums.Cards.Art_r] = Card.CARD_REVERSE_TEMPERANCE,
	[enums.Cards.Devil_r] = Card.CARD_REVERSE_DEVIL,
	[enums.Cards.Tower_r] = Card.CARD_REVERSE_TOWER,
	[enums.Cards.Star_r] = Card.CARD_REVERSE_STARS,
	[enums.Cards.Moon_r] = Card.CARD_REVERSE_MOON,
	[enums.Cards.Sun_r] = Card.CARD_REVERSE_SUN,
	[enums.Cards.Aeon_r] = Card.CARD_REVERSE_JUDGEMENT,
	[enums.Cards.Universe_r] = Card.CARD_REVERSE_WORLD,
	
	[enums.Cards.Eclipse] = Card.CARD_SUN,
	[enums.Cards.Eclipse_r] = Card.CARD_REVERSE_SUN,
	[enums.Cards.Profound] = Card.CARD_WORLD,
	[enums.Cards.Profound_r] = Card.CARD_REVERSE_WORLD,
	[enums.Cards.Sting] = Card.CARD_HIEROPHANT,
	[enums.Cards.Sting_r] = Card.CARD_REVERSE_HIEROPHANT,
}

function funct.get_maped_card(card,rng)
	if type(card) == "userdata" and card.SubType then card = card.SubType end
	if maped_card_map[card] then
		return funct.check_if_any(maped_card_map[card],rng)
	end
end

function funct.is_maped_card(card)
	if type(card) == "userdata" and card.SubType then card = card.SubType end
	if maped_card_map[card] then return true end
	return false
end

function funct.is_thoth_card(card)
	if type(card) == "userdata" and card.SubType then card = card.SubType end
	if reversed_card_map[card] then return true end
	return false
end

function funct.is_tarot_card(card)
	if type(card) == "userdata" and card.SubType then card = card.SubType end
	if reversed_card_map[card] == nil and maped_card_map[card] then return true end
	return false
end

local reverse_card_map = {
	[enums.Cards.Fool_r] = enums.Cards.Fool,
	[enums.Cards.Sage_r] = function(rg) 
		local rng if rg then rng = RNG() rng:SetSeed(rg:GetSeed(),0) end
		return funct.random_in_table({enums.Cards.Witch,enums.Cards.Invoker,enums.Cards.Wizard},rng)
	end,
	[enums.Cards.Priestess_r] = enums.Cards.Priestess,
	[enums.Cards.Empress_r] = enums.Cards.Empress,
	[enums.Cards.Emperor_r] = enums.Cards.Emperor,
	[enums.Cards.Hierophant_r] = enums.Cards.Hierophant,
	[enums.Cards.Lover_r] = enums.Cards.Lover,
	[enums.Cards.Chariot_r] = enums.Cards.Chariot,
	[enums.Cards.Adjustment_r] = enums.Cards.Adjustment,
	[enums.Cards.Hermit_r] = enums.Cards.Hermit,
	[enums.Cards.Wheel_of_Destiny_r] = enums.Cards.Wheel_of_Destiny,
	[enums.Cards.Lure_r] = enums.Cards.Lure,
	[enums.Cards.Hanged_Man_r] = enums.Cards.Hanged_Man,
	[enums.Cards.Faint_r] = enums.Cards.Faint,
	[enums.Cards.Death_r] = enums.Cards.Faint,
	[enums.Cards.Corpse_r] = enums.Cards.Faint,
	[enums.Cards.Art_r] = enums.Cards.Art,
	[enums.Cards.Devil_r] = enums.Cards.Devil,
	[enums.Cards.Tower_r] = enums.Cards.Tower,
	[enums.Cards.Star_r] = enums.Cards.Star,
	[enums.Cards.Moon_r] = enums.Cards.Moon,
	[enums.Cards.Sun_r] = enums.Cards.Sun,
	[enums.Cards.Aeon_r] = enums.Cards.Aeon,
	[enums.Cards.Universe_r] = enums.Cards.Universe,
	
	[enums.Cards.Eclipse_r] = enums.Cards.Eclipse,
	[enums.Cards.Profound_r] = enums.Cards.Profound,
	[enums.Cards.Sting_r] = enums.Cards.Sting,
}

function funct.is_reversed_card(card)
	if type(card) == "userdata" and card.SubType then card = card.SubType end
	if card > 55 and card < 78 then return true end
	if reverse_card_map[card] then return true end
	return false
end

function funct.get_tarot_cards()
	local ret = {}
	for i = 1,22 do table.insert(ret,#ret + 1,i) end
	for i = 56,77 do table.insert(ret,#ret + 1,i) end
	for i = enums.Cards.Fool,enums.Cards.Universe_r do table.insert(ret,#ret + 1,i) end
	return ret
end

function funct.check_bottom_down(bt,ctrlid)
	return Input.IsButtonTriggered(bt,ctrlid) or Input.IsButtonPressed(bt,ctrlid)
end

function funct.get_repel_params(ent)
	return 1/math.max(0.9,math.log(ent.Mass)/math.log(5) * 0.5 + 0.5)
end

function funct.get_string_real_length(str)
	local i = 1
	local ret = 0
	while(i <= #str) do
		local c = string.sub(str,i,i)
		local b = string.byte(c)
		if b > 128 then	i = i + 3 else i = i + 1 end	--中文字符占有3格
		ret = ret + 1
	end
	return ret
end

function funct.string_sub(str,val)		--没有做从XX开始到XX结束，而是只有从0开始到XX
	local i = 1
	if val <= 0 then return "" end
	while(i <= #str) do
		local c = string.sub(str,i,i)
		local b = string.byte(c)
		if b > 128 then	i = i + 3 else i = i + 1 end
		if i > val then return string.sub(str,1,i) end
	end
	return str
end

local languagemap = {
	["en"] = "English",
	["jp"] = "Japanese",
	["kr"] = "Korean",
	["zh"] = "Chinese",
	["ru"] = "Russian",
	["de"] = "German",
	["es"] = "Spanish",
}

function funct.get_language_map(str)
	return languagemap[str]
end

function funct.check_name_data(name,ret)
	local language = funct.get_language_map(Options.Language)
	if language and displaying_data[language] then
		return displaying_data[language][name] or ret or name
	else
		return ret or name
	end
end

function funct.spilt_string(str)
	local tbl = {}
	local i = 1
	while(i <= #str) do
		local c = string.sub(str,i,i)
		local b = string.byte(c)
		if b > 128 then
			c = string.sub(str,i,i+2)
			i = i + 3
		else
			i = i + 1
		end
		table.insert(tbl,c)
	end
	return tbl
end

function funct.get_string_display_length(str)
	local ret = 0
	local i = 1
	while(i <= #str) do
		local c = string.sub(str,i,i)
		local b = string.byte(c)
		if b > 128 then
			c = string.sub(str,i,i+2)
			i = i + 3
			ret = ret + 4.5
		else
			i = i + 1
			ret = ret + 1.8
		end
	end
	return ret
end

function funct.random_shuffle_string(str,rng)
	rng = funct.rng_for_sake(rng)
	local ret = funct.randomTable(funct.spilt_string(str),rng)
	return ret
end

function funct.get_mul_string(wd,mul)
	local ret = ""
	mul = mul or 10
	for i = 1,mul do
		ret = ret .. wd
	end
	return ret
end

function funct.collect_table_to_string(tbl,p1,p2,step)
	if tbl == nil then tbl = {} end
	step = step or 1
	if p2 == nil then p2 = #tbl end
	if p1 == nil then p1 = 1 end
	if step == 0 then step = 1 end
	if step < 0 then step = -step end
	if p1 > p2 then 
		local tmp = p1
		p1 = p2
		p2 = tmp
	end
	local ret = ""
	for i = p1,p2,step do
		if type(tbl[i]) == "string" then
			ret = ret..tbl[i]
		end
	end
	return ret
end

function funct.cut_string_by_mark(str)
	local i = 1
	local ipos = 0
	local ret = {}
	local cutid = {}
	while i < #str do
		i = string.find(str,"|",i)
		if i == nil then break end
		table.insert(ret,string.sub(str,ipos + 1,i - 1))
		table.insert(cutid,i)
		ipos = i
		i = i + 1
	end
	if ipos ~= #str then table.insert(ret,string.sub(str,ipos + 1,#str)) end
	return ret,cutid
end

function funct.reverse_table(tbl)
	if type(tbl) ~= "table" then return tbl end
	local ret = {}
	for i = 1,#tbl do
		table.insert(ret,tbl[#tbl + 1 - i])
	end
	return ret
end

function funct.reverse_string(str)
	return funct.collect_table_to_string(funct.reverse_table(funct.spilt_string(str)))
end

function funct.cut_string_by_id(str,cutid)
	local ipos = 0
	local ret = {}
	for i = 1,#cutid do
		table.insert(ret,string.sub(str,ipos + 1,cutid[i] - i))
		ipos = cutid[i] - i
	end
	if ipos + 1 ~= #str then table.insert(ret,string.sub(str,ipos + 1,#str)) end
	return ret
end

function funct.random_work_on_the_raw_string(data,rng)
	rng = funct.rng_for_sake(rng)
	local res,cid = funct.cut_string_by_mark(data)
	return funct.cut_string_by_id(funct.collect_table_to_string(funct.random_shuffle_string(funct.collect_table_to_string(res),rng)),cid)
end

function funct.KColor_2_Color(kcol)
	return Color(kcol.R,kcol.G,kcol.B,kcol.A,kcol.RO,kcol.GO,kcol.BO)
end

function funct.Color_2_KColor(col)
	return KColor(col.R,col.G,col.B,col.A,col.RO,col.GO,col.BO)
end

function funct.get_word_render_offset(word)
	local b = string.byte(word)
	if b > 128 then
		return Vector(-4,-8)
	else
		return Vector(-2,-8)
	end
end

function funct.get_word_damage(word)
	local b = string.byte(word)
	if b > 128 then
		return 2.5
	else
		return 1.5
	end
end

function funct.get_level_stat_of_spwq()
	local ls = Game():GetLevel():GetStage()
	return 2 / math.sqrt(ls + 3) 
end

function funct.PrintColor(col)
	local rc,gc,bc,ac = read_colorize(col)
	print(col.R.." "..col.G.." "..col.B.." "..col.A.." "..col.RO.." "..col.GO.." "..col.BO
		.." CZ("..rc.." "..gc.." "..bc.." "..ac..")")
end

function funct.PrintKColor(col)
	print(col.Red.." "..col.Green.." "..col.Blue.." "..col.Alpha.." ")
end

function funct.GetChampPosition(pos,margin)
	return Vector(math.floor(pos.X/margin + 0.5) * margin,math.floor(pos.Y/margin + 0.5) * margin)
end

function funct.my_morph(ent,tp,var,st,keepprice,keepseed,ignoremodifier)
	ent:ToPickup():Morph(tp,var,st,keepprice,keepseed,ignoremodifier)
end

function funct.self_morph(ent,params)
	ent = ent:ToPickup() if not ent then return end
	params = params or {}
	if params.no_morph then else ent:Morph(params.tp or params[1] or ent.Type,params.vr or params[2] or ent.Variant,params.st or params[3] or ent.SubType,true,true,true) end
	if params.no_dul then else ent:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE) end
	if params.no_cain then else local TC_H = require("Qing_Remaster_scripts.mimics.Tainted_Cain_holder") TC_H.add_touchable(ent) end
end

function funct.special_morph(ent,item,keepprice,keepseed,ignoremodifier)
	--print("morph")
	if keepprice == nil then keepprice = true end
	if keepseed == nil then keepseed = true end
	if ignoremodifier == nil then ignoremodifier = true end
	ent:ToPickup():Morph(5,item.Variant,item.SubType,true,true,true)
	if item.special_to_turn then 
		local should_hold,holdname = item.special_to_turn(ent,true)
		if should_hold then
			if consistance_holder == nil then consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder") end		--权宜之计
			consistance_holder.try_hold_entity(ent,holdname,{keep_level = true,})
		end
		if item.load_EID and EID then
			item.load_EID(ent)
		end
	end
	--print("end morph")
end

function funct.special_turn(ent,item,inout)
	if item.special_to_turn then 
		local should_hold,holdname = item.special_to_turn(ent,inout)
		if should_hold then
			if consistance_holder == nil then consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder") end		--权宜之计
			consistance_holder.try_hold_entity(ent,holdname,{keep_level = true,})
		end
		if item.load_EID and EID then
			item.load_EID(ent)
		end
	end
end

function funct.setCanShoot(player, canshoot)
	player = player or Game():GetPlayer(0)
    local oldchallenge = Game().Challenge
    Game().Challenge = canshoot and 0 or 6
    player:UpdateCanShoot()
    Game().Challenge = oldchallenge
	player:GetData().should_not_attack = not canshoot
end

function funct.checkrounded2(v1,v2,t1,t2,r)
	local ret = (v1 * t1 + v2 * t2) % r
	if math.abs(ret + r) < math.abs(ret) then ret = ret + r end
	if math.abs(ret - r) < math.abs(ret) then ret = ret - r end
	return ret
end

function funct.checkrounded(v1,v2,t1,t2,r)
	if math.abs(v1 + r - v2) < math.abs(v1 - v2) then v1 = v1 + r end
	if math.abs(v1 - r - v2) < math.abs(v1 - v2) then v1 = v1 - r end
	return v1 * t1 + v2 * t2
end

function funct.round_aver(v1,v2)
	return auxi.checkrounded(v1,v2,0.5,0.5,360)
end

function funct.move_in_round(v1,v2,delta,r)		--在环(周长为r)上从v1逼近v2，至多前进delta，给出移动后结果
	local diff = auxi.checkrounded2(v1,v2,1,-1,r)
	if math.abs(diff) < delta then return v2
	else 
		local r1 = v1 + delta
		local r2 = v1 - delta
		if math.abs(auxi.checkrounded2(r1,v2,1,-1,r)) < math.abs(auxi.checkrounded2(r2,v2,1,-1,r)) then return r1
		else return r2 end
	end
end

function funct.check_for_the_same(v1,v2)
	local ret = false
	if v1 and v2 then
		if type(v1) == "userdata" and type(v2) == "userdata" and GetPtrHash(v1) == GetPtrHash(v2) then return true end
		if v1.GetData and v2.GetData then
			local d1 = v1:GetData()
			local d2 = v2:GetData()
			d1.check_for_the_same = true
			if d2.check_for_the_same then ret = true end
			d1.check_for_the_same = nil
		end
	end
	return ret
end

function funct.reveal_item(player,pos,colid,params)
	params = params or {}
	player = player or Game():GetPlayer(0)
	pos = pos or player.Position
	colid = colid or 33
	local config = Isaac.GetItemConfig()
	local coll = config:GetCollectible(colid)
	local save = funct.get_save()
	if colid == enums.Items.It_s_a_trick then coll = config:GetCollectible(save.elses.glazed_trick or 32) or config:GetCollectible(32) end
	if coll then
		local q = funct.fire_nil(pos,Vector(0,0),{cooldown = 90,})
		--q:AddEntityFlags(EntityFlag.FLAG_INTERPOLATION_UPDATE)
		local s = q:GetSprite()
		s.Offset = params.offset or Vector(0,0)
		local d = q:GetData()
		d.is_revealer = true
		s:Load("gfx/cards/Revealer.anm2",true)
		if params.replace_renderer then
			s:ReplaceSpritesheet(1,"gfx/effects/nill.png")
			d.linked_sprite = params.replace_renderer
			d.replace_scale = params.scale or Vector(1,1)
			d.replace_offset = params.linkedoffset or Vector(0,0)
		else
			if Game():GetLevel():GetCurses() & LevelCurse.CURSE_OF_BLIND == LevelCurse.CURSE_OF_BLIND and not ignore_question_mark then
				s:ReplaceSpritesheet(1,"gfx/items/collectibles/questionmark.png")
			else
				s:ReplaceSpritesheet(1,coll.GfxFileName)
			end
		end
		s:LoadGraphics()
		s:Play("Appear",true)
		--if math.random(1000) > 500 then s.FlipX = true end
	end
end

function funct.reveal_item2(player,pos,colid,params)
	params = params or {}
	player = player or Game():GetPlayer(0)
	pos = pos or player.Position
	colid = colid or 33
	local config = Isaac.GetItemConfig()
	local coll = config:GetCollectible(colid)
	local save = funct.get_save()
	if colid == enums.Items.It_s_a_trick then coll = config:GetCollectible(save.elses.glazed_trick or 32) or config:GetCollectible(32) end
	if coll then
		local q = funct.fire_nil(pos,Vector(0,0),{cooldown = 90,})
		--q:AddEntityFlags(EntityFlag.FLAG_INTERPOLATION_UPDATE)
		local s = q:GetSprite()
		s.Offset = params.offset or Vector(0,0)
		local d = q:GetData()
		d.is_revealee = true
		s:Load("gfx/cards/Revealee.anm2",true)
		if params.replace_renderer then
			s:ReplaceSpritesheet(1,"gfx/effects/nill.png")
			d.linked_sprite = params.replace_renderer
			d.replace_scale = params.scale or Vector(1,1)
			d.replace_offset = params.linkedoffset or Vector(0,0)
		else
			if Game():GetLevel():GetCurses() & LevelCurse.CURSE_OF_BLIND == LevelCurse.CURSE_OF_BLIND and not ignore_question_mark then
				s:ReplaceSpritesheet(1,"gfx/items/collectibles/questionmark.png")
			else
				s:ReplaceSpritesheet(1,coll.GfxFileName)
			end
		end
		s:LoadGraphics()
		s:Play("Appear",true)
		if params.revealee_end then d.revealee_end = params.revealee_end end
		
		return q
	end
end

function funct.load_item(colid,params)
	params = params or {}
	local s = params.sprite or Sprite()
	if params.Loaded then
	else s:Load(params.Anm or "gfx/dropping_collectible.anm2",true) s:Play(params.Anim or "Idle",true) end
	local coll = Isaac.GetItemConfig():GetCollectible(colid)
	local save = funct.get_save()
	if colid == enums.Items.It_s_a_trick then coll = Isaac.GetItemConfig():GetCollectible(save.elses.glazed_trick or 32) or Isaac.GetItemConfig():GetCollectible(32) end
	if params.ForceBlind or (Game():GetLevel():GetCurses() & LevelCurse.CURSE_OF_BLIND == LevelCurse.CURSE_OF_BLIND and params.Blind) then s:ReplaceSpritesheet(0,"gfx/items/collectibles/questionmark.png")
	else s:ReplaceSpritesheet(0,coll.GfxFileName) end
	s:LoadGraphics()
	return s
end

function funct.render_border(pos,info,params)
	params = params or {}
	local s = Sprite()
	s:Load("gfx/item_border.anm2",true)
	s:Play("Idle",true)
	s.Color = params.color or Color(1,1,1,1)
	for i = 0,4 do s:ReplaceSpritesheet(i,info.replacename) end
	s:LoadGraphics()
	s:Render(pos,Vector(0,0),Vector(0,0))
end

function funct.load_trinket(tid,params)
	params = params or {}
	local s = params.sprite or Sprite()
	s:Load("gfx/dropping_collectible.anm2",true)
	s:Play("Idle",true)
	local tinfo = Isaac.GetItemConfig():GetTrinket(tid)
	s:ReplaceSpritesheet(0,tinfo.GfxFileName)
	s:LoadGraphics()
	return s
end

function funct.spawn_item_dust(player,pos,colid,color1,color2,ignore_question_mark)
	ignore_question_mark = ignore_question_mark or false
	player = player or Game():GetPlayer(0)
	pos = pos or player.Position
	colid = colid or 33
	color1 = color1 or Color(1,1,1,1)
	color2 = color2 or Color(0.2,0.2,0.2,0.3,-0.8,-0.8,-0.8)
	local coll = Isaac.GetItemConfig():GetCollectible(colid)
	local save = funct.get_save()
	if colid == enums.Items.It_s_a_trick then coll = Isaac.GetItemConfig():GetCollectible(save.elses.glazed_trick or 32) or Isaac.GetItemConfig():GetCollectible(32) end
	if coll then
		local q = Isaac.Spawn(1000,EffectVariant.CRACK_THE_SKY,0,pos,Vector(0,0),player):ToEffect()
		q.Parent = player
		q.CollisionDamage = 0
		local q2 = Isaac.Spawn(1000,11,0,pos,Vector(0,0),player)
		local s = q:GetSprite()
		s.Color = color1
		local s2 = q2:GetSprite()
		s2:Load("gfx/dropping_collectible.anm2",true)
		s2:Play("Idle",true)
		if Game():GetLevel():GetCurses() & LevelCurse.CURSE_OF_BLIND == LevelCurse.CURSE_OF_BLIND and not ignore_question_mark then
			s2:ReplaceSpritesheet(0,"gfx/items/collectibles/questionmark.png")
		else
			s2:ReplaceSpritesheet(0,coll.GfxFileName)
		end
		s2:LoadGraphics()
		q2:AddEntityFlags(EntityFlag.FLAG_RENDER_FLOOR)
		s2.Color = color2
		return q
	end
end

function funct.get_random_item_that_player_has(player,rng,params)
	params = params or {}
	if rng then rng = funct.rng_for_sake(rng) end
	local pool = {}
	local itemConfig = Isaac.GetItemConfig()
	local sz = itemConfig:GetCollectibles().Size
	local playerpool = {}
	if player then
		table.insert(playerpool,#playerpool + 1,player)
	else
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			table.insert(playerpool,#playerpool + 1,player)
		end
	end
	for u,player in pairs(playerpool) do
		local ignore_pool = params.ignore_pool or {}
		if params.ignore_active_item then for slot = 0,3 do local col = player:GetActiveItem(slot) if col then ignore_pool[col] = (ignore_pool[col] or 0) + 1 end end end
		if params.ignore_pocket_item then for slot = 2,3 do local col = player:GetActiveItem(slot) if col then ignore_pool[col] = (ignore_pool[col] or 0) + 1 end end end
		for id = 1,sz do
			local collectible = itemConfig:GetCollectible(id)
			if (collectible and player:HasCollectible(id)) and (params.dont_ignore_quest or collectible.Tags & ItemConfig.TAG_QUEST ~= ItemConfig.TAG_QUEST) then
				if player:GetCollectibleNum(id,true) - (ignore_pool[id] or 0) > 0 then
					local rin = {id = id,weigh = player:GetCollectibleNum(id,true) - (ignore_pool[id] or 0)}
					if params.by_weight then rin.weigh = params.by_weight(rin.weigh,id) or rin.weigh end
					table.insert(pool,rin)
				end
			end
		end
	end
	local target = nil
	if #pool > 0 then target = funct.random_in_weighed_table(pool,rng).id end
	if params.return_table then return target,pool
	else return target end
end

function funct.get_player_s_max_item(player,params)
	params = params or {}
	local pool = {}
	local playerpool = {}
	if player then
		table.insert(playerpool,#playerpool + 1,player)
	else
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			table.insert(playerpool,#playerpool + 1,player)
		end
	end
	local mxid = 0
	local itemConfig = Isaac.GetItemConfig()
	local sz = itemConfig:GetCollectibles().Size
	for u,player in pairs(playerpool) do
		local ignore_pool = params.ignore_pool or {}
		if params.ignore_pocket_item then for slot = 2,3 do local col = player:GetActiveItem(slot) if col then ignore_pool[col] = (ignore_pool[col] or 0) + 1 end end end
		for id = 1,sz do
			local collectible = itemConfig:GetCollectible(id)
			if (collectible and player:HasCollectible(id)) and (params.dont_ignore_quest or collectible.Tags & ItemConfig.TAG_QUEST ~= ItemConfig.TAG_QUEST) then
				if player:GetCollectibleNum(id,true) - (ignore_pool[id] or 0) > 0 then
					pool[id] = (pool[id] or 0) + player:GetCollectibleNum(id,true) - (ignore_pool[id] or 0)
					if pool[id] > (pool[mxid] or 0) then mxid = id end
				end
			end
		end
	end
	return pool[mxid] or 1
end

function funct.get_player_s_item_count(player,params)
	params = params or {}
	local ret = 0
	local playerpool = {}
	if player then
		table.insert(playerpool,#playerpool + 1,player)
	else
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			table.insert(playerpool,#playerpool + 1,player)
		end
	end
	local itemConfig = Isaac.GetItemConfig()
	local ignore_quest = not params.dont_ignore_quest
	for u,cur in pairs(playerpool) do
		local ignore_pool = params.ignore_pool or {}
		if params.ignore_pocket_item then for slot = 2,3 do local col = cur:GetActiveItem(slot) if col then ignore_pool[col] = (ignore_pool[col] or 0) + 1 end end end
		local function consider(id)
			if type(id) ~= "number" or id <= 0 then return end
			local collectible = itemConfig:GetCollectible(id)
			if not collectible then return end
			if ignore_quest and collectible.Tags & ItemConfig.TAG_QUEST == ItemConfig.TAG_QUEST then return end
			local num = cur:GetCollectibleNum(id) - (ignore_pool[id] or 0)
			if num > 0 then
				ret = ret + num - 1
			end
		end
		local listed = (REPENTOGON and cur.GetCollectiblesList) and cur:GetCollectiblesList() or nil
		if type(listed) == "table" then
			for id, n in pairs(listed) do
				if (n or 0) > 0 then consider(id) end
			end
		else
			local sz = itemConfig:GetCollectibles().Size
			for id = 1,sz do
				if cur:HasCollectible(id) then consider(id) end
			end
		end
	end
	return ret
end

function funct.choose(...)
	local options = {...}
	return options[math.random(#options)]
end

function funct.choose2(options)
	return options[math.random(#options)]
end

function funct.choose3(options, cnt)
    -- 如果未指定 cnt 或 cnt 无效，默认返回1个随机元素（保持原行为）
    cnt = cnt or 1
    if cnt <= 0 then cnt = 1 end

    -- 复制选项表以避免修改原始数据
    local shuffled = {}
    for i, v in ipairs(options) do
        shuffled[i] = v
    end

    -- Fisher-Yates 洗牌算法
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    -- 返回前 cnt 个元素
    local result = {}
    for i = 1, cnt do
		if i > #options then table.insert(result, choose2(shuffled))
		else table.insert(result, shuffled[i]) end
    end

    return result
end

function funct.random_in_table(tbl,rng)
	if type(tbl) ~= "table" then return tbl end
	if #tbl == 0 then return nil end
	if rng then
		local rnd = rng:RandomInt(#tbl) + 1
		return tbl[rnd]
	else
		local rnd = math.random(#tbl)
		return tbl[rnd]
	end
end

function funct.random_in_weighed_table(tbl,rng,wei)
	if type(tbl) ~= "table" then return tbl end
	local total_weigh = 0
	wei = wei or 1
	for u,v in pairs(tbl) do
		if type(v) == "table" then total_weigh = total_weigh + (funct.check_if_any(v.weigh,v) or wei)
		else total_weigh = total_weigh + wei end
	end
	total_weigh = math.floor(total_weigh)
	if rng then total_weigh = rng:RandomInt(total_weigh) + 1
	else total_weigh = math.random(total_weigh) end
	for u,v in pairs(tbl) do
		local dec = wei
		if type(v) == "table" then dec = funct.check_if_any(v.weigh,v) or dec end
		total_weigh = total_weigh - dec
		if total_weigh <= 0 then return v,u end
	end
	return nil
end

function funct.random_on_table(st,ed,rng)
	if ed <= st then return ed end
	local ret = st
	if rng then
		ret = rng:RandomInt(ed - st) + 1 + st
	else
		ret = math.random(ed - st) + st
	end
	return ret
end

local pill_effect_list = {
	[PillEffect.PILLEFFECT_BAD_GAS] = 0,
	[PillEffect.PILLEFFECT_BAD_TRIP] = -1,
	[PillEffect.PILLEFFECT_BALLS_OF_STEEL] = 1,
	[PillEffect.PILLEFFECT_BOMBS_ARE_KEYS] = 0,
	[PillEffect.PILLEFFECT_EXPLOSIVE_DIARRHEA] = 0,
	[PillEffect.PILLEFFECT_FULL_HEALTH] = 1,
	[PillEffect.PILLEFFECT_HEALTH_DOWN] = -1,
	[PillEffect.PILLEFFECT_HEALTH_UP] = 1,
	[PillEffect.PILLEFFECT_I_FOUND_PILLS] = 0,
	[PillEffect.PILLEFFECT_PUBERTY] = 0,
	[PillEffect.PILLEFFECT_PRETTY_FLY] = 2,
	[PillEffect.PILLEFFECT_RANGE_DOWN] = -1,
	[PillEffect.PILLEFFECT_RANGE_UP] = 3,
	[PillEffect.PILLEFFECT_SPEED_DOWN] = -1,
	[PillEffect.PILLEFFECT_SPEED_UP] = 3,
	[PillEffect.PILLEFFECT_TEARS_DOWN] = -1,
	[PillEffect.PILLEFFECT_TEARS_UP] = 3,
	[PillEffect.PILLEFFECT_LUCK_DOWN] = -1,
	[PillEffect.PILLEFFECT_LUCK_UP] = 3,
	[PillEffect.PILLEFFECT_TELEPILLS] = 0,
	[PillEffect.PILLEFFECT_48HOUR_ENERGY] = 4,
	[PillEffect.PILLEFFECT_HEMATEMESIS] = 1,
	[PillEffect.PILLEFFECT_PARALYSIS] = -1,
	[PillEffect.PILLEFFECT_SEE_FOREVER] = 2,
	[PillEffect.PILLEFFECT_PHEROMONES] = 5,
	[PillEffect.PILLEFFECT_AMNESIA] = -1,
	[PillEffect.PILLEFFECT_LEMON_PARTY] = 5,
	[PillEffect.PILLEFFECT_WIZARD] = -1,
	[PillEffect.PILLEFFECT_PERCS] = 2,
	[PillEffect.PILLEFFECT_ADDICTED] = -1,
	[PillEffect.PILLEFFECT_RELAX] = 0,
	[PillEffect.PILLEFFECT_QUESTIONMARK] = 0,
	[PillEffect.PILLEFFECT_LARGER] = 0,
	[PillEffect.PILLEFFECT_SMALLER] = 0,
	[PillEffect.PILLEFFECT_INFESTED_EXCLAMATION] = 5,
	[PillEffect.PILLEFFECT_INFESTED_QUESTION] = 5,
	[PillEffect.PILLEFFECT_POWER] = 5,
	[PillEffect.PILLEFFECT_RETRO_VISION] = -1,
	[PillEffect.PILLEFFECT_FRIENDS_TILL_THE_END] = 5,
	[PillEffect.PILLEFFECT_X_LAX] = 0,
	[PillEffect.PILLEFFECT_SOMETHINGS_WRONG] = 0,
	[PillEffect.PILLEFFECT_IM_DROWSY] = 0,
	[PillEffect.PILLEFFECT_IM_EXCITED] = 0,
	[PillEffect.PILLEFFECT_GULP] = 2,
	[PillEffect.PILLEFFECT_HORF] = 5,
	[PillEffect.PILLEFFECT_SUNSHINE] = 5,
	[PillEffect.PILLEFFECT_VURP] = 2,
	[PillEffect.PILLEFFECT_SHOT_SPEED_DOWN] = 0,
	[PillEffect.PILLEFFECT_SHOT_SPEED_UP] = 0,
	[PillEffect.PILLEFFECT_EXPERIMENTAL] = 0,
}

function funct.is_bad_pill(pill)
	--local config = Isaac.GetItemConfig()
	--local pillinfo = config:GetPillEffect(pill)		--这玩意是坏的
	return (pill_effect_list[pill or 0] or 0) < 0
end
--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") auxi.is_bad_pill(1)
function funct.get_stats_counter(player)
	local ret = 0
	ret = ret + player.Damage * 30 / (player.MaxFireDelay + 1) + player.TearRange / 40 + math.max(0,player.ShotSpeed - 2) * 20 + player.Luck * 3.5 + player:GetCollectibleCount() * 5
	return ret
end

local follow_spawner = {[80] = true,[235] = true,[240] = true,}
function funct.check_near_spawner_player(ent,params)
	params = params or {}
	local checklist = params.checklist or {"SpawnerEntity","Parent",}
	for u,v in pairs(checklist) do
		if ent[v] then
			if ent[v]:ToPlayer() then return ent[v]:ToPlayer() end
			if ent[v]:ToFamiliar() and ent[v]:ToFamiliar().Player and follow_spawner[ent[v].Variant] then return ent[v]:ToFamiliar().Player end
		end
	end
end

function funct.check_spawner_player(ent)
	local ret = nil
	if ent then	
		local d = ent:GetData()
		if auxi.check_all_exists(d.check_spawner_player_record) then return d.check_spawner_player_record end
		if d.check_spawner_visited then return nil end
		for i = 1,1 do
			d.check_spawner_visited = true
			if ent.Type == 3 and ent:ToFamiliar() and ent:ToFamiliar().Player then ret = ent:ToFamiliar().Player break end
			if ent.Type == 1 and ent:ToPlayer() then ret = ent:ToPlayer() break end
			if ent.SpawnerEntity then ret = ret or funct.check_spawner_player(ent.SpawnerEntity) end if ret then break end
			if ent.Parent then ret = ret or funct.check_spawner_player(ent.Parent) end 
		end
		d.check_spawner_visited = nil
		d.check_spawner_player_record = ret
	end
	return ret
end

local check_info_found_soul = {
	["lim_heart"] = -1,
	["sl_heart"] = -1,
}

function funct.is_found_soul(ent)
	if ent == nil or ent:ToPlayer() == nil then return false end
	ent = ent:ToPlayer()
	local ret = true
	local s = ent:GetSprite()
	if s:GetFilename() ~= "gfx/001.001_Player2.anm2" then return false end		--不知道为什么是大写的
	local info = funct.get_heart_info(ent)
	for u,v in pairs(info) do
		if (check_info_found_soul[u] or 0) ~= -1 and (check_info_found_soul[u] or 0) ~= v then		--似乎还是会误认某些2P宝
			return false
		end
	end
	if info.sl_heart >= 2 then return false end
	return ret
end

function funct.should_spawn_wisp(player,flags)
	 return player:HasCollectible(CollectibleType.COLLECTIBLE_BOOK_OF_VIRTUES) and (flags == nil or (flags & UseFlag.USE_NOANIM <= 0 or flags & UseFlag.USE_ALLOWWISPSPAWN > 0))
end

function funct.should_do_belial(player)
	player = player or Game():GetPlayer(0)
	return auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_BOOK_OF_BELIAL_PASSIVE)
end

function funct.should_do_Seija(player,id)
	if Reverie then
		local Seija = Reverie.Players.Seija		--Reverie.Require("scripts/players/seija")
		if id == true then return Seija:WillPlayerBuff(player)
		else return Seija:WillPlayerNerf(player) end
	end
	return false
end

function funct.should_do_Seija_all(id)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.should_do_Seija(player,id) then return true end
	end
	return false
end

function funct.add_to_seija(id)
	if Reverie then
		local Seija = Reverie.Players.Seija		--Reverie.Require("scripts/players/seija")
		Seija:AddExceptedModItem(id)
	end
end

function funct.get_wisps(t_player,subtype)
	if player == nil then
		local n_entity = Isaac.GetRoomEntities()
		local n_wisps = funct.getothers(n_entity,3,FamiliarVariant.WISP,subtype)
		return n_wisps
	else
		local n_entity = Isaac.GetRoomEntities()
		local n_wisps = funct.getothers(n_entity,3,FamiliarVariant.WISP,subtype,function(ent)
			if ent:ToFamiliar() then
				local player = ent:ToFamiliar().player
				if player and ent:ToFamiliar().player and funct.check_for_the_same(player,t_player) then
					return true
				end
			end
			return false
			end)
		return n_wisps
	end
end

function funct.get_acceptible_level()
	local stage = Game():GetLevel():GetStage()
	if (Game():GetLevel():GetCurses() & LevelCurse.CURSE_OF_LABYRINTH == LevelCurse.CURSE_OF_LABYRINTH) then
		stage = stage + 1
	end
	return stage
end

local sprite_set_list = {
	--["Scale"] = "S",
	["FlipX"] = {name = "FX",default = false,},
	["FlipY"] = {name = "FY",default = false,},
	--["Offset"] = true,
	["PlaybackSpeed"] = {name = "PS",default = 1,},
	["Rotation"] = {name = "R",default = 0,},
}

function funct.sprite2table(s)
	local ret = {}
	for u,v in pairs(sprite_set_list) do if s[u] ~= v.default then ret[v.name] = s[u] end end
	ret.f = s:GetFilename()
	ret.Am = s:GetAnimation() if ret.Am == "Idle" then ret.Am = nil end
	ret.OAm = s:GetOverlayAnimation() if ret.OAm == "" then ret.OAm = nil end
	ret.F = s:GetFrame() if ret.F == 0 then ret.F = nil end
	ret.OF = s:GetOverlayFrame() if ret.OF == -1 or ret.OF == 0 then ret.OF = nil end
	if not auxi.EqualColor(s.Color,Color(1,1,1,1)) then ret.C = auxi.color2table(s.Color) end
	if not auxi.EqualVector(s.Offset,Vector(0,0)) then ret.O = auxi.Vector2Table(s.Offset) end
	if not auxi.EqualVector(s.Scale,Vector(1,1)) then ret.S = auxi.Vector2Table(s.Scale) end
	return ret
end

function funct.table2sprite(params,s)
	s = s or Sprite()
	s:Load(params.f,true)
	s:SetFrame(params.Am or "Idle",params.F or 0)
	s:Play(params.Am or "Idle")
	if (params.OAm or "") ~= "" then s:SetOverlayFrame(params.OAm,params.OF or 0) s:PlayOverlay(params.OAm) end
	s.Color = auxi.table2color(params.C or {R = 1,G = 1,B = 1,A = 1,RO = 0,GO = 0,BO = 0,})
	s.Offset = auxi.ProtectVector(params.O or Vector(0,0))
	s.Scale = auxi.ProtectVector(params.S or Vector(1,1))
	for u,v in pairs(sprite_set_list) do s[u] = params[v.name] or v.default end
	return s
end
--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") local q = Isaac.Spawn(5,100,0,Vector(200,200),Vector(0,0),nil) local s = q:GetSprite() auxi.table2sprite(auxi.sprite2table(s),s)

local sprite_copy_list = {
	["Scale"] = "S",
	["FlipX"] = {name = "FX",default = false,},
	["FlipY"] = {name = "FY",default = false,},
	["Offset"] = true,
	["PlaybackSpeed"] = {name = "PS",default = 1,},
	["Rotation"] = {name = "R",default = 0,},
}

function funct.copy_sprite(s,s2,params)
	params = params or {}
	s2 = s2 or Sprite()
	if (params.filename or s2:GetFilename()) ~= s:GetFilename() then s2:Load(params.filename or s:GetFilename(),true) end
	if params.SetFrame ~= true then s2:SetFrame(params.Anim or s:GetAnimation(),params.Frame or s:GetFrame()) end
	if params.Play then s2:Play(params.Anim or s:GetAnimation(),true) end
	if params.SetOverLayFrame ~= true and (params.OverAnim or s:GetOverlayAnimation()) ~= "" then s2:SetOverlayFrame(params.OverAnim or s:GetOverlayAnimation(),params.OverFrame or s:GetOverlayFrame()) end
	if params.PlayOverlay and (params.OverAnim or s:GetOverlayAnimation()) ~= "" then s2:PlayOverlay(params.OverAnim or s:GetOverlayAnimation(),true) end
	if params.SetColor ~= true then s2.Color = Color(s.Color.R,s.Color.G,s.Color.B,s.Color.A,s.Color.RO,s.Color.GO,s.Color.BO) end
	for u,v in pairs(sprite_copy_list) do if params["Set"..u] ~= true then s2[u] = s[u] end end
	return s2
end

function funct.get_near_grid_info(pos,dir)
	local ret = {}
	dir = dir or 120
	if dir < 0 then dir = - dir end
	if pos then
		local leg = math.ceil(dir/40)
		local room = Game():GetRoom()
		local orig_idx = room:GetGridIndex(pos)
		local orig_pos = room:GetGridPosition(orig_idx)
		local dx = 1
		local dy = room:GetGridIndex(orig_pos + Vector(0,40)) - orig_idx
		local lr = orig_idx - dx * leg - dy * leg
		for i = 1,leg * 2 do
			for j = 1,leg * 2 do
				local grididx = lr + dx * (i - 1) + dy * (j - 1)
				if grididx >= 0 and (room:GetGridPosition(grididx) - pos):Length() < dir then
					local grid = room:GetGridEntity(grididx)
					if grid then table.insert(ret,{grid = grid,idx = grididx,}) end
				end
			end
		end
	end
	return ret
end

function funct.check_slot_with_item(player,colid,dont_check_charge)
	player = player or Game():GetPlayer(0)
	local col = Isaac:GetItemConfig():GetCollectible(colid)
	if col == nil then return -1 end
	local charge = col.MaxCharges
	for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do 
		 if (player:GetActiveItem(slot) == colid) then
			if dont_check_charge or player:GetActiveCharge(slot) >= charge then
				return slot
			end
		end
	end
	return -1
end

function funct.check_can_use(player,slot,colid)
	player = player or Game():GetPlayer(0)
	local col = Isaac:GetItemConfig():GetCollectible(colid)
	if col == nil then return -1 end
	local charge = col.MaxCharges
	if player:GetActiveCharge(slot) >= charge then return true
	else return false end
end

function funct.check_player(ent)
	if ent:ToPlayer() then return ent:ToPlayer() end
	if ent:ToFamiliar() then
		ent = ent:ToFamiliar()
		if ent.Player then return ent.Player end
	end
end

function funct.GetDimension(roomDesc)
    roomDesc = roomDesc or Game():GetLevel():GetCurrentRoomDesc()
    if roomDesc.GridIndex < 0 then return 0 end
    local hash = GetPtrHash(roomDesc)
    for dimension = 0,2 do
        local dimensionDesc = Game():GetLevel():GetRoomByIdx(roomDesc.SafeGridIndex, dimension)
        if GetPtrHash(dimensionDesc) == hash then
            return dimension
        end
    end
end

function funct.get_linked(ent)
	if ent == nil or ent:ToNPC() == nil then return {} end
	ent = ent:ToNPC()
	local ret = {}
	local npos = ent
	while(npos.ParentNPC and npos.ParentNPC:GetData().is_checked_by_linked == nil) do
		npos = npos.ParentNPC
		npos:GetData().is_checked_by_linked = true
		table.insert(ret,npos)
	end
	npos = ent
	while(npos.ChildNPC and npos.ChildNPC:GetData().is_checked_by_linked == nil) do
		npos = npos.ChildNPC
		npos:GetData().is_checked_by_linked = true
		table.insert(ret,npos)
	end
	for u,v in pairs(ret) do
		v:GetData().is_checked_by_linked = nil
	end
	ent:GetData().is_checked_by_linked = nil
	return ret
end

function funct.get_delta_length(pos1,pos2,dir)
	local ddi = pos2 - pos1
	local sq = ddi.X * dir.Y - ddi.Y * dir.X
	return sq / dir:Length()
end

function funct.get_alpha_length(pos1,pos2,dir)
	local ddi = pos2 - pos1
	local sq = ddi.X * dir.X + ddi.Y * dir.Y
	return sq / dir:Length()
end

function funct.get_weapon(player)
	if REPENTOGON then for i = 0,4 do if player:GetWeapon(i) then return player:GetWeapon(i):GetWeaponType() end end end
	player = player or Game():GetPlayer(0)
	local ret = 1
	for i = 1,16 do if player:HasWeaponType(i) == true then	ret = i end end
	return ret
end

function funct.check_list_exists(ents)
	for u,v in pairs(ents) do if auxi.check_exists(v) then return true end end
end

function funct.check_exists(ent)
	return ent and type(ent) ~= "function" and ent.Exists and ent:Exists()
end

function funct.check_all_exists(ent)
	return (ent and type(ent) ~= "function" and ent.Exists and ent:Exists() and ent.IsDead and not ent:IsDead()) == true
end

function funct.check_on_all_exists(ent)
	if funct.check_all_exists(ent) then return ent else return nil end
end

function funct.check_if_any(val,...)
	if type(val) == "function" then return funct.check_if_any(val(...),...) end
	if type(val) == "table" and val["Function"] then return funct.check_if_any(val["Function"],val,...) end
	return val
end

function funct.check_if_once(val,...)		--只进入1层函数
	if type(val) == "function" then return val(...) end
	if type(val) == "table" and val["Function"] then return funct.check_if_once(val["Function"],val,...) end
	return val
end

function funct.check_delay_exists(ent)
	return ent and (type(ent) == "function" or type(ent) == "table" or (ent.Exists and ent:Exists()))
end

function funct.get_limit(val,lim)
	if val > lim then return lim elseif val < -lim then return -lim else return val end
end
function funct.get_id(val,lim)
	lim = lim or 0
	if val > lim then return 1 end
	if val < -lim then return -1 end
	return 0
end
function funct.get_flat_id(val)
	if val > 1 then return 1 end
	if val < 1 then return -1 end
	return val
end

function funct.get_correct_angle(val)
	val = val % 360
	if val > 180 then val = val - 360 end
	if val < -180 then val = val + 360 end
	return val
end

function funct.AddAngle(v1,v2,m1,m2)
	if math.abs(v1 - v2) > math.abs(v1 - v2 + 360) then v2 = v2 - 360 end
	if math.abs(v1 - v2) > math.abs(v1 - v2 - 360) then v2 = v2 + 360 end
	return v1 * (m1 or 1) + v2 * (m2 or 1)
end

function funct.get_correct_angle_id(val,lim)
	return funct.get_id(funct.get_correct_angle(val),lim)
end

function funct.can_sleep(player)
	if player:GetEffectiveMaxHearts() == 0 or player:GetHearts() < player:GetEffectiveMaxHearts() then return true end
	return false
end

function funct.has_card(player,card)
	player = player or Game():GetPlayer(0)
	for i = 0,3 do
		if player:GetCard(i) == card then return i end
	end
end

function funct.have_card(card)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_card(player,card) then return player end
	end
	return nil
end

function funct.check_explosion(ent)
	local explosions = Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.BOMB_EXPLOSION)
	local mamaMega = Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.MAMA_MEGA_EXPLOSION)
	if #mamaMega > 0 then
		return mamaMega
	end
	for _, splosion in pairs(explosions) do
		local frame = splosion:GetSprite():GetFrame()
		if frame < 3 then
			local size = splosion.SpriteScale.X
			if (ent.Position - splosion.Position):Length() <= 75 * size then
				return splosion
			end
		end
	end
	return nil
end

function funct.get_acceptible_devil_price(ent,price,params)
	if ent.Variant == 100 then
		params = params or {}
		local st = ent.SubType
		local ret = price or -1
		local config = Isaac:GetItemConfig()
		local collectibleinfo = config:GetCollectible(st)
		if collectibleinfo then	ret = - collectibleinfo.DevilPrice end
		for i = 1,1 do
			if funct.have_player_has_trinket(TrinketType.TRINKET_YOUR_SOUL) then ret = -6 break end
			local player = Game():GetPlayer(0)
			if (ret == -1 or ret == -2) and (player:GetEffectiveMaxHearts() == 0 or funct.is_soul_player(player)) then
				if funct.is_special_soul_dealer(player) then
					if ret == -1 then ret = -7
					else ret = -8 end
				else ret = -3 end
			end
			if ret == -2 and player:GetEffectiveMaxHearts() == 2 and not funct.is_soul_player(player) then ret = -4	end
		end
		if not params.ignore_flesh and auxi.have_player_has_collectible(672) then if collectibleinfo then ret = collectibleinfo.ShopPrice end end
		if not params.ignore_keeper and auxi.has_keeper_player() then if collectibleinfo then ret = collectibleinfo.ShopPrice end end
		return ret
	end
	return -5
end

local level_stage_map = {
	[1] = 1,
	[2] = 1,
	[3] = 2,
	[4] = 2,
	[5] = 3,
	[6] = 3,
	[7] = 4,
	[8] = 4,
	[9] = 5,
	[10] = 6,
	[11] = 7,
	[12] = 8,
	[13] = 9,
}

local greed_level_stage_map = {
	[1] = 1,
	[2] = 2,
	[3] = 3,
	[4] = 4,
	[5] = 6,
	[6] = 10,
	[7] = 10,
}

function funct.get_special_door_id()
	if Game():IsGreedMode() then
		return nil
	else
		local level = Game():GetLevel()
		local lev = level:GetStage()
		local lvtp = level:GetStageType()
		if level:IsAscent() then return nil end
		if (lev == 1 or lev == 2) and lvtp <= 3 then return 1 end
		if lev == 2 and lvtp > 3 then return 2 end
		if (lev == 3 or lev == 4) and lvtp <= 3 then return 2 end
		if lev == 4 and lvtp > 3 then return 3 end
		if lev == 5 and lvtp < 3 then return 3 end
		if lev == 6 and lvtp < 3 then return 4 end
		if lev == 6 and lvtp > 3 and not level:IsPreAscent() then return 5 end
	end
end

function funct.get_level_door_info()
	if Game():IsGreedMode() then
		return greed_level_stage_map[Game():GetLevel():GetStage()]
	else
		return level_stage_map[Game():GetLevel():GetStage()]
	end
end

local grid_config_stage_map = {
	[0] = {u = 1,v = 0,},
	[1] = {u = 1,v = 0,},
	[2] = {u = 1,v = 1,},
	[3] = {u = 1,v = 2,},
	[4] = {u = 2,v = 0,},
	[5] = {u = 2,v = 1,},
	[6] = {u = 2,v = 2,},
	[7] = {u = 3,v = 0,},
	[8] = {u = 3,v = 1,},
	[9] = {u = 3,v = 2,},
	[10] = {u = 4,v = 0,},
	[11] = {u = 4,v = 1,},
	[12] = {u = 4,v = 2,},
	[13] = {u = 5,v = 0,},
	[14] = {u = 6,v = 0,},
	[15] = {u = 6,v = 1,},
	[16] = {u = 7,v = 0,},
	[17] = {u = 7,v = 1,},
	
	[18] = {u = 1,v = 0,},
	[19] = {u = 1,v = 0,},
	[20] = {u = 2,v = 0,},
	[21] = {u = 3,v = 0,},
	[22] = {u = 4,v = 0,},
	[23] = {u = 5,v = 0,},
	[24] = {u = 10,v = 0,},
	[25] = {u = 10,v = 0,},
	
	[26] = {u = 1,v = 0,},
	
	[27] = {u = 1,v = 4,},
	[28] = {u = 1,v = 5,},
	[29] = {u = 2,v = 4,},
	[30] = {u = 2,v = 5,},
	[31] = {u = 3,v = 4,},
	[32] = {u = 3,v = 5,},
	[33] = {u = 4,v = 4,},
	[34] = {u = 4,v = 5,},
	[35] = {u = 9,v = 0,},
	[36] = {u = 1,v = 0,},
}

function funct.get_grid_by_stage_info(val)
	return grid_config_stage_map[val or Game():GetRoom():GetRoomConfigStage()] or {u = 1,v = 0,}
end

local grid_config_backdrop_map = {
	[0] = {u = 1,v = 0,},
	[1] = {u = 1,v = 0,},
	[2] = {u = 1,v = 1,},
	[3] = {u = 1,v = 2,},
	[4] = {u = 2,v = 0,},
	[5] = {u = 2,v = 1,},
	[6] = {u = 2,v = 2,},
	[7] = {u = 3,v = 0,},
	[8] = {u = 3,v = 1,},
	[9] = {u = 3,v = 2,},
	[10] = {u = 4,v = 0,},
	[11] = {u = 4,v = 1,},
	[12] = {u = 4,v = 2,},
	[13] = {u = 5,v = 0,},
	[14] = {u = 6,v = 0,},
	[15] = {u = 6,v = 1,},
	[16] = {u = 7,v = 0,},
	[17] = {u = 7,v = 1,},
	[18] = {u = 1,v = 0,},		--老撒旦
	[19] = {u = 1,v = 0,},
	[20] = {u = 1,v = 0,},
	[21] = {u = 1,v = 0,},
	[22] = {u = 1,v = 0,},
	[23] = {u = 2,v = 4,},
	[24] = {u = 1,v = 0,},
	[25] = {u = 1,v = 0,},
	[26] = {u = 1,v = 0,},
	[27] = {u = 5,v = 0,},
	[28] = {u = 1,v = 0,},
	[29] = {u = 1,v = 0,},
	[30] = {u = 3,v = 0,},
	[31] = {u = 1,v = 4,},
	[32] = {u = 2,v = 4,},
	[33] = {u = 3,v = 4,},
	[34] = {u = 4,v = 4,},
	[35] = {u = 6,v = 1,},
	[36] = {u = 1,v = 4,},
	[37] = {u = 2,v = 4,},
	[38] = {u = 3,v = 4,},
	[39] = {u = 4,v = 7,},
	[40] = {u = 3,v = 4,},
	[41] = {u = 3,v = 4,},
	[42] = {u = 3,v = 4,},
	[43] = {u = 4,v = 5,},
	[44] = {u = 4,v = 6,},
	[45] = {u = 1,v = 5,},
	[46] = {u = 2,v = 5,},
	[47] = {u = 3,v = 5,},
	[48] = {u = 4,v = 5,},
	[49] = {u = 1,v = 0,},
	[50] = {u = 1,v = 0,},
	[51] = {u = 1,v = 0,},
	[52] = {u = 1,v = 0,},
	[53] = {u = 1,v = 0,},
	[54] = {u = 1,v = 0,},
	[55] = {u = 1,v = 0,},
	[56] = {u = 1,v = 0,},
	[57] = {u = 1,v = 0,},
	[58] = {u = 2,v = 4,},
	[59] = {u = 2,v = 5,},
	[60] = {u = 4,v = 5,},
}

function funct.get_grid_by_backdrop_info(val)
	return grid_config_backdrop_map[val or Game():GetRoom():GetBackdropType()] or {u = 1,v = 0,}
end

local removed_pickups = {
	[50] = true,
	[51] = true,
	[52] = true,
	[53] = true,
	[54] = true,
	[55] = true,
	[56] = true,
	[57] = true,
	[58] = true,
	[60] = true,
	[100] = true,
	[360] = true,
}

function funct.would_be_removed_entity(ent)
	if ent.Type == 5 and removed_pickups[ent.Variant] and ent.SubType == 0 then return true end
end

function funct.check_table_not_empty(tbl)
	for u,v in pairs(tbl) do return true end
	return false
end

function funct.check_no_lerp(frame,info)
	local st = #info
	for i = 1,#info do
		local v = info[i]
		if frame <= v.frame then 
			st = math.max(1,i - 1)
			break
		end
	end
	return info[st]
end

function funct.check_lerp(frame,info,framename)
	framename = framename or "frame"
	local st = #info
	local ed = #info
	for i = 1,#info do
		local v = info[i]
		if frame <= v[framename] then 
			st = math.max(1,i - 1)
			ed = i
			break
		end
	end
	local lerper = (frame - info[st][framename])/math.max(0.01,(info[ed][framename] - info[st][framename]))
	local ret = {}
	for u,v in pairs(info[st]) do
		ret[u] = funct.Lerp(info[st][u],info[ed][u],lerper)
	end
	return ret
end

function funct.initialize_item(ent,params)
	params = params or {}
	ent = ent:ToPickup()
	if ent and ent.Type == 5 and ent.Variant == 100 then 
		ent.Touched = false
		local collectibleinfo = Isaac.GetItemConfig():GetCollectible(ent.SubType)
		if collectibleinfo then	ent.Charge = collectibleinfo.InitCharge	end
		if not params.NoEffecr then	local q = Isaac.Spawn(1000,15,0,ent.Position,Vector(0,0),nil) return q end
	end
end

function funct.get_item_from_pool(tp,decrease,rng)
	if type(rng) == "number" then local seed = rng rng = RNG() rng:SetSeed(seed,0) end
	tp = tp or Game():GetItemPool():GetPoolForRoom(Game():GetRoom():GetType(),Game():GetLevel():GetCurrentRoomDesc().SpawnSeed)
	if tp == -1 then tp = 0 end
	return Game():GetItemPool():GetCollectible(tp,decrease,rng:GetSeed())
end

function funct.judge_by_brimstone(player)
	local tp = 1
	local dmg = 1
	if player:HasCollectible(247) then 
		dmg = dmg * 1.5
		if player:HasCollectible(68) or player:HasCollectible(152) or player:HasCollectible(enums.Items.Tech_9) then
			tp = 14
			dmg = dmg * 1.5
		else
			tp = 11 
		end
	elseif player:HasCollectible(68) or player:HasCollectible(152) or player:HasCollectible(enums.Items.Tech_9) then
		dmg = dmg * 1.5
		tp = 9
	end
	local ret = {tp = tp,dmg = dmg,}
	return ret
end

local unstopable = {
	[EntityType.ENTITY_PLAYER] = true,
	--[EntityType.ENTITY_TEAR] = true,
	[EntityType.ENTITY_LASER] = true,
	--[EntityType.ENTITY_MINECART] = true,
	[EntityType.ENTITY_KNIFE] = true,
	[EntityType.ENTITY_PROJECTILE] = true,
	[EntityType.ENTITY_TEXT] = true,
	[EntityType.ENTITY_EFFECT] = true,
}

local eventlist = {
	"Explosion",
	"Shoot",
	"Jump",
	"Land",
	"BloodStart",
	"BloodStop",
	"Heartbeat",
	"Lift",
	"Stop",
	"Slide",
	"Spawn",
	"Shoot2",
	"DeathSound",
	"DropSound",
	"Disappear",
	"Prize",
	"Shuffle",
	"CoinInsert",
}

-- 活跃时停源（按 name）；宝宝自驱会无视 FLAG_FREEZE，需配合 is_time_stopped 早退 / PRE 跳过 AI。
funct._time_stop_active = funct._time_stop_active or {}
funct._time_stop_refresh_frame = funct._time_stop_refresh_frame or {}
funct._time_stop_probe_observer = funct._time_stop_probe_observer or nil

function funct.set_time_stop_probe_observer(observer)
	funct._time_stop_probe_observer = type(observer) == "function" and observer or nil
end

function funct.is_time_stopped(name)
	if name ~= nil then return funct._time_stop_active[name] == true end
	return next(funct._time_stop_active) ~= nil
end

local function time_stop_pos_compare(v1, v2)
	return (v1 - v2):Length() < 0.001
end

local function time_stop_vel_compare(v1, v2)
	return (v1 - v2):Length() < 0.001
end

local function apply_time_stop_claims(name)
	local observer = funct._time_stop_probe_observer
	local audit = observer and {
		name = name, frame = Game():GetFrameCount(), scanned = 0, eligible = 0,
		already_complete = 0, entities_missing = 0, claim_attempts = 0,
		claim_created = 0, claim_failed = 0, player_claim_attempts = 0,
		player_claim_created = 0,
	} or nil
	local n_entity = Isaac.GetRoomEntities()
	for _,v in pairs(n_entity) do
		if audit then audit.scanned = audit.scanned + 1 end
		if funct.check_if_any(unstopable[v.Type],v) ~= true then
			if audit then audit.eligible = audit.eligible + 1 end
			local d = v:GetData()
			local keys = {
				name.."_freeze_succ", name.."_no_sprite_update_succ",
				name.."_position_succ", name.."_velocity_succ",
			}
			local missing = 0
			if audit then
				for i = 1, #keys do if d[keys[i]] == nil then missing = missing + 1 end end
				if missing == 0 then audit.already_complete = audit.already_complete + 1
				else audit.entities_missing = audit.entities_missing + 1; audit.claim_attempts = audit.claim_attempts + missing end
			end
			-- 已接管实体在增量刷新时不再重复检查事件或推进 Sprite。
			if d[name.."_freeze_succ"] == nil or d[name.."_no_sprite_update_succ"] == nil then
				local s = v:GetSprite()
				for _,event_name in pairs(eventlist) do if s:IsEventTriggered(event_name) ~= false then s:Update() end end
			end
			if d[name.."_freeze_succ"] == nil then d[name.."_freeze_succ"] = Attribute_holder.try_hold_attribute(v,"EntityFlag_FLAG_FREEZE",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FREEZE)) end
			if d[name.."_no_sprite_update_succ"] == nil then d[name.."_no_sprite_update_succ"] = Attribute_holder.try_hold_attribute(v,"EntityFlag_FLAG_NO_SPRITE_UPDATE",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_SPRITE_UPDATE)) end
			-- protect：FollowPosition / 自驱写 Position 时不要把冻结原点跟着滑走
			if d[name.."_position_succ"] == nil then d[name.."_position_succ"] = Attribute_holder.try_hold_attribute(v,"Position",Vector(v.Position.X,v.Position.Y),{protect = true,tocompare = time_stop_pos_compare,}) end
			if d[name.."_velocity_succ"] == nil then d[name.."_velocity_succ"] = Attribute_holder.try_hold_attribute(v,"Velocity",Vector(0,0),{protect = true,tocompare = time_stop_vel_compare,})	end
			if audit and missing > 0 then
				local still_missing = 0
				for i = 1, #keys do if d[keys[i]] == nil then still_missing = still_missing + 1 end end
				audit.claim_created = audit.claim_created + missing - still_missing
				audit.claim_failed = audit.claim_failed + still_missing
			end
		end
	end
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		local collision_key = name.."_entitycollisionclass_none_succ"
		local attack_key = name.."_data_should_not_attack_succ"
		if d[collision_key] == nil then
			if audit then audit.player_claim_attempts = audit.player_claim_attempts + 1 end
			d[collision_key] = Attribute_holder.try_hold_attribute(player,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE)
			if audit and d[collision_key] ~= nil then audit.player_claim_created = audit.player_claim_created + 1 end
		end
		if d[attack_key] == nil then
			if audit then audit.player_claim_attempts = audit.player_claim_attempts + 1 end
			d[attack_key] = Attribute_holder.try_hold_attribute(player,"Data_should_not_attack",true,Attribute_holder.descriptors.data_field("should_not_attack"))
			if audit and d[attack_key] ~= nil then audit.player_claim_created = audit.player_claim_created + 1 end
		end
	end
	if observer then pcall(observer, audit) end
end

function funct.refresh_time_stop(name, interval)
	name = name or ""
	if funct._time_stop_active[name] ~= true then return false end
	local frame = Game():GetFrameCount()
	interval = math.max(1, math.floor(tonumber(interval) or 15))
	if frame - (funct._time_stop_refresh_frame[name] or -interval) < interval then return false end
	funct._time_stop_refresh_frame[name] = frame
	apply_time_stop_claims(name)
	return true
end

function funct.time_stop(name)
	name = name or ""
	-- 已开启时必须是常数级；增量接管新实体请显式调用 refresh_time_stop。
	if funct._time_stop_active[name] == true then return false end
	funct._time_stop_active[name] = true
	funct._time_stop_refresh_frame[name] = Game():GetFrameCount()
	apply_time_stop_claims(name)
	return true
end

function funct.time_free(name)
	name = name or ""
	funct._time_stop_active[name] = nil
	funct._time_stop_refresh_frame[name] = nil
	local n_entity = Isaac.GetRoomEntities() 
	for u,v in pairs(n_entity) do 
		if funct.check_if_any(unstopable[v.Type],v) ~= true then
			local d = v:GetData()
			if d[name.."_freeze_succ"] then
				Attribute_holder.try_rewind_attribute(v,"EntityFlag_FLAG_FREEZE",d[name.."_freeze_succ"],Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FREEZE))
				d[name.."_freeze_succ"] = nil
			end
			if d[name.."_no_sprite_update_succ"] then
				Attribute_holder.try_rewind_attribute(v,"EntityFlag_FLAG_NO_SPRITE_UPDATE",d[name.."_no_sprite_update_succ"],Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_SPRITE_UPDATE))
				d[name.."_no_sprite_update_succ"] = nil
			end
			if d[name.."_position_succ"] then
				Attribute_holder.try_rewind_attribute(v,"Position",d[name.."_position_succ"],{tocompare = time_stop_pos_compare,})
				d[name.."_position_succ"] = nil
			end
			if d[name.."_velocity_succ"] then
				Attribute_holder.try_rewind_attribute(v,"Velocity",d[name.."_velocity_succ"],{tocompare = time_stop_vel_compare,})
				d[name.."_velocity_succ"] = nil
			end
		end
	end
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		if d[name.."_entitycollisionclass_none_succ"] then
			Attribute_holder.try_rewind_attribute(player,"EntityCollisionClass",d[name.."_entitycollisionclass_none_succ"])
			d[name.."_entitycollisionclass_none_succ"] = nil
		end
		if d[name.."_data_should_not_attack_succ"] then
			Attribute_holder.try_rewind_attribute(player,"Data_should_not_attack",d[name.."_data_should_not_attack_succ"],{toget = function(ent) return ent:GetData().should_not_attack end,tochange = function(ent,value) ent:GetData().should_not_attack = value end,})
			d[name.."_data_should_not_attack_succ"] = nil
		end
	end
end

function funct.protect_text(str)
	str = string.gsub(str,"，",", ") 
	str = string.gsub(str,"？","? ") 
	str = string.gsub(str,"！","! ") 
	return str
end

--l local ent = Game():Spawn(5, PickupVariant.PICKUP_GRAB_BAG, Game():GetPlayer(0).Position, Vector(0,0), nil, SackSubType.SACK_NORMAL,6) ent:GetSprite():SetLastFrame() ent:Update() ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR) ent.Visible = false for i = 1,10 do ent:Update() end ent:Remove() Game():GetPlayer(0):Update()
function funct.StartAmbush()
	if REPENTOGON then Ambush.StartChallenge() return end
	local player = Isaac.GetPlayer()
	local SACK_SEED_THAT_SPAWNS_TWO_COINS = 6
	local ent = Game():Spawn(5, PickupVariant.PICKUP_GRAB_BAG, player.Position, Vector(0,0), nil, SackSubType.SACK_NORMAL, SACK_SEED_THAT_SPAWNS_TWO_COINS)
	ent:GetSprite():SetLastFrame()
	ent:Update()
	ent:GetData().ignore_me = true
	ent.Visible = false
	local s = ent:GetSprite()
	SFXManager():Stop(252)
	for i = 2,4 do delay_buffer.addeffe(function(params) SFXManager():Stop(252) end,{},i) end
	delay_buffer.addeffe(function(params)
		local futureSack = params.Ref
		if not futureSack then return end
		futureSack:Remove()
		local sackPtrHash = GetPtrHash(futureSack)
		for _, coin in pairs(Isaac.FindByType(5, PickupVariant.PICKUP_COIN)) do
			if coin.SpawnerEntity and GetPtrHash(coin.SpawnerEntity) == sackPtrHash then coin:Remove() end
		end
		
	end,{Ref = ent},2)
end

local ambush_roomtypes = {
	[RoomType.ROOM_CHALLENGE] = true,
	[RoomType.ROOM_BOSSRUSH] = true,
}

local ambush_pickups = {
	[50] = true,
	[51] = true,
	[52] = true,
	[53] = true,
	[54] = true,
	[55] = true,
	[56] = true,
	[57] = true,
	[60] = true,
	[69] = true,
	[100] = true,
	[360] = true,
	[enums.Pickups.Glaze_chest] = true,
}

function funct.can_start_ambush(ent)
	if auxi.check_if_any(ambush_pickups[ent.Variant],ent) then return true end
	return false
end

function funct.would_start_ambush()
	local room = Game():GetRoom()
	return (ambush_roomtypes[room:GetType()] and room:IsAmbushDone() ~= true and room:IsAmbushActive() ~= true)
end

function funct.try_start_ambush()
	local room = Game():GetRoom()
	if ambush_roomtypes[room:GetType()] and room:IsAmbushDone() ~= true and room:IsAmbushActive() ~= true then
		funct.StartAmbush()
	end
end

function funct.get_acceptible_index(sgid,dim)
	sgid = sgid or Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex
	if dim == -1 then dim = nil end
	dim = dim or funct.GetDimension()
	if sgid < 0 then return sgid 
	else return dim * 1000 + sgid end
end

function funct.check_to_number(num,rng)
	local n1 = math.floor(num)
	local n2 = math.ceil(num)
	local rnd = math.random(1000)/1000
	if rng then rnd = rng:RandomFloat() end
	if rnd > num - n1 then return n1 else return n2 end
end

function funct.split_bits(num)
	local tbl = {}
	local sz = math.floor(math.log(num)/math.log(2))
	for i = 0,sz + 1 do
		if num % 2 == 1 then table.insert(tbl,#tbl + 1,i) end
		num = (num - num % 2) / 2
	end
	return tbl
end

function funct.check_equal(val1,val2)
	if val1 == nil or val2 == nil or val1 == -1 or val2 == -1 or val1 == val2 then return true end
	return false
end

local Controller = {
	DPAD_LEFT = 0,
	DPAD_RIGHT = 1,
	DPAD_UP = 2,
	DPAD_DOWN = 3,
	BUTTON_A = 4,
	BUTTON_B = 5,
	BUTTON_X = 6,
	BUTTON_Y = 7,
	BUMPER_LEFT = 8,
	TRIGGER_LEFT = 9,
	STICK_LEFT = 10,
	BUMPER_RIGHT = 11,
	TRIGGER_RIGHT = 12,
	STICK_RIGHT = 13,
	BUTTON_BACK = 14,
	BUTTON_START = 15,
}

function funct.random_bool(rng)
	if rng then if rng:RandomInt(2) == 1 then return true end
	else if math.random(2) == 1 then return true end end
	return false
end

local possible_targets = {
	{Type = 3,Variant = FamiliarVariant.PUNCHING_BAG,},
	{Type = 3,Variant = FamiliarVariant.LOST_FLY,},
}

function funct.get_acceptible_player_target(ent)
	local ret = nil
	local tbl = {}
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		table.insert(tbl,#tbl + 1,player)
	end
	for u_,v_ in pairs(possible_targets) do
		local tg = funct.getothers(nil,v_.Type,v_.Variant)
		for u,v in pairs(tg) do table.insert(tbl,#tbl + 1,v) end
	end
	for u,v in pairs(tbl) do
		if ret == nil or (ret.Position - ent.Position):Length() > (v.Position - ent.Position):Length() then	ret = v	end
	end
	return ret or Game():GetPlayer(0)
end

function funct.get_acceptible_target(ent)
	if ent.Target then return ent.Target end
	if ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then 
		return funct.get_nearest_enemy(nil,ent.Position) or funct.get_acceptible_player_target(ent)
	else
		return funct.get_acceptible_player_target(ent)
	end
end

function funct.get_quality_item(qual)
	qual = qual or 4
	local tbl = {}
	local itemConfig = Isaac.GetItemConfig()
	local sz = itemConfig:GetCollectibles().Size
	for id = 1,sz do
		local collectible = itemConfig:GetCollectible(id)
		if (collectible and not collectible.Hidden and not collectible:HasTags(1<<15) and collectible.Quality == qual) then
			table.insert(tbl,#tbl + 1,id)
		end
	end
	return funct.random_in_table(tbl)
end

local double_charge_room = {
	[RoomShape.ROOMSHAPE_2x2] = true,
	[RoomShape.ROOMSHAPE_LTL] = true,
	[RoomShape.ROOMSHAPE_LTR] = true,
	[RoomShape.ROOMSHAPE_LBL] = true,
	[RoomShape.ROOMSHAPE_LBR] = true,
}

function funct.get_charge_from_room(roomdesc)
	roomdesc = roomdesc or Game():GetLevel():GetCurrentRoomDesc()
	if not roomdesc.Data then return 1 end
	if double_charge_room[roomdesc.Data.Shape] then return 2
	else return 1 end
end

function funct.should_real_charge(player,slot)
	player = player or Game():GetPlayer(0)
	slot = slot or 0
	local id = player:GetActiveItem(slot)
	local col = Isaac.GetItemConfig():GetCollectible(id)
	if col == nil then return false end
	if player:GetActiveCharge(slot) < col.MaxCharges then return true end
	if funct.has_have_coll(player,CollectibleType.COLLECTIBLE_BATTERY) then if player:GetBatteryCharge(slot) < col.MaxCharges then return true end end
	return false
end

function funct.can_open(col)
	if (col.Variant >= 50 and col.Variant <= 69) or col.Variant == 360 or col.Variant == 390 then return true
	else return false end
end

function funct.illustrate_ent(ent)
	if ent.IsGrid then 
	elseif ent:ToPlayer() then ent = ent:ToPlayer()
	elseif ent:ToEffect() then ent = ent:ToEffect()
	elseif ent:ToNPC() then ent = ent:ToNPC()
	elseif ent:ToPickup() then ent = ent:ToPickup()
	elseif ent:ToFamiliar() then ent = ent:ToFamiliar()
	elseif ent:ToBomb() then ent = ent:ToBomb()
	elseif ent:ToKnife() then ent = ent:ToKnife()
	elseif ent:ToLaser() then ent = ent:ToLaser()
	elseif ent:ToTear() then ent = ent:ToTear()
	elseif ent:ToProjectile() then ent = ent:ToProjectile()
	elseif REPENTOGON and ent:ToSlot() then ent = ent:ToSlot() end
	return ent
end

local key_chest_list = {
	[53] = true,
	[55] = true,
	[57] = true,
	[60] = true,
}

function funct.needs_key(ent)
	return funct.check_if_any(key_chest_list[ent.Variant],ent)
end

local open_chest_list = {
	[53] = function(ent) local s = ent:GetSprite() if s:IsPlaying("Idle") or s:IsFinished("Idle") or s:IsFinished("Close") then return true end end,
	[57] = function(ent) local s = ent:GetSprite() if s:IsPlaying("Idle") or s:IsFinished("Idle") or s:IsFinished("UseKey") or s:IsFinished("UseGoldenKey") then return true end end,
}

function funct.needs_open(ent)
	return funct.check_if_any(open_chest_list[ent.Variant] or (function(ent) local s = ent:GetSprite() if s:IsPlaying("Idle") or s:IsFinished("Idle") then return true end end),ent)
end

local grid_rot_dirs = {
	{dv = Vector(0,-40),dir = -180,},
	{dv = Vector(0,40),dir = 0,},
	{dv = Vector(40,0),dir = -90,},
	{dv = Vector(-40,0),dir = 90,},
}

function funct.find_rot_dir(idx)
	local room = Game():GetRoom()
	local wid = room:GetGridWidth()
	local pos = room:GetGridPosition(idx)
	for u,v in pairs(grid_rot_dirs) do
		if room:IsPositionInRoom(pos + v.dv,-30) == false then
			return v.dir
		end
	end
	return 0
end

local check_path_dirs = {
	{dv = Vector(0,-40),dir = -180,},
	{dv = Vector(0,40),dir = 0,},
	{dv = Vector(40,0),dir = -90,},
	{dv = Vector(-40,0),dir = 90,},
}

local ignore_grid = {
	[GridEntityType.GRID_DECORATION] = true,
	[GridEntityType.GRID_SPIKES] = true,
	[GridEntityType.GRID_SPIKES_ONOFF] = true,
	[GridEntityType.GRID_SPIDERWEB] = true,
	[GridEntityType.GRID_TNT] = true,
	[GridEntityType.GRID_POOP] = true,
	[GridEntityType.GRID_TRAPDOOR] = true,
	[GridEntityType.GRID_STAIRS] = true,
	[GridEntityType.GRID_PRESSURE_PLATE] = true,
}

function funct.check_path_from_door()
	local room = Game():GetRoom()
	local door = {}
	for slot = 0,7 do 
		if room:GetDoor(slot) then 
			door[room:GetGridIndex(room:GetDoorSlotPosition(slot))] = true
		end
	end
	return auxi.check_path_from(door)
end

function funct.check_path_from(tbl)
	local room = Game():GetRoom()
	local rec = {}
	local ret = {}
	for u,v in pairs(tbl) do table.insert(rec,#rec + 1,u) end
	while(rec[1]) do
		table.insert(ret,#ret + 1,rec[1])
		for u,v in pairs(check_path_dirs) do
			local t_pos = v.dv + room:GetGridPosition(rec[1])
			local idx = room:GetGridIndex(t_pos)
			if (not tbl[idx]) and room:IsPositionInRoom(t_pos,0) then 
				tbl[idx] = true
				local grid = room:GetGridEntity(idx)
				if (not grid) or ignore_grid[grid:GetType()] or grid.CollisionClass == GridCollisionClass.COLLISION_NONE then
					table.insert(rec,#rec + 1,idx)
				end
			end
		end
		table.remove(rec,1)
	end
	return ret
end

function funct.has_door()
	local room = Game():GetRoom()
	for slot = 0,7 do 
		if room:GetDoor(slot) then return true end
	end
	return false
end

function funct.check_path_to_door(pos)
	local room = Game():GetRoom()
	local mp = {}
	local door = {}
	local succ = false
	for slot = 0,7 do 
		if room:GetDoor(slot) then 
			door[room:GetGridIndex(room:GetDoorSlotPosition(slot))] = true
			succ = true
		end
	end
	if succ ~= true then return true end
	local tbl = {}
	mp[room:GetGridIndex(pos)] = true
	pos = room:GetGridPosition(room:GetGridIndex(pos))
	local grid = room:GetGridEntity(room:GetGridIndex(pos))
	if (not grid) or ignore_grid[grid:GetType()] or grid.CollisionClass == GridCollisionClass.COLLISION_NONE then
		table.insert(tbl,pos)
	end
	while(tbl[1]) do
		for u,v in pairs(check_path_dirs) do
			local t_pos = v.dv + tbl[1]
			local idx = room:GetGridIndex(t_pos)
			if door[idx] then return false end
			if (not mp[idx]) and room:IsPositionInRoom(t_pos,0) then 
				mp[idx] = true
				local grid = room:GetGridEntity(idx)
				if (not grid) or ignore_grid[grid:GetType()] or grid.CollisionClass == GridCollisionClass.COLLISION_NONE then
					table.insert(tbl,t_pos)
				end
			end
		end
		table.remove(tbl,1)
	end
	return true
end

function funct.check_path_to(pos,tgs)
	local room = Game():GetRoom()
	local mp = {}
	local tgs = tgs or {}
	local tbl = {}
	local id = room:GetGridIndex(pos)
	mp[id] = true
	if tgs[id] then return false end
	pos = room:GetGridPosition(id)
	local grid = room:GetGridEntity(id)
	if (not grid) or ignore_grid[grid:GetType()] or grid.CollisionClass == GridCollisionClass.COLLISION_NONE then
		table.insert(tbl,pos)
	end
	while(tbl[1]) do
		for u,v in pairs(check_path_dirs) do
			local t_pos = v.dv + tbl[1]
			local idx = room:GetGridIndex(t_pos)
			if (not mp[idx]) and room:IsPositionInRoom(t_pos,0) then 
				mp[idx] = true
				local grid = room:GetGridEntity(idx)
				if ((not grid) or ignore_grid[grid:GetType()] or grid.CollisionClass == GridCollisionClass.COLLISION_NONE) and room:GetGridPath(idx) <= 900 then
					table.insert(tbl,t_pos)
					if tgs[idx] then return false end
				end
			end
		end
		table.remove(tbl,1)
	end
	return true
end

function funct.gidx2pos(idx) return Game():GetRoom():GetGridPosition(idx) end
function funct.pos2gidx(pos) return Game():GetRoom():GetGridIndex(pos) end

local record_DFC_target = {		--只控制强制转移的敌人
	[5] = true,
	[6] = true,
	[17] = true,
	[30] = true,
	[33] = true,
	[36] = true,
	[40] = true,		--很特殊哦
	[42] = true,
	[45] = true,
	[56] = true,
	[59] = true,
	[60] = true,
	--[61] = true,		--目标坐标
	--[63] = true,
	--[65] = true,
	[84] = true,
	[78] = true,
	[96] = true,
	[101] = true,
	[102] = true,
	[201] = true,
	[202] = true,
	[203] = true,
	[209] = true,
	[218] = true,
	[221] = true,
	[228] = true,
	[231] = true,
	[235] = true,
	[236] = true,
	[240] = true,
	[241] = true,
	[242] = true,
	[244] = true,
	[245] = true,
	[251] = true,
	[255] = true,
	[262] = true,
	[263] = true,
	[266] = true,
	[270] = true,
	[273] = function(ent) if ent.Variant == 10 then return true end end,
	[274] = true,
	[275] = true,
	[276] = true,
	[289] = true,
	[292] = true,
	[294] = true,
	[298] = true,
	[300] = true,
	[304] = true,
	[306] = true,
	[307] = true,
	[309] = true,
	[406] = function(ent) if ent.State == 9000 or ent.State == 9001 then return true end end,
	[804] = true,
	[805] = true,
	[809] = true,
	[825] = true,
	[829] = true,
	[832] = function(ent) if ent.Variant == 1 and ent.SubType > 0 and (ent.State == 16 or ent.State == 5) then return true end end,
	[837] = true,
	[852] = true,
	[856] = true,
	[861] = true,
	[862] = true,
	[877] = true,
	[880] = true,
	[881] = true,
	[889] = true,
	[900] = true,
	[904] = function(ent) if ent.Variant == 1 then return true end end,
	[905] = function(ent) if ent.State == 6 then return true end end,
	[906] = true,
	[907] = true,
	[911] = true,
	[912] = function(ent) if ent.Variant < 100 then return true end end,
	[914] = true,
	[917] = true,
	--919
	[921] = true,
	[950] = function(ent) if ent.Variant == 1 or ent.Variant == 2 then return true end end,
	[951] = function(ent) if ent.Variant == 0 or ent.Variant == 1 then return true end end,
	[960] = true,
	[964] = true,
	[965] = true,
	[967] = true,
}

local record_DFC_middle_target = {
	[29] = true,		--
	[54] = true,		--
	[86] = true,		--
	[215] = true,		--
	[246] = true,		--
	[250] = true,		--
	[305] = true,		--
	[840] = true,		--
	[851] = true,		--
	--[869] = true,		--
	--[20] = true,		--
	--[100] = true,		--
	--[68] = true,		--
	--[264] = true,		--
	--[43] = true,		--
	[410] = true,		--
}

function funct.fix_position(ent,pos)
	pos = ent.Position
	--if not auxi.check_if_any(item.no_target[ent.Type],ent) then ent.TargetPosition = pos end
	if auxi.check_if_any(record_DFC_target[ent.Type],ent) then ent.TargetPosition = pos end
	if auxi.check_if_any(record_DFC_middle_target[ent.Type],ent) then ent.TargetPosition = pos * 0.9 + Game():GetPlayer(0).Position * 0.1 end
end

function funct.get_EID_language()
	local language = "en_us"
	if EID and EID.Config["Language"] then
		language = EID.Config["Language"]
		if language == "auto" then language = (Options and EID.LanguageMap[Options.Language]) or "en_us" end
	end
	return language
end

function funct.is_normal_game() return (Isaac.GetChallenge() > 0 or Game():GetVictoryLap() > 0) ~= true end

function funct.safely_remove(ent)
	if ent.Type == 5 then ent.SubType = 0 end
	if ent:ToNPC() then ent:Morph(16,0,0,0) end
	ent.Position = Vector(2000,2000)
	ent:Remove()
end

function funct.safely_kill(ent)
	if ent:ToNPC() then ent:ToNPC():Morph(16,0,0,0) end
	ent.Position = Vector(2000,2000)
	ent:Kill()
end

function funct.illustrate_sprite_(ent,s,ent2)
	--auxi.PrintTable(ent)
	if (ent.Type or 0) == 5 then
		if ent.Variant == 100 then
			local config = Isaac.GetItemConfig()
			local info = config:GetCollectible(ent.SubType)
			local save = funct.get_save()
			if ent.SubType == enums.Items.It_s_a_trick then info = config:GetCollectible(save.elses.glazed_trick or 32) or config:GetCollectible(32) end
			if info == nil then info =  {GfxFileName = "gfx/effects/nill.png",} end
			if ent.B then s:ReplaceSpritesheet(1,"gfx/items/collectibles/questionmark.png")
			else s:ReplaceSpritesheet(1,info.GfxFileName) end
			s:LoadGraphics()
		elseif ent.Variant == 350 then
			local config = Isaac.GetItemConfig()
			local info = config:GetTrinket(ent.SubType)
			s:ReplaceSpritesheet(0,info.GfxFileName)
			s:LoadGraphics()
		end
	elseif (ent.Type or 0) == 1001 then
		local grid_morpher = require("Qing_Remaster_scripts.grids.grid_morpher")
		grid_morpher.morph_info(ent,{ent = ent2,})
	end
end

function funct.illustrate_sprite(ent,s)
	if ent.Type == 5 then
		if ent.Variant == 100 then
			local config = Isaac.GetItemConfig()
			local info = config:GetCollectible(ent.SubType)
			local save = funct.get_save()
			if ent.SubType == enums.Items.It_s_a_trick then info = config:GetCollectible(save.elses.glazed_trick or 32) or config:GetCollectible(32) end
			if info == nil then info =  {GfxFileName = "gfx/effects/nill.png",} end
			if auxi.isBlindPickup(ent) then s:ReplaceSpritesheet(1,"gfx/items/collectibles/questionmark.png")
			else s:ReplaceSpritesheet(1,info.GfxFileName) end
			s:LoadGraphics()
		elseif ent.Variant == 350 then
			local config = Isaac.GetItemConfig()
			local info = config:GetTrinket(ent.SubType)
			s:ReplaceSpritesheet(0,info.GfxFileName)
			s:LoadGraphics()
		end
	elseif ent.Type == 2 then
		if ent.Variant == 40 then
			local grid_morpher = require("Qing_Remaster_scripts.grids.grid_morpher")
			grid_morpher.load_grid(s,{gtp = math.floor(ent.SubType/65536),gfr = ent.SubType%65536,})
		end
	end
end

local alchemy_items = {
	enums.Items.A_Shard_Of_Coin,
	enums.Items.A_Shard_Of_Glaze,
	enums.Items.A_Shard_Of_Lava,
	enums.Items.A_Shard_Of_Meat,
	enums.Items.A_Shard_Of_Rock,
	--enums.Items.A_Shard_Of_Blood,
}

function funct.get_alchemy_count()
	local cnt = 0
	for u,v in pairs(alchemy_items) do
		if auxi.have_player_has_collectible(v) then cnt = cnt + 1 end
	end
	return cnt
end

function funct.add_EID_item_synic(ent,description,check_language)
	
if EID then
	local descinfo = description
	if check_language then descinfo = description[EID.LanguageMap[Options.Language] or "en_us"] or description["zh_cn"] or description["en_us"] or description[Options.Language] or description["zh"] or description["en"] end
	EID:addDescriptionModifier("qing_item_sync"..tostring(ent), function(desc) local ret = auxi.have_player_has_collectible(ent) if ret then return true end end, function(desc)
		local tp = desc.ObjType
		local vr = desc.ObjVariant
		local st = desc.ObjSubType
		if (tp == 5 and vr == 100 and descinfo[st]) then
			local info = descinfo[st].desc
			if (info) then
				info = "#"..info
				local repl = "#{{Collectible"..tostring(ent).."}} "
				info = string.gsub(info, "#", repl)
				EID:appendToDescription(desc, info)
			end
		end
		return desc
	end)
	for u,v in pairs(descinfo) do
		if u ~= ent then
			EID:addDescriptionModifier("qing_item_sync"..tostring(ent).."_r_"..tostring(u), function(desc) local ret = auxi.have_player_has_collectible(u) if ret then return true end end, function(desc)
				local tp = desc.ObjType
				local vr = desc.ObjVariant
				local st = desc.ObjSubType
				if (tp == 5 and vr == 100 and st == ent) then
					local info = descinfo[u].desc
					if (info) then
						info = "#"..info
						local repl = "#{{Collectible"..tostring(u).."}} "
						info = string.gsub(info, "#", repl)
						EID:appendToDescription(desc, info)
					end
				end
				return desc
			end)
		end
	end
end

end

function funct.try_require(name)
	local ret = require(name)
	while(type(ret) == "table" and ret.Assemble_holder_linker) do ret = ret.Assemble_holder_linker end
	return ret
end

function funct.find_in_parents(ent,check)
	if auxi.check_if_any(check,ent) then return true end
	local ents = auxi.get_linked(ent)
	for u,v in pairs(ents) do if auxi.check_if_any(check,ent) then return true end end
	return ret
end

function funct.is_all_clear()
	local room = Game():GetRoom()
	return room:IsClear() and room:GetAliveEnemiesCount() == 0 and room:GetAliveBossesCount() == 0
end

function funct.may_all_clear()
	local n_enemy = auxi.getenemies()
	if #n_enemy == 0 then return true end
end

function funct.is_death_item(ent)
	return ent:ToPickup().OptionsPickupIndex == 1
end

local heart_pickup_map = {
	[1] = "CanPickRedHearts",
	[2] = "CanPickRedHearts",
	[3] = "CanPickSoulHearts",
	--4
	[5] = "CanPickRedHearts",
	[6] = "CanPickBlackHearts",
	[7] = "CanPickGoldenHearts",
	[8] = "CanPickSoulHearts",
	[9] = "CanPickRedHearts",
	[10] = function(player) return player:CanPickRedHearts() or player:CanPickSoulHearts() end,
	[11] = "CanPickBoneHearts",
	[12] = "CanPickRottenHearts",
}

function funct.need_a_charge(player)
	for i = 0,3 do
		if player:NeedsCharge(i) then return true end
	end
	return false
end

function funct.will_pick_up(player,ent)
	if player:IsExtraAnimationFinished() and player:IsItemQueueEmpty() then
		if ent.Variant == 100 then
			if player:CanPickupItem() and (ent.FrameCount - math.min(0,(ent:GetData()["Uni_h_PICKUP_TIME"] or 0)) >= 20) and Game():GetFrameCount() - (player:GetData()["Uni_h_PICKUP_TIME"] or -100) >= 52 and ent.SubType ~= 0 then return true end
		elseif ent.Variant == 10 then
			local info = heart_pickup_map[ent.SubType]
			local succ = auxi.check_if_any(info,player) or true
			if type(succ) == "string" then succ = player[succ](player) end
			return succ
		elseif ent.Variant == 90 then
			if auxi.need_a_charge(player) then return true end
		else
			return true
		end
	end
	return false
end

function funct.may_pick_up(player,ent)
	if player:IsExtraAnimationFinished() and player:IsItemQueueEmpty() and ent.SubType ~= 0 then return true end
end

function funct.check_if_value(val,default,...)
	if type(val) == "function" then return val(...) end
	return (default or (function(v) return v end))(val,...)
end

function funct.cut_by(v,tbl,params)		--将一个支持乘法的值按tbl内容切分为同数量段。
	local ret = {}
	params = params or {}
	if type(tbl) == "number" then 
		if tbl >= 0 then
			for i = 1,tbl do ret[i] = auxi.check_if_value(v,function(v,a) return v * a end,i/tbl) end
		else return {v} end
	else 
		local cnt = 0
		local ct = 0
		for i = 1,#tbl do local v = tbl[i] cnt = cnt + v end
		if cnt > 0 then 
			for i = 1,#tbl do 
				ct = ct + tbl[i]/cnt
				ret[i] = auxi.check_if_value(v,function(v,a) return v * a end,ct) 
			end
		else return {v} end
	end
	table.insert(ret,1,auxi.check_if_value(v,function(v,a) return v * a end,0)) 
	return ret
end
--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") auxi.PrintTable(auxi.cut_by(auxi.sigmod,{5,2,41,-1,20,}))
function funct.set_to(tbl,tbl2,key)		--将tbl2内所有值作为tbl的key键值对应值
	key = key or "Setted"
	for u,v in pairs(tbl2 or {}) do 
		tbl[u] = tbl[u] or {}
		tbl[u][key] = v
	end
	return tbl
end

function funct.make_lerp(tbl)
	tbl = tbl or {}
	params = params or {}
	local ret = {{frame = 0,},}
	local total = 0
	if #tbl > 0 then 
		local multi = 0
		for i = 1,#tbl do 
			table.insert(ret,#ret + 1,{frame = tbl[i] + multi,})
			if not tbl.multi then multi = multi + tbl[i] end
		end
		total = multi if tbl.multi then total = total + tbl[#tbl] end
	end
	if tbl.cnt or tbl.mul then
		for i = 1,(tbl.mul or 1) do
			table.insert(ret,#ret + 1,{frame = total + i * (tbl.cnt or 1),})
		end
		total = total + (tbl.cnt or 1) * (tbl.mul or 1)
	end
	if not tbl.no_total then ret.total = total end
	return ret
end

local flip_directions = {
	[0] = 2,
	[1] = 3,
	[2] = 0,
	[3] = 1,
}
function funct.flipdirection(dir) return flip_directions[dir] end

local Gridroom_dir_move = {
	[-1] = 0,
	[-13] = 1,
	[1] = 2,
	[13] = 3,
}
function funct.move2dir(dir) return Gridroom_dir_move[dir] or -1 end
local Gridroom_move_dir = {
	[0] = -1,
	[1] = -13,
	[2] = 1,
	[3] = 13,
}

function funct.move_in_gridroom(id,dir)		--dir = 0,1,2,3
	if (id % 13 == 0 and dir == 0) or (id % 13 == 12 and dir == 2) or (id < 13 and dir == 1) or (id >= 13 * 12 and dir == 3) then return id end
	return id + Gridroom_move_dir[dir]
end

local Grid_move_dir = {
	[0] = Vector(-1,0),
	[1] = Vector(0,-1),
	[2] = Vector(1,0),
	[3] = Vector(0,1),
}
function funct.move_in_roomgrid(id,dir,width,height)
	width = width or 15 height = height or 9
	if (id % width == 0 and dir == 0) or (id % width == width - 1 and dir == 2) or (id < height and dir == 1) or (id >= width * (height - 1) and dir == 3) then return id end
	return id + auxi.Manhattan_Distance_(auxi.mul_t(Grid_move_dir[dir],Vector(1,width)))
end

local Gridroom_move_shape_info = {
	[RoomShape.ROOMSHAPE_1x1] = {
		[-1] = 0,
		[1] = 2,
		[-13] = 1,
		[13] = 3,
	},
	[RoomShape.ROOMSHAPE_IH] = {
		[-1] = 0,
		[1] = 2,
		[-13] = true,
		[13] = true,
	},
	[RoomShape.ROOMSHAPE_IV] = {
		[-1] = true,
		[1] = true,
		[-13] = 1,
		[13] = 3,
	},
	[RoomShape.ROOMSHAPE_1x2] = {
		[-1] = 0,
		[1] = 2,
		[-13] = 1,
		[26] = 3,
		[12] = 4,
		[14] = 6,
	},
	[RoomShape.ROOMSHAPE_IIV] = {
		[-1] = true,
		[1] = true,
		[12] = true,
		[14] = true,
		[-13] = 1,
		[26] = 3,
	},
	[RoomShape.ROOMSHAPE_2x1] = {
		[-1] = 0,
		[2] = 2,
		[-13] = 1,
		[13] = 3,
		[-12] = 5,
		[14] = 7,
	},
	[RoomShape.ROOMSHAPE_IIH] = {
		[-1] = 0,
		[2] = 2,
		[-13] = true,
		[13] = true,
		[-12] = true,
		[14] = true,
	},
	[RoomShape.ROOMSHAPE_2x2] = {
		[-1] = 0,
		[12] = 4,
		[2] = 2,
		[15] = 6,
		[-13] = 1,
		[-12] = 5,
		[26] = 3,
		[27] = 7,
	},
	[RoomShape.ROOMSHAPE_LTL] = {
		[-1] = 0,		--1
		[11] = 4,
		[1] = 2,
		[14] = 6,
		[-13] = 5,
		[25] = 3,
		[26] = 7,
	},
	[RoomShape.ROOMSHAPE_LTR] = {
		[-1] = 0,
		[12] = 4,
		[1] = 2,		--5
		[15] = 6,
		[-13] = 1,
		[26] = 3,
		[27] = 7,
	},
	[RoomShape.ROOMSHAPE_LBL] = {
		[-1] = 0,
		[2] = 2,
		[15] = 6,
		[-13] = 1,
		[-12] = 5,
		[13] = 3,		--4
		[27] = 7,
	},
	[RoomShape.ROOMSHAPE_LBR] = {
		[-1] = 0,
		[12] = 4,
		[2] = 2,
		[-13] = 1,
		[-12] = 5,
		[26] = 3,
		[14] = 6,		--7
	},
}

function funct.is_safe_move_in_gridroom(id,tgid)		--检查是否跨越了门
	local level = Game():GetLevel()
	local desc = level:GetRoomByIdx(id)
	if desc and desc.Data then 
		local info = Gridroom_move_shape_info[desc.Data.Shape] or {}
		if info[tgid - desc.SafeGridIndex] == true then return false
		elseif type(info[tgid - desc.SafeGridIndex]) == "number" and desc.Data.Doors & (1<<info[tgid - desc.SafeGridIndex]) == (1<<info[tgid - desc.SafeGridIndex]) then 
			return true
		end
		return false
	end
	return true
end

function funct.is_safe_move_in_grids(id,step)
	local tid = id + step
	if tid < 0 or tid > 168 then return false end
	if step % 13 < 6 and id % 13 > (id + step) % 13 then return false end 
	if step % 13 > 6 and id % 13 < (id + step) % 13 then return false end 
	return true
end

local Gridroom_r_move_shape_info = {
	[RoomShape.ROOMSHAPE_1x1] = {
		[0] = -1,
		[2] = 1,
		[1] = -13,
		[3] = 13,
	},
	[RoomShape.ROOMSHAPE_IH] = {
		[0] = -1,
		[2] = 1,
	},
	[RoomShape.ROOMSHAPE_IV] = {
		[1] = -13,
		[3] = 13,
	},
	[RoomShape.ROOMSHAPE_1x2] = {
		[0] = -1,
		[2] = 1,
		[1] = -13,
		[3] = 26,
		[4] = 12,
		[6] = 14,
	},
	[RoomShape.ROOMSHAPE_IIV] = {
		[1] = -13,
		[3] = 26,
	},
	[RoomShape.ROOMSHAPE_2x1] = {
		[0] = -1,
		[2] = 2,
		[1] = -13,
		[3] = 13,
		[5] = -12,
		[7] = 14,
	},
	[RoomShape.ROOMSHAPE_IIH] = {
		[0] = -1,
		[2] = 2,
	},
	[RoomShape.ROOMSHAPE_2x2] = {
		[0] = -1,
		[4] = 12,
		[2] = 2,
		[6] = 15,
		[1] = -13,
		[5] = -12,
		[3] = 26,
		[7] = 27,
	},
	[RoomShape.ROOMSHAPE_LTL] = {
		[0] = -1,
		[1] = -1,
		[4] = 11,
		[2] = 1,
		[6] = 14,
		[5] = -13,
		[3] = 25,
		[7] = 26,
	},
	[RoomShape.ROOMSHAPE_LTR] = {
		[0] = -1,
		[4] = 12,
		[2] = 1,
		[5] = 1,
		[6] = 15,
		[1] = -13,
		[3] = 26,
		[7] = 27,
	},
	[RoomShape.ROOMSHAPE_LBL] = {
		[0] = -1,
		[2] = 2,
		[6] = 15,
		[1] = -13,
		[5] = -12,
		[3] = 13,
		[4] = 13,
		[7] = 27,
	},
	[RoomShape.ROOMSHAPE_LBR] = {
		[0] = -1,
		[4] = 12,
		[2] = 2,
		[1] = -13,
		[5] = -12,
		[3] = 26,
		[6] = 14,
		[7] = 14,
	},
}
local Gridroom_b_move_shape_info = {
	[RoomShape.ROOMSHAPE_IH] = {
		[1] = -13,
		[3] = 13,
	},
	[RoomShape.ROOMSHAPE_IV] = {
		[0] = -1,
		[2] = 1,
	},
	[RoomShape.ROOMSHAPE_IIV] = {
		[0] = -1,
		[2] = 1,
		[4] = 12,
		[6] = 14,
	},
	[RoomShape.ROOMSHAPE_IIH] = {
		[1] = -13,
		[3] = 13,
		[5] = -12,
		[7] = 14,
	},
}

function funct.get_moves_in_gridroom(tp)
	local ret = auxi.deepCopy(Gridroom_r_move_shape_info[tp] or {})
	return ret
end

function funct.get_banished_moves_in_gridroom(tp)
	local ret = auxi.deepCopy(Gridroom_b_move_shape_info[tp] or {})
	return ret
end

function funct.make_red_room(id)
	local level = Game():GetLevel()
	if level:GetRoomByIdx(id).Data then return false end
	for i = 0,3 do 
		local iid = auxi.move_in_gridroom(id,i)
		if iid ~= id then 
			local ti = auxi.flipdirection(i)
			local desc_ = level:GetRoomByIdx(iid)
			if desc_ and desc_.Data and desc_.SafeGridIndex ~= iid then
				iid = desc_.SafeGridIndex
				ti = Gridroom_move_shape_info[desc_.Data.Shape][id - iid]
			end
			if level:MakeRedRoomDoor(iid,ti) then return true 
			else end	--print("Fail "..tostring(iid).." "..tostring(id).." "..tostring(i))	end
		end
	end
	return nil
end

local Shape_former = {
	[5] = {Y = true,},
	[7] = {X = true,},
	[8] = {X = true,Y = true},
	[9] = {X = true,Y = true},
	[10] = {X = true,Y = true},
	[11] = {X = true,Y = true},
	[12] = {X = true,Y = true},
}

function funct.pos2safegridindex(pos)
	pos = pos or Game():GetPlayer(0).Position
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local desc = level:GetCurrentRoomDesc()
	local dcenter = pos - (room:GetTopLeftPos() + room:GetBottomRightPos()) * 0.5
	local shapeinfo = Shape_former[desc.Data.Shape] or {}
	local ret = desc.GridIndex
	if shapeinfo.X and dcenter.X > 0 then ret = ret + 1 end
	if shapeinfo.Y and dcenter.Y > 0 then ret = ret + 13 end
	return ret
end

function funct.sgid_ctrl_dir(sgid,dir)
	local desc = Game():GetLevel():GetRoomByIdx(sgid)
	if desc and desc.Data then
		local dgid = sgid - desc.GridIndex
		if dgid % 13 == 1 then if dir == 1 or dir == 3 then dir = dir + 4 end end
		if dgid >= 13 then if dir == 0 or dir == 2 then dir = dir + 4 end end
	end
	return dir 
end

--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") auxi.pos2safegridindex()
local Shape_Adder = {
	[RoomShape.ROOMSHAPE_1x2] = {13,},
	[RoomShape.ROOMSHAPE_IIV] = {13,},
	[RoomShape.ROOMSHAPE_2x1] = {1,},
	[RoomShape.ROOMSHAPE_IIH] = {1,},
	[RoomShape.ROOMSHAPE_2x2] = {1,13,14,},
	[RoomShape.ROOMSHAPE_LTL] = {13,12,},
	[RoomShape.ROOMSHAPE_LTR] = {13,14,},
	[RoomShape.ROOMSHAPE_LBL] = {1,14,},
	[RoomShape.ROOMSHAPE_LBR] = {1,13,},
}

function funct.is_suitible_gridindex(id)
	if id > 0 then 
		local level = Game():GetLevel()
		local desc = level:GetRoomByIdx(id)
		if desc and desc.Data then
			if desc.SafeGridIndex == id then return true end
		else return true end
	end
	return false
end

function funct.get_suitible_gridindex(id)
	local level = Game():GetLevel()
	local desc = level:GetRoomByIdx(id)
	if desc and desc.Data then return desc.SafeGridIndex end
	return id
end

function funct.get_all_gridindexs(desc)
	local ret = {}
	local level = Game():GetLevel()
	if type(desc) == "number" then desc = level:GetRoomByIdx(desc) end
	desc = desc or level:GetCurrentRoomDesc()
	table.insert(ret,#ret + 1,desc.SafeGridIndex)
	if desc.Data and desc.SafeGridIndex > 0 then 
		for u,v in pairs(Shape_Adder[desc.Data.Shape] or {}) do 
			local cd = level:GetRoomByIdx(desc.SafeGridIndex + v)
			if cd and auxi.check_for_the_same(cd,desc) then table.insert(ret,#ret + 1,desc.SafeGridIndex + v) end
		end
	end
	return ret
end
--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") auxi.PrintTable(auxi.get_all_gridindexs())

function funct.judge_by_trinket(player,golden)
	local ret = 1
	if golden then ret = ret + 1 end
	if auxi.has_have_coll(player,439) then ret = ret + 1 end
	return ret
end

function funct.would_replace_active(player)
	if auxi.has_have_coll(player,534) and player:GetActiveItem(0) ~= 0 and player:GetActiveItem(1) ~= 0 then return true
	elseif player:GetActiveItem(0) ~= 0 then return true end
	return false
end

function funct.has_zeis()
	local zeis = require("Qing_Remaster_scripts.player.player_Zeis")
	return zeis.get_zeis()
end

local playerOrders = {}
function funct.GetPlayerOrder(player)
    local playerHash = GetPtrHash(player:GetMainTwin())
    if (not playerOrders[playerHash]) then
        local indexes = {}
        local index = 0
        for i = 0, Game():GetNumPlayers() -1 do
            local hash = GetPtrHash(Game():GetPlayer(i):GetMainTwin())
            if (playerHash == hash) then
                playerOrders[playerHash] = index
                break
            end
            if (not indexes[hash]) then
                indexes[hash] = index
                index = index + 1
            end
        end
    end
    return playerOrders[playerHash]
end

function funct.find_in(data,params)
	data = data or Game():GetLevel():GetCurrentRoomDesc().Data
	params = params or {}
	local spawns = data.Spawns
	local sz = spawns.Size
	for i = 1,sz do
		local info = spawns:Get(i - 1)
		local entinfo = info:PickEntry(math.random(1000)/1000)
		if entinfo.Type == (params.Type or params[1] or 999) 
			and entinfo.Variant == (params.Variant or params[2] or enums.Entities.Remover)
			and entinfo.Subtype == (params.SubType or params[3] or 0) then 
			return Game():GetRoom():GetGridPosition((data.Width + 2) * (info.Y + 1) + info.X + 1)
		end
	end
end

function funct.safe_gridindex()
	if auxi.GetDimension() == 2 then return 80 end
	return 84
end
--l local desc = Game():GetLevel():GetCurrentRoomDesc() local idinfo = desc.Data.Spawns:Get(0) print(idinfo.X.." "..idinfo.Y)

function funct.get_near_grid_position(pos)
	return Vector(math.ceil(pos.X/40 - 0.5) * 40,math.ceil(pos.Y/40 - 0.5) * 40)
end

function funct.guass_dis(x,u,u_1)		--x=u时取值为1，x=u+u_1时取值为0.1((x-u)^2=2.3)的高斯分布
	return math.exp(-(x-u)*(x-u)/(u_1 * u_1/2.3))
end

function funct.on_laser_path(laser,pos,params)		--margin是宽度
	local margin = params.margin or 40
	local samples = laser:GetSamples()
	local stpos = laser.Position
	local lspos = stpos
	local ep = params.ep or laser:GetEndPoint()
	local leg = 0
	for i = 0, #samples - 1 do
		local tpos = samples:Get(i)
		if auxi.do_t(tpos - pos,tpos - stpos) <= 0 then
			if (tpos - pos):Length() <= margin then return {leg = leg + (tpos - stpos):Length(),pos = tpos,} end --if (tpos - pos):Length() < (ret - pos):Length() then ret = tpos end end
		elseif auxi.do_t(stpos - pos,stpos - tpos) <= 0 then
			if (stpos - pos):Length() <= margin then return {leg = leg,pos = stpos,} end--if (stpos - pos):Length() < (ret - pos):Length() then ret = stpos end end
		else
			if math.abs(auxi.cros_s(tpos - pos,(stpos - tpos):Normalized())) <= margin then 
				local lg = auxi.do_t(stpos - pos,tpos - stpos)/(tpos - stpos):Length()
				local dpos = stpos + (tpos - stpos):Normalized() * lg
				return {leg = leg + lg,pos = dpos,}
			end
		end
		leg = leg + (tpos - stpos):Length()
		stpos = tpos
	end
	local tpos = ep
	if auxi.do_t(tpos - pos,tpos - stpos) <= 0 then
		if (tpos - pos):Length() <= margin then return {leg = leg + (tpos - stpos):Length(),pos = tpos,} end --if (tpos - pos):Length() < (ret - pos):Length() then ret = tpos end end
	elseif auxi.do_t(stpos - pos,stpos - tpos) <= 0 then
		if (stpos - pos):Length() <= margin then return {leg = leg,pos = stpos,} end--if (stpos - pos):Length() < (ret - pos):Length() then ret = stpos end end
	else
		if math.abs(auxi.cros_s(tpos - pos,(stpos - tpos):Normalized())) <= margin then 
			local lg = auxi.do_t(stpos - pos,tpos - stpos)/(tpos - stpos):Length()
			local dpos = stpos + (tpos - stpos):Normalized() * lg
			return {leg = leg + lg,pos = dpos,}
		end
	end
end

function funct.find_target_on_dir(pos,dir,tgs,params)
	tgs = tgs or auxi.getenemies()
	params = params or {}
	if #tgs == 0 then return {pos = pos + auxi.get_by_rotate(dir,auxi.random_2() * (params.angle or 15),(params.leg or 40) + auxi.random_2() * (params.leg2 or 40)),} end
	local val = 99999
	local tg = nil
	for u,v in pairs(tgs) do
		local v1 = auxi.do_t(dir,v.Position - pos)/(dir:Length())
		if v1 < val then tg = v val = v1 end
	end
	if tg then return {pos = tg.Position,tg = tg,}
	else return {pos = pos + auxi.get_by_rotate(dir,auxi.random_2() * (params.angle or 15),(params.leg or 40) + auxi.random_2() * (params.leg2 or 40)),} end
end

function funct.check_screen_size(v)
	local screensize = auxi.GetScreenSize()
	while(screensize.X > 256) do 
		screensize.X = screensize.X / 2 
		v.X = v.X / 2
	end
	while(screensize.Y > 256) do 
		screensize.Y = screensize.Y / 2 
		v.Y = v.Y / 2
	end
	return v
end

function funct.check_screen_multi(v)
	local screensize = auxi.GetScreenSize()
	while(screensize.X > 256) do 
		screensize.X = screensize.X / 2 
		v.X = v.X * 2
	end
	while(screensize.Y > 256) do 
		screensize.Y = screensize.Y / 2 
		v.Y = v.Y * 2
	end
	return v
end
	
function funct.get_screensize_multi(val)
	local ret = val or 4
	local screensize = auxi.GetScreenSize()
	while(screensize.X > 256) do 
		screensize.X = screensize.X / 2 
		ret = ret / 2
	end 
	return ret
end

function funct.trapezoid_shape(x,params)
	params = params or {}
	params.h1 = params.h1 or 0
	params.h2 = params.h2 or 0
	params.v0 = params.v0 or 0
	params.v1 = params.v1 or 1
	if params.v1 - params.v0 < 0.00001 then params.v1 = params.v0 + 0.0001 end
	if x < params.v0 then return params.h2
	elseif x < params.v1 then return (params.h1 - params.h2) * (params.v1 - x)/(params.v1 - params.v0) + params.h2
	elseif x < params.v2 then return params.h2
	elseif x < params.v3 then return (params.h2 - params.h1) * (params.v3 - x)/(params.v3 - params.v2) + params.h1
	else return params.h2 end
	return 
end

function funct.random_glaze_pickup(params)
	local info = "Glaze_chest"
	local wei = 0
	for u,v in pairs(enums.Pickups) do wei = wei + (params[u] or v.wei) end
	if params.rng then wei = params.rng:RandomInt(wei) else wei = math.random(wei) - 1 end
	for u,v in pairs(enums.Pickups) do
		wei = wei - (params[u] or v.wei)
		if wei <= 0 then
			info = u
			if u == "Glaze_bomb" and auxi.has_poop_player() then info = "Glaze_big_poop" end
			break
		end
	end
	return enums.Pickups[info]
end

function funct.inner_tick_(data,key,limit,params)
	data["QING_SPECIAL_Inner_tick"] = data["QING_SPECIAL_Inner_tick"] or {} local d = data["QING_SPECIAL_Inner_tick"]
	params = params or {}
	d[key] = d[key] or 0 
	if params.set then auxi.check_if_any(params.set_val or function(d,key) d[key] = 0 end,d,key) return 0 end
	if params.Update then d[key] = d[key] + 1 end
	if d[key] > limit then if params.Update then d[key] = 0 end return limit + 1
	else return d[key] end
end

function funct.inner_tick(data,key,limit,params)		--正数达到N后触发并清零
	local ret = funct.inner_tick_(data,key,limit,params)
	params = params or {}
	if params.Val then if params.WithZero and ret == limit + 1 then ret = 0 end return ret 
	else if ret > limit then return true else return false end end
end

function funct.inner_count(data,key,params)				--倒数达到0后持续触发
	data["QING_SPECIAL_Inner_count"] = data["QING_SPECIAL_Inner_count"] or {} local d = data["QING_SPECIAL_Inner_count"]
	params = params or {}
	if params.Set and type(params.Set) == "number" then d[key] = params.Set end
	if d[key] == nil then return true end
	if params.Update then d[key] = d[key] - 1 end
	if d[key] <= 0 then return true
	else return false end
end

function funct.screentop2pos(pos)
	return auxi.myScreenToWorld(Vector((Isaac.WorldToScreen(pos) - Game():GetRoom():GetRenderScrollOffset() - Game().ScreenShakeOffset).X,0))
end

function funct.dichotomy_search(f,lwbd,upbd,params)		--二分搜索，必须是FFFFFTTTTT的情况
	params = params or {}
	if f(lwbd,params) ~= false then return lwbd elseif f(upbd,params) ~= true then return upbd end
	while(upbd - lwbd > (params.epsl or 0.1)) do
		local mid = (upbd + lwbd) * 0.5
		if f(mid,params) then upbd = mid
		else lwbd = mid end
	end
	return lwbd
end

function funct.get_mx_pair(tbl,params)
	local mxid = nil local mxval = nil
	for u,v in pairs(tbl) do
		if (mxval == nil) or (v > mxval) then mxid = u mxval = v end
	end
	return mxid,mxval
end

function funct.apply_friction(vel,val)
	return vel:Normalized() * (math.max(0,vel:Length() - val))
end

function funct.vec2dangle(v1,v2)			--计算2个vector的夹角（返回0-180）
	return math.acos(auxi.do_t(v1,v2)/v1:Length()/v2:Length()) * 180/3.1415926
end

function funct.draw_scan(f,tg,value)		--遍历迭代器
	for u,v in pairs(tg) do	value = auxi.check_if_any(f,v,value,u) or value end
	return value
end

function funct.find_suitable_pos_list(a_list,b_list)
	local banish_list = auxi.get_player_positions()
	for u,v in pairs(b_list) do table.insert(banish_list,v) end
	local tbl = {}
	local tbl2 = {}
	local tbl3 = {}
	for uu,vv in pairs(a_list) do
		local val = 7
		for u,v in pairs(banish_list) do
			if (v - vv):Length() > 400 or (v - vv):Length() < 180 then 
				val = val & 3
				if (v - vv):Length() < 120 then 
					val = val & 1
					if (v - vv):Length() < 60 then 
						val = 0 
					end
				end
			end
		end
		if (val & 4) == 4 then table.insert(tbl3,vv) end
		if (val & 2) == 2 then table.insert(tbl2,vv) end
		if (val & 1) == 1 then table.insert(tbl,vv) end
	end
	if #tbl3 > 0 then return tbl3
	elseif #tbl2 > 0 then return tbl2
	elseif #tbl > 0 then return tbl
	else return a_list end
end

function funct.calculate_height_base_on_rate(rate,height)		--按抛物线最高点和进程占比计算抛物线的高度
	local v1 = math.abs(0.5 - rate)
	return height * (1 - 4 * v1 * v1)
end

function funct.safely_init(ent)		--修复生成特效
	ent:AddEntityFlags(EntityFlag.FLAG_AMBUSH)
    ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	return ent
end

function auxi.GetMinWallDistance(pos)
    local room = Game():GetRoom()
    local gridIndex = room:GetGridIndex(pos)
    local x = gridIndex % room:GetGridWidth()
    local y = math.floor(gridIndex / room:GetGridWidth())
    return math.min(
        x,                          -- 左墙距离
        room:GetGridWidth() - x - 1, -- 右墙距离 
        y,                          -- 上墙距离
        room:GetGridHeight() - y - 1 -- 下墙距离
    )
end

-- 预加载：运行时懒 require 在 MCM 中文包装 require 后会报 module not found
attack_list_calculator = require("Qing_Remaster_scripts.player.attack_list_calculator")

return funct
