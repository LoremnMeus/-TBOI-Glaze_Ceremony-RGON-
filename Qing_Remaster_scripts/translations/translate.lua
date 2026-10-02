local enums = require("Qing_Remaster_scripts.core.enums")
local Items = enums.Items
local Cards = enums.Cards
local Trinkets = enums.Trinkets
local Players = enums.Players
local Pickups = enums.Pickups

local function eidButton(action)
    if EID and EID.ButtonToIconMap and action then
        return EID.ButtonToIconMap[action] or ""
    end
    return ""
end

local item = {
    en = {},
    zh = {},
    en_us = {},
    zh_cn = {},
    Reverse = {},
}

item.Collectibles = {
    [1] = {
        Name = "暗之六面",
        id = Items.Darkness,
        type = "passive",
        xmlId = 1,
        zh = {
            Name = "暗之六面",
            Desc = "湮灭于未知",
            Description = "{{BlackHeart}} +1黑心"..
            "#!!! 将普通生命体系变为魂心体系"..
            "#{{Damage}} 按黑心数量增加攻击"..
            "#{{BlackHeart}} 击杀敌人逐渐将魂心染成黑心，或填满半黑心"..
            "#{{DevilRoom}} {{BlackHeart}} 黑心可以等价代替{{Heart}}红心进行恶魔交易",
            AbyssSynic = "纯黑蝗虫，杀死敌人时有概率掉落黑心",
        },
        en = {
            Name = "Darkness",
            Desc = "Buried in the past.",
            Description = "{{BlackHeart}} +1 Black Heart"..
            "#!!! Converts standard health into a soul-heart system"..
            "#{{Damage}} Damage up based on black hearts"..
            "#{{BlackHeart}} Kills gradually stain soul hearts into black hearts, or fill half black heart"..
            "#{{DevilRoom}} {{BlackHeart}} Black hearts can replace red-heart devil deal costs",
            AbyssSynic = "Pure black locust with chance to drop black hearts on kill",
        },
    },
    [2] = {
        Name = "无名刃·弑金",
        id = Items.Touchstone,
        type = "active",
        xmlId = 2,
        zh = {
            Name = "无名刃·弑金",
            Desc = "借来我的刀法",
            Description = "#{{Player"..Players.wq.."}} 使用后，本房间内攻击方式变为青的刀法",
            AbyssSynic = "蝗虫命中敌人后发动刺击",
            BookOfBelial = "使用后，青的刀法额外视为拥有硫磺火",
        },
        en = {
            Name = "Touchstone",
            Desc = "Borrow my blade",
            Description = "#{{Player"..Players.wq.."}} On use, replaces your attack with Qing's blade style for the current room",
            AbyssSynic = "Locust that stab at enemies",
            BookOfBelial = "On use, Qing's blade style additionally counts as having Brimstone",
        },
    },
    [3] = {
        Name = "青的帽子",
        id = Items.My_Hat,
        type = "passive",
        xmlId = 3,
        zh = {
            Name = "青的帽子",
            Desc = "太大了！",
            Description = "头上的帽子会阻挡接触到它的敌方弹幕"..
            "#攻击时将帽子向前掷出，沿途清除附近弹幕"..
            "#命中敌人后将其罩住并减速，同时继续阻挡周围弹幕",
        },
        en = {
            Name = "Qing's Hat",
            Desc = "It's too big!",
            Description = "The hat blocks enemy projectiles that touch it while worn"..
            "#Firing throws it forward, clearing nearby projectiles along its path"..
            "#Enemies hit are covered and slowed while the hat continues blocking nearby projectiles",
        },
    },
    [4] = {
        Name = "科技IX",
        id = Items.Tech_9,
        type = "passive",
        xmlId = 4,
        zh = {
            Name = "科技IX",
            Desc = "被跳过的未来",
            Description = "攻击有概率追加科技激光或科技X激光环",
            AbyssSynic = "蝗虫有概率伴生科技X激光环",
        },
        en = {
            Name = "Tech IX",
            Desc = "Skipped, looped, returned.",
            Description = "Attacks have a chance to add a Technology laser or Tech X ring",
            AbyssSynic = "Locusts have a chance to spawn with a Tech X ring.",
        },
    },
    [5] = {
        Name = "刺杀者之眼",
        id = Items.Assassin_s_Eye,
        type = "passive",
        xmlId = 5,
        zh = {
            Name = "刺杀者之眼",
            Desc = "彗星袭月",
            Description = "泪弹会伺机刺向附近的敌人",
            AbyssSynic = "蝗虫学会暗杀",
        },
        en = {
            Name = "Assassin's Eye",
            Desc = "Savour the Dark",
            Description = "Tears will seize openings to strike nearby enemies",
            AbyssSynic = "Locust assassinates enemies when closed",
        },
    },
    [6] = {
        Name = "精神控制",
        id = Items.Mental_Hypnosis,
        type = "passive",
        xmlId = 6,
        zh = {
            Name = "精神控制",
            Desc = "劳驾你，照做吧",
            Description = "{{TreasureRoom}} 每层生成一串特殊房间指令"..
            "#依次进入对应特殊房间，每次成功获得奖励"..
            "#{{Warning}} 提前进入其他特殊房间会受到惩罚",
            AbyssSynic = "彩色蝗虫",
        },
        en = {
            Name = "Mental Hypnosis",
            Desc = "Would you kindly?",
            Description = "{{TreasureRoom}} Each floor creates an ordered list of special rooms"..
            "#Enter matching special rooms in order; each success grants a reward"..
            "#{{Warning}} Entering other special rooms early causes a punishment",
        },
    },
    [7] = {
        Name = "淘金热",
        id = Items.Gold_Rush,
        type = "passive",
        xmlId = 7,
        zh = {
            Name = "淘金热",
            Desc = "发光的不都是金子",
            Description = "进入新房间时，部分岩石会变成{{ColorGold}}愚人金{{CR}}"..
            "#摧毁愚人金可能发现硬币、特殊奖励，或受惊逃走的老鼠",
            AbyssSynic = "金色蝗虫，命中敌人时小概率施加点金",
        },
        en = {
            Name = "Gold Rush",
            Desc = "All that glitters...",
            Description = "Entering a new room can turn some rocks into {{ColorGold}}fool's gold{{CR}}"..
            "#Destroying fool's gold may uncover coins, special finds, or startled fleeing rats",
            AbyssSynic = "Golden locust with a small chance to turn enemies gold on hit",
        },
    },
    [8] = {
        Name = "空行零号-试做版",
        id = Items.Air_Flight,
        type = "passive",
        xmlId = 8,
        zh = {
            Name = "空行零号-试做版",
            Desc = "滴..注入成功..",
            Description = "与你攻击方式相同，自动攻击敌人的小跟班",
            SeijaNerf = "小跟班的攻速减半",
        },
        en = {
            Name = "AF-00 Prototype",
            Desc = "Hello World",
            Description = "A baby mimics your attack and automaticly targets enemies",
            SeijaNerf = "Half the baby's fire rate.",
        },
    },
    [9] = {
        Name = "监视",
        id = Items.The_Watcher,
        type = "passive",
        xmlId = 9,
        zh = {
            Name = "监视",
            Desc = "老大哥在看着你",
            Description = "{{Speed}} 移速不会低于1.5"..
            "#{{Warning}} 低速时展开逐渐扩大的监视域，锁定自身与附近敌人"..
            "#锁定完成后爆炸，伤害为{{Damage}}攻击力 ×4 +20"..
            "#地上的监视也会锁定附近目标并开火",
            SeijaBuff = "监视范围扩展至全房间，并免疫监视造成的爆炸",
        },
        en = {
            Name = "The Watcher",
            Desc = "Big Brother is watching",
            Description = "{{Speed}} Move speed cannot fall below 1.5"..
            "#{{Warning}} Moving slowly expands a watch zone that locks onto you and nearby enemies"..
            "#Full locks explode for {{Damage}} Damage ×4 +20"..
            "#While on the ground, The Watcher also locks onto nearby targets and fires",
            SeijaBuff = "Watch range becomes room-wide and Watcher explosions cannot hurt you",
        },
    },
    [10] = {
        Name = "巨大化",
        id = Items.Giant_Punch,
        type = "passive",
        xmlId = 10,
        zh = {
            Name = "巨大化",
            Desc = "神※拳※粉※碎",
            Description = "↑ 生命未满时，角色巨大化，攻击翻倍"..
            "#↓ 满血后拥有额外生命时，角色缩小，攻击减半",
            AbyssSynic = "稍大的蝗虫",
        },
        en = {
            Name = "Giant Punch",
            Desc = "God-o-hand-o-Crash!",
            Description = "↑ While below normal full health, grow larger and deal double damage"..
            "#↓ While holding health beyond normal capacity, shrink and deal half damage",
        },
    },
    [11] = {
        Name = "回忆",
        id = Items.Memory,
        type = "active",
        xmlId = 11,
        zh = {
            Name = "回忆",
            Desc = "我好像掉进了一个怪圈...",
            Description = "!!! 一次性"..
            "#本局后续道具只会从角色已拥有的道具中生成"..
            "#重复持有会提高再次出现的概率",
            AbyssSynic = "彩色蝗虫",
            BookOfBelial = "50%概率改为从恶魔房道具池生成",
            BookOfVirtues = "熄灭时结束回忆效果的魂火"..
            "#↑ 每个重复的道具少量将其加强"..
            "#进入新房间后魂火回复到满状态",
        },
        en = {
            Name = "Memory",
            Desc = "I fall into a loop...",
            Description = "!!! SINGLE USE"..
            "#For this run, new collectibles only come from items you already hold"..
            "#More copies of an item make it more likely to appear again",
            AbyssSynic = "Colorful locust",
            BookOfBelial = "50% chance to spawn from the Devil Room pool instead",
            BookOfVirtues = "Wisp that ends the effect when extinguished#↑ Each repeated item will slightly strengthen it#Return to its full state when entering a new room",
        },
    },
    [12] = {
        Name = "小青最好的朋友",
        id = Items.My_Best_Friend,
        type = "passive",
        xmlId = 12,
        zh = {
            Name = "小青最好的朋友",
            Desc = "那么，你真的有朋友吗？",
            Description = "{{Chest}} 拾取时生成2个随机箱子"..
            "#{{GoldenChest}} 金箱开出道具时，会改为随机“朋友”"..
            "#{{Chest}} 普通箱与刺箱有10%概率开出“朋友”",
        },
        en = {
            Name = "My Best Friend",
            Desc = "Do you really have a friend?",
            Description = "{{Chest}} Spawns 2 random chests on pickup"..
            "#{{GoldenChest}} Golden Chest collectibles become random “friends”"..
            "#{{Chest}} Normal and Spiked Chests have a 10% chance to contain a “friend”",
        },
    },
    [13] = {
        Name = "超级炸弹",
        id = Items.Super_Bombs,
        type = "passive",
        xmlId = 13,
        zh = {
            Name = "超级炸弹",
            Desc = "口袋里的末日",
            Description = "{{Bomb}} +5超大炸弹"..
            "#{{Timer}} 没有超大炸弹时，20秒未使用炸弹会使1枚炸弹成长为超大炸弹"..
            "#{{Collectible483}} 主主动槽为空时，2分钟未使用炸弹会使1枚超大炸弹成长为妈咪炸弹",
        },
        en = {
            Name = "Super Bombs",
            Desc = "My pocket doomsday",
            Description = "{{Bomb}} +5 Giga Bombs"..
            "#{{Timer}} With no Giga Bombs, leave bombs unused for 20 seconds to grow 1 into a Giga Bomb"..
            "#{{Collectible483}} With the primary active slot empty, leave bombs unused for 2 minutes to grow 1 Giga Bomb into Mama Mega",
        },
    },
    [14] = {
        Name = "硫磺激流",
        id = Items.Brimstream,
        type = "passive",
        xmlId = 14,
        zh = {
            Name = "硫磺激流",
            Desc = "唯有燃烧",
            Description = "生成不断穿行于战场的硫磺火箭"..
            "#火箭高速掠过敌人，并在身后留下短暂的硫磺火航迹",
            AbyssSynic = "高速飞行时留下短暂硫磺火航迹的蝗虫",
        },
        en = {
            Name = "Brimstream",
            Desc = "Devil's trick.",
            Description = "Spawns a brimstone rocket that repeatedly crosses the battlefield"..
            "#It streaks through enemies at high speed and leaves a brief damaging brimstone trail",
            AbyssSynic = "A locust that leaves a brief brimstone trail while flying quickly",
        },
    },
    [15] = {
        Name = "琉璃的冠冕",
        id = Items.Crown_of_the_glaze,
        type = "passive",
        xmlId = 15,
        zh = {
            Name = "琉璃的冠冕",
            Desc = "破碎之前，你即为王",
            Description = "↑ 提高琉璃化掉落物的生成概率"..
            "#拾取琉璃掉落时冠冕获得1层辉片，最多5层"..
            "#{{Damage}} 每层辉片提供+0.3攻击"..
            "#{{Luck}} 每层辉片提供+1幸运"..
            "#3层：泪弹攻击有概率化为琉璃冠冕弹（主核+4辉片）"..
            "#5层：完成冠冕，强化琉璃掉落，并免疫琉璃化敌人的接触伤害"..
            "#{{Warning}} 受伤时冠冕破碎，根据原辉片数向四周释放琉璃碎片",
            SeijaNerf = "碎冠时，每层辉片额外失去半颗心",
        },
        en = {
            Name = "Crown of the glaze",
            Desc = "A king, until it shatters",
            Description = "↑ Increases the chance of glazed pickups"..
            "#Picking up glazed pickups adds 1 Crown shard, up to 5"..
            "#{{Damage}} Each shard grants +0.3 Damage"..
            "#{{Luck}} Each shard grants +1 Luck"..
            "#3 shards: Tear attacks may become a glazed crown shot (core + 4 shards)"..
            "#5 shards: Completes the crown, empowers glazed pickups, and blocks glazed enemy contact damage"..
            "#{{Warning}} Taking damage shatters the crown and fires glaze fragments based on lost shards",
            SeijaNerf = "On shatter, lose half a heart for each shard held",
        },
    },
    [16] = {
        Name = "铸币之余",
        id = Items.A_Shard_Of_Coin,
        type = "passive",
        xmlId = 16,
        zh = {
            Name = "铸币之余",
            Desc = "金玉所成，必先自晦",
            Description = "#{{Warning}} 当前版本暂不可用"..
            "#旧剧情素材，现阶段不会在正常流程中生成",
        },
        en = {
            Name = "A Shard of Coin",
            Desc = "Those who shared Pennies have been in pieces",
            Description = "#{{Warning}} Not currently available"..
            "#Legacy story material; it does not spawn during normal progression in this version",
        },
    },
    [17] = {
        Name = "琉璃之残",
        id = Items.A_Shard_Of_Glaze,
        type = "passive",
        xmlId = 17,
        zh = {
            Name = "琉璃之残",
            Desc = "晦明五色，必损于光",
            Description = "#{{Warning}} 当前版本暂不可用"..
            "#旧剧情素材，现阶段不会在正常流程中生成",
        },
        en = {
            Name = "A Shard of Glaze",
            Desc = "Those who honored Pride have been in pieces",
            Description = "#{{Warning}} Not currently available"..
            "#Legacy story material; it does not spawn during normal progression in this version",
        },
    },
    [18] = {
        Name = "流焰之华",
        id = Items.A_Shard_Of_Lava,
        type = "passive",
        xmlId = 18,
        zh = {
            Name = "流焰之华",
            Desc = "光结岩熔，必逢碎体",
            Description = "#{{Warning}} 当前版本暂不可用"..
            "#旧剧情素材，现阶段不会在正常流程中生成",
        },
        en = {
            Name = "A Shard of Lava",
            Desc = "Those who ingested Heat have been in pieces",
            Description = "#{{Warning}} Not currently available"..
            "#Legacy story material; it does not spawn during normal progression in this version",
        },
    },
    [19] = {
        Name = "鲜肉之渣",
        id = Items.A_Shard_Of_Meat,
        type = "passive",
        xmlId = 19,
        zh = {
            Name = "鲜肉之渣",
            Desc = "体遍万物，必破心神",
            Description = "#{{Warning}} 当前版本暂不可用"..
            "#旧剧情素材，现阶段不会在正常流程中生成",
        },
        en = {
            Name = "A Shard of Meat",
            Desc = "Those who valued Life have been in pieces",
            Description = "#{{Warning}} Not currently available"..
            "#Legacy story material; it does not spawn during normal progression in this version",
        },
    },
    [20] = {
        Name = "岩田之蚀",
        id = Items.A_Shard_Of_Rock,
        type = "passive",
        xmlId = 20,
        zh = {
            Name = "岩田之蚀",
            Desc = "神归至诚，必开飞金",
            Description = "#{{Warning}} 当前版本暂不可用"..
            "#旧剧情素材，现阶段不会在正常流程中生成",
        },
        en = {
            Name = "A Shard of Rock",
            Desc = "Those who desired Eternal have been in pieces",
            Description = "#{{Warning}} Not currently available"..
            "#Legacy story material; it does not spawn during normal progression in this version",
        },
    },
    [21] = {
        Name = "黑地图",
        id = Items.Black_Map,
        type = "passive",
        xmlId = 21,
        zh = {
            Name = "黑地图",
            Desc = "为了探寻未知",
            Description = "显示所有房间"..
            "#{{Warning}} 已进入的房间会尽可能从地图上消失",
        },
        en = {
            Name = "Black Map",
            Desc = "Into the uncharted",
            Description = "Reveals every room"..
            "#{{Warning}} Visited rooms try to disappear from the map",
        },
    },
    [22] = {
        Name = "硫磺爆射",
        id = Items.Blaststone,
        type = "passive",
        xmlId = 22,
        zh = {
            Name = "硫磺爆射",
            Desc = "唯有彭拜",
            Description = "{{Chargeable}} 双击发射硫磺火球 "..
            "#火球吸引敌人，随后爆发出硫磺火",
            AbyssSynic = "命中后爆发出硫磺火的蝗虫",
        },
        en = {
            Name = "Blaststone",
            Desc = "Devil's treachery",
            Description = "{{Chargeable}} Double tap to fire brimstone fireball",
            AbyssSynic = "Locust that burst brimstone on collision",
        },
    },
    [23] = {
        Name = "小黄鸭",
        id = Items.Little_Duck,
        type = "passive",
        xmlId = 23,
        zh = {
            Name = "小黄鸭",
            Desc = "鸭！鸭！鸭鸭鸭！！",
            Description = "进入未清理房间时，每份道具生成3只小黄鸭"..
            "#小黄鸭受到7次攻击后爆开并环射泪弹",
        },
        en = {
            Name = "Little Duck",
            Desc = "Quack, quack, quack!",
            Description = "Entering an uncleared room spawns 3 ducks per copy"..
            "#Ducks burst after 7 hits and fire a ring of tears",
        },
    },
    [24] = {
        Name = "炼金术的掌中锅",
        id = Items.Alchemy_Pot,
        type = "active",
        xmlId = 25,
        zh = {
            Name = "炼金术的掌中锅",
            Desc = "愿你必有所得",
            Description = "从持有道具中选择并消耗3个道具，制作1个道具"..
            "#结果编号依次取第1个道具的百位、第2个的十位、第3个的个位",
            BookOfBelial = "每次制作可以免费投入一个数字6",
            BookOfVirtues = "制作后生成对应投入道具的魂火",
            SeijaNerf = "50%概率制作出错误道具",
        },
        en = {
            Name = "Alchemy Pot",
            Desc = "Handle with transmutation",
            Description = "Select and consume 3 held collectibles to craft 1 collectible"..
            "#The result ID uses the 1st item's hundreds, 2nd item's tens, and 3rd item's ones",
            BookOfBelial = "Each craft can add one free digit 6",
            BookOfVirtues = "Spawns wisps for the invested collectibles after crafting",
            SeijaNerf = "50% chance to craft a wrong item",
        },
    },
    [25] = {
        Name = "空御一号-标准型",
        id = Items.Air_Terror,
        type = "passive",
        xmlId = 26,
        zh = {
            Name = "空御一号-标准型",
            Desc = "敌人已锁定！",
            Description = "自动巡航，追逐并拦截附近的敌方弹幕"..
            "#拦截后将其转化为竖直落下的{{Collectible331}} 神性泪弹，下落时留下伤害光环",
        },
        en = {
            Name = "Air Guard 01 - Standard",
            Desc = "Hello...Again?",
            Description = "Cruises automatically, chases and intercepts nearby enemy projectiles"..
            "#Converts them into falling {{Collectible331}} Godhead tears that leave a damaging aura",
        },
    },
    [26] = {
        Name = "琉璃的蘑菇",
        id = Items.Glaze_Mushroom,
        type = "passive",
        xmlId = 27,
        zh = {
            Name = "琉璃的蘑菇",
            Desc = "我是…嗝……琉璃？",
            Description = "{{Heart}} +1心之容器"..
            "#{{BossRoom}} Boss道具池底座有20%被菌丝侵蚀并变为{{Collectible12}} 魔法蘑菇"..
            "#本局最多触发一次",
        },
        en = {
            Name = "Glaze Mushroom",
            Desc = "I Feel...Glazed..uh?",
            Description = "{{Heart}} +1 Heart container"..
            "#{{BossRoom}} Boss-pool pedestals have a 20% chance to be overgrown into {{Collectible12}} Magic Mushroom"..
            "#Triggers at most once per run",
        },
    },
    [27] = {
        Name = "盛装男娘",
        id = Items.Pageant_Cross_dresser,
        type = "passive",
        xmlId = 28,
        zh = {
            Name = "盛装男娘",
            Desc = "超级豪华究极无敌涩涩！",
            Description = "{{Luck}} +2幸运"..
            "#随机穿上10件装扮",
        },
        en = {
            Name = "Pageant Cross-dresser",
            Desc = "Ultimate grand sexy",
            Description = "{{Luck}} +2 Luck"..
            "#Wear 10 random costumes",
        },
    },
    [28] = {
        Name = "琉璃之核",
        id = Items.It_s_a_trick,
        type = "active",
        xmlId = 29,
        zh = {
            Name = "琉璃之核",
            Desc = "成为所见之物",
            Description = "{{Room}} 使用后，本房间获得其伪装道具的效果"..
            "#每次使用有5%概率永久变为该道具",
        },
        en = {
            Name = "Glaze Core",
            Desc = "Become what you see",
            Description = "{{Room}} On use, gain the disguised item's effect for the room"..
            "#Each use has a 5% chance to permanently become that item",
        },
    },
    [29] = {
        Name = "世末天依",
        id = Items.Tianyi,
        type = "passive",
        xmlId = 30,
        zh = {
            Name = "世末天依",
            Desc = "至少这一次，我们相遇了",
            Description = "清理房间后，有20%概率遇见来自另一条世界线的天依"..
            "#在她离开前靠近，会收到一份礼物",
        },
        en = {
            Name = "World's End Tianyi",
            Desc = "At least this time, we met",
            Description = "After clearing a room, there is a 20% chance to encounter a Tianyi from another worldline"..
            "#Approach her before she leaves to receive a gift",
        },
    },
    [30] = {
        Name = "傲慢或是偏见",
        id = Items.Colorblindness,
        type = "passive",
        xmlId = 31,
        zh = {
            Name = "傲慢或是偏见",
            Desc = "我的品味不需要解释",
            Description = "靠近道具时可以评价它"..
            "#{{ButtonRT}} + {{ButtonLB}} 点赞；{{ButtonRT}} + {{ButtonRB}} 点踩"..
            "#{{Collectible}} 点赞：复制一份该道具进入当前道具池"..
            "#{{Warning}} 点踩：该道具从当前局与下一局的道具池中移除",
        },
        en = {
            Name = "Pride or Prejudice",
            Desc = "My taste needs no defense",
            Description = "Approach an item pedestal to judge it"..
            "#{{ButtonRT}} + {{ButtonLB}} to like; {{ButtonRT}} + {{ButtonRB}} to dislike"..
            "#{{Collectible}} Like: copy that item into the current item pool"..
            "#{{Warning}} Dislike: remove it from this run and the next run's item pools",
        },
    },
    [31] = {
        Name = "逆反力场",
        id = Items.Field,
        type = "passive",
        xmlId = 32,
        zh = {
            Name = "逆反力场",
            Desc = "↑升天↑",
            Description = "房间内生成1个{{ColorPurple}}逆反力场{{CR}}"..
            "#{{Tears}} 站在力场内时射速+1"..
            "#你的眼泪进入力场后会逐渐停下，并反复升空、重新出现"..
            "#多个力场彼此连通，被捕获的眼泪可从其他力场中出现",
        },
        en = {
            Name = "Anti-Field",
            Desc = "Those who rise up must be drifting down.",
            Description = "Creates an {{ColorPurple}}Anti-Field{{CR}} in the room"..
            "#{{Tears}} +1 Tears while standing inside the Field"..
            "#Your tears entering the Field gradually stop, then repeatedly rise and reappear"..
            "#Multiple Fields are linked; captured tears can emerge from another Field",
        },
    },
    [32] = {
        Name = "缝合针",
        id = Items.Suture_Needle,
        type = "active",
        xmlId = 33,
        zh = {
            Name = "缝合针",
            Desc = "那兽像豹，脚如熊足，口如狮口",
            Description = "分别选择1个{{ColorGreen}}移动部件{{CR}}与{{ColorRed}}攻击部件{{CR}}"..
            "#将二者缝合为一只友方敌人"..
            "#移动由前者决定，攻击由后者决定",
        },
        en = {
            Name = "Suture Needle",
            Desc = "The beast was like a leopard, with feet like a bear's and a mouth like a lion's.",
            Description = "Choose a {{ColorGreen}}movement part{{CR}} and an {{ColorRed}}attack part{{CR}}"..
            "#Stitch them together into a friendly enemy"..
            "#The former determines its movement; the latter determines its attacks",
        },
    },
    [33] = {
        Name = "更多更多选择！",
        id = Items.More_Options___,
        type = "passive",
        xmlId = 44,
        zh = {
            Name = "更多更多选择！",
            Desc = "当然，也要付出一点代价",
            Description = "{{Shop}} 商品会额外生成一个二选一选项"..
            "#{{Warning}} 商品价格随机提高约0–35%",
            SeijaNerf = "价格变为约三倍",
        },
        en = {
            Name = "More and more Options!",
            Desc = "Also Double Price",
            Description = "{{Shop}} Shop items gain an extra either/or choice"..
            "#{{Warning}} Prices rise randomly by about 0–35%",
            SeijaNerf = "Prices become about triple",
        },
    },
    [34] = {
        Name = "注定一抽",
        id = Items.Fate_s_Draw,
        type = "passive",
        xmlId = 45,
        zh = {
            Name = "注定一抽",
            Desc = "只要我牌组里还有卡，我始终相信我的牌组！！",
            Description = "持有的卡牌会不断变为同种类的另一张牌"..
            "#按住{{ButtonRT}}可以暂时锁定当前牌",
        },
        en = {
            Name = "Fate's Draw",
            Desc = "My Drawwww!!!!",
            Description = "Held cards keep changing into another card of the same type"..
            "#Hold {{ButtonRT}} to temporarily lock the current card",
        },
    },
    [35] = {
        Name = "小青的纹章",
        id = Items.My_Emblem,
        type = "passive",
        xmlId = 46,
        zh = {
            Name = "小青的纹章",
            Desc = "为它们找个家吧！",
            Description = "生成3个纹章"..
            "#大多数跟班会沿着你的泪弹轨迹组织进攻"..
            "#纹章接触敌人造成伤害，并可拦截敌方弹幕",
        },
        en = {
            Name = "Qing's Emblem",
            Desc = "Finally a home for me..",
            Description = "Spawns 3 emblems"..
            "#Most familiars organize attacks along your tear paths"..
            "#Emblems deal contact damage and can block enemy shots",
        },
    },
    [36] = {
        Name = "夜之摄取",
        id = Items.Ingestion_to_Night,
        type = "passive",
        xmlId = 47,
        zh = {
            Name = "夜之摄取",
            Desc = "长夜生牙",
            Description = "↑ 飞行"..
            "#按住攻击呼唤夜色，松开后发动摄取"..
            "#夜将你吞下，并重创敌人、吞噬敌方弹幕"..
            "#{{Warning}} 新房间有概率陷入黑暗，其中摄取更快",
            AbyssSynic = "概率恐惧的蝗虫",
        },
        en = {
            Name = "Ingestion to Night",
            Desc = "The night has teeth",
            Description = "↑ Flight"..
            "#Hold fire to call the night, then release to ingest"..
            "#The night swallows you, heavily damages enemies, and consumes enemy projectiles"..
            "#{{Warning}} New rooms may fall into darkness, where ingestion charges faster",
            AbyssSynic = "Locust that can fear enemies",
        },
    },
    [37] = {
        Name = "D773",
        id = Items.D773,
        type = "active",
        xmlId = 48,
        zh = {
            Name = "D773",
            Description = "重置你的皮肤 "..
            "#重置房间内所有道具为其本身",
            BookOfBelial = "额外获得数个恶魔皮肤",
            BookOfVirtues = "魂火消失后将房间内随机基础重置为其本身",
        },
        en = {
            Name = "D773",
            Desc = "Life is like an Oreo",
            Description = "Reroll your costumes"..
            "#Reroll items into theirselves",
            BookOfBelial = "Gain extra devil costumes",
            BookOfVirtues = "Spawn a wisp that reroll pickups into theirselves when extinguished.",
        },
    },
    [38] = {
        Name = "恶魔的心智",
        id = Items.Devil_s_Heart,
        type = "active",
        xmlId = 49,
        zh = {
            Name = "恶魔的心智",
            Desc = "他们自愿为我而死",
            Description = "使用后射出恶魔种子，与命中的敌人签订替死契约"..
            "#受到致死伤害时，由签约敌人代替你死亡"..
            "#签约敌人死亡时会转化为永久友军"..
            "#{{Timer}} 每次借命都会使之后的索命伤害增加1整心",
            AbyssSynic = "蝗虫命中敌人也会与其签约",
            BookOfBelial = "通过契约复活后，本房间获得临时攻击提升",
            BookOfVirtues = "消耗魂火可让普通敌对宿主替死后存活；Boss支付的生命减半",
            SeijaBuff = "通过契约复活不会增加恶魔索命伤害",
        },
        en = {
            Name = "Devil's Heart",
            Desc = "They volunteered to die for me",
            Description = "Use to fire a devil seed and bind the enemy it hits into a death pact"..
            "#On lethal damage, a contracted enemy dies in your place"..
            "#Contracted enemies that die instead become permanent friendly servants"..
            "#{{Timer}} Each borrowed life increases future claim damage by 1 full heart",
            AbyssSynic = "Locust hits can also bind enemies into contracts",
            BookOfBelial = "After reviving through a contract, gain a temporary room damage up",
            BookOfVirtues = "Spend a wisp to let a normal hostile host survive its sacrifice; bosses pay half as much HP",
            SeijaBuff = "Reviving through a contract does not increase the Devil's claim damage",
        },
    },
    [39] = {
        Name = "D-V-F",
        id = Items.DVF,
        type = "active",
        xmlId = 50,
        zh = {
            Name = "D-V-F",
            Desc = "不惜一切代价",
            Description = "!!! 一次性"..
            "#使用后举起，按射击键掷出二向箔"..
            "#{{Timer}} 箔片悬停后倒计时7秒，结束后抹除范围内相交的所有房间"..
            "# 仅留下一个连接残存边界的额外房间"..
            "#{{BossRoom}} 抹除最终Boss房时，在额外房间生成下层入口",
        },
        en = {
            Name = "D-V-F",
            Desc = "At any cost",
            Description = "!!! One-time use"..
            "#Raise it, then press a fire key to throw a Dual Vector Foil"..
            "#{{Timer}} After it lands, a 7-second countdown starts; when it ends, erase every room intersecting its range"..
            "# Leaves only an extra room linking the surviving boundaries"..
            "#{{BossRoom}} Erasing the final boss room spawns a next-floor entrance in the extra room",
        },
    },
    [40] = {
        Name = "未来之书",
        id = Items.Book_of_Future,
        type = "active",
        xmlId = 51,
        zh = {
            Name = "未来之书",
            Desc = "未来写入，现在删改",
            Description = "从当前房间道具池中抽走道具，直到总品质达到50"..
            "#生成一个四选一道具",
            BookOfBelial = "四选一中额外加入2个恶魔房道具池候选",
            BookOfVirtues = "从本次抽走的道具中随机生成对应魂火",
            SeijaNerf = "改为生成一个一选一道具",
        },
        en = {
            Name = "Book of Future",
            Desc = "Rewrite what has yet to happen",
            Description = "Draws from the current room's item pool until total quality reaches 50"..
            "#Spawns a 4-choice item selection",
            BookOfBelial = "Adds 2 Devil Room pool items to the selection",
            BookOfVirtues = "Spawns a wisp for one randomly chosen drawn item",
            SeijaNerf = "Only spawns a 1-choice item",
        },
    },
    [41] = {
        Name = "和谐号",
        id = Items.Hyper_Velocity,
        type = "active",
        xmlId = 52,
        zh = {
            Name = "和谐号",
            Desc = "下一站，创死你",
            Description = "{{Throwable}} 举起后按方向召唤一列动车"..
            "#动车撞击敌人并破坏地形"..
            "#{{Damage}} 撞击敌人造成250+5倍角色伤害"..
            "#{{Warning}} 动车会对角色造成5点伤害",
            AbyssSynic = "速度极快的蝗虫",
            BookOfVirtues = "和平魂火 #角色受到至少1整心伤害时，熄灭全部和平魂火并抵消该次伤害",
        },
        en = {
            Name = "Hyper Velocity",
            Desc = "Next stop: impact",
            Description = "{{Throwable}} Hold up the item, then choose a direction to call a train"..
            "#The train runs through enemies and terrain"..
            "#{{Damage}} Deals 250 + 5x Isaac's damage to enemies"..
            "#{{Warning}} Deals 5 damage to Isaac on collision",
            AbyssSynic = "Very fast locust",
            BookOfVirtues = "Peace wisps block a hit of at least 1 full heart, then all vanish",
        },
    },
    [42] = {
        Name = "摇摆之眼",
        id = Items.Wavering_Eyes,
        type = "passive",
        xmlId = 53,
        zh = {
            Name = "摇摆之眼",
            Desc = "别眨眼，别偏离",
            Description = "连续用眼泪命中敌人会累计凝视"..
            "#↓ 凝视越高，眼泪摇摆越明显"..
            "#{{Tears}} 每3层凝视提升射速"..
            "#5层：眼泪轻微吸附敌人"..
            "#{{Collectible3}} 8层：追踪眼泪"..
            "#{{Trinket26}} 13层：钩虫眼泪"..
            "#{{Collectible221}} 21层：弹性眼泪"..
            "#!!! 连续失误会清空凝视",
        },
        en = {
            Name = "Wavering Eyes",
            Desc = "Don't blink, don't miss",
            Description = "Consecutive tear hits build Focus"..
            "#↓ Higher Focus: tears waver more in a steady sway"..
            "#{{Tears}} Every 3 Focus: tears up"..
            "#5 Focus: tears gently pull toward nearby foes"..
            "#{{Collectible3}} 8 Focus: homing tears"..
            "#{{Trinket26}} 13 Focus: hook worm tears"..
            "#{{Collectible221}} 21 Focus: rubber tears"..
            "#!!! Too many misses clear Focus",
        },
    },
    [43] = {
        Name = "灵摆之星",
        id = Items.Pendulum_Star,
        type = "passive",
        xmlId = 54,
        zh = {
            Name = "灵摆之星",
            Desc = "刻度设置完毕",
            Description = "生成一对摆动的灵摆星"..
            "#穿过两星之间刻度的眼泪会被记录"..
            "#回摆时，以75%伤害重新释放为具有灵体与跟踪效果的星泪",
        },
        en = {
            Name = "Pendulum Star",
            Desc = "Scale set",
            Description = "Spawns a pair of swinging pendulum stars"..
            "#Tears that cross the scale between them are recorded"..
            "#On the backswing, they are released again at 75% damage as spectral homing star tears",
        },
    },
    [44] = {
        Name = "透特之书",
        id = Items.Book_of_Thoth,
        type = "active",
        xmlId = 55,
        zh = {
            Name = "透特之书",
            Desc = "命运只是尚未整理的书页",
            Description = "{{ThothCard}} 拾取时生成1张透特牌，并记录获得过的透特牌面"..
            "#{{Battery}} 登记新牌面+1启示，使用透特牌+2启示，最多12格"..
            "#消耗3格启示，选择至多3张记录牌面进行占卜"..
            "#进入新战斗房时随机发动一张；每个牌面每层限一次",
            AbyssSynic = "命中后概率生成卡牌的蝗虫",
            BookOfBelial = "占卜时最多可选择4张牌",
            BookOfVirtues = "魂火熄灭时生成一张塔罗牌",
            SeijaNerf = "透特牌以背面出现；卡册先只显示正逆位，首次占卜后才翻开",
        },
        en = {
            Name = "Book of Thoth",
            Desc = "Fate is merely a book yet to be put in order.",
            Description = "{{ThothCard}} Spawns 1 Thoth card on pickup; records obtained Thoth faces"..
            "#{{Battery}} Registering a new face +1 Revelation, using a Thoth card +2, up to 12"..
            "#Spend 3 Revelation to read up to 3 recorded faces"..
            "#Entering a new combat room plays one at random; each face once per floor",
            AbyssSynic = "Locust that may spawn a card on hit",
            BookOfBelial = "Readings can hold up to 4 faces",
            BookOfVirtues = "Wisps spawn a tarot card when extinguished",
            SeijaNerf = "Thoth cards appear face-down; the codex shows only upright/reversed until the first reading",
        },
    },
    [45] = {
        Name = "法之书",
        id = Items.Book_of_The_Law,
        type = "active",
        xmlId = 56,
        zh = {
            Name = "法之书",
            Desc = "它为你而扭曲",
            Description = "记录当前房间的道具池"..
            "#下一件来自其他道具池的道具改从记录池生成",
            BookOfBelial = "在恶魔房使用时三倍效果",
            BookOfVirtues = "熄灭时额外使用一次{{Collectible"..tostring(enums.Items.Book_of_The_Law).."}}的魂火",
        },
        en = {
            Name = "Book of The Law",
            Desc = "Left is Right.Right is Lefted.",
            Description = "Records this room's item pool"..
            "#The next item from a different pool is drawn from the recorded pool instead",
            BookOfBelial = "Triple effect in devil room",
            BookOfVirtues = "Wisp that triggers {{Collectible"..tostring(enums.Items.Book_of_The_Law).."}} when extinguished",
        },
    },
    [46] = {
        Name = "觅之书",
        id = Items.Book_of_Vision,
        type = "active",
        xmlId = 57,
        zh = {
            Name = "觅之书",
            Desc = "看见两次",
            Description = "本房间内基础资源的获得与消耗都会重复一次"..
            "#{{GoldenBomb}} {{GoldenKey}} 获得时额外转化为3个对应基础资源",
            BookOfBelial = "获得心类资源时额外获得半颗黑心",
            BookOfVirtues = "每次有效获得资源时，消耗全部觅之书魂火，并按魂火数量额外再复制一次",
        },
        en = {
            Name = "Book of Vision",
            Desc = "See twice",
            Description = "Basic resource gains and spends in this room are applied again"..
            "#{{GoldenBomb}} {{GoldenKey}} also grant 3 matching basic resources",
            BookOfBelial = "Gaining heart-type resources also grants half a black heart",
            BookOfVirtues = "On a resource gain, consume Vision wisps and duplicate once more per wisp",
        },
    },
    [47] = {
        Name = "假象之书",
        id = Items.Book_of_Voice,
        type = "active",
        xmlId = 58,
        zh = {
            Name = "假象之书",
            Desc = "快，毁灭我",
            Description = "{{Battery}} 以0充能获得；充满后可主动呼唤低语"..
            "#低语也会自然响起，并使此书暂时可用"..
            "#每次接受低语都会让声音更加清晰，并缩短充能",
            BookOfBelial = "可加倍接受低语，以更高代价换取更高报酬",
            BookOfVirtues = "回应低语时生成假象魂火，使要求降低一级",
            SeijaBuff = "拒绝低语也会获得小型报酬，并使声音更加清晰",
        },
        en = {
            Name = "Book of Voice",
            Desc = "Destroy me. Quickly.",
            Description = "{{Battery}} Obtained at 0 charge; when full, can call a whisper"..
            "#Whispers can also arise on their own, temporarily making the book usable"..
            "#Each accepted whisper makes the voice clearer and shortens the charge",
            BookOfBelial = "Can double-accept a whisper, paying more for a greater reward",
            BookOfVirtues = "Answering a whisper spawns an illusion wisp that lowers the demand by one tier",
            SeijaBuff = "Refusing a whisper also grants a small reward and makes the voice clearer",
        },
    },
    [48] = {
        Name = "失语症",
        id = Items.Aphasia,
        type = "passive",
        xmlId = 59,
        zh = {
            Name = "失语症",
            Desc = "名可名，非常名",
            Description = "大部分普通道具文字会被打乱，并从描述中掉落"..
            "#拾取文字会暂时提高攻击，并保存为文字弹药"..
            "#发射泪弹时消耗一个文字，使该泪弹获得额外伤害"..
            "#不会打乱EID",
        },
        en = {
            Name = "Aphasia",
            Desc = "Hardly can I ever read",
            Description = "Most normal item text is scrambled, and some characters fall to the floor"..
            "#Picked-up words briefly raise damage and are stored as word ammo"..
            "#Firing a tear spends one word and boosts that tear"..
            "#Does not scramble EID",
        },
    },
    [49] = {
        Name = "纳兹卡巨画",
        id = Items.Nazca,
        type = "passive",
        xmlId = 60,
        zh = {
            Name = "纳兹卡巨画",
            Desc = "神明立于尘埃之上",
            Description = "在房间中不断绘制地缚图线"..
            "#敌人站在线上会持续受到伤害"..
            "#站在线上时，根据图线浓度提高{{Damage}}攻击与{{Speed}}移速",
            AbyssSynic = "三只蝗虫",
            SeijaNerf = "只保留一名绘制者，且图线浓度上限降低",
        },
        en = {
            Name = "Nazca",
            Desc = "Earthbound Deity",
            Description = "Keeps drawing earthbound lines across the room"..
            "#Enemies standing on the lines take damage over time"..
            "#Standing on denser lines raises {{Damage}} Damage and {{Speed}} Speed",
            AbyssSynic = "Triple locust",
            SeijaNerf = "Only one painter, with a lower line density cap",
        },
    },
    [50] = {
        Name = "云玩大佬",
        id = Items.Cloundy,
        type = "passive",
        xmlId = 61,
        zh = {
            Name = "云玩大佬",
            Desc = "说什么呢，你才是云玩家！",
            Description = "自动吞噬敌人并转化为基础掉落的小跟班 "..
            "#也会吞噬基础掉落并转化为敌人 "..
            "#为你提供有益？的游戏指导",
            SeijaBuff = "将道具转化为Boss，也将Boss转化为道具",
        },
        en = {
            Name = "Cloundy",
            Desc = "Cloundy knows much more than you",
            Description = "Digests enemies and turn them into pickups"..
            "#Digests pickups and turn them into enemies"..
            "#Provides instruction to you and help you",
            SeijaBuff = "Turn bosses into items and turn items into bosses",
        },
    },
    [51] = {
        Name = "痛苦因子",
        id = Items.Skiel,
        type = "passive",
        xmlId = 62,
        zh = {
            Name = "痛苦因子",
            Desc = "你的过去由我笼罩",
            Description = "{{Chargeable}} 持续攻击进行蓄力"..
            "#蓄满后展开由泪弹连接而成的因子网"..
            "#松开攻击会失去当前蓄力",
        },
        en = {
            Name = "Skiel",
            Desc = "Your past is shrouded by me",
            Description = "{{Chargeable}} Keep firing to charge"..
            "#At full charge, release a linked web of tears"..
            "#Releasing fire resets the current charge",
        },
    },
    [52] = {
        Name = "绝望因子",
        id = Items.Wisel,
        type = "passive",
        xmlId = 63,
        zh = {
            Name = "绝望因子",
            Desc = "你的现在由我咒缚",
            Description = "{{Chargeable}} 反复点按攻击进行蓄力"..
            "#停止攻击后蓄力逐渐流失"..
            "#蓄满后向攻击方向连续释放大型冲击波",
        },
        en = {
            Name = "Wisel",
            Desc = "Your present is bound by me",
            Description = "{{Chargeable}} Repeatedly tap fire to charge"..
            "#Charge gradually decays while not firing"..
            "#At full charge, release a series of large shockwaves",
        },
    },
    [53] = {
        Name = "泯灭因子",
        id = Items.Granel,
        type = "passive",
        xmlId = 64,
        zh = {
            Name = "泯灭因子",
            Desc = "你的未来由我惩戒",
            Description = "{{Chargeable}} 持续攻击蓄力，反复点按可加快蓄力"..
            "#停止攻击后蓄力逐渐流失"..
            "#蓄满后向四周连续喷射大量火焰",
        },
        en = {
            Name = "Granel",
            Desc = "Your future shall be judged by me",
            Description = "{{Chargeable}} Hold fire to charge; repeated taps charge faster"..
            "#Charge gradually decays while not firing"..
            "#At full charge, unleash waves of flames in four directions",
        },
    },
    [54] = {
        Name = "妖刀·逢魔",
        id = Items.Spectralsword,
        type = "active",
        xmlId = 65,
        zh = {
            Name = "妖刀·逢魔",
            Desc = "物皆有灵",
            Description = "使用后唤出妖鬼，可调整属性、基础资源及其上限、房间概率"..
            "#降低数值获得对应灵质；消耗同类灵质提高其他数值"..
            "#属性、资源与概率灵质彼此独立"..
            "#天使房概率改分配且不消耗概率灵质",
            BookOfVirtues = "不生成魂火",
            SeijaNerf = "抽取时有50%概率不产生灵质",
        },
        en = {
            Name = "Spectral Sword",
            Desc = "Out of its sheath",
            Description = "Use to summon the oni and adjust stats, basic resources and their caps, and room chances"..
            "#Lower values to gain matching essence; spend matching essence to raise other values"..
            "#Stat, resource, and chance essence are separate"..
            "#Angel Room chance reshapes the Deal split and costs no Chance Essence",
            BookOfVirtues = "Does not spawn wisps",
            SeijaNerf = "50% chance for extraction to produce no essence",
        },
    },
    [55] = {
        Name = "妖刻·白隙",
        id = Items.Squiresaga,
        type = "active",
        xmlId = 66,
        zh = {
            Name = "妖刻·白隙",
            Desc = "物皆有间",
            Description = "使用后挥刀选择附近的对象，斩开它的“间隙”"..
            "#在间隙中查看并修改该对象支持的属性"..
            "#可作用于敌人、掉落物、机关与部分地形"..
            "#不同对象可修改的内容不同",
            BookOfVirtues = "不生成魂火",
            SeijaNerf = "在修改器中每次移动指针都会降低全属性",
        },
        en = {
            Name = "Squiresaga",
            Desc = "My blade burns",
            Description = "Use to swing the blade and select a nearby object, cutting open its \"gap\""..
            "#Inspect and modify attributes supported by that object"..
            "#Works on enemies, pickups, mechanisms, and some grid entities"..
            "#Available attributes depend on the target",
            BookOfVirtues = "No wisps",
            SeijaNerf = "Lower all stats when moving pointer in the crevice",
        },
    },
    [56] = {
        Name = "妖星·一瞬",
        id = Items.Moment,
        type = "passive",
        xmlId = 67,
        zh = {
            Name = "妖星·一瞬",
            Desc = "物皆有能",
            Description = "回收攻击留下的残余能量"..
            "#回收的能量会逐渐转化为随机属性提升"..
            "#能量过高后开始自动泄露"..
            "#{{Warning}} 严重过载会触发零点反转，使积累的属性反向生效",
            SeijaNerf = "能量不会泄露，即使反转已经发生",
        },
        en = {
            Name = "Moment",
            Desc = "lasrever dlroW",
            Description = "Recover residual energy left by your attacks"..
            "#Recovered energy gradually becomes random stat bonuses"..
            "#Excess energy is automatically vented"..
            "#{{Warning}} Severe overload triggers Zero Reversal, reversing the accumulated bonuses",
            SeijaNerf = "The world will reverse forever",
        },
    },
    [57] = {
        Name = "至高之阵",
        id = Items.Lofty,
        type = "passive",
        xmlId = 68,
        zh = {
            Name = "至高之阵",
            Desc = "坠入深不见底的绝望深渊吧",
            Description = "每个房间首次受伤时阻挡伤害，并释放扩张的冲击波"..
            "#冲击波命中敌人后，会从目标处再次扩散"..
            "#{{Chargeable}} 本房间护盾尚未触发时，持续攻击蓄力可主动释放冲击波",
            AbyssSynic = "蝗虫命中后释放小型冲击波",
            SeijaNerf = "改为每层下层时恢复",
        },
        en = {
            Name = "Lofty",
            Desc = "Bottomless despair abyss",
            Description = "Block the first hit in each room and release an expanding shockwave"..
            "#Enemies touched by the wave emit another shockwave"..
            "#{{Chargeable}} While the room's shield is unused, hold fire to charge and release a shockwave",
            AbyssSynic = "Locust with small shock wave",
            SeijaNerf = "Shock wave recovers only once each level",
        },
    },
    [58] = {
        Name = "忒修斯之印",
        id = Items.Theseus_s_Sign,
        type = "passive",
        xmlId = 69,
        zh = {
            Name = "忒修斯之印",
            Desc = "条款正在改写",
            Description = "持有2条会不断改写的条款"..
            "#完成条款后执行对应结果，并随机改写其中一部分"..
            "#进入新一层时也会改写1条条款",
        },
        en = {
            Name = "Theseus's Sign",
            Desc = "Terms under revision",
            Description = "Hold 2 clauses that are continuously rewritten"..
            "#Completing a clause performs its result and randomly rewrites part of it"..
            "#Entering a new floor also rewrites 1 clause",
        },
    },
    [59] = {
        Name = "心变",
        id = Items.Heart_Change,
        type = "passive",
        xmlId = 70,
        zh = {
            Name = "心变",
            Desc = "一念神魔",
            Description = "双翼完整时获得飞行"..
            "#{{AngelRoom}} 首次进入天使房：折断恶魔翼，生成1个{{BlackHeart}} 黑心"..
            "#{{DevilRoom}} 首次进入恶魔房：折断天使翼，生成1个{{EternalHeart}} 永恒之心"..
            "#{{Collectible}} 双翼均折断后，下层生成天使与恶魔道具各1件，并恢复双翼",
        },
        en = {
            Name = "Heart Change",
            Desc = "Demon in body,angel in mind",
            Description = "Grants flight while both wings are intact"..
            "#{{AngelRoom}} First Angel Room visit: break the Devil wing and spawn 1 {{BlackHeart}} Black Heart"..
            "#{{DevilRoom}} First Devil Room visit: break the Angel wing and spawn 1 {{EternalHeart}} Eternal Heart"..
            "#{{Collectible}} After both wings break, the next floor spawns 1 Angel and 1 Devil item, then restores both wings",
        },
    },
    [60] = {
        Name = "罐中雷暴",
        id = Items.Cable_Jar,
        type = "passive",
        xmlId = 71,
        zh = {
            Name = "罐中雷暴",
            Desc = "你感到有点漏电",
            Description = "{{Battery}} 将主主动槽中有充能主动的上限压缩至2格"..
            "#溢出的充能会泄露为留在房间中的能量球"..
            "#使用主动时，按当前上限/原始上限的概率正常发动"..
            "#失败：泄露所有充能并释放雷暴，上限+2"..
            "#{{Warning}} 受伤时上限-2，并泄露超出新上限的充能",
            AbyssSynic = "蝗虫命中时小概率生成充能球",
        },
        en = {
            Name = "Cable Jar",
            Desc = "Slightly leaky",
            Description = "{{Battery}} Compresses the charge cap of charged primary actives to 2"..
            "#Excess charge leaks into energy orbs that remain in the room"..
            "#On use: current cap/original cap chance to activate normally"..
            "#Failure: leak all charge in a thunderstorm; cap +2"..
            "#{{Warning}} Taking damage lowers the cap by 2 and leaks charge above the new cap",
            AbyssSynic = "The locust has a small chance to spawn an energy orb on hit",
        },
    },
    [61] = {
        Name = "福音",
        id = Items.Gospel,
        type = "passive",
        xmlId = 72,
        zh = {
            Name = "福音",
            Desc = "神的国度带着主权临到",
            Description = "每4次攻击，该次攻击成为{{ColorYellow}}福音攻击{{CR}}"..
            "#命中使敌人接受福音，并可向附近敌人传播"..
            "#击杀受福音影响的敌人，或持续伤害受影响的Boss，会降下启示"..
            "#本房间累计6次启示后发动最终启示",
            AbyssSynic = "蝗虫命中敌人时使其接受福音",
            SeijaNerf = "福音不再传播，改为对原目标降下较弱的黑暗启示；最终启示不补全全房",
        },
        en = {
            Name = "Gospel",
            Desc = "The kingdom of God comes with sovereignty",
            Description = "Every 4th attack becomes a {{ColorYellow}}Gospel attack{{CR}}"..
            "#Hits make enemies receive the Gospel, which can spread to nearby foes"..
            "#Killing affected enemies or repeatedly damaging affected Bosses invokes Revelation"..
            "#After 6 Revelations in the room, invoke final Revelation",
            AbyssSynic = "Locusts cause hit enemies to receive the Gospel",
            SeijaNerf = "Gospel no longer spreads, instead invoking a weaker dark Revelation on the original target; final Revelation does not fill the room",
        },
    },
    [62] = {
        Name = "提拉米苏",
        id = Items.Tiramisu,
        type = "passive",
        xmlId = 73,
        zh = {
            Name = "提拉米苏",
            Desc = "血量上升 + 道具变得美味",
            Description = "{{EmptyHeart}} +1血上限"..
            "#获得属性提升时，临时复制其中一部分"..
            "#复制的属性会逐渐消退；连续触发时效果减弱",
        },
        en = {
            Name = "Tiramisu",
            Desc = "Health Up + Tastes Tasty",
            Description = "{{EmptyHeart}} +1 Health up"..
            "#Stat increases temporarily grant part of the same increase again"..
            "#Copied stats fade over time; rapid triggers weaken the effect",
        },
    },
    [63] = {
        Name = "直播姬",
        id = Items.Live_Broadcast,
        type = "passive",
        xmlId = 74,
        zh = {
            Name = "直播姬",
            Desc = "成为主播出道吧！",
            Description = "战斗、拾取与消费等行为会触发观众弹幕"..
            "#观众评价会改变人气"..
            "#{{ArrowUp}} 人气越高，弹幕越活跃，并可能收到赞助礼物"..
            "#礼物提供临时属性或主动充能",
        },
        en = {
            Name = "Live Broadcast",
            Desc = "Going live!",
            Description = "Combat, pickups, and spending can trigger viewer chat"..
            "#Viewer reactions change popularity"..
            "#{{ArrowUp}} Higher popularity means livelier chat and possible sponsor gifts"..
            "#Gifts grant temporary stats or active charge",
        },
    },
    [64] = {
        Name = "悲欢之凶剧",
        id = Items.Drama_of_sorrow_and_joy,
        type = "passive",
        xmlId = 75,
        zh = {
            Name = "悲欢之凶剧",
            Desc = "丑角登场",
            Description = "概率发射交替出现的悲剧与喜剧面具泪"..
            "#悲剧：戴面具的敌人死亡时引发冲击，并将悲剧传给另一名敌人"..
            "#喜剧：戴面具的敌人受到致命伤害时拒绝死亡，并成为友军"..
            "#两种面具相遇时化为{{ColorPurple}}凶剧{{CR}}：悲剧传遍舞台，而喜剧拒绝谢幕",
            Rnd_Special = {
                Name = "悲欢之凶剧",
                Description = "没有演员真正离开舞台。",
                weigh = 5,
            },
        },
        en = {
            Name = "Drama of sorrow and joy",
            Desc = "Leader To Despia",
            Description = "Chance to fire alternating tragedy and comedy mask tears"..
            "#Tragedy: masked foes unleash a shockwave on death and pass Tragedy onward"..
            "#Comedy: masked foes refuse death when taking lethal damage and become friendly"..
            "#When both masks meet, they become {{ColorPurple}}Tragicomedy{{CR}}: tragedy spreads across the stage, while comedy refuses the curtain call",
            Rnd_Special = {
                Name = "Drama of sorrow and joy",
                Description = "No actor ever truly leaves the stage.",
                weigh = 5,
            },
        },
    },
    [65] = {
        Name = "卓尔金神历",
        id = Items.Tzolkin,
        type = "active",
        xmlId = 76,
        zh = {
            Name = "卓尔金神历",
            Desc = "祈祷神历的宿命",
            Description = "使用后选择1件持有道具，换取接近其品质的三选一"..
            "#原道具与新获得道具均成为临时道具"..
            "#{{Warning}} 受伤时抵挡伤害，并失去神历与临时道具"..
            "#之后重新获得神历时，恢复此前的临时道具",
        },
        en = {
            Name = "Tzolkin",
            Desc = "Replay the divine calendar",
            Description = "Choose 1 held item and trade it for a 3-choice near its quality"..
            "#The original and chosen items both become temporary"..
            "#{{Warning}} Taking damage blocks the hit and loses Tzolkin and temporary items"..
            "#Reclaiming Tzolkin restores those temporary items",
        },
    },
    [66] = {
        Name = "妖心·盈月",
        id = Items.Pareidolia,
        type = "passive",
        xmlId = 77,
        zh = {
            Name = "妖心·盈月",
            Desc = "物皆有情",
            Description = "对敌人造成伤害会开始注视目标，并逐渐积累月相"..
            "#切换目标或目标死亡不会失去已有月相"..
            "#{{Damage}} 月相盈满时，对当前注视目标发动妖眼共鸣",
        },
        en = {
            Name = "Pareidolia",
            Desc = "Moonlight Domain",
            Description = "Damaging foes begins a gaze and builds moon phase"..
            "#Changing targets or killing the target keeps current moon phase"..
            "#{{Damage}} At full moon, unleash Yokai Eye resonance on the gaze target",
        },
    },
    [67] = {
        Name = "反转片？",
        id = Items.Reversal_Film,
        type = "passive",
        xmlId = 78,
        zh = {
            Name = "反转片？",
            Desc = "阴影选择了我",
            Description = "剧情道具"..
            "#用于特定剧情中的门"..
            "#按剧情拾取时，会立刻将角色送回初始房间",
        },
        en = {
            Name = "Reversal Film",
            Desc = "Cast Fate On Me",
            Description = "Story item"..
            "#Used with certain story doors"..
            "#Picking it up during the story sequence returns you to the starting room",
        },
    },
    [68] = {
        Name = "鲛人之泪",
        id = Items.Tears_of_Pearl,
        type = "passive",
        xmlId = 79,
        zh = {
            Name = "鲛人之泪",
            Desc = "高尚者为我悼哭",
            Description = "概率发射珍珠泪"..
            "#珍珠落地后停留，可被角色踢动"..
            "#接触敌方弹幕时将其吞下，并反向射回友方泪弹"..
            "#每颗珍珠最多反射或碰撞5次",
        },
        en = {
            Name = "Tears of Pearl",
            Desc = "Nobility Cherisher",
            Description = "Chance to fire pearl tears"..
            "#Pearls linger on the ground and can be kicked"..
            "#Contact with enemy shots swallows them and fires a friendly tear back"..
            "#Each pearl can reflect or collide up to 5 times",
        },
    },
    [69] = {
        Name = "非数骰子",
        id = Items.D_NAN,
        type = "active",
        xmlId = 80,
        zh = {
            Name = "非数骰子",
            Desc = "错误：尝试将零作为除数",
            Description = "将房间内的普通道具重置为错误道具"..
            "#将错误道具重新重置为普通道具",
            BookOfBelial = "将房间内错误道具重置成恶魔房道具",
            BookOfVirtues = "发射随机特效子弹的魂火",
        },
        en = {
            Name = "D NAN",
            Desc = "Warning: division by zero",
            Description = "Rerolls normal collectibles into glitched items"..
            "#Rerolls glitched items back into normal collectibles",
            BookOfBelial = "Rerolls glitched items into Devil Room items",
            BookOfVirtues = "Grants a wisp that fires tears with random effects",
        },
    },
    [70] = {
        Name = "勇者祝福",
        id = Items.Risemara,
        type = "passive",
        xmlId = 81,
        zh = {
            Name = "勇者祝福",
            Desc = "得刷个好开局",
            Description = "拾取时，为6项基础属性分别随机生成评级"..
            "#评级决定对应属性的上升或下降幅度"..
            "#靠近原本的空底座可将其放回"..
            "#不满意？重新拾取，再来一次",
        },
        en = {
            Name = "Risemara",
            Desc = "Once more again",
            Description = "On pickup, roll grades for 6 basic stats"..
            "#Each grade sets how much that stat rises or falls"..
            "#Return it to its original empty pedestal"..
            "#Not happy? Pick it up again and reroll",
        },
    },
    [71] = {
        Name = "无名刃：心灾",
        id = Items.Chiastolite,
        type = "passive",
        xmlId = 82,
        zh = {
            Name = "无名刃：心灾",
            Desc = "最好以血浇灌",
            Description = "心剑会自动附身于一名敌人"..
            "#目标受到伤害时，暂时斩出其当前生命的20%"..
            "#被斩出的生命会在短暂延迟后飞回目标"..
            "#Boss仅斩出5%，且额外伤害存在上限",
            AbyssSynic = "斩出少许血量的蝗虫",
        },
        en = {
            Name = "Chiastolite",
            Desc = "Sacrifice with blood",
            Description = "A heart blade automatically possesses an enemy"..
            "#When that foe takes damage, temporarily cut out 20% of its current HP"..
            "#The cut HP flies back to the target after a short delay"..
            "#Bosses lose only 5%, and the bonus cut has a damage cap",
            AbyssSynic = "Locust that cuts out a small amount of health",
        },
    },
    [72] = {
        Name = "妖神合道",
        id = Items.Annihilation,
        type = "passive",
        xmlId = 83,
        Hidden = "true",
        zh = {
            Name = "妖神合道",
            Description = "若角色没有副手主动，则自动占据那个位置，否则放置在副手主动下方"..
            "#未完成"..
            "#根据角色产生效果：",
        },
        en = {
            Name = "Annihilation",
            Desc = "Who knows?",
            Description = "Occupy your second hand item if you don't have any, otherwise it will be placed under that"..
            "#Different effect based on character："..
            "#UNFINISHED",
        },
    },
    [73] = {
        Name = "妖神合道",
        id = Items.Annihilation_,
        type = "active",
        xmlId = 84,
        Hidden = "true",
        zh = {
            Name = "妖神合道",
            Desc = "计略已成",
            Description = "",
        },
        en = {
            Name = "Annihilation",
            Desc = "Who knows?",
            Description = "UNFINISHED",
        },
    },
    [74] = {
        Name = "天象灾变",
        id = Items.Calamity,
        type = "active",
        xmlId = 85,
        zh = {
            Name = "天象灾变",
            Desc = "II",
            Description = "{{BossRoom}} 只能通过清理Boss房获得充能（满充通常需2个Boss房）"..
            "#靠近一扇门使用，对门后的未清理房间发动灾变"..
            "#灾变会提前清除该房间中的敌人，包括Boss房"..
            "#进入被灾变的房间时，将直接视为已被清理",
            AbyssSynic = "生成小型硫磺火柱的蝗虫",
            BookOfVirtues = "发射生成小型硫磺火柱眼泪的魂火",
        },
        en = {
            Name = "Calamity",
            Desc = "II",
            Description = "{{BossRoom}} Only recharges by clearing Boss rooms (full charge usually needs 2)"..
            "#Use near a door to calamitize the uncleared room beyond it"..
            "#Clears that room's enemies in advance, including Boss rooms"..
            "#Entering a calamitized room treats it as already cleared",
            AbyssSynic = "Locust that spawns small brimstone fire pillars",
            BookOfVirtues = "Grants a wisp that fires tears which spawn small brimstone pillars",
        },
    },
    [75] = {
        Name = "瓶中阴影",
        id = Items.Shadow_Bottle,
        type = "passive",
        xmlId = 86,
        zh = {
            Name = "瓶中阴影",
            Desc = "如坠深渊",
            Description = "首次进入未清理房间时，召唤1名随机友方阴影敌人"..
            "#重复持有会额外召唤",
        },
        en = {
            Name = "Shadow Bottle",
            Desc = "Just like inferno",
            Description = "On first entry to an uncleared room, summon 1 random friendly shadow enemy"..
            "#Extra copies summon additional shadows",
        },
    },
    [76] = {
        Name = "真实之名",
        id = Items.The_True_Name,
        type = "active",
        xmlId = 87,
        zh = {
            Name = "真实之名",
            Desc = "吾名，阿图姆",
            Description = "使用后，从所有道具中选择1件作为你的猜测"..
            "#随后揭示当前道具池的下一件道具"..
            "#猜中：生成你猜的道具，并额外生成{{Collectible628}}死亡证明"..
            "#猜错：本次预测失败",
            BookOfBelial = "改为从恶魔房道具池揭示下一件道具",
            BookOfVirtues = "猜中后生成对应道具的魂火",
        },
        en = {
            Name = "The True Name",
            Desc = "ATEM!",
            Description = "On use, pick 1 collectible from all items as your guess"..
            "#Then reveal the next item from the current item pool"..
            "#Correct: spawn that item plus {{Collectible628}} Death Certificate"..
            "#Wrong: the prediction fails",
            BookOfBelial = "Reveal from the Devil Room pool instead",
            BookOfVirtues = "On a correct guess, spawn a wisp of that item",
        },
    },
    [77] = {
        Name = "蓝图",
        id = Items.Blue_Print,
        type = "active",
        xmlId = 88,
        zh = {
            Name = "蓝图",
            Desc = "别担心，我有图纸",
            Description = "长按使用打开蓝图，制造并管理飞行器"..
            "#{{Collectible}} 机体底座决定基础性能，装入的道具成为攻击或功能模块"..
            "#{{Battery}} 控制带宽限制同时出战的飞行器"..
            "#持有蓝图时，有机会发现可用于制造的道具原型",
        },
        en = {
            Name = "Blueprint",
            Desc = "Don't worry, I've got the plans",
            Description = "Hold to open Blueprint and craft / manage your fleet"..
            "#{{Collectible}} Frame pedestals set base power; installed items become attack or utility modules"..
            "#{{Battery}} Control bandwidth limits how many crafts can fight at once"..
            "#While held, Item Prototypes for crafting may appear",
        },
    },
    [78] = {
        Name = "戴森球",
        id = Items.Dyson_Star,
        type = "passive",
        xmlId = 89,
        Hidden = "true",
        zh = {
            Name = "戴森球",
            Desc = "让群星为我们燃烧",
            Description = "一组自我建设的跟班"..
            "#环绕房间中的敌人，吸收弹幕攻击并建设自己"..
            "#根据建设的文明等级获得以下效果",
        },
        en = {
            Name = "Dyson Star",
            Desc = "May you be surrounded by stars",
            Description = "Four spinning blades that cut enemies",
            "#Rotate and launch enemies when they are close to it",
            "#Longest cooldown: 30 seconds",
        },
    },
    [79] = {
        Name = "超忆症",
        id = Items.Hypermnesia,
        type = "passive",
        xmlId = 90,
        zh = {
            Name = "超忆症",
            Desc = "未来来来来来来来来来来",
            Description = "#你身上每个重复的道具为你提供额外属性加成"..
            "#{{Damage}} +0.5攻击"..
            "#{{Tears}} +0.15射速"..
            "#{{Range}} +1射程"..
            "#{{Speed}} +0.05移速"..
            "#{{Luck}} +1幸运"..
            "#{{Collectible"..tostring(enums.Items.Memory).."}} 此道具的生成不受道具回忆影响",
            AbyssSynic = "彩色蝗虫",
        },
        en = {
            Name = "Hypermnesia",
            Desc = "Foreverevereverevereverever",
            Description = "Gain bonus for every repetitive item that Isaac has"..
            "#{{Damage}} +0.5 Damage up"..
            "#{{Tears}} +0.15 Tear up"..
            "#{{Range}} +1 Range up"..
            "#{{Speed}} +0.05 Speed up"..
            "#{{Luck}} +1 Luck up"..
            "#{{Collectible"..tostring(enums.Items.Memory).."}} This item is not affected by memory",
            AbyssSynic = "Colorful locust",
        },
    },
    [80] = {
        Name = "娇嫩的花",
        id = Items.Delicate_Flower,
        type = "passive",
        xmlId = 91,
        zh = {
            Name = "娇嫩的花",
            Desc = "送给爱你的人",
            Description = "每份道具提供1朵花，每层开始时重新补充"..
            "#{{Warning}} 受到敌人伤害会失去1朵花"..
            "#靠近店长、撒旦或天使时，可以将花赠送给对方"..
            "#根据收花者及所在房间获得不同回礼",
        },
        en = {
            Name = "Delicate Flower",
            Desc = "Wish you a better future",
            Description = "Each copy grants 1 flower; flower count resets to copies held at each new floor"..
            "#{{Warning}} Enemy damage destroys 1 flower"..
            "#Approach a Keeper, Satan, or an Angel to give them a flower"..
            "#Rewards depend on the recipient and the room type",
        },
    },
    [81] = {
        Name = "科技XIV",
        id = Items.Tech_14,
        type = "passive",
        xmlId = 92,
        zh = {
            Name = "科技XIV",
            Desc = "强盛是衰败的旗手",
            Description = "行走时在经过的格子留下科技限制器"..
            "#相邻限制器之间形成可触发的连接"..
            "#敌人穿过连接时发射短暂激光，并消耗其中一个限制器",
            AbyssSynic = "留下科技限制器的蝗虫",
        },
        en = {
            Name = "Tech 14",
            Desc = "Prosperity leads to decline",
            Description = "Walking leaves technology limiters on crossed grid cells"..
            "#Adjacent limiters form triggerable connections"..
            "#Enemies crossing a connection fire a brief laser and consume one limiter",
            AbyssSynic = "Locust leaving technology limiters",
        },
    },
    [82] = {
        Name = "求索者之眼",
        id = Items.Seeker_s_Eye,
        type = "passive",
        xmlId = 93,
        zh = {
            Name = "求索者之眼",
            Desc = "这条路不是答案",
            Description = "偏离目标的眼泪会短暂停顿并重新求索附近敌人"..
            "#每枚眼泪最多重新寻找3次"..
            "#{{Damage}} 每次求索都会增强该眼泪，最高造成150%伤害",
        },
        en = {
            Name = "Seeker's Eye",
            Desc = "This path is not the answer",
            Description = "Off-course tears briefly pause and reseek nearby enemies"..
            "#Each tear can reseek up to 3 times"..
            "#{{Damage}} Each seek strengthens that tear, up to 150% damage",
        },
    },
    [83] = {
        Name = "白日梦",
        id = Items.Day_Dreamer,
        type = "passive",
        xmlId = 94,
        zh = {
            Name = "白日梦",
            Desc = "如果四级道具能从天上掉下来就好了",
            Description = "每层开始时，在起始房间静止约5秒进入梦境"..
            "#梦见一个品质4道具，梦中按 {{ButtonLT}} 可放弃当前候选并等待下一件"..
            "#{{Timer}} 约60秒后醒来，获得当前候选的效果直到本层结束"..
            "#{{Warning}} 离开起始房前没有入睡，本层将无法再次做梦",
            SeijaNerf = "改为梦见0级道具",
        },
        en = {
            Name = "Day Dreamer",
            Desc = "If only my wish would come true",
            Description = "At floor start, stand still ~5s in the starting room to enter a dream"..
            "#Dream a quality 4 item; press {{ButtonLT}} to discard it and wait for the next"..
            "#{{Timer}} After ~60s, wake with the current pick's effect for the floor"..
            "#{{Warning}} If you leave the start room before sleeping, no dream this floor",
            SeijaNerf = "Dream quality 0 items instead",
        },
    },
    [84] = {
        Name = "天象失权",
        id = Items.Disequilibrium,
        type = "passive",
        xmlId = 95,
        zh = {
            Name = "天象失权",
            Desc = "IV",
            Description = "缝合你的恶魔房与天使房"..
            "#{{DevilRoom}} 恶魔侧道具需要血量交易"..
            "#{{AngelRoom}} 天使侧道具只能拿一个",
        },
        en = {
            Name = "Disequilibrium",
            Desc = "IV",
            Description = "Sew your {{DevilRoom}} Devil Room and {{AngelRoom}} Angel Room together"..
            "#{{DevilRoom}} Devil items require health trading"..
            "#{{AngelRoom}} Only one angel item can be taken",
        },
    },
    [85] = {
        Name = "天象解构",
        id = Items.Destruction,
        type = "passive",
        xmlId = 96,
        zh = {
            Name = "天象解构",
            Desc = "VI",
            Description = "{{Card78}} 每层开始获得3张红钥匙碎片"..
            "#最多4间特殊房会被搬到正常地图之外"..
            "#使用红钥匙碎片重新打开通往这些房间的路线"..
            "#{{Card78}} 每间被搬走的特殊房首次进入时返还1张碎片",
        },
        en = {
            Name = "Deconstruction",
            Desc = "VI",
            Description = "{{Card78}} Gain 3 Cracked Keys at the start of each floor"..
            "#Up to 4 special rooms move beyond the normal map"..
            "#Use Cracked Keys to reopen routes to those rooms"..
            "#{{Card78}} Each moved room returns 1 Cracked Key on its first visit",
        },
    },
    [86] = {
        Name = "贤者之石",
        id = Items.Philosopher_s_stone,
        type = "active",
        xmlId = 97,
        zh = {
            Name = "贤者之石",
            Desc = "杰作",
            Description = "{{Battery}} 吸收3个空道具底座即可充满"..
            "#使用时，使最近的道具在一组固定候选之间快速切换",
            BookOfVirtues = "有概率将敌人点金的金色魂火",
            SeijaNerf = "75%概率将目标道具变成彩虹大便",
        },
        en = {
            Name = "Philosopher's Stone",
            Desc = "Masterpiece",
            Description = "{{Battery}} Absorb 3 empty item pedestals to fully charge"..
            "#On use, makes the nearest item rapidly cycle through a fixed set of alternatives",
            BookOfVirtues = "Golden wisp with a chance to turn enemies to gold",
            SeijaNerf = "75% chance to turn the target item into a rainbow poop",
        },
    },
    [87] = {
        Name = "辉煌",
        id = Items.Brilliant,
        type = "passive",
        xmlId = 98,
        zh = {
            Name = "辉煌",
            Desc = "献给永恒之金",
            Description = "{{GoldenHeart}} +3金心"..
            "#{{Shop}} 每颗金心使硬币商品价格-1"..
            "#{{Coin}} 辉煌自身售价不会高于当前硬币数，0硬币时仍售价1",
        },
        en = {
            Name = "Brilliant",
            Desc = "To the gold of eternity",
            Description = "{{GoldenHeart}} +3 Golden Hearts"..
            "#{{Shop}} Each Golden Heart reduces coin prices by 1"..
            "#{{Coin}} Brilliant's price cannot exceed your coins; at 0 coins it still costs 1",
        },
    },
    [88] = {
        Name = "博爱",
        id = Items.Fraternity,
        type = "passive",
        xmlId = 99,
        zh = {
            Name = "博爱",
            Desc = "爱屋及乌",
            Description = "{{Charm}} 生成一个跟随角色的魅惑光环"..
            "#光环靠近敌人后会魅惑目标，并转而跟随该敌人",
            AbyssSynic = "命中敌人时有10%概率魅惑目标",
        },
        en = {
            Name = "Fraternity",
            Desc = "love me,love my dog",
            Description = "{{Charm}} Spawn a charm halo that follows the character"..
            "#Approaching an enemy charms it, then the halo follows that target",
            AbyssSynic = "10% chance to charm enemies on hit",
        },
    },
    [89] = {
        Name = "终末倒数",
        id = Items.Ending_Count,
        type = "active",
        xmlId = 100,
        zh = {
            Name = "终末倒数",
            Desc = "请稍等片刻...",
            Description = "使用后抽取一个随机主动道具效果，并显示在角色头顶"..
            "#{{Timer}} 30秒后自动发动该主动道具一次",
        },
        en = {
            Name = "Ending Count",
            Desc = "Please wait a moment...",
            Description = "Draw a random active-item effect and display it above the character"..
            "#{{Timer}} After 30 seconds, automatically activate it once",
        },
    },
    [90] = {
        Name = "作弊者的祝福",
        id = Items.Cheater_s_Blessing,
        type = "passive",
        xmlId = 101,
        Hidden = "true",
        zh = {
            Name = "作弊者的祝福",
            Desc = "你打得也太好了！",
            Description = "本局第3次完成rewind回溯后生成"..
            "#拾取时获得一次圣洁卡片的神圣屏障"..
            "#全属性极小幅上升",
            SeijaNerf = "受伤后触发一次{{Collectible422}}发光沙漏",
        },
        en = {
            Name = "Cheater's Blessing",
            Desc = "I'm so glad that you cheat so many times",
            Description = "Appears after the 3rd completed rewind in a run"..
            "#On pickup, gain one Holy Card shield"..
            "#Very small all-stats up",
            SeijaNerf = "Taking damage triggers Glowing Hour Glass",
        },
    },
    [91] = {
        Name = "次元之楔",
        id = Items.Dimension_Contact,
        type = "active",
        xmlId = 102,
        zh = {
            Name = "次元之楔",
            Desc = "我发现了新通道！",
            Description = "从尚未探索的房间中随机拉来2-3名敌人"..
            "#这些敌人会在当前房间与你战斗"..
            "#它们原本占用的刷怪位置会被留空",
            BookOfVirtues = "发射传送泪弹的红色魂火",
        },
        en = {
            Name = "Dimension Contact",
            Desc = "I found a new passage!",
            Description = "Pull 2-3 enemies from unexplored rooms"..
            "#Fight them in the current room"..
            "#Their original spawn positions will be left empty",
            BookOfVirtues = "Red wisp that fires teleporting tears",
        },
    },
    [92] = {
        Name = "世界弧",
        id = Items.World_Arc,
        type = "active",
        xmlId = 103,
        zh = {
            Name = "世界弧",
            Desc = "天下如一",
            Description = "使用后消失，并获得一个持续本层的随机被动道具效果"..
            "#随后随机藏进本层另一间房"..
            "#找到它即可再次使用"..
            "#本层未找到时，下层会再次出现",
            BookOfBelial = "随机被动道具来自恶魔道具池",
            BookOfVirtues = "额外生成一个随机道具魂火",
        },
        en = {
            Name = "World Arc",
            Desc = "The world is so small!",
            Description = "Disappears on use and grants a random passive effect for the floor"..
            "#Then hides in another random room on the floor"..
            "#Find it to use it again"..
            "#If left behind, it reappears on the next floor",
            BookOfBelial = "Random passive item from devil pool",
            BookOfVirtues = "Spawns an additional random item wisp",
        },
    },
    [93] = {
        Name = "最终棱镜",
        id = Items.Final_Prism,
        type = "active",
        xmlId = 104,
        zh = {
            Name = "最终棱镜",
            Desc = "异世界的赠礼",
            Description = "未开启时自动恢复充能"..
            "#使用后持续发射6道彩色激光，并不断消耗充能"..
            "#持续照射时，光束逐渐聚拢并增强"..
            "#照射中再次使用：消耗10充能，光束+3",
            BookOfBelial = "改为发射彩色硫磺火",
            BookOfVirtues = "协同发射激光的魂火",
        },
        en = {
            Name = "Final Prism",
            Desc = "A gift from another world",
            Description = "Recharges automatically while inactive"..
            "#On use, fires 6 colored lasers and drains charge"..
            "#Beams gradually converge and grow stronger while held"..
            "#While active, use again: spend 10 charge, +3 beams",
            BookOfBelial = "Fire rainbow brimstone",
            BookOfVirtues = "Wisps firing laser together with Isaac",
        },
    },
    [94] = {
        Name = "卢恩之书",
        id = Items.Book_of_Rune,
        type = "active",
        xmlId = 105,
        zh = {
            Name = "卢恩之书",
            Desc = "回三，抽三，回三，抽三...",
            Description = "{{Rune}} 首次拾取生成1张随机符文"..
            "#{{Rune}} 本房间每使用1张符文，记录1次，最多3次"..
            "#使用本书，按记录数生成等量随机符文"..
            "#{{Rune}} 持有符文时，可额外携带1张卡牌或药丸"..
            "#离开房间时清空记录",
            BookOfVirtues = "成功生成符文时产生魂火；泪弹有0.05%概率使击杀敌人掉落符文",
            SeijaNerf = "90%概率生成{{Card55}}符文碎片",
        },
        en = {
            Name = "Book of Rune",
            Desc = "Return three, draw three...",
            Description = "{{Rune}} First pickup spawns 1 random rune"..
            "#{{Rune}} Each rune used this room records 1 use, up to 3"..
            "#Use the book to spawn that many random runes"..
            "#{{Rune}} Carry 1 extra card or pill while holding a rune"..
            "#Leaving the room clears the record",
            BookOfVirtues = "Spawns a wisp on successful rune spawn; tears have 0.05% chance for kills to drop runes",
            SeijaNerf = "90% chance to spawn {{Card55}} Rune Shard",
        },
    },
    [95] = {
        Name = "邪恶干涉",
        id = Items.Evil_Intervention,
        type = "passive",
        xmlId = 106,
        zh = {
            Name = "邪恶干涉",
            Desc = "拥抱不祥",
            Description = "概率发射穿透并追踪敌人的蝴蝶泪"..
            "#蝴蝶泪会吞噬接触的敌方弹幕，并截断敌方激光"..
            "#蝴蝶消失时，将吸收的攻击转化为友方泪弹与硫磺火返还",
        },
        en = {
            Name = "Evil Intervention",
            Desc = "Embrace ominous",
            Description = "Chance to fire a piercing, homing butterfly tear"..
            "#It devours enemy projectiles and intercepts enemy lasers"..
            "#On disappearing, returns absorbed attacks as friendly tears and Brimstone",
        },
    },
    [96] = {
        Name = "论如何飞行",
        id = Items.Book_of_How_to_Fly,
        type = "active",
        xmlId = 107,
        zh = {
            Name = "论如何飞行",
            Desc = "点击，点击，再点击！",
            Description = "使用时向上扑动，随后逐渐落下"..
            "#下落前再次使用，可以继续升高"..
            "#飞得足够高时，可以越过障碍与敌人",
            BookOfBelial = "从角色高度向下抛射眼泪",
            BookOfVirtues = "从角色高度向下飘落的魂火",
        },
        en = {
            Name = "How to Fly",
            Desc = "Tap Tap tap!",
            Description = "Flap upward on use, then gradually fall"..
            "#Use again before landing to keep climbing"..
            "#At sufficient height, pass over obstacles and enemies",
            BookOfBelial = "Throw tears down from the height of the character",
            BookOfVirtues = "Wisp falling from the height of the character",
        },
    },
    [97] = {
        Name = "天象破幻",
        id = Items.Illumination,
        type = "active",
        xmlId = 108,
        zh = {
            Name = "天象破幻",
            Desc = "I",
            Description = "!!! 一次性"..
            "#使用后举起道具，按攻击方向确认"..
            "#{{Collectible580}} 沿所选方向连续开启红房间，直到无法继续"..
            "#举起后再次使用可取消选择",
        },
        en = {
            Name = "Illumination",
            Desc = "I",
            Description = "!!! SINGLE USE"..
            "#Lift it overhead, then press a fire direction to confirm"..
            "#{{Collectible580}} Opens Red Rooms along that direction until blocked"..
            "#Press active again while raised to cancel",
        },
    },
    [98] = {
        Name = "天象窥井",
        id = Items.Contemplation,
        type = "passive",
        xmlId = 109,
        zh = {
            Name = "天象窥井",
            Desc = "III",
            Description = "{{Collectible628}} 进入未探索的房间时，有4%概率短暂进入死亡证明层"..
            "#每多持有1份，概率+4%"..
            "#1-3秒后进入原本要去的房间",
        },
        en = {
            Name = "Contemplation",
            Desc = "III",
            Description = "{{Collectible628}} Entering an unexplored room has a 4% chance to briefly enter the Death Certificate floor"..
            "#Each extra copy adds +4% chance"..
            "#After 1-3 seconds, enter the intended room",
        },
    },
    [99] = {
        Name = "天象入渊",
        id = Items.Chasm,
        type = "passive",
        xmlId = 110,
        zh = {
            Name = "天象入渊",
            Desc = "V",
            Description = "{{SecretRoom}} 隐藏房中会出现通往“深渊”的吊索"..
            "#接触吊索后进入一个独立的深渊房间"..
            "#深渊中藏有额外奖励，之后可通过吊索返回",
        },
        en = {
            Name = "Chasm",
            Desc = "V",
            Description = "{{SecretRoom}} A hanger leading to the Chasm appears in Secret Rooms"..
            "#Touch it to enter a separate Chasm room"..
            "#Find extra rewards there, then use the hanger to return",
        },
    },
    [100] = {
        Name = "六罪论",
        id = Items.Book_of_6_sin,
        type = "passive",
        xmlId = 111,
        zh = {
            Name = "六罪论",
            Desc = "除却愤怒",
            Description = "{{Bomb}} 免疫爆炸伤害"..
            "#本局首次击败其余六种七宗罪时，获得对应奖励："..
            "#嫉妒：本局获得穿透与灵体泪"..
            "#{{Card}} 贪婪：生成3张卡牌"..
            "#{{Collectible}} 傲慢：生成随机道具三选一"..
            "#{{Card31}} 色欲：生成一张小丑卡"..
            "#{{Coin}} 懒惰：本局商店价格-1"..
            "#{{Card78}} 暴食：生成2个红钥匙碎片",
            BookOfBelial = "傲慢：生成恶魔道具池三选一道具",
        },
        en = {
            Name = "Book of 6 sin",
            Desc = "Except Anger",
            Description = "{{Bomb}} Immunity to explosion damage"..
            "#First time each of the other six Sins is defeated this run, gain its reward:"..
            "#Envy: Piercing and spectral tears for the run"..
            "#{{Card}} Greed: Spawns 3 cards"..
            "#{{Collectible}} Pride: Spawns a choice of 3 random items"..
            "#{{Card31}} Lust: Spawns a Joker card"..
            "#{{Coin}} Sloth: Shop prices -1 for the run"..
            "#{{Card78}} Gluttony: Spawns 2 Cracked Keys",
            BookOfBelial = "Pride: Allow Isaac to choose between 3 items from devil item pool",
        },
    },
    [101] = {
        Name = "悲悯",
        id = Items.Pathetique,
        type = "passive",
        xmlId = 112,
        zh = {
            Name = "悲悯",
            Desc = "它们被迫为我而死",
            Description = "受到敌人伤害时，牺牲1件被动道具并抵消伤害"..
            "#低品质道具更容易被牺牲"..
            "#{{Tears}} 每件被牺牲的道具使射速+0.5，并在牺牲时释放攻击"..
            "#失去悲悯时，返还所有因此失去的道具",
            SeijaNerf = "失去道具不再获得射速提升",
        },
        en = {
            Name = "Pathetique",
            Desc = "They die for me",
            Description = "Taking enemy damage sacrifices 1 passive item and negates the hit"..
            "#Lower-quality items are more likely to be sacrificed"..
            "#{{Tears}} Each sacrificed item grants +0.5 tears and releases an attack"..
            "#Losing Pathetique returns all items lost this way",
            SeijaNerf = "Lost items no longer grant tears up",
        },
    },
    [102] = {
        Name = "暗黑神秘学",
        id = Items.Dark_Mysticism,
        type = "passive",
        xmlId = 113,
        zh = {
            Name = "暗黑神秘学",
            Desc = "暗面重现",
            Description = "50%概率抵消受到的伤害"..
            "#成功时向四周释放高伤害的黑色眼泪，并恐惧敌人",
			SeijaNerf = "成功抵消伤害时，自己也会恐惧约3秒，期间无法攻击",
        },
        en = {
            Name = "Dark Mysticism",
            Desc = "Darkside Reproduction",
            Description = "50% chance to negate damage taken"..
            "#On success, fire high-damage black tears in four directions and fear enemies",
            SeijaNerf = "On a successful negate, also fear yourself for ~3s and cannot attack",
        },
    },
    [103] = {
        Name = "鲜活死者",
        id = Items.Fresh_Death,
        type = "passive",
        xmlId = 114,
        zh = {
            Name = "鲜活死者",
            Desc = "让我犯呕",
            Description = "获得3个随机被动道具的效果",
        },
        en = {
            Name = "Fresh Death",
            Desc = "Yuck!",
            Description = "Grants the effects of 3 random passive items",
        },
    },
    [104] = {
        Name = "新式缝合针",
        id = Items.The_Suture_Needle,
        type = "active",
        xmlId = 115,
        zh = {
            Name = "新式缝合针",
            Desc = "自左心室刺入",
            Description = "失去所有{{Heart}}红心并+1{{BrokenHeart}}碎心"..
            "#将房间中的道具底座全部转化为{{Collectible"..tostring(enums.Items.Fresh_Death).."}}鲜活死者"..
            "#每份鲜活死者提供3个随机被动道具效果",
            BookOfBelial = "{{Collectible"..tostring(enums.Items.Fresh_Death).."}}鲜活死者只提供恶魔道具池的被动效果",
            BookOfVirtues = "{{Collectible"..tostring(enums.Items.Fresh_Death).."}}鲜活死者只提供天使道具池的被动效果",
            SeijaNerf = "总计+3碎心",
        },
        en = {
            Name = "The Suture Needle",
            Desc = "Left Ventricular Puncture",
            Description = "Lose all {{Heart}} red hearts and gain +1{{BrokenHeart}} broken heart"..
            "#Convert all pedestals in the room into {{Collectible"..tostring(enums.Items.Fresh_Death).."}} Fresh Death"..
            "#Each Fresh Death grants 3 random passive effects",
            BookOfBelial = "{{Collectible"..tostring(enums.Items.Fresh_Death).."}} Fresh Death only rolls Devil pool passives",
            BookOfVirtues = "{{Collectible"..tostring(enums.Items.Fresh_Death).."}} Fresh Death only rolls Angel pool passives",
            SeijaNerf = "+3 broken hearts total",
        },
    },
    [105] = {
        Name = "琉璃镜片",
        id = Items.Glaze_Mirror,
        type = "passive",
        xmlId = 116,
        zh = {
            Name = "琉璃镜片",
            Desc = "有点晃眼...",
            Description = "生成4-8个琉璃掉落物"..
            "#{{Luck}} 靠近角色的敌方弹幕有概率被镜面偏折",
        },
        en = {
            Name = "Glaze Mirror",
            Desc = "Kind of dazzling",
            Description = "Spawns 4-8 glaze pickups"..
            "#{{Luck}} Nearby enemy projectiles may be mirrored away",
        },
    },
    [106] = {
        Name = "精神失序",
        id = Items.Mental_Disorder,
        type = "passive",
        xmlId = 117,
        zh = {
            Name = "精神失序",
            Desc = "这里原本有两个",
            Description = "进入房间时概率产生一个{{ColorRainbow}}错误事实{{CR}}"..
            "#将一个敌人、掉落物或已有道具效果错认为存在第二份"..
            "#离开房间时，未被利用的错误会被纠正"..
            "#同时只能存在一个错误事实",
            Rnd_Special = {
                Name = "精神失序",
                Description = "我记得不是这样的",
                weigh = 5,
            },
        },
        en = {
            Name = "Mental Disorder",
            Desc = "There used to be two.",
            Description = "Entering a room may create a {{ColorRainbow}}false fact{{CR}}"..
            "#Mistakes an enemy, pickup, or existing item effect as having a second copy"..
            "#Unused errors are corrected when leaving the room"..
            "#Only one false fact may exist at a time",
            Rnd_Special = {
                Name = "Mental Disorder",
                Description = "I don't remember it this way.",
                weigh = 5,
            },
        },
    },
    [107] = {
        Name = "妄想症",
        id = Items.Paranoia,
        type = "passive",
        xmlId = 118,
        zh = {
            Name = "妄想症",
            Desc = "这里有个骰子",
            Description = "被拾取的道具有50%概率保留在原地",
            SeijaNerf = "拾取的道具有5%概率替换为{{Collectible258}}编号错误",
        },
        en = {
            Name = "Paranoia",
            Desc = "There is a dice",
            Description = "Picked items have a 50% chance of remaining in place",
            SeijaNerf = "5% chance for picked items to become {{Collectible258}} Missing No",
        },
    },
    [108] = {
        Name = "诅咒面具",
        id = Items.Cursed_Mask,
        type = "passive",
        xmlId = 119,
        zh = {
            Name = "诅咒面具",
            Desc = "你感到头晕目眩",
            Description = "进入房间后，射击方向会持续旋转并逐渐减慢"..
            "#{{Damage}} +2攻击"..
            "#{{Collectible260}} 保留属性提升，但不会再旋转射击方向",
            SeijaBuff = "{{Tears}} +2射速"..
            "#旋转中的瞄准方向会尝试追踪敌人",
        },
        en = {
            Name = "Cursed Mask",
            Desc = "You feel dizzy and dizzy",
            Description = "After entering a room, your firing direction spins and gradually slows"..
            "#{{Damage}} +2 Damage"..
            "#{{Collectible260}} Keeps the damage bonus, but no longer spins your aim",
            SeijaBuff = "{{Tears}} +2 Tears"..
            "#Spinning aim tries to track nearby enemies",
        },
    },
    [109] = {
        Name = "血仪刺刃",
        id = Items.Ritual_Sting,
        type = "active",
        xmlId = 120,
        zh = {
            Name = "血仪刺刃",
            Desc = "以血调色",
            Description = "献祭持有道具，为所选颜色充能"..
            "#达到100%时点亮该颜色能力"..
            "#击杀精英也会少量补充对应颜色"..
            "#点亮的颜色会随清理房间逐渐消耗",
        },
        en = {
            Name = "Ritual Sting",
            Desc = "Color with blood",
            Description = "Sacrifice a held collectible to charge the selected color"..
            "#Its ability activates at 100%"..
            "#Defeating champions slightly charges matching colors"..
            "#Lit colors gradually drain after clearing rooms",
        },
    },
    [110] = {
        Name = "虚无假眼",
        id = Items.Nihilistic_Artificial_Eye,
        type = "passive",
        xmlId = 121,
        zh = {
            Name = "虚无假眼",
            Desc = "目不能视",
            Description = "出现时额外生成3件随机道具，组成四选一"..
            "#{{Damage}} +0.33攻击"..
            "#拾取后获得2次机会，使之后生成的道具有10%概率替换为虚无假眼",
            SeijaNerf = "伴生道具环绕速度提高至4倍",
        },
        en = {
            Name = "Nihilistic Artificial Eye",
            Desc = "I can't see...",
            Description = "Spawns with 3 extra random collectibles as a 4-choice set"..
            "#{{Damage}} +0.33 Damage"..
            "#On pickup, gain 2 chances for later collectibles to become this item (10% each)",
            SeijaNerf = "Companion orbit speed is 4× faster",
        },
    },
    [111] = {
        Name = "幻像冠冕",
        id = Items.Phantom_Crown,
        type = "passive",
        xmlId = 122,
        zh = {
            Name = "幻像冠冕",
            Desc = "嘲弄虚无",
            Description = "{{Chargeable}} 蓄力后发射向前移动的幻影"..
            "#{{Warning}} 受到敌人伤害时，消耗幻影抵消伤害并冲向其位置"..
            "#冲刺期间无敌；抵达后对周围敌人造成{{Damage}} 5倍攻击伤害",
            SeijaNerf = "幻影移动速度提高至2.5倍",
        },
        en = {
            Name = "Phantom Crown",
            Desc = "Mocking Nothingness",
            Description = "{{Chargeable}} Charge to fire a forward-moving phantom"..
            "#{{Warning}} When taking enemy damage, consume the phantom to negate the hit and dash to it"..
            "#Invincible during the dash; on arrival deal {{Damage}} 5× damage to nearby enemies",
            SeijaNerf = "Phantom movement speed is 2.5× faster",
        },
    },
    [112] = {
        Name = "血翼",
        id = Items.Blood_Wing,
        type = "passive",
        xmlId = 123,
        zh = {
            Name = "血翼",
            Desc = "飞行+收割鲜血",
            Description = "↑ 获得飞行"..
            "#{{Chargeable}} 贴墙约2秒完成蓄力"..
            "#蓄满后离墙会无敌冲刺约2秒，并向身后持续喷射30%攻击伤害的硫磺火",
        },
        en = {
            Name = "Blood Wing",
            Desc = "Flying + Harvesting Blood",
            Description = "↑ Grants flight"..
            "#{{Chargeable}} Charge by hugging a wall for about 2 seconds"..
            "#Leave the wall at full charge for an invincible ~2s dash that sprays 30% damage Brimstone behind you",
        },
    },
    [113] = {
        Name = "次时代炬火",
        id = Items.Subera_Light,
        type = "passive",
        xmlId = 124,
        zh = {
            Name = "次时代炬火",
            Desc = "旧日破碎",
            Description = "生成6个自动锁定敌人的激光发射器"..
            "#{{Chargeable}} 持续攻击约2秒完成蓄力"..
            "#蓄满后松开攻击，所有发射器同时射出30%攻击伤害的激光",
            SeijaNerf = "第一份仅生成1个激光发射器",
        },
        en = {
            Name = "Subera Light",
            Desc = "Break the old days",
            Description = "Creates 6 auto-locking laser emitters"..
            "#{{Chargeable}} Hold fire for about 2 seconds to finish charging"..
            "#Release when full so every emitter fires 30% damage lasers at once",
            SeijaNerf = "First copy creates only 1 laser emitter",
        },
    },
    [114] = {
        Name = "D++",
        id = Items.D_Plus,
        type = "active",
        xmlId = 125,
        zh = {
            Name = "D++",
            Desc = "缝合致死",
            Description = "{{Battery}} 至少1格充能即可使用，并消耗当前全部充能"..
            "#消耗几格充能，就将当前D编号向前推进几格"..
            "#到达新编号后，触发所有与该编号匹配的骰子效果"..
            "#{{Collectible476}} D1始终触发",
        },
        en = {
            Name = "D++",
            Desc = "Stitching to death",
            Description = "{{Battery}} Usable with at least 1 charge; spends all current charges"..
            "#Spending N charges advances the current D number by N"..
            "#On the new number, triggers every matching die effect"..
            "#{{Collectible476}} D1 always fires",
        },
    },
    [115] = {
        Name = "香格里拉",
        id = Items.Shangrila,
        type = "passive",
        xmlId = 126,
        zh = {
            Name = "香格里拉",
            Desc = "天魔袭来",
            Description = "持续开火时，维持空袭节奏并周期性呼叫随机火力支援"..
            "#支援包括导弹、硫磺火炮与旋转激光装置"..
            "#这些空袭不会伤害角色",
            SeijaNerf = "空袭路径上会随机生成通往下层的活板门",
        },
        en = {
            Name = "Shangrila",
            Desc = "Kashtira Arrival",
            Description = "While firing, keeps an airstrike rhythm and periodically calls random aerial support"..
            "#Support includes missiles, brimstone cannons, and spinning laser devices"..
            "#These strikes cannot harm the player",
            SeijaNerf = "Aerial support paths may spawn trapdoors to the next floor",
        },
    },
    [116] = {
        Name = "命运锚点",
        id = Items.Destiny_Anchor,
        type = "active",
        xmlId = 127,
        zh = {
            Name = "命运锚点",
            Desc = "过去仍在前方等待",
            Description = "使用时锚定当前房间，每层最多3个"..
            "#进入下一层时，锚定内容会优先映射到普通房间"..
            "#无法完整复现时，仅保留部分锚定内容"..
            "#再次使用可取消当前房间的锚定",
            BookOfVirtues = "新建锚点时生成留守此处的命运魂火",
            BookOfBelial = "{{DevilRoom}} 可锚定恶魔房，并在下层恶魔房开启时复现",
        },
        en = {
            Name = "Destiny Anchor",
            Desc = "The past still waits ahead",
            Description = "Anchors the current room on use, up to 3 per floor"..
            "#On the next floor, anchored content prefers mapping into normal rooms"..
            "#If it cannot fully reproduce, only part of the anchored content returns"..
            "#Use again in an anchored room to cancel that anchor",
            BookOfVirtues = "New anchors spawn a Destiny Wisp that remains there to guard them",
            BookOfBelial = "{{DevilRoom}} Devil Rooms can be anchored and reproduced if one opens next floor",
        },
    },
    [117] = {
        Name = "慕残症",
        id = Items.Acrotomophilia,
        type = "passive",
        xmlId = 128,
        zh = {
            Name = "慕残症",
            Desc = "腐烂而破碎",
            Description = "{{RottenHeart}} 失去红心血量时留下腐心"..
            "#{{BrokenHeart}} 失去心之容器时留下碎心"..
            "#腐心与碎心会彼此抵消，且不会因此直接致死",
        },
        en = {
            Name = "Acrotomophilia",
            Desc = "Rotten and Broken",
            Description = "{{RottenHeart}} Lost red health leaves Rotten Hearts"..
            "#{{BrokenHeart}} Lost Heart Containers leave Broken Hearts"..
            "#Rotten and Broken Hearts cancel each other and cannot kill by that cancel alone",
        },
    },
    [118] = {
        Name = "孤独",
        id = Items.Loneliness,
        type = "passive",
        xmlId = 129,
        zh = {
            Name = "孤独",
            Desc = "两位旅人在此交汇",
            Description = "第一次死亡时召来另一名角色救援"..
            "#被召来的角色留下并共同继续本局"..
            "#只要还有一人存活，游戏就不会结束",
        },
        en = {
            Name = "Loneliness",
            Desc = "Journey convergence",
            Description = "On the first death, summons another character to rescue"..
            "#The summoned character stays and continues the run together"..
            "#The run does not end while either character is still alive",
        },
    },
    [119] = {
        Name = "魔法胸针",
        id = Items.Core_Brooch,
        type = "active",
        xmlId = 130,
        zh = {
            Name = "魔法胸针",
            Desc = "神择祭品",
            Description = "!!! 最多选择10次"..
            "#每次随机展示3项基础属性"..
            "#选择其中1项强化，同时削弱另外2项"..
            "#用尽后碎裂为{{Trinket"..enums.Trinkets.Broken_Brooch.."}}破碎的胸针",
        },
        en = {
            Name = "Core Brooch",
            Desc = "Sacrifice of Heavenly Selection",
            Description = "!!! Choose up to 10 times"..
            "#Each use shows 3 random base stats"..
            "#Pick 1 to boost; the other 2 are weakened"..
            "#When spent, shatters into {{Trinket"..enums.Trinkets.Broken_Brooch.."}} Broken Brooch",
        },
    },
    [120] = {
        Name = "灵感",
        id = Items.Inspiration,
        type = "passive",
        xmlId = 131,
        zh = {
            Name = "灵感",
            Desc = "由幻象救赎",
            Description = "清理房间后有概率额外生成奖励幻像"..
            "#幻像不会取代原本的清房奖励"..
            "#生命极低时触碰幻像才会变为现实",
        },
        en = {
            Name = "Inspiration",
            Desc = "Redemption by Illusion",
            Description = "Clearing a room may spawn an extra reward illusion"..
            "#The illusion does not replace the normal clear reward"..
            "#Only at extremely low health does touching it make it real",
        },
    },
    [121] = {
        Name = "饿魔汉堡",
        id = Items.Hunger_Burger,
        type = "passive",
        xmlId = 132,
        zh = {
            Name = "饿魔汉堡",
            Desc = "压轴美味！",
            Description = "{{Heart}} +2心之容器"..
            "#{{Damage}} +1攻击"..
            "#{{Speed}} +0.3移速"..
            "#击杀敌人时生成小饿魔，追咬其他敌人并使其恐惧",
            SeijaNerf = "饥饿的小饿魔追着玩家咬并逐渐损失生命",
        },
        en = {
            Name = "Hunger Burger",
            Desc = "Delicious finale",
            Description = "{{Heart}} +2 Heart Containers"..
            "#{{Damage}} +1 Damage"..
            "#{{Speed}} +0.3 Speed"..
            "#Killing enemies spawns little hungers that bite and fear other enemies",
            SeijaNerf = "Hungry little hungers chase the player to bite and gradually lose life",
        },
    },
    [122] = {
        Name = "飞蚊症",
        id = Items.Muscae_Volitantes,
        type = "active",
        xmlId = 133,
        zh = {
            Name = "飞蚊症",
            Desc = "精灵魔术",
            Description = "使用后召来一群彩色飞蚊："..
            "#66%：留下2-3只彩虹苍蝇"..
            "#{{Trinket}} 33%：留下随机饰品"..
            "#{{Collectible}} 1%：留下随机道具",
            BookOfBelial = "留下的彩虹苍蝇变得血红，伤害路径上的敌人。留下的苍蝇被替换为{{Trinket113}}战争蝗虫",
            BookOfVirtues = "留下的苍蝇被替换为一颗彩虹魂火",
        },
        en = {
            Name = "Muscae Volitantes",
            Desc = "Magic of Flies",
            Description = "On use, summons a swarm of colorful flies:"..
            "#66%: leave 2-3 rainbow flies"..
            "#{{Trinket}} 33%: leave a random trinket"..
            "#{{Collectible}} 1%: leave a random item",
            BookOfBelial = "Rainbow flies turn blood-red and damage enemies on their path; leftover flies become {{Trinket113}} War Locust",
            BookOfVirtues = "Leftover flies become a rainbow wisp",
        },
    },
    [123] = {
        Name = "卡戎之印",
        id = Items.Charon_s_Sign,
        type = "passive",
        xmlId = 134,
        zh = {
            Name = "卡戎之印",
            Desc = "黑潮将至",
            Description = "进入楼层45秒后，黑潮从初始房向外蔓延"..
            "#黑潮逐渐吞噬地形与掉落物，但会避开玩家及机器、乞丐周围"..
            "#{{Damage}} 黑潮每秒对敌人造成7点伤害"..
            "#不会蔓延到其他维度",
            SeijaNerf = "黑潮整体推进速度提高至4倍"..
            "#不再吞噬掉落物，并会避开掉落物周围",
        },
        en = {
            Name = "Charon's Sign",
            Desc = "The Tide is approaching",
            Description = "After 45 seconds on a floor, a black tide spreads outward from the starting room"..
            "#The tide gradually consumes terrain and pickups, but keeps clear of Isaac and machines/beggars"..
            "#{{Damage}} Deals 7 damage per second to enemies in the tide"..
            "#Does not spread across dimensions",
            SeijaNerf = "Overall tide progress is 4× faster"..
            "#No longer consumes pickups and keeps clear of them",
        },
    },
    [124] = {
        Name = "宝宝泰克罗",
        id = Items.Baby_Tecro,
        type = "familiar",
        xmlId = 135,
        zh = {
            Name = "宝宝泰克罗",
            Desc = "我来刺穿！",
            Description = "{{Chargeable}} 持续攻击时预览一条可在墙壁间反射的突刺路线"..
            "#松开后沿锁定路线高速突进并伤害敌人"..
            "#蓄力越高，可延伸的反射次数越多",
        },
        en = {
            Name = "Baby Tecro",
            Desc = "I pierce!",
            Description = "{{Chargeable}} While firing, preview a wall-reflecting pierce path"..
            "#Release to dash along the locked path and damage enemies"..
            "#Higher charge extends more reflections",
        },
    },
    [125] = {
        Name = "宝宝安娜",
        id = Items.Baby_Anna,
        type = "familiar",
        xmlId = 136,
        zh = {
            Name = "宝宝安娜",
            Desc = "我来吞噬！",
            Description = "{{Chargeable}} 蓄力后向瞄准方向高速发射宝宝"..
            "#飞行过程中在身后留下{{Collectible118}}硫磺火尾迹",
        },
        en = {
            Name = "Baby Anna",
            Desc = "I devour!",
            Description = "{{Chargeable}} Charge, then launch the familiar toward your aim"..
            "#Leaves a {{Collectible118}} Brimstone trail while flying",
        },
    },
    [126] = {
        Name = "宝宝泽伊斯",
        id = Items.Baby_Zeis,
        type = "familiar",
        xmlId = 137,
        zh = {
            Name = "宝宝泽伊斯",
            Desc = "我来知晓！",
            Description = "每层开始时沉睡"..
            "#发现道具底座后醒来并飞向目标"..
            "#到达后复制一份该道具，本层仅触发一次",
        },
        en = {
            Name = "Baby Zeis",
            Desc = "I know!",
            Description = "Starts each floor asleep"..
            "#Wakes on finding an item pedestal and flies to it"..
            "#Copies that item on arrival; once per floor",
        },
    },
    [127] = {
        Name = "宝宝玛丽",
        id = Items.Baby_Marri,
        type = "familiar",
        xmlId = 138,
        zh = {
            Name = "宝宝玛丽",
            Desc = "我来质疑！",
            Description = "{{AngelRoom}} 初始为天使形态：天使房转化率+15%"..
            "#{{DevilRoom}} 受到伤害后切换为恶魔形态：恶魔房开启率+15%"..
            "#再次受到伤害时切回天使形态",
        },
        en = {
            Name = "Baby Marri",
            Desc = "I question!",
            Description = "{{AngelRoom}} Starts in Angel form: +15% Angel Room conversion chance"..
            "#{{DevilRoom}} Taking damage switches to Devil form: +15% Devil Room chance"..
            "#Taking damage again switches back to Angel form",
        },
    },
    [128] = {
        Name = "宝宝艾提奥",
        id = Items.Baby_Autio,
        type = "familiar",
        xmlId = 139,
        zh = {
            Name = "宝宝艾提奥",
            Desc = "我来掌控！",
            Description = "自动飞向敌人，并在目标附近展开恐惧光环"..
            "#光环持续恐惧并伤害范围内的敌人"..
            "#停留一段时间后返回角色身边",
        },
        en = {
            Name = "Baby Autio",
            Desc = "I command!",
            Description = "Flies to enemies and deploys a fear aura near the target"..
            "#The aura keeps applying fear and damages enemies inside"..
            "#Returns after lingering for a short time",
        },
    },
    [129] = {
        Name = "宝宝露",
        id = Items.Baby_Lu,
        type = "familiar",
        xmlId = 140,
        zh = {
            Name = "宝宝露",
            Desc = "我来安排！",
            Description = "举行仪式并依次标记数个特殊房间的宝宝"..
            "#随后生成用于前往这些房间的传送入口",
        },
        en = {
            Name = "Baby Lu",
            Desc = "I plan!",
            Description = "A familiar that performs a ritual to mark several special rooms"..
            "#Then creates portals leading to those rooms",
        },
    },
    [130] = {
        Name = "开天",
        id = Items.Kaitian,
        type = "passive",
        xmlId = 141,
        Hidden = "true",
        zh = {
            Name = "开天",
            Desc = "刺穿规则",
            Description = "攻击有概率标记敌人"..
            "#从屏幕外不断飞入飞针刺穿被标记的敌人"..
            "#未完成",
        },
        en = {
            Name = "Kaitian",
            Desc = "Puncture all rules",
        },
    },
    [131] = {
        Name = "倍增重刃",
        id = Items.Multiknife,
        type = "active",
        xmlId = 142,
        zh = {
            Name = "倍增重刃",
            Desc = "十年磨一剑",
            Description = "{{Battery}} 拥有至少1格充能时即可使用"..
            "#消耗当前全部充能，向瞄准方向挥出重刃"..
            "#{{Damage}} 1格充能造成100%角色攻击伤害"..
            "#每多1格充能，伤害与攻击范围翻倍",
            BookOfBelial = "{{Battery}} +2充能上限（最多12格），刀刃变为血红",
            BookOfVirtues = "每消耗1格充能生成一颗攻击和生命均为1的魂火",
        },
        en = {
            Name = "Multiknife",
            Desc = "Ten years I honed this sword",
            Description = "{{Battery}} Usable with at least 1 charge"..
            "#Spends all current charges to swing a heavy blade toward your aim"..
            "#{{Damage}} 1 charge deals 100% of your damage"..
            "#Each extra charge doubles damage and swing size",
            BookOfBelial = "{{Battery}} +2 charge cap (max 12). Blade turns blood-red",
            BookOfVirtues = "Spawns a 1 HP / 1 damage wisp per charge spent",
        },
    },
    [132] = {
        Name = "深渊龙牙",
        id = Items.Dragon_Tooth,
        type = "passive",
        xmlId = 143,
        zh = {
            Name = "深渊龙牙",
            Desc = "随我步入深渊",
            Description = "{{Damage}} 1.5倍攻击"..
            "#{{AngelRoom}} 每份本道具可污染1个天使房，使其中道具改用{{DevilRoom}}恶魔房道具池"..
            "#每成功污染1次，永久{{Damage}} +1攻击",
        },
        en = {
            Name = "Dragon Tooth",
            Desc = "Follow me into the abyss",
            Description = "{{Damage}} x1.5 Damage"..
            "#{{AngelRoom}} Each copy can pollute 1 Angel Room so its items use the {{DevilRoom}} Devil pool"..
            "#Each successful pollution permanently grants {{Damage}} +1 Damage",
        },
    },
    [133] = {
        Name = "钝化骰子",
        id = Items.DI_III,
        type = "active",
        xmlId = 144,
        Hidden = "true",
        zh = {
            Name = "钝化骰子",
            Desc = "重置你的理智",
            Description = "{{Collectible105}} 重置所在房间的底座道具"..
            "#{{Luck}} 每重置一个道具+1愚钝值"..
            "#{{Dullize}} 钝化：额外重置空底座",
            BookOfBelial = "小概率重置出恶魔房道具",
            BookOfVirtues = "",
        },
        en = {
            Name = "D_IIII",
            Desc = "Roll your Sanity",
        },
    },
    [134] = {
        Name = "钝化的心",
        id = Items.D_Heart,
        type = "passive",
        xmlId = 145,
        Hidden = "true",
        zh = {
            Name = "钝化的心",
            Desc = "思维随肉体远去",
            Description = "{{Heart}} 满血"..
            "#{{Luck}} 每格红心提供+1临时愚钝值 "..
            "#满红心时触碰红心，消耗1点{{Dullize}}愚钝值将其转化为{{SoulHeart}}魂心",
        },
        en = {
            Name = "D Heart",
            Desc = "Sanity fades away with the body",
        },
    },
    [135] = {
        Name = "钝化钥匙",
        id = Items.D_Key,
        type = "passive",
        xmlId = 146,
        Hidden = "true",
        zh = {
            Name = "钝化钥匙",
            Desc = "开启理智之门",
            Description = "{{Key}} +5钥匙"..
            "#依照愚钝值，清理房间奖励有概率替换为{{Coin}}硬币，{{Key}}钥匙，{{Bomb}}炸弹，{{Trinket}}饰品四选一",
        },
        en = {
            Name = "D Key",
            Desc = "Open the gate to Sanity",
        },
    },
    [136] = {
        Name = "钝化炸弹",
        id = Items.D_Bomb,
        type = "passive",
        xmlId = 147,
        Hidden = "true",
        zh = {
            Name = "钝化炸弹",
            Desc = "智能爆破",
            Description = "{{Bomb}} +5炸弹"..
            "#炸弹伤害敌人时获得临时攻击与临时炸弹"..
            "#{{Luck}} 被炸弹炸伤时+1愚钝值",
        },
        en = {
            Name = "D Bomb",
            Desc = "Sanity blasting",
        },
    },
    [137] = {
        Name = "钝化刀片",
        id = Items.D_RazorBlade,
        type = "passive",
        xmlId = 148,
        Hidden = "true",
        zh = {
            Name = "钝化刀片",
            Desc = "沾满理智之血",
            Description = "使用后："..
            "#受到1点红心伤害"..
            "#攻击大幅临时提升"..
            "#幸运暂时下降",
        },
        en = {
            Name = "D RazorBlade",
            Desc = "Covered with the blood of Sanity",
        },
    },
    [138] = {
        Name = "钝化十字架",
        id = Items.D_Cross,
        type = "passive",
        xmlId = 149,
        Hidden = "true",
        zh = {
            Name = "钝化十字架",
            Desc = "永恒哲思？",
            Description = "{{Luck}} 受伤后-0.2幸运"..
            "#{{SoulHeart}} 每受伤5次，生成1颗魂心",
        },
        en = {
            Name = "D Cross",
            Desc = "Eternal Sanity?",
        },
    },
    [139] = {
        Name = "钝化鲜血",
        id = Items.D_Lusty,
        type = "passive",
        xmlId = 150,
        Hidden = "true",
        zh = {
            Name = "钝化鲜血",
            Desc = "真理蕴含其中",
            Description = "{{EmptyHeart}} +2心之容器"..
            "#{{Luck}} -2幸运"..
            "#{{EternalHeart}} 下层后+1白心并-1{{Luck}}幸运",
        },
        en = {
            Name = "D Lusty",
            Desc = "Sanity is contained within it",
        },
    },
    [140] = {
        Name = "钝化神火",
        id = Items.D_Flame,
        type = "passive",
        xmlId = 151,
        Hidden = "true",
        zh = {
            Name = "钝化神火",
            Desc = "以理智为引",
            Description = "",
        },
        en = {
            Name = "D Flame",
            Desc = "Guided by Sanity",
        },
    },
    [141] = {
        Name = "钝化绷带",
        id = Items.D_Rag,
        type = "passive",
        xmlId = 152,
        Hidden = "true",
        zh = {
            Name = "钝化绷带",
            Desc = "智者死而复生",
            Description = "{{Luck}} 死后-10幸运并以半颗魂心复活"..
            "#有-{{Luck}}幸运*5%的概率失败",
        },
        en = {
            Name = "D Rag",
            Desc = "Come back to Sanity after death",
        },
    },
    [142] = {
        Name = "钝性",
        id = Items.D_Trinity,
        type = "passive",
        xmlId = 153,
        Hidden = "true",
        zh = {
            Name = "钝性",
            Desc = "失智之泪滴",
            Description = "{{Luck}} -2倍幸运"..
            "#子弹发射小子弹并试图躲避敌人",
        },
        en = {
            Name = "D Trinity",
            Desc = "Sanity Tears",
        },
    },
    [143] = {
        Name = "钝化的灵魂",
        id = Items.D_Soul,
        type = "active",
        xmlId = 154,
        Hidden = "true",
        zh = {
            Name = "钝化的灵魂",
            Desc = "理智沉沦",
            Description = "!!! 一次性"..
            "#{{Collectible}} 生成3个随机钝化道具",
        },
        en = {
            Name = "D Soul",
            Desc = "Sanity sinks",
        },
    },
    [144] = {
        Name = "钝化祭坛",
        id = Items.D_Sacrificalaltar,
        type = "passive",
        xmlId = 155,
        Hidden = "true",
        zh = {
            Name = "钝化祭坛",
            Desc = "献上心智",
            Description = "{{Luck}} -5幸运"..
            "#生成一个随机宝宝",
        },
        en = {
            Name = "D Sacrificalaltar",
            Desc = "Dedicate your Sanity",
        },
    },
    [145] = {
        Name = "钝化钱币",
        id = Items.D_Coin,
        type = "passive",
        xmlId = 156,
        Hidden = "true",
        zh = {
            Name = "钝化钱币",
            Desc = "+25 灵能",
            Description = "{{Luck}} -25幸运"..
            "#{{Coin}} +33硬币",
        },
        en = {
            Name = "D Coin",
            Desc = "+25 Sanity",
        },
    },
    [146] = {
        Name = "钝化指骨",
        id = Items.D_Pointyrib,
        type = "passive",
        xmlId = 157,
        Hidden = "true",
        zh = {
            Name = "钝化指骨",
            Desc = "指向心灵",
            Description = "生成一枚骨刺"..
            "#造成10次伤害后骨刺破碎"..
            "#一段时间后消耗1点幸运重新生成",
        },
        en = {
            Name = "D Pointyrib",
            Desc = "Pointing to the Sanity",
        },
    },
    [147] = {
        Name = "钝化之书",
        id = Items.Book_of_Dull,
        type = "passive",
        xmlId = 158,
        Hidden = "true",
        zh = {
            Name = "钝化之书",
            Desc = "你必得智慧，敬畏耶和华，远离恶事",
            Description = "",
        },
        en = {
            Name = "Book of Dull",
            Desc = "You will gain wisdom, fear the Lord, and stay away from evil",
        },
    },
    [148] = {
        Name = "钝化契约",
        id = Items.D_Pack,
        type = "passive",
        xmlId = 159,
        Hidden = "true",
        zh = {
            Name = "钝化契约",
            Desc = "随时违背它",
            Description = "{{SoulHeart}} +3魂心"..
            "#",
        },
        en = {
            Name = "D Pack",
            Desc = "Violating it at any time",
        },
    },
    [149] = {
        Name = "保留意见",
        id = Items.Reserved_Judgment,
        type = "passive",
        xmlId = 160,
        zh = {
            Name = "保留意见",
            Desc = "这还不算数",
            Description = "保留一件商品的当前报价至下一层"..
            "#靠近商品并按"..eidButton(ButtonAction and ButtonAction.ACTION_DROP).."保留"..
            "#同时只能保留1件；新的保留会替换旧的"..
            "#作为商品出现时，无需持有本道具也可保留它",
            AbyssSynic = "白色蝗虫",
        },
        en = {
            Name = "Reserved Judgment",
            Desc = "This isn't final",
            Description = "Reserve a priced item's current offer to the next floor"..
            "#Near an item, press "..eidButton(ButtonAction and ButtonAction.ACTION_DROP).." to reserve it"..
            "#Only 1 offer can be reserved; a new one replaces the old"..
            "#Reserved Judgment can reserve itself while being sold, even if not held",
            AbyssSynic = "White locust",
        },
    },
    [150] = {
        Name = "通灵盘",
        id = Items.Death_Sentence,
        type = "active",
        xmlId = 161,
        zh = {
            Name = "通灵盘",
            Desc = "判决即是终局",
            Description = "满充能时自动通灵1个随机字母"..
            "#使用打开预测面板"..
            "#用字母拼出道具名称，即可获得对应道具"..
            "#「=」可代替名称中的符号"..
            "#{{Warning}} 集齐“FINAL”时，立即唤醒你的死亡终局",
            BookOfBelial = "始终额外拥有一个匹配恶魔房道具池道具时充当通配符的6",
            BookOfVirtues = "显示通灵字母的魂火，熄灭时再获得该字母",
        },
        en = {
            Name = "Death Sentence",
            Desc = "The sentence is final",
            Description = "Fully charged: automatically summon 1 random letter"..
            "#Use to open the prediction panel"..
            "#Spell an item name with letters to gain it"..
            "#「=」 can stand in for symbols in the name"..
            "#{{Warning}} Spelling “FINAL” immediately wakes your death end",
            BookOfBelial = "Always have an extra 6; for Devil Room pool items, this 6 can replace any character",
            BookOfVirtues = "A wisp showing the letter; if you still hold this item when it dies, gain that letter again",
        },
    },
    [151] = {
        Name = "重制版！",
        id = Items.Remaster,
        type = "active",
        xmlId = 162,
        zh = {
            Name = "重制版！",
			Desc = "正在按下闪烁的红色按钮",
            Description = "选择一个楼层，打开时空隧道并前往"..
            "#记录这次穿越，跨越之后的游戏保留"..
            "#未来有角色进入目标楼层时，强制将其送回你的出发楼层",
            BookOfVirtues = "时空隧道会将魂火一并留给未来的使用者",
            BookOfBelial = "回程后，本层继承过去角色更高的战斗属性",
        },
        en = {
            Name = "Remaster!",
			Desc = "Pressing on the bloody blinking button",
            Description = "Choose a floor, open a time rift, and travel there"..
            "#This crossing is saved across future games"..
            "#When a character later enters the target floor, they are forced back to your origin floor",
            BookOfVirtues = "The time rift leaves your wisps for the future traveler",
            BookOfBelial = "After return, this floor inherits the stronger combat stats from the past traveler",
        },
    },
    [152] = {
        Name = "红地图",
        id = Items.Bloody_Map,
        type = "passive",
        xmlId = 163,
        zh = {
            Name = "红地图",
            Desc = "血绘而成",
            Description = "{{UltraSecretRoom}} 进入新层时，揭示红隐藏房间"..
            "#{{UltraSecretRoom}} 红隐藏房间中有概率出现血红使者",
            SeijaBuff = "进入新层时，额外生成1个通往红隐藏的传送漩涡",
        },
        en = {
            Name = "Bloody Map",
            Desc = "Drawn in blood",
            Description = "{{UltraSecretRoom}} Reveals Ultra Secret Rooms on each new floor"..
            "#{{UltraSecretRoom}} Chance to spawn a Bloody Messenger in Ultra Secret Rooms",
            SeijaBuff = "On each new floor, also spawn 1 Ultra Secret portal",
        },
    },
    [153] = {
        Name = "黄金抽奖机",
        id = Items.Golden_Slot,
        type = "active",
        xmlId = 164,
        zh = {
            Name = "黄金抽奖机",
            Desc = "投币赢大奖！",
            Description = "{{Coin}} 每次使用消耗1枚金币进行抽奖"..
            "#可能获得各种黄金奖励"..
            "#连续落空会逐渐提高中奖机会"..
            "#极小概率获得超大金箱或金奖杯",
            BookOfVirtues = "抽奖落空时生成黄金魂火"..
            "#黄金魂火的攻击概率使敌人点金",
            BookOfBelial = "{{Coin}} 每次抽奖改为消耗2枚金币"..
            "#中奖时抽取两次奖励并保留更高价值的一项",
        },
        en = {
            Name = "Golden Slot",
            Desc = "Insert coin to win!",
            Description = "{{Coin}} Costs 1 coin per use"..
            "#May grant various golden rewards"..
            "#Consecutive misses gradually improve win chance"..
            "#Tiny chance for a mega golden chest or trophy",
            BookOfVirtues = "Spawns a golden wisp on a miss"..
            "#Golden wisp attacks have a chance to Midas Freeze enemies",
            BookOfBelial = "{{Coin}} Each gamble costs 2 coins"..
            "#On a win, roll twice and keep the higher-value reward",
        },
    },
    [154] = {
        Name = "拖延症",
        id = Items.Procrastination,
        type = "passive",
        xmlId = 165,
        zh = {
            Name = "拖延症",
            Desc = "马上就做……",
            Description = "{{Timer}} 每30秒永久获得{{Damage}} +0.1攻击；每层最多+1"..
            "#{{BossRoom}} 击杀Boss后本层停止增长；Boss存活时房门保持开启",
        },
        en = {
            Name = "Procrastination",
            Desc = "I'll do it soon...",
            Description = "{{Timer}} Permanently gain {{Damage}} +0.1 every 30 seconds, up to +1 per floor"..
            "#{{BossRoom}} Killing a boss stops growth for this floor; doors stay open while a boss is alive",
        },
    },
    [155] = {
        Name = "神圣心之防护罩－心灵之力",
        id = Items.Sacred_Mind_Shield,
        type = "passive",
        xmlId = 166,
        zh = {
            Name = "神圣心之防护罩－心灵之力",
            Desc = "双心合一",
            Description = "获得1个{{ColorRed}}防护之心{{CR}}"..
            "#阻挡首个惩罚性伤害并释放心灵冲击波，然后转化为1个{{Heart}}心之容器"..
            "#冲击波每击杀1个敌人：获得{{Damage}} x1.05、{{Shotspeed}} -0.02，每房间最多5次"..
            "#房间内敌人不少于5个时：冲击波无视护甲，并波及本层其他房间",
        },
        en = {
            Name = "Sacred Mind Shield",
            Desc = "Two hearts as one",
            Description = "Gain 1 {{ColorRed}}protective heart{{CR}}"..
            "#Blocks the first punitive hit and releases a mind shockwave, then becomes 1 {{Heart}} heart container"..
            "#Each enemy killed by the wave grants {{Damage}} x1.05 and {{Shotspeed}} -0.02, up to 5 times per room"..
            "#With at least 5 enemies in the room, the wave ignores armor and spreads to other rooms this floor",
        },
    },
    [156] = {
        Name = "钻石",
        id = Items.Qing_Faceted_Market_Diamond,
        type = "passive",
        xmlId = 167,
        zh = {
            Name = "钻石",
            Desc = "永恒是可以议价的",
            Description = "此道具基础售价为5{{Coin}}"..
            "#{{Coin}} 作为商品遇见却未购买时，永久减半售价"..
            "#{{Shop}} 商店有50%概率出现钻石收购商，可以将钻石以任意价格出售"..
            "#随后钻石售价永久变为成交价",
        },
        en = {
            Name = "Diamond",
            Desc = "Eternity is negotiable",
            Description = "Base shop price is 5{{Coin}}"..
            "#{{Coin}} Leaving it unsold as a shop item permanently halves its price"..
            "#{{Shop}} Shops have a 50% chance to spawn a Diamond Merchant who will buy it at any price"..
            "#Its shop price then permanently becomes the sale price",
        },
    },
    [157] = {
        Name = "杯糕猫",
        id = Items.Cup_Cat,
        type = "passive",
        xmlId = 168,
        zh = {
            Name = "杯糕猫",
            Desc = "猫猫不会单独出现",
            Description = "{{Heart}} +1心之容器"..
            "#拥有其他{{Guppy}}猫套道具时，额外获得1{{SoulHeart}}并生成1个随机卡牌或符文"..
            "#每个杯糕猫只触发一次",
        },
        en = {
            Name = "Cup Cat",
            Desc = "Cats don't come alone",
            Description = "{{Heart}} +1 Heart container"..
            "#If you own any other {{Guppy}} item: gain 1{{SoulHeart}} and spawn 1 random card or rune"..
            "#Triggers once per Cup Cat",
        },
    },
    [158] = {
        Name = "无生源论",
        id = Items.Abiogenesis,
        type = "active",
        xmlId = 169,
        zh = {
            Name = "无生源论",
            Desc = "你看，它自己活了",
            Description = "{{Battery}} 每次仅消耗1格充能，但额外消耗 {{Coin}} {{Key}} {{Bomb}} 各1个"..
            "#随后观测剩余充能、硬币、钥匙与炸弹"..
            "#若任一剩余：实验失败，从剩余最多的资源中掉落1个对应掉落物"..
            "#{{Warning}} 金钥匙与金炸弹仍视为持有"..
            "#若四者同时归零：证明无生源论，将其{{ColorRainbow}}活化{{CR}}为无生源论宝宝",
            BookOfVirtues = "按剩余最多的资源生成对应魂火",
            BookOfBelial = "每次失败将一种非0资源排除出实验",
        },
        en = {
            Name = "Abiogenesis",
            Desc = "Look, it lives on its own",
            Description = "{{Battery}} Costs 1 charge per use, but also spends 1 {{Coin}} {{Key}} {{Bomb}} each"..
            "#Then observe remaining charge, coins, keys, and bombs"..
            "#If any remain: the experiment fails and spawns 1 pickup of the most remaining resource"..
            "#{{Warning}} Golden Key and Golden Bomb still count as holding"..
            "#If all four are 0: prove Abiogenesis, {{ColorRainbow}}animate{{CR}} it into an Abiogenesis familiar",
            BookOfVirtues = "Spawns a matching resource wisp",
            BookOfBelial = "Each failure excludes one non-zero resource from the experiment",
        },
    },
    [159] = {
        Name = "声音",
        id = Items.The_Voice,
        type = "passive",
        xmlId = 170,
        zh = {
            Name = "声音",
            Desc = "现在，只剩我们两个了",
            Description = "它已经不再需要那本书"..
            "#低语响起时，主动栏会留下声音的虚影"..
            "#{{Collectible}} 使用虚影即可回应低语"..
            "#确认交易后立即支付要求并获得许诺",
            BookOfBelial = "低语面板中额外出现“加倍接受”"..
            "#支付更大的代价，并获得更高的许诺",
            BookOfVirtues = "回应低语时生成假象魂火"..
            "#魂火存在时，低语提出的要求降低一级，许诺不变",
            SeijaBuff = "拒绝低语时获得较小的替代报酬",
        },
        en = {
            Name = "The Voice",
            Desc = "Now it's just the two of us",
            Description = "It no longer needs the book"..
            "#When a whisper starts, a phantom remains in the active slot"..
            "#{{Collectible}} Use the phantom to answer"..
            "#Confirming pays the demand and grants the promise immediately",
            BookOfBelial = "The whisper panel gains Double Accept"..
            "#Pay a greater cost for a greater promise",
            BookOfVirtues = "Answering a whisper spawns an illusion wisp"..
            "#While it lasts, the whisper's demand drops by one tier; the promise stays the same",
            SeijaBuff = "Refusing a whisper grants a small substitute reward",
        },
    },
    [160] = {
        Name = "再世纪",
        id = Items.Regenesis,
        type = "passive",
        xmlId = 171,
        zh = {
            Name = "再世纪",
            Desc = "一个也不失落",
            Description = "生成一个记住近期失物的宝宝"..
            "#每项失物需要记录1-4个战斗房，完成后由宝宝吐回",
        },
        en = {
            Name = "Regenesis",
            Desc = "Not one will be lost",
            Description = "Spawns a familiar that remembers things you recently lost"..
            "#Each loss takes 1-4 cleared combat rooms to recover, then the familiar spits it back out",
        },
    },
    [161] = {
        Name = "余烬",
        id = Items.Ember,
        type = "passive",
        xmlId = 172,
        zh = {
            Name = "余烬",
            Desc = "最后留下的东西",
            Description = "复制最近一次永久失去的其他被动道具"..
            "#再次失去道具时，改为复制新的道具",
        },
        en = {
            Name = "Ember",
            Desc = "What remains",
            Description = "Copies the last passive item you permanently lost"..
            "#Losing another item changes the copied item",
        },
    },
    [162] = {
        Name = "似有所选",
        id = Items.Perhaps_Chosen,
        type = "passive",
        xmlId = 173,
        zh = {
            Name = "似有所选",
            Desc = "请再看看罢",
            Description = "持有时没有效果"..
            "#没有选择它时，会作为额外选项加入之后的道具选择"..
            "#重置不会将其从选择中移除",
            SeijaBuff = "再次加入道具选择时，会在自己的底座上额外与一个当前道具池的随机道具轮换出现",
        },
        en = {
            Name = "Perhaps Chosen",
            Desc = "Please, look again.",
            Description = "Has no effect while held"..
            "#If not chosen, it returns as an extra option in a later item choice"..
            "#Rerolls do not remove it from that choice",
            SeijaBuff = "When it rejoins an item choice, its pedestal also cycles with a random item from the current pool",
        },
    },
    [163] = {
        Name = "零存在感",
        id = Items.Zero_Presence,
        type = "passive",
        xmlId = 174,
        zh = {
            Name = "零存在感",
            Desc = "你忘记了它",
            Description = "#概率发射零存在感眼泪"..
            "#零存在感眼泪会穿透并追踪敌人"..
            "#获得新道具时，它可能回到该道具的底座",
        },
        en = {
            Name = "Zero Presence",
            Desc = "You forgot it",
            Description = "#Chance to fire Zero Presence Tears"..
            "#Zero Presence Tears pierce and home on enemies"..
            "#When gaining a new item, it may return to that item's pedestal",
        },
    },
}

