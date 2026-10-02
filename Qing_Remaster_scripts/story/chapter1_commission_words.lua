-- Chapter 1 commission dialogue draft (NOT wired to runtime yet).
-- Do not require this from Ending1. Do not play during prologue.
-- Material names / five-element lore remain OPEN; do not re-lock old 金木水火土.

local draft = {
	SCHEMA_VERSION = 1,
	status = "draft_unwired",
	story_node = "chapter1.commission",
	notes = {
		zh = [[
触发边界：
- 必须在 Chapter1 opening（第一章 · 所求之物）之后
- Chapter1 opening 本身不发布 Quest
- Commission scene 开始前 Chapter1 可保持 AVAILABLE + current=nil + objective=nil
- begin_chapter1_commission() → ACTIVE + current=commission（仍无 Quest）
- accept_chapter1_commission() 完成后才：
  commission_accepted=true
  material_phase
  collect_materials
  首次显示第一章主线任务
]],
		en = [[
Boundaries:
- Must occur after Chapter1 opening title
- Opening itself publishes no Quest
- Before commission scene: AVAILABLE + nil current/objective is valid
- begin_chapter1_commission() → ACTIVE + commission node (still no Quest)
- accept_chapter1_commission() then sets commission_accepted + material_phase + collect_materials
  (first Chapter1 main quest)
]],
	},
	Words = {
		zh = {
			{word = "琉璃：醒了？",},
			{word = "以撒：青呢？",},
			{word = "琉璃：还活着。",},
			{word = "以撒：我要见她。",},
			{word = "琉璃：现在不行。",},
			{word = "以撒：为什么？",},
			{word = "琉璃：因为她伤得比你想象中严重。",},
			{word = "琉璃：顺便自我介绍一下。",},
			{word = "琉璃：鄙人琉璃。",},
			{word = "琉璃：现在是青的主治医师。",},
			{word = "以撒：你能救她吗？",},
			{word = "琉璃：能。",},
			{word = "以撒：那就快点啊！",},
			{word = "琉璃：如果材料够的话。",},
			-- TODO: expand material ask without locking five-element canon.
		},
		en = {
			{word = "Glaze: Awake?",},
			{word = "Isaac: Where's Qing?",},
			{word = "Glaze: Still alive.",},
			{word = "Isaac: I want to see her.",},
			{word = "Glaze: Not now.",},
			{word = "Isaac: Why?",},
			{word = "Glaze: Because she's hurt worse than you think.",},
			{word = "Glaze: Introductions, then.",},
			{word = "Glaze: I am Glaze.",},
			{word = "Glaze: Currently Qing's attending physician.",},
			{word = "Isaac: Can you save her?",},
			{word = "Glaze: Yes.",},
			{word = "Isaac: Then hurry!",},
			{word = "Glaze: If the materials are enough.",},
		},
	},
}

return draft
