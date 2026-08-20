local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local grid_wall = require("Qing_Remaster_scripts.grids.grid_wall")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")

local function make_dirs_from_info(ent,info,dirs)
	dirs = dirs or 4
	info = info or {}
	local rnd = math.random(dirs)
	local s = ent:GetSprite()
	if (info.Flip or {})[rnd] then s.FlipX = true else s.FlipX = false end
	if info.Anims then s:Play(info.Anims[rnd],true) end
	if info.OverlayAnims and info.OverlayAnims ~= "" then s:PlayOverlay(info.OverlayAnims[rnd],true) end
	if info.I1 then ent.I1 = info.I1[rnd] or 0 end
	if info.I2 then ent.I2 = info.I2[rnd] or 0 end
	if info.V1 then ent.V1 = info.V1[rnd] or Vector(0,0) end
	if info.V2 then ent.V2 = info.V2[rnd] or Vector(0,0) end
	if info.Target then ent.TargetPosition = info.Target[rnd] or ent.TargetPosition end
end

local function make_4_dirs_from_info(ent,info) make_dirs_from_info(ent,info,4) end

local item = {
	pre_ToCall = {},
	ToCall = {},
	Post_ToCall = {},
	orig_col = Color(0.5,0,0.5,1,0.2,0,0.2),
	trans_col = Color(0.5,0,0.5,1,0.2,0,0.2),
	entity = enums.Entities.Shadow_Linker,
	own_key = "Level_Shadoll_",
	ignorer = {
		[865] = function(ent) if ent.Variant == 10 then return true end end,
	},
	Morphers = {
		[18] = {{Type = 18,sprite = "monster_010_fly",},},
		[24] = {{Type = 24,
		sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "monster_161_globin",[0] = "monster_161_globin_body",},},},
		[33] = {{Type = 33,Variant = 11,sprites = {[1] = "818.002_coalspider",[0] = "818.002_coal",},},},
		[96] = {{Type = 96,sprite = "monster_010_eternalfly",},},
		[818] = {{Type = 818,sprite = "818.000_rockspider",},
				{Type = 818,Variant = 2,sprite = "818.002_coalspider",},},
		[819] = {{Type = 819,sprite = "819.000_flybomb",},},
		[835] = {{Type = 835,Variant = 10,Tail = true,
		sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "peeper_fatty_cord",[0] = "peeper_fatty_eye",},},},
	},
	weigh_table = {
		[1] = {
			{id = 1,weigh = 25,},
			{id = 2,weigh = 5,},
			{id = 3,weigh = 20,},
			{id = 4,weigh = 5,},
			{id = 5,weigh = 3,},
			{id = 6,weigh = 1,},
		},
	},
	weigh_list = {
		
	},
	floater = Vector(0,-200),
	thrower = {
		{		--最菜的单发/自机狙
			{Type = 12,sprite = "monster_029_horf",},
			{Type = 14,Variant = 0,State = 8,Anim = "Attack",sprite = "monster_001_pooter",},
			{Type = 26,Variant = 0,State = 8,Anim = "Shoot",sprite = "monster_141_maw",},
			{Type = 26,Variant = 2,State = 8,Anim = "Shoot",sprite = "monster_144_psychicmaw",},
			{Type = 38,Variant = 0,State = 4,Anim = "Attack",work = function(ent) ent.V1 = Vector(0,0) end,sprite = "monster_155_baby",},
			----5----
			{Type = 31,State = 9,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"Attack Hori","Attack Hori","Attack Down","Attack Up",},Flip = {[1] = true,},I1 = {[3] = 2,[4] = 1,},sprite = "monster_115_spitty",},
			{Type = 227,Variant = 0,State = 8,work = function(ent,info) make_4_dirs_from_info(ent,info) end,		--!!Dir
			Anims = {"AttackHori","AttackHori","AttackUp","AttackDown",},Flip = {[1] = true,},
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "monster_227_boney head",[0] = "monster_227_boney body",},},
			{Type = 243,Variant = 0,State = 9,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"Attack Hori","Attack Hori","Attack Down","Attack Down",},Flip = {[1] = true,},I1 = {[3] = 2,[4] = 1,},sprite = "monster_243_conjoined spitty",},
			{Type = 244,Variant = 0,State = 8,Anim = "DigOut",sprite = "monster_244_roundworm",},
			{Type = 248,Variant = 0,Check_Anim = true,Anim = "Attack",sprite = "monster_248_psychic horf",},
			----10----
			{Type = 259,Variant = 0,State = 8,Anim = "Attack",Delay = 30,Counter = 45,sprite = "259.000_imp",},
			{Type = 277,Variant = 0,State = 8,work = function(ent,info) make_4_dirs_from_info(ent,info) end,		--!!Dir
			Anims = {"AttackHori","AttackHori","AttackUp","AttackDown",},Flip = {[1] = true,},
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "277.000_blackboney head",[0] = "277.000_blackboney body",},},
			{Type = 284,Variant = 0,State = 8,OverlayAnim = "Attack",Counter = -1,
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "280.000_cyclopia",[0] = "monster_000_bodies01",},},
			{Type = 308,Variant = 0,State = 8,Anim = "Attack",check = function(ent,info) if ent.State ~= info.State and ent.HitPoints > 1 then return true end end,sprite = "fistuloid",},
			{Type = 808,Variant = 0,State = 8,Anim = "Attack",sprite = "808.000_willo",},
			----15----
			{Type = 838,Variant = 0,State = 8,Anim = "Attack",
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "lv2_willo",[0] = "lv2_willo",[2] = "lv2_willo",[3] = "lv2_willo_glow",},},
			{Type = 890,Variant = 0,SubType = {0,1,},State = 8,work = function(ent,info) make_4_dirs_from_info(ent,info) end,		--!!Dir
			sprite = function(ent,info,id) if ent.SubType == 0 then return info.sprites1[id] or info.sprites1[0] else return info.sprites2[id] or info.sprites2[0] end end,sprites1 = {[1] = "maze_roamers",[0] = "maze_roamers_body",},sprites2 = {[1] = "maze_roamers",[0] = "maze_roamers_body",},
			Anims = {"AttackLeft2","AttackRight2","AttackDown2","AttackUp2",},Counter = 0,I1 = {0,2,3,1,},},
			{Type = 841,Variant = 0,State = 8,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			OverlayAnims = {"AttackStartHori","AttackStartHori","AttackStartUp","AttackStartDown",},Flip = {[1] = true,},
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[2] = "841.000_revenant",[1] = "841.000_revenant",[0] = "841.000_revenant_body",},},
			{Type = 828,Variant = 0,State = 8,Anim = "Attack",TargetPosition = function() local room = Game():GetRoom() return room:FindFreeTilePosition(room:GetRandomPosition(10),10) end,sprite = "necro",},
		},
		{		--爆炸物
			{Type = 87,Variant = 0,State = 8,Anim = "Attack",			--!!Color
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "monster_028_gurgle",[0] = "monster_000_bodies02",},FlipX = true,},
			{Type = 88,Variant = 1,State = 8,Anim = "Shoot",			--!!Color
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "monster_089_gut",[0] = "monster_000_bodies01",},},
			{Type = 244,Variant = 3,State = 8,Anim = "DigOut",sprite = "tube_worm",},
			{Type = 257,Variant = 1,State = 8,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"AttackHori","AttackHori","AttackVert","AttackVert",},sprite = "257.001_blueconjoinedfatty",},
			{Type = 276,Variant = 0,State = 8,Anim = "DigOut",sprite = "276.000_roundy",},
			----5----
		},
		{		--多发封走位
			{Type = 14,Variant = 1,State = 8,Anim = "Attack",sprite = "monster_007_superpooter",},
			{Type = 27,Variant = 0,State = 8,Anim = "Shoot",sprite = "monster_122_host",},
			{Type = 39,Variant = 2,State = 10,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"Attack03Horiz","Attack03Horiz","Attack03Down","Attack03Up",},Flip = {[1] = true,},V1 = {[1] = Vector(-1,0),[2] = Vector(1,0),[3] = Vector(0,1),[4] = Vector(0,-1),},sprite = "monster_181_chubber",},
			{Type = 56,Variant = 0,State = 8,Anim = "Spit",sprite = "monster_198_lump",},
			{Type = 86,Variant = 0,State = 8,Anim = "ShootDown",sprite = "monster_152_keeper",},
			----5----
			{Type = 88,Variant = 0,State = 8,Anim = "Shoot",		--!!Color
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "monster_087_boil",[0] = "monster_000_bodies01",},},
			{Type = 90,Variant = 0,State = 8,Anim = "AttackHead04",sprite = "monster_183_hanger",},
			{Type = 204,Variant = 0,State = 8,
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "204.001_mobile host head",[0] = "monster_000_bodies01",},},
			{Type = 219,Variant = 0,State = 8,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"ShootLeft","ShootRight","ShootDown","ShootUp",},I1 = {0,2,3,1,},TargetPosition = function(ent) return ent.Position + 40 * auxi.GetDirVec(ent.I1) end,
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "others/shadow",[0] = "monster_219_wizoob",},},
			{Type = 247,Variant = 0,State = 8,		--!!Color
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "monster_247_flesh mobile host",[0] = "monster_000_bodies01",},},
			----10----
			{Type = 257,Variant = 0,State = 8,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"AttackHori","AttackHori","AttackVert","AttackVert",},sprite = "257.000_conjoinedfatty",},
			{Type = 305,Variant = 0,State = 8,Anim = "Attack",sprite = "monster_305_ministro",},
			{Type = 307,Variant = 0,State = 8,Anim = "Attack",sprite = "tar_boy",},
			{Type = 829,Variant = 0,State = 8,Anim = "Shoot",sprite = "829.000_mole",Force = true,},
			{Type = 834,Variant = 0,State = 8,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"AttackHori","AttackHori","AttackUp","AttackDown",},OverlayAnims = {"HeadLaughRight","HeadLaughRight","HeadLaughUp","HeadLaughDown",},Flip = {[1] = true,},I1 = {0,2,3,1,},
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "834.000_whipper_head",[0] = "834.000_whipper_body",},},
			----15----
			{Type = 859,Variant = 0,State = 8,Anim = "Shoot",sprite = "859.000_floatinghost",},
			{Type = 879,Variant = 0,State = 8,work = function(ent,info) make_dirs_from_info(ent,info,8) end,
			Anims = {"AttackDown","AttackDownRight","AttackRight","AttackUpRight","AttackUp","AttackUpRight","AttackRight","AttackDownRight",},Flip = {true,true,true,true,},I2 = {2,3,4,5,6,7,0,1,},sprite = "bloaty",},
			{Type = 883,Variant = 0,State = 8,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"AttackRight","AttackRight","AttackDown","AttackUp",},Flip = {[1] = true,},Target = {[1] = Vector(-1,0),[2] = Vector(1,0),[3] = Vector(0,1),[4] = Vector(0,-1),},i1 = 0,sprite = "baby_begotten",},
			{Type = 38,Variant = 1,State = 4,Anim = "Attack",work = function(ent) ent.V1 = Vector(0,0) end,sprite = "monster_157_angelicbaby",},
			--{Type = 59,Variant = 0,State = 6,Anim = "JumpDownHead",TargetPosition = function(ent) return ent.Position end,},		--Pos
			{Type = 244,Variant = 1,State = 8,Anim = "DigOut",sprite = "tubeworm",},
			----20----
			{Type = 27,Variant = 1,State = 8,Anim = "Shoot",sprite = "monster_127_redhost",},
			{Type = 207,Variant = 1,State = 8,Anim = "Attack",sprite = "monster_206_crazy long legs_small",},
			{Type = 820,Variant = 0,State = 8,Anim = "Attack",		--!!Projectile
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "820.000_danny",[0] = "820.000_danny_body",},},
			{Type = 832,Variant = 1,State = 8,OverlayAnim = "Attack",
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[2] = "monster_144_psychicmaw",[1] = "832.001_fanatic",[0] = "832.000_exorcist_body",},},
			{Type = 255,Variant = 0,State = 8,Anim = "DigOut",sprite = "monster_255_nightcrawler",},
		},
		{		--整行直线/跟踪直线
			{Type = 39,Variant = 0,State = 9,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"Attack01Horiz","Attack01Horiz","Attack01Down","Attack01Up",},Flip = {[1] = true,},V1 = {[1] = Vector(-1,0),[2] = Vector(1,0),[3] = Vector(0,1),[4] = Vector(0,-1),},sprite = "vis",},
			{Type = 39,Variant = 1,State = 9,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"Attack02Horiz","Attack02Horiz","Attack02Down","Attack02Up",},Flip = {[1] = true,},V1 = {[1] = Vector(-1,0),[2] = Vector(1,0),[3] = Vector(0,1),[4] = Vector(0,-1),},sprite = "doublevis",},
			{Type = 285,Variant = 0,State = 8,work = function(ent,info) make_4_dirs_from_info(ent,info) end,		--!!Color
			Anims = {"ShootLeft","ShootRight","ShootDown","ShootUp",},I1 = {0,2,3,1,},TargetPosition = function(ent) return ent.Position + 40 * auxi.GetDirVec(ent.I1) end,sprite = "285.000_redghost",},
			{Type = 834,Variant = 1,State = 8,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"AttackHori","AttackHori","AttackDown","AttackUp",},OverlayAnims = {"HeadLaughRight","HeadLaughRight","HeadLaughDown","HeadLaughUp",},Flip = {[1] = true,},I1 = {0,2,1,3,},
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "834.001_snapper_head",[0] = "834.001_snapper_body",},},
			{Type = 836,Variant = 0,State = 9,work = function(ent,info) make_4_dirs_from_info(ent,info) end,		--!!Target
			Anims = {"Attack01Horiz","Attack01Horiz","Attack01Down","Attack01Up",},Flip = {[1] = true,},V1 = {[1] = Vector(-1,0),[2] = Vector(1,0),[3] = Vector(0,1),[4] = Vector(0,-1),},TargetPosition = function(ent) return auxi.get_acceptible_target(ent).Position end,sprite = "836.000_visversa",},
			----5----
			{Type = 885,Variant = 1,State = 8,Anim = "Attack",FlipX = true,sprite = "red_cultist",},
			{Type = 230,Variant = 0,check = function(ent,info) if info.Anims[ent:GetSprite():GetAnimation()] ~= true then return true end end,Anims = {["ShootDown"] = true,["ShootUp"] = true,},
			Anim = "ShootDown",FlipX = true,TargetPosition = function(ent) return auxi.get_acceptible_target(ent).Position - ent.Position end,sprite = "monster_230_camillojr",},
			{Type = 60,Variant = 0,State = 8,Anim = "Shoot",v1 = function(ent) return Vector((auxi.get_acceptible_target(ent).Position - ent.Position):GetAngleDegrees(),0) end,sprite = "monster_194_eye",},
			{Type = 60,Variant = 1,State = 8,OverlayAnim = "ShootOverlay",v1 = function(ent) return Vector((auxi.get_acceptible_target(ent).Position - ent.Position):GetAngleDegrees(),0) end,sprite = "monster_201_brimstoneeye",},
			{Type = 87,Variant = 1,State = 8,Anim = "Attack",
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[3] = "crackle",[2] = "crackle",[1] = "crackle",[0] = "crackle_body",},},
			----10----
			{Type = 31,Variant = 1,State = 9,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"Attack Hori","Attack Hori","Attack Down","Attack Up",},Flip = {[1] = true,},I1 = {[3] = 2,[4] = 1,},sprite = "spitty",},
		},
		{		--多向强者
			{Type = 39,Variant = 3,State = 9,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"Attack04Horiz","Attack04Horiz","Attack04Down","Attack04Up",},Flip = {[1] = true,},V1 = {[1] = Vector(-1,0),[2] = Vector(1,0),[3] = Vector(0,1),[4] = Vector(0,-1),},sprite = "039.003_scarreddoublevis",},
			{Type = 57,Variant = 0,State = 8,Anim = "Attack",sprite = "monster_170_mamaguts",},		--会分裂
			{Type = 57,Variant = 1,State = 8,Anim = "Attack",sprite = "monster_160_membrain",},		--会分裂
			{Type = 57,Variant = 2,State = 8,Anim = "Attack",sprite = "dead_meat",},		--会分裂
			{Type = 208,Variant = 1,State = 8,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"AttackHori","AttackHori","AttackVert","AttackVert",},sprite = "monster_207_fatty_pale",},
			----5----
			{Type = 210,Variant = 0,check = function(ent,info) if ent.ProjectileCooldown > 10 then return true end end,Counter = 10,sprite = "monster_209_blubber",},
			{Type = 237,Variant = 0,State = 3,Anim = "Stop",
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "monster_237_gurgling",[0] = "monster_237_gurgling hands",},},
			{Type = 60,Variant = 2,State = 8,Anim = "Attack",
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[4] = "others/CrackTheSky_lighting",[3] = "others/CrackTheSky_lighting",[2] = "holy eye",[1] = "holy eye",[0] = "holy eye",},},
			{Type = 258,Variant = 0,State = 8,Anim = "Shooting",sprite = "258.000_fat bat",},			--!!Delay
			{Type = 246,Variant = 0,State = 8,Anim = "Appear",sprite = "monster_246_ragling",},		--!!Delay		--!!Variant = 1
			----10----
			{Type = 300,Variant = 0,State = 8,Anim = "Revealed",i1 = function() return auxi.choose(0,1) end,sprite = "monster_300_mushroomman",},
			{Type = 823,Variant = 0,State = 8,Anim = "Jump",TargetPosition = Vector(0,0),sprite = "823.000_quakey",},
			{Type = 827,Variant = 0,State = 8,v1 = Vector(3,0),
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "827.000_faceless",[0] = "monster_000_bodies02",},},
			{Type = 835,Variant = 0,State = 8,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"AttackLeft","AttackRight","AttackVert","AttackVert",},sprite = "peeper_fatty",},
			{Type = 841,Variant = 1,State = 8,OverlayAnim = "AttackStart",
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[2] = "quad_revenant",[1] = "quad_revenant",[0] = "841.000_revenant_body",},},
			----15----
			{Type = 891,Variant = 1,State = 9,Anim = "Attack2",
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "black_goat",[0] = "black_goat_body",},},
			{Type = 892,Variant = 0,State = 8,Anim = function(ent) local str = ent:GetSprite():GetAnimation() local id = string.sub(str,string.len(str),string.len(str)) if tostring(id) then else id = "0" end return "Attack"..id end,sprite = "poofer",},
			{Type = 229,Variant = 0,Check_Anim = true,Anim = "ShootDown",sprite = "monster_229_tumor",},
			{Type = 15,Variant = 0,State = 8,Anim = "Attack",work = function(ent) ent.V1 = Vector(30,0) end,sprite = "monster_065_clotty",},
			{Type = 92,Variant = 0,State = 8,Anim = "HeartAttack",sprite = "monster_187_maskandheart",},
			----20----
			{Type = 92,Variant = 1,SubType = {0,1,},State = 8,Anim = "HeartAttack",sprite = "mask_and_halfhearts",},
			{Type = 207,Variant = 0,State = 8,Anim = "Attack",sprite = "monster_206_crazy long legs",},
			{Type = 806,Variant = 0,State = 8,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"AttackHori","AttackHori","AttackVert","AttackVert",},Flip = {[1] = true,},sprite = "806.000_bubbles",},
			{Type = 872,Variant = 0,State = 8,Anim = "Attack",v1 = Vector(30,0),sprite = "residuum",},
			{Type = 15,Variant = 1,State = 8,Anim = "Attack",work = function(ent) ent.V1 = Vector(30,0) end,sprite = "monster_071_clot",},
			----25----
			{Type = 15,Variant = 2,State = 8,Anim = "Attack",work = function(ent) ent.V1 = Vector(30,0) end,sprite = "monster_075_lblob",},
			{Type = 15,Variant = 3,State = 8,Anim = "Attack",work = function(ent) ent.V1 = Vector(30,0) end,
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "others/effect_005_fire",[0] = "015.100_grilledclotty",},},
			{Type = 29,Variant = 3,State = 4,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"Hop","Hop2","Hop","Hop2",},I1 = {[2] = 1,[3] = 2,[4] = 3,},
			TargetPosition = function(ent) return ent.Position end,sprite = "hopper",},
			{Type = 827,Variant = 1,State = 8,v1 = Vector(3,0),sprite = "faceless",},
		},
		--------5---------
		{		--强力的神仙敌人
			{Type = 282,Variant = 0,State = 8,Anim = "Attack",v1 = Vector(30,0),sprite = "282.000_megaclotty",},		--!!Spawner
			{Type = 829,Variant = 1,State = 8,Anim = "Shoot",i2 = 0,Force = true,
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "mole_dirt",[0] = "mole",},},
			{Type = 885,Variant = 0,State = 8,Anim = "Attack",sprite = "purple_cultist",},
			{Type = 857,Variant = 0,Spilt = {
					{Type = 857,Variant = 0,State = 8,Anim = "Attack1",FlipX = true,},
					{Type = 857,Variant = 0,State = 9,Anim = "Attack2",MoveStep = 200,},
				},
				sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,
				sprites = {[1] = "others/shadow",[0] = "857.000_cohort",},
			},
			{Type = 14,Variant = 2,State = 8,Anim = "Attack",sprite = "pooter",},
			----5----
			{Type = 227,Variant = 1,State = 8,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"AttackLeft","AttackRight","AttackUp","AttackDown",},TargetPosition = function(ent) return ent.Position + 40 * auxi.GetDirVec(ent.I1) end,
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[2] = "others/Costume_072_Wafer",[1] = "holy_bony",[0] = "holy_bony_body",},},
			{Type = 820,Variant = 1,State = 8,Anim = "Attack",
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "820.001_coalboy",[0] = "820.001_coalboy_body",},},
			{Type = 821,Variant = 0,State = 8,Anim = "Attack",
			sprite = function(ent,info,id) return info.sprites[id] or info.sprites[0] end,sprites = {[1] = "821.000_blaster",[0] = "821.000_blaster_body",},},
			{Type = 830,Variant = 0,State = 8,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"AttackHori","AttackHori","AttackVert","AttackVert",},Counter = 0,sprite = "830.000_big_bony",},
			{Type = 888,Variant = 0,Spilt = {
					{Type = 888,Variant = 0,State = 9,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
					Anims = {"AttackHori","AttackHori","AttackVert","AttackVert",},Counter = 0,weigh = 2,},
					{Type = 888,Variant = 0,State = 8,Anim = "Jump",Counter = 0,Lev = 5,MoveStep = 200,weigh = 1,},
				},
				sprite = "shady",
			},
			----10----
		},
		{		--小Boss
			{Type = 46,Variant = 0,State = 9,Anim = "Attack",},
			{Type = 46,Variant = 1,State = 9,Anim = "Attack",},
			{Type = 48,Variant = 0,State = 9,Anim = "Attack",work = function(ent,info) make_4_dirs_from_info(ent,info) end,V2 = {[1] = Vector(-1,0),[2] = Vector(1,0),[3] = Vector(0,1),[4] = Vector(0,-1),},},
			{Type = 48,Variant = 1,State = 9,Anim = "Attack",work = function(ent,info) make_4_dirs_from_info(ent,info) end,V2 = {[1] = Vector(-1,0),[2] = Vector(1,0),[3] = Vector(0,1),[4] = Vector(0,-1),},},
			{Type = 49,Variant = 0,State = 9,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"Attack01Horiz","Attack01Horiz","Attack01Down","Attack01Up",},Flip = {[1] = true,},V1 = {[1] = Vector(-1,0),[2] = Vector(1,0),[3] = Vector(0,1),[4] = Vector(0,-1),},},
			----5----
			{Type = 49,Variant = 1,State = 9,work = function(ent,info) make_4_dirs_from_info(ent,info) end,		--/8
			Anims = {"Attack02Horiz","Attack02Horiz","Attack02Down","Attack02Up",},Flip = {[1] = true,},V1 = {[1] = Vector(-1,0),[2] = Vector(1,0),[3] = Vector(0,1),[4] = Vector(0,-1),},},
			{Type = 50,Variant = 0,State = 8,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"Attack01Horiz","Attack01Horiz","Attack01Down","Attack01Up",},Flip = {[1] = true,},V1 = {[1] = Vector(-10,0),[2] = Vector(10,0),[3] = Vector(0,10),[4] = Vector(0,-10),},},
			{Type = 50,Variant = 1,State = 8,work = function(ent,info) make_4_dirs_from_info(ent,info) end,
			Anims = {"Attack01Horiz","Attack01Horiz","Attack01Down","Attack01Up",},Flip = {[1] = true,},V1 = {[1] = Vector(-10,0),[2] = Vector(10,0),[3] = Vector(0,10),[4] = Vector(0,-10),},},
			{Type = 52,Variant = 0,State = 8,Anim = "Attack01",},		--/9
			{Type = 52,Variant = 1,State = 8,Anim = "Attack01",},
			----10----
		},
		{		--Boss
			{Type = 20,Variant = 0,State = 8,Anim = "Taunt",FlipX = true,},		--可能会生成2只
			{Type = 43,Variant = 0,State = 8,Anim = "Taunt",FlipX = true,},
			--{Type = 43,Variant = 0,State = 7,Anim = "JumpDown",TargetPosition = function(ent) return ent.Position end,MoveStep = 0,Move = function() return {Level = 8,subtype = 3,}},
			{Type = 43,Variant = 1,State = 8,Anim = "Taunt",FlipX = true,},
			{Type = 63,Variant = 0,SubType = 1,State = 13,Anim = "Attack1",Move = function(ent) if ent.State == 9 then return {{8,5,},} end end,},
			{Type = 63,Variant = 0,SubType = {0,1,},State = 9,Anim = "HeadAttack",OverlayAnim = "Blood",Check_Anim = true,},
			
			{Type = 64,Variant = 0,SubType = {0,1,},State = 8,Anim = "Attack1",},
			--{Type = 64,Variant = 0,SubType = {0,1,},State = 13,Anim = "HeadlessAttack2",},
			{Type = 65,Variant = 0,SubType = {0,1,},State = 8,Anim = "Attack1",Check_Anim = true,Move = function(ent) if ent:GetSprite():GetAnimation() == "Cry" then return {{8,8,},} end end,},
			{Type = 65,Variant = 10,SubType = 1,State = 8,Anim = "Cry",Check_Anim = true,},
			{Type = 65,Variant = 1,SubType = 0,State = 8,Anim = "Attack1",},
			{Type = 66,Variant = 0,SubType = {0,1,},Spilt = {
					{Type = 66,Variant = 0,SubType = 0,State = 8,Anim = "Attack02",MoveStep = 0,weigh = 2,Move = function(ent) if ent.State == 6 then return "End" end end,},
					{Type = 66,Variant = 0,SubType = 0,State = 13,Anim = "Attack01",weigh = 3,Move = function(ent) if ent.State == 6 then return "End" end end,},
					{Type = 66,Variant = 0,SubType = 0,State = 14,Anim = "Attack04",weigh = 3,Move = function(ent) if ent.State == 6 then return "End" end end,},
				},
			},
			
			{Type = 66,Variant = 0,SubType = {0,1,},Spilt = {
					{Type = 66,Variant = 0,SubType = 1,State = 8,Anim = "Attack02",MoveStep = 0,weigh = 2,Move = function(ent) if ent.State == 6 then return "End" end end,},
					{Type = 66,Variant = 0,SubType = 1,State = 14,Anim = "Attack04",weigh = 3,Move = function(ent) if ent.State == 6 then return "End" end end,},
				},
			},
			{Type = 67,Variant = 0,SubType = 1,State = 8,Anim = "Attack03",},
			{Type = 67,Variant = 1,SubType = {0,1,2,},Spilt = {
					{Type = 67,Variant = 1,SubType = {0,1,2,},State = 14,Anim = "Attack02",},
					{Type = 67,Variant = 1,SubType = {0,1,2,},State = 8,Anim = "Attack03",},
				},
			},
			{Type = 68,Variant = 0,SubType = {0,1,2,},State = 8,Anim = "Attack01",},
			{Type = 69,Variant = 0,SubType = 0,Spilt = {
					{Type = 69,Variant = {0,1,},SubType = 0,State = 9,Anim = "Attack03",},
					{Type = 69,Variant = {0,1,},SubType = 0,State = 10,Anim = "Attack01",},
				},
			},
			{Type = 69,Variant = 1,SubType = 0,Spilt = {		--!!
					{Type = 69,Variant = {0,1,},SubType = 0,State = 9,Anim = "Attack03",},
					{Type = 69,Variant = {0,1,},SubType = 0,State = 10,Anim = "Attack01",},
				},
			},
			
			{Type = 74,Variant = 0,SubType = 0,State = 8,Anim = "Attack",},
			{Type = 75,Variant = 0,SubType = 0,State = 8,Anim = "Attack",},
			{Type = 76,Variant = 0,SubType = 0,State = 8,Anim = "Attack",},
			--{Type = 78,Variant = {0,1,},SubType = 0,State = 3,Anim = "HeartBeat1",},
			{Type = 81,Variant = 0,SubType = 0,Spilt = {
					{Type = 81,Variant = 0,SubType = 0,State = 8,Anim = "Attack1",},
					{Type = 81,Variant = 0,SubType = 0,State = 10,Anim = "Attack2",},
				},
			},
			
		},
		--{Type = 38,Variant = 2,State = 8,},
		--20/8
		--237
		--238
		--240-242
		--253
		--260.10
		--289
		--290
		--850
		--886
	},
	target_info = {		--只控制强制转移的敌人
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
	},
	room_info = {
		[RoomShape.ROOMSHAPE_1x1] = 4,
		[RoomShape.ROOMSHAPE_IH] = 2,
		[RoomShape.ROOMSHAPE_IV] = 2,
		[RoomShape.ROOMSHAPE_1x2] = 6,
		[RoomShape.ROOMSHAPE_IIV] = 4,
		[RoomShape.ROOMSHAPE_2x1] = 6,
		[RoomShape.ROOMSHAPE_IIH] = 4,
		[RoomShape.ROOMSHAPE_2x2] = 10,
		[RoomShape.ROOMSHAPE_LTL] = 6,
		[RoomShape.ROOMSHAPE_LTR] = 6,
		[RoomShape.ROOMSHAPE_LBL] = 6,
		[RoomShape.ROOMSHAPE_LBR] = 6,
	},
}