item.Trinkets = {
    [1] = {
        Name = "平罪符",
        id = Trinkets.Pacification_Mark,
        type = "trinket",
        xmlId = 1,
        zh = {
            Name = "平罪符",
            Desc = "公平意味着有利可图",
            Description = "{{Shop}} 同一房间内的商品价格变为平均价格并向上取整",
        },
        en = {
            Name = "Pacification Mark",
            Desc = "Fair means profitable",
            Description = "{{Shop}} Priced goods in the same room become the average price, rounded up",
        },
    },
    [2] = {
        Name = "黑暗脆块",
        id = Trinkets.Dark_Particle,
        type = "trinket",
        xmlId = 2,
        zh = {
            Name = "黑暗脆块",
            Desc = "易燃又美味？",
            Description = "{{BlackHeart}} 获得时+2黑心"..
            "#{{BrokenHeart}} 失去时+1碎心",
            goldenTrinket = {t={1,1,},},
        },
        en = {
            Name = "Dark Particle",
            Desc = "Flammable and delicious",
            Description = "{{BlackHeart}} +2 Black Hearts on pickup"..
            "#{{BrokenHeart}} +1 Broken Heart when lost",
            goldenTrinket = {t={1,1,},},
        },
    },
    [3] = {
        Name = "透特卡残片",
        id = Trinkets.Torn_Emperor,
        type = "trinket",
        xmlId = 3,
        zh = {
            Name = "透特卡残片",
            Desc = "反对奥秘学！",
            Description = "首次进入房间时约25%概率随机开启1扇额外的门",
            goldenTrinket = {t = {1,},},
        },
        en = {
            Name = "Torn Emperor",
            Desc = "Oppose esoteric!",
            Description = "About 25% chance to open 1 extra door when first entering a room",
            goldenTrinket = {t = {1,},},
        },
    },
    [4] = {
        Name = "恶魔的把戏",
        id = Trinkets.Devil_s_Joke,
        type = "trinket",
        xmlId = 4,
        zh = {
            Name = "恶魔的把戏",
            Desc = "愿你怒不可遏",
            Description = "{{Collectible105}} 进入恶魔房时获得一个临时的六面骰子"..
            "#{{DevilRoom}} 随机改变进入恶魔房的方向",
        },
        en = {
            Name = "Devil's Joke",
            Desc = "What an ugly appearance!",
            Description = "{{Collectible105}} Obtain a temporary D6 when entering the devil room"..
            "#{{DevilRoom}} Randomly change the direction of entering the devil room",
        },
    },
    [5] = {
        Name = "塔罗牌残片？",
        id = Trinkets.Torn_Moon_,
        type = "trinket",
        xmlId = 5,
        zh = {
            Name = "塔罗牌残片？",
            Desc = "双月？",
            Description = "{{UltraSecretRoom}} 持有时+1究极隐藏房",
            goldenTrinket = {t={1,},},
        },
        en = {
            Name = "Torn Moon？",
            Desc = "Double moon?",
            Description = "{{UltraSecretRoom}} +1 extra UltraSecretRoom Room per floor while held",
            goldenTrinket = {t={1,},},
        },
    },
    [6] = {
        Name = "穿刺符号",
        id = Trinkets.Puncture_Symbol,
        type = "trinket",
        xmlId = 6,
        zh = {
            Name = "穿刺符号",
            Desc = "放血",
            Description = "!!! 每次拾取受到2点伤害"..
            "#{{ArrowUp}} 持有时获得穿透眼泪与幽灵眼泪效果",
            goldenTrinket = {t={2,},},
        },
        en = {
            Name = "Puncture Symbol",
            Desc = "Haemospasia",
            Description = "!!! Take 2 damage on pickup"..
            "#{{ArrowUp}} Grants spectral and piercing tears while held",
            goldenTrinket = {t={2,},},
        },
    },
    [7] = {
        Name = "囤积符号",
        id = Trinkets.Hoarding_Symbol,
        type = "trinket",
        xmlId = 7,
        zh = {
            Name = "囤积符号",
            Desc = "重建",
            Description = "!!! 首次拾取时失去全部{{Coin}}硬币、{{Key}}钥匙与{{Bomb}}炸弹"..
            "#{{Damage}} 永久+1攻击",
            goldenTrinket = {t={1,},},
        },
        en = {
            Name = "Hoarding Symbol",
            Desc = "Reconstruction",
            Description = "!!! On pickup, lose all {{Coin}} coins, {{Key}} keys, and {{Bomb}} bombs"..
            "#{{Damage}} Permanent +1 Damage",
            goldenTrinket = {t={1,},},
        },
    },
    [8] = {
        Name = "迁跃符号",
        id = Trinkets.Transition_Symbol,
        type = "trinket",
        xmlId = 8,
        zh = {
            Name = "迁跃符号",
            Desc = "远离",
            Description = "{{ErrorRoom}} 穿门进入未探索房间时，2%概率改为进入错误房",
            goldenTrinket = {t={2,},},
        },
        en = {
            Name = "Transition Symbol",
            Desc = "Away",
            Description = "{{ErrorRoom}} 2% chance to enter an Error Room when walking into an unvisited room",
            goldenTrinket = {t={2,},},
        },
    },
    [9] = {
        Name = "粘合符号",
        id = Trinkets.Adhesive_Symbol,
        type = "trinket",
        xmlId = 9,
        zh = {
            Name = "粘合符号",
            Desc = "寄生",
            Description = "{{EmptyHeart}} 失去{{BrokenHeart}}碎心时+1心之容器",
            goldenTrinket = {t={1,},},
        },
        en = {
            Name = "Adhesive Symbol",
            Desc = "Parasitism",
            Description = "{{EmptyHeart}}  +1 Heart container when losing {{BrokenHeart}} broken hearts",
            goldenTrinket = {t={1,},},
        },
    },
    [10] = {
        Name = "下坠符号",
        id = Trinkets.Straining_Symbol,
        type = "trinket",
        xmlId = 10,
        zh = {
            Name = "下坠符号",
            Desc = "抑郁",
            Description = "此饰品落到地面时击落房间内所有弹幕",
        },
        en = {
            Name = "Straining Symbol",
            Desc = "Depression",
            Description = "Clears room projectiles when this trinket appears on the ground",
        },
    },
    [11] = {
        Name = "配给符号",
        id = Trinkets.Allocation_Symbol,
        type = "trinket",
        xmlId = 11,
        zh = {
            Name = "配给符号",
            Desc = "谋划",
            Description = "{{ArrowUp}} 全属性以0.1为最小间隔进行上取整",
            goldenTrinket = {t={0.1,},},
        },
        en = {
            Name = "Allocation Symbol",
            Desc = "Scheme",
            Description = "{{ArrowUp}} Round up all attributes with a minimum interval of 0.1",
            goldenTrinket = {t={0.1,},},
        },
    },
    [12] = {
        Name = "暂停？",
        id = Trinkets.Pause_,
        type = "trinket",
        xmlId = 12,
        zh = {
            Name = "暂停？",
            Desc = "即时游戏开始了！",
            Description = "{{ArrowUp}} 全属性上升"..
            "#{{Warning}} 打开暂停菜单后失去此饰品"..
            "#睡床造成的特殊暂停不会触发",
        },
        en = {
            Name = "Pause?",
            Desc = "A Real time game!",
            Description = "{{ArrowUp}} All stats up"..
            "#{{Warning}} Lost after opening the pause menu"..
            "#Bed pause does not count",
        },
    },
    [13] = {
        Name = "平等协议",
        id = Trinkets.Equality_Agreement,
        type = "trinket",
        xmlId = 13,
        zh = {
            Name = "平等协议",
            Desc = "看似公平",
            Description = "{{Shop}} 在商店中{{Coin}}硬币为0时，收费的非道具商品变为随机{{Collectible}}道具",
        },
        en = {
            Name = "Equality Agreement",
            Desc = "Seemingly equal",
            Description = "{{Shop}} While {{Coin}} coins are 0 in a shop, priced non-item goods become random {{Collectible}} items",
        },
    },
    [14] = {
        Name = "期望协定",
        id = Trinkets.Consistent_Expectations,
        type = "trinket",
        xmlId = 14,
        zh = {
            Name = "期望协定",
            Desc = "概率上一致",
            Description = "{{Shop}} 原价高于1{{Coin}}的商品只需1{{Coin}}尝试购买"..
            "#每次有1/原价的概率成功"..
            "#失败仍支付1{{Coin}}，商品留在原地",
        },
        en = {
            Name = "Consistent Expectations",
            Desc = "Equal in Expection",
            Description = "{{Shop}} Goods priced above 1 {{Coin}} cost 1 {{Coin}} per attempt"..
            "#Success chance is 1 / original price"..
            "#Failure still spends 1 {{Coin}}; the goods stay",
        },
    },
    [15] = {
        Name = "捆绑销售",
        id = Trinkets.Bundled_Sale,
        type = "trinket",
        xmlId = 15,
        zh = {
            Name = "捆绑销售",
            Desc = "多买多得",
            Description = "{{Shop}} 商品价格提升100%"..
            "#{{ArrowUp}} 完成购买后，随机1件剩余收费商品变为免费",
        },
        en = {
            Name = "Bundled Sale",
            Desc = "Buy more, get more",
            Description = "{{Shop}} Product prices increase by 100%"..
            "#{{ArrowUp}} After a purchase, 1 random remaining priced good becomes free",
        },
    },
    [16] = {
        Name = "破碎的胸针",
        id = Trinkets.Broken_Brooch,
        type = "trinket",
        xmlId = 16,
        zh = {
            Name = "破碎的胸针",
            Desc = "时间足以改变一切",
            Description = "清理房间后小概率强化攻击、射速、移速或射程中的较弱项",
        },
        en = {
            Name = "Broken Brooch",
            Desc = "Time is enough to change everything",
            Description = "After clearing a room, small chance to buff the weaker of Damage / Tears / Speed / Range",
        },
    },
}

