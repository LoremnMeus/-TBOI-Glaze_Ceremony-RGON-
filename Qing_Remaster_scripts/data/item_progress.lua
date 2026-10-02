local enums = require("Qing_Remaster_scripts.core.enums")

local data = {Item = {},Trinket = {},Card = {},Pickup = {},Player = {}}
local function add(kind,id,value)
	if id then data[kind][id] = value end
	if kind == "Item" and id then data[id] = value end
end

add("Item",enums.Items.Darkness,{
		content_type = "Item",
		key = "Darkness",
		name = "Darkness",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Darkness.png",
})
add("Item",enums.Items.Touchstone,{
		content_type = "Item",
		key = "Touchstone",
		name = "Touchstone",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Touchstone.png",
})
add("Item",enums.Items.My_Hat,{
		content_type = "Item",
		key = "My_Hat",
		name = "My Hat",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_My_Hat.png",
})
add("Item",enums.Items.Tech_9,{
		content_type = "Item",
		key = "Tech_9",
		name = "Tech 9",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Tech_9.png",
})
add("Item",enums.Items.Assassin_s_Eye,{
		content_type = "Item",
		key = "Assassin_s_Eye",
		name = "Assassin's Eye",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Assassin_s_Eye.png",
})
add("Item",enums.Items.Mental_Hypnosis,{
		content_type = "Item",
		key = "Mental_Hypnosis",
		name = "Mental Hypnosis",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Mental_Hypnosis.png",
})
add("Item",enums.Items.Gold_Rush,{
		content_type = "Item",
		key = "Gold_Rush",
		name = "Gold Rush",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Golden_Rush.png",
})
add("Item",enums.Items.Air_Flight,{
		content_type = "Item",
		key = "Air_Flight",
		name = "Air Flight",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Air_Flight.png",
})
add("Item",enums.Items.The_Watcher,{
		content_type = "Item",
		key = "The_Watcher",
		name = "The Watcher",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_The_Watcher.png",
})
add("Item",enums.Items.Giant_Punch,{
		content_type = "Item",
		key = "Giant_Punch",
		name = "Giant Punch",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Gaint_Punch.png",
})
add("Item",enums.Items.Memory,{
		content_type = "Item",
		key = "Memory",
		name = "Memory",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Memory.png",
})
add("Item",enums.Items.My_Best_Friend,{
		content_type = "Item",
		key = "My_Best_Friend",
		name = "My Best Friend",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_My_Best_Friend.png",
})
add("Item",enums.Items.Super_Bombs,{
		content_type = "Item",
		key = "Super_Bombs",
		name = "Super Bombs",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Super_Bombs.png",
})
add("Item",enums.Items.Brimstream,{
		content_type = "Item",
		key = "Brimstream",
		name = "Brimstream",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Brimstream.png",
})
add("Item",enums.Items.Crown_of_the_glaze,{
		content_type = "Item",
		key = "Crown_of_the_glaze",
		name = "Crown of the Glaze",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Glaze_Crown.png",
})
add("Item",enums.Items.A_Shard_Of_Coin,{
		content_type = "Item",
		key = "A_Shard_Of_Coin",
		name = "A Shard of Coin",
		remaster_status = "inactive",
		-- Dormant legacy story material: keep XML achievement asset, do not surface unlock popups.
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.A_Shard_Of_Glaze,{
		content_type = "Item",
		key = "A_Shard_Of_Glaze",
		name = "A Shard of Glaze",
		remaster_status = "inactive",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.A_Shard_Of_Lava,{
		content_type = "Item",
		key = "A_Shard_Of_Lava",
		name = "A Shard of Lava",
		remaster_status = "inactive",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.A_Shard_Of_Meat,{
		content_type = "Item",
		key = "A_Shard_Of_Meat",
		name = "A Shard of Meat",
		remaster_status = "inactive",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.A_Shard_Of_Rock,{
		content_type = "Item",
		key = "A_Shard_Of_Rock",
		name = "A Shard of Rock",
		remaster_status = "inactive",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Black_Map,{
		content_type = "Item",
		key = "Black_Map",
		name = "Black Map",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Black_Map.png",
})
add("Item",enums.Items.Blaststone,{
		content_type = "Item",
		key = "Blaststone",
		name = "Blaststone",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Brimstream.png",
})
add("Item",enums.Items.Little_Duck,{
		content_type = "Item",
		key = "Little_Duck",
		name = "Little Duck",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Little_Duck.png",
})
add("Item",enums.Items.Alchemy_Pot,{
		content_type = "Item",
		key = "Alchemy_Pot",
		name = "Alchemy Pot",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Alchemy_Pot.png",
})
add("Item",enums.Items.Air_Terror,{
		content_type = "Item",
		key = "Air_Terror",
		name = "Air Terror",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Air_Flight.png",
})
add("Item",enums.Items.Glaze_Mushroom,{
		content_type = "Item",
		key = "Glaze_Mushroom",
		name = "Glaze Mushroom",
		remaster_status = "presentation",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Glazed_Cap.png",
})
add("Item",enums.Items.Pageant_Cross_dresser,{
		content_type = "Item",
		key = "Pageant_Cross_dresser",
		name = "Pageant Cross-dresser",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Pageant_Cross_Dresser.png",
})
add("Item",enums.Items.It_s_a_trick,{
		content_type = "Item",
		key = "It_s_a_trick",
		name = "It's a trick!!",
		remaster_status = "presentation",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_a_tricky_one.png",
})
add("Item",enums.Items.Tianyi,{
		content_type = "Item",
		key = "Tianyi",
		name = "Apocalypse",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_TianYi.png",
})
add("Item",enums.Items.Colorblindness,{
		content_type = "Item",
		key = "Colorblindness",
		name = "Colorblindness",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_ColorBlinder.png",
})
add("Item",enums.Items.Field,{
		content_type = "Item",
		key = "Field",
		name = "Field",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Field.png",
})
add("Item",enums.Items.Suture_Needle,{
		content_type = "Item",
		key = "Suture_Needle",
		name = "Suture Needle",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Suture_Needle.png",
})
add("Item",enums.Items.More_Options___,{
		content_type = "Item",
		key = "More_Options___",
		name = "More Options??!",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_More_Options___.png",
})
add("Item",enums.Items.Fate_s_Draw,{
		content_type = "Item",
		key = "Fate_s_Draw",
		name = "Fate's Draw",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Fate_s_Draw.png",
})
add("Item",enums.Items.My_Emblem,{
		content_type = "Item",
		key = "My_Emblem",
		name = "My Emblem",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_My_Emblem.png",
})
add("Item",enums.Items.Ingestion_to_Night,{
		content_type = "Item",
		key = "Ingestion_to_Night",
		name = "Ingestion to Night",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Ingestion_to_Night.png",
})
add("Item",enums.Items.D773,{
		content_type = "Item",
		key = "D773",
		name = "D773",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_D773.png",
})
add("Item",enums.Items.Devil_s_Heart,{
		content_type = "Item",
		key = "Devil_s_Heart",
		name = "Devil's Heart",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Devil_s_Heart.png",
})
add("Item",enums.Items.DVF,{
		content_type = "Item",
		key = "DVF",
		name = "D-V-F",
		remaster_status = "new",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_DVF.png",
})
add("Item",enums.Items.Book_of_Future,{
		content_type = "Item",
		key = "Book_of_Future",
		name = "Book of Future",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Book_of_Future.png",
})
add("Item",enums.Items.Hyper_Velocity,{
		content_type = "Item",
		key = "Hyper_Velocity",
		name = "Hyper Velocity",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Hyper_Velocity.png",
})
add("Item",enums.Items.Wavering_Eyes,{
		content_type = "Item",
		key = "Wavering_Eyes",
		name = "Wavering Eyes",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_wavering_eye.png",
})
add("Item",enums.Items.Pendulum_Star,{
		content_type = "Item",
		key = "Pendulum_Star",
		name = "Pendulum Star",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Pendulum_star.png",
})
add("Item",enums.Items.Book_of_Thoth,{
		content_type = "Item",
		key = "Book_of_Thoth",
		name = "Book of Thoth",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Book_of_Thoth.png",
})
add("Item",enums.Items.Book_of_The_Law,{
		content_type = "Item",
		key = "Book_of_The_Law",
		name = "Book of The Law",
		remaster_status = "presentation",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Book_of_Law.png",
})
add("Item",enums.Items.Book_of_Vision,{
		content_type = "Item",
		key = "Book_of_Vision",
		name = "Book of Vision",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Book_of_Vision.png",
})
add("Item",enums.Items.Book_of_Voice,{
		content_type = "Item",
		key = "Book_of_Voice",
		name = "Book of Voice",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Book_of_Voice.png",
})
add("Item",enums.Items.Aphasia,{
		content_type = "Item",
		key = "Aphasia",
		name = "Aphasia",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Aphasia.png",
})
add("Item",enums.Items.Nazca,{
		content_type = "Item",
		key = "Nazca",
		name = "Nazca",
		remaster_status = "presentation",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Nazca.png",
})
add("Item",enums.Items.Cloundy,{
		content_type = "Item",
		key = "Cloundy",
		name = "Cloundy",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_cloudy.png",
})
add("Item",enums.Items.Skiel,{
		content_type = "Item",
		key = "Skiel",
		name = "Skiel",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Ilasters.png",
})
add("Item",enums.Items.Wisel,{
		content_type = "Item",
		key = "Wisel",
		name = "Wisel",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Ilasters.png",
})
add("Item",enums.Items.Granel,{
		content_type = "Item",
		key = "Granel",
		name = "Granel",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Ilasters.png",
})
add("Item",enums.Items.Spectralsword,{
		content_type = "Item",
		key = "Spectralsword",
		name = "Spectralsword",
		remaster_status = "new",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_SpectralSword.png",
})
add("Item",enums.Items.Squiresaga,{
		content_type = "Item",
		key = "Squiresaga",
		name = "Squiresaga",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Squiresaga.png",
})
add("Item",enums.Items.Moment,{
		content_type = "Item",
		key = "Moment",
		name = "Moment",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_moment.png",
})
add("Item",enums.Items.Lofty,{
		content_type = "Item",
		key = "Lofty",
		name = "Lofty",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Lofty.png",
})
add("Item",enums.Items.Theseus_s_Sign,{
		content_type = "Item",
		key = "Theseus_s_Sign",
		name = "Theseus's Sign",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_theseus_s_sign.png",
})
add("Item",enums.Items.Heart_Change,{
		content_type = "Item",
		key = "Heart_Change",
		name = "Heart Change",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_HeartChange.png",
})
add("Item",enums.Items.Cable_Jar,{
		content_type = "Item",
		key = "Cable_Jar",
		name = "Cable Jar",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_CableJar.png",
})
add("Item",enums.Items.Gospel,{
		content_type = "Item",
		key = "Gospel",
		name = "Gospel",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_gospel.png",
})
add("Item",enums.Items.Tiramisu,{
		content_type = "Item",
		key = "Tiramisu",
		name = "Tiramisu",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_tiramisu.png",
})
add("Item",enums.Items.Live_Broadcast,{
		content_type = "Item",
		key = "Live_Broadcast",
		name = "Live Broadcast",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_live_Broadcast.png",
})
add("Item",enums.Items.Drama_of_sorrow_and_joy,{
		content_type = "Item",
		key = "Drama_of_sorrow_and_joy",
		name = "Drama of sorrow and joy",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Dosaj.png",
})
add("Item",enums.Items.Tzolkin,{
		content_type = "Item",
		key = "Tzolkin",
		name = "Tzolkin",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Tzolkin.png",
})
add("Item",enums.Items.Pareidolia,{
		content_type = "Item",
		key = "Pareidolia",
		name = "Pareidolia",
		remaster_status = "reworked",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_pareidolia.png",
})
add("Item",enums.Items.Reversal_Film,{
		content_type = "Item",
		key = "Reversal_Film",
		name = "Reversal Film",
		remaster_status = "",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_reversal_film.png",
})
add("Item",enums.Items.Tears_of_Pearl,{
		content_type = "Item",
		key = "Tears_of_Pearl",
		name = "Tears of Pearl",
		remaster_status = "adjusted",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_pearl_tears.png",
})
add("Item",enums.Items.D_NAN,{
		content_type = "Item",
		key = "D_NAN",
		name = "D NAN",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_dnan.png",
})
add("Item",enums.Items.Risemara,{
		content_type = "Item",
		key = "Risemara",
		name = "Risemara",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_risemara.png",
})
add("Item",enums.Items.Chiastolite,{
		content_type = "Item",
		key = "Chiastolite",
		name = "Chiastolite",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Chiastolite.png",
})
add("Item",enums.Items.Annihilation,{
		content_type = "Item",
		key = "Annihilation",
		name = "Annihilation",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Annihilation_,{
		content_type = "Item",
		key = "Annihilation_",
		name = "Annihilation ",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Calamity,{
		content_type = "Item",
		key = "Calamity",
		name = "Calamity",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_sin_worlds.png",
})
add("Item",enums.Items.Shadow_Bottle,{
		content_type = "Item",
		key = "Shadow_Bottle",
		name = "Shadow Bottle",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.The_True_Name,{
		content_type = "Item",
		key = "The_True_Name",
		name = "The True Name",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Blue_Print,{
		content_type = "Item",
		key = "Blue_Print",
		name = "Blue Print",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Dyson_Star,{
		content_type = "Item",
		key = "Dyson_Star",
		name = "Dyson Star",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Hypermnesia,{
		content_type = "Item",
		key = "Hypermnesia",
		name = "Hypermnesia",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Delicate_Flower,{
		content_type = "Item",
		key = "Delicate_Flower",
		name = "Delicate Flower",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Tech_14,{
		content_type = "Item",
		key = "Tech_14",
		name = "Tech 14",
		remaster_status = "presentation",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Seeker_s_Eye,{
		content_type = "Item",
		key = "Seeker_s_Eye",
		name = "Seeker's Eye",
		remaster_status = "reworked",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Day_Dreamer,{
		content_type = "Item",
		key = "Day_Dreamer",
		name = "Day Dreamer",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Disequilibrium,{
		content_type = "Item",
		key = "Disequilibrium",
		name = "Disequilibrium",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Destruction,{
		content_type = "Item",
		key = "Destruction",
		name = "Deconstruction",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Philosopher_s_stone,{
		content_type = "Item",
		key = "Philosopher_s_stone",
		name = "Philosopher's stone",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Brilliant,{
		content_type = "Item",
		key = "Brilliant",
		name = "Brilliant",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Fraternity,{
		content_type = "Item",
		key = "Fraternity",
		name = "Fraternity",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Ending_Count,{
		content_type = "Item",
		key = "Ending_Count",
		name = "Ending Count",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Cheater_s_Blessing,{
		content_type = "Item",
		key = "Cheater_s_Blessing",
		name = "Cheater's Blessing",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Dimension_Contact,{
		content_type = "Item",
		key = "Dimension_Contact",
		name = "Dimension Contact",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.World_Arc,{
		content_type = "Item",
		key = "World_Arc",
		name = "World Arc",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Final_Prism,{
		content_type = "Item",
		key = "Final_Prism",
		name = "Final Prism",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Book_of_Rune,{
		content_type = "Item",
		key = "Book_of_Rune",
		name = "Book of Rune",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Evil_Intervention,{
		content_type = "Item",
		key = "Evil_Intervention",
		name = "Evil Intervention",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Book_of_How_to_Fly,{
		content_type = "Item",
		key = "Book_of_How_to_Fly",
		name = "How to Fly",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Illumination,{
		content_type = "Item",
		key = "Illumination",
		name = "Illumination",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Contemplation,{
		content_type = "Item",
		key = "Contemplation",
		name = "Contemplation",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Chasm,{
		content_type = "Item",
		key = "Chasm",
		name = "Chasm",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Book_of_6_sin,{
		content_type = "Item",
		key = "Book_of_6_sin",
		name = "Book of 6 sin",
		remaster_status = "unchanged",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Book_of_6_sin.png",
})
add("Item",enums.Items.Pathetique,{
		content_type = "Item",
		key = "Pathetique",
		name = "Pathetique",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Dark_Mysticism,{
		content_type = "Item",
		key = "Dark_Mysticism",
		name = "Dark Mysticism",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Fresh_Death,{
		content_type = "Item",
		key = "Fresh_Death",
		name = "Fresh Death",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.The_Suture_Needle,{
		content_type = "Item",
		key = "The_Suture_Needle",
		name = "The Suture Needle",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Glaze_Mirror,{
		content_type = "Item",
		key = "Glaze_Mirror",
		name = "Glaze Mirror",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Mental_Disorder,{
		content_type = "Item",
		key = "Mental_Disorder",
		name = "Mental Disorder",
		remaster_status = "reworked",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Paranoia,{
		content_type = "Item",
		key = "Paranoia",
		name = "Paranoia",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Cursed_Mask,{
		content_type = "Item",
		key = "Cursed_Mask",
		name = "Cursed Mask",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Ritual_Sting,{
		content_type = "Item",
		key = "Ritual_Sting",
		name = "Ritual Sting",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Nihilistic_Artificial_Eye,{
		content_type = "Item",
		key = "Nihilistic_Artificial_Eye",
		name = "Nihilistic Artificial Eye",
		remaster_status = "adjusted",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Phantom_Crown,{
		content_type = "Item",
		key = "Phantom_Crown",
		name = "Phantom Crown",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Blood_Wing,{
		content_type = "Item",
		key = "Blood_Wing",
		name = "Blood Wing",
		remaster_status = "reworked",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Subera_Light,{
		content_type = "Item",
		key = "Subera_Light",
		name = "Subera Light",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.D_Plus,{
		content_type = "Item",
		key = "D_Plus",
		name = "D Plus",
		remaster_status = "adjusted",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Shangrila,{
		content_type = "Item",
		key = "Shangrila",
		name = "Shangrila",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Destiny_Anchor,{
		content_type = "Item",
		key = "Destiny_Anchor",
		name = "Destiny Anchor",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Acrotomophilia,{
		content_type = "Item",
		key = "Acrotomophilia",
		name = "Acrotomophilia",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Loneliness,{
		content_type = "Item",
		key = "Loneliness",
		name = "Loneliness",
		remaster_status = "adjusted",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Core_Brooch,{
		content_type = "Item",
		key = "Core_Brooch",
		name = "Core Brooch",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Inspiration,{
		content_type = "Item",
		key = "Inspiration",
		name = "Fantastic Inspiration",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Hunger_Burger,{
		content_type = "Item",
		key = "Hunger_Burger",
		name = "Hunger Burger",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Muscae_Volitantes,{
		content_type = "Item",
		key = "Muscae_Volitantes",
		name = "Muscae Volitantes",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Charon_s_Sign,{
		content_type = "Item",
		key = "Charon_s_Sign",
		name = "Charon's Sign",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Baby_Tecro,{
		content_type = "Item",
		key = "Baby_Tecro",
		name = "Baby Tecro",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Baby_Anna,{
		content_type = "Item",
		key = "Baby_Anna",
		name = "Baby Anna",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Baby_Zeis,{
		content_type = "Item",
		key = "Baby_Zeis",
		name = "Baby Zeis",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Baby_Marri,{
		content_type = "Item",
		key = "Baby_Marri",
		name = "Baby Marri",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Baby_Autio,{
		content_type = "Item",
		key = "Baby_Autio",
		name = "Baby Autio",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Baby_Lu,{
		content_type = "Item",
		key = "Baby_Lu",
		name = "Baby Lu",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Kaitian,{
		content_type = "Item",
		key = "Kaitian",
		name = "Kaitian",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Multiknife,{
		content_type = "Item",
		key = "Multiknife",
		name = "Multiknife",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Dragon_Tooth,{
		content_type = "Item",
		key = "Dragon_Tooth",
		name = "Dragon Tooth",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Reserved_Judgment,{
		content_type = "Item",
		key = "Reserved_Judgment",
		name = "Reserved Judgment",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Death_Sentence,{
		content_type = "Item",
		key = "Death_Sentence",
		name = "Death Sentence",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Remaster,{
		content_type = "Item",
		key = "Remaster",
		name = "Remaster!",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Bloody_Map,{
		content_type = "Item",
		key = "Bloody_Map",
		name = "Bloody Map",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Golden_Slot,{
		content_type = "Item",
		key = "Golden_Slot",
		name = "Golden Slot",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Procrastination,{
		content_type = "Item",
		key = "Procrastination",
		name = "Procrastination",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Sacred_Mind_Shield,{
		content_type = "Item",
		key = "Sacred_Mind_Shield",
		name = "Sacred Mind Shield",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Qing_Faceted_Market_Diamond,{
		content_type = "Item",
		key = "Qing_Faceted_Market_Diamond",
		name = "Qing's Faceted Market Diamond",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Cup_Cat,{
		content_type = "Item",
		key = "Cup_Cat",
		name = "Cup Cat",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Abiogenesis,{
		content_type = "Item",
		key = "Abiogenesis",
		name = "Abiogenesis",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.The_Voice,{
		content_type = "Item",
		key = "The_Voice",
		name = "The Voice",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Regenesis,{
		content_type = "Item",
		key = "Regenesis",
		name = "Regenesis",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Ember,{
		content_type = "Item",
		key = "Ember",
		name = "Ember",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Perhaps_Chosen,{
		content_type = "Item",
		key = "Perhaps_Chosen",
		name = "Perhaps Chosen",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Zero_Presence,{
		content_type = "Item",
		key = "Zero_Presence",
		name = "Zero Presence",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Pacification_Mark,{
		content_type = "Trinket",
		key = "Pacification_Mark",
		name = "Pacification Mark",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Dark_Particle,{
		content_type = "Trinket",
		key = "Dark_Particle",
		name = "Dark Particle",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Torn_Emperor,{
		content_type = "Trinket",
		key = "Torn_Emperor",
		name = "Torn Emperor",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Devil_s_Joke,{
		content_type = "Trinket",
		key = "Devil_s_Joke",
		name = "Devil's Joke",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Torn_Moon_,{
		content_type = "Trinket",
		key = "Torn_Moon_",
		name = "Torn Moon?",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Puncture_Symbol,{
		content_type = "Trinket",
		key = "Puncture_Symbol",
		name = "Puncture Symbol",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Hoarding_Symbol,{
		content_type = "Trinket",
		key = "Hoarding_Symbol",
		name = "Hoarding Symbol",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Transition_Symbol,{
		content_type = "Trinket",
		key = "Transition_Symbol",
		name = "Transition Symbol",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Adhesive_Symbol,{
		content_type = "Trinket",
		key = "Adhesive_Symbol",
		name = "Adhesive Symbol",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Straining_Symbol,{
		content_type = "Trinket",
		key = "Straining_Symbol",
		name = "Straining Symbol",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Allocation_Symbol,{
		content_type = "Trinket",
		key = "Allocation_Symbol",
		name = "Allocation Symbol",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Pause_,{
		content_type = "Trinket",
		key = "Pause_",
		name = "Pause?",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Equality_Agreement,{
		content_type = "Trinket",
		key = "Equality_Agreement",
		name = "Equality Agreement",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Consistent_Expectations,{
		content_type = "Trinket",
		key = "Consistent_Expectations",
		name = "Consistent Expectations",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Bundled_Sale,{
		content_type = "Trinket",
		key = "Bundled_Sale",
		name = "Bundled Sale",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Broken_Brooch,{
		content_type = "Trinket",
		key = "Broken_Brooch",
		name = "Broken Brooch",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Glaze_dice_shard,{
		content_type = "Card",
		key = "Glaze_dice_shard",
		name = "Glazed Dice Shard",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Qing_s_Soul,{
		content_type = "Card",
		key = "Qing_s_Soul",
		name = "Qing's Soul",
		remaster_status = "",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Soul_of_WQ.png",
})
add("Card",enums.Cards.Round_trip_Rail_Ticket,{
		content_type = "Card",
		key = "Round_trip_Rail_Ticket",
		name = "Round trip Rail Ticket",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.One_way_Rail_Ticket,{
		content_type = "Card",
		key = "One_way_Rail_Ticket",
		name = "One way Rail Ticket",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Fool,{
		content_type = "Card",
		key = "Fool",
		name = "0 - The Fool",
		remaster_status = "reworked",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Witch,{
		content_type = "Card",
		key = "Witch",
		name = "I - The Witch",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Invoker,{
		content_type = "Card",
		key = "Invoker",
		name = "I - The Invoker",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Wizard,{
		content_type = "Card",
		key = "Wizard",
		name = "I - The Wizard",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Priestess,{
		content_type = "Card",
		key = "Priestess",
		name = "II - The High Priestess",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Empress,{
		content_type = "Card",
		key = "Empress",
		name = "III - The Empress",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Emperor,{
		content_type = "Card",
		key = "Emperor",
		name = "IV - The Emperor",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Hierophant,{
		content_type = "Card",
		key = "Hierophant",
		name = "V - The Hierophant",
		remaster_status = "presentation",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Lover,{
		content_type = "Card",
		key = "Lover",
		name = "VI - Lover",
		remaster_status = "reworked",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Chariot,{
		content_type = "Card",
		key = "Chariot",
		name = "VII - Chariot",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Adjustment,{
		content_type = "Card",
		key = "Adjustment",
		name = "VIII - Adjustment",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Hermit,{
		content_type = "Card",
		key = "Hermit",
		name = "IX - The Hermit",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Wheel_of_Destiny,{
		content_type = "Card",
		key = "Wheel_of_Destiny",
		name = "X - The Wheel of Destiny",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Lure,{
		content_type = "Card",
		key = "Lure",
		name = "XI - Lure",
		remaster_status = "reworked",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Hanged_Man,{
		content_type = "Card",
		key = "Hanged_Man",
		name = "XII - The Hanged Man",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Faint,{
		content_type = "Card",
		key = "Faint",
		name = "XIII - Faint",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Art,{
		content_type = "Card",
		key = "Art",
		name = "XIV - Art",
		remaster_status = "reworked",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Devil,{
		content_type = "Card",
		key = "Devil",
		name = "XV - The Devil",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Tower,{
		content_type = "Card",
		key = "Tower",
		name = "XVI - The Tower",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Star,{
		content_type = "Card",
		key = "Star",
		name = "XVII - The Star",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Moon,{
		content_type = "Card",
		key = "Moon",
		name = "XVIII - The Moon",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Sun,{
		content_type = "Card",
		key = "Sun",
		name = "XIX - The Sun",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Aeon,{
		content_type = "Card",
		key = "Aeon",
		name = "XX - The Aeon",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Universe,{
		content_type = "Card",
		key = "Universe",
		name = "XXI - The Universe",
		remaster_status = "adjusted",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Fool_r,{
		content_type = "Card",
		key = "Fool_r",
		name = "0 - The Fool?",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Sage_r,{
		content_type = "Card",
		key = "Sage_r",
		name = "I - The Sage?",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Priestess_r,{
		content_type = "Card",
		key = "Priestess_r",
		name = "II - The High Priestess?",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Empress_r,{
		content_type = "Card",
		key = "Empress_r",
		name = "III - The Empress?",
		remaster_status = "adjusted",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Emperor_r,{
		content_type = "Card",
		key = "Emperor_r",
		name = "IV - The Emperor?",
		remaster_status = "adjusted",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Hierophant_r,{
		content_type = "Card",
		key = "Hierophant_r",
		name = "V - The Hierophant?",
		remaster_status = "adjusted",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Lover_r,{
		content_type = "Card",
		key = "Lover_r",
		name = "VI - The Lover?",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Chariot_r,{
		content_type = "Card",
		key = "Chariot_r",
		name = "VII - The Chariot?",
		remaster_status = "reworked",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Adjustment_r,{
		content_type = "Card",
		key = "Adjustment_r",
		name = "VIII - Adjustment?",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Hermit_r,{
		content_type = "Card",
		key = "Hermit_r",
		name = "IX - The Hermit?",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Wheel_of_Destiny_r,{
		content_type = "Card",
		key = "Wheel_of_Destiny_r",
		name = "X - The Wheel of Destiny?",
		remaster_status = "adjusted",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Lure_r,{
		content_type = "Card",
		key = "Lure_r",
		name = "XI - Lure?",
		remaster_status = "reworked",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Hanged_Man_r,{
		content_type = "Card",
		key = "Hanged_Man_r",
		name = "XII - The Hanged Man?",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Faint_r,{
		content_type = "Card",
		key = "Faint_r",
		name = "XIII - Faint?",
		remaster_status = "reworked",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Death_r,{
		content_type = "Card",
		key = "Death_r",
		name = "XIII - Death?",
		remaster_status = "reworked",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Corpse_r,{
		content_type = "Card",
		key = "Corpse_r",
		name = "XIII - The Corpse?",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Art_r,{
		content_type = "Card",
		key = "Art_r",
		name = "XIV - Art?",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Devil_r,{
		content_type = "Card",
		key = "Devil_r",
		name = "XV - The Devil?",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Tower_r,{
		content_type = "Card",
		key = "Tower_r",
		name = "XVI - The Tower?",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Star_r,{
		content_type = "Card",
		key = "Star_r",
		name = "XVII - The Stars?",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Moon_r,{
		content_type = "Card",
		key = "Moon_r",
		name = "XVIII - The Moon?",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Sun_r,{
		content_type = "Card",
		key = "Sun_r",
		name = "XIX - The Sun?",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Aeon_r,{
		content_type = "Card",
		key = "Aeon_r",
		name = "XX - The Aeon?",
		remaster_status = "reworked",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Universe_r,{
		content_type = "Card",
		key = "Universe_r",
		name = "XXI - The Universe?",
		remaster_status = "presentation",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Eclipse,{
		content_type = "Card",
		key = "Eclipse",
		name = "XIX - The Eclipse",
		remaster_status = "adjusted",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Eclipse_r,{
		content_type = "Card",
		key = "Eclipse_r",
		name = "XIX - The Eclipse?",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Tecro_s_Soul,{
		content_type = "Card",
		key = "Tecro_s_Soul",
		name = "Tecro's Soul",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Anna_s_Soul,{
		content_type = "Card",
		key = "Anna_s_Soul",
		name = "Anna's Soul",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Zeis_s_Soul,{
		content_type = "Card",
		key = "Zeis_s_Soul",
		name = "Zeis's Soul",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Profound,{
		content_type = "Card",
		key = "Profound",
		name = "XXI - The Profound",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Profound_r,{
		content_type = "Card",
		key = "Profound_r",
		name = "XXI - The Profound?",
		remaster_status = "adjusted",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Sting,{
		content_type = "Card",
		key = "Sting",
		name = "V - The Sting",
		remaster_status = "unchanged",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Sting_r,{
		content_type = "Card",
		key = "Sting_r",
		name = "V - The Sting?",
		remaster_status = "reworked",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Oblivion,{
		content_type = "Card",
		key = "Oblivion",
		name = "0 - Oblivion",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Oblivion_r,{
		content_type = "Card",
		key = "Oblivion_r",
		name = "0 - Oblivion?",
		remaster_status = "new",
		achievement = false,
		achievement_path = "",
})
add("Pickup","Glaze_Heart",{
		content_type = "Pickup",
		key = "Glaze_Heart",
		name = "Glaze heart",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Pickup","Glaze_Key",{
		content_type = "Pickup",
		key = "Glaze_Key",
		name = "Glaze key",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Pickup","Glaze_Grabbag",{
		content_type = "Pickup",
		key = "Glaze_Grabbag",
		name = "Glaze grabbag",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Pickup","Glaze_Coin",{
		content_type = "Pickup",
		key = "Glaze_Coin",
		name = "Glaze coin",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Pickup","Glaze_Bomb",{
		content_type = "Pickup",
		key = "Glaze_Bomb",
		name = "Glaze bomb",
		remaster_status = "",
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Glaze_Bomb.png",
})
add("Pickup","Glaze_Battery",{
		content_type = "Pickup",
		key = "Glaze_Battery",
		name = "Glaze battery",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Pickup","Glaze_Chest",{
		content_type = "Pickup",
		key = "Glaze_Chest",
		name = "Glaze chest",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Pickup","Glaze_Poop",{
		content_type = "Pickup",
		key = "Glaze_Poop",
		name = "Glaze big poop",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Pickup","Glaze_Enemy",{
		content_type = "Pickup",
		key = "Glaze_Enemy",
		name = "Glazed Enemy",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Pickup","Glaze_Spider",{
		content_type = "Pickup",
		key = "Glaze_Spider",
		name = "Glazed Spider",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Player","W_Qing",{
		content_type = "Player",
		key = "W_Qing",
		name = "W.Qing",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Player","SP_W_Qing",{
		content_type = "Player",
		key = "SP_W_Qing",
		name = "SP.W.Qing",
		remaster_status = "",
		achievement = false,
		achievement_path = "gfx/ui/Some achievements/achievement_Spwq.png",
})
add("Player","Tecro",{
		content_type = "Player",
		key = "Tecro",
		name = "Tecro",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Player","Tecrorun",{
		content_type = "Player",
		key = "Tecrorun",
		name = "Tecrorun",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Player","Anna",{
		content_type = "Player",
		key = "Anna",
		name = "Anna",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Player","annA",{
		content_type = "Player",
		key = "annA",
		name = "annA",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Player","Zeistos",{
		content_type = "Player",
		key = "Zeistos",
		name = "Zeistos",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Player","Zeiz",{
		content_type = "Player",
		key = "Zeiz",
		name = "Zeiz",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Player","Marriano",{
		content_type = "Player",
		key = "Marriano",
		name = "Marriano",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Player","Autio",{
		content_type = "Player",
		key = "Autio",
		name = "Autio",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})
add("Player","Lu",{
		content_type = "Player",
		key = "Lu",
		name = "Lu",
		remaster_status = "",
		achievement = false,
		achievement_path = "",
})

return data