function item.is_shadow() return save.elses.shadoll_level == 1 end

if true then
	for u_,v_ in pairs(item.thrower) do	
		for u,v in pairs(v_) do
			item.Morphers[v.Type] = item.Morphers[v.Type] or {}
			table.insert(item.Morphers[v.Type],#item.Morphers[v.Type] + 1,v)
		end
	end
end
--l local n_entity = Isaac.GetRoomEntities() for u,v in pairs(n_entity) do if v.Type == 208 then v:ToNPC().State = 8 end end
--l local shadoll = require("Qing_Remaster_scripts.level.Level_Shaddoll") shadoll.spawn_shadow(1,1)
--l local shadoll = require("Qing_Remaster_scripts.level.Level_Shaddoll") shadoll.spawn_random_shadow(Vector(200,200))
--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") local tbl = {{weigh = 1,},{weigh = 3},} print(auxi.random_in_weighed_table(tbl).weigh)
local function render_shadow(ent)
	if ent == nil or ent:GetSprite() == nil or ent:GetData() == nil then return end
	local d = ent:GetData()
	local s = ent:GetSprite()
	d.shadoll_render_sprite = d.shadoll_render_sprite or {}
	local mx = 8
	local s2 = auxi.copy_sprite(ent:GetSprite())
	--print(s2:GetOverlayAnimation().." " .. s2:GetAnimation())
	if ent:IsVisible() then
		table.insert(d.shadoll_render_sprite,1,{sprite = s2,pos = ent.Position + ent.PositionOffset,})
	else
		table.insert(d.shadoll_render_sprite,1,{})
	end
	if #d.shadoll_render_sprite > mx then table.remove(d.shadoll_render_sprite,mx) end
	local ao = s.Color.A
	for i = 1,mx do 
		if d.shadoll_render_sprite[i] then
			local s3 = d.shadoll_render_sprite[i].sprite
			local pos = d.shadoll_render_sprite[i].pos
			if s3 and pos then
				s3.Color = Color(s.Color.R,s.Color.G,s.Color.B,(mx - i)/mx * ao * 0.85,s.Color.RO,s.Color.GO,s.Color.BO)				
				s3:Render(Isaac.WorldToScreen(pos),Vector(0,0),Vector(0,0))
			end
		end
	end
end

local function render_proj_shadow(ent)
	if ent == nil then return end
	local s = ent:GetSprite()
	local d = ent:GetData()
	d[item.own_key.."record"] = d[item.own_key.."record"] or {}
	local mx = 3
	local ao = s.Color.A
	for i = 1,mx do
		local s2 = auxi.copy_sprite(ent:GetSprite())
		s2.Color = Color(s2.Color.R,s2.Color.G,s2.Color.B,(mx - i)/mx * ao * 0.85,s2.Color.RO,s2.Color.GO,s2.Color.BO)
		s2.Scale = s.Scale * (mx * 2 - i + 0.5)/(mx * 2)
		s2:Render(Isaac.WorldToScreen(ent.Position + (d[item.own_key.."record"][i] or ent.PositionOffset) - ent.Velocity * 3 * i/mx),Vector(0,0),Vector(0,0))
	end
end

function item.get_active_shadows()
	local ret = {}
	local n_enemy = Isaac.GetRoomEntities()
	for u,v in pairs(n_enemy) do 
		if v:GetData()[item.own_key.."Doll"] and v:IsVulnerableEnemy() and not v:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) and (v:GetData()[item.own_key.."Delay"] or 0) == 0 then table.insert(ret,#ret + 1,v) end
	end
	return ret
end

function item.get_a_acceptible_shadow_pos()
	local ret = Vector(200,200)
	local room = Game():GetRoom()
	local tbl = {}
	local tbl2 = {}
	local tbl3 = {}
	local n_enemy = auxi.getenemies()
	for u,v in pairs(n_enemy) do 
		tbl[room:GetGridIndex(v.Position)] = true
		if v:GetData()[item.own_key.."Pos"] then tbl[room:GetGridIndex(v:GetData()[item.own_key.."Pos"])] = true end
	end
	for i = 1,room:GetGridSize() do
		local grid = room:GetGridEntity(i)
		if room:IsPositionInRoom(room:GetGridPosition(i),0) then
			if grid and grid:ToPit() and not tbl[i] then 
				table.insert(tbl2,#tbl2 + 1,{pos = room:GetGridPosition(i),})
			elseif not grid and not tbl[i] then 
				table.insert(tbl3,#tbl3 + 1,{pos = room:GetGridPosition(i),})
			end
		end
	end
	ret = (auxi.random_in_table(tbl2) or {}).pos or (auxi.random_in_table(tbl3) or {}).pos or ret
	return ret
end

function item.spawn_shadow(lev,id,pos,params)
	params = params or {}
	pos = pos or item.get_a_acceptible_shadow_pos()
	local info = params.info or (item.thrower[lev] or item.thrower[1])[id] or item.thrower[1][1]
	local iifo = info
	if info.Spilt then iifo = info info = auxi.random_in_weighed_table(iifo.Spilt,params.rng) end
	local ent_info = {Type = info.Type or 10,Variant = auxi.random_in_table(info.Variant,params.rng) or 0,SubType = auxi.random_in_table(info.SubType,params.rng) or 0,}
	if params.ent then params.ent:Morph(ent_info,ent_info.Type,ent_info.Variant,ent_info.SubType,params.ent:GetChampionColorIdx()) end
	local q = params.ent or Isaac.Spawn(ent_info.Type,ent_info.Variant,ent_info.SubType,pos,Vector(0,0),nil):ToNPC()
	q.SubType = ent_info.SubType
	local d = q:GetData()
	local s = q:GetSprite()
	d[item.own_key.."Doll"] = info
	d[item.own_key.."Info"] = iifo
	d[item.own_key.."Counter"] = 0
	d[item.own_key.."Delay"] = math.random(60)
	if iifo.sprite then 
		for i = 0,5 do 
			local str = "gfx/dolls/"..auxi.check_if_any(iifo.sprite,q,iifo,i)..".png"
			s:ReplaceSpritesheet(i,str) 
		end
		s:LoadGraphics()
	end
	s:SetLastFrame()
	auxi.check_if_any(info.Init,q,info)
	local tg_pos = pos + Vector(math.random(300)/10 - 15,0)
	local e1 = item.spawn_shadow_linker(tg_pos + Vector(0,-400),{})
	d[item.own_key.."Linker"] = item.spawn_shadow_link(tg_pos + auxi.MakeVector(math.random(360)) * math.random(1000)/1000 * 10,{Target = q,Parent = e1,immediate = params.immediate,main = true,})
	q.PositionOffset = item.floater
	if info.Force then 
		if info.State then q.State = info.State end
		if info.Anim then s:Play(info.Anim,true) s:SetLastFrame() s:SetFrame(info.Anim,s:GetFrame() - 1) s:Play(info.Anim) end
	end
	return q
end

function item.get_acceptible_counter()
	return item.room_info[Game():GetRoom():GetRoomShape()]
end

function item.spawn_random_shadow(pos,params)
	params = params or {}
	local info = item.thrower[auxi.check_if_any(params.level,params) or math.random(#item.thrower)]
	info = info[math.random(#info)]
	params.info = info
	return item.spawn_shadow(nil,nil,pos,params)
end

function item.spawn_shadow_linker(pos,params)
	local q = Isaac.Spawn(1000,item.entity,0,pos,Vector(0,0),nil):ToEffect()
	return q
end

function item.spawn_shadow_link(pos,params)
	params = params or {}
	local q = Isaac.Spawn(865,10,0,pos,Vector(0,0),nil) 
	local d = q:GetData()
	d[item.own_key.."Link"] = true
	local s = q:GetSprite() 
	for k = 0,1 do s:ReplaceSpritesheet(k,"gfx/effects/linkers/shadow_linker.png") end 
	s:LoadGraphics()
	q.DepthOffset = -40
	q.Parent = params.Parent or item.spawn_shadow_linker(pos + Vector(0,-400),params)
	local q2 = item.spawn_shadow_linker(q.Parent.Position,params)
	if params.immediate and params.Target then 
		q2.Position = params.Target.Position
	end
	q.Target = q2
	local d2 = q2:GetData()
	if params.main then	d2[item.own_key.."Linkie"] = true end
	q.Parent:GetData()[item.own_key.."Linker"] = q
	d2[item.own_key.."Linker"] = q
	d2[item.own_key.."Target"] = params.Target
	d[item.own_key.."Parent"] = q.Parent
	d[item.own_key.."Target"] = q.Target
	for i = 1,30 do q:Update() end
	return q2
end

--l local tbl = Isaac.GetRoomEntities() for u,v in pairs(tbl) do if v.Type == 829 then print() end end
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if false then
		print(ent.Type.." "..ent.Variant.." "..ent.SubType.." "..ent.State.." "..ent:GetSprite():GetFilename().." "..ent:GetSprite():GetAnimation().." "..ent:GetSprite():GetOverlayAnimation().." "..ent.ProjectileDelay.." "..ent.ProjectileCooldown)
		print(ent.TargetPosition)
		print(ent.I1.." "..ent.I2.." "..ent.V1.X..","..ent.V1.Y.." "..ent.V2.X..","..ent.V2.Y)
	end
	if auxi.check_all_exists(ent.Parent) and ent.Parent:GetData()[item.own_key.."Doll"] then
		if ent.FrameCount > 1 then
			d[item.own_key.."Posoffset"] = d[item.own_key.."Posoffset"] or Vector(0,ent.PositionOffset.Y)
			ent.PositionOffset = ent.Parent.PositionOffset
		end
		if ent.Parent.EntityCollisionClass == EntityCollisionClass.ENTCOLL_NONE then
			d[item.own_key.."entitycollisionclass_succ2"] = d[item.own_key.."entitycollisionclass_succ2"] or Attribute_holder.try_hold_attribute(ent,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE)
		else Attribute_holder.try_rewind_attribute(ent,"EntityCollisionClass",d[item.own_key.."entitycollisionclass_succ2"]) d[item.own_key.."entitycollisionclass_succ2"] = nil end
	else
		if d[item.own_key.."Posoffset"] then ent.PositionOffset = d[item.own_key.."Posoffset"] d[item.own_key.."Posoffset"] = nil end
		if d[item.own_key.."entitycollisionclass_succ2"] then Attribute_holder.try_rewind_attribute(ent,"EntityCollisionClass",d[item.own_key.."entitycollisionclass_succ2"]) d[item.own_key.."entitycollisionclass_succ2"] = nil end
	end
	for i = 1,1 do if d[item.own_key.."Doll"] then
		local info = ent:GetData()[item.own_key.."Doll"] 
		local iifo = ent:GetData()[item.own_key.."Info"] 
		ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_PITSONLY
		d[item.own_key.."Pos"] = d[item.own_key.."Pos"] or ent.Position
		ent.Position = ent.Position * 0.1 + d[item.own_key.."Pos"] * 0.9
		ent.Velocity = Vector(0,0)
		if auxi.check_if_any(item.target_info[ent.Type],ent) then ent.TargetPosition = d[item.own_key.."Pos"] end
		
		local check = info.check or (function(ent,info) return info.State and ent.State ~= info.State end)
		if check(ent,info) or (info.Check_Anim and s:GetAnimation() ~= info.Anim) then
			local ret = auxi.check_if_any(info.Move,ent,info,iifo)
			if (iifo.Spilt and math.random(1000) > (info.MoveStep or 500)) or ret then 
				if ret == "End" then 
					ent:GetData()[item.own_key.."Doll"] = nil
					ent:GetData()[item.own_key.."Info"] = nil
					break
				end
				if type(ret) == "table" then 
					ret = auxi.random_in_weighed_table(ret) 
					iifo = (item.thrower[ret[1] or 1] or {})[ret[2] or 1] or iifo
					if info.Spilt then info = iifo.Spilt[ret[3]] or auxi.random_in_weighed_table(iifo.Spilt)
					else info = iifo end
				elseif iifo.Spilt then info = auxi.random_in_weighed_table(ret or iifo.Spilt) end
				ent:GetData()[item.own_key.."Doll"] = info
				ent:GetData()[item.own_key.."Info"] = iifo
			end
			
			if info.work then info.work(ent,info) end
			if info.Anim then s:Play(auxi.check_if_any(info.Anim,ent,info),true) end
			if info.OverlayAnim then s:PlayOverlay(auxi.check_if_any(info.OverlayAnim,ent,info),true) end
			if info.Delay then ent.ProjectileDelay = auxi.check_if_any(info.Delay,ent,info) end
			if info.Counter then ent.ProjectileCooldown = auxi.check_if_any(info.Counter,ent,info) or ent.ProjectileCooldown end
			if info.TargetPosition then ent.TargetPosition = auxi.check_if_any(info.TargetPosition,ent,info) or ent.Position end
			if info.FlipX then ent.FlipX = auxi.random_bool() end
			if info.i1 then ent.I1 = auxi.check_if_any(info.i1,ent,info) or ent.I1 end
			if info.i2 then ent.I2 = info.i2 end
			if info.v1 then ent.V1 = auxi.check_if_any(info.v1,ent,info) or ent.V1 end
			if info.v2 then ent.V2 = info.v2 end
			if info.State then ent.State = info.State end
			ent.StateFrame = 0
			d[item.own_key.."Counter"] = (d[item.own_key.."Counter"] or 0) - 1
			if d[item.own_key.."Counter"] <= 0 then 
				d[item.own_key.."Linker"] = d[item.own_key.."Linker"] or item.spawn_shadow_link(ent.Position,{Target = ent,main = true,})
				local d2 = d[item.own_key.."Linker"]:GetData()
				if ent.FrameCount > 5 then d2[item.own_key.."MoveOver"] = 1 end
				d[item.own_key.."freeze_succ"] = d[item.own_key.."freeze_succ"] or Attribute_holder.try_hold_attribute(ent,"EntityFlag_FLAG_FREEZE",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FREEZE))
			end
		end
	end end
	if d[item.own_key.."Info"] then
		if d[item.own_key.."Info"].Tail then
			if auxi.check_all_exists(d[item.own_key.."tail"]) ~= true then
				local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.SPRITE_TRAIL,0,ent.Position + ent.PositionOffset,Vector(0,0),ent):ToEffect()
				q.PositionOffset = Vector(0,0)
				local s2 = q:GetSprite()
				s2:Load("gfx/recolored_trail.anm2",true)
				s2:Play("Idle",true)
				q.Color = Color(0,0,0,1,0.5,0,0.5)
				q.MinRadius = 0.05
				q.MaxRadius = 0.05
				q.SpriteScale = Vector(2,2)
				q.Parent = ent
				d[item.own_key.."tail"] = q
			else
				d[item.own_key.."tail"].Position = ent.Position + ent.PositionOffset
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if ent.SpawnerEntity and ent.SpawnerEntity:GetData()[item.own_key.."Info"] then
		local iifo = {}
		for u,v in pairs(item.Morphers[ent.Type] or {}) do if (v.Variant or 0) == ent.Variant then iifo = v break end end
		if iifo.sprite then 
			for i = 0,5 do 
				local str = "gfx/dolls/"..auxi.check_if_any(iifo.sprite,q,iifo,i)..".png"
				s:ReplaceSpritesheet(i,str) 
			end
			s:LoadGraphics()
		end
		d[item.own_key.."Info"] = iifo
	end
end,
})

--[[
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if item.is_shadow() then
		if auxi.check_if_any(item.ignorer[ent.Type],ent) then
		else d.is_shadoll = true end
		s.Color = item.orig_col
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_RENDER, params = nil,
Function = function(_,ent,offset)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if d.is_shadoll then
		s.Color = auxi.AddColor(s.Color,item.trans_col,0.8,0.2)
		render_shadow(ent)
	end
end,
})
--]]

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PROJECTILE_INIT, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if item.is_shadow() or (ent.SpawnerEntity and ent.SpawnerEntity:GetData()[item.own_key.."Doll"]) then
		d.is_shadoll = true
		s.Color = item.orig_col
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PROJECTILE_UPDATE, params = nil,
Function = function(_,ent,offset)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if d.is_shadoll then
		if auxi.check_all_exists(d[item.own_key.."tail"]) ~= true then
			local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.SPRITE_TRAIL,0,ent.Position + ent.PositionOffset,Vector(0,0),ent):ToEffect()
			q.PositionOffset = Vector(0,0)
			local s2 = q:GetSprite()
			s2:Load("gfx/recolored_trail.anm2",true)
			s2:Play("Idle",true)
			q.Color = Color(0,0,0,1,0.5,0,0.5)
			q.MinRadius = 0.1
			q.MaxRadius = 0.07
			q.SpriteScale = Vector(2,2)
			q.Parent = ent
			d[item.own_key.."tail"] = q
		else
			d[item.own_key.."tail"].Position = ent.Position + ent.PositionOffset
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PROJECTILE_RENDER, params = nil,
Function = function(_,ent,offset)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if d.is_shadoll then
		s.Color = auxi.AddColor(s.Color,item.trans_col,0.8,0.2)
		render_proj_shadow(ent)
		d[item.own_key.."record"] = d[item.own_key.."record"] or {}
		table.insert(d[item.own_key.."record"],1,Vector(ent.PositionOffset.X,ent.PositionOffset.Y))
		if #d[item.own_key.."record"] > 3 then table.remove(d[item.own_key.."record"],3) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_INIT, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if item.is_shadow() or (ent.SpawnerEntity and ent.SpawnerEntity:GetData()[item.own_key.."Doll"]) then
		if ent.SpawnerType >= 9 then 
			d.is_shadoll = true
			s.Color = item.orig_col
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_RENDER, params = nil,
Function = function(_,ent,offset)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if d.is_shadoll then
		s.Color = auxi.AddColor(s.Color,item.trans_col,0.8,0.2)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = item.entity,
