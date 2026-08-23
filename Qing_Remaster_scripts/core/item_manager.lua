local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")

local modReference
local Item_manager = {
	items = {},
}

function Item_manager.Init(mod)
	modReference = mod
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Darkness"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Touchstone"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_My_Hat"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Assassin_s_Eye"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Tech_9"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Giant_Punch"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Memory"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Gold_Rush"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Air_Flight"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Super_Bombs"))			--10
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Crown_of_the_Glaze"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Black_Map"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_The_Watcher"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Blaststone"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Brimstream"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Glaze_Cap"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Pageant_Cross_dresser"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Little_Duck"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Glaze_Item"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_TianYi"))				--20
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Mental_Hypnosis"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Colorblindness"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_My_Best_Friend"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Field"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Suture_Needle"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_More_Options"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Fate_s_Draw"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Ingestion_to_Night"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_My_Emblem"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_D773"))					--40
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Devil_s_Heart"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_DVF"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Air_Terror"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Book_of_Future"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Hyper_Velocity"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Wavering_Eyes"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Star_Pendulum"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Book_of_Thoth"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Aphasia"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Book_of_The_Law"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Book_of_Voice"))			--50
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Book_of_Vision"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Nazca"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Cloundy"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Iliaster"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Moment"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Lofty"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Theseus_s_Sign"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Heart_Change"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Cable_Jar"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Tiramisu"))				--60
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Live_Broadcast"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Drama_of_sorrow_and_joy"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Tzolkin"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Pareidolia"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Gospel"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Spectralsword"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Squiresaga"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Alchemy_Pot"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Tears_of_Pearl"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_D_NAN"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Risemara"))				--70
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Chiastolite"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Calamity"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Shadow_Bottle"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_The_True_Name"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Blue_Print"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Delicate_Flower"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Hypermnesia"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Tech_14"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Seeker_s_Eye"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Day_Dreamer"))			--80
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Disequilibrium"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Cheater_s_Blessing"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Philosopher_s_stone"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Ending_Count"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Destruction"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Fraternity"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Brilliant"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Dimension_Contact"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Book_of_Rune"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Final_Prism"))			--90
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_World_Arc"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Book_of_How_to_Fly"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Evil_Intervention"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Illumination"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Contemplation"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Book_of_6_sin"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Pathetique"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Dark_Mysticism"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Chasm"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Annihilation"))			--100
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_The_Suture_Needle"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Paranoia"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Mental_Disorder"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Cursed_Mask"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Nihilistic_Artificial_Eye"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Ritual_Sting"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Subera_Light"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Blood_Wing"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_D_Plus"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Glaze_Mirror"))			--110
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Shangrila"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Destiny_Anchor"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Phantom_Crown"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Acrotomophilia"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Loneliness"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Core_Brooch"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Inspiration"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Hunger_Burger"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Multiknife"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Dragon_Tooth"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Muscae_Volitantes"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Charon_s_Sign"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Dyson_Star"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Reserved_Judgment"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Death_Sentence"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Remaster"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Bloody_Map"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Golden_Slot"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Procrastination"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Sacred_Mind_Shield"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Qing_Faceted_Market_Diamond"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Cup_Cat"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Abiogenesis"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Regenesis"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Ember"))

	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Baby_Tecro"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Baby_Anna"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Baby_Zeis"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Baby_Marri"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Baby_Autio"))
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Item_Baby_Lu"))
	--钝化点数（D773）。Zeis D 系 XML 已停用；Lua 留在 items/Zeiz/，重做时再接：
	-- Item_D_D4, Item_D_Heart, Item_D_Key, Item_D_Bomb, Item_D_RazorBlade, Item_D_Cross,
	-- Item_D_Lusty, Item_D_Flame, Item_D_Rag, Item_D_Trinity, Item_D_Soul,
	-- Item_D_Sacrificalaltar, Item_D_Coin, Item_D_Pointyrib, Item_Book_of_Dull, Item_D_Pack
	table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Zeiz.Item_Dull_items"))
	--table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Zeiz.Item_D_D4"))
	--table.insert(Item_manager.items,#Item_manager.items + 1,require("Qing_Remaster_scripts.items.Zeiz.Item_D_Heart"))
	--Item_manager.MakeItems()
end

function Item_manager.MakeItems()	--没有传入参数。
	for i = 1,#Item_manager.items do
		if Item_manager.items[i].ToCall then
			for j = 1,#(Item_manager.items[i].ToCall) do
				if Item_manager.items[i].ToCall[j] ~= nil and Item_manager.items[i].ToCall[j].Function ~= nil and Item_manager.items[i].ToCall[j].CallBack ~= nil then
					if Item_manager.items[i].ToCall[j].params == nil then
						modReference:AddCallback(Item_manager.items[i].ToCall[j].CallBack,Item_manager.items[i].ToCall[j].Function)
					else
						modReference:AddCallback(Item_manager.items[i].ToCall[j].CallBack,Item_manager.items[i].ToCall[j].Function,Item_manager.items[i].ToCall[j].params)
					end
				end
			end
		end
	end
end

return Item_manager
