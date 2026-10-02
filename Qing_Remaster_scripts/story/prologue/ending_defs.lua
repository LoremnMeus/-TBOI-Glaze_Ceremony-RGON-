-- Prologue Ending1 presentation data only.
-- StoryProgress sees only prologue.ending; these PHASE ids are scene-runtime.
-- 8 presentation phases = 8 BodyPanels art frames (320×192 on my_intro_1.png).

local defs = {}

defs.PHASE = {
	QING_CHARGES_BEAST = "qing_charges_beast",
	BEAST_FATAL_BLOW = "beast_fatal_blow",
	QING_REACHES_EYE = "qing_reaches_eye",
	GLAZE_SEIZES_EYE = "glaze_seizes_eye",
	STANDOFF = "standoff",
	CLASH = "clash",
	QING_PROTECTS_ISAAC = "qing_protects_isaac",
	AFTERMATH = "aftermath",
}

defs.PHASE_ORDER = {
	defs.PHASE.QING_CHARGES_BEAST,
	defs.PHASE.BEAST_FATAL_BLOW,
	defs.PHASE.QING_REACHES_EYE,
	defs.PHASE.GLAZE_SEIZES_EYE,
	defs.PHASE.STANDOFF,
	defs.PHASE.CLASH,
	defs.PHASE.QING_PROTECTS_ISAAC,
	defs.PHASE.AFTERMATH,
}

-- Formal storyboard art on my_intro_1.png (640×768, 2×4 cells of 320×192).
defs.ART = {
	QING_CHARGES = 0,
	BEAST_FATAL = 1,
	REACHES_EYE = 2,
	GLAZE_SEIZES = 3,
	STANDOFF = 4,
	CLASH = 5,
	QING_PROTECTS = 6,
	AFTERMATH = 7,
}
defs.ART_FRAME_COUNT = 8

defs.PHASE_ART = {
	[defs.PHASE.QING_CHARGES_BEAST] = defs.ART.QING_CHARGES,
	[defs.PHASE.BEAST_FATAL_BLOW] = defs.ART.BEAST_FATAL,
	[defs.PHASE.QING_REACHES_EYE] = defs.ART.REACHES_EYE,
	[defs.PHASE.GLAZE_SEIZES_EYE] = defs.ART.GLAZE_SEIZES,
	[defs.PHASE.STANDOFF] = defs.ART.STANDOFF,
	[defs.PHASE.CLASH] = defs.ART.CLASH,
	[defs.PHASE.QING_PROTECTS_ISAAC] = defs.ART.QING_PROTECTS,
	[defs.PHASE.AFTERMATH] = defs.ART.AFTERMATH,
}

defs.ANM2_PATH = "gfx/thread/Chapter0/my_fin1.anm2"
-- Scene = background / overlay / fade timeline (no Body). BodyPanels = Lua-driven 0..7.
defs.ANM2_BACKGROUND_ANIM = "Scene"
defs.ANM2_BODY_ANIM = "BodyPanels"

-- Background Scene hold / outro (legacy timeline frames; Body is independent).
defs.BG_FRAME = {
	MAIN = 0,
	OUTRO_BEGIN = 116,
	OUTRO_END = 140,
}

defs.MUSIC_ID = 69
defs.LINE_AUTO_ADVANCE = 80 -- MC_POST_UPDATE frames (30Hz); lines may override with duration=
defs.LINE_CONFIRM_MIN = 6
-- Finishing: Body hold → Body fade → Scene outro. BG must not leave MAIN until Body alpha is 0.
defs.OUTRO = {
	BODY_HOLD = 18,
	BODY_FADE = 24,
}
-- Total finishing timeline (body hold+fade + Scene 116→140 + short linger).
defs.FIN_HOLD_FRAMES = 90
-- Presentation handoff only: freeze Beast Death at this frame before Ending1. Not Story truth;
-- not derived from BodyPanels panel 0 content (storyboard may cinematic-replay the blow).
defs.BEAST_HANDOFF_FRAME = 60
defs.DIALOG_Y_RATIO = 0.82
defs.SKIP_HINT_Y_RATIO = 0.94
-- Hold SPACE: dialogue / hold / Scene outro clocks run at this multiplier.
defs.FAST_FORWARD_MULT = 4
-- Stage canvas the ANM2 was authored against (overlay/shadow align to this).
defs.STAGE_WIDTH = 432
defs.STAGE_HEIGHT = 240
defs.BODY_WIDTH = 320
defs.BODY_HEIGHT = 192