item.Cards = {
    [1] = {
        Name = "琉璃的骰子碎片",
        id = Cards.Glaze_dice_shard,
        type = "card",
        xmlId = 2359,
        zh = {
            Name = "琉璃的骰子碎片",
            Desc = "我的模仿者在何方？何方？何方？",
            Description = "将房间内的道具随机变为同色道具"..
            "#常见基础掉落变为对应的琉璃版本 {{Coin}}{{Heart}}{{Key}}{{Bomb}}{{GrabBag}}{{Battery}}{{Poop}}"..
            "#敌人琉璃化",
            Frame = 0,
        },
        en = {
            Name = "Glaze Dice Shard",
            Desc = "Looking for Assimilation",
            Description = "Rerolls collectibles in the room into random items of matching colors"..
            "#Common pickups are converted into their glazed counterparts"..
            "#Enemies become glazed",
            Frame = 0,
        },
    },
    [2] = {
        Name = "小青的灵魂石",
        id = Cards.Qing_s_Soul,
        type = "card",
        xmlId = 2360,
        zh = {
            Name = "小青的灵魂石",
            Desc = "安全了，暂时的",
            Description = "连续向当前攻击方向发射多波飞刀",
            Frame = 1,
        },
        en = {
            Name = "Qing's Soul",
            Desc = "Safe, for now",
            Description = "Rapidly fires multiple waves of knives in the current firing direction",
            Frame = 1,
            Type = "Soul",
        },
    },
    [3] = {
        Name = "双行火车票",
        id = Cards.Round_trip_Rail_Ticket,
        type = "card",
        xmlId = 2375,
        zh = {
            Name = "双行火车票",
            Desc = "提供食宿！",
            Description = "!!! 举起后，按攻击方向召唤列车冲过房间"..
            "#{{Card}} 同时生成一张单程票，可再次召唤列车",
            Frame = 2,
        },
        en = {
            Name = "Round-Trip Rail Ticket",
            Desc = "Room and board included!",
            Description = "!!! Hold it up, then fire in a direction to send a train through the room"..
            "#{{Card}} Also spawns a One-Way Ticket that can summon another train",
            Frame = 2,
        },
    },
    [4] = {
        Name = "单程票",
        id = Cards.One_way_Rail_Ticket,
        type = "card",
        xmlId = 2376,
        zh = {
            Name = "单程票",
            Desc = "送我回家吧！",
            Description = "!!! 举起后，按攻击方向召唤列车冲过房间"..
            "#{{Warning}} 不会生成新的车票",
            Frame = 3,
        },
        en = {
            Name = "One-Way Rail Ticket",
            Desc = "Take me home!",
            Description = "!!! Hold it up, then fire in a direction to send a train through the room"..
            "#{{Warning}} Does not create another ticket",
            Frame = 3,
        },
    },
    [5] = {
        Name = "泰克罗的魂石",
        id = Cards.Tecro_s_Soul,
        type = "card",
        xmlId = 2428,
        zh = {
            Name = "泰克罗的魂石",
            Desc = "羡..",
            Description = "持有时受伤，或使用后，向八个方向刺出长枪"..
            "#{{Damage}} 长枪造成1.5倍攻击伤害",
            Frame = 54,
        },
        en = {
            Name = "Tecro's Soul",
            Desc = "Envy...",
            Description = "Taking damage while holding it, or using it, fires spears in eight directions"..
            "#{{Damage}} Spears deal 1.5× your damage",
            Frame = 54,
            Type = "Soul",
        },
    },
    [6] = {
        Name = "安娜的魂石",
        id = Cards.Anna_s_Soul,
        type = "card",
        xmlId = 2429,
        zh = {
            Name = "安娜的魂石",
            Desc = "欲..",
            Description = "地上的魂石会反复进入黑洞，瞄准敌人后从上方坠落爆炸"..
            "#使用后，在自身位置引发一次不会伤害玩家的爆炸",
            Frame = 55,
        },
        en = {
            Name = "Anna's Soul",
            Desc = "Desire...",
            Description = "While on the ground, repeatedly disappears into a black hole, targets an enemy, then crashes down from above in an explosion"..
            "#On use, creates an explosion at your position that cannot hurt players",
            Frame = 55,
            Type = "Soul",
        },
    },
    [7] = {
        Name = "泽伊斯的魂石",
        id = Cards.Zeis_s_Soul,
        type = "card",
        xmlId = 2430,
        zh = {
            Name = "泽伊斯的魂石",
            Desc = "知..",
            Description = "以房间中的道具为中心，显现出若干相邻的可能性"..
            "#{{Collectible}} 原道具与显现出的道具组成多选一"..
            "#空间不足时只能显现部分道具",
            Frame = 56,
        },
        en = {
            Name = "Zeis's Soul",
            Desc = "Knowledge...",
            Description = "Reveals several nearby possibilities around each eligible item in the room"..
            "#{{Collectible}} The original item and its revealed alternatives form a single choice"..
            "#Limited space may reduce the number revealed",
            Frame = 56,
            Type = "Soul",
        },
    },
    [8] = {
        Name = "VIII - 调节",
        id = Cards.Adjustment,
        zh = {
            Name = "VIII - 调节",
            Desc = "无知之幕正在落下",
            Description = "平衡你的硬币、钥匙与炸弹"..
            "#余数转化为{{Coin}}/{{Bomb}}/{{Key}}三选一",
            Frame = 14,
            tarotClothBuffs = "平衡后，硬币、钥匙与炸弹各+1",
        },
        en = {
            Name = "VIII - Adjustment",
            Desc = "Power of balance",
            Description = "Balance your coins, keys and bombs"..
            "#Convert the remainder into a {{Coin}}/{{Bomb}}/{{Key}} choice",
            Frame = 14,
            tarotClothBuffs = "After balancing, gain +1 coin, +1 key and +1 bomb",
        },
    },
    [9] = {
        Name = "VIII - 调节?",
        id = Cards.Adjustment_r,
        zh = {
            Name = "VIII - 调节?",
            Desc = "与其纷争，莫如没收",
            Description = "{{Coin}}{{Key}}{{Bomb}} 将全部硬币、钥匙和炸弹转化为本局永久属性"..
            "#持有越多，获得的强化越高，但收益逐渐递减",
            Frame = 36,
            tarotClothBuffs = "仍按全部资源获得强化，并返还约一半硬币、钥匙和炸弹",
        },
        en = {
            Name = "VIII - Adjustment?",
            Desc = "Better to confiscate than to quarrel",
            Description = "{{Coin}}{{Key}}{{Bomb}} Convert all coins, keys and bombs into permanent stats for the current run"..
            "#More resources grant a stronger boost, with diminishing returns",
            Frame = 36,
            tarotClothBuffs = "Gain the full conversion, then recover about half of your coins, keys and bombs",
        },
    },
    [10] = {
        Name = "XX - 永恒",
        id = Cards.Aeon,
        zh = {
            Name = "XX - 永恒",
            Desc = "引导永恒的哀悼",
            Description = "{{EternalHeart}} 持有时，受伤有小概率生成永恒之心"..
            "#{{Confessional}} 使用后生成一台忏悔室",
            Frame = 26,
            tarotClothBuffs = "生成两台忏悔室",
        },
        en = {
            Name = "XX - The Aeon",
            Desc = "Don't be sad.Don't worry.",
            Description = "{{EternalHeart}} While held, taking damage has a small chance to spawn an Eternal Heart"..
            "#{{Confessional}} On use, spawn a Confessional",
            Frame = 26,
            tarotClothBuffs = "Spawn 2 Confessionals",
        },
    },
    [11] = {
        Name = "XX - 永恒?",
        id = Cards.Aeon_r,
        zh = {
            Name = "XX - 永恒?",
            Desc = "瞬间即成永恒",
            Description = "记录接下来3秒内的动作与攻击"..
            "#本层进入房间时，过去的你会完整重演这段时间",
            Frame = 50,
            tarotClothBuffs = "记录时间延长至5秒",
        },
        en = {
            Name = "XX - The Aeon?",
            Desc = "An instant becomes eternity",
            Description = "Record your actions and attacks for the next 3 seconds"..
            "#For this floor, your past self replays them when entering rooms",
            Frame = 50,
            tarotClothBuffs = "Recording duration increases to 5 seconds",
        },
    },
    [12] = {
        Name = "XIV - 艺术",
        id = Cards.Art,
        zh = {
            Name = "XIV - 艺术",
            Desc = "超绝!豪快!闷绝!优雅!超级!究极超级!",
            Description = "{{Timer}} 30秒内，击杀敌人会掉落彩虹颜料"..
            "#每3份颜料合成为1个随机基础掉落",
            Frame = 20,
            tarotClothBuffs = "持续时间延长至45秒",
        },
        en = {
            Name = "XIV - Art",
            Desc = "Perfect Faintless Transcendent Supernatural Maniac Absolute",
            Description = "{{Timer}} For 30s, defeated enemies drop rainbow pigments"..
            "#Every 3 pigments combine into 1 random basic pickup",
            Frame = 20,
            tarotClothBuffs = "Duration increases to 45s",
        },
    },
    [13] = {
        Name = "XIV - 艺术?",
        id = Cards.Art_r,
        zh = {
            Name = "XIV - 艺术?",
            Desc = "艺术，就是爆炸",
            Description = "地上的此卡会周期性爆炸并弹向别处"..
            "#使用后，本房间内泪弹、敌方弹幕、敌人、掉落物等消失时发生爆炸"..
            "#{{Damage}} 爆炸造成2倍攻击伤害；距离玩家过近时不会触发",
            Frame = 44,
            tarotClothBuffs = "使用后的爆炸不会伤害玩家",
        },
        en = {
            Name = "XIV - Art?",
            Desc = "Art is explosion",
            Description = "While on the ground, this card periodically explodes and bounces away"..
            "#On use, tears, hostile projectiles, enemies, pickups, and more explode when they disappear in this room"..
            "#{{Damage}} These explosions deal 2× damage; entities too close to the player do not trigger them",
            Frame = 44,
            tarotClothBuffs = "Explosions caused by the used card cannot hurt the player",
        },
    },
    [14] = {
        Name = "VII - 巨炮",
        id = Cards.Chariot,
        zh = {
            Name = "VII - 巨炮",
            Desc = "大地因我的到来而鸣响",
            Description = "向攻击方向发射1枚巨型火箭"..
            "#爆炸造成300点伤害",
            Frame = 13,
            tarotClothBuffs = "额外向两侧各发射1枚巨型火箭",
        },
        en = {
            Name = "VII - Chariot",
            Desc = "The earth is tingling for my arrival",
            Description = "Fire 1 giant rocket in the attack direction"..
            "#Its explosion deals 300 damage",
            Frame = 13,
            tarotClothBuffs = "Fire 1 additional giant rocket to each side",
        },
    },
    [15] = {
        Name = "VII - 巨像?",
        id = Cards.Chariot_r,
        zh = {
            Name = "VII - 巨像?",
            Desc = "前路只待撞碎",
            Description = "举起卡牌并输入射击方向，将自己发射出去"..
            "#飞行期间无敌，对撞到的敌人造成巨额伤害并摧毁可破坏障碍"..
            "#撞墙时引发猛烈爆炸并停止",
            Frame = 35,
            tarotClothBuffs = "第一次撞墙后会反弹并继续飞行",
        },
        en = {
            Name = "VII - The Chariot?",
            Desc = "The path ahead waits only to be smashed",
            Description = "Hold up the card, then fire in a direction to launch yourself"..
            "#Invincible in flight; heavily damages enemies you ram and smashes destructible obstacles"..
            "#Crashing into a wall causes a powerful explosion and ends the flight",
            Frame = 35,
            tarotClothBuffs = "The first wall crash makes you bounce back and keep flying",
        },
    },
    [16] = {
        Name = "XIII - 尸首?",
        id = Cards.Corpse_r,
        zh = {
            Name = "XIII - 尸首?",
            Desc = "心怀异端",
            Description = "{{RottenHeart}} 向身后吐出红心，并将其转化为腐心"..
            "#吐出的腐心释放毒雾伤害敌人"..
            "#无法继续安全消耗红心后，仍有10%概率额外吐出腐心",
            Frame = 43,
            tarotClothBuffs = "概率提升至25%",
        },
        en = {
            Name = "XIII - The Corpse?",
            Desc = "Harbouring heresy",
            Description = "{{RottenHeart}} Spit red hearts behind you and turn them into rotten hearts"..
            "#Spat-out rotten hearts release damaging toxic fog"..
            "#When no more red hearts can be safely spent, still has a 10% chance to spit an extra rotten heart",
            Frame = 43,
            tarotClothBuffs = "Chance increases to 25%",
        },
    },
    [17] = {
        Name = "XIII - 死神?",
        id = Cards.Death_r,
        zh = {
            Name = "XIII - 死神?",
            Desc = "如此，我就能满足了",
            Description = "卸下全部主动道具、卡牌/药丸和饰品，其中至多6件形成物品阵列"..
            "#阵列中的主动与卡牌/药丸仍可使用，饰品持续生效"..
            "#选中地上资源时按{{ButtonRT}}收入阵列；选中阵列资源时长按{{ButtonRT}}放回地面"..
            "#重新持有任意主动、卡牌/药丸或饰品时，阵列结束并返还其中所有资源",
            tarotClothBuffs = "阵列上限提升至8件",
            Frame = 42,
        },
        en = {
            Name = "XIII - Death?",
            Desc = "Handless combo",
            Description = "Drop all actives, cards/pills, and trinkets; up to 6 become a Field array"..
            "#Field actives and cards/pills can still be used; trinkets remain active"..
            "#Press {{ButtonRT}} on a ground resource to add it; hold {{ButtonRT}} on a Field resource to return it"..
            "#Holding any active, card/pill, or trinket again ends the Field and returns everything in it",
            tarotClothBuffs = "Field capacity increases to 8",
            Frame = 42,
        },
    },
    [18] = {
        Name = "XV - 邪心",
        id = Cards.Devil,
        zh = {
            Name = "XV - 邪心",
            Desc = "灵魂算子：重生",
            Description = "{{DevilRoom}} 持有时，死亡后在恶魔房复活"..
            "#使用后立即死亡并触发此次复活",
            Frame = 21,
            tarotClothBuffs = "主动使用后返还此卡",
        },
        en = {
            Name = "XV - The Devil",
            Desc = "Soul = Rebirth",
            Description = "{{DevilRoom}} While held, revive in a Devil Room after death"..
            "#Using it kills you immediately and triggers this revival",
            Frame = 21,
            tarotClothBuffs = "Returns this card after using it",
        },
    },
    [19] = {
        Name = "XV - 邪心?",
        id = Cards.Devil_r,
        zh = {
            Name = "XV - 邪心?",
            Desc = "虚无解械",
            Description = "{{DevilRoom}} 召来撒旦进行一次恶魔交易，出现2–3件商品"..
            "#用爆炸攻击撒旦可改为与其战斗；击败后可免费取得尚未购买的商品",
            Frame = 45,
            tarotClothBuffs = "商品增加至4–5件",
        },
        en = {
            Name = "XV - The Devil?",
            Desc = "Zero = Infinity",
            Description = "{{DevilRoom}} Summon Satan for a Devil deal with 2–3 goods"..
            "#Bomb Satan to fight him instead; defeating him makes all unbought goods free",
            Frame = 45,
            tarotClothBuffs = "Goods increase to 4–5",
        },
    },
    [20] = {
        Name = "XIX - 日食",
        id = Cards.Eclipse,
        zh = {
            Name = "XIX - 日食",
            Desc = "永夜将至",
            Description = "生成持续15秒的旋涡"..
            "#吸入附近敌人，使其从高空坠回",
            Frame = 52,
            tarotClothBuffs = "旋涡持续30秒",
        },
        en = {
            Name = "XIX - Eclipse",
            Desc = "Everlasting night approaches",
            Description = "Creates a vortex for 15 seconds"..
            "#Swallows nearby enemies and drops them back from above",
            Frame = 52,
            tarotClothBuffs = "Vortex lasts 30 seconds",
        },
    },
    [21] = {
        Name = "XIX - 食日?",
        id = Cards.Eclipse_r,
        zh = {
            Name = "XIX - 食日?",
            Desc = "极昼重临",
            Description = "{{Timer}} 日蚀持续3分钟，太阳逐渐逼近"..
            "#期间不断召来落光攻击敌人，也会有落光袭击玩家"..
            "#时间越久，落光越频繁",
            Frame = 53,
            tarotClothBuffs = "攻击敌人的落光伤害由3倍提升至6倍",
        },
        en = {
            Name = "XIX - Eclipse?",
            Desc = "Polar Day Reaches Again",
            Description = "{{Timer}} An eclipse lasts 3 minutes as the sun approaches"..
            "#Falling light repeatedly strikes enemies, while other strikes target the player"..
            "#The strikes become more frequent over time",
            Frame = 53,
            tarotClothBuffs = "Enemy-targeting strikes increase from 3× to 6× damage",
        },
    },
    [22] = {
        Name = "IV - 帝王",
        id = Cards.Emperor,
        zh = {
            Name = "IV - 帝王",
            Desc = "命运的囚徒",
            Description = "沿当前房间墙面尽可能生成通往其他房间的特殊门"..
            "#原有普通门暂时关闭"..
            "#部分门可能通往特殊目的地",
            Frame = 10,
            tarotClothBuffs = "提高墙面生成门的成功率，因此通常会出现更多门",
        },
        en = {
            Name = "IV - The Emperor",
            Desc = "Never can we escape",
            Description = "Create as many special doors as possible along the current room's walls"..
            "#Normal doors are temporarily closed"..
            "#Some doors may lead to special destinations",
            Frame = 10,
            tarotClothBuffs = "Raises the per-wall spawn chance, so you usually get more doors",
        },
    },
    [23] = {
        Name = "IV - 帝王?",
        id = Cards.Emperor_r,
        zh = {
            Name = "IV - 帝王?",
            Desc = "二日齐天",
            Description = "召唤一个Boss并封锁房间"..
            "#击败后，该Boss会复活为友军并持续跟随玩家",
            Frame = 32,
            tarotClothBuffs = "不会召唤较弱的Boss",
        },
        en = {
            Name = "IV - The Emperor?",
            Desc = "When you raise the second sun",
            Description = "Summon a boss and seal the room"..
            "#After being defeated, it returns as a friendly ally and continues to follow you",
            Frame = 32,
            tarotClothBuffs = "Excludes weaker bosses from the summon pool",
        },
    },
    [24] = {
        Name = "III - 女帝",
        id = Cards.Empress,
        zh = {
            Name = "III - 女帝",
            Desc = "我最爱互相残杀的剧本了",
            Description = "{{Charm}} 一名敌人吸收其他普通敌人的生命，使它们降至10%生命并被魅惑"..
            "#这名敌人变为彩虹变异",
            Frame = 9,
            tarotClothBuffs = "被魅惑的敌人改为剩余20%生命",
        },
        en = {
            Name = "III - The Empress",
            Desc = "Let them fight for me",
            Description = "{{Charm}} One enemy absorbs the health of other regular enemies, reducing them to 10% HP and charming them"..
            "#That enemy becomes a Rainbow Champion",
            Frame = 9,
            tarotClothBuffs = "Charmed enemies retain 20% HP",
        },
    },
    [25] = {
        Name = "III - 女帝?",
        id = Cards.Empress_r,
        zh = {
            Name = "III - 女帝?",
            Desc = "命运的一切礼物，都在暗中标好了价格",
            Description = "重置本层所有道具"..
            "#本层的道具均需要购买且无法辨认"..
            "#售价为道具等级的五倍",
            Frame = 31,
            tarotClothBuffs = "售价降低至一倍",
        },
        en = {
            Name = "III - The Empress?",
            Desc = "Marked with prices in secret",
            Description = "Reroll all items in this floor "..
            "# Items on this floor need to be purchased and cannot be identified"..
            "# Its price is related to its quality and their original price",
            Frame = 31,
            tarotClothBuffs = "Lower its price greatly.",
        },
    },
    [26] = {
        Name = "XIII - 长眠",
        id = Cards.Faint,
        zh = {
            Name = "XIII - 长眠",
            Desc = "梦入异乡",
            Description = "{{IsaacsRoom}} 生成一张可以入睡的床"..
            "#睡醒后传送至本层随机房间"..
            "#损坏的床不会传送",
            Frame = 19,
            tarotClothBuffs = "睡下时额外触发一次{{Card51}}的效果",
        },
        en = {
            Name = "XIII - Faint",
            Desc = "Dream into a mirror",
            Description = "{{IsaacsRoom}} Spawn a bed you can sleep in"..
            "#After waking, teleport to a random room on the floor"..
            "#Broken beds do not teleport you",
            Frame = 19,
            tarotClothBuffs = "Sleeping also triggers {{Card51}} once",
        },
    },
    [27] = {
        Name = "XIII - 长眠?",
        id = Cards.Faint_r,
        zh = {
            Name = "XIII - 长眠?",
            Desc = "万籁将眠",
            Description = "停止攻击时，房间逐渐陷入沉睡"..
            "#沉睡越深，敌人、敌方弹幕与激光行动越慢"..
            "#重新攻击会逐渐唤醒房间",
            Frame = 41,
            tarotClothBuffs = "更快入睡，攻击造成的唤醒更慢",
        },
        en = {
            Name = "XIII - Faint?",
            Desc = "Cross between life and death",
            Description = "While not firing, the room gradually falls asleep"..
            "#Deeper sleep slows enemies, hostile projectiles, and hostile lasers"..
            "#Firing again slowly wakes the room",
            Frame = 41,
            tarotClothBuffs = "Falls asleep faster; attacks wake it more slowly",
        },
    },
    [28] = {
        Name = "0 - 旅者",
        id = Cards.Fool,
        zh = {
            Name = "0 - 旅者",
            Desc = "所遗者广",
            Description = "从当前道具池展示5个可生成魂火的道具虚影"..
            "#接触其中一个，将其牺牲并生成对应魂火"..
            "#被选择的道具会从道具池移除",
            Frame = 4,
            tarotClothBuffs = "候选虚影由5个增加至8个",
        },
        en = {
            Name = "0 - The Fool",
            Desc = "May you lose more",
            Description = "Show 5 phantom items from the current item pool that can generate item wisps"..
            "#Touch one to sacrifice it and generate its corresponding item wisp"..
            "#The selected item is removed from the item pool",
            Frame = 4,
            tarotClothBuffs = "Increases the number of phantom items from 5 to 8",
        },
    },
    [29] = {
        Name = "0 - 旅者?",
        id = Cards.Fool_r,
        zh = {
            Name = "0 - 旅者?",
            Desc = "所知者稀",
            Description = "从当前房间道具池预知1件道具"..
            "#下一件出现的道具会与其组成多选一",
            Frame = 28,
            tarotClothBuffs = "改为预知3件道具",
        },
        en = {
            Name = "0 - The Fool?",
            Desc = "May you know less",
            Description = "Foretell 1 item from the current room's item pool"..
            "#The next collectible to appear will become a choice with it",
            Frame = 28,
            tarotClothBuffs = "Foretell 3 items instead",
        },
    },
    [30] = {
        Name = "XII - 缚者",
        id = Cards.Hanged_Man,
        zh = {
            Name = "XII - 缚者",
            Desc = "倒错回环",
            Description = "本层后续出现的正位塔罗牌会变为对应的逆位牌",
            Frame = 18,
            tarotClothBuffs = "额外生成1张{{Card"..tostring(Cards.Hanged_Man).."}}",
        },
        en = {
            Name = "XII - The Hanged Man",
            Desc = "Looping and winding",
            Description = "Later upright Tarot cards on this floor become their reversed versions",
            Frame = 18,
            tarotClothBuffs = "Spawns an additional {{Card"..tostring(Cards.Hanged_Man).."}}",
        },
    },
    [31] = {
        Name = "XII - 缚者?",
        id = Cards.Hanged_Man_r,
        zh = {
            Name = "XII - 缚者?",
            Desc = "环回错倒",
            Description = "本层后续出现的逆位塔罗牌会变为对应的正位牌",
            Frame = 40,
            tarotClothBuffs = "额外生成1张{{Card"..tostring(Cards.Hanged_Man_r).."}}",
        },
        en = {
            Name = "XII - The Hanged Man?",
            Desc = "May you a better escape",
            Description = "Later reversed Tarot cards on this floor become their upright versions",
            Frame = 40,
            tarotClothBuffs = "Spawns an additional {{Card"..tostring(Cards.Hanged_Man_r).."}}",
        },
    },
    [32] = {
        Name = "IX - 隐者",
        id = Cards.Hermit,
        zh = {
            Name = "IX - 隐者",
            Desc = "你的过去萦绕在心",
            Description = "随机生成1个本局失去过的道具"..
            "#优先选择被动道具",
            Frame = 15,
            tarotClothBuffs = "改为从3个道具中选择1个",
        },
        en = {
            Name = "IX - The Hermit",
            Desc = "Bury your past deeply in mind",
            Description = "Spawn 1 random item you have lost this run"..
            "#Passive items are chosen first",
            Frame = 15,
            tarotClothBuffs = "Choose 1 of 3 lost items",
        },
    },
    [33] = {
        Name = "IX - 隐者?",
        id = Cards.Hermit_r,
        zh = {
            Name = "IX - 隐者?",
            Desc = "跨越千年的命运",
            Description = "随机暂时隐藏至多3件持有道具"..
            "#立即生成1件随机道具"..
            "#见到7次新道具后返还",
            Frame = 37,
            tarotClothBuffs = "随机奖励改为二选一",
        },
        en = {
            Name = "IX - The Hermit?",
            Desc = "Buried for thousand years",
            Description = "Temporarily hides up to 3 random held items"..
            "#Immediately spawns 1 random item"..
            "#Returns the hidden items after seeing 7 new items",
            Frame = 37,
            tarotClothBuffs = "The random reward becomes a choice of 2",
        },
    },
    [34] = {
        Name = "V - 教导",
        id = Cards.Hierophant,
        zh = {
            Name = "V - 教导",
            Desc = "愿我纯粹",
            Description = "{{ArrowUp}} 本房间内获得{{Collectible182}}和{{Collectible533}}效果",
            Frame = 11,
            tarotClothBuffs = "改为生成脆弱的{{Collectible182}}魂火、{{Collectible184}}魂火和{{Collectible533}}魂火各一个",
        },
        en = {
            Name = "V - The Hierophant",
            Desc = "I . I",
            Description = "Gain a temporary effect of {{Collectible182}} and {{Collectible533}}.",
            Frame = 11,
            tarotClothBuffs = "Generate delicate wisps of {{Collectible182}},{{Collectible184}} and {{Collectible533}}.",
        },
    },
    [35] = {
        Name = "V - 教导?",
        id = Cards.Hierophant_r,
        zh = {
            Name = "V - 教导?",
            Desc = "所信者亦可背弃",
            Description = "{{AngelRoom}} 献祭所有仍持有的、在天使房取得的道具"..
            "#{{DevilRoom}} 每献祭1件，生成1件恶魔房道具",
            Frame = 33,
            tarotClothBuffs = "被献祭的道具额外留下对应魂火",
        },
        en = {
            Name = "V - The Hierophant?",
            Desc = "detautafnI ... ni ... si ... em",
            Description = "{{AngelRoom}} Sacrifice all items you still hold that were obtained in Angel Rooms"..
            "#{{DevilRoom}} Each sacrificed item spawns 1 Devil Room item",
            Frame = 33,
            tarotClothBuffs = "Sacrificed items also leave behind their corresponding wisps",
        },
    },
    [36] = {
        Name = "I - 魔启",
        id = Cards.Invoker,
        zh = {
            Name = "I - 魔启",
            Desc = "我将启迪",
            Description = "从原版塔罗与透特牌中随机预言1张牌面"..
            "#之后使用该牌面时，生成1张随机卡牌并返还{{Card"..tostring(Cards.Invoker).."}}",
            Frame = 6,
            tarotClothBuffs = "预言3张不同牌面"..
            "#命中时生成2张随机卡牌",
        },
        en = {
            Name = "I - The Invoker",
            Desc = "I Will Invoke",
            Description = "Foretell 1 random face from vanilla tarot and Thoth cards"..
            "#When that face is used, spawn 1 random card and return {{Card"..tostring(Cards.Invoker).."}}",
            Frame = 6,
            tarotClothBuffs = "Foretell 3 different faces"..
            "#Spawn 2 random cards when one is used",
        },
    },
    [37] = {
        Name = "VI - 爱",
        id = Cards.Lover,
        zh = {
            Name = "VI - 爱",
            Desc = "吾爱自鸣",
            Description = "使用后，本房间内拾取基础资源或接触箱子时，有50%概率复制一份"..
            "#复制品不会再次触发此效果",
            Frame = 12,
            tarotClothBuffs = "概率提升至75%",
        },
        en = {
            Name = "VI - Lover",
            Desc = "A lover in Octave",
            Description = "For this room, picking up basic resources or contacting chests has a 50% chance to create a copy"..
            "#Copies cannot trigger this effect again",
            Frame = 12,
            tarotClothBuffs = "Chance increased to 75%",
        },
    },
    [38] = {
        Name = "VI - 爱?",
        id = Cards.Lover_r,
        zh = {
            Name = "VI - 爱?",
            Desc = "直到血流成河",
            Description = "品质0-4各生成1件被动道具，选择其中1件成为该品质的「爱人」"..
            "#同品质的其它被动道具会被排斥为对应道具魂火"..
            "#之后出现的该品质道具会变为「爱人」"..
            "#{{BrokenHeart}} 背叛爱人或利用候选时会受到惩罚",
            Frame = 34,
            tarotClothBuffs = "每个品质生成2件候选",
        },
        en = {
            Name = "VI - The Lover?",
            Desc = "Til blood shedding like river",
            Description = "Spawn 1 passive item of each quality 0-4; choose 1 to become that quality's beloved"..
            "#Other passive items of the same quality are rejected into corresponding item wisps"..
            "#Future items of that quality become the beloved"..
            "#{{BrokenHeart}} Betraying a beloved or exploiting a candidate causes punishment",
            Frame = 34,
            tarotClothBuffs = "2 candidates per quality",
        },
    },
    [39] = {
        Name = "XI - 欲望",
        id = Cards.Lure,
        zh = {
            Name = "XI - 欲望",
            Desc = "欲求皆有其形",
            Description = "使用时，当前敌人各自索求{{Coin}}{{Key}}{{Bomb}}{{Heart}}之一"..
            "#满足普通敌人后，其不再阻挡房门且不会造成接触伤害"..
            "#击杀已满足的敌人会掉落1-2份所求资源",
            Frame = 17,
            tarotClothBuffs = "普通敌人额外掉落1份资源的概率由35%提升至75%",
        },
        en = {
            Name = "XI - Lure",
            Desc = "Inspire their inner beast",
            Description = "On use, current enemies each demand one of {{Coin}}, {{Key}}, {{Bomb}}, or {{Heart}}"..
            "#Satisfying a normal enemy makes it no longer keep doors closed and deal no contact damage"..
            "#Killing a satisfied enemy drops 1-2 of the requested resource",
            Frame = 17,
            tarotClothBuffs = "Normal enemies' chance to drop 1 extra resource increases from 35% to 75%",
        },
    },
    [40] = {
        Name = "XI - 欲望?",
        id = Cards.Lure_r,
        zh = {
            Name = "XI - 欲望?",
            Desc = "顺从你内心的奴隶",
            Description =
            "持有时，每次受伤获得+0.75攻击，并使之后受到的最低伤害+0.5心"..
            "#使用后清空记录；每2层生成1个{{SoulHeart}}",
            Frame = 39,
            tarotClothBuffs = "奖励改为{{BlendedHeart}}",
        },
        en = {
            Name = "XI - Lure?",
            Desc = "Free your inner slave",
            Description =
            "While held, each hit grants +0.75 Damage and raises later minimum damage by half a heart"..
            "#Using it clears all records; spawns 1 {{SoulHeart}} per 2 records",
            Frame = 39,
            tarotClothBuffs = "Rewards become {{BlendedHeart}}",
        },
    },
    [41] = {
        Name = "XVIII - 太阴",
        id = Cards.Moon,
        zh = {
            Name = "XVIII - 太阴",
            Desc = "长守月明",
            Description = "{{Collectible589}} 生成一道月光",
            Frame = 24,
            tarotClothBuffs = "月光消失后留下通往隐藏房的传送门",
        },
        en = {
            Name = "XVIII - The Moon",
            Desc = "Keep watching moon til bright",
            Description = "Generate a moonlight whose effect is the same with {{Collectible589}}",
            Frame = 24,
            tarotClothBuffs = "When the moonlight generated by this method disappears, it will leave a portal to the secret room",
        },
    },
    [42] = {
        Name = "XVIII - A?",
        id = Cards.Moon_r,
        zh = {
            Name = "XVIII - A?",
            Desc = "望向天空，高高在上",
            Description = "{{Fear}} 使本房间敌人陷入恐惧，并使其受到约3倍总伤害"..
            "#{{Fear}} 玩家自身也会陷入20秒恐惧",
            Frame = 48,
            tarotClothBuffs = "玩家不再受到恐惧",
        },
        en = {
            Name = "XVIII - A?",
            Desc = "Look to the sky, way up on high",
            Description = "{{Fear}} Fear enemies in this room and make them take about 3× total damage"..
            "#{{Fear}} You are also feared for 20 seconds",
            Frame = 48,
            tarotClothBuffs = "You are no longer feared",
        },
    },
    [43] = {
        Name = "II - 女司祭",
        id = Cards.Priestess,
        zh = {
            Name = "II - 女司祭",
            Desc = "妈妈?是妈妈!",
            Description = "{{Timer}} 持续30秒，攻击时改为召唤巨大的妈妈之脚"..
            "#妈妈之脚造成40倍玩家伤害",
            Frame = 8,
            tarotClothBuffs = "持续时间延长至60秒",
        },
        en = {
            Name = "II - The High Priestess",
            Desc = "Mom? It's mom!",
            Description = "{{Timer}} For 30 seconds, attacking summons Mom's giant foot instead"..
            "#Mom's foot deals 40x your damage",
            Frame = 8,
            tarotClothBuffs = "Duration increased to 60 seconds",
        },
    },
    [44] = {
        Name = "II - 女司祭?",
        id = Cards.Priestess_r,
        zh = {
            Name = "II - 女司祭?",
            Desc = "和妈妈抱抱！",
            Description = "{{Timer}} 30秒内，攻击时发射会追踪敌人的标记"..
            "#标记命中后，妈妈之手会抓住敌人约3秒",
            Frame = 30,
            tarotClothBuffs = "被抓住的非Boss敌人会转化为友军",
        },
        en = {
            Name = "II - The High Priestess?",
            Desc = "Hug with your mommy!",
            Description = "{{Timer}} For 30s, attacking fires a mark that homes toward enemies"..
            "#On hit, Mom's Hand grabs the enemy for about 3 seconds",
            Frame = 30,
            tarotClothBuffs = "Grabbed non-boss enemies become friendly",
        },
    },
    [45] = {
        Name = "XXI - 深邃",
        id = Cards.Profound,
        zh = {
            Name = "XXI - 深邃",
            Desc = "有物井中来",
            Description = "{{SuperSecretRoom}} 使用后传送至本层超级隐藏房"..
            "#持有至下一层时，额外生成1个超级隐藏房",
            Frame = 57,
            tarotClothBuffs = "额外生成2个超级隐藏房",
        },
        en = {
            Name = "XXI - Profound",
            Desc = "Something rises from the well",
            Description = "{{SuperSecretRoom}} On use, teleport to a Super Secret Room on this floor"..
            "#Holding this card into the next floor adds 1 Super Secret Room",
            Frame = 57,
            tarotClothBuffs = "Adds 2 Super Secret Rooms instead",
        },
    },
    [46] = {
        Name = "XXI - 深邃?",
        id = Cards.Profound_r,
        zh = {
            Name = "XXI - 深邃?",
            Desc = "不见天月明",
            Description = "进入一座由心跳指引的迷宫"..
            "#连续找到4次正确的门"..
            "#完成后获得隐藏房道具3选1",
            Frame = 58,
            tarotClothBuffs = "最终奖励改为4选1",
        },
        en = {
            Name = "XXI - Profound?",
            Desc = "No moonlight reaches these depths",
            Description = "Enter a maze guided by heartbeats"..
            "#Find the correct door 4 times in a row"..
            "#Complete it for a 3-choice Secret Room item reward",
            Frame = 58,
            tarotClothBuffs = "Final reward becomes a 4-choice",
        },
    },
    [47] = {
        Name = "I - 贤者?",
        id = Cards.Sage_r,
        zh = {
            Name = "I - 贤者?",
            Desc = "我将绝火",
            Description = "在房间中所有实体边上点燃火堆"..
            "#复燃所有其他火堆"..
            "#当前房间内靠近火堆会将其自动熄灭",
            Frame = 29,
            tarotClothBuffs = "大幅提升特殊火的出现概率",
        },
        en = {
            Name = "I - The Sage?",
            Desc = "I Will Inflame",
            Description = "Light the fire on the edge of all enemies and pickups in the room"..
            "#Re-ignite all other fires"..
            "#The fire will be automatically extinguished when you are close to it in the current room",
            Frame = 29,
            tarotClothBuffs = "Greatly increase the occurrence probability of special fire",
        },
    },
    [48] = {
        Name = "XVII - 星坠",
        id = Cards.Star,
        zh = {
            Name = "XVII - 星坠",
            Desc = "星霜在此凝结",
            Description = "若此卡为本层使用的第一张卡牌，生成{{Heart}}红心、{{SoulHeart}}魂心与{{EternalHeart}}永恒心各1个"..
            "#否则，生成1个{{HalfHeart}}半红心",
            Frame = 23,
            tarotClothBuffs = "首次满足条件时，额外生成{{BlendedHeart}}混合心、{{BlackHeart}}黑心与{{BoneHeart}}骨心各1个",
        },
        en = {
            Name = "XVII - The Star",
            Desc = "Star frost condenses here",
            Description = "If this is the first card used on the floor, spawn 1 {{Heart}} Red Heart, 1 {{SoulHeart}} Soul Heart, and 1 {{EternalHeart}} Eternal Heart"..
            "#Otherwise, spawn 1 {{HalfHeart}} Half Red Heart",
            Frame = 23,
            tarotClothBuffs = "On a qualifying first use, also spawn 1 {{BlendedHeart}} Blended Heart, 1 {{BlackHeart}} Black Heart, and 1 {{BoneHeart}} Bone Heart",
        },
    },
    [49] = {
        Name = "XVII - 星辰?",
        id = Cards.Star_r,
        zh = {
            Name = "XVII - 星辰?",
            Desc = "他们灿若繁星",
            Description = "{{Collectible651}} 点亮房间内的敌人，使其获得伯列恒之星的光环"..
            "#地上的此卡也会提供50%强度的光环",
            Frame = 47,
            tarotClothBuffs = "本层后续出现的敌人与掉落物也会获得光环",
        },
        en = {
            Name = "XVII - The Stars?",
            Desc = "They shine like stars",
            Description = "{{Collectible651}} Light up enemies in the room, giving them a Star of Bethlehem aura"..
            "#This card also provides a 50%-strength aura while on the ground",
            Frame = 47,
            tarotClothBuffs = "Enemies and pickups appearing later on this floor also gain the aura",
        },
    },
    [50] = {
        Name = "V - 密仪",
        id = Cards.Sting,
        zh = {
            Name = "V - 密仪",
            Desc = "降神仪式",
            Description = "{{SacrificeRoom}} 生成一座仪式法阵"..
            "#在法阵中献祭半格生命，逐次获得不同奖励"..
            "#{{Heart}} 优先献祭红心",
            Frame = 59,
            tarotClothBuffs = "每次献祭有30%概率生成一颗魂心",
        },
        en = {
            Name = "V - Sting",
            Desc = "Invocation ritual",
            Description = "{{SacrificeRoom}} Creates a ritual circle"..
            "#Sacrifice half a heart within it to receive successive rewards"..
            "#{{Heart}} Red Hearts are consumed first",
            Frame = 59,
            tarotClothBuffs = "Each sacrifice has a 30% chance to spawn a Soul Heart",
        },
    },
    [51] = {
        Name = "V - 密仪?",
        id = Cards.Sting_r,
        zh = {
            Name = "V - 密仪?",
            Desc = "落入彼岸",
            Description = "将最强的敌人选作祭品"..
            "#每完成一次献祭，之后的祭品受到更多伤害"..
            "#仪式持续到房间中没有新的祭品",
            Frame = 60,
            tarotClothBuffs = "可同时标记2个祭品",
        },
        en = {
            Name = "V - Sting?",
            Desc = "Fall to abyss",
            Description = "Mark the strongest enemy as a sacrifice"..
            "#Each completed sacrifice makes later victims take more damage"..
            "#Continues until no new sacrifice remains",
            Frame = 60,
            tarotClothBuffs = "Can mark 2 sacrifices at once",
        },
    },
    [52] = {
        Name = "XIX - 太阳",
        id = Cards.Sun,
        zh = {
            Name = "XIX - 太阳",
            Desc = "物皆重临",
            Description = "重新发动本房间此前使用过的其他卡牌"..
            "#若一次重放至少3张卡牌，额外生成1张随机卡牌",
            Frame = 25,
            tarotClothBuffs = "若一次重放至少10张卡牌，额外生成1件道具",
        },
        en = {
            Name = "XIX - The Sun",
            Desc = "All that falls again",
            Description = "Replay other cards previously used in this room"..
            "#If at least 3 cards are replayed at once, spawn 1 random card",
            Frame = 25,
            tarotClothBuffs = "If at least 10 cards are replayed at once, also spawn 1 collectible",
        },
    },
    [53] = {
        Name = "XIX - 太阳?",
        id = Cards.Sun_r,
        zh = {
            Name = "XIX - 太阳?",
            Desc = "赞美我！",
            Description = "生成一个本层持续存在的彩虹传送门"..
            "#可以反复进入，每次进入都会重新随机传送至一个特殊房间",
            Frame = 49,
            tarotClothBuffs = "每次进入时优先传送至尚未探索的特殊房间",
        },
        en = {
            Name = "XIX - The Sun?",
            Desc = "Praise me!",
            Description = "Spawn a rainbow portal that lasts for the current floor"..
            "#It can be entered repeatedly; each entry rerolls a random special-room destination",
            Frame = 49,
            tarotClothBuffs = "Each entry prioritizes an unexplored special room",
        },
    },
    [54] = {
        Name = "XVI - 尖塔",
        id = Cards.Tower,
        zh = {
            Name = "XVI - 尖塔",
            Desc = "万物皆虚，万事皆允",
            Description = "将当前房间的障碍物升空，随后砸向敌人",
            Frame = 22,
            tarotClothBuffs = "出房间后恢复那些地形块",
        },
        en = {
            Name = "XVI - The Tower",
            Desc = "May you be terialistic",
            Description = "Lift obstacles in the current room, then smash them into enemies",
            Frame = 22,
            tarotClothBuffs = "Restore those grids after leaving the room",
        },
    },
    [55] = {
        Name = "XVI - 尖塔?",
        id = Cards.Tower_r,
        zh = {
            Name = "XVI - 尖塔?",
            Desc = "崩落...",
            Description = "持续从天而降大量随机障碍物"..
            "#后续波次越来越密集",
            Frame = 46,
            tarotClothBuffs = "波次数量由10提高至16",
        },
        en = {
            Name = "XVI - The Tower?",
            Desc = "Collapse...",
            Description = "Rain waves of random obstacles from above"..
            "#Later waves become increasingly dense",
            Frame = 46,
            tarotClothBuffs = "Wave count increases from 10 to 16",
        },
    },
    [56] = {
        Name = "XXI - 宇宙",
        id = Cards.Universe,
        zh = {
            Name = "XXI - 宇宙",
            Desc = "星汉灿烂",
            Description = "{{Planetarium}} 从你持有的道具中随机展示3个候选"..
            "#选择并永久失去其中1件，换取1件星辰类道具",
            Frame = 27,
            tarotClothBuffs = "奖励改为2选1",
        },
        en = {
            Name = "XXI - The Universe",
            Desc = "Ever shinning",
            Description = "{{Planetarium}} Show up to 3 random candidates from items you hold"..
            "#Permanently lose the chosen one for 1 star-themed item",
            Frame = 27,
            tarotClothBuffs = "Reward becomes a 2-choice instead",
        },
    },
    [57] = {
        Name = "XXI - 宇宙?",
        id = Cards.Universe_r,
        zh = {
            Name = "XXI - 宇宙?",
            Desc = "不管离开多远",
            Description = "首次使用时，将一件已有道具送入宇宙"..
            "#之后每次使用，生成该道具的一个副本"..
            "#进入新层时会重新获得这张卡",
            Frame = 51,
            tarotClothBuffs = "生成的道具视为新生成",
        },
        en = {
            Name = "XXI - The Universe?",
            Desc = "No matter how far you go",
            Description = "First use sends one owned item into the Universe"..
            "#Later uses create a copy of that item"..
            "#This card returns at the start of each new floor",
            Frame = 51,
            tarotClothBuffs = "Spawned copies count as newly generated",
        },
    },
    [58] = {
        Name = "X - 命运",
        id = Cards.Wheel_of_Destiny,
        zh = {
            Name = "X - 命运",
            Desc = "明暗为逆",
            Description = "选择1件已有道具，将其转化为2个脆弱的同名道具魂火"..
            "#经过2层后，存活的魂火各自变回该道具",
            Frame = 16,
            tarotClothBuffs = "改为生成3个更耐久的道具魂火",
        },
        en = {
            Name = "X - The Wheel of Destiny",
            Desc = "Light and dark coexist",
            Description = "Choose 1 held item and turn it into 2 fragile matching item wisps"..
            "#After 2 floors, each surviving wisp turns back into that item",
            Frame = 16,
            tarotClothBuffs = "Creates 3 tougher item wisps instead",
        },
    },
    [59] = {
        Name = "X - 命运?",
        id = Cards.Wheel_of_Destiny_r,
        zh = {
            Name = "X - 命运?",
            Desc = "你相信引力吗?",
            Description = "将房间内的普通掉落物展开为旋转的三至五选一",
            Frame = 38,
            tarotClothBuffs = "改为五至七选一",
        },
        en = {
            Name = "X - The Wheel of Destiny?",
            Desc = "Do you believe in gravity?",
            Description = "Turns ordinary pickups in the room into spinning choices of 3–5",
            Frame = 38,
            tarotClothBuffs = "Becomes a choice of 5–7",
        },
    },
    [60] = {
        Name = "I - 魔女",
        id = Cards.Witch,
        zh = {
            Name = "I - 魔女",
            Desc = "我将晶结",
            Description = "{{Freezing}} 发射4枚特殊冰冻泪弹"..
            "#命中敌人会将其冻结约5秒"..
            "#被冻结的敌人死亡时，使全房敌人减速约5秒",
            Frame = 5,
            tarotClothBuffs = "发射数量由4枚增加至8枚",
        },
        en = {
            Name = "I - The Witch",
            Desc = "I Will Congeal",
            Description = "{{Freezing}} Fire 4 special freezing tears"..
            "#Enemies hit are frozen for about 5 seconds"..
            "#If a frozen enemy dies, all enemies in the room are slowed for about 5 seconds",
            Frame = 5,
            tarotClothBuffs = "Increases the number of special freezing tears from 4 to 8",
        },
    },
    [61] = {
        Name = "I - 魔导",
        id = Cards.Wizard,
        zh = {
            Name = "I - 魔导",
            Desc = "我将昭世",
            Description = "揭示本层一种特殊房型的所有房间"..
            "#首次进入该房型时，生成数个通往其他特殊房间的传送旋涡",
            Frame = 7,
            tarotClothBuffs = "额外生成2个传送旋涡，并提高特殊目的地的出现机会",
        },
        en = {
            Name = "I - The Wizard",
            Desc = "I Will Reveal",
            Description = "Reveal all rooms of one special room type on this floor"..
            "#The first time you enter that room type, spawn several portals to other special rooms",
            Frame = 7,
            tarotClothBuffs = "+2 portals and a higher chance of special destinations",
        },
    },
    [62] = {
        Name = "0 - 忘却",
        id = Cards.Oblivion,
        zh = {
            Name = "0 - 忘却",
            Desc = "别忘了这是什么",
            Description = "持于主卡牌栏时逐渐褪色，约90秒后消失"..
            "#消失时，将最近获得的一件可移除被动道具替换为同池的另一件"..
            "#直接使用不会发动效果，且不会重置褪色进度",
            Frame = 61,
            tarotClothBuffs = "遗忘1件道具后，改为获得2件同池替代道具",
        },
        en = {
            Name = "0 - Oblivion",
            Desc = "Don't forget what this is",
            Description = "Gradually fades while held as your primary card, disappearing after about 90 seconds"..
            "#When it disappears, replaces your most recently acquired removable passive with another from the same item pool"..
            "#Using it directly has no effect and does not reset the fade",
            Frame = 61,
            tarotClothBuffs = "Forgetting 1 item grants 2 replacements from the same item pool instead",
        },
    },
    [63] = {
        Name = "0 - 忘却?",
        id = Cards.Oblivion_r,
        zh = {
            Name = "0 - 忘却?",
            Desc = "无量空处！",
            Description = "每秒临时获得1件随机被动道具，共50件"..
            "#每件持续5秒，且不会触发获得道具时的效果",
            Frame = 62,
            tarotClothBuffs = "额外获得50件临时道具",
        },
        en = {
            Name = "0 - Oblivion?",
            Desc = "Unlimited Void!",
            Description = "Temporarily gain 1 random passive item every second, 50 times"..
            "#Each lasts 5 seconds and does not trigger on-acquire effects",
            Frame = 62,
            tarotClothBuffs = "Grants 50 additional temporary items",
        },
    },
}

