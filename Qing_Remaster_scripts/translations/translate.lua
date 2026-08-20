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
            Desc = "灭于未知",
            Description = "{{BlackHeart}} +1黑心"..
            "#!!! 变为魂心角色"..
            "#{{Damage}} 按黑心数量增加攻击"..
            "#{{BlackHeart}} 击杀敌人逐渐将魂心染成黑心，或填满半黑心"..
            "#{{DevilRoom}} {{BlackHeart}} 黑心可以等价代替{{Heart}}红心进行恶魔交易",
            AbyssSynic = "纯黑蝗虫，杀死敌人时有概率掉落黑心",
        },
        en = {
            Name = "Darkness",
            Desc = "Buried in the past.",
            Description = "{{BlackHeart}} +1 Black Heart"..
            "#!!! Changes your health type to soul hearts"..
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
            Description = "#{{Player"..Players.wq.."}} 使用后，本房间内攻击方式变为青的刀法"..
            "#重复使用使攻击次数+1",
            AbyssSynic = "蝗虫命中敌人后发动刺击",
            BookOfBelial = "使用后，青的刀法额外视为拥有硫磺火",
        },
        en = {
            Name = "Touchstone",
            Desc = "Borrow my blade",
            Description = "#{{Player"..Players.wq.."}} on use, replaces your attack with Qing's blade style for the current room"..
            "#Repeated uses grant +1 attack count",
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
            Description = "阻挡来自脑袋上的眼泪攻击"..
            "#站在跳起来的敌人身体下方造成伤害",
        },
        en = {
            Name = "Qing's Hat",
            Desc = "It's too big!",
            Description = "Blocks damage from projectiles falling from above."..
            "#Standing under the jumping enemy's body to inflict damage.",
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
            Desc = "Skipped...But why?",
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
            Description = "角色的眼泪学会刺杀",
            AbyssSynic = "蝗虫学会暗杀",
        },
        en = {
            Name = "Assassin's Eye",
            Desc = "Savour the Dark",
            Description = "Tears assassinate enemies when getting closed",
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
            "#按顺序进入这些房间以获得奖励"..
            "#{{Warning}} 进入错误房间会受到惩罚",
            AbyssSynic = "彩色蝗虫",
        },
        en = {
            Name = "Mental Hypnosis",
            Desc = "Would you kindly?",
            Description = "{{TreasureRoom}} Each floor creates an ordered list of special rooms"..
            "#Enter them in order to receive a reward"..
            "#{{Warning}} Entering the wrong room causes a punishment",
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
            Description = "进入新房间时，普通岩石有概率变成愚人金块"..
            "#破坏{{ColorGold}}愚人金块{{CR}}时，33%概率生成2~4只黄金蜘蛛",
            AbyssSynic = "金色蝗虫，命中敌人时小概率施加点金",
        },
        en = {
            Name = "Gold Rush",
            Desc = "All that glitters...",
            Description = "Entering a new room gives normal rocks a chance to become fool's gold"..
            "#Destroying {{ColorGold}}fool's gold{{CR}} has a 33% chance to spawn 2-4 golden spiders",
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
            "#{{Warning}} 停滞过久会被锁定射击"..
            "#靠近的敌人也会被锁定射击",
            SeijaBuff = "防爆"..
            "#射击全屏敌人",
        },
        en = {
            Name = "The Watcher",
            Desc = "Big Brother is watching",
            Description = "{{Speed}} Minimum speed is 1.5"..
            "#{{Warning}} Standing still too long marks and shoots you"..
            "#Nearby enemies are also marked and shot",
            SeijaBuff = "Immune to explosion"..
            "#All enemies will be shot",
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
            Description = "↑ 总血量低于生命上限时，角色变大，攻击翻倍"..
            "#↓ 总血量高于生命上限时，角色变小，攻击减半",
            AbyssSynic = "稍大的蝗虫",
        },
        en = {
            Name = "Giant Punch",
            Desc = "God-o-hand-o-Crash!",
            Description = "↑ Double damage when your total hearts are less than heart containers"..
            "#↓ Half damage when more than it",
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
            Description = "!!! 一次性 "..
            "#将道具池替换为只包含角色已有的道具",
            AbyssSynic = "彩色蝗虫",
            BookOfBelial = "恶魔房道具50%概率替代已拥有道具出现",
            BookOfVirtues = "熄灭时结束回忆效果的魂火"..
            "#↑ 每个重复的道具少量将其加强"..
            "#进入新房间后魂火回复到满状态",
        },
        en = {
            Name = "Memory",
            Desc = "I fall into a loop...",
            Description = "!!! SINGLE USE "..
            "#!!! Grants all itempools only contain items that you already have.",
            AbyssSynic = "Colorful locust",
            BookOfBelial = "Grants a 50% chance to replace memoried item with devil items.",
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
            Description = "{{Chest}} 生成2个随机箱子"..
            "#{{GoldenChest}} 金箱子改为开出头部相关道具"..
            "#{{Chest}} 普通箱子也有小概率开出这些道具",
        },
        en = {
            Name = "My Best Friend",
            Desc = "Do you really have a friend?",
            Description = "{{Chest}} Spawns 2 random chests"..
            "#{{GoldenChest}} Golden chests give head-themed items instead"..
            "#{{Chest}} Regular and spiked chests have a small chance to give head-themed items",
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
            "#{{Timer}} 无超大炸弹时，1个炸弹闲置20秒后成长为超大炸弹"..
            "#{{Collectible483}} 无主动时，超大炸弹闲置2分钟后成长为妈咪炸弹",
        },
        en = {
            Name = "Super Bombs",
            Desc = "My pocket doomsday",
            Description = "{{Bomb}} +5 Giga Bombs"..
            "#{{Timer}} With no Giga Bombs, leave bombs unused for 20 seconds to grow 1 into a Giga Bomb"..
            "#{{Collectible483}} With no active item, leave a Giga Bomb unused for 2 minutes to grow it into Mama Mega",
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
            Description = "带有硫磺火柱的火箭跟班"..
            "#{{BrimstoneCurse}} 被火箭炸到的敌人对硫磺火脆弱",
            AbyssSynic = "移速较快，命中后造成硫磺火脆弱的蝗虫",
        },
        en = {
            Name = "Brimstream",
            Desc = "Devil's trick.",
            Description = "Spawn a rocket baby with wake of brimstone."..
            "#{{BrimstoneCurse}} Enemies being exploded will be fragile to brimstone",
            AbyssSynic = "Locust that is fast and deals fragile to brimstone.",
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
            Description = "提高琉璃化掉落物的生成概率"..
            "#拾取琉璃化掉落物会为冠冕增加1层辉片，最多5层"..
            "#{{Damage}} 1层：+0.6攻击"..
            "#2层：攻击命中时有概率产生琉璃折射"..
            "#{{Luck}} 3层：+1幸运，并强化琉璃效果的触发率"..
            "#4层：攻击有概率使敌人琉璃化"..
            "#5层：完成冠冕，强化琉璃化掉落物，并免疫琉璃化敌人的碰撞伤害"..
            "#{{Warning}} 受伤时冠冕破碎并失去全部辉片"..
            "#根据失去的辉片数量向四周释放琉璃碎片",
            SeijaNerf = "琉璃化掉落生成率提升减弱，碎冠伤害减半，且不再强化琉璃效果触发率",
        },
        en = {
            Name = "Crown of the glaze",
            Desc = "A king, until it shatters",
            Description = "Increases the chance of glazed pickups"..
            "#Picking up glazed pickups adds 1 Crown shard, up to 5"..
            "#{{Damage}} 1 shard: +0.6 Damage"..
            "#2 shards: Hits may split into glazed refraction tears"..
            "#{{Luck}} 3 shards: +1 Luck, and glazed effect chances are boosted"..
            "#4 shards: Attacks may glaze normal enemies"..
            "#5 shards: Completes the crown, empowers glazed pickups, and blocks glazed enemy contact damage"..
            "#{{Warning}} Taking damage shatters the crown and removes all shards"..
            "#Fires glaze fragments based on lost shards",
            SeijaNerf = "Weaker glazed pickup bonus, half shatter damage, and no glazed-effect chance bonus",
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
            Description = "有谶曰：金玉所成，必先自晦 "..
            "#剧情道具 "..
            "#在主线中拾取此道具将立刻与乞丐国王再战，胜利会获得硬币作为奖励",
        },
        en = {
            Name = "A Shard of Coin",
            Desc = "Those who shared Pennies have been in pieces",
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
            Description = "有谶曰：晦明五色，必损于光 "..
            "#剧情道具",
        },
        en = {
            Name = "A Shard of Glaze",
            Desc = "Those who honored Pride have been in pieces",
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
            Description = "有谶曰：光结岩熔，必逢碎体 "..
            "#剧情道具",
        },
        en = {
            Name = "A Shard of Lava",
            Desc = "Those who ingested Heat have been in pieces",
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
            Description = "有谶曰：体遍万物，必破心神 "..
            "#剧情道具",
        },
        en = {
            Name = "A Shard of Meat",
            Desc = "Those who valued Life have been in pieces",
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
            Description = "有谶曰：神归至诚，必开飞金 "..
            "#剧情道具",
        },
        en = {
            Name = "A Shard of Rock",
            Desc = "Those who desired Eternal have been in pieces",
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
            Description = "每个未清理的房间随机生成3只小黄鸭"..
            "#向其注入眼泪使之爆开",
        },
        en = {
            Name = "Little Duck",
            Desc = "Quack, quack, quack!",
            Description = "Spawns 3 little ducks in each uncleared room"..
            "#Feed them tears until they burst",
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
            Description = "投入3个道具以精准制作1个道具"..
            "#制作的道具编号为投入的三个道具依次的百位、十位、个位的和",
            BookOfBelial = "每次制作可以免费投入一个数字6",
            BookOfVirtues = "将投入的道具作为魂火保留下来",
            SeijaNerf = "50%概率制作出错误道具",
        },
        en = {
            Name = "Alchemy Pot",
            Desc = "Handle with transmutation",
            Description = "Invest 3 items to craft a precise collectible"..
            "#The result ID is made from the hundreds, tens, and ones digits of the invested items",
            BookOfBelial = "Each casting can add a free digit 6",
            BookOfVirtues = "Keeps the invested items as wisps",
            SeijaNerf = "50% chance to make a wrong item",
        },
    },
    [25] = {
        Name = "飞行界域者",
        id = Items.Air_Terror,
        type = "passive",
        xmlId = 26,
        zh = {
            Name = "飞行界域者",
            Desc = "敌人已锁定！",
            Description = "自动巡航的小跟班，快速收集敌弹并短暂留下{{Collectible331}}伤害性光环",
        },
        en = {
            Name = "Air Terror",
            Desc = "Hello...Again?",
            Description = "An automatic cruising familiar quickly collects enemy bullets and briefly leaves a {{Collectible331}} damage halo.",
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
            Description = "{{EmptyHeart}} +1血上限 "..
            "#{{Collectible12}} 向头目房道具池内增加一个大蘑菇",
        },
        en = {
            Name = "Glaze Mushroom",
            Desc = "I Feel...Glazed..uh?",
            Description = "{{Heart}} +1 full red heart container."..
            "#{{Collectible12}} Add a Magic Mushroom into the boss itempool",
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
            Description = "{{Luck}} 每1个皮肤+0.1幸运"..
            "#随机获得10个皮肤",
        },
        en = {
            Name = "Pageant Cross-dresser",
            Desc = "Ultimate grand sexy",
            Description = "{{Luck}} +0.1 Luck up per costume"..
            "#↑ Add 10 random costumes",
        },
    },
    [28] = {
        Name = "鸭架",
        id = Items.It_s_a_trick,
        type = "active",
        xmlId = 29,
        zh = {
            Name = "鸭架",
            Description = "{{Tears}} 射速+0.7",
        },
        en = {
            Name = "Wire duck hanger",
            Desc = "You Are Fooled Again!!",
            Description = "{{Tears}} +0.7Tears up",
            Hidden = true,
        },
    },
    [29] = {
        Name = "世末天依",
        id = Items.Tianyi,
        type = "passive",
        xmlId = 30,
        zh = {
            Name = "世末天依",
            Description = "{{Chargeable}} 蓄力发射{{Collectible643}} 启示光波的宝宝",
        },
        en = {
            Name = "Apocalypse",
            Desc = "Forever and Never",
            Description = "{{Chargeable}} Spawn a baby familiar that follows Isaac and will charge a shot while firing."..
            "#Releasing it will fire a {{Collectible643}} light beam.",
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
            "#按住Ctrl并按E点赞；按住Ctrl并按Q点踩"..
            "#{{Collectible}} 点赞：复制一份该道具进入当前道具池"..
            "#{{Warning}} 点踩：该道具从当前局与下一局的道具池中移除",
        },
        en = {
            Name = "Pride or Prejudice",
            Desc = "My taste needs no defense",
            Description = "Approach an item pedestal to judge it"..
            "#Hold Ctrl and press E to like it; hold Ctrl and press Q to dislike it"..
            "#Controllers can hold Drop and press Shoot Right/Left"..
            "#{{Collectible}} Liked items are copied into the current item pool"..
            "#{{Warning}} Disliked items are removed from this run and the next run's item pools",
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
            Description = "不移动时眼泪向上飘，随后从地面上重新出现 "..
            "#移动时眼泪加速下落 "..
            "#{{Tears}} 射速+1",
        },
        en = {
            Name = "Anti-Field",
            Desc = "Those who rise up must be drifting down.",
            Description = "Standing still provides floating up tears"..
            "#otherwise tears slowly float down"..
            "#{{Tears}} +2 Tears up",
        },
    },
    [32] = {
        Name = "缝合针",
        id = Items.Suture_Needle,
        type = "active",
        xmlId = 33,
        zh = {
            Name = "缝合针",
            Desc = "死亡只是线断了",
            Description = "{{Timer}} 自动充能"..
            "#使用时缝合附近的敌人，持续数秒"..
            "#期间死亡的敌人会被强行维持活动一段时间"..
            "#继续攻击会拆开缝线"..
            "#缝线断裂时撕裂身体并伤害附近敌人",
            BookOfBelial = "每有一个敌人进入缝尸状态，本房间获得临时攻击提升",
            BookOfVirtues = "生成最多一个缝合魂火"..
            "#每有一个敌人进入缝尸状态，魂火会变大并提高伤害"..
            "#敌人拆线死亡时，魂火向其位置发动攻击",
            SeijaBuff = "缝尸持续更久，但受到攻击时缝线会更快断裂",
        },
        en = {
            Name = "Suture Needle",
            Desc = "Death is only a broken thread",
            Description = "{{Timer}} Recharges over time"..
            "#Sutures nearby enemies for a few seconds"..
            "#Enemies that die during this window continue moving briefly"..
            "#Further damage causes their sutures to break faster"..
            "#When the sutures completely break, their bodies rupture and damage nearby enemies",
            BookOfBelial = "Gain a temporary damage up whenever an enemy enters the sutured state",
            BookOfVirtues = "Spawns up to one Suture Wisp"..
            "#The wisp grows and gains damage whenever an enemy enters the sutured state"..
            "#When a sutured enemy ruptures, the wisp attacks its position",
            SeijaBuff = "Sutured enemies persist longer, but damage breaks their sutures much faster",
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
            Description = "商品二选一 "..
            "#!!! 商品价格随机提升0-35%",
            SeijaNerf = "价格翻3倍",
        },
        en = {
            Name = "More and more Options!",
            Desc = "Also Double Price",
            Description = "Shop items and devil deals become a selection in two."..
            "#All shop items will have a higher price, between 100% and 135%.",
            SeijaNerf = "Triple price",
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
            Description = "{{Card}} 你持有的所有卡牌均在同种类卡间切换",
        },
        en = {
            Name = "Fate's Draw",
            Desc = "My Drawwww!!!!",
            Description = "{{Card}} Change your card in hand every 0.2 seconds.",
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
            Description = "3个造成每15帧7点接触伤害的纹章宝宝 "..
            "#让宝宝随着子弹发射组织进攻",
        },
        en = {
            Name = "Qing's Emblem",
            Desc = "Finally a home for me..",
            Description = "Spawn 3 emblem familiars that follows Isaac and deals 10 collision damage per second. "..
            "#Emblem familiar can absorb 1 bullet after dealing collision damage. "..
            "#Familiars will follow Isaac's tear to move around.",
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
            Description = "{{CurseDarkness}} 33%概率使黑暗笼罩房间"..
            "#{{CurseDarkness}} 蓄力潜入黑暗，发动斩击并反击弹幕"..
            "#↑ 在黑暗中30%概率免疫攻击"..
            "#↑ 飞行 "..
            "#{{Damage}} +1攻击",
            AbyssSynic = "概率恐惧的蝗虫",
        },
        en = {
            Name = "Ingestion to Night",
            Desc = "The night has teeth",
            Description = "{{CurseDarkness}} 33% chance for rooms to become pitch black"..
            "#{{CurseDarkness}} Charge in darkness to unleash slashes and counter projectiles"..
            "#↑ 30% chance to ignore damage in darkness"..
            "#↑ Flight"..
            "#{{Damage}} +1 damage",
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
            Description = "使用主动标记敌人 "..
            "#!!! 角色死亡时将取代被标记的敌人，复活并失去数个随机{{Collectible}}道具，不足时增加{{BrokenHeart}}碎心",
            AbyssSynic = "蝗虫命中敌人也进行标记",
            BookOfBelial = "复活后依次获得：#前5次：{{Collectible51}}#5-12次：{{Collectible462}}#13次以上：{{Collectible118}}",
            BookOfVirtues = "每个魂火可以替代一个道具被主动抵消",
            SeijaBuff = "复活时不消耗道具",
        },
        en = {
            Name = "Devil's Heart",
            Desc = "Stage a Comeback",
            Description = "Fire devil's mark at enemy"..
            "#!!! Revive at a live enemy's position that is marked when you die"..
            "#After that,remove several {{Collectible}}collectibles or add {{BrokenHeart}} broken hearts and kill the enemy",
            AbyssSynic = "Marking locust",
            BookOfBelial = "Gain item depending on reviving time：#1-5：{{Collectible51}}#5-12：{{Collectible462}}#More than 13：{{Collectible118}}",
            BookOfVirtues = "Each wisp replace a collectible to be removed",
            SeijaBuff = "Revive without removing items",
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
            Description = "{{Collectible}} 从道具池中抽取随机道具，直到总品质达到50"..
            "#生成一个四选一道具",
            BookOfBelial = "额外生成两个恶魔房道具作为选项",
            BookOfVirtues = "生成一个被移除的道具对应魂火",
            SeijaNerf = "改为生成一个一选一道具",
        },
        en = {
            Name = "Book of Future",
            Desc = "Rewrite what has yet to happen",
            Description = "{{Collectible}} Pulls random items from item pools until their total quality reaches 50"..
            "#Spawns a 4-choice item selection",
            BookOfBelial = "Adds 2 Devil Room items to the selection",
            BookOfVirtues = "Spawns a wisp from one removed item",
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
            BookOfVirtues = "和平魂火 #角色受到2格心或以上的伤害时，熄灭全部和平魂火，那个伤害被抵消",
        },
        en = {
            Name = "Hyper Velocity",
            Desc = "Next stop: impact",
            Description = "{{Throwable}} Hold up the item, then choose a direction to call a train"..
            "#The train runs through enemies and terrain"..
            "#{{Damage}} Deals 250 + 5x Isaac's damage to enemies"..
            "#{{Warning}} Deals 5 damage to Isaac on collision",
            AbyssSynic = "Very fast locust",
            BookOfVirtues = "Peace wisps prevent one hit of 2 hearts or more, then all vanish",
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
            "#↓ 每2层凝视：眼泪方向更加摇摆"..
            "#{{Tears}} 每3层凝视：射速提升"..
            "#{{Collectible572}} 5层：可控制眼泪"..
            "#{{Collectible3}} 8层：跟踪眼泪"..
            "#{{Trinket26}} 13层：钩虫眼泪"..
            "#{{Collectible221}} 21层：弹性眼泪"..
            "#!!! 4次失误后重置计数器",
        },
        en = {
            Name = "Wavering Eyes",
            Desc = "Don't blink, don't miss",
            Description = "Consecutive tear hits build Focus"..
            "#↓ Every 2 Focus: tears waver more"..
            "#{{Tears}} Every 3 Focus: tears up"..
            "#{{Collectible572}} 5 Focus: controllable tears"..
            "#{{Collectible3}} 8 Focus: homing tears"..
            "#{{Trinket26}} 13 Focus: hook worm tears"..
            "#{{Collectible221}} 21 Focus: rubber tears"..
            "#{{Warning}} 4 misses reset the counter",
        },
    },
    [43] = {
        Name = "回荡之星",
        id = Items.Pendulum_Star,
        type = "passive",
        xmlId = 54,
        zh = {
            Name = "回荡之星",
            Desc = "摇晃吧！吾魂之灵摆！",
            Description = "一对不断晃动的跟班，在最低点对敌人造成每帧3.5点伤害",
        },
        en = {
            Name = "Pendulum Star",
            Desc = "Pendulum Scale Setting",
            Description = "Spawn a pair of constantly shaking followers deal 3.5 damage per frame to the enemy at the lowest point.",
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
            Description = "{{ThothCard}} 获得透特牌时，将对应牌面登记至卡册"..
            "#{{Battery}} 使用透特牌获得1格启示充能，最多12格"..
            "#启示不会随清理房间自然恢复，未满也可打开卡册"..
            "#使用打开全屏卡册：卡册/占卜可翻页浏览，占卜页将已登记牌拖入槽位"..
            "#占卜可先排出至多3张牌的牌阵，每张消耗1格启示"..
            "#超出当前启示的牌面会标红，充能不足时无法确认"..
            "#每清理一个战斗房，依次发动下一张牌"..
            "#正逆位均被登记后，可自由选择对应牌面"..
            "#未登记的透特牌更容易出现",
            AbyssSynic = "命中后概率生成卡牌的蝗虫",
            BookOfBelial = "使用透特牌获得临时攻击力",
            BookOfVirtues = "魂火熄灭时生成一张塔罗牌",
            SeijaNerf = "所有透特卡以背面表示出现",
        },
        en = {
            Name = "Book of Thoth",
            Desc = "Fate is merely a book yet to be put in order.",
            Description = "{{ThothCard}} Picking up a Thoth card registers that face in the codex"..
            "#{{Battery}} Using a Thoth card grants 1 Revelation charge, up to 12"..
            "#Revelation does not refill by clearing rooms; the book can still be opened when not full"..
            "#Use to open the fullscreen codex: turn pages on Codex/Reading, drag registered faces into slots on Reading"..
            "#Draft up to 3 faces first; each costs 1 Revelation"..
            "#Faces beyond current Revelation are marked red; confirm stays locked until you can pay"..
            "#Clearing a combat room plays the next card in the spread"..
            "#Registering both upright and reversed lets you choose either face"..
            "#Unseen Thoth faces appear more often",
            AbyssSynic = "Locust that have chance to spawn a tarot card",
            BookOfBelial = "Damage up when using Thoth cards",
            BookOfVirtues = "Wisps that spawn a tarot card when extinguished",
            SeijaNerf = "All Thoth cards appear on the back",
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
            Description = "使用后，下一次生成的道具来自当前房间的道具池",
            BookOfBelial = "在恶魔房使用时三倍效果",
            BookOfVirtues = "熄灭时额外使用一次{{Collectible"..tostring(enums.Items.Book_of_The_Law).."}}的魂火",
        },
        en = {
            Name = "Book of The Law",
            Desc = "Left is Right.Right is Lefted.",
            Description = "Record the itempool in this room."..
            "#The next item will be selected from this itempool.",
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
            Desc = "视线所及，再无安宁",
            Description = "使用后，当前房间内资源获取、消耗量翻倍 "..
            "#金雷、金钥匙对应3个普通基础",
            BookOfBelial = "获得心类资源时额外获得半颗黑心",
            BookOfVirtues = "获得资源时，自动消耗并将资源量+1的魂火",
        },
        en = {
            Name = "Book of Vision",
            Desc = "Doubook Vision",
            Description = "Double all pickup acquisition and consumption in the current room."..
            "#Extra golden bomb/golden key corresponds to 3 bombs/keys.",
            BookOfBelial = "Grants heart-type pickups an additional half a black heart.",
            BookOfVirtues = "Spawn a wisp that automatically extinguish and duplicate the pickup on collision.",
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
            "#{{Collectible}} 使用后选择接受或拒绝，接受则立即完成交易"..
            "#每次接受都会让声音更加清晰，并缩短充能",
            BookOfBelial = "可加倍接受低语，以更高代价换取更高报酬",
            BookOfVirtues = "回应低语时生成假象魂火，使要求降低一级",
            SeijaBuff = "拒绝低语也会获得小型报酬，并使声音更加清晰",
        },
        en = {
            Name = "Book of Voice",
            Desc = "Destroy me. Quickly.",
            Description = "{{Battery}} Obtained at 0 charge; when full, can call a whisper"..
            "#Whispers also start on their own and temporarily make this book usable"..
            "#{{Collectible}} Use to accept or refuse; accepting completes the deal immediately"..
            "#Each accept makes the voice clearer and shortens charge",
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
            Description = "!!! 失去表述文字的能力 "..
            "#无法表述的文字散落在地上 "..
            "#{{Damage}} 收集文字，每个文字可以让一发眼泪增加2.5点伤害，并暂时提升0.4攻击 "..
            "#不会影响EID",
        },
        en = {
            Name = "Aphasia",
            Desc = "Hardly can I ever read",
            Description = "!!! Lose the ability to express words, including most of normal descriptions in the game."..
            "#Words scattered around"..
            "#{{Damage}} Picking up words grants bonus damage",
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
            Description = "从角色的身下开始绘制地缚图线 "..
            "#踩到的敌人受到伤害 "..
            "#{{Damage}} 站立在地缚图线上获得速度与攻击倍率提升，最高+100%",
            AbyssSynic = "三只蝗虫",
            SeijaNerf = "只有一条绘制线",
        },
        en = {
            Name = "Nazca",
            Desc = "Earthbound Deity",
            Description = "Draw nazca lines in the room "..
            "#{{Damage}} Deal damage to the enemies and grants stats bonus to Isaac",
            AbyssSynic = "Triple locust",
            SeijaNerf = "Only one draw line",
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
            Description = "#{{Chargeable}} 长按蓄力，否则清空蓄力值 "..
            "#蓄力完成后自动向身后发射因子网 "..
            "#作为底座道具出现时，在2秒后转化为{{Collectible"..tostring(enums.Items.Wisel).."}}。",
        },
        en = {
            Name = "Skiel",
            Desc = "Your past is lying in pain",
            Description = "{{Chargeable}} Hold down to charge, or the charge value will be reset"..
            "#Fire factor network when charged",
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
            Description = "#{{Chargeable}} 反复点击以蓄力，否则逐渐减少蓄力值 "..
            "#蓄力完成后，向前方发射冲击波纹 "..
            "#作为底座道具出现时，在2秒后转化为{{Collectible"..tostring(enums.Items.Granel).."}}。",
        },
        en = {
            Name = "Wisel",
            Desc = "Your present is immersed in dispair",
            Description = "{{Chargeable}} Press repeatedly to accumulate power,otherwise lose power gradually "..
            "#Fire Shooting Waves when charged",
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
            Description = "#{{Chargeable}} 长按蓄力，点按加快蓄力，否则缓缓减少蓄力值 "..
            "#蓄力完成后向四角喷射火焰 "..
            "#作为底座道具出现时，在2秒后转化为{{Collectible"..tostring(enums.Items.Skiel).."}}。",
        },
        en = {
            Name = "Granel",
            Desc = "Your future is trailed in vanishment",
            Description = "{{Chargeable}} Long press to accumulate power,press repeatedly to accelerate power accumulation "..
            "#Fire flames in four directions when charged",
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
            Description = "举起妖刀，挥向房间中的道具"..
            "#在面板中花费1{{Coin}}，随机重铸一个前缀和一个后缀"..
            "#词缀永久绑定该道具，持有时获得对应效果"..
            "#面板也可永久改写其名字与描述"..
            "#支持中文输入法"..
            "#可重复付费重新随机词缀",
            SeijaNerf = "大幅提升重铸词条的费用",
        },
        en = {
            Name = "Spectral Sword",
            Desc = "Out of its sheath",
            Description = "Raise the blade and swing at a room item"..
            "#In the editor, spend 1{{Coin}} to roll one random prefix and suffix"..
            "#Affixes permanently bind to that item and grant effects while held"..
            "#The editor can also permanently rewrite its name and description"..
            "#Affixes can be reforged repeatedly",
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
            Description = "#斩开事物的间隙 "..
            "#在间隙中调整它们的属性 "..
            "#按下 "..eidButton(ButtonAction and ButtonAction.ACTION_DROP).." 结束属性操作 "..
            "#按下 "..eidButton(ButtonAction and ButtonAction.ACTION_PILLCARD).." 与 "..eidButton(ButtonAction and ButtonAction.ACTION_MAP).." 在项内切换",
            BookOfVirtues = "不生成魂火",
            SeijaNerf = "在修改器中每次移动指针都会降低全属性",
        },
        en = {
            Name = "Squiresaga",
            Desc = "My blade burns",
            Description = "#Cut out the crevice of an entity #Adjust their attributes in the crevice(ONLY CHINESE) #Press"..eidButton(ButtonAction and ButtonAction.ACTION_DROP).."to end attribute adjusting#Press"..eidButton(ButtonAction and ButtonAction.ACTION_PILLCARD).."and"..eidButton(ButtonAction and ButtonAction.ACTION_MAP).."switch in attributes",
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
            Description = "{{ArrowUp}} 回收利用攻击的剩余能量，对敌人造成伤害并转化为属性提升 "..
            "#提升达到一定值后，会泄露提升的属性防止过载 "..
            "#!!! 过量的能量吸收导致零点反转",
            SeijaNerf = "能量不会泄露，即使反转已经发生",
        },
        en = {
            Name = "Moment",
            Desc = "lasrever dlroW",
            Description = "Recover the remaining energy of all attack methods and convert it into attribute enhancement"..
            "#!!! Overload will reverse the world for sometime and overturn all attribute enhancement",
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
            Description = "阻挡每个房间第一次受到的伤害，并出释放冲击波消除弹幕 "..
            "#在冲击波碰撞的敌人处再次释放冲击波 "..
            "#{{Chargeable}} 冲击波未被消耗时，可蓄力释放小型冲击波",
            AbyssSynic = "蝗虫命中后释放小型冲击波",
            SeijaNerf = "改为每层下层时恢复",
        },
        en = {
            Name = "Lofty",
            Desc = "Bottomless despair abyss",
            Description = "Block the first damage to each room and release shock wave"..
            "#Release shock wave again at the enemies touched by the shock wave "..
            "#{{Chargeable}} Charge to shoot small shock wave before you take damage",
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
            Description = "此道具以下效果在触发或下层时逐渐改写",
        },
        en = {
            Name = "Theseus's Sign",
            Desc = "Terms under revision",
            Description = "The following effects rewrite after triggering or entering a new floor",
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
            Description = "↑ 飞行直到翅膀折断 "..
            "#{{BlackHeart}} 进入天使房折断恶魔翅膀，生成1个黑心 "..
            "#{{EternalHeart}} 进入恶魔房折断天使翅膀，生成1个白心 "..
            "#{{Collectible}} 双翅均折断后，下层生成天使、恶魔房道具各一个，然后恢复双翅",
        },
        en = {
            Name = "Heart Change",
            Desc = "Demon in body,angel in mind",
            Description = "↑ Grants flight when two wing exists "..
            "#Break Devil's wing when entering angel room "..
            "#Break Angel's wing when entering devil room "..
            "#Recover both wings when then are broken and spawn 2 item from angel and devil's item pool after entering a new level",
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
            Description = "{{Battery}} 将主动充能上限设置为2，溢出的充能以球的形式泄露出来"..
            "#使用主动时有 当前上限/原上限 概率成功使用"..
            "#失败：泄露所有充能，上限+2"..
            "#{{Warning}} 受伤时上限-2",
            AbyssSynic = "蝗虫命中时小概率生成充能球",
        },
        en = {
            Name = "Cable Jar",
            Desc = "Slightly leaky",
            Description = "{{Battery}} Sets the primary active's charge cap to 2; excess charge leaks out as energy orbs"..
            "#On use: current cap/base cap chance to succeed"..
            "#Failure: leak all charge; cap +2"..
            "#{{Warning}} Taking damage reduces the cap by 2",
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
            Description = "{{Tears}} 每4发眼泪变为福音眼泪并增伤"..
            "#其他攻击方式会额外发射福音眼泪"..
            "#福音眼泪使命中的敌人接受福音"..
            "#持续攻击受福音影响的敌人，会向附近敌人射出圣光并传播福音"..
            "#受福音影响的敌人死亡时降下启示之光，并继续传播福音"..
            "#{{BossRoom}} 对Boss造成足够伤害也会降下启示"..
            "#多次启示后发动最终审判",
            AbyssSynic = "蝗虫命中敌人时使其接受福音",
            SeijaNerf = "福音无法传播；宣讲与启示改为在自身降下较弱的黑暗之光",
        },
        en = {
            Name = "Gospel",
            Desc = "Dogmatical Judgement",
            Description = "{{Tears}} Every 4th tear becomes a Gospel tear with bonus damage"..
            "#Other attacks fire extra Gospel tears"..
            "#Gospel tears cause hit enemies to receive the Gospel"..
            "#Keep attacking affected enemies to fire holy beams that spread Gospel to nearby foes"..
            "#When an affected enemy dies, Revelation strikes and Gospel keeps spreading"..
            "#{{BossRoom}} Dealing enough damage to a Boss also invokes Revelation"..
            "#Repeated Revelations invoke a final Judgement",
            AbyssSynic = "Locusts cause hit enemies to receive the Gospel",
            SeijaNerf = "Gospel can no longer spread; Preaching and Revelation instead drop a weaker dark light on the source",
        },
    },
    [62] = {
        Name = "提拉米苏",
        id = Items.Tiramisu,
        type = "passive",
        xmlId = 73,
        zh = {
            Name = "提拉米苏",
            Desc = "血量上升+道具变得美味",
            Description = "{{EmptyHeart}} +1血上限 "..
            "#↑ 属性提升时，额外提供40%逐渐减少的属性增幅量",
        },
        en = {
            Name = "Tiramisu",
            Desc = "Health Up + Tastes Tasty",
            Description = "{{EmptyHeart}} +1 Health up "..
            "#↑ Stats gaining will bring about a fading bonus stats about 40%",
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
            Description = "游戏进入直播模式 "..
            "#可以实时与弹幕互动 "..
            "#{{ArrowUp}} 人气值足够会有老板送来礼物，提升属性",
        },
        en = {
            Name = "Live Broadcast",
            Desc = "Going live!",
            Description = "Starts a live broadcast "..
            "#Viewer comments react to events in real time "..
            "#{{ArrowUp}} Building popularity attracts sponsors whose gifts grant fading stat boosts",
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
            Description = "概率发射交替出现的悲剧与喜剧面具眼泪"..
            "#悲剧：敌人死亡后，将死亡化作追击敌人的爆炸"..
            "#喜剧：敌人死亡后，作为友方演员再次登台"..
            "#同时戴上两张面具的敌人将出演{{ColorPurple}}凶剧{{CR}}"..
            "#凶剧退场时同时触发强化的悲剧与喜剧",
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
            "#Tragedy: slain enemies turn their death into a chasing explosion"..
            "#Comedy: slain enemies take the stage again as brief friendly actors"..
            "#Enemies wearing both masks perform {{ColorPurple}}Tragicomedy{{CR}}"..
            "#Tragicomedy's curtain call triggers empowered tragedy and comedy",
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
            Description = "使用后选择一件持有的被动道具，将其变为临时道具"..
            "#然后生成同品质的三选一底座，其被拾取后也是临时道具"..
            "#{{Warning}} 受伤时自动失去此道具并阻止伤害，并将此道具置于道具池顶部。"..
            "#再次获得后恢复失去的临时道具",
        },
        en = {
            Name = "Tzolkin",
            Desc = "Replay the divine calendar",
            Description = "On use, choose a held passive and convert it into a temporary item"..
            "#Then spawn a same-quality 3-choice set; the picked one is also temporary"..
            "#{{Warning}} On hit, lose this item, block the damage, and put this item at the top of the item pool"..
            "#Reclaiming it restores the lost temporary items",
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
            Description = "对敌人造成伤害会注视目标并逐渐积累月相"..
            "#月相会在敌人死亡或切换目标后保留"..
            "#{{Damage}} 盈满时对注视目标发动一次妖眼共鸣",
        },
        en = {
            Name = "Pareidolia",
            Desc = "Moonlight Domain",
            Description = "Damaging enemies marks a gaze target and builds moon phase"..
            "#Moon phase is kept when the target dies or changes"..
            "#{{Damage}} At full moon, unleash a Yokai Eye resonance on the gaze target",
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
            Description = "剧情道具 "..
            "#将它贴在某个门上 "..
            "#按剧情拾取：立刻将你传送回到初始房间",
        },
        en = {
            Name = "Reversal Film",
            Desc = "Cast Fate On Me",
            Description = "When pasting it on the door to go home, open the room leading to the death certificate floor.",
        },
    },
    [68] = {
        Name = "鲛人之泪",
        id = Items.Tears_of_Pearl,
        type = "passive",
        xmlId = 79,
        zh = {
            Name = "鱼人之泪",
            Desc = "高尚者为我悼哭",
            Description = "概率发射珍珠眼泪 "..
            "#珍珠眼泪落地后吸收周围的飞弹 "..
            "#地上的珍珠可以踢动",
        },
        en = {
            Name = "Tears of Pearl",
            Desc = "Nobility Cherisher",
            Description = "Grants a chance to fire pearl tears."..
            "#Pearl tears can absorb surrounding projectiles after landing and can be kicked around.",
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
            Description = "将房间内道具重置成错误道具"..
            "#将房间内错误道具重置成道具",
            BookOfBelial = "将房间内错误道具重置成恶魔房道具",
            BookOfVirtues = "发射随机特效子弹的魂火",
        },
        en = {
            Name = "D NAN",
            Desc = "Warning: division by zero",
            Description = "Roll the normal items in the room into glitched items."..
            "#Roll the glitched items in the room into normal items.",
            BookOfBelial = "Roll the glitched items in the room into items from devil room.",
            BookOfVirtues = "Grants a wisp that fires random special effects bullets.",
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
            Description = "全属性随机上升/下降"..
            "#接近拾取其的空底座可将其放下以刷取最佳的属性加成"..
            "#最高值："..
            "#{{Damage}} +3攻击"..
            "#{{Tears}} +1.5射速"..
            "#{{Range}} +4.5射程"..
            "#{{Speed}} +0.6移速"..
            "#{{Luck}} +6幸运"..
            "#{{Shotspeed}} +0.6弹速",
        },
        en = {
            Name = "Risemara",
            Desc = "Once more again",
            Description = "Randomly gain stats bonus when pickup"..
            "#Can be put back and pick up again to reroll its stats bonus"..
            "#Maximum："..
            "#{{Damage}} +3 damage"..
            "#{{Tears}} +1.5 tear"..
            "#{{Range}} +4.5 range"..
            "#{{Speed}} +0.6 speed"..
            "#{{Luck}} +6 luck"..
            "#{{Shotspeed}} +0.6 shotspeed",
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
            Description = "隐身的心剑跟班"..
            "#自动标记心剑附身的敌人"..
            "#附身的敌人受到伤害后，斩出其当前生命的20%"..
            "#斩出的生命缓缓飞回敌人体内"..
            "#对Boss只斩出5%",
            AbyssSynic = "斩出少许血量的蝗虫",
        },
        en = {
            Name = "Chiastolite",
            Desc = "Sacrifice with blood",
            Description = "Invisible chiastolite familiar"..
            "#Automatically marks one enemy"..
            "#Cut out 20% the enemy's hitpoints when it get hit"..
            "#Only cut out 5% of the Bosses"..
            "#The hitpoints will slowly fly back to the enemy after that",
            AbyssSynic = "Chiastolite familiar that cuts out a small amount of health",
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
            Description = "只能通过清理Boss房间来充能"..
            "#靠近一扇门来使用，清除门后房间",
            AbyssSynic = "生成小型硫磺火柱的蝗虫",
            BookOfVirtues = "发射生成小型硫磺火柱眼泪的魂火",
        },
        en = {
            Name = "Calamity",
            Desc = "II",
            Description = "Only can be charged by clearing boss rooms"..
            "#Destroy target room completely",
            AbyssSynic = "Locust that spawns small brimstone fire pillars",
            BookOfVirtues = "Grants a wisp that fires small brimstone fire pillars tears",
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
            Description = "进入房间后召唤一个随机友方阴影敌人",
        },
        en = {
            Name = "Shadow Bottle",
            Desc = "Just like inferno",
            Description = "Summon a shadow enemy when entering one room",
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
            Description = "从所有道具中猜测一个道具，随后揭示道具池中的下一个道具"..
            "#猜中的场合，生成那个道具和{{Collectible628}}",
            BookOfBelial = "只从恶魔道具池中揭示道具",
            BookOfVirtues = "成功后生成三个随机道具魂火",
        },
        en = {
            Name = "The true name",
            Desc = "ATEM!",
            Description = "Guess one item in all items and reveal the next item"..
            "#Success:Spawn that item and {{Collectible628}}",
            BookOfBelial = "Only reveal items from devil items",
            BookOfVirtues = "Spawn three random items wisp after success",
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
            Description = "使用后打开蓝图面板"..
            "#{{Collectible}} 将道具作为成本制造飞行器，或作为模块赋予其效果"..
            "#飞行器拥有独立属性与攻击方式，仅受模块影响"..
            "#{{Battery}} 飞行器需要占用控制带宽才能投入战斗"..
            "#每个道具只能被蓝图占用一次"..
            "#{{Collectible}} 持有时有概率生成道具原型模块，可额外使用一次对应模块"..
            "#可随时重新编队、拆装并返还成本",
        },
        en = {
            Name = "Blueprint",
            Desc = "Don't worry, I've got the plans",
            Description = "Use to open the Blueprint panel"..
            "#{{Collectible}} Assign an item as a Flight cost, or install it as a module"..
            "#Flights have independent stats and attacks, affected only by modules"..
            "#{{Battery}} Active Flights consume control bandwidth"..
            "#Each item can only be assigned to Blueprint once"..
            "#{{Collectible}} While held, item prototype modules may appear, granting one extra use of that module"..
            "#Freely reorganize, uninstall modules, and reclaim costs",
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
            Description = "拾取/下层后获得一朵花"..
            "#受伤后花朵就会破碎"..
            "#可选的送达对象：有脑袋的店主、撒旦、天使",
        },
        en = {
            Name = "Delicate Flower",
            Desc = "Wish you a better future",
            Description = "Gain a flower when pick it up and when entering the next level"..
            "#The flower will fade away on getting hit"..
            "#Flowers can be sent to:"..
            "#Keepers with head、Satan、Angel",
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
            Description = "在身后留下科技限制器"..
            "#有敌人经过时，距离为1格的限制器间生成激光并在数秒后消除",
            AbyssSynic = "留下科技限制器的蝗虫",
        },
        en = {
            Name = "Tech 14",
            Desc = "Prosperity leads to decline",
            Description = "Leave technology limiters behind Isaac"..
            "#When an enemy passes by, a laser is generated between limiters at a distance of 1 grid and eliminated after a few seconds",
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
            Description = "每层开始时，在初始房间静止5s后入睡"..
            "#在睡梦中选择心仪的4级道具"..
            "#{{Timer}} 60s后那个道具落到身上并在本层持续"..
            "#按下 {{ButtonRT}} 提前结束梦境",
            SeijaNerf = "改为梦见0级道具",
        },
        en = {
            Name = "Day Dreamer",
            Desc = "If only my wish would come true",
            Description = "At the beginning of each floor, fall asleep in the initial room after a 5 seconds doing completely nothing"..
            "#Choose the desired quality 4 item in your sleep"..
            "#{{Timer}} 60 seconds later, that item will land on Isaac"..
            "#Press {{ButtonRT}} to end the dream in advance",
            SeijaNerf = "Dream about quality 0 items",
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
            Description = "Sew your {{DevilRoom}} devil room and {{AngelRoom}} angel room together",
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
            Description = "{{Card78}} 下层时生成3张红钥匙碎片"..
            "#{{UltraSecretRoom}} 楼层中至多4个特殊房间的布局位置变为与红隐藏相同"..
            "#{{Card78}} 进入那些特殊房间后生成1张红钥匙碎片",
        },
        en = {
            Name = "Deconstruction",
            Desc = "VI",
            Description = "{{Card78}} Spawns 3 red key fragments each level"..
            "#{{UltraSecretRoom}} The layout positions of up to 4 special rooms in the floor will become the same as that of the UltraSecret Room"..
            "#{{Card78}} Spawn 1 red key fragment after entering those special rooms",
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
            Description = "{{Battery}} 需要接触并吸收3个空道具底座以充满充能"..
            "#将距你最近的道具转化为快速切换的数个与其连号的道具",
            BookOfVirtues = "概率发射点金子弹的魂火",
            SeijaNerf = "75%概率将道具转化为彩虹便便",
        },
        en = {
            Name = "Philosopher's Stone",
            Desc = "Masterpiece",
            Description = "{{Battery}} Contact and absorb 3 empty pedestals to fully charge"..
            "#Convert the item closest to Isaac into several items whose number are close to it for quick switching",
            BookOfVirtues = "Wisp with probability to turn enemies gold",
            SeijaNerf = "75% Chance to convert items into rainbow poops",
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
            "#商品价格下降金心总数"..
            "#此道具价格不高于角色的硬币数量",
        },
        en = {
            Name = "Brilliant",
            Desc = "To the gold of eternity",
            Description = "{{GoldenHeart}} +3 Golden Heart"..
            "#The number of golden hearts due to a decrease in commodity prices",
            "#This item's price is not higher than the Isaac's coin count",
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
            Description = "{{Charm}} 角色身上出现一个魅惑光环"..
            "#{{Charm}} 光环魅惑接近的敌人，随后附着在那个敌人上",
            AbyssSynic = "概率魅惑的蝗虫",
        },
        en = {
            Name = "Fraternity",
            Desc = "love me,love my dog",
            Description = "{{Charm}} A charm halo appears on Isaac"..
            "#{{Charm}} The halo enchants the approaching enemy and then attaches to it",
            AbyssSynic = "Locust with chance to charm enemies",
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
            Description = "使用后，随机主动道具从角色头顶逐渐飘落"..
            "#{{Timer}} 30s后角色接收并使用之",
        },
        en = {
            Name = "Ending Count",
            Desc = "Please wait a moment...",
            Description = "Random active items gradually fall from above the character's head"..
            "#{{Timer}} After 30 seconds, Isaac receives and uses it",
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
            Description = "只会在一局游戏中输入rewind指令第3次后生成"..
            "#拾取时获得一层{{Collectible313}}"..
            "#全属性极小幅上升",
            SeijaNerf = "受伤后使用{{Collectible422}}",
        },
        en = {
            Name = "Cheater's Blessing",
            Desc = "I'm so glad that you cheat so many times",
            Description = "It will only be generated after entering the rewind command for the third time in a game"..
            "#Obtain one {{Collectible313}} when pickup"..
            "#Stats up very very small",
            SeijaNerf = "Use {{Collectible422}} on getting hit",
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
            Description = "生成几只来自未清理房间的敌方怪物"..
            "#对应位置怪物视为被清理",
            BookOfVirtues = "发射有传送效果的魂火",
        },
        en = {
            Name = "Dimension Contact",
            Desc = "I found a new passage!",
            Description = "Spawns several enemies from uncleaned rooms"..
            "#The corresponding monster is considered as cleared",
            BookOfVirtues = "Wisp with teleportation effect",
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
            Description = "!!! 一次性"..
            "#获得一个持续一层的随机被动道具效果"..
            "#此道具在本层随机房间中重新出现"..
            "#若没有被找回，也在下层出现",
            BookOfBelial = "随机被动道具来自恶魔道具池",
            BookOfVirtues = "额外生成一个随机道具魂火",
        },
        en = {
            Name = "World Arc",
            Desc = "The world is so small!",
            Description = "!!! SINGLE USE"..
            "#Obtain a random passive item effect that lasts for one level"..
            "#This item reappears in the random room in this floor"..
            "#It also appears in the next level if not retrieved.",
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
            Description = "自动充能"..
            "#使用后放出六道彩色激光并逐渐消耗充能",
            BookOfBelial = "改为发射彩色硫磺火",
            BookOfVirtues = "协同发射激光的魂火",
        },
        en = {
            Name = "Final Prism",
            Desc = "A gift from another world",
            Description = "Charge automatically"..
            "#Release six colored lasers and gradually consume charging energy",
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
            Description = "{{Rune}} 本房间中每使用过一张符文，就抽一张符文，上限3张"..
            "#{{Rune}} 持有符文时可以多带一张卡片或药丸",
            BookOfVirtues = "若成功抽出符文，生成发射极低概率生成符文的眼泪的魂火",
            SeijaNerf = "极高概率抽出{{Card55}}",
        },
        en = {
            Name = "Book of Rune",
            Desc = "Return three, draw three...",
            Description = "{{Rune}} For every rune used in this room, draw one rune with a maximum of 3 runes"..
            "#{{Rune}} Allow Isaac to carry 2 cards whe he have a rune",
            BookOfVirtues = "If the rune is successfully drawn,spawn a wisp with a very low probability of spawning runes",
            SeijaNerf = "Highly chance to draw {{Card55}}",
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
            Description = "概率发射穿透并追踪敌人的蝴蝶眼泪"..
            "#蝴蝶会吸收敌方泪弹与硫磺火"..
            "#最后炸开并返还出来",
        },
        en = {
            Name = "Evil Intervention",
            Desc = "Embrace ominous",
            Description = "Probability to launch piercing and chasing evil tears"..
            "#Counteract enemy tear bullets, and fire brimstone after hitting the enemy",
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
            Description = "让角色能够跳跃着飞行",
            BookOfBelial = "从角色高度向下抛射眼泪",
            BookOfVirtues = "从角色高度向下飘落的魂火",
        },
        en = {
            Name = "How to Fly",
            Desc = "Tap Tap tap!",
            Description = "Enable characters to fly",
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
            Description = "!!! 一次性 "..
            "#{{Collectible580}} 向投掷方向连续开启红房间直至碰到边界",
        },
        en = {
            Name = "Illumination",
            Desc = "I",
            Description = "!!! SINGLE USE "..
            "#{{Collectible580}} Continuously open red room towards the throwing direction until it touches the boundary",
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
            Description = "{{Collectible628}} 进入新房间时，4%概率进入死亡证明层的随机房间，并在倒数随机1-3秒后立刻离开",
        },
        en = {
            Name = "Contemplation",
            Desc = "III",
            Description = "{{Collectible628}} When entering a new room, 4% chance to enter a random room in the death certificate level and leave immediately after a random 1-3 seconds",
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
            Description = "{{SecretRoom}} 在隐藏房中生成一个传送绳，通往一个额外的奖励房间",
        },
        en = {
            Name = "Chasm",
            Desc = "V",
            Description = "{{SecretRoom}}Spawns a conveyor rope in the secret room, leading to an additional reward room",
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
            Description = "防止爆炸伤害"..
            "#根据本局杀死的七罪小Boss获得效果："..
            "#嫉妒：眼泪获得穿透与灵体效果"..
            "#{{Card}} 贪婪：抽3张卡"..
            "#{{Collectible}} 傲慢：生成随机道具池三选一道具"..
            "#{{Card31}} 色欲：生成一张小丑卡"..
            "#{{Coin}} 懒惰：商店价格永久-1"..
            "#{{Card78}} 暴食：生成2个红钥匙碎片",
            BookOfBelial = "傲慢：生成恶魔道具池三选一道具",
        },
        en = {
            Name = "Book of 6 sin",
            Desc = "Except Anger",
            Description = "Grants immunity to explosions"..
            "#Obtain effects based on the Sins mini-Bosses killed in this game："..
            "#Envy：Grants spectral and piercing tear effects"..
            "#{{Card}} Greed: Draw 3 cards"..
            "#{{Collectible}} Pride: Allow Isaac to choose between 3 items."..
            "#{{Card31}} Lust:Spawns a Joker card"..
            "#{{Coin}} Sloth：Store Price -1"..
            "#{{Card78}} Gluttony: Spawns 2 red key fragments",
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
            Description = "{{Tears}} 受伤时失去一个被动道具并抵消伤害，随后+0.5射速"..
            "#优先失去低品质道具"..
            "#{{ArrowUp}} 失去此道具时，恢复所有以此法失去的道具",
            SeijaNerf = "不增加射速",
        },
        en = {
            Name = "Pathetique",
            Desc = "They die for me",
            Description = "{{Tears}} Lose a passive item on getting hit, counteract the damage and +0.5 Tears up"..
            "#Prioritize losing low-quality items"..
            "#{{ArrowUp}} When losing this item, restore all items lost using this method",
            SeijaNerf = "Doesn't grant tears up",
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
            Description = "{{Fear}} 50%概率抵消受到的伤害，并释放黑色眼睛恐惧敌人",
            SeijaNerf = "也会恐惧自己",
        },
        en = {
            Name = "Dark Mysticism",
            Desc = "Darkside Reproduction",
            Description = "{{Fear}} 50% probability of counteracting damage received and releasing black eyes to fear enemies",
            SeijaNerf = "Also fears Isaac",
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
            Description = "Obtain the effect of 3 random passive items",
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
            Description = "失去所有{{Heart}}红心，+1{{BrokenHeart}}碎心，将房间中道具转化为{{Collectible"..tostring(enums.Items.Fresh_Death).."}}鲜活死者",
            BookOfBelial = "{{Collectible"..tostring(enums.Items.Fresh_Death).."}}鲜活死者只提供恶魔道具池的被动效果",
            BookOfVirtues = "鲜活死者只提供天使道具池的被动效果",
            SeijaNerf = "+3碎心",
        },
        en = {
            Name = "The Suture Needle",
            Desc = "Left Ventricular Puncture",
            Description = "Lose all {{Heart}} red hearts，+1{{BrokenHeart}} broken hearts，convert pedestal in rooms into {{Collectible"..tostring(enums.Items.Fresh_Death).."}} Fresh Death",
            BookOfBelial = "Item Fresh Death only provide passive effects from devil item pool",
            BookOfVirtues = "Item Fresh Death only provide passive effects from angel item pool",
            SeijaNerf = "+3 broken hearts",
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
            "#20%概率偏折弹幕",
        },
        en = {
            Name = "Glaze Mirror",
            Desc = "Kind of dazzling",
            Description = "Spawns several glaze pickups on pickup"..
            "#20% chance to deflect enemy projectiles",
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
            Description = "进入房间时概率产生一次{{ColorPurple}}错认{{CR}}"..
            "#将一个敌人、掉落物或自身效果误认为存在第二份"..
            "#{{Pickup}} 未被消耗的幻象资源会在离开房间时消失"..
            "#在此之前使用它，则产生的结果将被保留"..
            "#幻象敌人能够攻击，但受伤后便会消失"..
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
            Description = "Entering a room may cause a {{ColorPurple}}misperception{{CR}}"..
            "#Mistakes an enemy, pickup, or one of your effects as having a second copy"..
            "#{{Pickup}} Unspent illusory resources disappear when leaving the room"..
            "#Spend them before then, and their consequences become real"..
            "#Illusory enemies can attack, but disappear when hit"..
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
            SeijaNerf = "Picked items have a 50% chance to be replaced as {{Collectible258}} Missing No",
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
            Description = "进入房间的一段时间内，旋转你的射击方向"..
            "#{{Tears}} +0.35射速"..
            "#{{Damage}} +2攻击",
            SeijaBuff = "+2射速"..
            "#瞄准线跟踪敌人",
        },
        en = {
            Name = "Cursed Mask",
            Desc = "You feel dizzy and dizzy",
            Description = "Rotate your shooting direction during a period of time after entering the room"..
            "#{{Tears}} +0.35 Tears up"..
            "#{{Damage}} +2 Damage up",
            SeijaBuff = "+2 Tears up"..
            "#Line of sight tracking enemy",
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
            "#击杀精英敌人也会少量补充对应颜色"..
            "#{{Room}} 清理房间后六颜色各流失3%"..
            "#颜色达到阈值时触发对应效果",
        },
        en = {
            Name = "Ritual Sting",
            Desc = "Color with blood",
            Description = "Sacrifice a held collectible to charge the selected color"..
            "#Defeating champions also charges their matching colors"..
            "#{{Room}} Clearing a room drains all six colors by 3%"..
            "#Crossing color thresholds activates their effects",
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
            Description = "此道具伴生有3个随机道具以供4选1"..
            "#{{Damage}} +0.33攻击"..
            "#拾取时向所有道具池加入两个{{Collectible"..tostring(enums.Items.Nihilistic_Artificial_Eye).."}}虚无假眼",
            SeijaNerf = "加快伴生道具环绕速度",
        },
        en = {
            Name = "Nihilistic Artificial Eye",
            Desc = "I can't see...",
            Description = "This item is accompanied by 3 random items to choose 1"..
            "#{{Damage}} +0.33 Damage up"..
            "#Add a {{Collectible"..tostring(enums.Items.Nihilistic_Artificial_Eye).."}} Nihilistic Artificial Eye into all itempools on pickup",
            SeijaNerf = "Accelerate the surrounding speed of accompanying items",
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
            Description = "{{Chargeable}} 蓄力发射阴影对接触的敌人造成伤害"..
            "#玩家受伤前与阴影换位并免伤",
            SeijaNerf = "加快阴影速度",
        },
        en = {
            Name = "Phantom Crown",
            Desc = "Mocking Nothingness",
            Description = "{{Chargeable}} Charge up and launch shadows to deal damage to enemies in contact"..
            "# Players should switch positions with shadows before getting injured and avoid damage",
            SeijaNerf = "Accelerate shadow speed",
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
            Description = "↑ 飞行"..
            "#{{Chargeable}} 靠近墙壁移动以蓄力，蓄力完成后无敌冲刺4秒并向后喷射30%攻击伤害的硫磺火",
        },
        en = {
            Name = "Blood Wing",
            Desc = "Flying + Harvesting Blood",
            Description = "↑ Flight"..
            "#{{Chargeable}} Move close to the wall to accumulate power, and after accumulating power, sprint invincibly for 4 seconds and spray 30% attack damage brimstones fire backwards",
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
            Description = "6个自动瞄准敌人的激光发射器 "..
            "#{{Chargeable}} 蓄力后分别发射造成30%攻击伤害的激光",
            SeijaNerf = "只有1个激光发射器",
        },
        en = {
            Name = "Subera Light",
            Desc = "Break the old days",
            Description = "6 laser launchers with automatic aiming at enemies "..
            "#{{Chargeable}} After accumulating power, fire lasers that deal 30% of attack damage each",
            SeijaNerf = "There is only one laser emitter",
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
            Description = "触发此道具使用次数因数的骰子的效果",
        },
        en = {
            Name = "D++",
            Desc = "Stitching to death",
            Description = "The effect of triggering the dice with the factor of the number of times this item is used",
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
            Description = "玩家攻击时从上空不断生成安全的导弹、激光炮进行自动攻击",
            SeijaNerf = "攻击落地后概率生成下层通道",
        },
        en = {
            Name = "Shangrila",
            Desc = "Kashtira Arrival",
            Description = "When players attack, they continuously generate safe missiles and laser cannons from above for automatic attacks",
            SeijaNerf = "Probability generation of lower level channels after attack landing",
        },
    },
    [116] = {
        Name = "命运锚点",
        id = Items.Destiny_Anchor,
        type = "active",
        xmlId = 127,
        zh = {
            Name = "命运锚点",
            Desc = "这一切都是命运石之门的选择",
            Description = "在当前房间设置命运锚点，每层最多设置3个"..
            "#{{ArrowDown}} 下层时，被锚定的房间会在新楼层复现"..
            "#优先替换相同类型的房间",
        },
        en = {
            Name = "Destiny Anchor",
            Desc = "This is the choice of Steins;Gate",
            Description = "Anchors the current room, up to 3 rooms per floor"..
            "#{{ArrowDown}} Anchored rooms reappear on the next floor"..
            "#Rooms of the same type are replaced first",
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
            Description = "{{RottenHeart}} 失去红心后填充一颗腐心"..
            "#{{BrokenHeart}} 失去心之容器后填充一颗碎心"..
            "#腐心与碎心相互抵消且不致死",
        },
        en = {
            Name = "Acrotomophilia",
            Desc = "Rotten and Broken",
            Description = "{{RottenHeart}} After losing the red heart, fill it with a rotten heart"..
            "#{{BrokenHeart}} After losing the container of the heart, fill it with a broken heart"..
            "#Rotten and broken hearts cancel each other out without causing death",
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
            Description = "角色死亡时随机生成一个其他角色，由其将角色复活"..
            "#此法生成的所有角色均死亡时游戏才结束",
        },
        en = {
            Name = "Loneliness",
            Desc = "Journey convergence",
            Description = "When a character dies, a random other character is generated to revive the character"..
            "# The game only ends when all characters generated by this method die",
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
            Description = "#!!! 最多可用10次"..
            "#从三种属性中挑选1项提升，降低另外2项属性"..
            "#耗尽后生成饰品{{Trinket"..enums.Trinkets.Broken_Brooch.."}}破碎的胸针",
        },
        en = {
            Name = "Core Brooch",
            Desc = "Sacrifice of Heavenly Selection",
            Description = "#!!! Can be used up to 10 times"..
            "# Select 1 attribute from three to improve and 2 attributes to decrease"..
            "# Generate trinket {{Trinket"..enums.Trinkets.Broken_Brooch.."}} after depletion",
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
            Description = "清理房间后有概率生成掉落物和道具的幻像"..
            "#仅当角色剩余最后一格血时，碰触幻像变为现实",
        },
        en = {
            Name = "Inspiration",
            Desc = "Redemption by Illusion",
            Description = "After cleaning the room, chance to generate illusions of pickups and trinkets. "..
            "#Only when the character has the last remaining health, touching the illusion becomes reality",
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
            "#杀死敌人时生成小饿魔咬咬敌人并将其恐惧",
            SeijaNerf = "饥饿的小饿魔追着玩家咬并逐渐损失生命",
        },
        en = {
            Name = "Hunger Burger",
            Desc = "Delicious finale",
            Description = "{{Heart}} +2 Heart Container"..
            "#{{Damage}} +1 Damage"..
            "#{{Speed}} +0.3 Move Speed"..
            "#Generate a little hungry demon to bite and scare enemies when killing them",
            SeijaNerf = "The little hungry demon chased after the player to bite and gradually lost their life",
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
            Description = "使用后，飞来一群彩色苍蝇："..
            "#!!! 66%概率留下数只彩虹苍蝇"..
            "#{{Trinket}} 33%概率留下随机饰品"..
            "#{{Beelzebub}} 1%概率留下随机道具",
            BookOfBelial = "留下的彩虹苍蝇变得血红，伤害路径上的敌人。留下的苍蝇被替换为{{Trinket113}}战争蝗虫",
            BookOfVirtues = "留下的苍蝇被替换为一颗彩虹魂火",
        },
        en = {
            Name = "Muscae Volitantes",
            Desc = "Magic of Flies",
            Description = "After use, a group of colorful flies come："..
            "#!!! 66% probability of leaving multiple rainbow flies"..
            "#{{Trinket}} 33% probability of leaving a random trinket"..
            "#{{Beelzebub}} 1% probability of leaving a random item",
            BookOfBelial = "The remaining rainbow flies turn blood red, and the enemies in their path are damaged. The remaining flies is replaced by a {{Trinket113}} War Locust.",
            BookOfVirtues = "The remaining flies is replaced as a rainbow wisp",
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
            Description = "进入楼层45秒后，黑潮开始从初始房向外蔓延"..
            "#黑潮逐渐吞噬地形与掉落物，但会避开可互动实体且不会伤害玩家"..
            "#{{Damage}} 黑潮对敌人每30帧造成7点伤害"..
            "#不会蔓延到其他维度",
            SeijaNerf = "黑潮的蔓延速度大幅提高"..
            "#黑潮避开所有掉落物，且不再吞噬它们",
        },
        en = {
            Name = "Charon's Sign",
            Desc = "The Tide is approaching",
            Description = "After 45 seconds on a floor, a black tide spreads outward from the starting room"..
            "#The tide gradually consumes terrain and pickups, but avoids interactive entities and cannot harm players"..
            "#{{Damage}} Deals 7 damage to enemies every 30 frames"..
            "#Does not spread across dimensions",
            SeijaNerf = "The tide spreads much faster"..
            "#The tide avoids all pickups and no longer consumes them",
        },
    },
    [124] = {
        Name = "宝宝泰克罗",
        id = Items.Baby_Tecro,
        type = "familiar",
        xmlId = 135,
        Hidden = "true",
        zh = {
            Name = "宝宝泰克罗",
            Desc = "我来刺穿！",
            Description = "{{Chargeable}} 蓄力发射自己的跟班"..
            "#在墙壁间快速弹射3次",
        },
        en = {
            Name = "Baby Tecro",
            Desc = "I find!",
            Description = "{{Chargeable}} Charge to launch the familiar"..
            "#Bounces between walls 3 times",
        },
    },
    [125] = {
        Name = "宝宝安娜",
        id = Items.Baby_Anna,
        type = "familiar",
        xmlId = 136,
        Hidden = "true",
        zh = {
            Name = "宝宝安娜",
            Desc = "我来吞噬！",
            Description = "{{Chargeable}} 蓄力发射自己的跟班"..
            "#飞行时留下硫磺火尾迹",
        },
        en = {
            Name = "Baby Anna",
            Desc = "I eat!",
            Description = "{{Chargeable}} Charge to launch the familiar"..
            "#Leaves a {{Collectible118}} Brimstone trail while flying",
        },
    },
    [126] = {
        Name = "宝宝泽伊斯",
        id = Items.Baby_Zeis,
        type = "familiar",
        xmlId = 137,
        Hidden = "true",
        zh = {
            Name = "宝宝泽伊斯",
            Desc = "我来知晓！",
            Description = "沉睡的跟班"..
            "#每层醒来并复制你见到的第一个道具",
        },
        en = {
            Name = "Baby Zeis",
            Desc = "I know!",
            Description = "Sleeping familiar"..
            "#Wakes each floor to copy the first pedestal item seen",
        },
    },
    [127] = {
        Name = "宝宝玛丽",
        id = Items.Baby_Marri,
        type = "familiar",
        xmlId = 138,
        Hidden = "true",
        zh = {
            Name = "宝宝玛丽",
            Desc = "我来质疑！",
            Description = "发射普通眼泪的跟班"..
            "#玩家受伤后临时提升伤害和攻速",
        },
        en = {
            Name = "Baby Marri",
            Desc = "I ask!",
            Description = "Familiar that shoots tears"..
            "#{{Damage}} {{Tears}} Temporary boost after taking damage",
        },
    },
    [128] = {
        Name = "宝宝艾提奥",
        id = Items.Baby_Autio,
        type = "familiar",
        xmlId = 139,
        Hidden = "true",
        zh = {
            Name = "宝宝艾提奥",
            Desc = "我来掌控！",
            Description = "飞向敌人的跟班"..
            "#{{Fear}} 在落点留下恐惧光圈，随后返回",
        },
        en = {
            Name = "Baby Autio",
            Desc = "I hang!",
            Description = "Familiar that teleports onto enemies"..
            "#{{Fear}} Leaves a fear aura, then returns",
        },
    },
    [129] = {
        Name = "宝宝露",
        id = Items.Baby_Lu,
        type = "familiar",
        xmlId = 140,
        Hidden = "true",
        zh = {
            Name = "宝宝露",
            Desc = "我来安排！",
            Description = "每层揭示3个特殊房间的跟班"..
            "#清理这些特殊房间后打开一个奖励房间",
        },
        en = {
            Name = "Baby Lu",
            Desc = "I plan!",
            Description = "Familiar that reveals 3 special rooms each floor"..
            "#Clearing them opens a reward room",
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
            Description = "拥有至少1格充能时即可使用"..
            "#消耗当前全部充能，向瞄准方向挥出重刃"..
            "#{{Damage}} 1格充能造成1点伤害，攻击范围为1"..
            "#每多1格充能，伤害与范围翻倍",
        },
        en = {
            Name = "Multiknife",
            Desc = "Ten years I honed this sword",
            Description = "Can be used with at least 1 charge"..
            "#Consumes all current charges to swing a heavy blade in the aiming direction"..
            "#{{Damage}} At 1 charge, deals 1 damage with 1 range"..
            "#Each additional charge doubles damage and range",
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
            Description = "{{Damage}} 1.5倍伤害"..
            "#{{AngelRoom}} 污染下一个天使房为{{DevilRoom}}恶魔房道具池，触发后+1攻击",
        },
        en = {
            Name = "Dragon Tooth",
            Desc = "Follow me into the abyss",
            Description = "{{Damage}} x1.5 Damage multiplier"..
            "#{{AngelRoom}} Pollution the next angel room into {{DevilRoom}} Devil Room item pool, after triggering +1 Damage",
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
            Description = "按"..eidButton(ButtonAction and ButtonAction.ACTION_DROP).."保留多选道具中的一个"..
            "#拾取保留项以在当前层试用道具，并在下层生成售价{{Coin}}15¢的对应道具"..
            "#主动也可保留；换下试用主动时，掉落的该主动消失",
            AbyssSynic = "白色蝗虫",
        },
        en = {
            Name = "Reserved Judgment",
            Desc = "This isn't final",
            Description = "Press "..eidButton(ButtonAction and ButtonAction.ACTION_DROP).." to reserve one item in an option group"..
            "#Each option group can hold 1 reserved item"..
            "#Pick up the reserved item to trial it this floor; next floor it returns for {{Coin}}15¢"..
            "#Actives can be reserved; swapping away a trial active removes its dropped pedestal",
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
            "#用字母拼出英文名，即可获得道具。=可代替名称中的符号"..
            "#{{Warning}} 集齐“FINAL”时，立即唤醒你的死亡终局",
            BookOfBelial = "始终额外拥有一个匹配恶魔房道具池道具时充当通配符的6",
            BookOfVirtues = "显示通灵字母的魂火，熄灭时再获得该字母",
        },
        en = {
            Name = "Death Sentence",
            Desc = "The sentence is final",
            Description = "Fully charged: automatically summon 1 random letter"..
            "#Use to open the prediction panel"..
            "#Spell an English name with letters to gain the item; = covers symbols"..
            "#{{Warning}} Spelling “FINAL” immediately wakes up your death end",
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
            Description = "使用后选择一个楼层并立即前往"..
            "#永久记录该传送渠道"..
            "#下次有玩家到达所选楼层时，将其传送回出发楼层",
        },
        en = {
            Name = "Remaster!",
			Desc = "Pressing on the bloody blinking button",
            Description = "On use, choose a floor and travel there"..
            "#Permanently records that teleport link"..
            "#The next time a player reaches the chosen floor, send them back to the origin floor",
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
            Description = "{{Coin}} 消耗金币抽奖"..
            "#生成金色奖励"..
            "#极小概率生成金奖杯或超大金箱",
        },
        en = {
            Name = "Golden Slot",
            Desc = "Insert coin to win!",
            Description = "{{Coin}} Spend coins to gamble"..
            "#Spawn golden rewards"..
            "#Tiny chance for a golden trophy or mega chest",
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
            Description = "{{Timer}} 每30秒 {{Damage}} +0.1"..
            "#本层最多 {{Damage}} +1"..
            "#击杀任意Boss后本层不再增长"..
            "#包含Boss敌人的房间门保持开启",
        },
        en = {
            Name = "Procrastination",
            Desc = "I'll do it soon...",
            Description = "{{Timer}} Every 30 seconds {{Damage}} +0.1"..
            "#Up to {{Damage}} +1 per floor"..
            "#Stops growing this floor after killing any boss"..
            "#Doors stay open in rooms with bosses",
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
            Description = "获得1个防护之心"..
            "#阻挡首个惩罚性伤害并释放心灵冲击波，然后转化为1个 {{Heart}} 心之容器"..
            "#冲击波每击杀1个敌人：获得 {{Damage}} x1.05 {{Shotspeed}} -0.02，每房间最多5次"..
            "#若房间内敌人≥5：冲击波无视护甲，并波及本层其他房间",
        },
        en = {
            Name = "Sacred Mind Shield",
            Desc = "Two hearts as one",
            Description = "Gain 1 protective heart"..
            "#Blocks the first punitive hit and releases a mind shockwave, then converts into 1 {{Heart}} heart container"..
            "#Per enemy killed by the wave: {{Damage}} x1.05 {{Shotspeed}} -0.02, up to 5 per room"..
            "#If 5+ enemies in the room: wave ignores armor and spreads to other rooms this floor",
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
            Desc = "连错误也会被继承",
            Description = "本局的行为会塑造一个{{ColorYellow}}世纪{{CR}}"..
            "#本局结束时，为下一局留下对应的{{ColorYellow}}遗产{{CR}}与{{ColorRed}}代价{{CR}}"..
            "#世纪仅影响下一局一次"..
            "#{{DeathMark}} 死亡也会留下世纪"..
            "#{{Player}} 重开不会进行结算",
        },
        en = {
            Name = "Regenesis",
            Desc = "Even mistakes are inherited",
            Description = "This run's actions shape an {{ColorYellow}}Age{{CR}}"..
            "#When the run truly ends, the next run inherits its {{ColorYellow}}legacy{{CR}} and {{ColorRed}}cost{{CR}}"..
            "#The Age lasts for the next run only"..
            "#{{DeathMark}} Death still leaves an Age"..
            "#{{Player}} Restarting does not settle",
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
            Description = "{{Shop}} 商品价格改为总平均数上取整",
        },
        en = {
            Name = "Pacification Mark",
            Desc = "Fair means profitable",
            Description = "{{Shop}} Change the product price to round up of the total average",
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
            Description = "{{BlackHeart}} 初次拾取时+1黑心"..
            "#{{BrokenHeart}} 初次失去时+1碎心",
            goldenTrinket = {t={1,1,},},
        },
        en = {
            Name = "Dark Particle",
            Desc = "Flammable and delicious",
            Description = "{{BlackHeart}} +1 black heart when first pick"..
            "#{{BrokenHeart}} +1 broken heart when first lose",
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
            Description = "进入新房间时25%概率随机开启1扇通往其他房间的门",
            goldenTrinket = {t = {1,},},
        },
        en = {
            Name = "Torn Emperor",
            Desc = "Oppose esoteric!",
            Description = "25% Chance to randomly open 1 door when entering a new room",
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
            Description = "!!! 初次拾取时失去所有掉落物"..
            "#{{Damage}} 永久+1攻击",
            goldenTrinket = {t={1,},},
        },
        en = {
            Name = "Hoarding Symbol",
            Desc = "Reconstruction",
            Description = "!!! Lose all pickups on first pickup"..
            "#{{Damage}} +1 Damage up",
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
            Description = "{{ErrorRoom}} 进入新房间时，2%概率进入错误房",
            goldenTrinket = {t={2,},},
        },
        en = {
            Name = "Transition Symbol",
            Desc = "Away",
            Description = "{{ErrorRoom}} 2% Chance to enter error room when entering a new room",
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
            Description = "放下此饰品时击落所有弹幕",
        },
        en = {
            Name = "Straining Symbol",
            Desc = "Depression",
            Description = "Shoot down all projectiles when placing this trinket",
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
            "#{{Timer}} 暂停游戏后失去此饰品",
        },
        en = {
            Name = "Pause？",
            Desc = "A Real time game!",
            Description = "{{ArrowUp}} Stats Up"..
            "#{{Timer}} Lose this trinket after pausing the game",
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
            Description = "若你没有任何{{Coin}}硬币，{{Shop}}商店只会出售{{Collectible}}道具",
        },
        en = {
            Name = "Equality Agreement",
            Desc = "Seemingly equal",
            Description = "If you have no {{Coin}} coin，{{Shop}}Shop will only provide {{Collectible}} collectible",
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
            Description = "{{Shop}} 商品价格至多为1{{Coin}}硬币，但降价越多越可能白花钱"..
            "#商品的折扣就是成功购买概率",
        },
        en = {
            Name = "Consistent Expectations",
            Desc = "Equal in Expection",
            Description = "All shop price is only 1 {{Coin}} coin, but there ara chance to waste money"..
            "#The discount on the product is the probability of successful purchase",
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
            "#{{ArrowUp}} 完成交易后随机一份商品变为免费",
        },
        en = {
            Name = "Bundled Sale",
            Desc = "Buy more, get more",
            Description = "{{Shop}} Product prices increase by 100%"..
            "#{{ArrowUp}} After completing the transaction, randomly select a product to become free",
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
            Description = "清理房间后小概率随机提升最低属性",
        },
        en = {
            Name = "Broken Brooch",
            Desc = "Time is enough to change everything",
            Description = "After cleaning the room, there is a small probability of randomly increasing the lowest attribute",
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
            Description = "将所有掉落物转化为它们的琉璃版本 "..
            "#将房间内所有道具变成与他们同色的随机道具"..
            "#!!! 一个道具可能有多种颜色",
            Frame = 0,
        },
        en = {
            Name = "Glaze Dice Shard",
            Desc = "Looking for Assimilation",
            Description = "Converts all pickups to the glazed type."..
            "#Morph all items in the room to the same color item.",
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
            Description = "连续发射若干把帅气飞刀",
            Frame = 1,
        },
        en = {
            Name = "Qing's Soul",
            Desc = "Namely Safe",
            Description = "Fire several stab knife.",
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
            Description = "!!! 召唤一辆列车撞向选定方向",
            Frame = 2,
        },
        en = {
            Name = "Round trip Rail Ticket",
            Desc = "Granting one meal",
            Description = "Summon a train rushing to you."..
            "#Spawn a One way rail ticket.",
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
            Description = "!!! 再次召唤列车",
            Frame = 3,
        },
        en = {
            Name = "One way Rail Ticket",
            Desc = "Welcome again!",
            Description = "Summon a train rushing to you.",
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
            Description = "持有此魂石时受伤或使用后向八向刺出长枪",
            Frame = 54,
        },
        en = {
            Name = "Tecro's Soul",
            Desc = "I Hate",
            Description = "Injured while holding this soul stone or using it will fire eight way spears",
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
            Description = "地上的此魂石自动飞向敌人并爆炸"..
            "#使用时触发一次安全的爆炸",
            Frame = 55,
        },
        en = {
            Name = "Anna's Soul",
            Desc = "I Want",
            Description = "The soul stone on the ground automatically flies towards the enemy and explodes"..
            "#Trigger an explosion that does not harm Isaac on use",
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
            Description = "为房间中所有道具生成与其编号临近的若干个道具进行多选一"..
            "#需要足够空间生成道具",
            Frame = 56,
        },
        en = {
            Name = "Zeis's Soul",
            Desc = "I Know",
            Description = "Generate multiple items adjacent to their numbers for all items in the room to choose from"..
            "#Need enough space to generate items",
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
            Description = "平衡你的金币、钥匙与炸弹"..
            "#余数转化为硬币、炸弹、钥匙三选一",
            Frame = 14,
            tarotClothBuffs = "根据此次平衡改变的基础数量，获得属性提升",
        },
        en = {
            Name = "VIII - Adjustment",
            Description = "Balance your coins, keys and bombs"..
            "#Convert the remainder into pickups of coins, bombs and keys",
            Frame = 14,
            tarotClothBuffs = "Get attribute improvement according to the amount of this balance change",
        },
    },
    [9] = {
        Name = "VIII - 调节?",
        id = Cards.Adjustment_r,
        zh = {
            Name = "VIII - 调节?",
            Desc = "与其纷争，莫如没收",
            Description = "{{ArrowUp}} 将你的全部基础掉落转化为属性",
            Frame = 36,
            tarotClothBuffs = "50%概率再次掉落此卡",
        },
        en = {
            Name = "VIII - Adjustment?",
            Description = "Convert all your basic pickups into attributes",
            Frame = 36,
            tarotClothBuffs = "50% chance to spawn this card again",
        },
    },
    [10] = {
        Name = "XX - 永恒",
        id = Cards.Aeon,
        zh = {
            Name = "XX - 永恒",
            Desc = "引导永恒的哀悼",
            Description = "{{EternalHeart}} 持有此卡受伤时，有概率掉落一个白心"..
            "#{{Confessional}} 使用后生成一台忏悔机",
            Frame = 26,
            tarotClothBuffs = "生成两台忏悔机",
        },
        en = {
            Name = "XX - The Aeon",
            Description = "Holding this card when you are hurt, provide a chance to drop a eternal heart "..
            "#Use it to generate a repentance machine",
            Frame = 26,
            tarotClothBuffs = "Generate 2 machine",
        },
    },
    [11] = {
        Name = "XX - 永恒?",
        id = Cards.Aeon_r,
        zh = {
            Name = "XX - 永恒?",
            Desc = "瞬间即成永恒",
            Description = "{{ArrowUp}} 全属性大幅上升"..
            "#!!! 角色的任意动作都会减少属性上升量"..
            "#清理房间后少量提升全属性",
            Frame = 50,
            tarotClothBuffs = "额外提升属性上升量",
        },
        en = {
            Name = "XX - The Aeon?",
            Description = "Greatly increase all attributes"..
            "#When one of the following triggers, the increase will be reduced"..
            "#1. Gain or lose pickups or HP"..
            "#2. Gain or lose trinkets or items"..
            "#3. Gain cards and pills"..
            "#Before the increase is reduced to 0, each time you clear the room, slightly increase all attributes",
            Frame = 50,
            tarotClothBuffs = "Increase more attributes",
        },
    },
    [12] = {
        Name = "XIV - 艺术",
        id = Cards.Art,
        zh = {
            Name = "XIV - 艺术",
            Desc = "超绝!豪快!闷绝!优雅!超级!究极超级!",
            Description = "{{ArrowUp}} 使用后，30s内，击杀生命值在10%以下的敌人会随机奖励掉落物"..
            "#对boss无效",
            Frame = 20,
            tarotClothBuffs = "效果时间翻倍",
        },
        en = {
            Name = "XIV - Art",
            Description = "kill enemies with HP less than 10% within 30s will randomly reward pickups"..
            "#Invalid for bosses",
            Frame = 20,
            tarotClothBuffs = "within 60s",
        },
    },
    [13] = {
        Name = "XIV - 艺术?",
        id = Cards.Art_r,
        zh = {
            Name = "XIV - 艺术?",
            Desc = "艺术，就是爆炸",
            Description = "本房间内，引爆所有消失的实体"..
            "#每次爆炸会变得更加猛烈"..
            "#{{Timer}} 地上的此卡每隔6秒爆炸一次",
            Frame = 44,
            tarotClothBuffs = "使用后引发的是安全的爆炸",
        },
        en = {
            Name = "XIV - Art?",
            Description = "In this room, detonate all disappeared entities "..
            "#Each explosion will become more violent"..
            "#This card on the ground explodes every 6 seconds",
            Frame = 44,
            tarotClothBuffs = "The explosion will not harm the user",
        },
    },
    [14] = {
        Name = "VII - 巨炮",
        id = Cards.Chariot,
        zh = {
            Name = "VII - 巨炮",
            Desc = "大地因我的到来而鸣响",
            Description = "向攻击方向发射1枚300点伤害继承攻击特效的超大导弹",
            Frame = 13,
            tarotClothBuffs = "三向发射3枚超大导弹",
        },
        en = {
            Name = "VII - Chariot",
            Description = "Launch a super missile with 300 damage points in the attack direction",
            Frame = 13,
            tarotClothBuffs = "Launch 3 in three directions",
        },
    },
    [15] = {
        Name = "VII - 巨像?",
        id = Cards.Chariot_r,
        zh = {
            Name = "VII - 巨像?",
            Desc = "次元· 陷阱· 金字塔",
            Description = "交替设下5张陷阱"..
            "#不同的陷阱对敌人有不同的效果",
            Frame = 35,
            tarotClothBuffs = "翻倍陷阱可使用次数",
        },
        en = {
            Name = "VII - The Chariot?",
            Description = "#Set 5 traps:#Mirror Force:Release a shock wave same as {{Collectible"..tostring(Items.Lofty).."}} with 100 damage to enemies stepped on it#Magic Cylinder：Convert the projectiles into tears, disappear after 10 times#Skill Drain:Seal the enemy stepped on it for 10s(3s for bosses),disappear after 3 times#Great Universe:Randomly transfer enemies step on it and reduce their HP by 50%,disappear after 5 times#Void Space:Reduce the life of newly generated enemy to 1(20% to the boss),disappear after 2 times",
            Frame = 35,
            tarotClothBuffs = "Double the usable time",
        },
    },
    [16] = {
        Name = "XIII - 尸首?",
        id = Cards.Corpse_r,
        zh = {
            Name = "XIII - 尸首?",
            Desc = "心怀异端",
            Description = "{{RottenHeart}} 将你的红心或腐心向后吐出并转化为腐心，放出毒性气体伤害敌人"..
            "#{{ArrowUp}} 吐尽红心后，仍然有10%概率吐出腐心",
            Frame = 43,
            tarotClothBuffs = "概率提升至25%",
        },
        en = {
            Name = "XIII - The Corpse?",
            Description = "Spit your red heart or rotten heart and turn it into rotten heart, and release toxic gas to hurt the enemy "..
            "#After spitting out all your red heart, there is still a 10% probability of spitting out rotten heart",
            Frame = 43,
            tarotClothBuffs = "Higher chance to 25%",
        },
    },
    [17] = {
        Name = "XIII - 死神?",
        id = Cards.Death_r,
        zh = {
            Name = "XIII - 死神?",
            Desc = "如此，我就能满足了",
            Description = "立即放下你的主动、卡牌/药丸、饰品"..
            "#{{ArrowUp}} 属性大幅提升直到上述栏位有一项非空"..
            "#副手主动拾取后回到原位",
            Frame = 42,
        },
        en = {
            Name = "XIII - Death?",
            Description = "Put down your active item,cards/pills and trinkets immediately"..
            "#Gain all stats up until one of the above fields is not empty"..
            "#The second hand active item returns to the original position after being picked up",
            Frame = 42,
        },
    },
    [18] = {
        Name = "XV - 邪心",
        id = Cards.Devil,
        zh = {
            Name = "XV - 邪心",
            Desc = "灵魂算子：重生",
            Description = "{{DevilRoom}} 持有此卡时死亡：在恶魔房复活并失去此卡"..
            "#使用后，主动触发上述效果",
            Frame = 21,
            tarotClothBuffs = "主动使用时保留此卡",
        },
        en = {
            Name = "XV - The Devil",
            Description = "Death while holding this card:revive in the devil room and lose this card "..
            "#When use:activate above effect",
            Frame = 21,
            tarotClothBuffs = "Keep this card when you use it",
        },
    },
    [19] = {
        Name = "XV - 邪心?",
        id = Cards.Devil_r,
        zh = {
            Name = "XV - 邪心?",
            Desc = "虚无解械",
            Description = "{{DevilRoom}} 生成一个临时的撒旦与你交易"..
            "#交易内容："..
            "#随机基础掉落"..
            "#随机道具"..
            "#随机恶魔房道具"..
            "#出房间后交易和撒旦均不保留"..
            "#!!! 炸毁撒旦雕像可以抢夺交易",
            Frame = 45,
            tarotClothBuffs = "交易数量增加",
        },
        en = {
            Name = "XV - The Devil?",
            Description = "Generate a temporary Satan to trade with you"..
            "#Trade and Satan are not reserved after leaving the room"..
            "#Blow up the statue of Satan: you can seize the trade, but you must defeat Mr. Satan first",
            Frame = 45,
            tarotClothBuffs = "Increase in the number of trades",
        },
    },
    [20] = {
        Name = "XIX - 日食",
        id = Cards.Eclipse,
        zh = {
            Name = "XIX - 日食",
            Desc = "永夜将至",
            Description = "生成一道旋涡将敌人吸入并从上方吐出",
            Frame = 52,
            tarotClothBuffs = "翻倍旋涡持续时长",
        },
        en = {
            Name = "XIX - Eclipse",
            Description = "Generate a vortex to suck in the enemy and spit them out from above",
            Frame = 52,
            tarotClothBuffs = "Double the duration of the vortex",
        },
    },
    [21] = {
        Name = "XIX - 食日?",
        id = Cards.Eclipse_r,
        zh = {
            Name = "XIX - 食日?",
            Desc = "极昼重临",
            Description = "召唤巨大的落日，对敌人发射密集激光造成伤害"..
            "#!!! 橙色激光攻击角色"..
            "#下层后结束食日",
            Frame = 53,
            tarotClothBuffs = "落日造成的伤害翻倍",
        },
        en = {
            Name = "XIX - Eclipse?",
            Description = "Summoning a huge sunset, causing damage to enemies by firing dense light "..
            "#!!! Orange light attack Isaac "..
            "# Ends Eclipse After Level",
            Frame = 53,
            tarotClothBuffs = "Double the damage caused by sunset",
        },
    },
    [22] = {
        Name = "IV - 帝王",
        id = Cards.Emperor,
        zh = {
            Name = "IV - 帝王",
            Desc = "命运的囚徒",
            Description = "封闭当前房间的门"..
            "#在墙边尽可能地生成通往其他房间的门"..
            "#也可能生成不在地图上房间的门"..
            "#{{ArrowUp}} 角色能飞时，可以开门的位置更多",
            Frame = 10,
            tarotClothBuffs = "提升通往特殊房间的门的生成率",
        },
        en = {
            Name = "IV - The Emperor",
            Description = "Close the doors of the current room"..
            "#Try to generate as many doors to other rooms on the wall as possible"..
            "#Chance to generate doors to room that's not on the map",
            Frame = 10,
            tarotClothBuffs = "Increase the generation rate of doors to special rooms",
        },
    },
    [23] = {
        Name = "IV - 帝王?",
        id = Cards.Emperor_r,
        zh = {
            Name = "IV - 帝王?",
            Desc = "二日齐天",
            Description = "召唤一个随机boss，战胜它可以生成它的永久友方复制"..
            "#{{Damage}} 持有此卡且位于{{BossRoom}}boss房/{{ChallengeRoom}}挑战房/{{BossRushRoom}}Bossrush房间：+1攻击",
            Frame = 32,
            tarotClothBuffs = "改为+2攻击",
        },
        en = {
            Name = "IV - The Emperor?",
            Description = "Summon a random boss"..
            "#Defeat it will generate a friendly version of the boss"..
            "#+1 damage when in boss room/challenge room/Bossrush",
            Frame = 32,
            tarotClothBuffs = "+2 damage",
        },
    },
    [24] = {
        Name = "III - 女帝",
        id = Cards.Empress,
        zh = {
            Name = "III - 女帝",
            Desc = "我最爱互相残杀的剧本了",
            Description = "{{Charm}} 魅惑房间内生命值非最高的所有怪物，其生命值降至10%，削弱的生命值补充给生命最高的敌人"..
            "#生命值最高的敌人变为彩虹变异",
            Frame = 9,
            tarotClothBuffs = "降至20%",
        },
        en = {
            Name = "III - The Empress",
            Description = "Charm all monsters with not highest HP"..
            "#Reduce their health to 10% and add them to the highest one"..
            "#Invalid for bosses",
            Frame = 9,
            tarotClothBuffs = "Reduce to 20%",
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
            Description = "{{IsaacsRoom}} 生成一张床"..
            "#用此床入睡后，传送至随机房间，并改变本层所有房间的背景"..
            "#离开本房间后此床消失"..
            "#{{BarrenRoom}} 概率生成坏床：入睡后无法传送",
            Frame = 19,
            tarotClothBuffs = "入睡后额外获得一层{{Collectible313}}",
        },
        en = {
            Name = "XIII - Faint",
            Description = "Generate a bed"..
            "#After sleeping on this bed,be transmitted to a random room and the background of all rooms this floor will be changed"..
            "#Remove the bed after leaving the room"..
            "#Chance of 1/5 generating a bad bed which can't teleport you.",
            Frame = 19,
            tarotClothBuffs = "Gain one layer of {{Collectible313}} after sleeping",
        },
    },
    [27] = {
        Name = "XIII - 长眠?",
        id = Cards.Faint_r,
        zh = {
            Name = "XIII - 长眠?",
            Desc = "生死交辉",
            Description = "!!! 本房间内全属性暂时下降"..
            "#本房间内受伤后，随机掉落魂心、红心"..
            "#店长改为掉落硬币",
            Frame = 41,
            tarotClothBuffs = "大幅下降你的全属性，基础掉落概率更高，受伤后也会掉落其他基础",
        },
        en = {
            Name = "XIII - Faint?",
            Description = "Reduced all attributes in this room temporarily"..
            "#Chance to spawn soul heart and red heart after being injured in this room",
            Frame = 41,
            tarotClothBuffs = "Reduced much more attributes and provide higher chance to spawn hearts#Also have chance to spawn other pickups",
        },
    },
    [28] = {
        Name = "0 - 旅者",
        id = Cards.Fool,
        zh = {
            Name = "0 - 旅者",
            Desc = "所遗者广",
            Description = "从当前房间道具池中抽取5个道具，并生成其中等级最高道具对应魂火",
            Frame = 4,
            tarotClothBuffs = "改为抽取8个道具",
        },
        en = {
            Name = "0 - The Fool",
            Description = "Remove 5 items from the itempool and generate the corresponding wisp of the highest quality item",
            Frame = 4,
            tarotClothBuffs = "Remove 8 instead of 5",
        },
    },
    [29] = {
        Name = "0 - 旅者?",
        id = Cards.Fool_r,
        zh = {
            Name = "0 - 旅者?",
            Desc = "所知者稀",
            Description = "从本房间道具池中预知一个道具，下一个生成的道具改为和它一起多选一",
            Frame = 28,
            tarotClothBuffs = "预知三个道具",
        },
        en = {
            Name = "0 - The Fool?",
            Description = "Predict an item from the item pool in this room. The next generated item can be choosed with it",
            Frame = 28,
            tarotClothBuffs = "Predict 3 items",
        },
    },
    [30] = {
        Name = "XII - 缚者",
        id = Cards.Hanged_Man,
        zh = {
            Name = "XII - 缚者",
            Desc = "倒错回环",
            Description = "{{ThothCard2}} 将本层所有卡牌变为倒位置",
            Frame = 18,
            tarotClothBuffs = "额外生成此卡",
        },
        en = {
            Name = "XII - The Hanged Man",
            Description = "#Change all cards on this floor to the reverse position#Used with card {{Card"..tostring(Cards.Hanged_Man_r).."}}:Turn over cards repeatedly until it detonates, then grants 10% probability of transmitting it to the error room and clear this effect",
            Frame = 18,
            tarotClothBuffs = "Spawn this card again",
        },
    },
    [31] = {
        Name = "XII - 缚者?",
        id = Cards.Hanged_Man_r,
        zh = {
            Name = "XII - 缚者?",
            Desc = "环回错倒",
            Description = "{{ThothCard}} 将本层所有卡牌变为正位置",
            Frame = 40,
            tarotClothBuffs = "并生成此卡",
        },
        en = {
            Name = "XII - The Hanged Man?",
            Description = "#Change all cards on this floor to the positive position#Used with card {{Card"..tostring(Cards.Hanged_Man).."}}:Turn over cards repeatedly until it detonates, then grants 10% probability of transmitting it to the error room and clear this effect",
            Frame = 40,
            tarotClothBuffs = "Spawn this card again",
        },
    },
    [32] = {
        Name = "IX - 隐者",
        id = Cards.Hermit,
        zh = {
            Name = "IX - 隐者",
            Desc = "你的过去萦绕在心",
            Description = "随机生成一个本局失去过的道具，优先选择被动道具"..
            "#{{Collectible36}} 没有这样的道具：生成摸过的大便",
            Frame = 15,
            tarotClothBuffs = "在至多三个失去道具中选择其一获得",
        },
        en = {
            Name = "IX - The Hermit",
            Description = "Randomly generate a lost item"..
            "#Give priority to passive items"..
            "#None:Spawn a touched {{Collectible36}}",
            Frame = 15,
            tarotClothBuffs = "Choose one of the three lost items",
        },
    },
    [33] = {
        Name = "IX - 隐者?",
        id = Cards.Hermit_r,
        zh = {
            Name = "IX - 隐者?",
            Desc = "跨越千年的命运",
            Description = "随机失去至多3个道具并生成一个道具"..
            "#失去的道具会与之后见到的第7个道具一同生成(不刷新状态)"..
            "#不会失去副手主动",
            Frame = 37,
            tarotClothBuffs = "额外失去2个道具，生成一个二选一道具",
        },
        en = {
            Name = "IX - The Hermit?",
            Description = "Lose up to 3 items randomly and generate one item"..
            "#The lost items will be generated together with the seventh item seen later (their status will not be refreshed)",
            Frame = 37,
            tarotClothBuffs = "Lose 2 items more and generate 2 items to choose one.",
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
            Desc = "...魔入将我",
            Description = "{{AngelRoom}} 失去本局所有在天堂房拾取过的道具以及同名道具"..
            "#{{DevilRoom}} 这样的道具每有一个，获得一份来自恶魔的奖励",
            Frame = 33,
            tarotClothBuffs = "若失去的道具有对应魂火，则生成它们的脆弱版本",
        },
        en = {
            Name = "V - The Hierophant?",
            Description = "Lose all items picked up in the Angel Room and the items with the same name"..
            "#Every time you lose one item in this way:"..
            "#6%: generate 1-2 black hearts"..
            "#66%: generate 1-2 devil room items"..
            "#1%: +6.66 damage "..
            "#6%: +0.66 damage"..
            "#1%: +0.66 speed"..
            "#6%: +0.11 speed"..
            "#1%: generate 66 coins"..
            "#6%: generate 6 random pickups"..
            "#1%: gain devil transformation"..
            "#6%: generate a {{Card31}}",
            Frame = 33,
            tarotClothBuffs = "Generate a fragile item wisp for each item removed in this way.",
        },
    },
    [36] = {
        Name = "I - 魔启",
        id = Cards.Invoker,
        zh = {
            Name = "I - 魔启",
            Desc = "我将启迪",
            Description = "{{Card}} 预知并记录一张塔罗牌"..
            "#使用那张塔罗牌的时候，生成此卡和一张随机卡牌",
            Frame = 6,
            tarotClothBuffs = "预知3张卡，额外生成一张随机卡",
        },
        en = {
            Name = "I - The Invoker",
            Description = "Predict and record a tarot card "..
            "#When using that tarot card, generate this card and a random card",
            Frame = 6,
            tarotClothBuffs = "Predict 3 cards, generate 2 random cards",
        },
    },
    [37] = {
        Name = "VI - 爱",
        id = Cards.Lover,
        zh = {
            Name = "VI - 爱",
            Desc = "吾爱自鸣",
            Description = "{{ArrowUp}} 本房间内，拾取基础掉落改为获得临时属性提升，并有50%概率再次生成一个基础掉落",
            Frame = 12,
            tarotClothBuffs = "75%概率再次生成",
        },
        en = {
            Name = "VI - Lover",
            Description = "In this room, picking up pickups will gain temporary attribute improvement instead of the actual effect, with 50% probability of generating another pickup again",
            Frame = 12,
            tarotClothBuffs = "75% chance",
        },
    },
    [38] = {
        Name = "VI - 爱?",
        id = Cards.Lover_r,
        zh = {
            Name = "VI - 爱?",
            Desc = "直到血流成河",
            Description = "{{Collectible}} 生成0-4级被动道具各一个进行五选一"..
            "#!!! 若进行拾取，与那个道具相同等级的被动道具全部转化为同名魂火，道具池内的所有同等级道具改为此道具"..
            "#!!! 忤逆爱人将会受到心碎的惩罚",
            Frame = 34,
            tarotClothBuffs = "改为各2个进行十选一",
        },
        en = {
            Name = "VI - The Lover?",
            Description = "Generate a set of item with quality from 0-4 and choose one from five"..
            "#If one of the item is choiced,all items of the same quality as that item will be converted into fragile item wisp.All items with the same quality in item pool will be replaced with this item"..
            "#!!! Disobedience to your lover will be punished with heartbreak",
            Frame = 34,
            tarotClothBuffs = "Generate 2 set of item and choose one from ten",
        },
    },
    [39] = {
        Name = "XI - 欲望",
        id = Cards.Lure,
        zh = {
            Name = "XI - 欲望",
            Desc = "释放他们内心的猛兽",
            Description = "本房间内，略微加速所有敌人，他们受到的伤害提升固定值5点",
            Frame = 17,
            tarotClothBuffs = "固定值提升至10点",
        },
        en = {
            Name = "XI - Lure",
            Description = "In this room, slightly accelerate all enemies, damage they take will be increased by 5",
            Frame = 17,
            tarotClothBuffs = "increased by 10",
        },
    },
    [40] = {
        Name = "XI - 欲望?",
        id = Cards.Lure_r,
        zh = {
            Name = "XI - 欲望?",
            Desc = "顺从你内心的奴隶",
            Description = "!!! 持有时，每次受到的伤害不低于1.5格心"..
            "#受伤无敌也相应延长"..
            "#{{SoulHeart}} 使用后，根据持有此卡的受伤次数生成等量魂心",
            Frame = 39,
            tarotClothBuffs = "生成等量混合心",
        },
        en = {
            Name = "XI - Lure?",
            Description = "When you hold this card, you will take at least one half heart each time."..
            "#After using this card, generate an equal amount of soul heart according to the number of times you are injured",
            Frame = 39,
            tarotClothBuffs = "Generate mixed hearts.",
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
            Description = "{{Fear}} 恐惧房间内所有敌人2分钟"..
            "#!!! 恐惧角色10秒"..
            "#!!! 被恐惧时受到3倍伤害"..
            "#击杀恐惧的敌人有概率掉落此卡",
            Frame = 48,
            tarotClothBuffs = "永久恐惧房间内所有敌人，恐惧角色20秒",
        },
        en = {
            Name = "XVIII - A?",
            Description = "Frighten 2 minutes for all enemies in the room"..
            "#Frighten player for 10 seconds"..
            "#Suffer 3 times the damage when being frightened"..
            "#killing feard enemies have a chance to drop this card again",
            Frame = 48,
            tarotClothBuffs = "Frighten enemies eternally#Frighten player for 20 seconds",
        },
    },
    [43] = {
        Name = "II - 女司祭",
        id = Cards.Priestess,
        zh = {
            Name = "II - 女司祭",
            Desc = "妈妈?是妈妈!",
            Description = "角色巨大化"..
            "#攻击方式改为操纵妈腿攻击"..
            "#妈腿造成角色攻击40倍的伤害"..
            "#蓄力时长为10倍角色延迟"..
            "#持续30s"..
            "#可叠加",
            Frame = 8,
            tarotClothBuffs = "持续时长翻倍",
        },
        en = {
            Name = "II - The High Priestess",
            Description = "Temperorily size up"..
            "#Change your attack method to manipulating mom's stomp"..
            "#mom's stomp cause 40 times the damage of player"..
            "#10 times the firedelay of player to charge "..
            "#Lasts for 30 second "..
            "#Stackable",
            Frame = 8,
            tarotClothBuffs = "Double the duration",
        },
    },
    [44] = {
        Name = "II - 女司祭?",
        id = Cards.Priestess_r,
        zh = {
            Name = "II - 女司祭?",
            Desc = "和妈妈抱抱！",
            Description = "额外发射略微跟踪的准星，命中敌人则会降下妈手"..
            "#妈手捕获敌人后可以控制其一段时间"..
            "#持续30s",
            Frame = 30,
            tarotClothBuffs = "捕获结束后妈手会抓走敌人，随后带着成为友方的敌人重新出现#对boss无效",
        },
        en = {
            Name = "II - The High Priestess?",
            Description = "Fire a slightly tracked mark when you attack"..
            "#Spawn a mother's hand to catpure and freeze the enemy for a period of time."..
            "#Lasts for 30 seconds",
            Frame = 30,
            tarotClothBuffs = "Mother's hand will take the enemy away and turn it to be a friendly one.",
        },
    },
    [45] = {
        Name = "XXI - 深邃",
        id = Cards.Profound,
        zh = {
            Name = "XXI - 深邃",
            Desc = "有物井中来",
            Description = "持有此卡下层时+1{{SuperSecretRoom}}超级隐藏房"..
            "#{{SuperSecretRoom}} 使用后传送到超级隐藏房",
            Frame = 57,
            tarotClothBuffs = "+2{{SuperSecretRoom}}超级隐藏房",
        },
        en = {
            Name = "XXI - Profound",
            Description = "+1{{SuperSecretRoom}} Super Secret Room next level while holding it"..
            "#{{SuperSecretRoom}} Teleports Isaac to the Super Secret Room",
            Frame = 57,
            tarotClothBuffs = "+2{{SuperSecretRoom}} Super Secret Room",
        },
    },
    [46] = {
        Name = "XXI - 深邃?",
        id = Cards.Profound_r,
        zh = {
            Name = "XXI - 深邃?",
            Desc = "不见天月明",
            Description = "传送到一个迷宫房间，听声音寻找规律通过数道门后奖励隐藏道具三选一",
            Frame = 58,
            tarotClothBuffs = "奖励为四选一",
        },
        en = {
            Name = "XXI - Profound?",
            Description = "Transfer to a maze room.Listen to the sound and find patterns. After passing several gates, reward 3 items from secret room to choose in one",
            Frame = 58,
            tarotClothBuffs = "Rewards 4 items to choose",
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
            Description = "若此卡为本层使用的第一张卡，生成1个魂心、1个白心、1个红心"..
            "#否则，生成1个半红心",
            Frame = 23,
            tarotClothBuffs = "满足条件：额外生成一个混合心、一个黑心、一个骨心",
        },
        en = {
            Name = "XVII - The Star",
            Description = "If this card is the first card used in this level: generate a soul heart, a eternal heart,a red heart."..
            "#Otherwise: generate a half red heart.",
            Frame = 23,
            tarotClothBuffs = "First card: generate an additional mixed heart,a black heart and a bone heart.",
        },
    },
    [49] = {
        Name = "XVII - 星辰?",
        id = Cards.Star_r,
        zh = {
            Name = "XVII - 星辰?",
            Desc = "他们灿若繁星",
            Description = "{{Collectible651}} 点亮房间内的敌人并为其添加光环"..
            "#{{Collectible651}} 在此卡的周围自动提供一个有50%增幅效果的光圈",
            Frame = 47,
            tarotClothBuffs = "点亮全层敌人#点亮本层的掉落物",
        },
        en = {
            Name = "XVII - The Stars?",
            Description = "Light up the enemies in the room, their light effect is the same with {{Collectible651}}",
            Frame = 47,
            tarotClothBuffs = "Light up the enemies and pickups in the level",
        },
    },
    [50] = {
        Name = "V - 密仪",
        id = Cards.Sting,
        zh = {
            Name = "V - 密仪",
            Desc = "降神仪式",
            Description = "{{SacrificeRoom}} 生成一座仪式法阵，在法阵中献祭半格生命获得对应奖励"..
            "#{{Heart}} 优先献祭红心",
            Frame = 59,
            tarotClothBuffs = "每次献祭有30%概率生成一颗魂心",
        },
        en = {
            Name = "V - Sting",
            Description = "{{SacrificeRoom}} Generate a ceremonial array and sacrifice life in it to receive rewards"..
            "#{{Heart}} Sacrifice red heart first",
            Frame = 59,
            tarotClothBuffs = "30% chance to generate a soul heart when sacrifice",
        },
    },
    [51] = {
        Name = "V - 密仪?",
        id = Cards.Sting_r,
        zh = {
            Name = "V - 密仪?",
            Desc = "落入彼岸",
            Description = "失去半颗{{Heart}}红心，对所有敌人造成10点伤害"..
            "#击杀敌人时翻倍伤害并重复伤害",
            Frame = 60,
            tarotClothBuffs = "初始伤害为20点",
        },
        en = {
            Name = "V - Sting?",
            Description = "Lose half a {{Heart}} red heart, deal 10 damage to all enemies "..
            "#Double the damage and repeat it when killing enemies",
            Frame = 60,
            tarotClothBuffs = "Base damage as 20",
        },
    },
    [52] = {
        Name = "XIX - 太阳",
        id = Cards.Sun,
        zh = {
            Name = "XIX - 太阳",
            Desc = "物皆重临",
            Description = "按照顺序，将本房间内使用的所有卡牌重复执行一次"..
            "#使用了三种或以上卡牌：额外生成一张随机卡",
            Frame = 25,
            tarotClothBuffs = "使用了十种或以上卡牌：额外生成一个道具",
        },
        en = {
            Name = "XIX - The Sun",
            Description = "Repeat all the cards used in this room once in order "..
            "#Three or more cards are used: generate an additional random card",
            Frame = 25,
            tarotClothBuffs = "Ten or more cards are used: generate an item.",
        },
    },
    [53] = {
        Name = "XIX - 太阳?",
        id = Cards.Sun_r,
        zh = {
            Name = "XIX - 太阳?",
            Desc = "赞美我！",
            Description = "生成一个彩虹传送旋涡，进入后传送至随机特殊房间"..
            "#此旋涡可以永久使用",
            Frame = 49,
            tarotClothBuffs = "优先传送向未探索的房间",
        },
        en = {
            Name = "XIX - The Sun?",
            Description = "After use, gain half a red heart, +0.4 damage and +0.1 speed every minute"..
            "#This effect will disappear in next level",
            Frame = 49,
            tarotClothBuffs = "Additional effect: gain half a red heart, +0.4 damage and +0.1 speed every half minute in this room",
        },
    },
    [54] = {
        Name = "XVI - 尖塔",
        id = Cards.Tower,
        zh = {
            Name = "XVI - 尖塔",
            Desc = "万物皆虚，万事皆允",
            Description = "将本房间内所有地形块悬空，随后扔向敌人"..
            "#不同的地形块有不同的掉落效果",
            Frame = 22,
            tarotClothBuffs = "出房间后恢复那些地形块",
        },
        en = {
            Name = "XVI - The Tower",
            Description = "Suspend all grid blocks in the room and then throw them to the enemy",
            Frame = 22,
            tarotClothBuffs = "Restore those grid blocks after leaving the room",
        },
    },
    [55] = {
        Name = "XVI - 尖塔?",
        id = Cards.Tower_r,
        zh = {
            Name = "XVI - 尖塔?",
            Desc = "崩落...",
            Description = "从天上逐渐加速地落下岩块砸向敌人"..
            "#{{Timer}} 持续10s",
            Frame = 46,
            tarotClothBuffs = "扔下更多数量与种类的地形块",
        },
        en = {
            Name = "XVI - The Tower?",
            Description = "Gradually and rapidly fall rocks from the sky and smash them at the enemies",
            Frame = 46,
            tarotClothBuffs = "Drop more rocks",
        },
    },
    [56] = {
        Name = "XXI - 宇宙",
        id = Cards.Universe,
        zh = {
            Name = "XXI - 宇宙",
            Desc = "星汉灿烂",
            Description = "{{Planetarium}} 移除身上一个随机道具，生成一个星座或星象道具",
            Frame = 27,
            tarotClothBuffs = "生成一个二选一的星象道具",
        },
        en = {
            Name = "XXI - The Universe",
            Description = "Remove a random item and generate a constellation or astrological item",
            Frame = 27,
            tarotClothBuffs = "Generate a alternative choice",
        },
    },
    [57] = {
        Name = "XXI - 宇宙?",
        id = Cards.Universe_r,
        zh = {
            Name = "XXI - 宇宙?",
            Desc = "不管离开多远，不管时间如何流逝，你永远都是属于我的",
            Description = "!!! 第一次使用时，随机失去一个道具"..
            "#此后每次使用此卡，重新生成这个道具，但它视为被摸过的道具"..
            "#{{ArrowUp}} 下层开始时，生成此卡",
            Frame = 51,
            tarotClothBuffs = "额外刷新失去道具的状态",
        },
        en = {
            Name = "XXI - The Universe?",
            Description = "When you use it for the first time,lose a random item"..
            "#Otherwise,regenerate that item(used)"..
            "#Generate this card at the beginning of the next level after you use it",
            Frame = 51,
            tarotClothBuffs = "regenerate that item(unused)",
        },
    },
    [58] = {
        Name = "X - 命运",
        id = Cards.Wheel_of_Destiny,
        zh = {
            Name = "X - 命运",
            Desc = "明暗为逆",
            Description = "选择一个道具转换为2个脆弱的同名道具魂火"..
            "#以此法生成的魂火在通过2层后重新转换为道具"..
            "#刷新重新生成道具的状态",
            Frame = 16,
            tarotClothBuffs = "转换为3个同名道具魂火，魂火可以抵挡一次碰撞",
        },
        en = {
            Name = "X - The Wheel of Destiny",
            Description = "Select one item and convert it into two fragile item wisp in the same name."..
            "#Item wisps spawned in this way turn back to items if you successfully protect it in 2 level.",
            Frame = 16,
            tarotClothBuffs = "Convert into 3 wisps which can withstand one hit",
        },
    },
    [59] = {
        Name = "X - 命运?",
        id = Cards.Wheel_of_Destiny_r,
        zh = {
            Name = "X - 命运?",
            Desc = "你相信引力吗?",
            Description = "将房间内所有基础掉落物转化为旋转着的三至五选一掉落物",
            Frame = 38,
            tarotClothBuffs = "改为五至七选一掉落物",
        },
        en = {
            Name = "X - The Wheel of Destiny?",
            Description = "Convert all the pickups in the room into 3-5 pickups to choose one,they are spining in a circle",
            Frame = 38,
            tarotClothBuffs = "Add the choices of the pickups.",
        },
    },
    [60] = {
        Name = "I - 魔女",
        id = Cards.Witch,
        zh = {
            Name = "I - 魔女",
            Desc = "我将晶结",
            Description = "{{Freezing}} 生成4枚冻结敌人5s的冰锥眼泪"..
            "#冻结状态下死亡的敌人被冰冻并减速全屏敌人",
            Frame = 5,
            tarotClothBuffs = "生成8枚，冰锥伤害为面板的3倍",
        },
        en = {
            Name = "I - The Witch",
            Description = "Generate 4 ice tears that freeze the enemy for 5s "..
            "#The enemies who died in this freezing state are frozen and decelerate all enemies",
            Frame = 5,
            tarotClothBuffs = "Generate 8 ice tears with damage multiplier of 3",
        },
    },
    [61] = {
        Name = "I - 魔导",
        id = Cards.Wizard,
        zh = {
            Name = "I - 魔导",
            Desc = "我将昭世",
            Description = "在地图上揭示一种特殊房间，进入对应房间时打开数个通往其他特殊房间的传送旋涡"..
            "#{{Card22}} 全部特殊房间均已预知：点亮全图",
            Frame = 7,
            tarotClothBuffs = "开启更多特殊房间的传送门",
        },
        en = {
            Name = "I - The Wizard",
            Description = "Predict a special room "..
            "#Light up all rooms of that type on the map "..
            "#Upon entering that room only once, open several transmission portal leading to other special rooms in this level "..
            "#All special rooms have been predicted: light up the whole map "..
            "#Small probability to open a transmission portal to special rooms not on the map(including Devil Room, Error Room, etc.)",
            Frame = 7,
            tarotClothBuffs = "Open much more portals.#Higher chance to open special portals.",
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
            Desc = "",
            Description = "灾难之角",
        },
        en = {
            Name = "Anna",
            Description = "The horn of Nitimity",
            Animation = "Anna",
            Sprite = "gfx/characterportraits.anm2",
        },
    },
    [2] = {
        Name = "艾提奥",
        id = enums.Players.Autio,
        type = "player",
        zh = {
            Name = "艾提奥",
            Desc = "",
            Description = "灾难之影",
        },
        en = {
            Name = "Autio",
            Description = "The shadow of Nitimity",
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
            Desc = "",
            Description = "灾难之喉",
        },
        en = {
            Name = "Lu",
            Description = "The throat of Nitimity",
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
        },
        en = {
        },
    },
    [5] = {
        Name = "万青",
        id = enums.Players.Spwq,
        type = "player",
        zh = {
            Name = "万青",
            Desc = "",
            Description = "{{Collectible"..enums.Items.Air_Flight.."}} 持有飞行器，用射击键抛出指挥标记"..
            "#Alt（可改键）切换模式：猎杀 / 护航 / 压制"..
            "#猎杀：飞行器在标记附近自动接敌盘旋"..
            "#护航：飞行器贴身侧后，朝标记方向开火；走位即改炮位"..
            "#压制：压进标记点持续开火；拖动标记做战场调度"..
            "#Ctrl（可改键）收回标记",
        },
        en = {
            Name = "Qing",
            Description = "{{Collectible"..enums.Items.Air_Flight.."}} Starts with Air Flight and a command mark steered by fire keys"..
            "#Alt (rebindable) cycles Hunt / Form / Pin"..
            "#Hunt: auto-engages near the mark"..
            "#Form: stays on your flank and fires toward the mark"..
            "#Pin: pins the mark and keeps firing; drag the mark to redirect"..
            "#Ctrl (rebindable) recalls the mark",
            Animation = "SP.W.Qing",
            Sprite = "gfx/characterportraitsalt.anm2",
            Tainted = true,
        },
    },
    [6] = {
        Name = "泰克罗",
        id = enums.Players.Tecro,
        type = "player",
        zh = {
            Name = "泰克罗",
            Desc = "",
            Description = "灾难之牙",
        },
        en = {
            Name = "Tecro",
            Description = "The tooth of Nitimity",
            Animation = "Tecro",
            Sprite = "gfx/characterportraits.anm2",
        },
    },
    [7] = {
        Name = "泰克罗罗恩",
        id = enums.Players.Tecrorun,
        type = "player",
        zh = {
            Name = "泰克罗罗恩",
            Desc = "",
            Description = "灾难之光",
        },
        en = {
            Name = "Tecrorun",
            Description = "The light of Nitimity",
            Animation = "Tecrorun",
            Sprite = "gfx/characterportraitsalt.anm2",
            Tainted = true,
        },
    },
    [8] = {
        Name = "泽伊斯托斯",
        id = enums.Players.Zeistos,
        type = "player",
        zh = {
            Name = "泽伊斯托斯",
            Desc = "",
            Description = "灾难之眼",
        },
        en = {
            Name = "Zeis",
            Description = "The eye of Nitimity",
            Animation = "Zeistos",
            Sprite = "gfx/characterportraits.anm2",
        },
    },
    [9] = {
        Name = "安奈",
        id = enums.Players.annA,
        type = "player",
        zh = {
            Name = "安奈",
            Desc = "",
            Description = "灾难之魔",
        },
        en = {
            Name = "Anna",
            Description = "The devil of Nitimity",
            Animation = "annA",
            Sprite = "gfx/characterportraitsalt.anm2",
            Tainted = true,
        },
    },
    [10] = {
        Name = "小青",
        id = enums.Players.wq,
        type = "player",
        zh = {
            Name = "小青",
            Desc = "",
            Description = "灾难之先导",
        },
        en = {
            Name = "Qing",
            Description = "The precursor of Nitimity",
            Animation = "W.Qing",
            Sprite = "gfx/characterportraits.anm2",
        },
    },
    [11] = {
        Name = "泽伊兹",
        id = enums.Players.Zeiz,
        type = "player",
        zh = {
            Name = "泽伊兹",
            Desc = "",
            Description = "每层进入控制中枢"..
            "#接触候选虚影以任命管理员"..
            "#其愚见会错误地管理世界",
        },
        en = {
            Name = "Zeiz",
            Description = "Enter the Control Hub each floor"..
            "#Touch a candidate phantom to appoint them"..
            "#Their Folly mismanages the world",
            Animation = "Zeiz",
            Sprite = "gfx/characterportraitsalt.anm2",
            Tainted = true,
        },
    },
}