Function = function(_,ent)
	local d = ent:GetData()
	if auxi.check_all_exists(d[item.own_key.."Linker"]) ~= true then ent:Remove() return end
	if d[item.own_key.."Linkie"] then
		if auxi.check_all_exists(d[item.own_key.."Target"]) ~= true then ent:Remove() return
		else
			local targ = d[item.own_key.."Target"]
			local d2 = targ:GetData()
			targ.PositionOffset = ent.Position - targ.Position
			if targ.PositionOffset:Length() > 10 then 
				d2[item.own_key.."entitycollisionclass_succ"] = d2[item.own_key.."entitycollisionclass_succ"] or Attribute_holder.try_hold_attribute(targ,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE)
				d2[item.own_key.."gridcollisionclass_succ"] = d2[item.own_key.."gridcollisionclass_succ"] or Attribute_holder.try_hold_attribute(targ,"GridCollisionClass",EntityGridCollisionClass.GRIDCOLL_NONE)
				targ:GetSprite().Color = auxi.AddColor(Color(1,1,1,1),Color(-1,-1,-1,0),1,targ.PositionOffset:Length()/250)
			end
			if (d[item.own_key.."MoveOver"] or 0) == 1 then
				local dir = targ.Position + item.floater - ent.Position
				ent.Velocity = dir:Normalized() * math.min(20,dir:Length() * 0.4)
				if auxi.check_all_exists(d[item.own_key.."tail"]) ~= true then
					local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.SPRITE_TRAIL,0,ent.Position + ent.PositionOffset,Vector(0,0),ent):ToEffect()
					q.PositionOffset = Vector(0,0)
					local s2 = q:GetSprite()
					s2:Load("gfx/recolored_trail.anm2",true)
					s2:Play("Idle",true)
					q.Color = Color(0,0,0,1,0.5,0,0.5)
					q.MinRadius = 0.05
					q.MaxRadius = 0.05
					q.SpriteScale = Vector(2,2)
					q.Parent = ent
					d[item.own_key.."tail"] = q
				else 
					d[item.own_key.."tail"].Position = ent.Position + ent.PositionOffset 
					d[item.own_key.."tail"].Color = auxi.AddColor(d[item.own_key.."tail"].Color,Color(0,0,0,-1),1,0.1)
				end
				if (targ.PositionOffset - item.floater):Length() < 1 then
					if auxi.check_all_exists(d[item.own_key.."tail"]) then d[item.own_key.."tail"]:Remove() d[item.own_key.."tail"] = nil end
					d[item.own_key.."MoveOver"] = 2
					d2[item.own_key.."Pos"] = item.get_a_acceptible_shadow_pos()
					local q2 = item.spawn_shadow_link(d2[item.own_key.."Pos"],{Target = targ,})
					d[item.own_key.."Replacement"] = q2
				end
			elseif (d[item.own_key.."MoveOver"] or 0) == 2 then
				if auxi.check_all_exists(d[item.own_key.."Replacement"]) then
					if (d[item.own_key.."Replacement"].Position - ent.Position):Length() < 1 then
						d[item.own_key.."MoveOver"] = 3
					end
				end
			elseif (d[item.own_key.."MoveOver"] or 0) == 3 then
				if auxi.check_all_exists(d[item.own_key.."Replacement"]) then
					local dir = d2[item.own_key.."Pos"] + item.floater - ent.Position
					ent.Velocity = dir:Normalized() * math.min(20,dir:Length() * 0.4)
					targ.Position = ent.Position - item.floater
					if dir:Length() < 0.1 then 
						d2[item.own_key.."Linker"] = d[item.own_key.."Replacement"]
						d[item.own_key.."Replacement"]:GetData()[item.own_key.."Linkie"] = true
						ent:Remove()
						return
					end
				end
			else
				if (d2[item.own_key.."Delay"] or 0) > 0 then d2[item.own_key.."Delay"] = d2[item.own_key.."Delay"] - 1 end
				local n_tgs = item.get_active_shadows()
				--print(#n_tgs .." ".. item.get_acceptible_counter())
				if (d2[item.own_key.."Delay"] or 0) <= 0 and (#n_tgs < item.get_acceptible_counter() or targ.PositionOffset:Length() < 160) then
					local dir = (d2[item.own_key.."Pos"] or targ.Position) - ent.Position
					ent.Velocity = dir:Normalized() * math.min(20,dir:Length() * 0.4)
					targ.Position = targ.Position * 0.5 + d2[item.own_key.."Pos"] * 0.5
				else
					if d2[item.own_key.."Delay"] <= 0 then d2[item.own_key.."Delay"] = math.random(60) end
					local dir = (d2[item.own_key.."Pos"] or targ.Position) + item.floater - ent.Position
					ent.Velocity = dir:Normalized() * math.min(20,dir:Length() * 0.4)
				end
				if targ.PositionOffset:Length() < 10 and (d2[item.own_key.."entitycollisionclass_succ"] or d2[item.own_key.."freeze_succ"]) then
					Attribute_holder.try_rewind_attribute(targ,"EntityFlag_FLAG_FREEZE",d2[item.own_key.."freeze_succ"],Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FREEZE)) d2[item.own_key.."freeze_succ"] = nil
					Attribute_holder.try_rewind_attribute(targ,"EntityCollisionClass",d2[item.own_key.."entitycollisionclass_succ"]) d2[item.own_key.."entitycollisionclass_succ"] = nil
					Attribute_holder.try_rewind_attribute(targ,"GridCollisionClass",d2[item.own_key.."gridcollisionclass_succ"]) d2[item.own_key.."gridcollisionclass_succ"] = nil
					d2[item.own_key.."Counter"] = auxi.choose(3,4,5,6,7,8)
				end
			end
		end
	else
		if d[item.own_key.."Pos"] then ent.Position = ent.Position * 0.2 + d[item.own_key.."Pos"] * 0.8
		elseif d[item.own_key.."Target"] then 
			local dir = d[item.own_key.."Target"].Position + d[item.own_key.."Target"].PositionOffset - ent.Position
			ent.Velocity = dir:Normalized() * math.min(30,dir:Length() * 0.5)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 865,
Function = function(_,ent)
	local d = ent:GetData()
	if ent.Variant == 10 and d[item.own_key.."Link"] then
		if auxi.check_all_exists(d[item.own_key.."Target"]) ~= true or auxi.check_all_exists(d[item.own_key.."Parent"]) ~= true then 
			ent:Remove()
			return
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 303,
Function = function(_,ent)
	if ent.Variant == enums.Enemies.ShadowToken then
		local rng = ent:GetDropRNG()
		local room = Game():GetRoom()
		local wid = room:GetGridWidth()
		local tot = 0
		local cnt = 20
		for i = 1,room:GetGridSize() do
			local grid = room:GetGridEntity(i)
			if grid and grid:ToPit() then tot = tot + 1 end
		end
		local tbl = {}
		for i = 1,room:GetGridSize() do
			local grid = room:GetGridEntity(i)
			if grid and grid:ToPit() then 
				local pos = room:GetGridPosition(i)
				local rnd = math.random(cnt * 2) - math.random(tot * 2)
				if rnd > 0 then table.insert(tbl,#tbl + 1,{pos = pos,}) end
			end
		end
		local rt = Game():GetRoom():GetType()
		for u,v in pairs(tbl) do
			local pos = v.pos
			if rt == RoomType.ROOM_MINIBOSS then
				local e2 = item.spawn_random_shadow(pos,{level = 7,rng = rng,})
				local d2 = e2:GetData()
				d2[item.own_key.."Pos"] = pos
			elseif rt == RoomType.ROOM_BOSS then
			else
				local e2 = item.spawn_random_shadow(pos,{level = function() return auxi.random_in_weighed_table(item.weigh_table[1],rng).id end,rng = rng,})
				local d2 = e2:GetData()
				d2[item.own_key.."Pos"] = pos
			end
		end
		if rt == RoomType.ROOM_BOSS then
			local autio = Isaac.Spawn(996,enums.Enemies.Autio,0,Game():GetPlayer(0).Position,Vector(0,0),nil)
		end
		ent:Remove()
	end
end,
})

return item