item.Players = {
    [1] = {
        Name = "安娜",
        id = enums.Players.Anna,
        type = "player",
        zh = {
            Name = "安娜",
            Desc = "灾难之角",
            Description = "操控掌中黑洞吸收敌人与掉落物，并将捕获物重新发射"..
                "#敌人被吸入后不会立即死亡"..
                "#捕获物的种类、重量与蓄力会影响释放攻击",
            StartGuide = {
                Name = "操作指南：安娜",
                Description = "按住 {{ButtonRT}} 时松开攻击键不会发射"..
                    "#清理房间后按住攻击键并双击 {{ButtonRT}} 可快速收回捕获物",
            },
        },
        en = {
            Name = "Anna",
            Desc = "The Horn of Nitimity",
            Description = "Control a handheld black hole to capture enemies and pickups, then launch them as projectiles"..
                "#Captured enemies remain alive inside the black hole"..
                "#A capture's type, mass, and charge affect the released attack",
            Animation = "Anna",
            Sprite = "gfx/characterportraits.anm2",
            StartGuide = {
                Name = "Operation Guide: Anna",
                Description = "Release the attack key while holding {{ButtonRT}} to avoid firing"..
                    "#After clearing a room, hold attack and double-tap {{ButtonRT}} to quickly recall captures",
            },
        },
    },
    [2] = {
        Name = "艾提奥",
        id = enums.Players.Autio,
        type = "player",
        zh = {
            Name = "艾提奥",
            Desc = "灾难之影",
            Description = "",
        },
        en = {
            Name = "Autio",
            Desc = "The Shadow of Nitimity",
            Description = "",
            Animation = "Autio",
            Sprite = "gfx/characterportraits.anm2",
        },
    },
    [3] = {
        Name = "露",
        id = enums.Players.Lu,
        type = "player",
        zh = {
            Name = "露",
            Desc = "灾难之喉",
            Description = "",
        },
        en = {
            Name = "Lu",
            Desc = "The Throat of Nitimity",
            Description = "",
            Animation = "Lu",
            Sprite = "gfx/characterportraits.anm2",
        },
    },
    [4] = {
        Name = "玛丽亚诺",
        id = enums.Players.Marriano,
        type = "player",
        zh = {
            Name = "玛丽亚诺",
            Desc = "",
            StartGuide = {
                Name = "操作指南：玛利亚诺",
                Description = "将道具重置为面具#面具全部破碎后堕入恶魔",
            },
        },
        en = {
            StartGuide = {
                Name = "Operation Guide: Marriano",
                Description = "Reset items into masks#Fall to the Devil when all masks break",
            },
        },
    },
    [5] = {
        Name = "青",
        id = enums.Players.Spwq,
        type = "player",
        zh = {
            Name = "青",
            Desc = "灾难之终械",
            Description = "{{Collectible"..enums.Items.Air_Flight.."}} 无法直接攻击；使用蓝图制造并改装独立飞行器"..
                "#将飞行器编入队伍，并用准星指挥它们作战"..
                "#控制带宽决定当前能够出战的机体",
            StartGuide = {
                Name = "操作指南：青",
                Description = "攻击键或按住鼠标左键移动指挥准星"..
                    "#Ctrl 或鼠标中键切换巡航 / 护卫"..
                    "#鼠标右键或短按蓝图切换自动 / 压制开火"..
                    "#长按蓝图打开面板",
            },
        },
        en = {
            Name = "Qing",
            Desc = "The Final Machine of Nitimity",
            Description = "{{Collectible"..enums.Items.Air_Flight.."}} Cannot attack directly; use Blueprint to build and refit independent drones"..
                "#Deploy drones into formation and command them with the targeting reticle"..
                "#Control bandwidth determines which drones can fight",
            Animation = "SP.W.Qing",
            Sprite = "gfx/characterportraitsalt.anm2",
            Tainted = true,
            StartGuide = {
                Name = "Operation Guide: Qing",
                Description = "Attack or hold LMB to move the command reticle"..
                    "#Ctrl or MMB toggles Cruise / Guard"..
                    "#RMB or tap Blueprint toggles Auto / Suppression fire"..
                    "#Hold Blueprint to open the panel",
            },
        },
    },
    [6] = {
        Name = "泰克罗",
        id = enums.Players.Tecro,
        type = "player",
        zh = {
            Name = "泰克罗",
            Desc = "灾难之牙",
            Description = "操纵持续存在的长枪，将敌人穿在枪上并继续旋转"..
                "#枪尖实际移动越快，接触伤害越高"..
                "#蓄力后松开攻击，向枪尖方向发动突刺",
            StartGuide = {
                Name = "操作指南：泰克罗",
                Description = "攻击方向旋转枪尖并蓄力"..
                    "#突刺命中敌人可将其固定在枪上"..
                    "#继续高速旋转；鼠标中键切换鼠标控制",
            },
        },
        en = {
            Name = "Tecro",
            Desc = "The Tooth of Nitimity",
            Description = "Control a persistent spear, impale enemies, and keep them on the weapon as it rotates"..
                "#Higher actual spear-tip speed deals more contact damage"..
                "#Charge and release to thrust in the spear tip's direction",
            Animation = "Tecro",
            Sprite = "gfx/characterportraits.anm2",
            StartGuide = {
                Name = "Operation Guide: Tecro",
                Description = "Use attack directions to rotate the spear tip and charge"..
                    "#Thrust into enemies to pin them onto the spear"..
                    "#Keep rotating at speed; press the middle mouse button to toggle mouse control",
            },
        },
    },
    [7] = {
        Name = "泰克罗罗恩",
        id = enums.Players.Tecrorun,
        type = "player",
        zh = {
            Name = "泰克罗罗恩",
            Desc = "灾难之光",
            Description = "以长枪瞄准并蓄力，使枪尖延伸出在房间中镜像反射的光柱"..
                "#松开攻击后沿光柱无敌冲刺，并伤害沿途附近的敌人",
            StartGuide = {
                Name = "操作指南：泰克罗·罗恩",
                Description = "按下鼠标中键开关鼠标控制"..
                    "#瞄准门口冲刺可以直接离开房间"..
                    "#满蓄力造成更高伤害",
            },
        },
        en = {
            Name = "Tecrorun",
            Desc = "The Light of Nitimity",
            Description = "Aim and charge the spear to project a beam from its tip that reflects across the room"..
                "#Release to dash invincibly along the beam, damaging nearby enemies",
            Animation = "Tecrorun",
            Sprite = "gfx/characterportraitsalt.anm2",
            Tainted = true,
            StartGuide = {
                Name = "Operation Guide: Tecrorun",
                Description = "Press the middle mouse button to toggle mouse control"..
                    "#Dash toward a door to leave the room"..
                    "#Fully charged attacks deal more damage",
            },
        },
    },
    [8] = {
        Name = "泽伊斯托斯",
        id = enums.Players.Zeistos,
        type = "player",
        zh = {
            Name = "泽伊斯托斯",
            Desc = "灾难之眼",
            Description = "接触道具时不会直接获得，而是将其作为知识送入死亡证明"..
                "#每层可永久取得知识对应的道具，或临时取得其附近的一项遐想"..
                "#选择遐想不会消耗知识；下一层仍可重新选择"..
                "#自动点亮死亡证明中存在可用知识的房间",
            StartGuide = {
                Name = "操作指南：泽·伊斯托斯",
                Description = "第一层可自由选择一个被动道具作为本层遐想"..
                    "#此后以送入死亡证明的知识为底座，取得对应道具或选择附近遐想"..
                    "#遐想仅持续一层，知识会在下一层恢复可选",
            },
        },
        en = {
            Name = "Zeis",
            Desc = "The Eye of Nitimity",
            Description = "Touched items are not gained immediately; they are sent to Death Certificate as knowledge"..
                "#Each floor, claim the item recorded as knowledge or temporarily realize a nearby reverie"..
                "#Choosing a reverie does not consume its knowledge; it can be chosen again next floor"..
                "#Automatically reveals Death Certificate rooms containing available knowledge",
            Animation = "Zeistos",
            Sprite = "gfx/characterportraits.anm2",
            StartGuide = {
                Name = "Operation Guide: Zeis",
                Description = "On the first floor, freely realize one passive reverie"..
                    "#Afterward, use knowledge sent to Death Certificate to claim its item or realize a nearby reverie"..
                    "#Reveries last for one floor; their knowledge becomes available again next floor",
            },
        },
    },
    [9] = {
        Name = "安奈",
        id = enums.Players.annA,
        type = "player",
        zh = {
            Name = "安奈",
            Desc = "灾难之魔",
            Description = "用准星选择落点，以自身为武器发动高威力坠击"..
                "#满蓄力后移动至准星上方，攻击落点附近的敌人"..
                "#准星也决定攻击后的站位；攻击过程及结束后0.25秒内无敌",
            StartGuide = {
                Name = "操作指南：安奈",
                Description = "使用攻击方向移动准星并蓄力"..
                    "#蓄力完成后自动坠击准星位置"..
                    "#利用攻击后0.25秒无敌离开落点",
            },
        },
        en = {
            Name = "Anna",
            Desc = "The Devil of Nitimity",
            Description = "Choose a landing point with the reticle and use annA herself as the weapon"..
                "#At full charge, move above the reticle and crash down to attack nearby enemies"..
                "#The reticle is also your final position; invincible during the attack and for 0.25s afterward",
            Animation = "annA",
            Sprite = "gfx/characterportraitsalt.anm2",
            Tainted = true,
            StartGuide = {
                Name = "Operation Guide: annA",
                Description = "Use attack directions to move the reticle and charge"..
                    "#At full charge, automatically dive onto the reticle"..
                    "#Use the 0.25s of post-attack invincibility to leave the landing point",
            },
        },
    },
    [10] = {
        Name = "小青",
        id = enums.Players.wq,
        type = "player",
        zh = {
            Name = "小青",
            Desc = "灾难之先导",
            Description = "以小刀近身刺杀或投掷攻击；投出的刀还能留下可返回的位置"..
                "#在刀与刀之间快速转移，从不同位置继续攻击"..
                "#必要时会保留可用的小刀，避免失去返回路径",
            StartGuide = {
                Name = "操作指南：青",
                Description = "按下Alt键瞬移至已插入的小刀"..
                    "#必要情况下小刀会自动扎在墙上",
            },
        },
        en = {
            Name = "Qing",
            Desc = "The Precursor of Nitimity",
            Description = "Fight with close-range knife strikes or thrown blades; lodged knives leave return points"..
                "#Move between knives to continue attacking from new positions"..
                "#A usable knife is preserved when necessary to keep a return path",
            Animation = "W.Qing",
            Sprite = "gfx/characterportraits.anm2",
            StartGuide = {
                Name = "Operation Guide: W.Q.",
                Description = "Press Alt to teleport to a lodged knife"..
                    "#When necessary, a knife automatically sticks into a wall",
            },
        },
    },
    [11] = {
        Name = "泽伊兹",
        id = enums.Players.Zeiz,
        type = "player",
        zh = {
            Name = "泽伊兹",
            Desc = "灾难之理",
            Description = "每层从控制中枢任命一名管理员，由其愚见改变世界的运行规则"..
                "#不同管理员会依照自己的错误认知解释并管理游戏机制"..
                "#引起管理员的兴趣，使其准备进一步改变规则的提案",
            StartGuide = {
                Name = "操作指南：泽伊兹",
                Description = "每层进入控制中枢"..
                    "#接触候选虚影以任命管理员"..
                    "#按照管理员的愚见行动以引起其兴趣",
            },
        },
        en = {
            Name = "Zeiz",
            Desc = "The Reason of Nitimity",
            Description = "Appoint an administrator in the Control Hub each floor, whose Folly alters how the world operates"..
                "#Each administrator interprets and manages game rules through their own mistaken reasoning"..
                "#Draw their interest until they prepare a Proposal to reshape the rules further",
            Animation = "Zeiz",
            Sprite = "gfx/characterportraitsalt.anm2",
            Tainted = true,
            StartGuide = {
                Name = "Operation Guide: Zeiz",
                Description = "Enter the Control Hub each floor"..
                    "#Touch a candidate phantom to appoint an administrator"..
                    "#Act according to their Folly to draw their interest",
            },
        },
    },
}