-- Dialogue tint by speaker (no name prefix in cutscene).
defs.SPEAKER_COLOR = {
	qing = {r = 0xCF / 255, g = 0xC2 / 255, b = 0xFB / 255, a = 1},
	glaze = {r = 0x78 / 255, g = 0xCD / 255, b = 0xFE / 255, a = 1},
	isaac = {r = 0xFF / 255, g = 0xF2 / 255, b = 0xE6 / 255, a = 1},
	narration = {r = 1, g = 1, b = 1, a = 1},
}

-- Authority storyboard dialogue (zh/en). speaker drives SPEAKER_COLOR.
defs.PHASES = {
	[defs.PHASE.QING_CHARGES_BEAST] = {
		lines = {
			{zh = "到此为止了。", en = "This ends here.", speaker = "qing"},
		},
	},
	[defs.PHASE.BEAST_FATAL_BLOW] = {
		lines = {
			{
				zh = "祸兽被彻底击溃，那颗眼球却完好无损地飞了出来。",
				en = "The Beast is torn apart—yet its eye is cast out completely intact.",
				speaker = "narration",
			},
		},
	},
	[defs.PHASE.QING_REACHES_EYE] = {
		lines = {
			{
				zh = "拿到了。",
				en = "Got it.",
				speaker = "qing",
				duration = 45,
			},
		},
	},
	[defs.PHASE.GLAZE_SEIZES_EYE] = {
		-- Brief beat after the sudden cut so the seize reads before dialogue.
		entry_hold = 8,
		lines = {
			{zh = "……琉璃。", en = "...Glaze.", speaker = "qing"},
			{zh = "好久不见。", en = "Long time no see.", speaker = "glaze"},
		},
	},
	[defs.PHASE.STANDOFF] = {
		lines = {
			{zh = "你果然是为了这个来的。", en = "So you came for this after all.", speaker = "qing"},
			{zh = "不然呢？", en = "What else?", speaker = "glaze"},
			{zh = "把它留下。", en = "Leave it.", speaker = "qing"},
			{zh = "那可不行。", en = "No.", speaker = "glaze"},
			{
				zh = "我等这东西成熟，已经等得够久了。",
				en = "I waited long enough for this to mature.",
				speaker = "glaze",
			},
		},
	},
	[defs.PHASE.CLASH] = {
		-- No dialogue; collision beat.
		lines = {},
		auto_hold = 90,
	},
	[defs.PHASE.QING_PROTECTS_ISAAC] = {
		lines = {
			{
				zh = "冲突失控，力量向上贯穿了原本隔开的空间。",
				en = "The clash breaks loose, tearing upward through the space that separated them.",
				speaker = "narration",
			},
			{zh = "……！", en = "...!", speaker = "isaac"},
			{zh = "趴下！", en = "Get down!", speaker = "qing"},
		},
	},
	[defs.PHASE.AFTERMATH] = {
		lines = {
			{zh = "喂……", en = "Hey...", speaker = "isaac"},
			{zh = "你醒醒……", en = "Wake up...", speaker = "isaac"},
			{zh = "她还活着……？", en = "She's still alive...?", speaker = "isaac"},
			{zh = "当然。", en = "Of course.", speaker = "glaze"},
			{
				zh = "她非要挡在你前面。",
				en = "She insisted on standing in front of you.",
				speaker = "glaze",
			},
			{zh = "……真是麻烦。", en = "...What a hassle.", speaker = "glaze"},
			{
				zh = "她的东西，你先拿着。",
				en = "Take her things for now.",
				speaker = "glaze",
				after_event = "ending1_achievement",
			},
			{zh = "你要把她怎么样？", en = "What are you going to do to her?", speaker = "isaac"},
			{zh = "救她。", en = "Save her.", speaker = "glaze", fin = true},
		},
	},
}

function defs.phase_index(phase_id)
	for i, id in ipairs(defs.PHASE_ORDER) do
		if id == phase_id then return i end
	end
	return nil
end

function defs.art_frame_for_phase(phase_id)
	return defs.PHASE_ART[phase_id] or 0
end

function defs.line_text(line)
	if type(line) ~= "table" then return "" end
	local lang = Options and Options.Language
	if lang == "en" and line.en then return line.en end
	return line.zh or line.en or ""
end

function defs.line_color(line)
	local speaker = type(line) == "table" and line.speaker or "narration"
	local c = defs.SPEAKER_COLOR[speaker] or defs.SPEAKER_COLOR.narration
	return KColor(c.r, c.g, c.b, c.a)
end

return defs
