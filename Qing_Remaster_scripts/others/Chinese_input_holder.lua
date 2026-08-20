local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	own_key = "Chinese_input_holder_",
	data = {
		["a"] = "啊阿呵吖锕",
		["ai"] = "爱癌哎唉哀挨碍艾矮隘蔼埃",
		["an"] = "暗安胺按案岸鞍俺氨庵",
		["ang"] = "昂肮盎",
		["ao"] = "凹奥懊傲熬拗澳袄",
		["ba"] = "爸疤巴八把吧拔叭罢扒霸耙跋捌坝靶芭笆",
		["bai"] = "白百败伯拜柏摆掰",
		["ban"] = "板伴搬绊班半办版拌斑般扮瓣扳颁",
		["bang"] = "绑榜磅帮蚌邦棒傍膀梆谤",
		["bao"] = "宝包煲暴胞保抱鲍爆褒剥报薄饱刨堡苞豹瀑雹",
		["bei"] = "被背悲杯辈北备卑倍贝碑狈惫焙",
		["ben"] = "本奔笨夯苯",
		["beng"] = "绷崩蚌蹦泵",
		["bi"] = "币比彼匕鼻笔吡毕必闭避臂秘璧辟碧弊蔽壁鄙逼毙痹庇蓖荸婢",
		["bian"] = "变便辫扁鞭蝙编辩边辨遍贬匾",
		["biao"] = "表标镖婊膘彪",
		["bie"] = "别瘪鳖憋",
		["bin"] = "频宾鬓彬滨缤濒",
		["bing"] = "冰饼病柄兵并丙秉禀屏",
		["bo"] = "勃波伯薄玻博剥脖拨卜播柏泊簿簸膊搏驳跛舶渤菠",
		["bu"] = "部怖布不捕卜步补簿哺埠",
		["ca"] = "擦",
		["cai"] = "菜彩才采财材裁猜睬踩",
		["can"] = "参餐残惨蚕惭灿掺",
		["cang"] = "藏苍仓沧舱",
		["cao"] = "槽草曹操糙",
		["ce"] = "册侧测策栅厕",
		["cen"] = "参岑",
		["ceng"] = "层曾蹭",
		["cha"] = "差查插叉察茶刹喳杈碴茬岔衩",
		["chai"] = "柴差拆豺",
		["chan"] = "产铲颤蝉缠搀阐崭馋掺",
		["chang"] = "肠长娼场厂常唱倡裳昌畅尝倘偿敞淌猖",
		["chao"] = "超巢吵朝抄炒钞潮绰嘲剿",
		["che"] = "车扯彻澈撤",
		["chen"] = "称尘沉臣陈辰晨趁衬忱",
		["cheng"] = "成程秤称呈橙乘城盛承诚澄逞惩撑",
		["chi"] = "池尺齿耻吃持赤驰痴迟侈翅弛斥嗤",
		["chong"] = "虫宠重充冲铳崇",
		["chou"] = "仇臭抽丑愁筹绸酬稠畴",
		["chu"] = "处触出除楚畜初储锄础橱厨雏矗",
		["chuai"] = "揣踹",
		["chuan"] = "传穿船川串喘",
		["chuang"] = "创床窗闯疮幢",
		["chui"] = "吹垂炊锤捶",
		["chun"] = "春唇蠢纯醇淳椿",
		["chuo"] = "戳绰龊",
		["ci"] = "词刺磁辞慈此次伺雌赐祠瓷",
		["cong"] = "葱从聪丛匆囱",
		["cou"] = "凑",
		["cu"] = "粗醋促簇猝蹴",
		["cuan"] = "窜篡蹿攒",
		["cui"] = "脆摧翠催悴粹崔",
		["cun"] = "寸存村",
		["cuo"] = "锉错撮措挫搓",
		["da"] = "大达答打搭瘩",
		["dai"] = "袋带待代戴隶呆歹贷逮怠",
		["dan"] = "弹蛋诞单旦但胆担丹淡耽掸氮",
		["dang"] = "当党荡挡铛档裆",
		["dao"] = "刀道祷稻倒到导蹈叨盗岛捣悼",
		["de"] = "的德地得の",
		["dei"] = "得",
		["deng"] = "灯等登澄瞪凳邓蹬",
		["di"] = "弟第地底笛滴敌蒂低的抵帝递涤堤缔嫡嘀",
		["dian"] = "店电甸典点颠垫殿佃掂奠碘玷淀惦",
		["diao"] = "调雕吊刁掉钓碉叼",
		["die"] = "爹蝶叠跌谍碟",
		["ding"] = "钉定订酊丁鼎顶叮锭盯",
		["diu"] = "丢",
		["dong"] = "洞动东冬咚冻栋懂董",
		["dou"] = "豆痘窦兜斗都抖逗陡蚪",
		["du"] = "毒度赌肚读嘟独睹督杜妒牍渡堵镀",
		["duan"] = "短断端段锻缎",
		["dui"] = "对兑堆队",
		["dun"] = "盾钝沌吨蹲顿盹敦墩囤饨",
		["duo"] = "多夺堕舵度朵惰垛躲哆踱跺",
		["e"] = "恶饿额蛾鹅扼讹遏俄噩愕鳄婀",
		["ei"] = "诶欸",
		["en"] = "恩嗯摁",
		["er"] = "儿二耳而尔贰饵",
		["fa"] = "发法罚伐乏筏阀",
		["fan"] = "反饭番烦凡繁翻犯返泛贩范帆樊矾",
		["fang"] = "防房方放坊芳访仿纺妨肪",
		["fei"] = "飞非肺啡肥费菲废沸匪吠诽",
		["fen"] = "粉粪分坟愤份奋焚纷忿芬吩氛",
		["feng"] = "风疯凤逢封缝锋蜂丰奉冯峰讽枫",
		["fo"] = "佛",
		["fou"] = "否缶",
		["fu"] = "复浮腹肤腐服福弗伏妇符蝠夫父负附富覆副扶赴俯府赋拂幅付抚斧辅傅凫辐敷缚芙袱甫脯孵咐俘麸",
		["ga"] = "伽噶嘎尬咖",
		["gai"] = "丐该盖改钙概溉芥",
		["gan"] = "干肝甘感杆敢竿赶乾柑橄秆",
		["gang"] = "钢港刚纲杠扛岗缸肛冈",
		["gao"] = "镐糕膏高告搞羔稿篙",
		["ge"] = "哥割嗝鸽格个歌戈各革隔葛阁疙蛤搁胳",
		["gei"] = "给",
		["gen"] = "跟根",
		["geng"] = "更颈耕羹梗埂耿",
		["gong"] = "攻工宫共公功供弓躬拱恭贡汞蚣巩",
		["gou"] = "狗够购勾苟钩垢沟构",
		["gua"] = "刮寡瓜挂卦褂括",
		["gu"] = "骨菇孤谷古股鼓故固顾贾姑估沽雇辜咕箍",
		["guai"] = "怪乖拐",
		["guan"] = "冠罐管馆观关官贯灌惯棺",
		["guang"] = "光胱广逛",
		["gui"] = "归鬼瑰贵规龟柜轨桂诡闺硅跪傀刽",
		["gun"] = "棍滚",
		["guo"] = "果过国锅郭裹",
		["ha"] = "哈蛤",
		["hai"] = "孩害海还嗨咳骇亥",
		["han"] = "汗寒喊含旱汉函憨捍撼韩悍涵罕酣翰憾焊",
		["hang"] = "杭航行夯吭",
		["hao"] = "好号毫豪耗浩嚎壕蒿",
		["he"] = "合喝盒和呵河禾何贺核鹤荷赫褐吓苛",
		["hei"] = "黑嘿",
		["hen"] = "痕很恨狠",
		["heng"] = "横衡恒哼",
		["hong"] = "红虹哄宏鸿洪轰烘",
		["hou"] = "后厚侯候猴喉吼",
		["hua"] = "化花华话画划豁滑哗猾桦",
		["hu"] = "虎户核呼糊许胡乎狐互湖壶护忽弧葫唬蝴沪",
		["huai"] = "怀坏槐淮徊",
		["huan"] = "还换欢患环幻缓唤涣焕宦痪",
		["huang"] = "黄皇荒晃谎惶慌恍煌蟥凰蝗幌",
		["hui"] = "会回灰毁溃堕悔挥讳汇惠辉晦秽诲贿慧恢徽绘茴蛔",
		["hun"] = "魂混昏婚浑荤",
		["huo"] = "火或活祸货和豁伙获惑霍",
		["jia"] = "家价假甲夹加架贾佳驾挟嫁嘉颊钾稼枷荚",
		["ji"] = "机即吉鸡挤计记几既讥己系极技积饥及奇肌急击寄纪济寂集迹疾脊级际稽剂继激忌箕棘嫉季基祭籍叽给辑唧畸绩冀妓鲫荠圾",
		["jian"] = "见间浅肩简监奸坚兼箭鉴建尖剑艰俭渐减件贱拣溅剪煎践健检舰茧键碱歼荐捡柬涧",
		["jiang"] = "将降江浆浆疆港讲奖匠姜桨僵酱缰蒋",
		["jiao"] = "角教椒交校脚饺觉嚼矫较焦胶叫浇骄娇剿缴搅郊轿狡窖酵礁绞侥蕉",
		["jie"] = "节姐杰届解结价街接揭界竭借芥劫皆截阶介捷洁楷戒诫秸",
		["jin"] = "金尽进仅禁劲近今锦筋紧斤津巾襟谨浸晋",
		["jing"] = "经景惊劲竞精井净镜静颈京敬警径境荆晶竟睛兢鲸茎阱靖",
		["jiong"] = "窘炯囧炅",
		["jiu"] = "酒九旧就久舅救究纠鸠臼揪灸疚玖韭",
		["ju"] = "句举居惧巨俱局具剧聚矩渠据拘驹距锯柜橘沮鞠拒炬菊车",
		["juan"] = "卷倦眷捐鹃绢圈",
		["jue"] = "绝觉决嚼角爵掘倔诀",
		["jun"] = "军龟君菌峻均钧骏俊竣",
		["ka"] = "卡咖咔咯喀",
		["kai"] = "开慨凯楷揩",
		["kan"] = "看砍刊堪坎勘嵌",
		["kang"] = "抗扛康炕慷糠",
		["kao"] = "考靠拷烤铐",
		["ke"] = "可客克刻科壳渴苛课咳磕坷颗棵蝌",
		["ken"] = "肯垦恳啃",
		["keng"] = "吭坑铿",
		["kong"] = "空孔恐控崆",
		["kou"] = "口扣寇抠",
		["kua"] = "夸跨垮挎胯",
		["ku"] = "苦酷枯哭库裤窟挎",
		["kuai"] = "快块筷会",
		["kuan"] = "宽款髋",
		["kuang"] = "狂旷矿筐况框眶",
		["kui"] = "溃窥愧亏葵盔魁傀",
		["kun"] = "困坤昆捆",
		["kuo"] = "阔括扩廓蛞",
		["la"] = "落拉啦腊蜡喇辣垃",
		["lai"] = "来赖癞莱濑",
		["lan"] = "懒蓝兰烂篮栏拦揽览缆滥榄澜",
		["lang"] = "郎狼浪朗琅榔廊",
		["lao"] = "老劳牢络捞潦唠落烙姥涝酪",
		["le"] = "乐了勒肋嘞",
		["lei"] = "累雷类勒泪擂肋垒儡蕾",
		["leng"] = "冷棱楞愣",
		["lia"] = "俩",
		["li"] = "力里理离利立礼丽厉历李例沥隶漓砾梨栗厘犁璃哩励吏篱狸粒荔痢鲤俐黎莉雳",
		["lian"] = "连脸联敛廉恋练怜炼链莲帘镰",
		["liang"] = "两凉良辆亮梁量粮粱谅晾",
		["liao"] = "了料燎撩潦寥疗聊僚瞭辽缭嘹镣",
		["lie"] = "裂列烈咧劣猎",
		["lin"] = "林临淋鳞邻吝凛磷赁檩琳躏",
		["ling"] = "令零领岭灵棱铃陵另凌龄伶菱玲蛉翎",
		["liu"] = "流六溜留刘柳碌榴馏硫瘤琉",
		["long"] = "龙笼聋拢隆弄垄咙胧窿",
		["lou"] = "楼漏陋露搂篓娄",
		["lu"] = "六路绿碌鹿陆炉卢露录鲁赂芦卤庐颅虏",
		["luan"] = "乱卵峦栾鸾",
		["lue"] = "略掠锊",
		["lun"] = "论轮伦仑抡沦纶囵",
		["luo"] = "落罗络锣箩螺萝烙洛裸逻骆啰骡",
		["lv"] = "绿率旅吕虑履律缕驴铝屡滤氯侣",
		["ma"] = "马吗妈玛抹麻骂码蚂蟆摩么",
		["mai"] = "脉卖埋买麦迈",
		["man"] = "满埋漫瞒慢蛮曼馒蔓幔",
		["mang"] = "盲忙芒茫莽氓",
		["mao"] = "毛冒貌猫茂帽茅矛贸铆锚",
		["me"] = "么",
		["mei"] = "没妹枚玫眉每美昧梅媚媒煤霉糜楣",
		["men"] = "门闷们焖扪",
		["meng"] = "蒙梦盟猛孟氓萌锰檬朦",
		["mi"] = "迷靡弥米秘密糜蜜泌觅眯谜咪",
		["mian"] = "面免眠绵勉棉冕娩缅",
		["miao"] = "妙秒苗庙描渺瞄藐",
		["mie"] = "灭蔑",
		["min"] = "民敏闽皿悯",
		["ming"] = "名明命鸣铭螟",
		["miu"] = "谬缪",
		["mo"] = "磨莫脉冒末模摩抹墨摸默魔膜没漠沫陌蟆寞摹蘑茉馍",
		["mou"] = "谋某牟眸",
		["mu"] = "目木姆模母拇幕牧亩沐牡暮慕墓睦募姥穆",
		["na"] = "那拿哪纳娜呐钠捺",
		["nai"] = "奈耐奶乃艿氖",
		["nan"] = "难南男楠",
		["nang"] = "囊馕囔",
		["nao"] = "脑闹挠恼孬",
		["ne"] = "呢呐哪讷",
		["nei"] = "内馁那",
		["nen"] = "嫩",
		["neng"] = "能",
		["ni"] = "你泥逆溺尼呢匿拟昵腻",
		["nian"] = "年念捻蔫碾撵",
		["niang"] = "娘酿",
		["niao"] = "鸟尿溺",
		["nie"] = "捏孽聂镊捻摄",
		["nin"] = "您",
		["ning"] = "宁凝拧狞泞柠",
		["niu"] = "牛扭拗纽钮",
		["nong"] = "弄农浓脓侬",
		["nu"] = "怒奴努弩",
		["nuan"] = "暖",
		["nue"] = "虐疟",
		["nuo"] = "诺挪懦糯娜",
		["nv"] = "女",
		["o"] = "哦噢喔",
		["ou"] = "偶呕欧鸥殴藕",
		["pa"] = "怕爬帕趴耙",
		["pai"] = "排牌拍派湃徘迫",
		["pan"] = "盘番判攀盼叛潘畔",
		["pang"] = "旁磅胖庞螃乓",
		["pao"] = "炮跑泡刨袍抛咆",
		["pei"] = "配陪佩赔培沛胚",
		["pen"] = "喷盆",
		["peng"] = "蓬碰烹篷朋棚膨鹏捧彭澎硼砰",
		["pi"] = "皮屁披劈批辟匹疲僻脾譬坯啤霹",
		["pian"] = "片便篇骗偏扁翩",
		["piao"] = "票朴漂飘瓢",
		["pie"] = "撇瞥",
		["pin"] = "品贫频聘拼",
		["ping"] = "平屏苹评凭瓶萍坪乒冯",
		["po"] = "破迫魄泊泼婆坡颇",
		["pou"] = "剖",
		["pu"] = "铺普仆扑暴谱葡蒲浦朴菩瀑圃",
		["qia"] = "卡洽恰掐",
		["qi"] = "气其祈期枝奇齐起器乞企启汽七骑妻泣岂弃旗栖契揭稽欺戚凄棋砌漆崎歧嘁脐鳍柒迄畦",
		["qian"] = "千前钱欠纤签谦浅铅歉潜迁牵乾遣钳嵌黔谴",
		["qiang"] = "强抢枪墙腔呛",
		["qiao"] = "巧俏敲壳桥翘悄乔瞧侨窍峭撬跷荞憔锹",
		["qie"] = "切契且砌窃怯茄",
		["qin"] = "亲琴勤寝擒秦禽侵钦芹",
		["qing"] = "情轻清青倾庆请晴顷氢卿蜻擎",
		["qiong"] = "穷琼茕穹",
		["qiu"] = "求秋龟球丘囚蚯仇",
		["qu"] = "曲区取去趣趋屈驱渠躯娶岖蛆",
		["quan"] = "全权拳犬圈券劝泉痊",
		["que"] = "雀确却缺鹊瘸",
		["qun"] = "群裙",
		["ran"] = "然染燃冉苒",
		["rang"] = "让壤嚷攘瓤",
		["rao"] = "扰饶绕",
		["re"] = "热惹",
		["ren"] = "人任仁忍认韧纫",
		["reng"] = "仍扔",
		["ri"] = "日",
		["rong"] = "容荣融溶冗绒蓉熔茸榕",
		["rou"] = "肉柔揉蹂",
		["ru"] = "如入儒辱乳褥蠕",
		["ruan"] = "软阮",
		["rui"] = "锐蕊瑞睿",
		["run"] = "润闰",
		["ruo"] = "若弱",
		["sa"] = "撒洒萨飒仨",
		["sai"] = "塞赛腮",
		["san"] = "三散参伞叁",
		["sang"] = "丧桑嗓",
		["sao"] = "扫骚嫂梢搔臊",
		["se"] = "色塞瑟涩铯",
		["sen"] = "森",
		["seng"] = "僧",
		["sha"] = "沙啥杀纱傻刹砂厦煞霎杉",
		["shai"] = "筛晒色",
		["shan"] = "山善扇栅衫删闪擅赡陕膳掺掸珊单苫",
		["shang"] = "上汤伤赏商尚裳晌",
		["shao"] = "少勺召烧梢稍稍绍捎捎哨芍",
		["she"] = "射蛇舌设舍社摄折涉奢赦赊拾",
		["shen"] = "身神深参甚什审伸申慎沈肾婶呻绅渗",
		["sheng"] = "生声乘胜省盛绳升圣剩牲甥笙",
		["shi"] = "石是食事时屎世师狮识实失使十示士尸市史氏视湿势似室泽拾施始适式诗什试饰释矢誓殖硕柿侍栅匙逝驶拭虱蚀恃嗜",
		["shou"] = "手首受守收兽寿瘦授售",
		["shua"] = "刷耍",
		["shu"] = "数书术树属鼠疏束熟竖殊输述枢舒暑叔漱梳蔬抒淑薯黍署赎蜀恕墅曙庶秫",
		["shuai"] = "率衰帅摔甩蟀",
		["shuan"] = "栓涮拴闩",
		["shuang"] = "霜双爽",
		["shui"] = "水说税睡谁",
		["shun"] = "顺瞬吮舜",
		["shuo"] = "说硕烁朔",
		["si"] = "思死四似丝私斯司伺肆寺撕饲嘶",
		["song"] = "松送诵宋颂耸讼",
		["sou"] = "搜嗽艘",
		["su"] = "俗缩宿素苏速粟溯塑诉酥肃",
		["suan"] = "算酸蒜",
		["sui"] = "随岁碎虽髓遂祟穗隧",
		["sun"] = "孙损笋隼荪",
		["suo"] = "所缩索锁琐梭唆嗦",
		["ta"] = "他它她塔塌踏蹋",
		["tai"] = "太台胎泰态抬苔汰",
		["tan"] = "弹谈叹毯贪探炭滩碳坦袒坛摊谭檀瘫痰昙潭",
		["tang"] = "汤堂糖唐倘烫塘躺棠趟膛搪淌",
		["tao"] = "套桃讨逃萄滔淘涛掏陶叨",
		["te"] = "特忑",
		["teng"] = "疼腾藤誊滕",
		["ti"] = "体提梯替蹄题踢涕剔惕剃啼屉",
		["tian"] = "天填田添甜舔恬甸佃",
		["tiao"] = "调条跳挑笤",
		["tie"] = "铁帖贴",
		["ting"] = "听庭停亭廷挺艇厅蜓",
		["tong"] = "同通童痛桶统铜筒桐彤瞳捅",
		["tou"] = "头投透偷愉",
		["tu"] = "土吐凸涂图徒途兔突屠秃",
		["tuan"] = "团揣",
		["tui"] = "退推腿颓蜕褪",
		["tun"] = "屯吞囤褪臀",
		["tuo"] = "拖托脱拓唾驼妥椭驮鸵",
		["wa"] = "瓦袜蛙挖娃凹洼",
		["wai"] = "外歪崴",
		["wan"] = "万蔓玩弯完晚丸顽宛腕湾碗挽婉豌惋",
		["wang"] = "亡王望忘往枉妄网旺汪",
		["wei"] = "为尾微喂未危委味位威违维卫唯畏围尉纬胃谓魏伪偎伟蔚萎巍慰猬苇桅薇",
		["wen"] = "文闻问温瘟纹稳吻紊蚊",
		["weng"] = "翁瓮嗡",
		["wo"] = "我握窝蜗卧沃涡",
		["wu"] = "无恶物五亡午务武舞雾屋乌污误悟伍吴勿巫梧侮芜晤呜鹉蜈捂坞诬",
		["xia"] = "下夏暇虾霞狭厦吓侠峡瞎辖唬匣",
		["xi"] = "戏西洗习系吸息细席希喜夕栖析洒稀膝腊袭惜隙徙犀悉熙昔锡媳溪嬉晰蟋牺熄铣",
		["xian"] = "线先鲜纤弦县闲险现限仙显陷衔贤嫌献掀咸腺涎馅羡宪掺锨舷铣",
		["xiang"] = "相向降巷香想项翔乡享象响详像箱祥橡湘厢镶",
		["xiao"] = "小笑校消削销俏效晓孝宵肖萧啸淆硝箫嚣哮",
		["xie"] = "邪鞋些血写蝎协泄谢斜卸泻谐歇屑携挟胁懈械蟹楔",
		["xin"] = "心信新薪辛欣衅芯锌",
		["xing"] = "行兴形性星省刑姓幸型醒腥杏猩邢",
		["xiong"] = "胸雄兄凶熊汹匈",
		["xiu"] = "休臭修朽宿秀羞袖绣锈嗅",
		["xu"] = "休邪虚徐许畜须序叙吁绪续恤婿需絮蓄旭酗",
		["xuan"] = "悬旋县选券宣玄轩喧炫癣漩",
		["xue"] = "学雪削血穴靴薛",
		["xun"] = "寻训驯循逊讯巡熏询迅殉勋旬汛",
		["ya"] = "牙呀丫压邪哑雅亚鸭涯押鸦崖呀轧芽衙蚜讶",
		["yan"] = "言眼燕烟沿研颜严铅艳炎咽掩殷雁厌盐岩验延演奄焰宴衍淹腌砚阎堰檐谚唁蜒",
		["yang"] = "羊扬仰洋阳央样养详痒氧杨殃鸯秧漾",
		["yao"] = "要药摇腰妖遥钥咬谣邀夭吆耀窑侥舀肴姚",
		["ye"] = "也叶页业夜邪野液爷椰掖冶腋谒",
		["yi"] = "一以仪已意依宜益乙椅艺衣义疑医姨异遗易议移蚁逸翼倚役夷疙伊溢亦谊译抑邑揖壹疫亿奕绎毅屹胰",
		["yin"] = "音隐阴引银饮印因殷淫吟茵瘾蚓姻",
		["ying"] = "应影婴英蝇迎盈营硬鹰映赢萤樱颖莺荧鹦莹缨",
		["yo"] = "哟唷",
		["yong"] = "用涌勇永拥庸泳佣咏踊蛹",
		["you"] = "有又犹右幼油由尤友游优忧幽悠诱邮佑",
		["yu"] = "雨语鱼玉育于与余宇预予浴邪欲域遇渔羽愚逾吁誉狱粥榆尉郁隅裕娱御舆愈喻寓迂愉淤豫芋屿",
		["yuan"] = "远员原源园圆元怨冤袁渊缘院援愿猿辕鸳",
		["yue"] = "乐月约越悦岳跃阅粤",
		["yun"] = "云运孕匀晕韵陨允蕴耘酝",
		["za"] = "杂扎砸咱",
		["zai"] = "在再灾仔载宰栽",
		["zan"] = "攒赞咱暂",
		["zang"] = "赃葬脏藏",
		["zao"] = "造早皂遭蚤灶枣藻燥凿躁糟澡噪",
		["ze"] = "泽择责则仄",
		["zei"] = "贼",
		["zen"] = "怎",
		["zeng"] = "曾增赠憎",
		["zha"] = "扎炸乍诈榨栅喳闸眨查渣铡",
		["zhai"] = "窄债宅摘斋寨",
		["zhan"] = "战站占展斩沾瞻粘盏颤毡栈崭绽蘸",
		["zhang"] = "长丈杖掌张章账涨彰帐障仗胀樟",
		["zhao"] = "找罩照爪着朝招昭召赵沼兆",
		["zhe"] = "折这着哲者辙遮浙蔗",
		["zhei"] = "这",
		["zhen"] = "真枕针振阵震珍贞镇侦诊斟疹榛",
		["zheng"] = "正争证政症征整蒸挣拯郑筝怔睁狰",
		["zhi"] = "只之知趾纸止枝至支直肢汁指植制质智志芝织职治致址置执值脂殖旨吱侄掷帜秩蜘挚窒滞稚",
		["zhong"] = "重中种众终钟忠仲衷肿盅",
		["zhou"] = "轴周咒舟州骤粥肘昼宙洲皱帚",
		["zhua"] = "爪抓",
		["zhu"] = "主烛蛛助祝猪珠朱注住柱著逐竹筑诸铸驻株拄嘱贮煮蛀",
		["zhuai"] = "拽跩",
		["zhuan"] = "转传专砖赚撰",
		["zhuang"] = "状装壮撞妆庄桩幢",
		["zhui"] = "追椎锥坠赘缀",
		["zhun"] = "准屯淳谆",
		["zhuo"] = "着桌捉拙琢卓浊酌灼茁啄",
		["zi"] = "子自字紫姿资仔滋姊籽滓咨",
		["zong"] = "纵总棕宗踪综",
		["zou"] = "走奏揍邹",
		["zu"] = "足诅族祖组卒租阻",
		["zuan"] = "钻攥",
		["zui"] = "嘴罪醉最",
		["zun"] = "尊遵樽鳟",
		["zuo"] = "作坐昨做左座撮琢"
	},
}