item.Birthrights = {
    [1] = {
        Name = "Players.Anna",
        id = Players.Anna,
        type = "birthright",
        zh = {
            Desc = "血光之灾",
            Description = "{{Speed}} 超额的吞噬物不再降低移速"..
            "#每层均有小恶魔乞丐",
            PlayerName = "安娜",
        },
        en = {
            Desc = "Bloody disaster",
            Description = "{{Speed}} Excessive phagocytosis no longer reduces movement speed"..
            "#There are rift beggars on each floor",
            PlayerName = "Anna",
        },
    },
    [2] = {
        Name = "Players.Marriano",
        id = Players.Marriano,
        type = "birthright",
        zh = {
            Desc = "人格重组",
            Description = "死亡时舍弃另一形态与此道具并复活"..
            "#通过2个楼层以拼合阴阳两面",
            PlayerName = "玛丽亚诺",
        },
        en = {
            Desc = "Personality reorganization",
        },
    },
    [3] = {
        Name = "Players.Spwq",
        id = Players.Spwq,
        type = "birthright",
        zh = {
            Desc = "额外组件已就位",
            Description = "每架飞行器额外获得1个镜像模块槽"..
            "#镜像槽可引用已拥有的道具，且不占用其蓝图分配"..
            "#失去原道具时，对应镜像失效",
            PlayerName = "青？",
        },
        en = {
            Desc = "Memories...",
            Description = "Each craft gains 1 mirror module slot"..
            "#Mirror slots reference owned items without using blueprint allocation"..
            "#Mirrors break if you lose the source item",
            PlayerName = "W.Qing",
        },
    },
    [4] = {
        Name = "Players.Tecro",
        id = Players.Tecro,
        type = "birthright",
        zh = {
            Desc = "刺痛塑我身",
            Description = "蓄力出枪后命中的第一个敌人受到所有持有隐枪的再次攻击",
            PlayerName = "泰克罗",
        },
        en = {
            Desc = "I Sting!",
            Description = "The first enemy hit by spear will be attacked by all hidden spears.",
            PlayerName = "Tecro",
        },
    },
    [5] = {
        Name = "Players.Tecrorun",
        id = Players.Tecrorun,
        type = "birthright",
        zh = {
            Desc = "轻如光明",
            Description = "100%聚焦时+4弹射次数",
            PlayerName = "泰克罗· 罗恩",
        },
        en = {
            Desc = "She is back now",
            Description = "+4 times of reflect when 100% charge.",
            PlayerName = "Tecrorun",
        },
    },
    [6] = {
        Name = "Players.Zeistos",
        id = Players.Zeistos,
        type = "birthright",
        zh = {
            Desc = "所见即所得",
            Description = "{{Collectible628}} 初始房间始终存在死亡证明传送门"..
            "#每层可以额外自由选择一个被动道具"..
            "#未拥有的被动道具最多可以拿两次",
            PlayerName = "泽伊斯托斯",
        },
        en = {
            Desc = "WYSIWYG",
            Description = "{{Collectible628}} The initial room always has a death certificate teleportation door"..
            "#Each layer can choose an additional passive item freely "..
            "#Unowned passive items can be taken up to twice",
            PlayerName = "Zeis",
        },
    },
    [7] = {
        Name = "Players.annA",
        id = Players.annA,
        type = "birthright",
        zh = {
            Desc = "神明攻势",
            Description = "攻击时概率触发随机额外攻击",
            PlayerName = "安奈",
        },
        en = {
            Desc = "Divine Offensive",
            Description = "Trigger extra random attack forms when attack.",
            PlayerName = "Anna",
        },
    },
    [8] = {
        Name = "Players.wq",
        id = Players.wq,
        type = "birthright",
        zh = {
            Desc = "血债应由血偿!",
            Description = "极大提升瞬移攻击与伤害"..
            "#无目标时按下瞬移键快速移动"..
            "#存在目标时快速暗杀敌人",
            PlayerName = "青",
        },
        en = {
            Desc = "Pain has to Pay!",
            Description = "Greatly evolves teleportation attack"..
            "#Press teleportation key to quickly move when there is no target "..
            "#Quickly assassinate enemies when there is a target",
            PlayerName = "W.Q.",
        },
    },
}

