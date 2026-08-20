local enums = require("Qing_Remaster_scripts.core.enums")

local data = {Item = {},Trinket = {},Card = {},Pickup = {},Player = {}}
local function add(kind,id,value)
	if type(id) ~= "number" or id <= 0 then return end
	data[kind][id] = value
	if kind == "Item" then data[id] = value end
end

add("Item",enums.Items.Darkness,{
		content_type = "Item",
		key = "Darkness",
		name = "Darkness",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Darkness.png",
})
add("Item",enums.Items.Touchstone,{
		content_type = "Item",
		key = "Touchstone",
		name = "Touchstone",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Touchstone.png",
})
add("Item",enums.Items.My_Hat,{
		content_type = "Item",
		key = "My_Hat",
		name = "My Hat",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_My_Hat.png",
})
add("Item",enums.Items.Tech_9,{
		content_type = "Item",
		key = "Tech_9",
		name = "Tech 9",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Tech_9.png",
})
add("Item",enums.Items.Assassin_s_Eye,{
		content_type = "Item",
		key = "Assassin_s_Eye",
		name = "Assassin's Eye",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Assassin_s_Eye.png",
})
add("Item",enums.Items.Mental_Hypnosis,{
		content_type = "Item",
		key = "Mental_Hypnosis",
		name = "Mental Hypnosis",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Mental_Hypnosis.png",
})
add("Item",enums.Items.Gold_Rush,{
		content_type = "Item",
		key = "Gold_Rush",
		name = "Gold Rush",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Golden_Rush.png",
})
add("Item",enums.Items.Air_Flight,{
		content_type = "Item",
		key = "Air_Flight",
		name = "Air Flight",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Air_Flight.png",
})
add("Item",enums.Items.The_Watcher,{
		content_type = "Item",
		key = "The_Watcher",
		name = "The Watcher",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_The_Watcher.png",
})
add("Item",enums.Items.Giant_Punch,{
		content_type = "Item",
		key = "Giant_Punch",
		name = "Giant Punch",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Gaint_Punch.png",
})
add("Item",enums.Items.Memory,{
		content_type = "Item",
		key = "Memory",
		name = "Memory",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Memory.png",
})
add("Item",enums.Items.My_Best_Friend,{
		content_type = "Item",
		key = "My_Best_Friend",
		name = "My Best Friend",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_My_Best_Friend.png",
})
add("Item",enums.Items.Super_Bombs,{
		content_type = "Item",
		key = "Super_Bombs",
		name = "Super Bombs",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Super_Bombs.png",
})
add("Item",enums.Items.Brimstream,{
		content_type = "Item",
		key = "Brimstream",
		name = "Brimstream",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Brimstream.png",
})
add("Item",enums.Items.Crown_of_the_glaze,{
		content_type = "Item",
		key = "Crown_of_the_glaze",
		name = "Crown of the Glaze",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Glaze_Crown.png",
})
add("Item",enums.Items.A_Shard_Of_Coin,{
		content_type = "Item",
		key = "A_Shard_Of_Coin",
		name = "A Shard of Coin",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Coin_Shard.png",
})
add("Item",enums.Items.A_Shard_Of_Glaze,{
		content_type = "Item",
		key = "A_Shard_Of_Glaze",
		name = "A Shard of Glaze",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.A_Shard_Of_Lava,{
		content_type = "Item",
		key = "A_Shard_Of_Lava",
		name = "A Shard of Lava",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.A_Shard_Of_Meat,{
		content_type = "Item",
		key = "A_Shard_Of_Meat",
		name = "A Shard of Meat",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.A_Shard_Of_Rock,{
		content_type = "Item",
		key = "A_Shard_Of_Rock",
		name = "A Shard of Rock",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Black_Map,{
		content_type = "Item",
		key = "Black_Map",
		name = "Black Map",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Black_Map.png",
})
add("Item",enums.Items.Blaststone,{
		content_type = "Item",
		key = "Blaststone",
		name = "Blaststone",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Brimstream.png",
})
add("Item",enums.Items.Little_Duck,{
		content_type = "Item",
		key = "Little_Duck",
		name = "Little Duck",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Little_Duck.png",
})
add("Item",enums.Items.Alchemy_Pot,{
		content_type = "Item",
		key = "Alchemy_Pot",
		name = "Alchemy Pot",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Alchemy_Pot.png",
})
add("Item",enums.Items.Air_Terror,{
		content_type = "Item",
		key = "Air_Terror",
		name = "Air Terror",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Air_Flight.png",
})
add("Item",enums.Items.Glaze_Mushroom,{
		content_type = "Item",
		key = "Glaze_Mushroom",
		name = "Glaze Mushroom",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Glazed_Cap.png",
})
add("Item",enums.Items.Pageant_Cross_dresser,{
		content_type = "Item",
		key = "Pageant_Cross_dresser",
		name = "Pageant Cross-dresser",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Pageant_Cross_Dresser.png",
})
add("Item",enums.Items.It_s_a_trick,{
		content_type = "Item",
		key = "It_s_a_trick",
		name = "It's a trick!!",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_a_tricky_one.png",
})
add("Item",enums.Items.Tianyi,{
		content_type = "Item",
		key = "Tianyi",
		name = "Apocalypse",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_TianYi.png",
})
add("Item",enums.Items.Colorblindness,{
		content_type = "Item",
		key = "Colorblindness",
		name = "Colorblindness",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_ColorBlinder.png",
})
add("Item",enums.Items.Field,{
		content_type = "Item",
		key = "Field",
		name = "Field",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Field.png",
})
add("Item",enums.Items.Suture_Needle,{
		content_type = "Item",
		key = "Suture_Needle",
		name = "Suture Needle",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Suture_Needle.png",
})
add("Item",enums.Items.More_Options___,{
		content_type = "Item",
		key = "More_Options___",
		name = "More Options??!",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_More_Options___.png",
})
add("Item",enums.Items.Fate_s_Draw,{
		content_type = "Item",
		key = "Fate_s_Draw",
		name = "Fate's Draw",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Fate_s_Draw.png",
})
add("Item",enums.Items.My_Emblem,{
		content_type = "Item",
		key = "My_Emblem",
		name = "My Emblem",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_My_Emblem.png",
})
add("Item",enums.Items.Ingestion_to_Night,{
		content_type = "Item",
		key = "Ingestion_to_Night",
		name = "Ingestion to Night",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Ingestion_to_Night.png",
})
add("Item",enums.Items.D773,{
		content_type = "Item",
		key = "D773",
		name = "D773",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_D773.png",
})
add("Item",enums.Items.Devil_s_Heart,{
		content_type = "Item",
		key = "Devil_s_Heart",
		name = "Devil's Heart",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Devil_s_Heart.png",
})
add("Item",enums.Items.DVF,{
		content_type = "Item",
		key = "DVF",
		name = "D-V-F",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_DVF.png",
})
add("Item",enums.Items.Book_of_Future,{
		content_type = "Item",
		key = "Book_of_Future",
		name = "Book of Future",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Book_of_Future.png",
})
add("Item",enums.Items.Hyper_Velocity,{
		content_type = "Item",
		key = "Hyper_Velocity",
		name = "Hyper Velocity",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Hyper_Velocity.png",
})
add("Item",enums.Items.Wavering_Eyes,{
		content_type = "Item",
		key = "Wavering_Eyes",
		name = "Wavering Eyes",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_wavering_eye.png",
})
add("Item",enums.Items.Pendulum_Star,{
		content_type = "Item",
		key = "Pendulum_Star",
		name = "Pendulum Star",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Pendulum_star.png",
})
add("Item",enums.Items.Book_of_Thoth,{
		content_type = "Item",
		key = "Book_of_Thoth",
		name = "Book of Thoth",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Book_of_Thoth.png",
})
add("Item",enums.Items.Book_of_The_Law,{
		content_type = "Item",
		key = "Book_of_The_Law",
		name = "Book of The Law",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Book_of_Law.png",
})
add("Item",enums.Items.Book_of_Vision,{
		content_type = "Item",
		key = "Book_of_Vision",
		name = "Book of Vision",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Book_of_Vision.png",
})
add("Item",enums.Items.Book_of_Voice,{
		content_type = "Item",
		key = "Book_of_Voice",
		name = "Book of Voice",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Book_of_Voice.png",
})
add("Item",enums.Items.Aphasia,{
		content_type = "Item",
		key = "Aphasia",
		name = "Aphasia",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Aphasia.png",
})
add("Item",enums.Items.Nazca,{
		content_type = "Item",
		key = "Nazca",
		name = "Nazca",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Nazca.png",
})
add("Item",enums.Items.Cloundy,{
		content_type = "Item",
		key = "Cloundy",
		name = "Cloundy",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_cloudy.png",
})
add("Item",enums.Items.Skiel,{
		content_type = "Item",
		key = "Skiel",
		name = "Skiel",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Ilasters.png",
})
add("Item",enums.Items.Wisel,{
		content_type = "Item",
		key = "Wisel",
		name = "Wisel",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Ilasters.png",
})
add("Item",enums.Items.Granel,{
		content_type = "Item",
		key = "Granel",
		name = "Granel",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Ilasters.png",
})
add("Item",enums.Items.Spectralsword,{
		content_type = "Item",
		key = "Spectralsword",
		name = "Spectralsword",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_SpectralSword.png",
})
add("Item",enums.Items.Squiresaga,{
		content_type = "Item",
		key = "Squiresaga",
		name = "Squiresaga",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Squiresaga.png",
})
add("Item",enums.Items.Moment,{
		content_type = "Item",
		key = "Moment",
		name = "Moment",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_moment.png",
})
add("Item",enums.Items.Lofty,{
		content_type = "Item",
		key = "Lofty",
		name = "Lofty",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Lofty.png",
})
add("Item",enums.Items.Theseus_s_Sign,{
		content_type = "Item",
		key = "Theseus_s_Sign",
		name = "Theseus's Sign",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_theseus_s_sign.png",
})
add("Item",enums.Items.Heart_Change,{
		content_type = "Item",
		key = "Heart_Change",
		name = "Heart Change",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_HeartChange.png",
})
add("Item",enums.Items.Cable_Jar,{
		content_type = "Item",
		key = "Cable_Jar",
		name = "Cable Jar",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_CableJar.png",
})
add("Item",enums.Items.Gospel,{
		content_type = "Item",
		key = "Gospel",
		name = "Gospel",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_gospel.png",
})
add("Item",enums.Items.Tiramisu,{
		content_type = "Item",
		key = "Tiramisu",
		name = "Tiramisu",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_tiramisu.png",
})
add("Item",enums.Items.Live_Broadcast,{
		content_type = "Item",
		key = "Live_Broadcast",
		name = "Live Broadcast",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_live_Broadcast.png",
})
add("Item",enums.Items.Drama_of_sorrow_and_joy,{
		content_type = "Item",
		key = "Drama_of_sorrow_and_joy",
		name = "Drama of sorrow and joy",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Dosaj.png",
})
add("Item",enums.Items.Tzolkin,{
		content_type = "Item",
		key = "Tzolkin",
		name = "Tzolkin",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Tzolkin.png",
})
add("Item",enums.Items.Pareidolia,{
		content_type = "Item",
		key = "Pareidolia",
		name = "Pareidolia",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_pareidolia.png",
})
add("Item",enums.Items.Reversal_Film,{
		content_type = "Item",
		key = "Reversal_Film",
		name = "Reversal Film",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_reversal_film.png",
})
add("Item",enums.Items.Tears_of_Pearl,{
		content_type = "Item",
		key = "Tears_of_Pearl",
		name = "Tears of Pearl",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_pearl_tears.png",
})
add("Item",enums.Items.D_NAN,{
		content_type = "Item",
		key = "D_NAN",
		name = "D NAN",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_dnan.png",
})
add("Item",enums.Items.Risemara,{
		content_type = "Item",
		key = "Risemara",
		name = "Risemara",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_risemara.png",
})
add("Item",enums.Items.Chiastolite,{
		content_type = "Item",
		key = "Chiastolite",
		name = "Chiastolite",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Chiastolite.png",
})
add("Item",enums.Items.Annihilation,{
		content_type = "Item",
		key = "Annihilation",
		name = "Annihilation",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Annihilation_,{
		content_type = "Item",
		key = "Annihilation_",
		name = "Annihilation ",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Calamity,{
		content_type = "Item",
		key = "Calamity",
		name = "Calamity",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Shadow_Bottle,{
		content_type = "Item",
		key = "Shadow_Bottle",
		name = "Shadow Bottle",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.The_True_Name,{
		content_type = "Item",
		key = "The_True_Name",
		name = "The True Name",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Blue_Print,{
		content_type = "Item",
		key = "Blue_Print",
		name = "Blue Print",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Dyson_Star,{
		content_type = "Item",
		key = "Dyson_Star",
		name = "Dyson Star",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Hypermnesia,{
		content_type = "Item",
		key = "Hypermnesia",
		name = "Hypermnesia",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Delicate_Flower,{
		content_type = "Item",
		key = "Delicate_Flower",
		name = "Delicate Flower",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Tech_14,{
		content_type = "Item",
		key = "Tech_14",
		name = "Tech 14",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Seeker_s_Eye,{
		content_type = "Item",
		key = "Seeker_s_Eye",
		name = "Seeker's Eye",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Day_Dreamer,{
		content_type = "Item",
		key = "Day_Dreamer",
		name = "Day Dreamer",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Disequilibrium,{
		content_type = "Item",
		key = "Disequilibrium",
		name = "Disequilibrium",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Destruction,{
		content_type = "Item",
		key = "Destruction",
		name = "Deconstruction",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Philosopher_s_stone,{
		content_type = "Item",
		key = "Philosopher_s_stone",
		name = "Philosopher's stone",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Brilliant,{
		content_type = "Item",
		key = "Brilliant",
		name = "Brilliant",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Fraternity,{
		content_type = "Item",
		key = "Fraternity",
		name = "Fraternity",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Ending_Count,{
		content_type = "Item",
		key = "Ending_Count",
		name = "Ending Count",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Cheater_s_Blessing,{
		content_type = "Item",
		key = "Cheater_s_Blessing",
		name = "Cheater's Blessing",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Dimension_Contact,{
		content_type = "Item",
		key = "Dimension_Contact",
		name = "Dimension Contact",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.World_Arc,{
		content_type = "Item",
		key = "World_Arc",
		name = "World Arc",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Final_Prism,{
		content_type = "Item",
		key = "Final_Prism",
		name = "Final Prism",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Book_of_Rune,{
		content_type = "Item",
		key = "Book_of_Rune",
		name = "Book of Rune",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Evil_Intervention,{
		content_type = "Item",
		key = "Evil_Intervention",
		name = "Evil Intervention",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Book_of_How_to_Fly,{
		content_type = "Item",
		key = "Book_of_How_to_Fly",
		name = "How to Fly",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Illumination,{
		content_type = "Item",
		key = "Illumination",
		name = "Illumination",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Contemplation,{
		content_type = "Item",
		key = "Contemplation",
		name = "Contemplation",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Chasm,{
		content_type = "Item",
		key = "Chasm",
		name = "Chasm",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Book_of_6_sin,{
		content_type = "Item",
		key = "Book_of_6_sin",
		name = "Book of 6 sin",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Book_of_6_sin.png",
})
add("Item",enums.Items.Pathetique,{
		content_type = "Item",
		key = "Pathetique",
		name = "Pathetique",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Dark_Mysticism,{
		content_type = "Item",
		key = "Dark_Mysticism",
		name = "Dark Mysticism",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Fresh_Death,{
		content_type = "Item",
		key = "Fresh_Death",
		name = "Fresh Death",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.The_Suture_Needle,{
		content_type = "Item",
		key = "The_Suture_Needle",
		name = "The Suture Needle",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Glaze_Mirror,{
		content_type = "Item",
		key = "Glaze_Mirror",
		name = "Glaze Mirror",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Mental_Disorder,{
		content_type = "Item",
		key = "Mental_Disorder",
		name = "Mental Disorder",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Paranoia,{
		content_type = "Item",
		key = "Paranoia",
		name = "Paranoia",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Cursed_Mask,{
		content_type = "Item",
		key = "Cursed_Mask",
		name = "Cursed Mask",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Ritual_Sting,{
		content_type = "Item",
		key = "Ritual_Sting",
		name = "Ritual Sting",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Nihilistic_Artificial_Eye,{
		content_type = "Item",
		key = "Nihilistic_Artificial_Eye",
		name = "Nihilistic Artificial Eye",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Phantom_Crown,{
		content_type = "Item",
		key = "Phantom_Crown",
		name = "Phantom Crown",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Blood_Wing,{
		content_type = "Item",
		key = "Blood_Wing",
		name = "Blood Wing",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Subera_Light,{
		content_type = "Item",
		key = "Subera_Light",
		name = "Subera Light",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.D_Plus,{
		content_type = "Item",
		key = "D_Plus",
		name = "D Plus",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Shangrila,{
		content_type = "Item",
		key = "Shangrila",
		name = "Shangrila",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Destiny_Anchor,{
		content_type = "Item",
		key = "Destiny_Anchor",
		name = "Destiny Anchor",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Acrotomophilia,{
		content_type = "Item",
		key = "Acrotomophilia",
		name = "Acrotomophilia",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Loneliness,{
		content_type = "Item",
		key = "Loneliness",
		name = "Loneliness",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Core_Brooch,{
		content_type = "Item",
		key = "Core_Brooch",
		name = "Core Brooch",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Inspiration,{
		content_type = "Item",
		key = "Inspiration",
		name = "Fantastic Inspiration",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Hunger_Burger,{
		content_type = "Item",
		key = "Hunger_Burger",
		name = "Hunger Burger",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Muscae_Volitantes,{
		content_type = "Item",
		key = "Muscae_Volitantes",
		name = "Muscae Volitantes",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Charon_s_Sign,{
		content_type = "Item",
		key = "Charon_s_Sign",
		name = "Charon's Sign",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Baby_Tecro,{
		content_type = "Item",
		key = "Baby_Tecro",
		name = "Baby Tecro",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Baby_Anna,{
		content_type = "Item",
		key = "Baby_Anna",
		name = "Baby Anna",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Baby_Zeis,{
		content_type = "Item",
		key = "Baby_Zeis",
		name = "Baby Zeis",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Baby_Marri,{
		content_type = "Item",
		key = "Baby_Marri",
		name = "Baby Marri",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Baby_Autio,{
		content_type = "Item",
		key = "Baby_Autio",
		name = "Baby Autio",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Baby_Lu,{
		content_type = "Item",
		key = "Baby_Lu",
		name = "Baby Lu",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Kaitian,{
		content_type = "Item",
		key = "Kaitian",
		name = "Kaitian",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Multiknife,{
		content_type = "Item",
		key = "Multiknife",
		name = "Multiknife",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Dragon_Tooth,{
		content_type = "Item",
		key = "Dragon_Tooth",
		name = "Dragon Tooth",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.DI_III,{
		content_type = "Item",
		key = "DI_III",
		name = "D_IIII",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.D_Heart,{
		content_type = "Item",
		key = "D_Heart",
		name = "D Heart",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.D_Key,{
		content_type = "Item",
		key = "D_Key",
		name = "D Key",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.D_Bomb,{
		content_type = "Item",
		key = "D_Bomb",
		name = "D Bomb",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.D_RazorBlade,{
		content_type = "Item",
		key = "D_RazorBlade",
		name = "D RazorBlade",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.D_Cross,{
		content_type = "Item",
		key = "D_Cross",
		name = "D Cross",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.D_Lusty,{
		content_type = "Item",
		key = "D_Lusty",
		name = "D Lusty",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.D_Flame,{
		content_type = "Item",
		key = "D_Flame",
		name = "D Flame",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.D_Rag,{
		content_type = "Item",
		key = "D_Rag",
		name = "D Rag",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.D_Trinity,{
		content_type = "Item",
		key = "D_Trinity",
		name = "D Trinity",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.D_Soul,{
		content_type = "Item",
		key = "D_Soul",
		name = "D Soul",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.D_Sacrificalaltar,{
		content_type = "Item",
		key = "D_Sacrificalaltar",
		name = "D Sacrificalaltar",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.D_Coin,{
		content_type = "Item",
		key = "D_Coin",
		name = "D Coin",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.D_Pointyrib,{
		content_type = "Item",
		key = "D_Pointyrib",
		name = "D Pointyrib",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Book_of_Dull,{
		content_type = "Item",
		key = "Book_of_Dull",
		name = "Book of Dull",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.D_Pack,{
		content_type = "Item",
		key = "D_Pack",
		name = "D Pack",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Reserved_Judgment,{
		content_type = "Item",
		key = "Reserved_Judgment",
		name = "Reserved Judgment",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Death_Sentence,{
		content_type = "Item",
		key = "Death_Sentence",
		name = "Death Sentence",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Remaster,{
		content_type = "Item",
		key = "Remaster",
		name = "Remaster!",
		artwork = true,
		effect = false,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Bloody_Map,{
		content_type = "Item",
		key = "Bloody_Map",
		name = "Bloody Map",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Golden_Slot,{
		content_type = "Item",
		key = "Golden_Slot",
		name = "Golden Slot",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Procrastination,{
		content_type = "Item",
		key = "Procrastination",
		name = "Procrastination",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Sacred_Mind_Shield,{
		content_type = "Item",
		key = "Sacred_Mind_Shield",
		name = "Sacred Mind Shield",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Qing_Faceted_Market_Diamond,{
		content_type = "Item",
		key = "Qing_Faceted_Market_Diamond",
		name = "Qing's Faceted Market Diamond",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Cup_Cat,{
		content_type = "Item",
		key = "Cup_Cat",
		name = "Cup Cat",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Abiogenesis,{
		content_type = "Item",
		key = "Abiogenesis",
		name = "Abiogenesis",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.The_Voice,{
		content_type = "Item",
		key = "The_Voice",
		name = "The Voice",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Item",enums.Items.Regenesis,{
		content_type = "Item",
		key = "Regenesis",
		name = "Regenesis",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Pacification_Mark,{
		content_type = "Trinket",
		key = "Pacification_Mark",
		name = "Pacification Mark",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Dark_Particle,{
		content_type = "Trinket",
		key = "Dark_Particle",
		name = "Dark Particle",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Torn_Emperor,{
		content_type = "Trinket",
		key = "Torn_Emperor",
		name = "Torn Emperor",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Devil_s_Joke,{
		content_type = "Trinket",
		key = "Devil_s_Joke",
		name = "Devil's Joke",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Torn_Moon_,{
		content_type = "Trinket",
		key = "Torn_Moon_",
		name = "Torn Moon?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Puncture_Symbol,{
		content_type = "Trinket",
		key = "Puncture_Symbol",
		name = "Puncture Symbol",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Hoarding_Symbol,{
		content_type = "Trinket",
		key = "Hoarding_Symbol",
		name = "Hoarding Symbol",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Transition_Symbol,{
		content_type = "Trinket",
		key = "Transition_Symbol",
		name = "Transition Symbol",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Adhesive_Symbol,{
		content_type = "Trinket",
		key = "Adhesive_Symbol",
		name = "Adhesive Symbol",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Straining_Symbol,{
		content_type = "Trinket",
		key = "Straining_Symbol",
		name = "Straining Symbol",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Allocation_Symbol,{
		content_type = "Trinket",
		key = "Allocation_Symbol",
		name = "Allocation Symbol",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Pause_,{
		content_type = "Trinket",
		key = "Pause_",
		name = "Pause?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Equality_Agreement,{
		content_type = "Trinket",
		key = "Equality_Agreement",
		name = "Equality Agreement",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Consistent_Expectations,{
		content_type = "Trinket",
		key = "Consistent_Expectations",
		name = "Consistent Expectations",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Bundled_Sale,{
		content_type = "Trinket",
		key = "Bundled_Sale",
		name = "Bundled Sale",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Trinket",enums.Trinkets.Broken_Brooch,{
		content_type = "Trinket",
		key = "Broken_Brooch",
		name = "Broken Brooch",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Glaze_dice_shard,{
		content_type = "Card",
		key = "Glaze_dice_shard",
		name = "Glazed Dice Shard",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Qing_s_Soul,{
		content_type = "Card",
		key = "Qing_s_Soul",
		name = "Qing's Soul",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Soul_of_WQ.png",
})
add("Card",enums.Cards.Round_trip_Rail_Ticket,{
		content_type = "Card",
		key = "Round_trip_Rail_Ticket",
		name = "Round trip Rail Ticket",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.One_way_Rail_Ticket,{
		content_type = "Card",
		key = "One_way_Rail_Ticket",
		name = "One way Rail Ticket",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Fool,{
		content_type = "Card",
		key = "Fool",
		name = "0 - The Fool",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Witch,{
		content_type = "Card",
		key = "Witch",
		name = "I - The Witch",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Invoker,{
		content_type = "Card",
		key = "Invoker",
		name = "I - The Invoker",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Wizard,{
		content_type = "Card",
		key = "Wizard",
		name = "I - The Wizard",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Priestess,{
		content_type = "Card",
		key = "Priestess",
		name = "II - The High Priestess",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Empress,{
		content_type = "Card",
		key = "Empress",
		name = "III - The Empress",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Emperor,{
		content_type = "Card",
		key = "Emperor",
		name = "IV - The Emperor",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Hierophant,{
		content_type = "Card",
		key = "Hierophant",
		name = "V - The Hierophant",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Lover,{
		content_type = "Card",
		key = "Lover",
		name = "VI - Lover",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Chariot,{
		content_type = "Card",
		key = "Chariot",
		name = "VII - Chariot",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Adjustment,{
		content_type = "Card",
		key = "Adjustment",
		name = "VIII - Adjustment",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Hermit,{
		content_type = "Card",
		key = "Hermit",
		name = "IX - The Hermit",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Wheel_of_Destiny,{
		content_type = "Card",
		key = "Wheel_of_Destiny",
		name = "X - The Wheel of Destiny",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Lure,{
		content_type = "Card",
		key = "Lure",
		name = "XI - Lure",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Hanged_Man,{
		content_type = "Card",
		key = "Hanged_Man",
		name = "XII - The Hanged Man",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Faint,{
		content_type = "Card",
		key = "Faint",
		name = "XIII - Faint",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Art,{
		content_type = "Card",
		key = "Art",
		name = "XIV - Art",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Devil,{
		content_type = "Card",
		key = "Devil",
		name = "XV - The Devil",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Tower,{
		content_type = "Card",
		key = "Tower",
		name = "XVI - The Tower",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Star,{
		content_type = "Card",
		key = "Star",
		name = "XVII - The Star",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Moon,{
		content_type = "Card",
		key = "Moon",
		name = "XVIII - The Moon",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Sun,{
		content_type = "Card",
		key = "Sun",
		name = "XIX - The Sun",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Aeon,{
		content_type = "Card",
		key = "Aeon",
		name = "XX - The Aeon",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Universe,{
		content_type = "Card",
		key = "Universe",
		name = "XXI - The Universe",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Fool_r,{
		content_type = "Card",
		key = "Fool_r",
		name = "0 - The Fool?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Sage_r,{
		content_type = "Card",
		key = "Sage_r",
		name = "I - The Sage?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Priestess_r,{
		content_type = "Card",
		key = "Priestess_r",
		name = "II - The High Priestess?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Empress_r,{
		content_type = "Card",
		key = "Empress_r",
		name = "III - The Empress?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Emperor_r,{
		content_type = "Card",
		key = "Emperor_r",
		name = "IV - The Emperor?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Hierophant_r,{
		content_type = "Card",
		key = "Hierophant_r",
		name = "V - The Hierophant?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Lover_r,{
		content_type = "Card",
		key = "Lover_r",
		name = "VI - The Lover?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Chariot_r,{
		content_type = "Card",
		key = "Chariot_r",
		name = "VII - The Chariot?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Adjustment_r,{
		content_type = "Card",
		key = "Adjustment_r",
		name = "VIII - Adjustment?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Hermit_r,{
		content_type = "Card",
		key = "Hermit_r",
		name = "IX - The Hermit?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Wheel_of_Destiny_r,{
		content_type = "Card",
		key = "Wheel_of_Destiny_r",
		name = "X - The Wheel of Destiny?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Lure_r,{
		content_type = "Card",
		key = "Lure_r",
		name = "XI - Lure?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Hanged_Man_r,{
		content_type = "Card",
		key = "Hanged_Man_r",
		name = "XII - The Hanged Man?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Faint_r,{
		content_type = "Card",
		key = "Faint_r",
		name = "XIII - Faint?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Death_r,{
		content_type = "Card",
		key = "Death_r",
		name = "XIII - Death?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Corpse_r,{
		content_type = "Card",
		key = "Corpse_r",
		name = "XIII - The Corpse?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Art_r,{
		content_type = "Card",
		key = "Art_r",
		name = "XIV - Art?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Devil_r,{
		content_type = "Card",
		key = "Devil_r",
		name = "XV - The Devil?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Tower_r,{
		content_type = "Card",
		key = "Tower_r",
		name = "XVI - The Tower?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Star_r,{
		content_type = "Card",
		key = "Star_r",
		name = "XVII - The Stars?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Moon_r,{
		content_type = "Card",
		key = "Moon_r",
		name = "XVIII - The Moon?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Sun_r,{
		content_type = "Card",
		key = "Sun_r",
		name = "XIX - The Sun?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Aeon_r,{
		content_type = "Card",
		key = "Aeon_r",
		name = "XX - The Aeon?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Universe_r,{
		content_type = "Card",
		key = "Universe_r",
		name = "XXI - The Universe?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Eclipse,{
		content_type = "Card",
		key = "Eclipse",
		name = "XIX - The Eclipse",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Eclipse_r,{
		content_type = "Card",
		key = "Eclipse_r",
		name = "XIX - The Eclipse?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Tecro_s_Soul,{
		content_type = "Card",
		key = "Tecro_s_Soul",
		name = "Tecro's Soul",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Anna_s_Soul,{
		content_type = "Card",
		key = "Anna_s_Soul",
		name = "Anna's Soul",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Zeis_s_Soul,{
		content_type = "Card",
		key = "Zeis_s_Soul",
		name = "Zeis's Soul",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Profound,{
		content_type = "Card",
		key = "Profound",
		name = "XXI - The Profound",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Profound_r,{
		content_type = "Card",
		key = "Profound_r",
		name = "XXI - The Profound?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Sting,{
		content_type = "Card",
		key = "Sting",
		name = "V - The Sting",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Card",enums.Cards.Sting_r,{
		content_type = "Card",
		key = "Sting_r",
		name = "V - The Sting?",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Pickup","Glaze_Heart",{
		content_type = "Pickup",
		key = "Glaze_Heart",
		name = "Glaze heart",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Pickup","Glaze_Key",{
		content_type = "Pickup",
		key = "Glaze_Key",
		name = "Glaze key",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Pickup","Glaze_Grabbag",{
		content_type = "Pickup",
		key = "Glaze_Grabbag",
		name = "Glaze grabbag",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Pickup","Glaze_Coin",{
		content_type = "Pickup",
		key = "Glaze_Coin",
		name = "Glaze coin",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Pickup","Glaze_Bomb",{
		content_type = "Pickup",
		key = "Glaze_Bomb",
		name = "Glaze bomb",
		artwork = true,
		effect = true,
		achievement = true,
		achievement_path = "gfx/ui/Some achievements/achievement_Glaze_Bomb.png",
})
add("Pickup","Glaze_Battery",{
		content_type = "Pickup",
		key = "Glaze_Battery",
		name = "Glaze battery",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Pickup","Glaze_Chest",{
		content_type = "Pickup",
		key = "Glaze_Chest",
		name = "Glaze chest",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Pickup","Glaze_Poop",{
		content_type = "Pickup",
		key = "Glaze_Poop",
		name = "Glaze big poop",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Pickup","Glaze_Enemy",{
		content_type = "Pickup",
		key = "Glaze_Enemy",
		name = "Glazed Enemy",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Pickup","Glaze_Spider",{
		content_type = "Pickup",
		key = "Glaze_Spider",
		name = "Glazed Spider",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Player","W_Qing",{
		content_type = "Player",
		key = "W_Qing",
		name = "W.Qing",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Player","SP_W_Qing",{
		content_type = "Player",
		key = "SP_W_Qing",
		name = "SP.W.Qing",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "gfx/ui/Some achievements/achievement_Spwq.png",
})
add("Player","Tecro",{
		content_type = "Player",
		key = "Tecro",
		name = "Tecro",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Player","Tecrorun",{
		content_type = "Player",
		key = "Tecrorun",
		name = "Tecrorun",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Player","Anna",{
		content_type = "Player",
		key = "Anna",
		name = "Anna",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Player","annA",{
		content_type = "Player",
		key = "annA",
		name = "annA",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Player","Zeistos",{
		content_type = "Player",
		key = "Zeistos",
		name = "Zeistos",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Player","Zeiz",{
		content_type = "Player",
		key = "Zeiz",
		name = "Zeiz",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Player","Marriano",{
		content_type = "Player",
		key = "Marriano",
		name = "Marriano",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Player","Autio",{
		content_type = "Player",
		key = "Autio",
		name = "Autio",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})
add("Player","Lu",{
		content_type = "Player",
		key = "Lu",
		name = "Lu",
		artwork = true,
		effect = true,
		achievement = false,
		achievement_path = "",
})

return data