item.Birthrights = {
    [1] = {
        Name = "Players.Anna",
        id = Players.Anna,
        type = "birthright",
        zh = {
            Description = "{{Speed}} 超额的吞噬物不再降低移速"..
            "#每层均有小恶魔乞丐",
            PlayerName = "安娜",
        },
        en = {
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
            Description = "死亡时舍弃另一形态与此道具并复活"..
            "#通过2个楼层以拼合阴阳两面",
            PlayerName = "玛丽亚诺",
        },
        en = {
        },
    },
    [3] = {
        Name = "Players.Spwq",
        id = Players.Spwq,
        type = "birthright",
        zh = {
            Description = "浮游炮+3",
            PlayerName = "万青？",
        },
        en = {
            Description = "+3 Funnel",
            PlayerName = "W.Qing",
        },
    },
    [4] = {
        Name = "Players.Tecro",
        id = Players.Tecro,
        type = "birthright",
        zh = {
            Description = "蓄力出枪后命中的第一个敌人受到所有持有隐枪的再次攻击",
            PlayerName = "泰克罗",
        },
        en = {
            Description = "The first enemy hit by spear will be attacked by all hidden spears.",
            PlayerName = "Tecro",
        },
    },
    [5] = {
        Name = "Players.Tecrorun",
        id = Players.Tecrorun,
        type = "birthright",
        zh = {
            Description = "100%聚焦时+4弹射次数",
            PlayerName = "泰克罗· 罗恩",
        },
        en = {
            Description = "+4 times of reflect when 100% charge.",
            PlayerName = "Tecrorun",
        },
    },
    [6] = {
        Name = "Players.Zeistos",
        id = Players.Zeistos,
        type = "birthright",
        zh = {
            Description = "{{Collectible628}} 初始房间始终存在死亡证明传送门"..
            "#每层可以额外自由选择一个被动道具"..
            "#未拥有的被动道具最多可以拿两次",
            PlayerName = "泽伊斯托斯",
        },
        en = {
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
            Description = "攻击时概率触发随机额外攻击",
            PlayerName = "安奈",
        },
        en = {
            Description = "Trigger extra random attack forms when attack.",
            PlayerName = "Anna",
        },
    },
    [8] = {
        Name = "Players.wq",
        id = Players.wq,
        type = "birthright",
        zh = {
            Description = "极大提升瞬移攻击与伤害"..
            "#无目标时按下瞬移键快速移动"..
            "#存在目标时快速暗杀敌人",
            PlayerName = "万青",
        },
        en = {
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
            "#!!! 不能发射眼泪"..
            "#鼠标点击敌人以造成伤害"..
            "#难度等级：普通",
        },
        en = {
            Name = "Cookie Clicker",
            Description = "{{Player15}} Play as Apollyon"..
            "#!!! Can't shoot"..
            "#Press enemies with mouse to deal damage"..
            "#Difficulty: Normal",
        },
    },
    [2] = {
        Name = "挑战：飞龙在天",
        id = enums.Challenges.Dragon_Flight,
        type = "challenge",
        zh = {
            Name = "挑战：飞龙在天",
            Description = "#{{Player3}} 犹大开局"..
            "#{{Collectible"..enums.Items.Book_of_How_to_Fly.."}} 使用飞行书+{{Collectible619}}长子权空战"..
            "#{{Collectible641}} 使用书本发射的眼泪像血田一样跟在角色身后"..
            "#难度等级：普通",
        },
        en = {
            Name = "Dragon Flight",
            Description = "#{{Player3}} Play as Judas"..
            "#{{Collectible"..enums.Items.Book_of_How_to_Fly.."}} Use How to Fly and {{Collectible619}}Birthright to fight in air"..
            "#{{Collectible641}} Tears emitted from books follow the character"..
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
            "#{{Charm}} 角色接近的敌人被永久魅惑"..
            "#{{ArrowUp}} 被魅惑的敌人每经过一个房间就会稍微成长"..
            "#!!! 每层第一次进入Boss房后，解除所有被魅惑的敌人"..
            "#超级撒旦的房间总是解除所有被魅惑的敌人"..
            "#难度等级：困难",
        },
        en = {
            Name = "Fans Service",
            Description = "{{Player1}} Play as Maggy"..
            "#{{Charm}} Constantly charm enemies getting closed"..
            "#{{ArrowUp}} Enchanted enemies grow slightly every time clearing a room"..
            "#!!! After entering the Boss room for the first time on each floor, release all enchanted enemies"..
            "#The room of Super Satan always relieves all enchanted enemies"..
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
            "#!!! 所有道具无效化，但保留血量和基础变化效果"..
            "#不可打开控制台"..
            "#难度等级：噩梦",
        },
        en = {
            Name = "Feels Like Dead Ashes",
            Description = "{{Player21}} Play as Tainted Isaac"..
            "#!!! All items are invalidated"..
            "#Forbids console"..
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
            "#!!! 不能发射眼泪"..
            "#{{Collectible710}} 用你的袋子将敌人当做基础掉落捕获"..
            "#对Boss捕获一个基础掉落并打出更多基础掉落"..
            "#!!! 没有{{TreasureRoom}}宝箱房与{{Shop}}商店"..
            "#难度等级：简单",
        },
        en = {
            Name = "Fusion Destiny",
            Description = "{{Player23}} Played as tainted Cain"..
            "#!!! Can't shoot"..
            "#{{Collectible710}} Capture enemies as pickup using craft bag"..
            "#Capture a pickup on the boss and hit out more"..
            "#!!! No {{TreasureRoom}}TreasureRoom nor {{Shop}}Shop"..
            "#Difficulty: Easy",
        },
    },
    [6] = {
        Name = "挑战：异热同心",
        id = enums.Challenges.Heterothermal_Concentric,
        type = "challenge",
        zh = {
            Name = "挑战：异热同心",
            Description = "{{Player19}} 双子开局"..
            "#!!! 双方只能向对方的方向射击"..
            "#难度等级：普通",
        },
        en = {
            Name = "Heterothermal Concentric",
            Description = "{{Player19}} Play as Esau and Jacob"..
            "#!!! They can only shoot in the other's direction"..
            "#Difficulty: Hard",
        },
    },
    [7] = {
        Name = "挑战：不为人知",
        id = enums.Challenges.Invisible,
        type = "challenge",
        zh = {
            Name = "挑战：不为人知",
            Description = "{{Player24}} 里犹大开局"..
            "#!!! 一切逐渐隐形"..
            "#!!! 没有{{TreasureRoom}}宝箱房与{{Shop}}商店"..
            "#难度等级：简单",
        },
        en = {
            Name = "Invisible",
            Description = "{{Player24}} Play as Tainted Judas"..
            "#!!! Everything gradually become invisible"..
            "#!!! No {{TreasureRoom}}TreasureRoom nor {{Shop}}Shop"..
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
            "#{{Collectible628}} 每层从死亡证明层开始游戏"..
            "#!!! 越接近道具，道具被重置的速度越快"..
            "#{{Collectible478}} 使用暂停可以暂停重置道具2s"..
            "#难度等级：简单",
        },
        en = {
            Name = "Louvre puzzle",
            Description = "{{Player0}} Play as Isaac"..
            "#{{Collectible628}} Start from death certificate room"..
            "#!!! The closer to item, the faster it will be rolled"..
            "#{{Collectible478}} Using Pause will pause the rolling in 2 seconds"..
            "#Difficulty: Easy",
        },
    },
    [9] = {
        Name = "挑战：指指点点",
        id = enums.Challenges.Pointing,
        type = "challenge",
        zh = {
            Name = "挑战：指指点点",
            Description = "#{{Player6}} 叁孙开局"..
            "#{{Collectible"..tostring(enums.Items.Cloundy).."}} 持有5个云玩大佬和一个{{Collectible583}}火箭炸弹"..
            "#难度等级：困难",
        },
        en = {
            Name = "Pointing and Disappointing",
            Description = "#{{Player6}} Play as Samson"..
            "#{{Collectible"..tostring(enums.Items.Cloundy).."}} Start with 5 Cloundy and a {{Collectible583}}rocket in a jar"..
            "#Difficulty: Hard",
        },
    },
    [10] = {
        Name = "挑战：安全驾驶",
        id = enums.Challenges.Safe_Driving,
        type = "challenge",
        zh = {
            Name = "挑战：安全驾驶",
            Description = "#{{Player18}} 伯大尼开局"..
            "#!!! 不能发射眼泪"..
            "#{{Collectible"..enums.Items.Hyper_Velocity.."}} 召唤列车冲击敌人"..
            "#难度等级：普通",
        },
        en = {
            Name = "Safe Driving",
            Description = "#{{Player18}} Play as Bethany"..
            "#!!! Can't shoot"..
            "#{{Collectible"..enums.Items.Hyper_Velocity.."}} Summon train to squash enemies"..
            "#Difficulty: Normal",
        },
    },
    [11] = {
        Name = "挑战：食日",
        id = enums.Challenges.Swallow_The_Sun,
        type = "challenge",
        zh = {
            Name = "挑战：食日",
            Description = "#{{Player"..enums.Players.Anna.."}} 安娜开局"..
            "#!!! 无法拾取任何掉落物"..
            "#每层下层后回复两颗黑心，获得一颗炸弹，一把钥匙"..
            "#难度等级：简单",
        },
        en = {
            Name = "Swallow the Sun",
            Description = "#{{Player"..enums.Players.Anna.."}} Play as Anna"..
            "#!!! Can't pickup items and pickup"..
            "#Consume everything"..
            "#Restore two black hearts, obtain one bomb and one key every level"..
            "#Difficulty: Normal",
        },
    },
    [12] = {
        Name = "挑战：不稳定体",
        id = enums.Challenges.Unstable_State,
        type = "challenge",
        zh = {
            Name = "挑战：不稳定体",
            Description = "{{Player9}} 伊甸开局"..
            "#!!! 受伤后你的道具全部落在地上"..
            "#难度等级：普通",
        },
        en = {
            Name = "Unstable State",
            Description = "{{Player9}} Play as Eden"..
            "#!!! All your items fell to the ground on hit"..
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
            Description = "随机模仿一颗已有的心"..
            "#优先抵消{{BrokenHeart}}碎心与{{RottenHeart}}腐心",
        },
        en = {
            Name = "Glaze Heart",
            Description = "Randomly imitate an existing heart"..
            "#Priority offset {{BrokenHeart}} BrokenHeart and {{RottenHeart}}RottenHeart",
        },
    },
    [2] = {
        Variant = Pickups.Glaze_heart_half.Variant,
        SubType = Pickups.Glaze_heart_half.SubType,
        zh = {
            Name = "琉璃之半心",
            Description = "随机模仿半颗已有的心"..
            "#优先抵消{{BrokenHeart}}碎心与{{RottenHeart}}腐心",
        },
        en = {
            Name = "Half of a Glaze Heart",
            Description = "Randomly imitate half an existing heart"..
            "#Priority offset {{BrokenHeart}} BrokenHeart and {{RottenHeart}}RottenHeart",
        },
    },
    [3] = {
        Variant = Pickups.Glaze_key.Variant,
        SubType = Pickups.Glaze_key.SubType,
        zh = {
            Name = "琉璃之匙",
            Description = "点亮一个随机地图",
        },
        en = {
            Name = "Glaze Key",
            Description = "Illuminate a random room on map",
        },
    },
    [4] = {
        Variant = Pickups.Glaze_bomb.Variant,
        SubType = Pickups.Glaze_bomb.SubType,
        zh = {
            Name = "琉璃之炸弹",
            Description = "下个使用的炸弹爆炸时会消除弹幕",
        },
        en = {
            Name = "Glaze Bomb",
            Description = "The next bomb will eliminate the projectiles when it explodes",
        },
    },
    [5] = {
        Variant = Pickups.Glaze_grabbag.Variant,
        SubType = Pickups.Glaze_grabbag.SubType,
        zh = {
            Name = "琉璃之福袋",
            Description = "打开后，消耗你的基础掉落生成等量琉璃化掉落物 "..
            "#{{PoopPickup}} 没有基础掉落的场合生成琉璃的便便"..
            "# 不会带来负收益",
        },
        en = {
            Name = "Glaze Grabbag",
            Description = "Consume your pickup to generate an equal amount of glazed pickup"..
            "#{{PoopPickup}}Spawns a glaze poop when nothing to convert",
        },
    },
    [6] = {
        Variant = Pickups.Glaze_battery.Variant,
        SubType = Pickups.Glaze_battery.SubType,
        zh = {
            Name = "琉璃之电池",
            Description = "!!! 消耗主动的所有充能 "..
            "#在接下来的房间清理中，获得充能的数量+2",
        },
        en = {
            Name = "Glaze Battery",
            Description = "!!! Consume all active charges"..
            "#In the following room cleaning, +2 the number of charges obtained",
        },
    },
    [7] = {
        Variant = Pickups.Glaze_chest.Variant,
        SubType = Pickups.Glaze_chest.SubType,
        zh = {
            Name = "琉璃之宝箱",
            Description = "本层随机方位出现一把钥匙跟班，只能用钥匙跟班打开"..
            "#给予数个琉璃化掉落物或一个重复道具",
        },
        en = {
            Name = "Glaze Chest",
            Description = "A key appears at random positions in this level"..
            "#Can only be opened with that key"..
            "#Spawns several glazed pickup or a repetitive item",
        },
    },
    [8] = {
        Variant = Pickups.Glaze_big_poop.Variant,
        SubType = Pickups.Glaze_big_poop.SubType,
        zh = {
            Name = "琉璃之便便",
            Description = "{{PoopSpell1}}受伤后随机使用1个便便 "..
            "#不可堆叠",
        },
        en = {
            Name = "Glaze poop",
            Description = "{{PoopSpell1}}Getting hit Randomly using a poop spell"..
            "#Can't stack",
        },
    },
    -- SubType 运行时为对应收藏品 ID；实际 Name/Desc 由 pickup_blueprint_prototype.load_EID / get_texts 动态覆盖
    [9] = {
        Variant = Pickups.Blueprint_Prototype.Variant,
        SubType = 0,
        zh = {
            Name = "道具原型",
            Desc = "",
            Description = "#将{{CollectibleXX}}加入蓝图库存，提供 1 份可分配材料"..
            "#只能放入制造材料槽，不能支付成本",
        },
        en = {
            Name = "Item Prototype",
            Desc = "",
            Description = "#Adds {{CollectibleXX}} to Blueprint inventory as 1 allocatable material"..
            "#Ingredient slots only; cannot pay craft cost",
        },
    },
}