item.Challenges = {
    [1] = {
        Name = "挑战：曲奇点击者",
        id = enums.Challenges.Cookie_Clicker,
        type = "challenge",
        zh = {
            Name = "挑战：曲奇点击者",
            Description = "{{Player15}} 亚波伦开局"..
            "#!!! 无法发射眼泪"..
            "#使用鼠标点击敌人造成伤害"..
            "#难度等级：普通",
        },
        en = {
            Name = "Cookie Clicker",
            Description = "{{Player15}} Play as Apollyon"..
            "#!!! Cannot shoot tears"..
            "#Click enemies with the mouse to deal damage"..
            "#Difficulty: Normal",
        },
    },
    [2] = {
        Name = "挑战：飞龙在天",
        id = enums.Challenges.Dragon_Flight,
        type = "challenge",
        zh = {
            Name = "挑战：飞龙在天",
            Description = "{{Player3}} 犹大开局"..
            "#{{Collectible"..enums.Items.Book_of_How_to_Fly.."}} 使用飞行书与{{Collectible619}}长子名分进行空战"..
            "#{{Collectible641}} 书本发射的眼泪会沿飞行轨迹留在角色身后"..
            "#难度等级：普通",
        },
        en = {
            Name = "Dragon Flight",
            Description = "{{Player3}} Play as Judas"..
            "#{{Collectible"..enums.Items.Book_of_How_to_Fly.."}} Fight in the air with How to Fly and {{Collectible619}}Birthright"..
            "#{{Collectible641}} Tears fired by books remain along your flight path"..
            "#Difficulty: Normal",
        },
    },
    [3] = {
        Name = "挑战：粉丝服务",
        id = enums.Challenges.Fans_Service,
        type = "challenge",
        zh = {
            Name = "挑战：粉丝服务",
            Description = "{{Player1}} 抹大拉开局"..
            "#{{Charm}} 接近普通敌人会将其永久魅惑"..
            "#{{ArrowUp}} 被魅惑的敌人每清理一个房间都会稍微成长"..
            "#!!! 每层第一次进入Boss房时，所有被魅惑敌人解除魅惑"..
            "#超级撒旦房间始终解除所有被魅惑敌人"..
            "#难度等级：困难",
        },
        en = {
            Name = "Fans Service",
            Description = "{{Player1}} Play as Magdalene"..
            "#{{Charm}} Walking near normal enemies charms them permanently"..
            "#{{ArrowUp}} Charmed enemies grow slightly each time a room is cleared"..
            "#!!! Entering the first Boss room on each floor removes Charm; they become hostile again"..
            "#Super Satan's room always removes Charm from all charmed enemies"..
            "#Difficulty: Hard",
        },
    },
    [4] = {
        Name = "挑战：心如死灰",
        id = enums.Challenges.Feels_Like_Dead_Ashes,
        type = "challenge",
        zh = {
            Name = "挑战：心如死灰",
            Description = "{{Player21}} 里以撒开局"..
            "#{{Collectible"..enums.Items.Ember.."}} 开局持有8个余烬，占用道具槽"..
            "#!!! 除余烬外，被动与跟班可占槽但效果无效"..
            "#{{Collectible"..enums.Items.Ember.."}} 每个余烬复制最近一次永久失去的可复制被动"..
            "#!!! 舍弃余烬会降低复制倍率，但不改变复制目标"..
            "#不可打开控制台"..
            "#难度等级：噩梦",
        },
        en = {
            Name = "Feels Like Dead Ashes",
            Description = "{{Player21}} Play as Tainted Isaac"..
            "#{{Collectible"..enums.Items.Ember.."}} Start with 8 Embers that occupy item slots"..
            "#!!! Non-Ember passives and familiars can occupy slots but are disabled"..
            "#{{Collectible"..enums.Items.Ember.."}} Each Ember copies the last permanently lost copyable passive"..
            "#!!! Discarding Embers lowers the copy multiplier, not the copy target"..
            "#Console is disabled"..
            "#Difficulty: Nightmare",
        },
    },
    [5] = {
        Name = "挑战：命运融合",
        id = enums.Challenges.Fusion_Destiny,
        type = "challenge",
        zh = {
            Name = "挑战：命运融合",
            Description = "{{Player23}} 里该隐开局"..
            "#!!! 无法发射眼泪"..
            "#{{Collectible710}} 使用合成袋捕获敌人，并将其转化为基础掉落"..
            "#对Boss使用合成袋会获得基础掉落，并从Boss身上打出更多素材"..
            "#!!! 没有{{TreasureRoom}}宝箱房与{{Shop}}商店"..
            "#难度等级：简单",
        },
        en = {
            Name = "Fusion Destiny",
            Description = "{{Player23}} Play as Tainted Cain"..
            "#!!! Cannot shoot tears"..
            "#{{Collectible710}} Capture enemies as pickups with the Bag of Crafting"..
            "#Using the bag on a Boss grants a pickup and knocks extra ingredients out of it"..
            "#!!! No {{TreasureRoom}}Treasure Rooms or {{Shop}}Shops"..
            "#Difficulty: Easy",
        },
    },
    [6] = {
        Name = "挑战：异热同心",
        id = enums.Challenges.Heterothermal_Concentric,
        type = "challenge",
        zh = {
            Name = "挑战：异热同心",
            Description = "{{Player19}} 雅各与以扫开局"..
            "#!!! 双方只能朝彼此所在的方向射击"..
            "#{{ArrowUp}} 眼泪穿过另一人后获得强化"..
            "#难度等级：普通",
        },
        en = {
            Name = "Heterothermal Concentric",
            Description = "{{Player19}} Play as Jacob and Esau"..
            "#!!! Both can only shoot toward each other"..
            "#{{ArrowUp}} Tears that pass through the other character are boosted"..
            "#Difficulty: Normal",
        },
    },
    [7] = {
        Name = "挑战：不为人知",
        id = enums.Challenges.Invisible,
        type = "challenge",
        zh = {
            Name = "挑战：不为人知",
            Description = "{{Player24}} 里犹大开局"..
            "#!!! 房间中的一切都会逐渐隐形"..
            "#{{Collectible705}} 黑暗艺术经过的区域会暂时重新显形"..
            "#!!! 没有{{TreasureRoom}}宝箱房与{{Shop}}商店"..
            "#难度等级：简单",
        },
        en = {
            Name = "Invisible",
            Description = "{{Player24}} Play as Tainted Judas"..
            "#!!! Everything in the room gradually turns invisible"..
            "#{{Collectible705}} Dark Arts briefly reveals the area it passes through"..
            "#!!! No {{TreasureRoom}}Treasure Rooms or {{Shop}}Shops"..
            "#Difficulty: Easy",
        },
    },
    [8] = {
        Name = "挑战：卢浮宫难题",
        id = enums.Challenges.Louvre_puzzle,
        type = "challenge",
        zh = {
            Name = "挑战：卢浮宫难题",
            Description = "{{Player0}} 以撒开局"..
            "#{{Collectible628}} 每层从死亡证明区域开始"..
            "#!!! 越接近道具，道具轮换得越快"..
            "#{{Collectible478}} 使用暂停可使所有道具停止轮换2秒"..
            "#难度等级：简单",
        },
        en = {
            Name = "Louvre Puzzle",
            Description = "{{Player0}} Play as Isaac"..
            "#{{Collectible628}} Each floor starts in the Death Certificate area"..
            "#!!! The closer you are to an item, the faster it rerolls"..
            "#{{Collectible478}} Using Pause freezes all rerolls for 2 seconds"..
            "#Difficulty: Easy",
        },
    },
    [9] = {
        Name = "挑战：指指点点",
        id = enums.Challenges.Pointing,
        type = "challenge",
        zh = {
            Name = "挑战：指指点点",
            Description = "{{Player6}} 参孙开局"..
            "#{{Collectible"..tostring(enums.Items.Cloundy).."}} 持有5个云玩大佬"..
            "#{{Collectible583}} 持有火箭炸弹，云玩大佬放置的炸弹也会变成火箭"..
            "#难度等级：困难",
        },
        en = {
            Name = "Pointing and Disappointing",
            Description = "{{Player6}} Play as Samson"..
            "#{{Collectible"..tostring(enums.Items.Cloundy).."}} Start with 5 Cloundies"..
            "#{{Collectible583}} Start with Rocket in a Jar; bombs placed by Cloundies also become rockets"..
            "#Difficulty: Hard",
        },
    },
    [10] = {
        Name = "挑战：安全驾驶",
        id = enums.Challenges.Safe_Driving,
        type = "challenge",
        zh = {
            Name = "挑战：安全驾驶",
            Description = "{{Player18}} 伯大尼开局"..
            "#!!! 无法发射眼泪"..
            "#蓄满专用充能后，朝攻击方向发出{{Collectible"..enums.Items.Hyper_Velocity.."}}列车撞击敌人"..
            "#难度等级：普通",
        },
        en = {
            Name = "Safe Driving",
            Description = "{{Player18}} Play as Bethany"..
            "#!!! Cannot shoot tears"..
            "#After the special charge fills, fire a {{Collectible"..enums.Items.Hyper_Velocity.."}} train in your attack direction"..
            "#Difficulty: Normal",
        },
    },
    [11] = {
        Name = "挑战：食日",
        id = enums.Challenges.Swallow_The_Sun,
        type = "challenge",
        zh = {
            Name = "挑战：食日",
            Description = "{{Player"..enums.Players.Anna.."}} 安娜开局"..
            "#{{ArrowUp}} 掌中黑洞完全吸入敌人后将其直接消灭"..
            "#!!! 无法拾取任何地面掉落物，包括道具"..
            "#{{BlackHeart}} 进入新层获得2颗黑心、{{Bomb}}1炸弹与{{Key}}1钥匙"..
            "#难度等级：简单",
        },
        en = {
            Name = "Swallow the Sun",
            Description = "{{Player"..enums.Players.Anna.."}} Play as Anna"..
            "#{{ArrowUp}} Fully sucked-in enemies are devoured"..
            "#!!! Cannot pick up any floor pickups, including items"..
            "#{{BlackHeart}} Gain 2 Black Hearts, {{Bomb}}1 bomb and {{Key}}1 key on each new floor"..
            "#Difficulty: Easy",
        },
    },
    [12] = {
        Name = "挑战：不稳定体",
        id = enums.Challenges.Unstable_State,
        type = "challenge",
        zh = {
            Name = "挑战：不稳定体",
            Description = "{{Player9}} 伊甸开局"..
            "#!!! 受伤时随机3个被动道具从身上脱落"..
            "#及时触碰可以重新拾取"..
            "#!!! 敌人可以抢走脱落的道具并获得强化"..
            "#击杀携带道具的敌人可重新取回道具"..
            "#难度等级：普通",
        },
        en = {
            Name = "Unstable State",
            Description = "{{Player9}} Play as Eden"..
            "#!!! Taking damage knocks 3 random passive items out of you"..
            "#Touch them to pick them back up"..
            "#!!! Enemies can steal dropped items and become stronger"..
            "#Kill the thief to recover the stolen item"..
            "#Difficulty: Normal",
        },
    },
}

