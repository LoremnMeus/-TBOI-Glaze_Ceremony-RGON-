local manifest = {
	-- Whole-ANM2 Load() path for title/main. Keep disabled until those
	-- language-specific ANM2 files exist; missing Loads would break the menu.
	enabled = false,
	default_language = "en",
	-- Character select / starting-room controls / game-over name: Reverie-style
	-- Load() onto the shared GetModded* sprites. Do not ReplaceSpritesheet the
	-- live vanilla/mod sprites every frame.
	character_select = {
		enabled = true,
		anm2 = {
			normal = {
				en = "gfx/charactermenu.anm2",
				zh = "gfx/ui/lang/zh/character_menu/menu.anm2",
			},
			alt = {
				en = "gfx/charactermenualt.anm2",
				zh = "gfx/ui/lang/zh/character_menu/menu_b.anm2",
			},
		},
	},
	controls = {
		enabled = true,
		en = "gfx/controls.anm2",
		zh = "gfx/ui/lang/zh/controls/controls.anm2",
	},
	game_over = {
		enabled = true,
		en = "gfx/death screen.anm2",
		zh = "gfx/ui/lang/zh/game_over/death_screen.anm2",
	},
	-- 标题 Logo 叠加（见 title_menu_logo_holder.lua）；不整包 Load titlemenu.anm2
	title_logo = {
		enabled = true,
		anm2 = "gfx/ui/main menu/titlemenu_replace.anm2",
		en = "gfx/ui/main menu/logo_replace.png",
		zh = "gfx/ui/lang/zh/title/logo_replace.png",
		follow_menu_lang = true,
		-- 可选手调；默认由 title_menu_logo_holder 按 vanilla/replace anm2 锚点差计算
		-- render_offset = { x = -39, y = -15 },
	},
	languages = {
		zh = {
			base = "gfx/ui/lang/zh/",
			global = {
				title = "title/titlemenu.anm2",
				main = "main_menu/mainmenu.anm2",
			},
			players = {
				{
					key = "wq",
					anim = "W.Qing",
					menu = "character_menu/menu.anm2",
					portrait = "character_menu/portraits.anm2",
					controls = "controls/controls.anm2",
					coop = "coop/coop_menu.anm2",
					game_over = "game_over/death_screen.anm2",
				},
				{
					key = "Spwq",
					anim = "SP.W.Qing",
					menu = "character_menu/menu_b.anm2",
					portrait = "character_menu/portraits_b.anm2",
					controls = "controls/controls_b.anm2",
					coop = "coop/coop_menu_b.anm2",
					game_over = "game_over/death_screen_b.anm2",
				},
				{
					key = "Tecro",
					anim = "Tecro",
					menu = "character_menu/menu.anm2",
					portrait = "character_menu/portraits.anm2",
					controls = "controls/controls.anm2",
					coop = "coop/coop_menu.anm2",
					game_over = "game_over/death_screen.anm2",
				},
				{
					key = "Tecrorun",
					anim = "Tecrorun",
					menu = "character_menu/menu_b.anm2",
					portrait = "character_menu/portraits_b.anm2",
					controls = "controls/controls_b.anm2",
					coop = "coop/coop_menu_b.anm2",
					game_over = "game_over/death_screen_b.anm2",
				},
				{
					key = "Anna",
					anim = "Anna",
					menu = "character_menu/menu.anm2",
					portrait = "character_menu/portraits.anm2",
					controls = "controls/controls.anm2",
					coop = "coop/coop_menu.anm2",
					game_over = "game_over/death_screen.anm2",
				},
				{
					key = "annA",
					anim = "annA",
					menu = "character_menu/menu_b.anm2",
					portrait = "character_menu/portraits_b.anm2",
					controls = "controls/controls_b.anm2",
					coop = "coop/coop_menu_b.anm2",
					game_over = "game_over/death_screen_b.anm2",
				},
				{
					key = "Zeistos",
					anim = "Zeistos",
					menu = "character_menu/menu.anm2",
					portrait = "character_menu/portraits.anm2",
					controls = "controls/controls.anm2",
					coop = "coop/coop_menu.anm2",
					game_over = "game_over/death_screen.anm2",
				},
				{
					key = "Zeiz",
					anim = "Zeiz",
					menu = "character_menu/menu_b.anm2",
					portrait = "character_menu/portraits_b.anm2",
					controls = "controls/controls_b.anm2",
					coop = "coop/coop_menu_b.anm2",
					game_over = "game_over/death_screen_b.anm2",
				},
				{
					key = "Marriano",
					anim = "Marriano",
					menu = "character_menu/menu.anm2",
					portrait = "character_menu/portraits.anm2",
					controls = "controls/controls.anm2",
					coop = "coop/coop_menu.anm2",
					game_over = "game_over/death_screen.anm2",
				},
				{
					key = "Autio",
					anim = "Autio",
					menu = "character_menu/menu.anm2",
					portrait = "character_menu/portraits.anm2",
					controls = "controls/controls.anm2",
					coop = "coop/coop_menu.anm2",
					game_over = "game_over/death_screen.anm2",
				},
				{
					key = "Lu",
					anim = "Lu",
					menu = "character_menu/menu.anm2",
					portrait = "character_menu/portraits.anm2",
					controls = "controls/controls.anm2",
					coop = "coop/coop_menu.anm2",
					game_over = "game_over/death_screen.anm2",
				},
			},
		},
	},
}

return manifest