item.active = nil
item.register_retry = 0
item.register_retry_interval = 30
item.repeat_delay = 18
item.repeat_interval = 4
item.keyboard_char_table = {
	[32] = {" "," "},[39] = {"'","\""},[44] = {",","<"},[45] = {"-","_"},[46] = {".",">"},[47] = {"/","?"},
	[48] = {"0",")"},[49] = {"1","!"},[50] = {"2","@"},[51] = {"3","#"},[52] = {"4","$"},[53] = {"5","%"},[54] = {"6","^"},[55] = {"7","&"},[56] = {"8","*"},[57] = {"9","("},
	[59] = {";",":"},[61] = {"=","+"},
	[65] = {"a","A"},[66] = {"b","B"},[67] = {"c","C"},[68] = {"d","D"},[69] = {"e","E"},[70] = {"f","F"},[71] = {"g","G"},[72] = {"h","H"},[73] = {"i","I"},[74] = {"j","J"},[75] = {"k","K"},[76] = {"l","L"},[77] = {"m","M"},
	[78] = {"n","N"},[79] = {"o","O"},[80] = {"p","P"},[81] = {"q","Q"},[82] = {"r","R"},[83] = {"s","S"},[84] = {"t","T"},[85] = {"u","U"},[86] = {"v","V"},[87] = {"w","W"},[88] = {"x","X"},[89] = {"y","Y"},[90] = {"z","Z"},
	[91] = {"[","{"},[92] = {"\\","|"},[93] = {"]","}"},[96] = {"`","~"},
	[320] = {"0","0"},[321] = {"1","1"},[322] = {"2","2"},[323] = {"3","3"},[324] = {"4","4"},[325] = {"5","5"},[326] = {"6","6"},[327] = {"7","7"},[328] = {"8","8"},[329] = {"9","9"},
	[330] = {".","."},[331] = {"/","/"},[332] = {"*","*"},[333] = {"-","-"},[334] = {"+","+"},[336] = {"=","="},
}