item.Pickups = {
    [1] = {
        Variant = Pickups.Glaze_heart.Variant,
        SubType = Pickups.Glaze_heart.SubType,
        zh = {
            Name = "琉璃之心",
            Description = "根据当前生命模仿一种可获得的心"..
            "#优先抵消{{BrokenHeart}}碎心与{{RottenHeart}}腐心",
        },
        en = {
            Name = "Glaze Heart",
            Description = "Imitates an obtainable heart based on your health"..
            "#Priority: remove {{BrokenHeart}} Broken Hearts and {{RottenHeart}} Rotten Hearts",
        },
    },
    [2] = {
        Variant = Pickups.Glaze_heart_half.Variant,
        SubType = Pickups.Glaze_heart_half.SubType,
        zh = {
            Name = "琉璃之半心",
            Description = "根据当前生命模仿一种可获得的心（半颗）"..
            "#优先抵消{{BrokenHeart}}碎心与{{RottenHeart}}腐心",
        },
        en = {
            Name = "Half of a Glaze Heart",
            Description = "Imitates an obtainable heart based on your health (half)"..
            "#Priority: remove {{BrokenHeart}} Broken Hearts and {{RottenHeart}} Rotten Hearts",
        },
    },

    [3] = {
        Variant = Pickups.Glaze_key.Variant,
        SubType = Pickups.Glaze_key.SubType,
        zh = {
            Name = "琉璃之匙",
            Description = "优先揭示未探索的{{TreasureRoom}}/{{Shop}}/{{BossRoom}}等特殊房（不含隐藏系）"..
            "#没有则揭示最多3个普通房间",
        },
        en = {
            Name = "Glaze Key",
            Description = "Reveal an unexplored special room (Treasure/Shop/Boss; not secret)"..
            "#If none, reveal up to 3 normal rooms",
        },
    },
    [4] = {
        Variant = Pickups.Glaze_bomb.Variant,
        SubType = Pickups.Glaze_bomb.SubType,
        zh = {
            Name = "琉璃之炸弹",
            Description = "下一次炸弹爆炸时清除本房间所有弹幕",
        },
        en = {
            Name = "Glaze Bomb",
            Description = "The next bomb explosion clears all projectiles in the room",
        },
    },
    [5] = {
        Variant = Pickups.Glaze_grabbag.Variant,
        SubType = Pickups.Glaze_grabbag.SubType,
        zh = {
            Name = "琉璃之福袋",
            Description = "消耗富余的硬币/钥匙/炸弹，生成对应琉璃掉落"..
            "#硬币>5、钥匙>1、炸弹>1才会计入"..
            "#最多约3份"..
            "#{{PoopPickup}} 没有可消耗资源时生成琉璃便便",
        },
        en = {
            Name = "Glaze Grabbag",
            Description = "Convert surplus coins/keys/bombs into glazed pickups"..
            "#Only coins>5, keys>1, bombs>1 count"..
            "#Up to about 3"..
            "#{{PoopPickup}} Spawns a glaze poop if nothing to convert",
        },
    },
    [6] = {
        Variant = Pickups.Glaze_battery.Variant,
        SubType = Pickups.Glaze_battery.SubType,
        zh = {
            Name = "琉璃之电池",
            Description = "下次使用普通主动时，返还一半消耗的充能（向上取整）",
        },
        en = {
            Name = "Glaze Battery",
            Description = "Next normal active use refunds half the charges spent (rounded up)",
        },
    },
    [7] = {
        Variant = Pickups.Glaze_chest.Variant,
        SubType = Pickups.Glaze_chest.SubType,
        zh = {
            Name = "琉璃之宝箱",
            Description = "本层另一个房间会出现对应钥匙，钥匙房会在地图上标记"..
            "#只有对应钥匙才能打开宝箱"..
            "#60%：生成4~7个随机琉璃掉落"..
            "#40%：复制一个当前持有的随机道具",
        },
        en = {
            Name = "Glaze Chest",
            Description = "A matching key appears in another room on this floor; its room is marked on the map"..
            "#Only that key can open the chest"..
            "#60%: spawns 4~7 random glazed pickups"..
            "#40%: duplicates a random item you currently own",
        },
    },
    [8] = {
        Variant = Pickups.Glaze_big_poop.Variant,
        SubType = Pickups.Glaze_big_poop.SubType,
        zh = {
            Name = "琉璃之便便",
            Description = "将队首便便复制到队列末尾"..
            "#空队列时获得基础便便",
        },
        en = {
            Name = "Glaze poop",
            Description = "Copy the front poop spell to the end of the queue"..
            "#Empty queue grants a basic poop",
        },
    },
    [10] = {
        pickupKey = "Glaze_Coin",
        pseudoPickup = true,
        Variant = Pickups.Glaze_coin.Variant,
        SubType = Pickups.Glaze_coin.SubType,
        zh = {
            Name = "琉璃硬币",
            Description = "#缓缓吸引周围的掉落物"..
                "#{{Coin}} 拾取：90%获得1枚硬币，10%获得5枚",
        },
        en = {
            Name = "Glaze Coin",
            Description = "#Slowly attracts nearby pickups"..
                "#{{Coin}} On pickup: 90% for 1 coin, 10% for 5",
        },
    },
    -- SubType 运行时为对应收藏品 ID；实际 Name/Desc 由 pickup_blueprint_prototype.load_EID / get_texts 动态覆盖
    [9] = {
        Variant = Pickups.Blueprint_Prototype.Variant,
        SubType = 0,
        zh = {
            Name = "道具原型",
            Desc = "",
            Description = "#{{Collectible}} 拾取后，将其中展示的道具记录为1份原型模块"..
            "#原型模块存入蓝图仓库，可额外装配1次对应道具效果"..
            "#只能作为模块使用，不能作为飞行器底座",
        },
        en = {
            Name = "Item Prototype",
            Desc = "",
            Description = "#{{Collectible}} On pickup, records the displayed item as 1 prototype module"..
            "#Stored in Blueprint inventory, granting 1 extra installation of that item's effect"..
            "#Modules only; cannot be used as a craft base",
        },
    },
}

item.Slots = {
    [1] = {
        id = enums.Slots.Bard_beggar.Variant,
        zh = {
            Name = "吟游乞丐",
            Description = "赠予一份资源，换取下层祝福"..
            "#靠近后左右切换馈赠，走进确认"..
            "#按{{ButtonRT}}取消",
        },
        en = {
            Name = "Bard Beggar",
            Description = "Offer a resource for a blessing on the next floor"..
            "#Switch gifts with left/right, walk in to confirm"..
            "#Press {{ButtonRT}} to cancel",
        },
    },
    [2] = {
        id = enums.Slots.Rift_beggar.Variant,
        zh = {
            Name = "黑洞恶魔乞丐",
            Description = "吞噬身边的基础掉落"..
            "#每25个送出一个品质4道具，然后离开"..
            "#每个偶数层出现",
        },
        en = {
            Name = "Rift beggar",
            Description = "Swallows nearby pickups"..
            "#Every 25 pickups: a quality 4 item, then leaves"..
            "#Appears on even floors",
        },
    },
    [3] = {
        id = enums.Slots.Tomorrows_creditor.Variant,
        zh = {
            Name = "来日债主",
            Description = "从来日预支资源，再用未来偿还"..
            "#靠近后左右切换契约，走进确认"..
            "#按{{ButtonRT}}取消",
        },
        en = {
            Name = "Tomorrow's Creditor",
            Description = "Borrow resources from tomorrow and repay them later"..
            "#Switch contracts with left/right, walk in to confirm"..
            "#Press {{ButtonRT}} to cancel",
        },
    },
    [4] = {
        id = enums.Slots.Bloody_Messenger.Variant,
        zh = {
            Name = "血红使者",
            Description = "{{Heart}} 支付一半红心（下取整）"..
            "#奖励随角色状态变化",
        },
        en = {
            Name = "Bloody Messenger",
            Description = "{{Heart}} Pay half your red hearts (floored)"..
            "#Rewards change with the player",
        },
    },
    [5] = {
        id = enums.Slots.Qing_Diamond_Merchant.Variant,
        zh = {
            Name = "钻石收购商",
            Description = "{{Coin}} 靠近后选择出售价格"..
            "#碰触商人完成定价交易"..
            "#按{{ButtonRT}}暂时取消",
        },
        en = {
            Name = "Diamond Merchant",
            Description = "{{Coin}} Choose a sale price nearby"..
            "#Walk into the merchant to confirm the trade"..
            "#Press {{ButtonRT}} to cancel temporarily",
        },
    },
}

item.Masks = {
    [1] = {
        id = 1,
        zh = {
            Name = "邪魔面具",
            Desc = "恶魔的面目",
            Description = "{{DevilRoom}} 至少包含1件来自恶魔房的被动道具 "..
            "#为下个恶魔形态的攻击方式加入硫磺火元素 "..
            "#面具破碎后，翻倍恶魔形态获取的黑心",
        },
        en = {
            Name = "Demonic Mask",
            Desc = "The face of a demon",
            Description = "{{DevilRoom}} Contains at least 1 passive item from the Devil Room"..
            "#Adds a brimstone element to the next demon form attack"..
            "#When the mask breaks, doubles the black hearts gained by demon form",
        },
    },
    [2] = {
        id = 2,
        zh = {
            Name = "天神面具",
            Desc = "天使的面目",
            Description = "{{AngelRoom}} 至少包含1件来自天使房的被动道具 "..
            "#为下个恶魔形态的攻击方式加入圣光元素 "..
            "#面具破碎后，恶魔形态不再消散魂心与白心",
        },
        en = {
            Name = "Divine Mask",
            Desc = "The face of an angel",
            Description = "{{AngelRoom}} Contains at least 1 passive item from the Angel Room"..
            "#Adds a holy light element to the next demon form attack"..
            "#When the mask breaks, demon form no longer dissipates soul hearts or eternal hearts",
        },
    },
    [3] = {
        id = 3,
        zh = {
            Name = "古神面具",
            Desc = "外道的面目",
            Description = "{{SecretRoom}} 至少包含1件来自隐藏房的被动道具 "..
            "#为下个恶魔形态的攻击方式加入触手元素 "..
            "#面具破碎后，下个恶魔形态结束时生成一张额外的古神面具",
        },
        en = {
            Name = "Elder Mask",
            Desc = "The face of an outsider",
            Description = "{{SecretRoom}} Contains at least 1 passive item from the Secret Room"..
            "#Adds a tentacle element to the next demon form attack"..
            "#When the mask breaks, spawns an extra Elder Mask after the next demon form ends",
        },
    },
    [4] = {
        id = 4,
        zh = {
            Name = "混沌面具",
            Desc = "无面的面目",
            Description = "此面具上的所有道具每个房间重置 "..
            "#面具破碎后，生成其上的一个随机道具",
        },
        en = {
            Name = "Chaos Mask",
            Desc = "The faceless face",
            Description = "All items on this mask reroll each room"..
            "#When the mask breaks, spawns one random item from it",
        },
    },
    [5] = {
        id = 5,
        zh = {
            Name = "舞会面具",
            Desc = "热烈的面目",
            Description = "普通的面具",
        },
        en = {
            Name = "Ball Mask",
            Desc = "The fervent face",
            Description = "An ordinary mask",
        },
    },
    [6] = {
        id = 6,
        zh = {
            Name = "乐团面具",
            Desc = "人偶的面目",
            Description = "普通的面具",
        },
        en = {
            Name = "Band Mask",
            Desc = "The puppet face",
            Description = "An ordinary mask",
        },
    },
    [7] = {
        id = 7,
        zh = {
            Name = "狐狸面具",
            Desc = "隐者的面目",
            Description = "面具破碎后，下个生成的面具必定不是普通的面具",
        },
        en = {
            Name = "Fox Mask",
            Desc = "The hermit face",
            Description = "When the mask breaks, the next generated mask is guaranteed to be non-ordinary",
        },
    },
    [8] = {
        id = 8,
        zh = {
            Name = "穿刺面具",
            Desc = "无情的面目",
            Description = "此面具排斥其他面具，佩戴时逐渐消耗其他面具的耐久度 "..
            "#为下个恶魔形态的攻击方式加入穿刺元素 "..
            "#面具破碎后永久+1攻击",
        },
        en = {
            Name = "Piercing Mask",
            Desc = "The merciless face",
            Description = "This mask repels other masks and gradually consumes their durability while worn"..
            "#Adds a piercing element to the next demon form attack"..
            "#When the mask breaks, permanently grants +1 damage",
        },
    },
    [9] = {
        id = 9,
        zh = {
            Name = "贪婪面具",
            Desc = "无谋的面目",
            Description = "此面具附着有4-6个随机道具，但每次失去耐久时损失其中一个道具 "..
            "#为下个恶魔形态的攻击方式加入毁灭元素 "..
            "#面具破碎后，每次进入恶魔形态生成一定数量的基础掉落物",
        },
        en = {
            Name = "Greed Mask",
            Desc = "The reckless face",
            Description = "This mask has 4-6 random items attached, but loses one of them whenever it loses durability"..
            "#Adds a destruction element to the next demon form attack"..
            "#When the mask breaks, entering demon form spawns a number of basic pickups",
        },
    },
    [10] = {
        id = 10,
        zh = {
            Name = "智慧面具",
            Desc = "聪颖的面目",
            Description = "此面具至少包含1个4级道具 "..
            "#为下个恶魔形态的攻击方式加入月光元素 "..
            "#面具破碎后，每次进入恶魔形态时开启本层地图",
        },
        en = {
            Name = "Wisdom Mask",
            Desc = "The clever face",
            Description = "This mask contains at least 1 quality 4 item"..
            "#Adds a moonlight element to the next demon form attack"..
            "#When the mask breaks, entering demon form reveals the map for this floor",
        },
    },
    [11] = {
        id = 11,
        zh = {
            Name = "增生面具",
            Desc = "本我的面目",
            Description = "此面具失去耐久时损失其中一个道具，但会随时间自然修复并填充新道具 "..
            "#增强下个恶魔形态的攻击 "..
            "#面具破碎后，保留其他面具并立刻进入恶魔形态",
        },
        en = {
            Name = "Proliferation Mask",
            Desc = "The face of the id",
            Description = "This mask loses one attached item when it loses durability, but naturally repairs over time and fills itself with new items"..
            "#Strengthens the next demon form attack"..
            "#When the mask breaks, keeps the other masks and immediately enters demon form",
        },
    },
    [12] = {
        id = 12,
        zh = {
            Name = "阴云面具",
            Desc = "抑郁的面目",
            Description = "此面具随时间逐渐失去耐久度",
        },
        en = {
            Name = "Gloom Mask",
            Desc = "The depressed face",
            Description = "This mask gradually loses durability over time",
        },
    },
    [13] = {
        id = 13,
        zh = {
            Name = "微笑面具",
            Desc = "狡诈的面目",
            Description = "此面具包含2-4个重复道具",
        },
        en = {
            Name = "Smile Mask",
            Desc = "The cunning face",
            Description = "This mask contains 2-4 duplicate items",
        },
    },
}

item.Room = {
    [1] = {
        id = "DESERVED SINS",
        zh = {
            Name = "罪有应得",
        },
        en = {
            Name = "Deserved Sins",
        },
    },
    [2] = {
        id = "DESIRED SINS",
        zh = {
            Name = "欲加之罪",
        },
        en = {
            Name = "Desired Sins",
        },
    },
    [3] = {
        id = "DOUBLE SINS",
        zh = {
            Name = "罪加一等",
        },
        en = {
            Name = "Double Sins",
        },
    },
    [4] = {
        id = "MULTIPLE SINS",
        zh = {
            Name = "数罪并罚",
        },
        en = {
            Name = "Multiple Sins",
        },
    },
    [5] = {
        id = "SUSPECTED SINS",
        zh = {
            Name = "疑罪从无",
        },
        en = {
            Name = "Suspected Sins",
        },
    },
    [6] = {
        id = "UNKNOWN SINS",
        zh = {
            Name = "不知者无罪",
        },
        en = {
            Name = "Unknown Sins",
        },
    },
}

item.Level = {
    [1] = {
        id = "Chasm",
        zh = {
            Name = "阴影裂口",
            Description = "",
        },
        en = {
            Name = "Chasm",
            Description = "",
        },
    },
    [2] = {
        id = "Profound",
        zh = {
            Name = "深瞳",
            Description = "",
        },
        en = {
            Name = "Profound",
            Description = "",
        },
    },
    [3] = {
        id = "The Realms",
        zh = {
            Name = "他界",
            Description = "",
        },
        en = {
            Name = "The Realms",
            Description = "",
        },
    },
}

local sectionMap = {
    Collectibles = {langKey = "Collectibles"},
    Trinkets = {langKey = "Trinkets"},
    Cards = {langKey = "Cards"},
    Players = {langKey = "Players"},
    Birthrights = {langKey = "Birthrights"},
    Challenges = {langKey = "Challenges"},
}

for section, map in pairs(sectionMap) do
    item.Reverse[section] = {}
    item.en[map.langKey] = {}
    item.zh[map.langKey] = {}
    for index, info in ipairs(item[section] or {}) do
        if type(info.id) == "number" and info.id > 0 then
            item.Reverse[section][info.id] = index
            if info.en then item.en[map.langKey][info.id] = info.en end
            if info.zh then item.zh[map.langKey][info.id] = info.zh end
        end
    end
end

for _, section in ipairs({"Slots", "Masks"}) do
    item.en[section] = {}
    item.zh[section] = {}
    for index, info in ipairs(item[section] or {}) do
        if info.id ~= nil then
            if info.en then item.en[section][info.id] = info.en end
            if info.zh then item.zh[section][info.id] = info.zh end
        end
    end
end

item.en.Pickups = {}
item.zh.Pickups = {}
item.en.PickupByKey = {}
item.zh.PickupByKey = {}
for index, info in ipairs(item.Pickups or {}) do
    local base = {Variant = info.Variant, SubType = info.SubType}
    if info.pseudoPickup and info.pickupKey then
        if info.zh then
            item.zh.PickupByKey[info.pickupKey] = {Variant = base.Variant, SubType = base.SubType}
            for key, value in pairs(info.zh) do item.zh.PickupByKey[info.pickupKey][key] = value end
        end
        if info.en then
            item.en.PickupByKey[info.pickupKey] = {Variant = base.Variant, SubType = base.SubType}
            for key, value in pairs(info.en) do item.en.PickupByKey[info.pickupKey][key] = value end
        end
    else
        if info.en then
            item.en.Pickups[index] = {Variant = base.Variant, SubType = base.SubType}
            for key, value in pairs(info.en) do item.en.Pickups[index][key] = value end
        end
        if info.zh then
            item.zh.Pickups[index] = {Variant = base.Variant, SubType = base.SubType}
            for key, value in pairs(info.zh) do item.zh.Pickups[index][key] = value end
        end
    end
end

function item.get_pickup_by_key(key, languageCode)
    if not key then return nil end
    local bucket = (languageCode == "zh_cn" or languageCode == "zh") and item.zh or item.en
    return bucket.PickupByKey and bucket.PickupByKey[key]
end

function item.get_player_start_guide(player_id, languageCode)
    if not player_id then return nil end
    local bucket = (languageCode == "zh_cn" or languageCode == "zh" or languageCode == "zh_tw") and item.zh or item.en
    local info = bucket.Players and bucket.Players[player_id]
    local guide = info and info.StartGuide
    if guide and guide.Name and guide.Description then return guide end
    return nil
end

item.en.Room = {}
item.zh.Room = {}
for _, info in ipairs(item.Room or {}) do
    if info.id ~= nil then
        if info.en and info.en.Name then item.en.Room[info.id] = info.en.Name end
        if info.zh and info.zh.Name then item.zh.Room[info.id] = info.zh.Name end
    end
end

item.en.Level = {}
item.zh.Level = {}
for _, info in ipairs(item.Level or {}) do
    if info.id ~= nil then
        if info.en then item.en.Level[info.id] = info.en end
        if info.zh then item.zh.Level[info.id] = info.zh end
    end
end

item.en_us = item.en
item.zh_cn = item.zh
item.en.Challanges = item.en.Challenges
item.zh.Challanges = item.zh.Challenges

item.en.CollectibleTransformations = {
    [Items.Darkness] = "9",
    [Items.Glaze_Mushroom] = "2",
    [Items.Mental_Hypnosis] = "5",
	[Items.Tianyi] = "4",
    [Items.Devil_s_Heart] = "9",
    [Items.Book_of_Future] = "12",
    [Items.Book_of_Thoth] = "12",
    [Items.Book_of_The_Law] = "12",
    [Items.Book_of_Vision] = "12",
    [Items.Book_of_Voice] = "12",
    [Items.Book_of_Rune] = "12",
    [Items.Book_of_6_sin] = "12",
    [Items.Muscae_Volitantes] = "3",
    [Items.Cup_Cat] = "1",
}

