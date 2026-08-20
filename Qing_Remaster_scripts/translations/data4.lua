local save = require("Qing_Remaster_scripts.core.savedata")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")

local function check_string(wd,language,params)
	if wd == nil then return "" end
	if type(wd) == "table" then 
		return check_string(wd.word,language,params)
	end
	if type(wd) == "function" then
		return check_string(wd(language,params),language,params)
	end
	if type(wd) == "string" then
		return wd
	end
	return ""
end

local function get_kind_of_word(tbl,language,idx,ignore_special_check,params)
	if tbl == nil then return "" end
	if tbl[language] == nil or #(tbl[language]) == 0 then language = "zh" end
	local ret = check_string(tbl[language][idx or math.random(#tbl[language])],language,params)
	if tbl.special_check and ignore_special_check ~= true then
		ret = tbl.special_check(ret,language,params) or ret
	end
	return ret
end

local function get_multi_word(wd,mul)
	local ret = ""
	mul = mul or math.random(10)
	for i = 1,mul do
		ret = ret .. wd
	end
	return ret
end

local ask_why = {
	zh = {
		"为什么",
		"为甚么",
		"怎么",
		"为何",
		"为啥",
		"什么原因",
	},
}

local ask_if = {
	zh = {
		"是不是",
		"莫非",
		"有没有可能",
		"如果说",
		"有可能",
		"可能",
		"也许",
		"很可能",
		"万一",
		"说不定",
		"或许",
		"如果",
		"如果说",
	},
}

local ask_what = {
	zh = {
		"什么",
		"啥",
	},
}

local ask_is = {
	zh = {
		"是",
		"叫",
		"名叫",
	},
}

local find_a_place = {
	zh = {
		"商店",
		"隐藏",
		"超隐",
		"挑战",
		"宝箱房",
	},
}

local find_a_dir = {
	zh = {
		"左边",
		"上边",
		"下边",
		"右边",
		"左上",
		"左下",
		"右下",
		"右上",
	},
}

local find_near = {
	zh = {
		"附近",
		"边上",
		"旁边",
		"那里",
		"那块",
	},
}

local get_hurt = {
	zh = {
		"被打",
		"受伤",
		"被揍",
		"掉血",
		"扣血",
		"损血",
	},
}

local get_good = {
	zh = {
		"牛",
		"强",
		"很强",
		"厉害",
		"很厉害",
		"可以",
		"优秀",
		"高手",
		"大师",
	},
}

local get_know = {
	zh = {
		"知道",
		"晓得",
		"清楚",
		"懂",
		"懂得",
	},
}

local get_bad = {
	zh = {
		"不行",
		"差劲",
		"不足",
		"不够",
		"够呛",
		"拉胯",
		"拉了",
		"下等",
		"低下",
		"低劣",
	},
}

local get_not = {
	zh = {
		"不",
		"没有",
	},
}

local get_don_t = {
	zh = {
		"别",
		"别再",
		"不要",
	},
}

local get_go = {
	zh = {
		"去",
		"得",
		"要",
	},
}

local get_pickup = {
	zh = {
		"搞",
		"拿",
		"选",
		"选择",
		"选个",
	},
}

local get_pick = {
	zh = {
		"拿到",
		"拿到了",
		"得到",
		"得到了",
		"搞到",
		"搞到了",
		"获得",
		"获得了",
	},
}

local get_need = {
	zh = {
		"要",
		"拿",
		"选择",
		"需要",
		"想要",
	},
}

local get_just = {
	zh = {
		"就",
		"只有",
		"就只有",
		"才",
		"才就",
		"就才",
		"就剩",
		"只剩",
	},
}

local get_kind = {
	zh = {
		"有点",
		"有些",
		"稍微有点",
		"感觉有点",
	},
}

local get_if = {
	zh = {
		"如果",
		"倘若",
		"假如",
		"有可能的话",
	},
}

local get_play = {
	zh = {
		"上",
		"来",
		"来玩",
		"玩",
	},
}

local get_dead = {
	zh = {
		"没",
		"死",
		"逝世",
		"寄",
		"挂掉",
	},
}

local get_sent = {
	zh = {
		"投喂",
		"赠送",
	},
}

local get_this_game = {
	zh = {
		"这把",
		"这局",
		"这次",
		"今天",
		"本局",
		"本把",
	},
}

local get_very = {
	zh = {
		"好",
		"实在",
		"确实",
		"真的",
		"非常",
		"极其",
		"超级",
		"十分",
		"very",
	},
}

local get_totally = {
	zh = {
		"根本",
		"实在",
		"确实",
		"真的",
		"非常",
		"极其",
		"十分",
		"绝对",
		"very",
	},
}

local get_skill = {
	zh = {
		"水平",
		"水准",
		"本事",
		"技术",
		"能力",
	},
}

local get_luck = {
	zh = {
		"运气",
		"幸运",
		"人品",
	},
}

local get_generous = {
	zh = {
		"大气",
		"断气",
		"被骗",
		"糊涂",
		"牛",
		"有钱",
		"慷慨",
	},
}

local get_description = {
	zh = {
		"大气",
		"细小",
		"吓人",
		"糊涂",
		"大量",
		"有钱",
		"慷慨",
		"清白",
		"朝阳",
		"现成",
		"可怜",
		"不定",
		"发火",
		"天生",
		"详细",
		"知足",
		"刻苦",
		"刚好",
		"和气",
		"黄色",
		"正好",
		"永久",
		"用功",
		"知己",
		"草本",
		"老大",
		"冷清",
		"不合",
		"友爱",
		"非分",
		"相对",
		"透明",
		"安定",
		"安乐",
		"安全",
		"安心",
		"动人",
		"多余",
		"暗淡",
		"平和",
		"平静",
		"齐全",
		"奇妙",
		"热情",
		"热心",
		"听话",
		"出名",
		"晴朗",
		"亲爱",
		"暖和",
		"明净",
		"忙乱",
		"平淡",
		"漂亮",
		"平安",
		"平常",
		"怕人",
		"冰凉",
		"亮晶晶",
		"吃力",
		"得力",
		"低级",
		"低下",
		"长远",
		"潮湿",
		"本来",
		"大方",
		"聪明",
		"纯净",
		"笔直",
		"可以",
		"冰冷",
		"白净",
		"金黄",
		"可能",
		"绿色",
		"光亮",
		"光明",
		"广大",
		"共同",
		"知名",
		"直接",
		"完美",
		"听说",
		"明白",
		"明亮",
		"迷人",
		"专心",
		"专业",
		"专一",
		"自然",
		"凉快",
		"冷淡",
		"礼貌",
		"理想",
	},
	en = {
		"Generous",
		"Lucky",
		"Golden",
		"Kind",
		"Anonymous",
		"Legendary",
		"Sleepy",
		"Cheerful",
		"Brave",
		"Mysterious",
		"Friendly",
		"Loaded",
	},
}

local ultrasecret_name = {
	zh = {
		"红隐",
		"超级红色隐藏",
		"红色隐藏",
		"究极隐藏",
		"究极红色隐藏",
		"红色隐藏房间",
		"红隐房间",
		"红超隐",
	},
}

local lost_name = {
	zh = {
		"小罗",
		"罗",
		"额啊宝",
		"嗯啊宝",
		"罗斯特宝",
		"罗斯特",
		"小罗斯特",
	},
}

local wrong_work = {
	zh = {
		"按下空格",
		"长按R键",
		"放个炸弹",
		"按按暂停",
		"打个boss",
		"卖个血",
		"拍个q",
	},
}

local meaningless_pre_word = {
	zh = {
		"O(N_N)O",
		"^_^",
		"( ^o^ )",
		"(.—.)",
		"嗨，",
		"嗨，",
		"哟，",
		"呀，",
		"呀！",
		"哇塞，",
		"哇塞！",
		"好耶！",
		"好耶！！",
		"好诶！",
		"好诶！！",
		"贴贴！",
		"贴贴！！",
		"爱你，",
		"爱你！",
		"永远爱你，",
		"永远爱你！",
		"小以撒，",
		"那个，",
		"可可爱爱，",
		"早好，",
		"午好，",
		"晚好，",
	}
}

local meaningless_post_word = {
	zh = {
		"~",
		"捏~",
		"捏",
		"捏捏",
		"捏捏哦",
		"...",
		"口牙",
		"贴贴",
		"呵呵",
		"呜哇",
		"唔唔",
		"呜哇~",
		"哇",
		"咕哇",
		"咕哇~",
		"咕",
		"摸摸",
		"摸摸！",
		"摸摸~",
		"......",
		"--------",
		"O(N_N)O",
		"^_^",
		"( ^o^ )",
		"(.—.)",
	},
}

local get_yeqi_name = {
	zh = {
		"夜骑",
		"夜骑老师",
		"夜0",
		"夜0老师",
		"strong1老师",
		"strong0老师",
	},
}

local Accusative_name = {
	zh = {
		"主播",
		"主播大叔",
		"这位光头主播",
		"老师",
		"光头老师",
		"Up",
		"Up主",
		"你",
		"您",
		"这位主播",
		"主播主播",
		"这主播",
	},
	special_check = function(ret,language,params)
		if save.elses.data4_mode == 1 and math.random(1000) > 500 then
			return get_kind_of_word(get_yeqi_name,language)
		end
		return ret
	end,
}

local post_sigh_word = {
	zh = {
		"啊",
		"呀",
		"么",
		"呢",
		"哇",
	},
}

local post_done_word = {
	zh = {
		"啊",
		"喽",
		"呀",
		"咯",
		"哦",
		"呢",
		"哇",
		"吧",
	},
}

local post_please_word = {
	zh = {
		"啊",
		"呗",
		"呀",
		"呐",
		"哇",
		"吧",
	},
}

local pre_question_word = {
	zh = {
		"不会吧",
		"不会吧，不会吧",
		"草，",
		"果然",
		"到底",
		"到底还是",
		"哈哈",
		"哈哈哈哈",
		"哈哈哈哈到底还是",
		"原来",
	},
}

local post_question_word = {
	zh = {
		"么",
		"嘛",
		"吗",
		"啊",
		"啊",
	},
}

local in_agressive_word = {
	zh = {
		"好",
		"真",
		"真的",
		"实在",
		"太",
		"果然",
	},
}

local post_aggressive_word = {
	zh = {
		"了",
		"啦",
		"了吧",
		"啊",
	},
}

local depressive_word = {
	zh = {
		"菜",
		"菜鸡",
		"菜狗",
		"傻",
		"弱",
		"笨",
		"笨猪",
		"不会玩",
		"不行",
		"没玩过",
	},
}

local useless_word = {
	zh = {
		"不会玩",
		"不行",
		"没玩过",
		"没水平",
	},
}

local Isaac_name = {
	zh = {
		"以撒",
		"比撤",
		"艾扎克",
		"小以撒",
		"光头",
		"光头魔王",
		"挨扎克",
		"爱扎克",
	},
}

local TBOI_name = {
	zh = {
		"以撒的结合",
		"比撤的给台",
		"艾扎克大冒险",
		"小以撒大冒险",
		"光头历险记",
		"光头魔王创世录",
		"挨扎克大冒险",
		"爱扎克的故事",
		"以撒的燔祭",
	},
}

local q_u_word = {
	zh = {
		"下载游戏Tb.oI，果休小阑孩等你来玩，就在s+EaM平台",
		"下载游戏Tb.oI，尅艾男孩自由换装，就在s+EaM平台",
		"想和楠彤亲密击剑？就在l;IvE.bi=li_BiLI.co_m/123_八7_三8-6",
		"扣1即送骚0香吻，就在liVe.b?il-i_BiL!I.com/幺二38七_3八6",
	},
}

local q_u_name = {
	zh = {
		"片哥",
		"麦片哥",
		"片总",
	},
}

local q_u_work = {
	zh = {
		"上个舰",
		"上个舰长",
		"来个舰长",
		"上个提督",
		"来个提督",
		"发个SC",
	},
}

local ask_for_game = {
	zh = {
		function(language,params)
			local ret = "什么游戏"
			if math.random(1000) > 400 then
				ret = "是" .. ret
			end
			if math.random(1000) > 400 then
				ret = "这" .. ret
			end
			if math.random(1000) > 600 then
				ret = ret .. "啊"
			end
			if params.no_mark ~= true then
				if math.random(1000) > 300 then
					ret = ret .. "？"
				end
			end
			return ret
		end,
		function(language,params)
			local ret = "查询游戏名"
			if math.random(1000) > 400 then
				ret = "可否" .. ret
				if math.random(1000) > 400 then
					ret = "请问" .. ret
				end
			end
			if params.no_mark ~= true then
				if math.random(1000) > 300 then
					ret = ret .. "？"
				end
			end
			return ret
		end,
		function(language,params)
			local ret = "这个游戏"
			if math.random(1000) > 600 then
				ret = "请问" .. ret
			elseif math.random(1000) > 600 then
				ret = "没人说一下" .. ret
			end
			ret = ret .. get_kind_of_word(ask_is,language) .. get_kind_of_word(ask_what,language)
			if params.no_mark ~= true then
				if math.random(1000) > 300 then
					ret = ret .. "？"
				end
			end
			return ret
		end,
	},
}

local data = {
	zh = {
		[1] = {				--表达快乐
			[1] = {
				word = function() 
					return "h" .. get_multi_word("h")
				end
			},
			[2] = {
				word = function() 
					return "23"..get_multi_word("3")
				end
			},
			[3] = {
				word = function() 
					return "哈哈"..get_multi_word("哈")
				end
			},
			[4] = {
				word = function() 
					local ret = "乐"
					if math.random(1000) > 500 then ret = ret .. "不住了" end
					return ret
				end
			},
			[5] = {
				word = function() 
					local ret = "草"
					if math.random(1000) > 700 then 
						ret = ret ..get_multi_word("草")
					end
					return ret
				end
			},
			[6] = "笑死",
			[7] = "节目效果拉满",
			[8] = "这也太有节目了",
			[9] = "绷不住了",
			[10] = "今日份快乐",
			work_on_wd = function(wd,language,rnd)
				local ret = wd
				if math.random(1000) > 700 then ret = get_kind_of_word(meaningless_pre_word,language) .. ret end
				if rnd ~= 1 and rnd ~= 2 then
					if math.random(1000) > 700 then ret = ret .. get_kind_of_word(meaningless_post_word,language) end
				end
				return ret
			end,
		},
		[2] = {				--打招呼
			[1] = "中午好",
			[2] = "下午好",
			[3] = "晚上好",
			[4] = "早上好",
			[5] = "早",
			[6] = "早啊",
			[7] = "唔唔",
			[8] = "贴贴",
			[9] = "初见，可爱，单推",
			[10] = "好耶",
			[11] = "玩以撒",
			[12] = "开心",
			[13] = "那个",
			[14] = "主播好",
			[15] = "第一次来",
			[16] = "前排围观",
			[17] = "开播了开播了",
			[18] = "今天播多久",
			[19] = "声音画面都正常",
			[20] = "签到",
			work_on_wd = function(wd,language)
				local ret = wd
				if math.random(1000) > 700 then ret = get_kind_of_word(meaningless_pre_word,language) .. ret end
				if math.random(1000) > 700 then ret = ret .. get_kind_of_word(meaningless_post_word,language) end
				return ret
			end,
		},
		[3] = {				--指指点点
			[1] = {
				word = function(language) 
					local ret = ""
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(Accusative_name,language) end
					if math.random(1000) > 700 then 
						ret = ret .. "是不是"
					elseif math.random(1000) > 200 then 
						ret = ret .. get_kind_of_word(in_agressive_word,language)
					end
					ret = ret .. get_kind_of_word(depressive_word,language)
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_aggressive_word,language) end
					return ret
				end,
			},
			[2] = {
				word = function(language,params)
					local load_name = params.target_zh or params.name or "那个道具"
					local ret = ""
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(Accusative_name,language) if math.random(1000) > 500 then ret = ret .. "，" end end
					if math.random(1000) > 500 then
						ret = ret ..get_kind_of_word(ask_why,language)
						ret = ret ..get_kind_of_word(get_not,language).. get_kind_of_word(get_need,language)..load_name
						if math.random(1000) > 300 then ret = ret .. get_kind_of_word(post_question_word,language) end
						if math.random(1000) > 700 then ret = ret .. "？" end
					elseif math.random(1000) > 700 then
						ret = ret .. load_name .. get_kind_of_word(ask_why,language) 
						if math.random(1000) > 500 then ret = ret .. "都" end
						ret = ret.. get_kind_of_word(get_not,language) .. get_kind_of_word(get_need,language) .. "的"
						if math.random(1000) > 300 then ret = ret .. get_kind_of_word(post_question_word,language) end
						if math.random(1000) > 700 then ret = ret .. "？" end
					else
						ret = ret ..get_kind_of_word(ask_why,language)
						if math.random(1000) > 500 then ret = ret .. "连" end
						ret = ret ..load_name .. "都" ..get_kind_of_word(get_not,language).. get_kind_of_word(get_need,language)
						if math.random(1000) > 500 then ret = ret .. "的" end
						if math.random(1000) > 300 then ret = ret .. get_kind_of_word(post_question_word,language) end
						if math.random(1000) > 700 then ret = ret .. "？" end
					end
					return ret
				end
			},
			[3] = {
				word = function(language,params)
					local ret = ""
					ret = ret .. "这都能"
					ret = ret .. get_kind_of_word(get_hurt,language)
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_sigh_word,language) end
					if math.random(1000) > 500 then ret = ret .. "！" end
					return ret
				end
			},
			[4] = {
				word = function(language,params)
					local ret = ""
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(Accusative_name,language) end
					ret = ret .. get_kind_of_word(get_just,language) .. "这点" .. get_kind_of_word(get_skill,language)
					if math.random(1000) > 500 then ret = ret .. "了" end
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_question_word,language) end
					if math.random(1000) > 700 then ret = ret .. "？" end
					if math.random(1000) > 500 then ret = ret .. "！" end
					return ret
				end
			},
			[5] = {
				word = function(language,params)
					local load_name = params.name or "鸭架"
					local ret = ""
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(Accusative_name,language) end
					ret = ret ..  get_kind_of_word(get_pick,language) .. load_name
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(get_this_game,language) end
					ret = ret .. "稳了"
					if math.random(1000) > 200 then ret = ret .. get_kind_of_word(post_sigh_word,language) end
					return ret
				end
			},
			[6] = {
				word = function(language,params)
					local ret = ""
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(Accusative_name,language) end
					ret = ret .. get_kind_of_word(get_luck,language) .. get_kind_of_word(get_good,language)
					if math.random(1000) > 500 then ret = ret .. "，" end
					ret = ret .. get_kind_of_word(get_skill,language) .. get_kind_of_word(get_bad,language)
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_sigh_word,language) end
					if math.random(1000) > 500 then ret = ret .. "！" end
					return ret
				end
			},
			[7] = {
				word = function(language) 
					local ret = "这"
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(Accusative_name,language) end
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(get_totally,language) end
					ret = ret .. get_kind_of_word(useless_word,language)
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_sigh_word,language) end
					if math.random(1000) > 500 then ret = ret .. "！" end
					return ret
				end,
			},
			[8] = "这走位是认真的吗",
			[9] = "建议先看路",
			[10] = "背包管理大师",
			[11] = "主播有自己的理解",
			[12] = "刚才那下可以躲吧",
		},
		[4] = {				--云，以及意义不明
			[1] = {
				word = function(language) 
					local ret = "刚来，"
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(Accusative_name,language).."，" end
					ret = ret .. get_kind_of_word(ask_for_game,language,nil,nil,{no_mark = true,})
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_question_word,language) end
					if math.random(1000) > 500 then ret = ret .. "？" end
					return ret
				end
			},
			[2] = {
				word = function(language) 
					local ret = "游戏" .. get_kind_of_word(ask_is,language)
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(ask_what,language) end
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_question_word,language) end
					if math.random(1000) > 700 then ret = ret .. "？" end
					return ret
				end
			},
			[3] = {
				word = function(language) 
					local ret = ""
					if math.random(1000) > 500 then ret = ret .. "游戏" .. get_kind_of_word(ask_is,language) end
					ret = ret .. get_kind_of_word(TBOI_name,language)
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_done_word,language) end
					if math.random(1000) > 500 then ret = ret .. "。" end
					return ret
				end
			},
			[4] = {
				word = function(language) 
					local ret = "不"
					if math.random(1000) > 500 then ret = "我" .. ret end
					ret = ret .. get_kind_of_word(get_know,language)
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_done_word,language) end
					if math.random(1000) > 500 then ret = ret .. "！" end
					return ret
				end
			},
			[5] = {
				word = function(language) 
					local ret = get_kind_of_word(ask_why,language) .. "在吃坏药"
					if math.random(1000) > 500 then if math.random(1000) > 500 then ret = "，" .. ret  end ret = get_kind_of_word(Accusative_name,language) .. ret end
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_question_word,language) end
					if math.random(1000) > 700 then ret = ret .. "？" end
					return ret
				end
			},
			[6] = "刚来，这是受苦直播吗",
			[7] = "有人知道主播在干什么吗",
			[8] = "这局能通关吗",
			[9] = "主播麦是不是没开",
			[10] = "画质不错，就是人有点糊",
		},
		[5] = {				--运气不错
			[1] = {
				word = function() 
					return get_multi_word("?")
				end
			},
			[2] = {
				word = function(language) 
					local ret = "感谢" .. get_kind_of_word(Accusative_name,language) .. "送的问号风暴"
					if math.random(1000) > 850 then ret = ret .. "！" end
					return ret
				end
			},
			[3] = {
				word = function() 
					local ret = "不能接受"
					if math.random(1000) > 500 then ret = "不相信" end
					if math.random(1000) > 500 then ret = ret .. "！" end
					if math.random(1000) > 500 then ret = "我" .. ret end
					return ret
				end
			},
			[4] = {
				word = function() 
					local ret = "不可能"
					if math.random(1000) > 500 then ret = ret .. "！" end
					if math.random(1000) > 500 then ret = "这" .. ret end
					if math.random(1000) > 500 then ret = ret .. "绝对不可能！" end
					return ret
				end
			},
			[5] = {
				word = function() 
					local ret = "" .. get_kind_of_word(ask_what,language) .. "？"
					return ret
				end
			},
			[6] = "欧皇实锤",
			[7] = "这也能出",
			[8] = "运气全用在这里了",
			[9] = "这局有了",
			[10] = "概率学不存在了",
		},
		[6] = {				--操作不错
			[1] = {
				word = function() 
					local ret = get_multi_word("牛",6)
					if math.random(1000) > 500 then ret = ret .. "！" end
					return ret
				end
			},
			[2] = {
				word = function(language) 
					local ret = get_multi_word("牛哇",2)
					if math.random(1000) > 500 then ret = ret .. "！" end
					return ret
				end
			},
			[3] = {
				word = function() 
					local ret = ""
					ret = get_multi_word(get_kind_of_word(get_good,language),2)
					if math.random(1000) > 500 then ret = get_kind_of_word(Accusative_name,language) .. ret end
					return ret
				end
			},
			[4] = {
				word = function() 
					local ret = "爱了爱了"
					if math.random(1000) > 500 then ret = "ilil" end
					if math.random(1000) > 500 then ret = get_kind_of_word(Accusative_name,language) .. "操作" .. get_kind_of_word(get_good,language) .. "，" .. ret end
					if math.random(1000) > 700 then 
						ret = "路人，" .. ret 
						if math.random(1000) > 700 then ret = "纯" .. ret end
					end
					return ret
				end
			},
			[5] = "好躲",
			[6] = "这波细节",
			[7] = "操作拉满",
			[8] = "有点东西",
			[9] = "这就是技术主播吗",
		},
		[7] = {				--危机
			[1] = {
				word = function() 
					local ret = get_multi_word("危",6)
					if math.random(1000) > 500 then ret = ret .. "！" end
					return ret
				end
			},
			[2] = {
				word = function() 
					local ret = "危"
					if math.random(1000) > 500 then ret = ret .. "！" end
					if math.random(1000) > 500 then ret = "高" .. ret end
					if math.random(1000) > 500 then ret = get_kind_of_word(Accusative_name,language) .. ret end
					return ret
				end
			},
			[3] = {
				word = function() 
					local ret = "吓人"
					if math.random(1000) > 500 then ret = ret .. "了" end
					if math.random(1000) > 500 then ret = ret .. "啊" end
					if math.random(1000) > 500 then ret = ret .. "！" end
					if math.random(1000) > 700 then ret = get_kind_of_word(get_kind,language) .. ret 
					elseif math.random(1000) > 500 then ret = get_kind_of_word(get_very,language) .. ret end
					if math.random(1000) > 500 then ret = get_kind_of_word(Accusative_name,language) .. ret end
					return ret
				end
			},
			[4] = {
				word = function() 
					local ret = "小心"
					if math.random(1000) > 500 then ret = "要" .. ret end
					if math.random(1000) > 500 then ret = get_kind_of_word(Accusative_name,language) .. ret end
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_sigh_word,language) end
					if math.random(1000) > 500 then ret = ret .. "！" end
					return ret
				end
			},
			[5] = {
				word = function() 
					local ret = "浪"
					ret = get_kind_of_word(get_don_t,language) .. ret
					if math.random(1000) > 500 then ret = get_kind_of_word(Accusative_name,language) .. ret end
					if math.random(1000) > 500 then ret = ret .. "了" end
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_sigh_word,language) end
					if math.random(1000) > 500 then ret = ret .. "！" end
					return ret
				end
			},
			[6] = {
				word = function() 
					local ret = "要浪到" .. get_kind_of_word(get_dead,language)
					if math.random(1000) > 500 then ret = get_kind_of_word(Accusative_name,language) .. ret end
					if math.random(1000) > 500 then ret = ret .. "了" end
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_sigh_word,language) end
					if math.random(1000) > 500 then ret = ret .. "！" end
					return ret
				end
			},
			[7] = "稳住稳住",
			[8] = "心跳加速了",
			[9] = "别贪伤害",
			[10] = "先保命啊",
			[11] = "这血量看得我害怕",
		},
		[8] = {				--考试的场合
			[1] = {
				word = function(language) 
					local ret = "考试"
					if math.random(1000) > 800 then ret = ret .. get_multi_word("考试",5) 
					elseif math.random(1000) > 400 then ret = ret .. get_kind_of_word(post_done_word,language) end
					if math.random(1000) > 500 then ret = ret .. "！" end
					return ret
				end
			},
			[2] = {
				word = function(language) 
					local ret = ""
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(ask_if,language) end
					if math.random(1000) > 300 then ret = ret .. get_kind_of_word(ultrasecret_name,language) end
					ret = ret .. "在"
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(find_a_place,language) .. get_kind_of_word(find_near,language)
					else ret = ret .. get_kind_of_word(find_a_dir,language) end
					if math.random(1000) > 300 then ret = ret .. get_kind_of_word(post_question_word,language) end
					if math.random(1000) > 700 then ret = ret .. "？" end
					return ret
				end
			},
			[3] = "红钥匙启动",
			[4] = "开始猜红隐",
			[5] = "答案不会在最离谱的位置吧",
			[6] = "今天的考试题超纲了",
		},
		[9] = {				--片哥专供
			[1] = {
				word = function(language) 
					local ret = get_kind_of_word(q_u_word,language)
					if math.random(1000) > 500 then ret = ret .. "！" end
					return ret
				end
			},
			[2] = {
				word = function(language) 
					local ret = ""
					ret = ret .. "保护"
					if math.random(1000) > 700 then ret = ret .. get_kind_of_word(q_u_name,language)
					elseif math.random(1000) > 500 then ret = ret .. get_multi_word("保护") end
					if math.random(1000) > 500 then ret = ret .. "！" end
					return ret
				end
			},
			[3] = {
				word = function(language) 
					local ret = ""
					ret = ret .. get_kind_of_word(q_u_name,language)
					ret = ret .. get_kind_of_word(q_u_work,language)
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_please_word,language) end
					if math.random(1000) > 500 then ret = ret .. "！" end
					return ret
				end
			},
			[4] = "免费游戏道具点击就送",
			[5] = "主播看看私信，急事",
			[6] = "已举报广告号",
		},
		[10] = {			--长时间离开后的弹幕
			[1] = {
				word = function(language) 
					local ret = ""
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(Accusative_name,language) end
					ret = ret .. "还在" .. get_kind_of_word(post_question_word,language)
					if math.random(1000) > 700 then ret = ret .. "？" end
					return ret
				end
			},
			[2] = {
				word = function(language) 
					local ret = ""
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(Accusative_name,language) end
					ret = ret .. "还在不在" .. get_kind_of_word(post_question_word,language)
					if math.random(1000) > 700 then ret = ret .. "？" end
					return ret
				end
			},
			[3] = {
				word = function(language) 
					local ret = "椅子" .. get_kind_of_word(wrong_work,language)
					return ret
				end
			},
			[4] = {
				word = function(language) 
					local ret = ""
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(Accusative_name,language) end
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(ask_if,language) end
					ret = ret .. "睡着了"
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_question_word,language) end
					if math.random(1000) > 700 then ret = ret .. "？" end
					return ret
				end
			},
			[5] = {
				word = function(language) 
					local ret = ""
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(Accusative_name,language) end
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(ask_if,language) end
					ret = ret .. "不想玩"
					if math.random(1000) > 500 then ret = ret .. "了" end
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_question_word,language) end
					if math.random(1000) > 700 then ret = ret .. "？" end
					return ret
				end
			},
			[6] = "人呢人呢",
			[7] = "主播被椅子夺舍了",
			[8] = "摄像头前经过了一阵风",
			[9] = "回来记得动一下",
		},
		[11] = {			--死亡的嘲讽
			[1] = {
				word = function(language) 
					local ret = ""
					ret = ret .. "起立"
					if math.random(1000) > 500 then ret = ret .. "！" end
					if math.random(1000) > 500 then ret = "全体" .. ret end
					return ret
				end
			},
			[2] = {
				word = function(language) 
					local ret = ""
					ret = ret .. "好死"
					if math.random(1000) > 500 then ret = get_kind_of_word(Accusative_name,language) .. ret end
					return ret
				end
			},
			[3] = {
				word = function(language) 
					local ret = ""
					ret = ret .. "菜"
					if math.random(1000) > 800 then
						if math.random(1000) > 500 then
							ret = ret .. "就多练练"
						else
							ret = ret .. "死啦！"
						end
					else
						if math.random(1000) > 200 then ret = get_kind_of_word(in_agressive_word,language) .. ret end
						if math.random(1000) > 500 then ret = get_kind_of_word(Accusative_name,language) .. ret end
					end
					return ret
				end
			},
			[4] = {
				word = function(language) 
					local ret = ""
					ret = ret .. "看不下去了"
					if math.random(1000) > 500 then ret = get_kind_of_word(get_totally,language).. ret end
					if math.random(1000) > 500 then ret = ret .. "，" .. get_kind_of_word(get_if,language) .. "让我" .. get_kind_of_word(get_play,language)  end
					return ret
				end
			},
			[5] = {
				word = function(language) 
					local ret = ""
					ret = ret .. "寄"
					if math.random(1000) > 500 then ret = get_kind_of_word(Accusative_name,language).. ret end
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_done_word,language) end
					return ret
				end
			},
			[6] = "经典结局",
			[7] = "重开下一把",
			[8] = "刚才不算",
			[9] = "这就是最后一局吗",
			[10] = "存档扣一",
		},
		[12] = {			--小罗死亡
			[1] = {
				word = function(language) 
					local ret = get_kind_of_word(lost_name,language)
					if math.random(1000) > 500 then	ret = ret .. get_multi_word("—",7) end
					if math.random(1000) > 500 then	ret = ret .. "~" end
					if math.random(1000) > 500 then	ret = "不！" .. ret end
					return ret
				end
			},
			[2] = {
				word = function(language) 
					local ret = "额啊"
					if math.random(1000) > 500 then	ret = ret .. get_multi_word("——",4) end
					if math.random(1000) > 500 then ret = ret .. "~" end
					return ret
				end
			},
			[3] = "不——我的神圣斗篷",
			[4] = "小罗今天也很努力了",
			[5] = "盾呢，盾救一下啊",
		},
		[13] = {			--老板点播、投喂
			[1] = {
				word = function(language,params)
					local load_name = params.name
					local ret = ""
					ret = ret .. "老板" .. get_kind_of_word(get_generous,language)
					if load_name and math.random(1000) > 700 then ret = load_name .. ret end
					if math.random(1000) > 600 then ret = ret .. get_kind_of_word(post_sigh_word,language) end
					if math.random(1000) > 600 then ret = ret .. "！" end
					return ret
				end
			},
			[2] = {
				word = function(language,params)
					local load_name = params.name or "ysd"
					local load_word = params.word or "好多礼物"
					local ret = load_name
					ret = ret .. "老板" .. get_kind_of_word(get_sent,language) .. "了" .. load_word
					if math.random(1000) > 600 then ret = ret .. get_kind_of_word(post_sigh_word,language) end
					if math.random(1000) > 600 then ret = ret .. "！" end
					return ret
				end
			},
			[3] = "感谢老板投喂",
			[4] = "老板大气",
			[5] = "礼物收到啦",
		},
		[14] = {			--下播
			[1] = {
				word = function() 
					return get_multi_word("再见")
				end
			},
			[2] = {
				word = function() 
					return get_multi_word("拜拜")
				end
			},
			[3] = {
				word = function() 
					return get_multi_word("88")
				end
			},
			[4] = "才八点",
			[5] = "才十点",
			[6] = "别啊",
			[7] = "羞愧下播",
			[8] = "下次一定来看",
			[9] = "主播晚安",
			[10] = "别走，再来一局",
			[11] = "今天也辛苦了",
			work_on_wd = function(wd,language)
				local ret = wd
				if math.random(1000) > 700 then ret = get_kind_of_word(meaningless_pre_word,language) .. ret end
				if math.random(1000) > 700 then ret = ret .. get_kind_of_word(meaningless_post_word,language) end
				return ret
			end,
		},
		[15] = {			--特殊描述
			[1] = {
				word = function(language,params)
					local load_name = params.name
					local ret = load_name
					if math.random(1000) > 500 then ret = "快" .. ret end
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_sigh_word,language) end
					if math.random(1000) > 500 then ret = ret .. "！" end
					return ret
				end
			},
			[2] = {
				word = function(language,params)
					local load_name = params.name
					local ret = load_name
					if math.random(1000) > 500 then ret = "是" .. ret end
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_sigh_word,language) end
					if math.random(1000) > 500 then ret = ret .. "！" end
					return ret
				end
			},
			[3] = {
				word = function(language,params)
					local load_name = params.name
					local rnd = math.random(2) * 2 + 1
					local ret = get_multi_word(load_name,rnd)
					if math.random(1000) > 500 then ret = ret .. "！" end
					return ret
				end
			},
			[4] = {
				word = function(language,params)
					return "主播看看" .. (params.name or "这个")
				end
			},
			[5] = {
				word = function(language,params)
					return (params.name or "这个") .. "能拿！"
				end
			},
		},
		[16] = {			--死亡证明
			[1] = {
				word = function(language,params)
					local ret = get_kind_of_word(get_go,language)..get_kind_of_word(get_pickup,language)
					local collid = auxi.get_quality_item(4) or 33
					local col = Isaac.GetItemConfig():GetCollectible(collid) or Isaac.GetItemConfig():GetCollectible(33)
					local info = item_displaying_holder.check_description("UnItem",collid,auxi.check_name_data(col.Name),auxi.check_name_data(col.Description),player)
					ret = ret..info.Name
					if math.random(1000) > 500 then ret = get_kind_of_word(Accusative_name,language) .. ret end
					if math.random(1000) > 500 then ret = ret .. get_kind_of_word(post_done_word,language) end
					if math.random(1000) > 500 then ret = ret .. "!" end
					return ret
				end
			},
			[2] = "死亡证明启动",
			[3] = "四级道具随便挑",
		},
		[17] = {			--未拾取道具的上下文解释
			[1] = function(language,params)
				local target = params.target_zh or "这个主动"
				local starts = {"可能主播觉得","我猜主播觉得","主播大概是觉得","也许在主播看来"}
				local endings = {"手上的主动更好","现在这个主动更顺手","当前主动更适合这局","换掉手里的不划算"}
				return auxi.random_in_table(starts) .. auxi.random_in_table(endings)
					.. (math.random(2) == 1 and "，所以没拿"..target or "")
			end,
			[2] = function(language,params)
				local target = params.target_zh or "这个道具"
				local starts = {"不是不想拿，","先别急，","这波真不是挑食，","答案很现实："}
				local endings = nil
				if params.payment_kind == "heart" then
					endings = {"没有心之容器付"..target.."的价","付不起"..target.."的血上限","主播没有能交易的血上限"}
				else
					endings = {"买不起"..target,"钱不够拿"..target,"主播的预算不允许","硬币数对不上价格"}
				end
				return auxi.random_in_table(starts) .. auxi.random_in_table(endings)
			end,
			[3] = function()
				local starts = {"等等，","商店里不是还有存款机吗，","缺钱的话，","主播看看旁边，"}
				local endings = {"炸存款机试试","可以向存款机借一点","这一炸说不定就够了","存款机该发挥作用了"}
				return auxi.random_in_table(starts) .. auxi.random_in_table(endings)
			end,
			[4] = function(language,params)
				local target = params.target_zh or "这个道具"
				local starts = {"多选的话我站","我觉得该选","这几个里面更看好","认真说，"}
				local endings = {target.."挺强的",target.."值得拿",target.."更适合这局",target.."应该是正解"}
				return auxi.random_in_table(starts) .. auxi.random_in_table(endings)
			end,
			[5] = function(language,params)
				local target = params.target_zh or "这个道具"
				local starts = {"多选里","我个人觉得","真要比较的话，","这次可以先放过"}
				local endings = {target.."比较弱",target.."收益不太够",target.."不值得占这个选择",target.."大概不是答案"}
				return auxi.random_in_table(starts) .. auxi.random_in_table(endings)
			end,
			[6] = function(language,params)
				local target = params.target_zh or "这个道具"
				local starts = {"这个多选有点难，","客观评价，","我觉得","要看后续搭配，"}
				local endings = {target.."能拿但不关键",target.."强度一般",target.."属于看情况",target.."和另外几个差不多"}
				return auxi.random_in_table(starts) .. auxi.random_in_table(endings)
			end,
			[7] = function(language,params)
				local target = params.target_zh or "这个道具"
				local starts = {"问号层怎么评价，","这谁看得出来，","道具都被遮住了，","先别云，"}
				local endings = {"只能说主播没选"..target,"观众也不知道"..target.."是什么","这次真没法比强度","只能按位置讨论"}
				return auxi.random_in_table(starts) .. auxi.random_in_table(endings)
			end,
		},
	},
	en = {
		[1] = {				--reactions
			"LMAO",
			"LOL",
			"KEKW",
			"I can't",
			"Peak entertainment",
			"That was perfect",
			"Comedy gold",
			"Chat is losing it",
		},
		[2] = {				--greetings
			"Good morning!",
			"Good afternoon!",
			"Good evening!",
			"Hi streamer!",
			"First time here",
			"Glad I caught the stream",
			"Hello chat",
			"Just tuned in",
			"Audio and video are good",
			"Let's go!",
		},
		[3] = {				--backseating and criticism
			"Streamer is throwing",
			function(language,params)
				return "Why skip " .. (params.target_en or params.name or "that item") .. "?"
			end,
			"How did that hit you?",
			"That is certainly one way to play",
			function(language,params)
				return (params.name or "That pickup") .. " wins the run"
			end,
			"Good luck, questionable gameplay",
			"Has the streamer played before?",
			"Maybe look where you are going",
			"Inventory management masterclass",
			"Chat would have dodged that",
		},
		[4] = {				--idle chatter
			"Just joined, what game is this?",
			"Game name?",
			"The Binding of Isaac!",
			"I have no idea what is happening",
			"Why take the bad pill?",
			"Is this a challenge run?",
			"Can this run still win?",
			"Mic check?",
			"Great stream, very confusing",
		},
		[5] = {				--good luck
			function() return get_multi_word("?") end,
			"Thanks for the question mark storm",
			"I cannot believe this",
			"No way! Absolutely no way!",
			"What?!",
			"Streamer luck is real",
			"That actually dropped?",
			"The run is saved",
		},
		[6] = {				--good play
			"INSANE",
			"Nice!",
			"Clean play",
			"That dodge was beautiful",
			"Perfect timing",
			"Streamer has hands",
			"Calculated",
			"Actual skill",
		},
		[7] = {				--danger
			"DANGER DANGER",
			"High danger!",
			"This is terrifying",
			"Careful!",
			"Do not get greedy",
			"One hit from disaster",
			"Play safe!",
			"My heart cannot take this",
		},
		[8] = {				--red-key exam
			"Pop quiz time!",
			"Where is the Ultra Secret Room?",
			"Red Key exam starts now",
			"Chat, place your guesses",
			"It is always in the weirdest spot",
			"This question is unfair",
		},
		[9] = {				--spam
			"FREE ITEMS! CLICK THIS TOTALLY SAFE LINK!",
			"MODS PROTECT CHAT",
			"Ban the spam bot",
			"Reported",
			"Nice try, bot",
		},
		[10] = {			--away for too long
			"Streamer, are you still there?",
			"Hello? Anyone home?",
			"The chair is streaming now",
			"Did the streamer fall asleep?",
			"Maybe they abandoned the run",
			"Move once if you are alive",
			"Best chair stream today",
		},
		[11] = {			--player death
			"Everyone stand",
			"Rest in pieces",
			"Skill issue",
			"I cannot watch this",
			"Run over",
			"Classic ending",
			"One more run",
			"That one did not count",
		},
		[12] = {			--The Lost death
			"NOOO, THE LOST!",
			"The Lost is lost again",
			"There goes Holy Mantle",
			"He tried his best",
			"Where did the shield go?",
		},
		[13] = {			--sponsors and gifts
			function(language,params)
				local name = params.name
				if name then return name .. " is a generous sponsor!" end
				return "What a generous sponsor!"
			end,
			function(language,params)
				local name = params.name or "A mysterious sponsor"
				local word = params.word or "a pile of gifts"
				return name .. " sent " .. word .. "!"
			end,
			"Thank you for the gift!",
			"Sponsor coming through!",
			"Chat, thank the sponsor!",
		},
		[14] = {			--stream ending
			"Bye bye!",
			"See you next stream!",
			"Good night!",
			"It is only eight!",
			"One more run!",
			"Do not end the stream!",
			"Thanks for streaming",
			"Take care!",
		},
		[15] = {			--special item callouts
			function(language,params)
				return "Take " .. (params.name or "that item") .. "!"
			end,
			function(language,params)
				return "It is " .. (params.name or "the item") .. "!"
			end,
			function(language,params)
				local name = params.name or "TAKE IT"
				return name .. "! " .. name .. "!"
			end,
			function(language,params)
				return "Streamer, look at " .. (params.name or "that") .. "!"
			end,
			function(language,params)
				return (params.name or "That item") .. " is the play"
			end,
		},
		[16] = {			--Death Certificate
			function()
				local collid = auxi.get_quality_item(4) or 33
				local col = Isaac.GetItemConfig():GetCollectible(collid) or Isaac.GetItemConfig():GetCollectible(33)
				local info = item_displaying_holder.check_description("UnItem",collid,auxi.check_name_data(col.Name),auxi.check_name_data(col.Description),nil)
				return "Go take " .. info.Name .. "!"
			end,
			"Death Certificate value!",
			"Pick any quality-four item!",
		},
		[17] = {			--context for skipped collectibles
			function(language,params)
				local target = params.target_en or "that active item"
				local starts = {"Maybe the streamer thinks ","I guess ","Probably ","Could be that "}
				local endings = {"the current active is better","their active fits the run better","swapping actives is not worth it","the active they have is safer"}
				local suffix = math.random(2) == 1 and ", so they skipped "..target or ""
				return auxi.random_in_table(starts) .. auxi.random_in_table(endings) .. suffix
			end,
			function(language,params)
				local target = params.target_en or "that item"
				local starts = {"They are not skipping it, ","Easy explanation: ","This is not being picky, ","Chat, look at the price: "}
				local endings = nil
				if params.payment_kind == "heart" then
					endings = {"there is no heart container to pay for "..target,"they cannot pay the max-health cost","the streamer has no red health to trade"}
				else
					endings = {"they cannot afford "..target,"there is not enough money for "..target,"the budget says no","the coin count does not match the price"}
				end
				return auxi.random_in_table(starts) .. auxi.random_in_table(endings)
			end,
			function()
				local starts = {"Wait, ","There is still a donation machine. ","If money is the problem, ","Streamer, look around. "}
				local endings = {"Bomb the donation machine","Time to borrow from the donation machine","One bomb might pay for it","The donation machine can help"}
				return auxi.random_in_table(starts) .. auxi.random_in_table(endings)
			end,
			function(language,params)
				local target = params.target_en or "that item"
				local starts = {"For this choice, ","I would take ","Out of these, ","Honestly, "}
				local endings = {target.." is strong",target.." is worth taking",target.." fits the run best",target.." looks like the right pick"}
				return auxi.random_in_table(starts) .. auxi.random_in_table(endings)
			end,
			function(language,params)
				local target = params.target_en or "that item"
				local starts = {"Among these, ","Personally, ","If we compare them, ","It is fine to skip "}
				local endings = {target.." is the weak one",target.." does not offer enough",target.." is not worth the choice",target.." is probably not the answer"}
				return auxi.random_in_table(starts) .. auxi.random_in_table(endings)
			end,
			function(language,params)
				local target = params.target_en or "that item"
				local starts = {"This choice is close. ","Objectively, ","I think ","It depends on the build, but "}
				local endings = {target.." is fine but not essential",target.." is average",target.." is situational",target.." is about as good as the others"}
				return auxi.random_in_table(starts) .. auxi.random_in_table(endings)
			end,
			function(language,params)
				local target = params.target_en or "that item"
				local starts = {"How do we rate a question mark? ","Nobody can see it. ","The item is hidden, ","No blind backseating: "}
				local endings = {"we only know they skipped "..target,"chat does not know what "..target.." is","there is no way to compare quality","we can only call out its position"}
				return auxi.random_in_table(starts) .. auxi.random_in_table(endings)
			end,
		},
	},
}

function data.get_a_word(language,tp,vr,params)
	params = params or {}
	if language == nil or data[language] == nil or #data[language] == 0 then language = "zh" end
	tp = (tp or math.random(#data[language]))
	local info = data[language][tp]
	local rnd = vr or math.random(#info)
	local wd = check_string(info[rnd],language,params) or ""
	if info.work_on_wd then	wd = info.work_on_wd(wd,language,rnd) or wd end
	return wd
end

function data.get_a_description(language)
	return get_kind_of_word(get_description,language)
end

function data.set_mode(md)
	save.elses.data4_mode = md
end

return data