local function split_utf8(str)
	local ret = {}
	local i = 1
	str = str or ""
	while i <= #str do
		local b = string.byte(str,i)
		local len = 1
		if b and b >= 240 then len = 4
		elseif b and b >= 224 then len = 3
		elseif b and b >= 192 then len = 2 end
		table.insert(ret,string.sub(str,i,i + len - 1))
		i = i + len
	end
	return ret
end

local function clamp_cursor(state)
	state.cursor = math.max(0,math.min(state.cursor or 0,#state.chars))
end

local function key_triggered(key,controllerIndex)
	-- Keyboard input is always exposed on controller 0. This mirrors SZX's
	-- polling path; applying the controller-button key % 32 filter here can
	-- discard valid keyboard presses.
	return Input.IsButtonTriggered(key,0)
end

local function key_pressed(key,controllerIndex)
	return Input.IsButtonPressed(key,0)
end

function item.new_state(text)
	local state = {
		chars = split_utf8(text or ""),
		cursor = 0,
		pinyin = "",
		mode = "zh",
		page = 1,
		page_size = 8,
		submitted = false,
		cancelled = false,
		hold_key = nil,
		hold_frame = 0,
		shift_down = false,
		shift_pending = false,
		shift_used = false,
		shift_frames = 0,
		caps_lock = false,
		suppress_escape_until_release = false,
	}
	state.cursor = #state.chars
	return state
end

function item.get_text(state)
	state = state or item.active
	if state == nil then return "" end
	return table.concat(state.chars)
end

item.common_char_order = "的一是了我不在人有他这个上们来到时大地为子中你说生年着就那和要她出也得里后自以会家可下而过天去能对小多然于心学么之都好看起发当没成只如事把还用第样道想作种开美总从无情己面最女但现前些所同日手又行意动方期它头经长儿回位分爱老因很给名法间知世两次使身者被高已亲其进此话常与活正感见明问力理点文几定本公特做外孩相西果走将月十实向声车全信重三机工物气每并别真打太新比才便夫再书部水像眼等体却加电主界门利海受听表德少代员许先口由死安写性马光白或住难望教命花结乐色更拉东神记处让母父应直字场平报友关放至张认接告入笑内英军候民岁往何度山觉路带万男边风解叫任金快原吃变通师立象数四失满战远格士音轻目条病始达深完今提求清王化空业思非找片罗钱语元喜曾离飞科言干流欢约各即指合反题必该论交终林请医晚制球决传画保读运及则房早院量苦火布品近坐产答星精视五连司奇管类未朋婚台夜青北队久乎越观落尽形影红百令周识步希术留市半热送兴造谈容极随演收首根讲整式取照办强石古华拿计装似足双转诉米称丽客南领节衣站黑刻统断福城故历惊脸选包紧争另建维绝树系伤示愿持千史谁准"
item.max_syllable_length = 6
item.prefix_index = nil
item.common_rank = nil
item.candidate_cache = {}

local function ensure_indexes()
	if item.prefix_index ~= nil then return end
	item.prefix_index = {}
	item.common_rank = {}
	for index,ch in ipairs(split_utf8(item.common_char_order)) do
		if item.common_rank[ch] == nil then item.common_rank[ch] = index end
	end
	for syllable,_ in pairs(item.data) do
		item.max_syllable_length = math.max(item.max_syllable_length,#syllable)
		for length = 1,#syllable do
			local prefix = string.sub(syllable,1,length)
			item.prefix_index[prefix] = item.prefix_index[prefix] or {}
			table.insert(item.prefix_index[prefix],syllable)
		end
	end
	for _,syllables in pairs(item.prefix_index) do table.sort(syllables) end
end

local function frequency_data()
	save.elses = save.elses or {}
	local key = item.own_key.."frequency"
	save.elses[key] = save.elses[key] or {}
	return save.elses[key]
end

local function can_segment_tail(text,memo)
	if text == "" then return true end
	ensure_indexes()
	memo = memo or {}
	if memo[text] ~= nil then return memo[text] end
	if item.prefix_index[text] then memo[text] = true return true end
	for length = math.min(item.max_syllable_length,#text),1,-1 do
		local syllable = string.sub(text,1,length)
		if item.data[syllable] and can_segment_tail(string.sub(text,length + 1),memo) then
			memo[text] = true
			return true
		end
	end
	memo[text] = false
	return false
end

function item.resolve_pinyin(pinyin)
	pinyin = string.lower(pinyin or "")
	if pinyin == "" then return "","",{} end
	ensure_indexes()
	if item.prefix_index[pinyin] then return pinyin,"",{pinyin} end
	for length = math.min(item.max_syllable_length,#pinyin - 1),1,-1 do
		local syllable = string.sub(pinyin,1,length)
		local rest = string.sub(pinyin,length + 1)
		if item.data[syllable] and can_segment_tail(rest,{}) then
			local segments = {syllable}
			local remain = rest
			while remain ~= "" do
				if item.prefix_index[remain] then
					table.insert(segments,remain)
					break
				end
				local found = false
				for next_length = math.min(item.max_syllable_length,#remain),1,-1 do
					local next_syllable = string.sub(remain,1,next_length)
					local next_rest = string.sub(remain,next_length + 1)
					if item.data[next_syllable] and can_segment_tail(next_rest,{}) then
						table.insert(segments,next_syllable)
						remain = next_rest
						found = true
						break
					end
				end
				if not found then table.insert(segments,remain) break end
			end
			return syllable,rest,segments
		end
	end
	return pinyin,"",{pinyin}
end

local function learned_score(frequency,query,ch)
	return (frequency[query..":"..ch] or 0) * 1000000000 +
		(frequency["*:"..ch] or 0) * 10000000
end

local function build_candidates(query)
	ensure_indexes()
	if item.candidate_cache[query] then return item.candidate_cache[query] end
	local frequency = frequency_data()
	local found = {}
	for _,syllable in ipairs(item.prefix_index[query] or {}) do
		for source_index,ch in ipairs(split_utf8(item.data[syllable])) do
			local common_index = item.common_rank[ch] or 10000
			local score = learned_score(frequency,query,ch)
			if syllable == query then score = score + 1000000 end
			score = score + math.max(0,500000 - common_index * 500)
			score = score + 1000 - source_index - (#syllable - #query) * 10
			local old = found[ch]
			if old == nil or score > old.score then
				found[ch] = {char = ch,score = score,syllable = syllable,source_index = source_index}
			end
		end
	end
	local ranked = {}
	for _,candidate in pairs(found) do table.insert(ranked,candidate) end
	table.sort(ranked,function(a,b)
		if a.score ~= b.score then return a.score > b.score end
		if a.syllable ~= b.syllable then return a.syllable < b.syllable end
		if a.source_index ~= b.source_index then return a.source_index < b.source_index end
		return a.char < b.char
	end)
	local ret = {}
	for _,candidate in ipairs(ranked) do table.insert(ret,candidate.char) end
	item.candidate_cache[query] = ret
	return ret
end

function item.get_candidates(pinyin,page,page_size)
	pinyin = string.lower(pinyin or "")
	page = math.max(1,page or 1)
	page_size = page_size or 8
	local query,rest,segments = item.resolve_pinyin(pinyin)
	local chars = build_candidates(query)
	local ret = {}
	local first = (page - 1) * page_size + 1
	for i = first,math.min(#chars,first + page_size - 1) do
		table.insert(ret,chars[i])
	end
	return ret,#chars,query,rest,segments
end

function item.change_page(state,delta)
	state = state or item.active
	if state == nil or state.pinyin == "" then return false end
	local _,total = item.get_candidates(state.pinyin,1,state.page_size)
	local page_count = math.max(1,math.ceil(total / state.page_size))
	local old_page = state.page or 1
	state.page = math.max(1,math.min(page_count,old_page + delta))
	return state.page ~= old_page
end

function item.get_page_info(state)
	state = state or item.active
	if state == nil then return 1,1 end
	local _,total = item.get_candidates(state.pinyin,1,state.page_size)
	return state.page or 1,math.max(1,math.ceil(total / state.page_size))
end

local function insert_text(state,text)
	for _,ch in ipairs(split_utf8(text)) do
		table.insert(state.chars,state.cursor + 1,ch)
		state.cursor = state.cursor + 1
	end
end

function item.commit_candidate(state,index)
	state = state or item.active
	if state == nil or state.pinyin == "" then return false end
	index = index or 1
	local candidates,_,query,rest = item.get_candidates(state.pinyin,state.page,state.page_size)
	local ch = candidates[index]
	if ch == nil then return false end
	insert_text(state,ch)
	local frequency = frequency_data()
	frequency[query..":"..ch] = (frequency[query..":"..ch] or 0) + 1
	frequency["*:"..ch] = (frequency["*:"..ch] or 0) + 1
	item.candidate_cache = {}
	state.pinyin = rest
	state.page = 1
	return true
end

function item.input_char(state,ch)
	state = state or item.active
	if state == nil or ch == nil then return false end
	if ch == "\b" then
		if state.pinyin ~= "" then
			state.pinyin = string.sub(state.pinyin,1,-2)
			state.page = 1
		elseif state.cursor > 0 then
			table.remove(state.chars,state.cursor)
			state.cursor = state.cursor - 1
		end
		return true
	elseif ch == "\n" or ch == "\r" then
		if state.pinyin ~= "" then item.commit_candidate(state,1)
		else state.submitted = true end
		return true
	elseif ch == " " then
		if state.pinyin ~= "" then return item.commit_candidate(state,1) end
		insert_text(state,ch)
		return true
	end
	local byte = string.byte(ch,1)
	if byte and byte >= 49 and byte <= 57 and state.pinyin ~= "" then
		return item.commit_candidate(state,byte - 48)
	end
	if byte and ((byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)) then
		if state.mode == "en" then
			insert_text(state,ch)
		else
			state.pinyin = state.pinyin..string.lower(ch)
			state.page = 1
		end
		return true
	end
	insert_text(state,ch)
	return true
end

function item.toggle_mode(state)
	state = state or item.active
	if state == nil then return false end
	if state.mode == "zh" then
		if state.pinyin ~= "" then item.commit_candidate(state,1) end
		state.mode = "en"
	else
		state.mode = "zh"
	end
	return true
end

function item.text_with_cursor(state)
	state = state or item.active
	if state == nil then return "" end
	local ret = {}
	for i = 1,#state.chars do
		if i - 1 == state.cursor then table.insert(ret,"|") end
		table.insert(ret,state.chars[i])
	end
	if state.cursor >= #state.chars then table.insert(ret,"|") end
	return table.concat(ret)
end

function item.control_string(str)
	if item.active == nil then item.active = item.new_state(str or "") end
	return item.get_text(item.active)
end

function item.open(key,text,on_change,on_submit,controllerIndex)
	item.active = item.new_state(text or "")
	item.active.key = key
	item.active.on_change = on_change
	item.active.on_submit = on_submit
	item.active.controller_index = controllerIndex
	return item.active
end

function item.close(submit)
	if item.active and submit and item.active.on_submit then
		item.active.on_submit(item.get_text(item.active),item.active)
	end
	item.active = nil
end

local function consume_key(state,key,value,shift)
	if key == Keyboard.KEY_CAPS_LOCK then
		state.caps_lock = not state.caps_lock
	elseif state.mode == "zh" and state.pinyin ~= "" and
		(key == Keyboard.KEY_MINUS or key == Keyboard.KEY_PAGE_UP or key == Keyboard.KEY_KP_SUBTRACT) then
		item.change_page(state,-1)
	elseif state.mode == "zh" and state.pinyin ~= "" and
		(key == Keyboard.KEY_EQUAL or key == Keyboard.KEY_PAGE_DOWN or key == Keyboard.KEY_KP_ADD) then
		item.change_page(state,1)
	elseif key == Keyboard.KEY_BACKSPACE then
		item.input_char(state,"\b")
	elseif key == Keyboard.KEY_ENTER or key == Keyboard.KEY_KP_ENTER then
		item.input_char(state,"\n")
	elseif key == Keyboard.KEY_ESCAPE then
		state.cancelled = true
	elseif key == Keyboard.KEY_LEFT then
		state.cursor = math.max(0,(state.cursor or 0) - 1)
	elseif key == Keyboard.KEY_RIGHT then
		state.cursor = math.min(#state.chars,(state.cursor or 0) + 1)
	elseif value then
		local normal = value[1]
		local shifted = value[2]
		local is_letter = normal and string.match(normal,"^[a-z]$") ~= nil
		local uppercase = (shift == true) ~= (state.caps_lock == true)
		local output = is_letter and (uppercase and shifted or normal) or (shift and shifted or normal)
		if is_letter and state.mode == "zh" and (shift or state.caps_lock) then
			insert_text(state,output)
		else
			item.input_char(state,output)
		end
	end
	if state.on_change then state.on_change(item.get_text(state),state) end
	if state.debug_name then
		Isaac.DebugString("[Qing ChineseInput] key="..tostring(key)..
			" mode="..tostring(state.mode)..
			" pinyin="..tostring(state.pinyin)..
			" text="..tostring(item.get_text(state)))
	end
	return true
end

function item.update_keyboard_input(controllerIndex)
	local state = item.active
	if state == nil then return false end
	controllerIndex = 0
	local shift = key_pressed(Keyboard.KEY_LEFT_SHIFT,controllerIndex) or key_pressed(Keyboard.KEY_RIGHT_SHIFT,controllerIndex)
	local shift_changed = false
	if shift and not state.shift_down then
		state.shift_pending = true
		state.shift_used = false
		state.shift_frames = 0
	elseif shift and state.shift_down then
		state.shift_frames = (state.shift_frames or 0) + 1
	elseif not shift and state.shift_down then
		if state.shift_pending and not state.shift_used and (state.shift_frames or 0) < 12 then
			item.toggle_mode(state)
			if state.on_change then state.on_change(item.get_text(state),state) end
			shift_changed = true
		end
		state.shift_pending = false
		state.shift_used = false
		state.shift_frames = 0
	end
	state.shift_down = shift

	if state.suppress_escape_until_release and not key_pressed(Keyboard.KEY_ESCAPE,controllerIndex) then
		state.suppress_escape_until_release = false
	end
	local check_keys = {Keyboard.KEY_CAPS_LOCK,Keyboard.KEY_BACKSPACE,Keyboard.KEY_ENTER,Keyboard.KEY_KP_ENTER,Keyboard.KEY_LEFT,Keyboard.KEY_RIGHT}
	if not state.suppress_escape_until_release then table.insert(check_keys,Keyboard.KEY_ESCAPE) end
	if state.mode == "zh" and state.pinyin ~= "" then
		table.insert(check_keys,Keyboard.KEY_MINUS)
		table.insert(check_keys,Keyboard.KEY_EQUAL)
		table.insert(check_keys,Keyboard.KEY_PAGE_UP)
		table.insert(check_keys,Keyboard.KEY_PAGE_DOWN)
		table.insert(check_keys,Keyboard.KEY_KP_SUBTRACT)
		table.insert(check_keys,Keyboard.KEY_KP_ADD)
	end
	for _,key in ipairs(check_keys) do
		if key_triggered(key,controllerIndex) then
			state.hold_key = key ~= Keyboard.KEY_CAPS_LOCK and key or nil
			state.hold_frame = 0
			return consume_key(state,key,nil,shift)
		end
	end
	for key,value in pairs(item.keyboard_char_table) do
		if key_triggered(key,controllerIndex) then
			if shift then state.shift_used = true end
			state.hold_key = key
			state.hold_frame = 0
			return consume_key(state,key,value,shift)
		end
	end
	if state.hold_key and key_pressed(state.hold_key,controllerIndex) then
		state.hold_frame = (state.hold_frame or 0) + 1
		if state.hold_frame >= item.repeat_delay and (state.hold_frame - item.repeat_delay) % item.repeat_interval == 0 then
			return consume_key(state,state.hold_key,item.keyboard_char_table[state.hold_key],shift)
		end
	else
		state.hold_key = nil
		state.hold_frame = 0
	end
	return shift_changed
end

function item.try_register_console_names(force)
	local ok,zh = pcall(require,"Qing_Remaster_scripts.translations.zh")
	if ok and zh and zh.register_chinese_console then
		return zh.register_chinese_console(force)
	end
	return false
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if not item.try_register_console_names(false) then
		item.register_retry = (item.register_retry or 0) + 1
		if item.register_retry % item.register_retry_interval == 0 then item.try_register_console_names(true) end
	end
end,
})

if IsaacSocket then
	table.insert(item.ToCall,#item.ToCall + 1,{CallBack = "ISMC_PRE_CHAR_INPUT", params = nil,
	Function = function(_,ch)
		if item.active then
			item.input_char(item.active,ch)
			if item.active.on_change then item.active.on_change(item.get_text(item.active),item.active) end
		end
	end,
	})
end

return item
