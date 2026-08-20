local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Pause_Screen_holder = require("Qing_Remaster_scripts.others.Pause_Screen_holder")
local time_holder = require("Qing_Remaster_scripts.others.Time_holder")
local CompletionMarks = require("Qing_Remaster_scripts.core.completion_marks_manager")

local item = {
	myToCall = {},
	ToCall = {},
	shader_name = "Qing_HelpfulShader",
	Anim_infos = {
		Appear = {
			{PosOffsetX = -445,PosOffsetY = 32,ScaleX = 1.38,ScaleY = 0.62,frame = 0,},
			{PosOffsetX = 12,PosOffsetY = -8,ScaleX = 0.9,ScaleY = 1.1,frame = 4,},
			{PosOffsetX = 0,PosOffsetY = 0,ScaleX = 1.0,ScaleY = 1.0,frame = 6,},
			total = 7,
		},
		Disappear = {
			{PosOffsetX = 0,PosOffsetY = 0,ScaleX = 1.0,ScaleY = 1.0,frame = 0,},
			{PosOffsetX = 0,PosOffsetY = 0,ScaleX = 1.0,ScaleY = 1.0,frame = 3,},
			{PosOffsetX = 12,PosOffsetY = -8,ScaleX = 0.9,ScaleY = 1.1,frame = 5,},
			{PosOffsetX = 540,PosOffsetY = 42,ScaleX = 1.5,ScaleY = 0.5,frame = 10,},
			total = 11,
		},
		MiniAppear = {
			{PosOffsetX = 0,PosOffsetY = 63,ScaleX = 0.5,ScaleY = 1.5,frame = 0,},
			{PosOffsetX = 0,PosOffsetY = 0,ScaleX = 1.1,ScaleY = 0.9,frame = 1,},
			{PosOffsetX = 0,PosOffsetY = 0,ScaleX = 1.0,ScaleY = 1.0,frame = 3,},
			total = 4,
		},
		MiniDisappear = {
			{PosOffsetX = 0,PosOffsetY = 0,ScaleX = 1.0,ScaleY = 1.0,frame = 0,},
			{PosOffsetX = 0,PosOffsetY = 0,ScaleX = 1.1,ScaleY = 0.9,frame = 2,},
			{PosOffsetX = 0,PosOffsetY = 63,ScaleX = 0.5,ScaleY = 1.5,frame = 4,},
			total = 5,
		},
	},
	kUnintrusiveHudPostItOffset = Vector(65, 50),
	kMiniHudPostItOffset = Vector(92, 89),
	kDefaultPostItsRenderOffset = Vector(-72, -84),
}

item.player_info = setmetatable({}, {
	__index = function(_, player_type)
		local char = CompletionMarks.get_character(player_type)
		return char and char.legacy_save or nil
	end,
})

local function GetPostItRenderOffset()
	if UNINTRUSIVEPAUSEMENU then
		return item.kUnintrusiveHudPostItOffset
	elseif MiniPauseMenu_Mod or MiniPauseMenuPlus_Mod then
		return item.kMiniHudPostItOffset
	else
		return item.kDefaultPostItsRenderOffset
	end
end

function item.AnimatePauseScreenPostIts(anim,frame)
	frame = frame or item.render_frame or 0
	local info = auxi.check_lerp(frame,item.Anim_infos[anim])
	frame = math.min(frame + 0.5,100)
	return {frame = frame,PosOffset = Vector(info.PosOffsetX,info.PosOffsetY),Scale = Vector(info.ScaleX,info.ScaleY),}
end

-- 无 RGON 时保留旧 shader 路径；RGON 由 completion_marks_manager 的 PRE/POST 回调负责。
if not REPENTOGON then

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.render_frame = 0
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldsave)
	item.render_frame = 0
end,
})

local function RenderPostIt(anim,noupdate,instant)
	if Isaac.GetChallenge() > 0 then return end
	anim = anim or "Disappear"
	if anim ~= item.currentAnim then
		if instant then	item.render_frame = item.Anim_infos[anim].total
		else item.render_frame = 0 end
	end

	item.currentAnim = anim
	local trueAnim = anim
	if UNINTRUSIVEPAUSEMENU or MiniPauseMenu_Mod or MiniPauseMenuPlus_Mod then trueAnim = "Mini" .. anim end

	local player = Game():GetPlayer(0)
	local player_type = player:GetPlayerType()
	if CompletionMarks.get_character(player_type) == nil then return end
	if item.renderer == nil then
		item.renderer = Sprite()
		item.renderer:Load("gfx/ui/completion_widget.anm2", true)
		item.renderer:Play("Idle",true)
	end
	for layer,frame in pairs(CompletionMarks.widget_layers(player_type)) do
		item.renderer:SetLayerFrame(layer,frame)
	end

	local ret = item.AnimatePauseScreenPostIts(trueAnim)
	if not noupdate then item.render_frame = ret.frame end

	local extraOffset = Vector(math.floor((Isaac.GetScreenWidth()/10) - 48), 0)
	local screenCenterPos = auxi.GetScreenCenter()
	local pos = screenCenterPos + GetPostItRenderOffset() + extraOffset

	if not (anim == "Disappear" and item.render_frame >= item.Anim_infos[anim].total) then
		item.renderer.Scale = ret.Scale
		item.renderer:Render(pos + ret.PosOffset,Vector(0,0),Vector(0,0))
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,
Function = function(_,name)
	if name == item.shader_name and Pause_Screen_holder.currentState then
		if time_holder.IsUpper() ~= true then return end
		if Pause_Screen_holder.check_info("Leave") then
			RenderPostIt("Disappear",Pause_Screen_holder.check_info("NoUpdate"))
		elseif Pause_Screen_holder.check_info("Hide") ~= true then
			RenderPostIt("Appear",Pause_Screen_holder.check_info("NoUpdate"))
		end
	end
end,
})

end

return item