item.zh.CollectibleTransformations = {
    [Items.Darkness] = "9",
    [Items.Glaze_Mushroom] = "2",
    [Items.Mental_Hypnosis] = "5",
	[Items.Tianyi] = "4",
    [Items.Devil_s_Heart] = "9",
    [Items.Book_of_Future] = "12",
    [Items.Book_of_Thoth] = "12",
    [Items.Book_of_The_Law] = "12",
    [Items.Book_of_Vision] = "12",
    [Items.Book_of_Voice] = "12",
    [Items.Book_of_Rune] = "12",
    [Items.Book_of_6_sin] = "12",
    [Items.Muscae_Volitantes] = "3",
    [Items.Cup_Cat] = "1",
}

item.zh.PlayerSync = {
	[enums.Players.wq] = {
		[CollectibleType.COLLECTIBLE_DR_FETUS] = {Description = "小刀命中敌人后引发爆炸"..
		    "#攻击策略变化",},
		[CollectibleType.COLLECTIBLE_TECHNOLOGY] = {Description = "科技刀刃"..
		    "#攻击策略变化",},
		[CollectibleType.COLLECTIBLE_MOMS_KNIFE] = {Description = "小刀刺入敌人后持续造成大量伤害"..
		    "#攻击策略变化",},
		[CollectibleType.COLLECTIBLE_BRIMSTONE] = {Description = "攻击间隙发射出附着硫磺火的飞刀"..
		    "#攻击策略变化",},
		[CollectibleType.COLLECTIBLE_EPIC_FETUS] = {Description = "飞刀命中目标后导弹落下"..
		    "#攻击策略变化",},
		[CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE] = {Description = "生成一个小青宝宝发出小刀进行战斗"..
		    "#距离较远时，可以将小青宝宝作为瞬移目标",},
		[CollectibleType.COLLECTIBLE_TECH_X] = {Description = "与科技光圈配合攻击"..
		    "#攻击策略变化",},
		[CollectibleType.COLLECTIBLE_MONSTROS_LUNG] = {Description = "攻击策略变化"..
		    "#不引起属性变化",},
		[CollectibleType.COLLECTIBLE_HAEMOLACRIA] = {Description = "发射大型飞刀"..
		    "#飞刀可以扎在墙上"..
		    "#攻击策略变化",},
		[CollectibleType.COLLECTIBLE_SPIRIT_SWORD] = {Description = "攻击策略变化",},
		[CollectibleType.COLLECTIBLE_C_SECTION] = {Description = "小刀攻击结束后变为小青宝宝，操纵飞刀攻击敌人"..
		    "#攻击策略变化",},
		
		[CollectibleType.COLLECTIBLE_IPECAC] = {Description = "飞刀命中敌人后引发爆炸"..
		    "#属性变化改为与持有妈刀时相同",},
		[CollectibleType.COLLECTIBLE_TECHNOLOGY_2] = {Description = "额外进行科技刀刃刺击",},
		[CollectibleType.COLLECTIBLE_TECH_5] = {Description = "概率发射带有随机科技尾部的小刀",},
		[CollectibleType.COLLECTIBLE_CURSED_EYE] = {Description = "可以连续攻击至多5次，但攻击的延迟将累计并在结束后计算"..
		    "#攻击时受伤会传送",},
		[CollectibleType.COLLECTIBLE_FRUIT_CAKE] = {Description = "20%概率变化出随机攻击策略",},
		[CollectibleType.COLLECTIBLE_3_DOLLAR_BILL] = {Description = "每一轮随机你的攻击策略",},
		[CollectibleType.COLLECTIBLE_MISSING_NO] = {Description = "每一发小刀都是全随机攻击策略",},
		
		[CollectibleType.COLLECTIBLE_CHOCOLATE_MILK] = {Description = "不攻击时自动蓄力"..
		    "#蓄力状态下一击伤害达到0-200%",},
		[CollectibleType.COLLECTIBLE_LEAD_PENCIL] = {Description = "15次出刀后下一次出刀数量增多",},
		--[enums.Items.Touchstone] = {Description = "使用后，本房间内改用青的刀击攻击方式",},
		[CollectibleType.COLLECTIBLE_TECHNOLOGY_ZERO] = {Description = "落地的飞刀一直停留，直到向下一把飞刀射出激光",},
		
		[CollectibleType.COLLECTIBLE_LEMON_MISHAP] = {Description = "小刀变成柠檬水瓶"..
		    "#飞刀落地后概率碎裂",},
		[CollectibleType.COLLECTIBLE_FREE_LEMONADE] = {Description = "小刀变成柠檬水瓶"..
		    "#飞刀落地后概率碎裂",},
		[CollectibleType.COLLECTIBLE_DAMOCLES] = {Description = "小刀变成达摩剑"..
		    "#击杀生命低于10%的敌人",},
		[CollectibleType.COLLECTIBLE_PARASITE] = {Description = "小刀命中敌人后分裂两发小型小刀",},
		[CollectibleType.COLLECTIBLE_CRICKETS_BODY] = {Description = "飞刀命中敌人后四向发射小型飞刀",},
		[CollectibleType.COLLECTIBLE_COMPOUND_FRACTURE] = {Description = "小刀命中敌人后随机方向发射小型小刀",},
		[CollectibleType.COLLECTIBLE_LUMP_OF_COAL] = {Description = "小刀伤害随生成时间变大",},
		[CollectibleType.COLLECTIBLE_PROPTOSIS] = {Description = "小刀伤害随生成时间变小",},
		[CollectibleType.COLLECTIBLE_POLYPHEMUS] = {Description = "小刀大幅变大",},
		[CollectibleType.COLLECTIBLE_SOY_MILK] = {Description = "小刀大幅变小",},
		[CollectibleType.COLLECTIBLE_ALMOND_MILK] = {Description = "小刀大幅变小",},
		[CollectibleType.COLLECTIBLE_LOST_CONTACT] = {Description = "斩飞弹幕",},
		[CollectibleType.COLLECTIBLE_LIBRA] = {Description = "阴阳小刀"..
		    "#阴阳刀都命中敌人后产生3轮爆炸",},
		[CollectibleType.COLLECTIBLE_DUALITY] = {Description = "阴阳小刀"..
		    "#阴阳刀都命中敌人后，会产生3轮爆炸",},
		[CollectibleType.COLLECTIBLE_AQUARIUS] = {Description = "海洋小刀"..
		    "#额外有概率留下水迹",},
		[CollectibleType.COLLECTIBLE_GODHEAD] = {Description = "飞刀命中敌人后产生惩戒光圈",},
		[CollectibleType.COLLECTIBLE_TRACTOR_BEAM] = {Description = "小刀不受收束光线限制",},
		[CollectibleType.COLLECTIBLE_EYE_OF_BELIAL] = {Description = "小刀穿过敌人后生成跟踪红色飞刀",},
		[CollectibleType.COLLECTIBLE_SULFURIC_ACID] = {Description = "小刀可以破坏石头与门",},
		[CollectibleType.COLLECTIBLE_JACOBS_LADDER] = {Description = "飞刀发动电击攻击敌人",},
		[CollectibleType.COLLECTIBLE_GHOST_PEPPER] = {Description = "有概率生成火焰小刀造成3倍伤害",},
		[CollectibleType.COLLECTIBLE_BIRDS_EYE] = {Description = "有概率生成火焰小刀造成2倍伤害",},
		[CollectibleType.COLLECTIBLE_BACKSTABBER] = {Description = "瞬移方式改为影遁闪击",},
		[enums.Items.Assassin_s_Eye] = {Description = "瞬移方式改为影遁闪击",},
		[CollectibleType.COLLECTIBLE_TRISAGION] = {Description = "雪光小刀，提升造成的伤害",},
		[CollectibleType.COLLECTIBLE_EYE_OF_THE_OCCULT] = {Description = "可以控制小刀的飞行方向",},
		[CollectibleType.COLLECTIBLE_TERRA] = {Description = "石中小刀，可以破坏石头、石头箱子与门",},
		[CollectibleType.COLLECTIBLE_URANUS] = {Description = "冰锥小刀，冰冻伤害到的敌人",},
		--[CollectibleType.COLLECTIBLE_MY_REFLECTION] = {Description = "瞬移方式改为镜面闪击",},
		--[CollectibleType.COLLECTIBLE_ANTI_GRAVITY] = {Description = "飞刀悬停在空中",},
		--[CollectibleType.COLLECTIBLE_TINY_PLANET] = {Description = "飞刀会旋转",},
		--[CollectibleType.COLLECTIBLE_FINGER] = {Description = "指尖小刀",},
		--[CollectibleType.COLLECTIBLE_PLAN_C] = {Description = "立即获得血色小刀",},
	},
	[enums.Players.Tecro] = {
		[CollectibleType.COLLECTIBLE_DR_FETUS] = {Description = "主攻击：蓄力后从枪头发射炸弹"..
		    "#副攻击：改为发射小炸弹",},
		[CollectibleType.COLLECTIBLE_MOMS_KNIFE] = {Description = "主攻击：蓄力后从枪头发射若干妈刀"..
		    "#副攻击：飞出妈刀数量减少，距离降低"..
		    "#穿刺数量+2"..
		    "#持有且拥有妈妈套：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_SPIRIT_SWORD] = {Description = "主攻击：蓄力后从枪头挥剑一周"..
		    "#副攻击：改为挥剑半周，伤害降低"..
		    "#穿刺持续时长+3s",},
		[CollectibleType.COLLECTIBLE_BRIMSTONE] = {Description = "主攻击：蓄力后从枪头发射硫磺火"..
		    "#副攻击：改为发射短硫磺火",},
		[CollectibleType.COLLECTIBLE_TECHNOLOGY_2] = {Description = "蓄力后从枪头发射持续的科技束线",},
		[CollectibleType.COLLECTIBLE_TECHNOLOGY] = {Description = "主攻击：蓄力后从枪头发射一道科技束线"..
		    "#副攻击：束线伤害降低",},
		[CollectibleType.COLLECTIBLE_EPIC_FETUS] = {Description = "主攻击：蓄力后从枪头发射大型导弹"..
		    "#副攻击：改为发射小型导弹",},
		[CollectibleType.COLLECTIBLE_TECH_X] = {Description = "主攻击：蓄力后从枪头生成科技激光圈，收枪时将激光圈发射"..
		    "#副攻击：激光圈的范围、伤害降低",},
		[CollectibleType.COLLECTIBLE_C_SECTION] = {Description = "主攻击：从长枪上生成6根飞针自动穿刺、捕获敌人"..
		    "#副攻击：飞针数量减为2根",},
		[CollectibleType.COLLECTIBLE_ANTI_GRAVITY] = {Description = "每蓄力达到5倍攻击延迟，设立一束悬浮长枪",},
		[CollectibleType.COLLECTIBLE_CHOCOLATE_MILK] = {Description = "蓄力上限达到2倍"..
		    "#2倍上限时有特殊效果",},
		[CollectibleType.COLLECTIBLE_MONSTROS_LUNG] = {Description = "改为向多个随机方向额外出枪（类似妈刀的配合）"..
		    "#不引起属性变化",},
		[CollectibleType.COLLECTIBLE_TINY_PLANET] = {Description = "穿刺持续时长+1s"..
		    "#长枪向一个方向旋转",},
		[CollectibleType.COLLECTIBLE_CURSED_EYE] = {Description = "蓄力后可以五连发出枪",},
		[CollectibleType.COLLECTIBLE_EYE_OF_GREED] = {Description = "10次出枪后发射黄金长枪",},
		[CollectibleType.COLLECTIBLE_SOY_MILK] = {Description = "附加的主、副攻击持续时间大幅提升或改为无限长，或是攻击数目额外增加",},
		[CollectibleType.COLLECTIBLE_ALMOND_MILK] = {Description = "附加的主、副攻击持续时间大幅提升或改为无限长，或是攻击数目额外增加",},
		[CollectibleType.COLLECTIBLE_MAW_OF_VOID] = {Description = "蓄力后从枪头发射伤害较低的黑圈",},
		[CollectibleType.COLLECTIBLE_TWISTED_PAIR] = {Description = "双生宝追随长枪而不是角色",},
		[CollectibleType.COLLECTIBLE_TRISAGION] = {Description = "蓄力后从枪头发射三圣颂",},
		[CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE] = {Description = "悬浮长枪，按"..eidButton(ButtonAction and ButtonAction.ACTION_SHOOTDOWN).."以收回长枪",},
		[CollectibleType.COLLECTIBLE_IPECAC] = {Description = "出枪后引发2倍角色伤害的安全的爆炸"..
		    "#长枪与敌人碰撞引起1倍伤害的安全的爆炸"..
		    "#属性变化改为与持有妈刀时相同",},
		[CollectibleType.COLLECTIBLE_TECHNOLOGY_ZERO] = {Description = "长枪枪尖附着相互链接的激光",},
		[CollectibleType.COLLECTIBLE_GODHEAD] = {Description = "枪尖附着有神性光辉，对周围敌人造成每5帧10%角色攻击的伤害",},
		[enums.Items.Assassin_s_Eye] = {Description = "出枪后使敌人受到暗杀",},
		[CollectibleType.COLLECTIBLE_THE_WIZ] = {Description = "主枪不会受影响而偏移角度"..
		    "#穿刺持续时长+1s",},
		[CollectibleType.COLLECTIBLE_NEPTUNUS] = {Description = "出枪后自动蓄力，至多蓄满50%",},
		[CollectibleType.COLLECTIBLE_MY_REFLECTION] = {Description = "向一个方向挥枪时会逐渐减速且反向",},
		[CollectibleType.COLLECTIBLE_EYE_OF_THE_OCCULT] = {Description = "主枪拥有三个灵能环绕眼泪，造成角色攻击1/3的伤害",},
		[CollectibleType.COLLECTIBLE_EYE_OF_BELIAL] = {Description = "主枪命中第一个敌人后从它所在的位置再出一发红色隐枪"..
		    "#穿刺数量+2",},	
		
		[CollectibleType.COLLECTIBLE_SACRIFICIAL_DAGGER] = {Description = "穿刺数量+1"..
		    "#作为枪尖：向外发射会修正一次弹道的献祭匕首",},	--
		[CollectibleType.COLLECTIBLE_SACRIFICIAL_ALTAR] = {Description = "作为枪尖：向外发射会修正一次弹道的献祭匕首",},
		[CollectibleType.COLLECTIBLE_GUILLOTINE] = {Description = "受伤后：穿刺数量+1",},		--作为枪尖：将一部分敌人头身分离
		[CollectibleType.COLLECTIBLE_BACKSTABBER] = {Description = "幸运高于5：穿刺数量+1",},	--
		[CollectibleType.COLLECTIBLE_BLOOD_OATH] = {Description = "攻击高于10：穿刺数量+1"..
		    "#作为枪尖：对第一个命中的敌人抽取其10%生命值，不高于角色攻击的5倍 "..
		    "#有概率抽取并生成一个快速消失的半红心",},
		[CollectibleType.COLLECTIBLE_SANGUINE_BOND] = {Description = "魂心数不高于2格：穿刺数量+1 "..
		    "#作为枪尖：在敌人脚下生成地刺，对在地面型敌人造成范围伤害",},
		[CollectibleType.COLLECTIBLE_KAMIKAZE] = {Description = "作为枪尖：使用此主动后同时引爆枪尖",},
		[CollectibleType.COLLECTIBLE_SALVATION] = {Description = "作为枪尖：枪尖附着有救济光辉，对范围内敌人降下小型圣光",},
		[CollectibleType.COLLECTIBLE_HOLY_LIGHT] = {Description = "作为枪尖：枪尖附着有救济光辉，对范围内敌人降下小型圣光",},
		[CollectibleType.COLLECTIBLE_URN_OF_SOULS] = {Description = "作为枪尖：出枪时有概率发出大量蓝火，但伤害较低",},
		[CollectibleType.COLLECTIBLE_CENSER] = {Description = "作为枪尖：对周围敌人施加减速",},
		[CollectibleType.COLLECTIBLE_MOMS_LIPSTICK] = {Description = "作为枪尖：概率染红敌人"..
		    "#对染为红色的敌人造成伤害更高",},
		[CollectibleType.COLLECTIBLE_DAMOCLES] = {Description = "作为枪尖：达摩剑将击杀生命低于10%的敌人",},
		[CollectibleType.COLLECTIBLE_MOMS_RAZOR] = {Description = "作为枪尖：概率附加1s流血特效"..
		    "#持有且拥有妈妈套：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_DEATHS_TOUCH] = {Description = "作为枪尖：镰刀尖端也能造成伤害",},
		[CollectibleType.COLLECTIBLE_MOMS_HEELS] = {Description = "作为枪尖：鞋尖端也能造成伤害",},
		[CollectibleType.COLLECTIBLE_ATHAME] = {Description = "受伤后：穿刺数量+1"..
		    "#作为枪尖：概率额外从枪头发射黑圈",},
		[CollectibleType.COLLECTIBLE_STAR_OF_BETHLEHEM] = {Description = "作为枪尖：蓄力后发射一颗星星子弹，造成角色攻击2倍的伤害，继承眼泪特效",},
		[CollectibleType.COLLECTIBLE_SMB_SUPER_FAN] = {Description = "血上限高于3：穿刺数量+1"..
		    "#作为枪尖：长枪的基础伤害增加角色面板的10%",},
		
		[CollectibleType.COLLECTIBLE_VENUS] = {Description = "持有且使用塞壬枪尖：枪尖的魅惑光环扩大，魅惑必然发生",},
		[CollectibleType.COLLECTIBLE_HEAD_OF_KRAMPUS] = {Description = "持有且使用坎普斯枪尖：出枪时概率发射四向（可能旋转）硫磺火",},
		
		[CollectibleType.COLLECTIBLE_VIRUS] = {Description = "针套：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_ROID_RAGE] = {Description = "针套：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_CUPIDS_ARROW] = {Description = "穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_GROWTH_HORMONES] = {Description = "针套：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_THE_NAIL] = {Description = "使用后，本房间内：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_PINKING_SHEARS] = {Description = "使用后，本房间内穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_OUIJA_BOARD] = {Description = "穿刺持续时长+1s",},
		[CollectibleType.COLLECTIBLE_RAZOR_BLADE] = {Description = "使用后，本房间内：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_IV_BAG] = {Description = "没有红心：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_SPEED_BALL] = {Description = "针套：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_SPIRIT_OF_THE_NIGHT] = {Description = "穿刺持续时长+1s",},
		[CollectibleType.COLLECTIBLE_POLYPHEMUS] = {Description = "穿刺数量大于2：穿刺数量+2",},
		[CollectibleType.COLLECTIBLE_DEAD_DOVE] = {Description = "穿刺持续时长+1s",},
		[CollectibleType.COLLECTIBLE_BLOOD_RIGHTS] = {Description = "使用后，本房间内：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_SHARP_PLUG] = {Description = "未满充能：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_DEATHS_TOUCH] = {Description = "穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_EXPERIMENTAL_TREATMENT] = {Description = "针套：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_SCREW] = {Description = "攻速高于5：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_SAGITTARIUS] = {Description = "穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_SCISSORS] = {Description = "使用后，本房间内：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_DEAD_ONION] = {Description = "穿刺数量+1"..
		    "#穿刺持续时长",},
		[CollectibleType.COLLECTIBLE_SAFETY_PIN] = {Description = "弹速高于2：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_8_INCH_NAILS] = {Description = "攻击高于10：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_CONTINUUM] = {Description = "穿刺持续时长+1s",},
		[CollectibleType.COLLECTIBLE_PUPULA_DUPLEX] = {Description = "穿刺持续时长+1s",},
		[CollectibleType.COLLECTIBLE_SPEAR_OF_DESTINY] = {Description = "穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_SHARD_OF_GLASS] = {Description = "受伤后：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_FINGER] = {Description = "攻击高于10：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_ADRENALINE] = {Description = "针套：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_EUTHANASIA] = {Description = "针套：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_POINTY_RIB] = {Description = "幸运高于5：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_GOLDEN_RAZOR] = {Description = "使用后，本房间内：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_DAMOCLES] = {Description = "穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_DAMOCLES_PASSIVE] = {Description = "穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_SHARP_KEY] = {Description = "穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_KNIFE_PIECE_2] = {Description = "穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_MEAT_CLEAVER] = {Description = "使用后，本房间内：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_TOOTH_AND_NAIL] = {Description = "穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_DARK_ARTS] = {Description = "移速高于1.7：穿刺数量+1",},
		[CollectibleType.COLLECTIBLE_STAPLER] = {Description = "穿刺数量+1",},
	},
	[enums.Players.Tecrorun] = {
		[CollectibleType.COLLECTIBLE_DR_FETUS] = {Description = "瞬移过程中在敌人处与墙边留下炸弹",},
		[CollectibleType.COLLECTIBLE_MOMS_KNIFE] = {Description = "将瞬移过程中碰到的敌人穿刺并在结束后用刀扎在墙上",},
		[CollectibleType.COLLECTIBLE_SPIRIT_SWORD] = {Description = "瞬移时额外挥剑斩击敌人",},
		[CollectibleType.COLLECTIBLE_BRIMSTONE] = {Description = "瞬移时身后留下硫磺火轨迹",},
		[CollectibleType.COLLECTIBLE_TECHNOLOGY] = {Description = "瞬移时在光路的夹角间发射5发激光",},
		[CollectibleType.COLLECTIBLE_EPIC_FETUS] = {Description = "瞬移时在墙边与敌人处落下导弹",},
		[CollectibleType.COLLECTIBLE_TECH_X] = {Description = "瞬移时身后留下科技激光圈",},
		--[CollectibleType.COLLECTIBLE_MAW_OF_VOID] = {Description = "瞬移时在角色周围生成黑色硫磺火圈",},
		[CollectibleType.COLLECTIBLE_C_SECTION] = {Description = "生成6个伴生针刺，瞬移时额外穿刺敌人",},
		[CollectibleType.COLLECTIBLE_MONSTROS_LUNG] = {Description = "攻击时生成数道随机方向攻击的幻影",},
		[CollectibleType.COLLECTIBLE_HAEMOLACRIA] = {Description = "最后一段攻击后生成数道随机方向攻击的幻影",},
		
		[CollectibleType.COLLECTIBLE_CURSED_EYE] = {Description = "蓄力上限提高4倍",},
		--[CollectibleType.COLLECTIBLE_SOY_MILK] = {Description = "额外连续发射沿轨迹移动的残影",},
		--[CollectibleType.COLLECTIBLE_ALMOND_MILK] = {Description = "额外连续发射沿轨迹移动的残影",},
		[CollectibleType.COLLECTIBLE_TRISAGION] = {Description = "瞬移时身后留下三圣颂"..
		    "#将瞬移过程中碰到的敌人吸到三圣颂上",},
		[CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE] = {Description = "悬浮长枪，按"..eidButton(ButtonAction and ButtonAction.ACTION_DROP).."以收回长枪",},
		[CollectibleType.COLLECTIBLE_IPECAC] = {Description = "瞬移过程中在敌人处与墙边引发爆炸"..
		    "#生成瞄准激光时在末端发生爆炸",},
		
		[CollectibleType.COLLECTIBLE_THE_WIZ] = {Description = "不受偏移角度影响，而是概率单发或多发",},
		[CollectibleType.COLLECTIBLE_TECHNOLOGY_ZERO] = {Description = "长枪枪尖附着相互链接的激光",},
		[CollectibleType.COLLECTIBLE_ANTI_GRAVITY] = {Description = "每蓄力达到2倍攻击延迟，生成一份残影",},
		[CollectibleType.COLLECTIBLE_CHOCOLATE_MILK] = {Description = "蓄力上限提高1倍",},
		[CollectibleType.COLLECTIBLE_RUBBER_CEMENT] = {Description = "向法线方向额外发射一条光束",},
		[CollectibleType.COLLECTIBLE_CONTINUUM] = {Description = "攻击从屏幕外额外重复一次",},
		[CollectibleType.COLLECTIBLE_TECHNOLOGY_2] = {Description = "瞄准线含有一道科技束线",},
		[CollectibleType.COLLECTIBLE_TINY_PLANET] = {Description = "长枪向一个方向旋转",},
		[CollectibleType.COLLECTIBLE_MY_REFLECTION] = {Description = "向后发射激光",},
		[CollectibleType.COLLECTIBLE_PROPTOSIS] = {Description = "每次弹射时伤害从200%开始衰减",},
		[CollectibleType.COLLECTIBLE_LUMP_OF_COAL] = {Description = "每次弹射时伤害从30%开始递增",},
		[CollectibleType.COLLECTIBLE_ANGELIC_PRISM] = {Description = "穿过棱镜的激光生成4条激光束",},
		[CollectibleType.COLLECTIBLE_EYE_OF_BELIAL] = {Description = "首次命中时额外生成带跟踪的红色幻影",},
		[CollectibleType.COLLECTIBLE_EYE_OF_GREED] = {Description = "每5次攻击消耗1块钱并额外生成金色幻影",},
		--[CollectibleType.COLLECTIBLE_PARASITE] = {Description = "",},
		[CollectibleType.COLLECTIBLE_MULTIDIMENSIONAL_BABY] = {Description = "穿过多维宝宝的激光生成2条激光束",},
		--[Items.Illumination] = {Description = "使用后不消耗，自动置入副手#独特的开掘效果",},
		
	},
	[enums.Players.Anna] = {
		[CollectibleType.COLLECTIBLE_DR_FETUS] = {Description = "发射物额外包含一枚炸弹",},
		[CollectibleType.COLLECTIBLE_MOMS_KNIFE] = {Description = "发射物由数柄妈刀环绕",},
		[CollectibleType.COLLECTIBLE_SPIRIT_SWORD] = {Description = "发射物由宝剑护卫",},
		[CollectibleType.COLLECTIBLE_BRIMSTONE] = {Description = "额外发射硫磺火",},
		[CollectibleType.COLLECTIBLE_TECHNOLOGY] = {Description = "抛射物向前方发射激光",},
		[CollectibleType.COLLECTIBLE_EPIC_FETUS] = {Description = "抛射物落地后留下导弹标靶",},
		[CollectibleType.COLLECTIBLE_TECH_X] = {Description = "抛射物获得科技激光圈",},
		[CollectibleType.COLLECTIBLE_C_SECTION] = {Description = "抛射物获得剖腹产宝宝的特性",},
		[CollectibleType.COLLECTIBLE_MONSTROS_LUNG] = {Description = "额外抛射大量眼泪",},		--不引起属性变化
		[CollectibleType.COLLECTIBLE_TECHNOLOGY_2] = {Description = "蓄力时发射科技束线",},
		[CollectibleType.COLLECTIBLE_MAW_OF_VOID] = {Description = "抛射物获得黑色激光圈",},
		[CollectibleType.COLLECTIBLE_ATHAME] = {Description = "抛射物获得黑色激光圈",},
		[CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE] = {Description = "黑洞悬浮在空中自由移动"..
		    "#按 "..eidButton(ButtonAction and ButtonAction.ACTION_DROP).." 收回",},
		[CollectibleType.COLLECTIBLE_IPECAC] = {Description = "抛射物碰撞时发生爆炸",},
		
		[CollectibleType.COLLECTIBLE_CHOCOLATE_MILK] = {Description = "2倍蓄力长度"..
		    "#可以随时发射",},
		[CollectibleType.COLLECTIBLE_CURSED_EYE] = {Description = "连续抛出至多5发抛射物",},
		[CollectibleType.COLLECTIBLE_INNER_EYE] = {Description = "额外+0.5倍伤害",},
		[CollectibleType.COLLECTIBLE_MUTANT_SPIDER] = {Description = "额外+0.25倍伤害",},
		[CollectibleType.COLLECTIBLE_20_20] = {Description = "额外+1倍伤害",},
		[CollectibleType.COLLECTIBLE_TERRA] = {Description = "可以吸入障碍物",},
		[CollectibleType.COLLECTIBLE_MEGA_MUSH] = {Description = "巨化状态可以吸入障碍物",},
		[CollectibleType.COLLECTIBLE_DIRTY_MIND] = {Description = "可以吸入便便",},
		[CollectibleType.COLLECTIBLE_MARKED] = {Description = "向准星的方向射击",},
		[CollectibleType.COLLECTIBLE_SOY_MILK] = {Description = "可以随时发射",},
		[CollectibleType.COLLECTIBLE_ALMOND_MILK] = {Description = "可以随时发射",},
		[CollectibleType.COLLECTIBLE_NEPTUNUS] = {Description = "蓄力50%以上即可发射",},
		[CollectibleType.COLLECTIBLE_BLACK_HOLE] = {Description = "黑洞与手持黑洞相通",},
		[CollectibleType.COLLECTIBLE_ANTI_GRAVITY] = {Description = "只保留射速修正",},
		[CollectibleType.COLLECTIBLE_TECHNOLOGY_ZERO] = {Description = "黑洞与抛掷物间由电弧连接",},
		[CollectibleType.COLLECTIBLE_EYE_SORE] = {Description = "额外向其他方向发射普通眼泪",},
		[enums.Items.Calamity] = {Description = "正常充能，自动置入副手"..
		    "#独特的毁灭效果",},
	},
	[enums.Players.annA] = {
		[CollectibleType.COLLECTIBLE_DR_FETUS] = {Description = "额外扔下炸弹攻击目标位置",},
		[CollectibleType.COLLECTIBLE_MOMS_KNIFE] = {Description = "发射3把妈刀自动跟踪敌人，落地后释放飞刀",},
		[CollectibleType.COLLECTIBLE_SPIRIT_SWORD] = {Description = "额外快速斩击目标位置3次",},
		[CollectibleType.COLLECTIBLE_BRIMSTONE] = {Description = "引导硫磺火轰击目标位置",},
		[CollectibleType.COLLECTIBLE_TECHNOLOGY] = {Description = "向四周发射激光",},
		[CollectibleType.COLLECTIBLE_EPIC_FETUS] = {Description = "携带巨型导弹一同落下",},
		[CollectibleType.COLLECTIBLE_TECH_X] = {Description = "轰击时留下科技光环",},
		[CollectibleType.COLLECTIBLE_C_SECTION] = {Description = "留下小飞蛾攻击敌人",},
		[CollectibleType.COLLECTIBLE_MONSTROS_LUNG] = {Description = "额外攻击数个位置"..
		    "#未完全蓄力也可以攻击",},
		[CollectibleType.COLLECTIBLE_TECHNOLOGY_2] = {Description = "蓄力的时候向目标位置发射激光",},
		[CollectibleType.COLLECTIBLE_MAW_OF_VOID] = {Description = "落地时生成黑色激光环",},
		[CollectibleType.COLLECTIBLE_ATHAME] = {Description = "落地时生成黑色激光环",},
		[CollectibleType.COLLECTIBLE_DEATHS_TOUCH] = {Description = "第一击前额外用镰刀向目标位置斩击",},
		[CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE] = {Description = "只用幻影轰炸目标位置"..
		    "#不自动收回准星",},
		[CollectibleType.COLLECTIBLE_IPECAC] = {Description = "额外引爆目标位置",},
		[CollectibleType.COLLECTIBLE_TRISAGION] = {Description = "攻击时额外引导三圣颂落下",},
		
		[CollectibleType.COLLECTIBLE_SPOON_BENDER] = {Description = "自动攻击目标周围的敌人",},
		[CollectibleType.COLLECTIBLE_CONTINUUM] = {Description = "一击结束前按住攻击键可以重复上一攻击"..
		    "#每个此道具一次攻击可触发一次",},
		[CollectibleType.COLLECTIBLE_CHOCOLATE_MILK] = {Description = "蓄力时身体也随之放大",},
		[CollectibleType.COLLECTIBLE_CURSED_EYE] = {Description = "额外使用幻影攻击角色与目标之间的位置",},
		[CollectibleType.COLLECTIBLE_EYE_OF_THE_OCCULT] = {Description = "在空中可短暂位移调整攻击方向",},
		--[CollectibleType.COLLECTIBLE_TERRA] = {Description = "",},
		[CollectibleType.COLLECTIBLE_SOY_MILK] = {Description = "跳过第一段前摇",},
		[CollectibleType.COLLECTIBLE_ALMOND_MILK] = {Description = "跳过第一段前摇",},
		[CollectibleType.COLLECTIBLE_NEPTUNUS] = {Description = "蓄力50%以上即可攻击",},
		[CollectibleType.COLLECTIBLE_ANTI_GRAVITY] = {Description = "每蓄力达到2倍攻击延迟，生成一个幻影在角色攻击后落下",},
		[CollectibleType.COLLECTIBLE_TECHNOLOGY_ZERO] = {Description = "用激光连接攻击目标",},
		[CollectibleType.COLLECTIBLE_LUMP_OF_COAL] = {Description = "准星距角色越远伤害越高",},
		[CollectibleType.COLLECTIBLE_PROPTOSIS] = {Description = "准星距角色越近伤害越高",},
		[CollectibleType.COLLECTIBLE_EYE_SORE] = {Description = "额外攻击一个随机位置",},
		[CollectibleType.COLLECTIBLE_MEGA_MUSH] = {Description = "巨化状态砸地时生成裂地波",},
		[CollectibleType.COLLECTIBLE_EYE_OF_BELIAL] = {Description = "命中后额外生成红色幻影攻击敌人",},
		[CollectibleType.COLLECTIBLE_EYE_OF_GREED] = {Description = "每5次攻击后失去1块钱并额外生成黄金色冲击",},
		[CollectibleType.COLLECTIBLE_TINY_PLANET] = {Description = "准星移动时向一个方向旋转",},
		[enums.Items.Tears_of_Pearl] = {Description = "概率弹反周围弹幕",},
	},
	[enums.Players.Zeistos] = {
		[CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE] = {Description = "自动置入副手"..
		    "#每层可以使用一次",},
		[enums.Items.Contemplation] = {Description = "不会自动离开",},
	},
}

item.zh.PlayerSyncTrinket = {
	[enums.Players.Tecro] = {
		[TrinketType.TRINKET_WIGGLE_WORM] = {Description = "枪尖扭来扭去",},
		[TrinketType.TRINKET_RING_WORM] = {Description = "枪尖旋转时快时慢",},
		[TrinketType.TRINKET_OUROBOROS_WORM] = {Description = "穿刺持续时长+1s"..
		    "#枪尖旋转难以开启且停不下来",},
		[TrinketType.TRINKET_PUSH_PIN] = {Description = "穿刺数量+1",},
		[TrinketType.TRINKET_HOOK_WORM] = {Description = "枪尖以方波状态旋转",},
		[TrinketType.TRINKET_BRAIN_WORM] = {Description = "改为穿刺持续时长+2s",},
		
		[TrinketType.TRINKET_CURVED_HORN] = {Description = "持有且使用羊总枪尖：攻击倍率提升1.5倍",},
	},
}

item.en_us = item.en
item.zh_cn = item.zh
item.en_us.Challanges = item.en_us.Challenges
item.zh_cn.Challanges = item.zh_cn.Challenges

return item