item.Slots = {
    [1] = {
        id = enums.Slots.Bard_beggar.Variant,
        zh = {
            Name = "吟游乞丐",
            Description = "接受你的馈赠并为你歌唱"..
            "#{{Collectible515}} 歌唱7次后送出一个礼物"..
            "#随机出现在下层通道",
        },
        en = {
            Name = "Bard beggar",
            Description = "Accept your gift and sing for you (ONLY CHINESE)"..
            "#{{Collectible515}} Sends a gift after singing 7 times"..
            "#Randomly appearing in the special entrance",
        },
    },
    [2] = {
        id = enums.Slots.Rift_beggar.Variant,
        zh = {
            Name = "黑洞恶魔乞丐",
            Description = "吞噬身边的任意基础掉落物"..
            "#每25个任意基础掉落物送出一个4级道具"..
            "#每个偶数层出现",
        },
        en = {
            Name = "Rift beggar",
            Description = "Swallow all pickups around"..
            "#Spawns a quality 4 item every 25 pickups"..
            "#Appears every even layer",
        },
    },
    [3] = {
        id = enums.Slots.Time_beggar.Variant,
        zh = {
            Name = "时光乞丐",
            Description = "食用游戏时间并以金钱作为回报"..
            "#{{Timer}} 投喂完成后给予与时间、记忆相关的道具"..
            "#身上的道具最高重复数量越多，出现概率越高",
        },
        en = {
            Name = "Time beggar",
            Description = "Consume game time and reward with money"..
            "#{{Timer}} After the feeding is completed, give items related to time and memory"..
            "#The higher the maximum number of repetitions of items, the higher the probability of its occurrence",
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
for index, info in ipairs(item.Pickups or {}) do
    local base = {Variant = info.Variant, SubType = info.SubType}
    if info.en then
        item.en.Pickups[index] = {Variant = base.Variant, SubType = base.SubType}
        for key, value in pairs(info.en) do item.en.Pickups[index][key] = value end
    end
    if info.zh then
        item.zh.Pickups[index] = {Variant = base.Variant, SubType = base.SubType}
        for key, value in pairs(info.zh) do item.zh.Pickups[index][key] = value end
    end
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
