local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local save = require("Qing_Remaster_scripts.core.savedata")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	original_info = {
		monsters = {
			normal = {
				{Type = 10,Variant = 0,level = 1,},
				{Type = 10,Variant = 1,level = 1,},
				{Type = 10,Variant = 2,level = 1,},
				{Type = 10,Variant = 3,SubType = {0,1,2,3,4,5,},level = 4,},
				{Type = 87,Variant = 0,level = 2,},
				{Type = 87,Variant = 1,level = 2,},
				{Type = 252,Variant = 0,level = 3,},
				{Type = 284,Variant = 0,level = 1,},
				{Type = 297,Variant = 0,level = 4,},
				{Type = 299,Variant = 0,level = 5,},
				{Type = 807,Variant = 0,level = 1,},
				{Type = 811,Variant = 0,SubType = {0,1,2,3,4,5,6,},level = 1,},
				{Type = 813,Variant = 0,level = 1,},
				{Type = 850,Variant = 0,level = 4,},
				{Type = 850,Variant = 1,level = 4,},
				{Type = 850,Variant = 2,level = 4,},
				{Type = 912,Variant = 20,level = 4,},
				{Type = 827,Variant = 0,level = 2,},
				{Type = 827,Variant = 1,level = 5,},
				{Type = 832,Variant = 0,level = 3,},
				{Type = 832,Variant = 1,level = 3,},
				{Type = 876,Variant = 0,level = 1,},
				{Type = 876,Variant = 1,level = 1,},
				{Type = 11,Variant = 0,level = 1,},
				{Type = 11,Variant = 1,level = 1,},
				{Type = 238,Variant = 0,level = 2,},
				{Type = 280,Variant = 0,level = 3,},
				{Type = 12,Variant = 0,level = 1,},
				{Type = 248,Variant = 0,level = 3,},
				{Type = 812,Variant = 0,level = 1,},
				{Type = 812,Variant = 1,level = 5,},
				{Type = 828,Variant = 0,level = 2,},
				{Type = 15,Variant = 0,level = 1,},
				{Type = 15,Variant = 1,level = 3,},
				{Type = 15,Variant = 2,level = 1,},
				{Type = 15,Variant = 3,level = 1,},
				{Type = 872,Variant = 0,level = 1,},
				{Type = 16,Variant = 0,level = 1,},
				{Type = 16,Variant = 1,level = 1,},
				{Type = 16,Variant = 2,level = 1,},
				{Type = 22,Variant = 0,level = 1,},
				{Type = 22,Variant = 1,level = 1,},
				{Type = 22,Variant = 2,level = 5,},
				{Type = 22,Variant = 3,level = 5,},
				{Type = 205,Variant = 0,level = 1,},
				{Type = 310,Variant = 0,level = 4,},
				{Type = 310,Variant = 0,SubType = 1,level = 4,},
				{Type = 310,Variant = 0,SubType = 2,level = 4,},
				{Type = 310,Variant = 0,SubType = 3,level = 4,},
				{Type = 310,Variant = 1,level = 4,},
				{Type = 817,Variant = 0,level = 1,},
				{Type = 817,Variant = 1,level = 1,},
				{Type = 822,Variant = 0,level = 2,},
				{Type = 874,Variant = 0,level = 1,},
				{Type = 820,Variant = 0,level = 2,},
				{Type = 820,Variant = 1,level = 2,},
				{Type = 821,Variant = 0,level = 2,},
				{Type = 21,Variant = 0,level = 2,},
				{Type = 23,Variant = 0,SubType = {0,1,},level = 2,},
				{Type = 23,Variant = 1,level = 2,},
				{Type = 23,Variant = 2,level = 3,},
				{Type = 23,Variant = 3,level = 2,},
				{Type = 810,SubType = {0,1,},Variant = 0,level = 1,},
				{Type = 853,Variant = 0,level = 4,mul = {3,4,5,6,7,8,},},
				{Type = 855,Variant = 0,level = 5,},
				{Type = 855,Variant = 1,level = 5,},
				{Type = 884,Variant = 0,level = 3,mul = {4,5,6,7,8,}},
				--802
				{Type = 31,Variant = 0,level = 2,},
				{Type = 31,Variant = 1,level = 5,},
				{Type = 243,Variant = 0,level = 2,},
				{Type = 24,Variant = 0,level = 2,},
				{Type = 24,Variant = 1,level = 2,},
				{Type = 24,Variant = 2,level = 3,},
				{Type = 24,Variant = 3,level = 3,},
				{Type = 278,Variant = 0,level = 3,},
				{Type = 889,Variant = 0,level = 2,},
				{Type = 856,Variant = 0,level = 4,},
				{Type = 857,Variant = 0,level = 4,},
				{Type = 27,Variant = 0,level = 3,},
				{Type = 27,Variant = 1,level = 4,},
				{Type = 27,Variant = 3,level = 2,},
				{Type = 204,Variant = 0,level = 3,},
				{Type = 247,Variant = 0,level = 3,},
				{Type = 300,Variant = 0,level = 2,},
				{Type = 30,Variant = 0,level = 1,},
				{Type = 30,Variant = 1,level = 2,},
				{Type = 30,Variant = 2,level = 1,},
				{Type = 298,Variant = 0,level = 4,},
				{Type = 309,Variant = 0,level = 3,},
				{Type = 861,Variant = 0,level = 4,},
				{Type = 88,Variant = 0,level = 2,},
				{Type = 88,Variant = 1,level = 2,},
				{Type = 88,Variant = 2,level = 2,},
				{Type = 32,Variant = 0,level = 4,},
				{Type = 279,Variant = 0,level = 3,},
				{Type = 831,Variant = 20,level = 4,},
				{Type = 824,Variant = 0,level = 2,},
				{Type = 824,Variant = 1,level = 1,},
				{Type = 35,Variant = 0,level = 3,},
				{Type = 35,Variant = 1,level = 2,},
				{Type = 35,Variant = 2,level = 3,},
				{Type = 35,Variant = 3,level = 2,},
				{Type = 216,Variant = 0,level = 4,},
				{Type = 39,Variant = 0,level = 3,},
				{Type = 39,Variant = 1,level = 3,},
				{Type = 39,Variant = 2,level = 4,},
				{Type = 39,Variant = 3,level = 4,},
				{Type = 836,Variant = 0,level = 3,},
				{Type = 865,Variant = 0,level = 4,},
				{Type = 40,Variant = 0,SubType = {0,1,2,3,4,},level = 3,},
				{Type = 40,Variant = 1,SubType = {0,1,2,3,4,},level = 4,},
				{Type = 40,Variant = 2,SubType = {0,1,2,3,4,},level = 3,},
				{Type = 862,Variant = 0,SubType = {0,1,2,3,4,},level = 4,},
				{Type = 41,Variant = 0,level = 3,},
				{Type = 41,Variant = 1,level = 3,},
				{Type = 41,Variant = 2,level = 3,},
				--41.3
				{Type = 41,Variant = 4,level = 3,},
				{Type = 283,Variant = 0,level = 5,},
				{Type = 834,Variant = 0,level = 4,},
				{Type = 834,Variant = 1,level = 4,},
				{Type = 834,Variant = 2,level = 4,},
				{Type = 57,Variant = 0,level = 4,},
				{Type = 57,Variant = 1,level = 4,},
				{Type = 57,Variant = 2,level = 4,},
				{Type = 223,Variant = 0,level = 3,},
				{Type = 282,Variant = 0,level = 2,},
				{Type = 60,Variant = 0,level = 4,},
				{Type = 60,Variant = 1,level = 4,},
				{Type = 60,Variant = 2,level = 5,},
				{Type = 77,Variant = 0,level = 1,},
				{Type = 85,Variant = 0,level = 1,},
				{Type = 94,Variant = 0,level = 1,},
				{Type = 814,Variant = 0,level = 1,},
				{Type = 818,Variant = 0,SubType = {0,1,2,3,},level = 2,},
				{Type = 818,Variant = 2,SubType = {0,1,2,3,},level = 2,},
				{Type = 89,Variant = 0,level = 2,},
				{Type = 878,Variant = 0,level = 3,},
				{Type = 92,Variant = 0,level = 3,},
				{Type = 93,Variant = 0,level = 3,},
				{Type = 92,Variant = 1,SubType = {0,1,},level = 4,},
				{Type = 93,Variant = 1,level = 4,},
				{Type = 206,Variant = 0,level = 1,},
				{Type = 206,Variant = 1,level = 1,},
				{Type = 207,Variant = 0,level = 1,},
				{Type = 207,Variant = 1,level = 1,},
				{Type = 208,Variant = 0,level = 1,},
				{Type = 208,Variant = 1,level = 2,},
				{Type = 208,Variant = 2,level = 1,},
				{Type = 209,Variant = 0,level = 3,},
				{Type = 210,Variant = 0,level = 3,},
				{Type = 211,Variant = 0,level = 3,},
				{Type = 257,Variant = 0,level = 2,},
				{Type = 257,Variant = 1,level = 4,},
				{Type = 302,Variant = 0,nonly_spawn = true,level = 1,},
				{Type = 302,Variant = 10,only_spawn = true,level = 1,},
				{Type = 806,Variant = 0,level = 1,},
				{Type = 823,Variant = 0,level = 2,},
				{Type = 830,Variant = 0,level = 2,},
				{Type = 831,Variant = 0,level = 4,},
				--831.10
				{Type = 835,Variant = 0,level = 4,},
				--835.10
				{Type = 875,Variant = 0,level = 1,},		--不会自动飞行
				{Type = 879,Variant = 0,level = 1,},
				{Type = 886,Variant = 0,SubType = {0,1,},level = 3,},
				{Type = 888,Variant = 0,level = 5,},
				{Type = 217,Variant = 0,level = 1,},
				{Type = 217,Variant = 1,level = 1,},
				{Type = 217,Variant = 2,level = 1,},
				{Type = 217,Variant = 3,level = 1,},
				{Type = 870,Variant = 0,level = 1,},
				{Type = 220,Variant = 0,level = 2,},
				{Type = 220,Variant = 1,level = 3,},
				{Type = 826,Variant = 0,level = 2,},
				{Type = 871,Variant = 0,level = 1,},
				{Type = 221,Variant = 0,level = 4,},
				{Type = 226,Variant = 0,level = 1,},
				{Type = 226,Variant = 1,level = 3,},
				{Type = 226,Variant = 2,level = 1,},
				{Type = 227,Variant = 0,level = 3,},
				{Type = 227,Variant = 1,level = 5,},
				{Type = 277,Variant = 0,level = 3,},
				{Type = 841,Variant = 0,level = 3,},
				{Type = 841,Variant = 1,level = 3,},
				{Type = 890,Variant = 0,SubType = {0,1,},level = 3,},
				{Type = 228,Variant = 0,level = 4,},
				{Type = 251,Variant = 0,level = 5,},
				{Type = 231,Variant = 0,level = 4,},
				{Type = 231,Variant = 1,level = 4,},
				{Type = 805,Variant = 0,level = 3,},
				{Type = 237,Variant = 0,level = 2,},
				{Type = 891,Variant = 0,level = 3,},
				{Type = 891,Variant = 1,level = 3,},
				{Type = 239,Variant = 0,mul = {3,4,5,6,7,},level = 2,},
				{Type = 290,Variant = 0,level = 4,},
				{Type = 844,Variant = 0,level = 2,},
				{Type = 306,Variant = 0,level = 5,},
				{Type = 306,Variant = 1,level = 3,},
				{Type = 295,Variant = 0,level = 3,},
				{Type = 892,Variant = 0,level = 3,},
				{Type = 293,Variant = 0,level = 6,mul = {1,2,3,4,},},
				--{Type = 293,Variant = 1,level = 6,},
				{Type = 293,Variant = 2,level = 6,mul = {1,2,3,4,},},
				--{Type = 293,Variant = 3,level = 6,},
				{Type = 818,Variant = 1,SubType = {0,1,2,3,},level = 4,},
				{Type = 829,Variant = 0,level = 2,},
				{Type = 829,Variant = 1,level = 5,},
				--{Type = 906,Variant = 1,},
				--966
			},
			onwall = {
				{Type = 240,Variant = 0,level = 2,},
				{Type = 240,Variant = 1,level = 2,},
				{Type = 240,Variant = 2,level = 3,},
				{Type = 240,Variant = 3,level = 5,},
				{Type = 241,Variant = 0,level = 3,},
				{Type = 241,Variant = 1,level = 3,},
				{Type = 242,Variant = 0,level = 2,},
				{Type = 304,Variant = 0,level = 2,},
			},
			jumpable = {
				{Type = 29,Variant = 0,level = 1,},
				{Type = 29,Variant = 1,level = 2,},
				{Type = 29,Variant = 2,level = 3,},
				{Type = 29,Variant = 3,level = 5,},
				{Type = 34,Variant = 0,level = 3,},
				{Type = 34,Variant = 1,level = 3,},
				{Type = 54,Variant = 0,level = 1,},
				{Type = 246,Variant = 0,level = 2,},
				{Type = 246,Variant = 1,level = 3,},
				{Type = 303,Variant = 0,level = 3,},
				{Type = 840,Variant = 0,level = 3,},
				{Type = 86,Variant = 0,level = 2,},
				{Type = 215,Variant = 0,level = 1,},
				{Type = 250,Variant = 0,level = 1,},
				{Type = 869,Variant = 0,level = 1,},
				{Type = 305,Variant = 0,level = 1,},
				{Type = 851,Variant = 0,level = 4,},
				--815.0
			},
			hideable = {
				{Type = 56,Variant = 0,level = 4,},
				{Type = 307,Variant = 0,level = 3,},
				{Type = 58,Variant = 0,level = 4,},
				{Type = 58,Variant = 1,level = 4,},
				{Type = 59,Variant = 0,level = 4,},
				{Type = 244,Variant = 0,level = 1,},
				{Type = 244,Variant = 1,level = 2,},
				{Type = 244,Variant = 2,level = 5,},
				{Type = 244,Variant = 3,level = 5,},
				{Type = 255,Variant = 0,level = 2,},
				{Type = 276,Variant = 0,level = 1,},
				{Type = 289,Variant = 0,level = 1,},
				{Type = 881,Variant = 0,level = 2,},
				{Type = 881,Variant = 1,level = 2,},
			},
			flyable = {
				{Type = 13,Variant = 0,level = 1,},
				{Type = 18,Variant = 0,level = 1,},
				{Type = 80,Variant = 0,level = 1,},
				--{Type = 96,Variant = 0,},
				{Type = 222,Variant = 0,level = 1,mul = {3,4,5,6,7,8,9,},},
				{Type = 256,Variant = 0,level = 1,},
				{Type = 281,Variant = 0,is_multi = true,level = 1,},
				{Type = 296,Variant = 0,level = 4,mul = {3,4,5,6,7,},},
				{Type = 808,Variant = 0,level = 1,mul = {1,2,3,},only_spawn = function(ent) if ent.ParentNPC and ent.ParentNPC.Type == 160 then return true end end,},
				{Type = 868,Variant = 0,level = 1,mul = {2,3,4,5,},},
				{Type = 951,Variant = 11,SubType = {0,1,2,},level = 4,mul = {1,2,3,4,},},
				{Type = 951,Variant = 21,SubType = {0,1,2,},level = 4,mul = {1,2,3,4,},},
				{Type = 819,Variant = 0,level = 2,},
				--{Type = 819,Variant = 1,},
				{Type = 79,Variant = 10,SubType = {0,1,2,},level = 4,},
				{Type = 79,Variant = 11,SubType = 0,level = 3,},
				{Type = 61,Variant = 0,level = 1,},
				{Type = 61,Variant = 1,level = 2,},
				{Type = 61,Variant = 2,level = 3,},
				{Type = 61,Variant = 3,level = 3,},
				{Type = 61,Variant = 4,level = 4,},
				{Type = 61,Variant = 5,level = 1,},
				{Type = 61,Variant = 6,level = 4,},
				{Type = 61,Variant = 7,level = 5,},
				{Type = 14,Variant = 0,SubType = {0,1,2,},level = 1,},
				{Type = 14,Variant = 1,level = 1,},
				{Type = 14,Variant = 2,level = 5,},
				{Type = 25,Variant = 0,level = 2,},
				{Type = 25,Variant = 1,level = 2,},
				{Type = 25,Variant = 2,level = 2,},
				{Type = 25,Variant = 3,SubType = 0,level = 2,},
				{Type = 25,Variant = 3,SubType = 1,level = 2,},
				{Type = 25,Variant = 4,level = 2,},
				{Type = 25,Variant = 5,level = 4,},
				{Type = 25,Variant = 6,level = 5,},
				{Type = 26,Variant = 0,level = 2,},
				{Type = 26,Variant = 1,level = 2,},
				{Type = 26,Variant = 2,level = 3,},
				{Type = 859,Variant = 0,level = 4,},
				{Type = 301,Variant = 0,level = 4,},
				{Type = 38,Variant = 0,level = 3,},
				{Type = 38,Variant = 1,level = 5,},
				{Type = 38,Variant = 2,level = 5,},
				{Type = 38,Variant = 1,SubType = 1,level = 3,},
				{Type = 38,Variant = 3,level = 4,},
				{Type = 259,Variant = 0,level = 5,},
				{Type = 860,Variant = 0,level = 4,},
				{Type = 883,Variant = 0,level = 3,},
				{Type = 833,Variant = 0,level = 3,},
				{Type = 254,Variant = 0,level = 3,},
				{Type = 55,Variant = 0,level = 3,},
				{Type = 55,Variant = 1,level = 4,},
				{Type = 55,Variant = 2,level = 5,},
				{Type = 854,Variant = 0,level = 4,},
				{Type = 90,Variant = 0,level = 3,},
				{Type = 91,Variant = 0,level = 2,},
				{Type = 886,Variant = 1,level = 3,},
				{Type = 212,Variant = 0,mul = {1,2,3,},ignore_place = true,level = 2,},
				{Type = 212,Variant = 1,level = 3,},
				{Type = 212,Variant = 2,only_spawn = true,ignore_place = true,level = 3,},
				{Type = 212,Variant = 3,only_spawn = true,mul = {1,2,3,},ignore_place = true,level = 3,},
				{Type = 212,Variant = 4,level = 2,},
				{Type = 286,Variant = 0,level = 4,},
				{Type = 887,Variant = 0,mul = {4,5,6,},ignore_place = true,only_spawn = true,level = 2,},
				--{Type = 951,Variant = 42,},
				{Type = 213,Variant = 0,level = 3,},
				{Type = 287,Variant = 0,level = 4,},
				{Type = 214,Variant = 0,level = 1,},
				{Type = 249,Variant = 0,level = 1,},
				{Type = 838,Variant = 0,level = 2,},
				{Type = 219,Variant = 0,level = 3,},
				{Type = 285,Variant = 0,level = 5,},
				{Type = 224,Variant = 0,level = 4,},
				{Type = 225,Variant = 0,level = 5,},
				{Type = 229,Variant = 0,level = 3,},
				{Type = 229,Variant = 1,level = 4,},
				{Type = 230,Variant = 0,level = 5,},
				{Type = 253,Variant = 0,level = 5,},
				{Type = 234,Variant = 0,level = 2,},
				{Type = 258,Variant = 0,level = 2,},
				{Type = 885,Variant = 0,level = 3,},
				{Type = 885,Variant = 1,level = 3,},
				{Type = 260,Variant = 10,level = 3,},
				{Type = 816,Variant = 0,level = 2,},
				{Type = 816,Variant = 1,level = 2,},
				{Type = 882,Variant = 0,level = 2,},
				{Type = 288,Variant = 0,level = 3,},
				{Type = 308,Variant = 0,level = 4,},
				{Type = 873,Variant = 0,level = 1,},
				{Type = 880,Variant = 0,level = 2,},
				{Type = 863,Variant = 0,SubType = {0,1,2,},level = 3,},
				{Type = 864,Variant = 0,level = 3,},
				--409.1
				{Type = 903,Variant = 20,level = 3,mul = {3,4,5,6,},},
				{Type = 951,Variant = 23,level = 5,},
				{Type = 404,Variant = 1,SubType = {0,1,2,},level = 2,},
				{Type = 950,Variant = 10,level = 5,mul = {1,2,3,4,},},
			},
			special = {
				{Type = 53,Variant = 0,},
				{Type = 53,Variant = 1,},
				--{Type = 818,Variant = 1,},
			},
			water = {
				{Type = 311,Variant = 0,},
				{Type = 825,Variant = 0,},
				{Type = 837,Variant = 0,},
			},
			unbreakable = {
				{Type = 42,Variant = 0,},
				{Type = 42,Variant = 1,},
				{Type = 42,Variant = 2,},
				{Type = 201,Variant = 0,},
				{Type = 202,Variant = 0,only_spawn = true,SubType = {0,1,2,3,},},
				{Type = 202,Variant = 10,},
				{Type = 203,Variant = 0,only_spawn = true,SubType = {0,1,2,3,},},
				{Type = 235,Variant = 0,},
				{Type = 236,Variant = 0,},
				{Type = 804,Variant = 0,only_spawn = true,SubType = {0,1,2,3,},},
				{Type = 809,Variant = 0,only_spawn = true,},
				{Type = 893,Variant = 0,only_spawn = true,},
				{Type = 852,Variant = 0,},
				{Type = 915,Variant = 1,},
				{Type = 291,Variant = 0,only_spawn = function(ent) if ent.SpawnerEntity then return true end end,},
				{Type = 291,Variant = 1,},
				{Type = 291,Variant = 2,only_spawn = function(ent) if ent.SpawnerEntity then return true end end,},
			},
			spike = {
				{Type = 44,Variant = 0,},
				{Type = 44,Variant = 1,},
				{Type = 218,Variant = 0,},
				{Type = 877,Variant = 0,only_spawn = true,},
			},
		},
		sins = {
			normal = {
				{Type = 46,Variant = 0,},
				{Type = 46,Variant = 1,},
				{Type = 46,Variant = 2,},
				{Type = 47,Variant = 0,},
				{Type = 47,Variant = 1,},
				{Type = 48,Variant = 0,},
				{Type = 48,Variant = 1,},
				{Type = 49,Variant = 0,},
				{Type = 49,Variant = 1,},
				{Type = 50,Variant = 0,},
				{Type = 50,Variant = 1,},
				{Type = 51,Variant = 0,only_spawn = true,},
				{Type = 51,Variant = 1,only_spawn = true,},
				{Type = 51,Variant = 10,only_spawn = true,},
				{Type = 51,Variant = 11,only_spawn = true,},
				{Type = 51,Variant = 20,},
				{Type = 51,Variant = 21,},
				{Type = 52,Variant = 0,},
				{Type = 52,Variant = 1,},
			},
		},
		boss = {
			normal = {
				{Type = 19,Variant = 0,SubType = {0,1,2,},mul = {4,5,6,7,},is_multi = true,},
				{Type = 19,Variant = 2,SubType = 0,mul = {4,5,6,7,},is_multi = true,special = function(pos) local q = Isaac.Spawn(809,0,0,pos,Vector(0,0),nil) end,},
				{Type = 79,Variant = 0,SubType = {0,1,2,},myspecial = function(ent) local n_entity = Isaac.GetRoomEntities() local chains = auxi.getothers(n_entity,79,20,nil) for u,v in pairs(chains) do v:Remove() end end,},
				{Type = 79,Variant = 1,SubType = 0,},
				{Type = 79,Variant = 2,SubType = 0,},
				{Type = 237,Variant = 1,SubType = {0,1,2,},},
				{Type = 237,Variant = 2,SubType = 0,},
				{Type = 261,Variant = 0,SubType = {0,1,2,},},
				{Type = 261,Variant = 1,SubType = 0,},
				{Type = 404,Variant = 0,SubType = {0,1,2,},},
				{Type = 405,Variant = 0,SubType = {0,1,2,},},
				{Type = 902,Variant = 0,SubType = 0,},
				{Type = 914,Variant = 0,SubType = 0,},
				{Type = 917,Variant = 0,SubType = 0,},
				{Type = 918,Variant = 0,SubType = 0,mul = {3,4,5,6,7,},is_multi = true,},
				{Type = 28,Variant = 0,SubType = {0,1,2,},mul = {3,4,5,},is_multi = true,},
				{Type = 28,Variant = 1,SubType = 0,mul = {3,4,5,},is_multi = true,},
				{Type = 28,Variant = 2,SubType = {0,1,},mul = {3,},is_multi = true,},
				{Type = 36,Variant = 0,SubType = {0,1,},},
				{Type = 99,Variant = 0,SubType = {0,1,2,},is_multi = true,},
				{Type = 262,Variant = 0,SubType = {0,1,2,},},
				{Type = 263,Variant = 0,SubType = {0,1,2,},},
				{Type = 402,Variant = 0,SubType = {0,1,},},
				{Type = 270,Variant = 0,SubType = 0,},
				{Type = 74,Variant = 0,SubType = 0,},
				{Type = 75,Variant = 0,SubType = 0,},
				{Type = 76,Variant = 0,SubType = 0,},
				{Type = 413,Variant = 0,SubType = 0,},
				{Type = 910,Variant = 0,SubType = 0,},
				{Type = 910,Variant = 1,SubType = 0,},
				{Type = 910,Variant = 2,SubType = 0,},
				{Type = 911,Variant = 0,SubType = 0,},		--有点特殊
				{Type = 407,Variant = 0,SubType = 0,},
				{Type = 84,Variant = 0,SubType = 0,},		--问题不大
				{Type = 273,Variant = 0,SubType = 0,},
				{Type = 406,Variant = 0,SubType = 0,},
				{Type = 406,Variant = 1,SubType = 0,},
				--{Type = 906,Variant = 0,SubType = 0,only_spawn = true,},
				{Type = 903,Variant = 0,SubType = 0,only_spawn = true,},
				{Type = 921,Variant = 0,SubType = 0,special = function(pos) local rnd = math.random(3) + 2 for i = 1,rnd do local q = Isaac.Spawn(889,0,0,pos,Vector(0,0),nil) local d2 = q:GetData() d2.has_been_checked_by_Danger = true q.SpawnerType = 10001 end end,},
			},
			jumpable = {
				{Type = 20,Variant = 0,SubType = {0,1,2,},is_multi = true,},
				{Type = 100,Variant = 0,SubType = {0,1,2,},},
				{Type = 100,Variant = 1,SubType = 0,},
				{Type = 68,Variant = 0,SubType = {0,1,2,},},
				{Type = 68,Variant = 1,SubType = {0,1,},},
				{Type = 264,Variant = 0,SubType = {0,1,2,},},
				{Type = 916,Variant = 0,SubType = 0,},
				{Type = 900,Variant = 0,SubType = 0,},
				{Type = 43,Variant = 0,SubType = {0,1,},},
				{Type = 43,Variant = 1,SubType = 0,},
				{Type = 69,Variant = 0,SubType = 0,},
				{Type = 69,Variant = 1,SubType = 0,mul = 2},
				{Type = 265,Variant = 0,SubType = {0,1,2,},},
				{Type = 410,Variant = 0,SubType = 0,is_multi = true,},		--这个会一次生成2个哦！
			},
			hideable = {
				{Type = 62,Variant = 0,SubType = {0,1,},is_multi = true,},
				{Type = 62,Variant = 1,SubType = 0,is_multi = true,},
				{Type = 62,Variant = 2,SubType = {0,1,},is_multi = true,},
				{Type = 401,Variant = 0,SubType = {0,1,},},
				{Type = 411,Variant = 0,SubType = 0,},
				{Type = 269,Variant = 0,SubType = {0,1,2,},},
				{Type = 269,Variant = 1,SubType = 0,},
			},
			flyable = {
				{Type = 19,Variant = 1,SubType = {0,1,2,3},mul = {3,4,5,6,7,8,9,},is_multi = true,},
				{Type = 63,Variant = 0,SubType = {0,1,},},
				{Type = 64,Variant = 0,SubType = {0,1,},},
				{Type = 65,Variant = 0,SubType = {0,1,},},
				{Type = 65,Variant = 1,SubType = 0,},
				{Type = 66,Variant = 0,SubType = {0,1,},},
				{Type = 67,Variant = 0,SubType = {0,1,2,},},
				{Type = 67,Variant = 1,SubType = {0,1,2,},},
				{Type = 908,Variant = 0,SubType = 0,},
				{Type = 260,Variant = 0,SubType = {0,1,2,},},
				{Type = 901,Variant = 0,SubType = 0,},
				{Type = 913,Variant = 0,SubType = 0,},
				{Type = 71,Variant = 0,SubType = {0,1,},},
				{Type = 71,Variant = 1,SubType = 0,},
				{Type = 72,Variant = 0,SubType = {0,1,},},
				{Type = 72,Variant = 1,SubType = 0,},
				{Type = 73,Variant = 0,SubType = {0,1,},},
				{Type = 73,Variant = 1,SubType = 0,},
				{Type = 267,Variant = 0,SubType = 0,},
				{Type = 403,Variant = 0,SubType = {0,1,},},
				{Type = 409,Variant = 0,SubType = 0,},
				{Type = 268,Variant = 0,SubType = 0,},
				{Type = 274,Variant = 0,SubType = 0,only_spawn = true,special_work = function(ent)
					ent.State = 3
				end,should_set_pit = true,},
				{Type = 275,Variant = 0,SubType = 0,only_spawn = true,special_work = function(ent)
					ent.State = 3
				end,should_set_pit = true,},
				{Type = 97,Variant = 0,SubType = {0,1,},},			--会生成心脏
				{Type = 904,Variant = 0,SubType = 0,},
				{Type = 905,Variant = 0,SubType = 0,},
				{Type = 920,Variant = 0,SubType = 0,},
				{Type = 78,Variant = 0,SubType = 0,},
				{Type = 78,Variant = 0,SubType = 1,},
				{Type = 78,Variant = 1,SubType = 0,},
				{Type = 78,Variant = 1,SubType = 1,},
				{Type = 101,Variant = 0,SubType = 0,},
				{Type = 101,Variant = 1,SubType = 0,},
				{Type = 266,Variant = 0,SubType = 0,},
				{Type = 909,Variant = 0,SubType = 0,},
				{Type = 911,Variant = 2,SubType = 0,},			--没问题
				{Type = 912,Variant = 0,SubType = 0,only_spawn = true,pre_special_work = function()
					local level = Game():GetLevel()
					local room = Game():GetRoom()
					local listindex = level:GetCurrentRoomDesc().ListIndex
					save.elses.alldoorsinfo = save.elses.alldoorsinfo or {}
					if save.elses.alldoorsinfo[listindex] == nil then
						save.elses.alldoorsinfo[listindex] = {}
						for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do 
							if room:IsDoorSlotAllowed(slot) then
								local door = room:GetDoor(slot)
								if door then
									--print(slot)
									save.elses.alldoorsinfo[listindex][slot] = {slot = slot,spritefilename = door:GetSprite():GetFilename(),linked = door.TargetRoomIndex,dir = door.Direction,}
								end
							end
						end
					end
					--l local room = Game():GetRoom() for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do local door = room:GetDoor(slot) if door then door:SetType(16) door:Init(1) door.TargetRoomIndex = 84 end end
				end,should_remakeroom = true,should_set_clear = true,},
				{Type = 912,Variant = 10,SubType = 0,},	
				{Type = 102,Variant = 0,SubType = 0,},
				{Type = 102,Variant = 1,SubType = 0,},
				{Type = 102,Variant = 2,SubType = 0,},
				{Type = 84,Variant = 10,SubType = 0,special = function(pos) local mul = math.random(3) for i = 1,mul do local q = Isaac.Spawn(84,10,0,pos,Vector(0,0),nil) local d2 = q:GetData() d2.has_been_checked_by_Danger = true q.SpawnerType = 10001 end end,},
				{Type = 412,Variant = 0	,SubType = 0,nonly_spawn = true,hard = true,},
				{Type = 919,Variant = 0,SubType = 0,fill_in = true,should_transmit = true,should_set_clear = true,pre_special_work = function()
					local level = Game():GetLevel()
					local room = Game():GetRoom()
					local listindex = level:GetCurrentRoomDesc().ListIndex
					save.elses.allpitinfo = save.elses.allpitinfo or {}
					if save.elses.allpitinfo[listindex] == nil then
						save.elses.allpitinfo[listindex] = {}
						local size = room:GetGridSize()
						for i = 0,size - 1 do
							local gent = room:GetGridEntity(i)
							if gent == nil or (gent:ToPit() == nil) then
								save.elses.allpitinfo[listindex][i] = true
							end
						end
					end
				end},
				{Type = 950,Variant = 0,SubType = 0,only_spawn = true,hard = true,special_work = function(ent)
					local d = ent:GetData()
					d.danger_kill_dogma = true
				end,should_transmit = true,should_set_clear = true,},
				{Type = 950,Variant = 2,SubType = 0,only_spawn = true,hard = true,special_work = function(ent)
					local d = ent:GetData()
					d.danger_help_with_idle = true
				end},
				{Type = 951,Variant = 0,SubType = 0,hard = true,only_spawn = true,},
				{Type = 951,Variant = 10,SubType = 0,},
				{Type = 951,Variant = 20,SubType = 0,},
				{Type = 951,Variant = 30,SubType = 0,},
				{Type = 951,Variant = 40,SubType = 0,},
				{Type = 81,Variant = 0,SubType = 0,is_multi = true,},
				{Type = 81,Variant = 1,SubType = 0,},
				{Type = 82,Variant = 0,SubType = 0,special = function(pos) local mul = math.random(3) for i = 1,mul do local q = Isaac.Spawn(83,0,0,pos,Vector(0,0),nil) local d2 = q:GetData() d2.has_been_checked_by_Danger = true q.SpawnerType = 10001 end end},
				{Type = 271,Variant = 0,SubType = 0,},
				{Type = 271,Variant = 1,SubType = 0,},
				{Type = 272,Variant = 0,SubType = 0,},
				{Type = 272,Variant = 1,SubType = 0,},
				{Type = 19,Variant = 3,SubType = 0,mul = {3,4,5,6,7,},is_multi = true,special = function(pos) local q = Isaac.Spawn(809,0,0,pos,Vector(0,0),nil) end,},
				{Type = 45,Variant = 10,SubType = 3,should_delay = true,special_morph = {Variant = 0,},center_pos = true,special = function(pos) 
					local room = Game():GetRoom()
					local n_entity = Isaac.GetRoomEntities()
					for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do 
						if room:IsDoorSlotAllowed(slot) then
							local pos = room:GetDoorSlotPosition(slot)
							local should_spawn = true
							for u,v in pairs(n_entity) do
								if v.Type == 45 and (v.Position - pos):Length() < 60 then
									should_spawn = false
									break
								end
							end
							if should_spawn then
								local q = Isaac.Spawn(45,0,3,pos,Vector(0,0),nil) 
								local d2 = q:GetData() 
								d2.has_been_checked_by_Danger = true
								d2.fixed_position = pos
							end
						end
					end
				end,hard = true,},
				{Type = 45,Variant = 10,SubType = 2,should_delay = true,special_morph = {Variant = 0,},center_pos = true,special = function(pos) 
					local room = Game():GetRoom()
					local n_entity = Isaac.GetRoomEntities()
					for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do 
						if room:IsDoorSlotAllowed(slot) then
							local pos = room:GetDoorSlotPosition(slot)
							local should_spawn = true
							for u,v in pairs(n_entity) do
								if v.Type == 45 and (v.Position - pos):Length() < 60 then
									should_spawn = false
									break
								end
							end
							if should_spawn then
								local q = Isaac.Spawn(45,0,2,pos,Vector(0,0),nil) 
								local d2 = q:GetData() 
								d2.has_been_checked_by_Danger = true
								d2.fixed_position = pos
							end
						end
					end
				end,hard = true,},
				{Type = 45,Variant = 10,SubType = 1,should_delay = true,special_morph = {Variant = 0,},center_pos = true,special = function(pos) 
					local room = Game():GetRoom()
					local n_entity = Isaac.GetRoomEntities()
					for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do 
						if room:IsDoorSlotAllowed(slot) then
							local pos = room:GetDoorSlotPosition(slot)
							local should_spawn = true
							for u,v in pairs(n_entity) do
								if v.Type == 45 and (v.Position - pos):Length() < 60 then
									should_spawn = false
									break
								end
							end
							if should_spawn then
								local q = Isaac.Spawn(45,0,1,pos,Vector(0,0),nil) 
								local d2 = q:GetData() 
								d2.has_been_checked_by_Danger = true
								d2.fixed_position = pos
							end
						end
					end
				end,hard = true,},
				{Type = 45,Variant = 10,SubType = 0,should_delay = true,special_morph = {Variant = 0,},center_pos = true,special = function(pos) 
					local room = Game():GetRoom()
					local n_entity = Isaac.GetRoomEntities()
					for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do 
						if room:IsDoorSlotAllowed(slot) then
							local pos = room:GetDoorSlotPosition(slot)
							local should_spawn = true
							for u,v in pairs(n_entity) do
								if v.Type == 45 and (v.Position - pos):Length() < 60 then
									should_spawn = false
									break
								end
							end
							if should_spawn then
								local q = Isaac.Spawn(45,0,0,pos,Vector(0,0),nil) 
								local d2 = q:GetData() 
								d2.has_been_checked_by_Danger = true
								d2.fixed_position = pos
							end
						end
					end
				end,hard = true,},
			},
			special = {
				--{Type = 906,Variant = 0,SubType = 0,},
				--{Type = 907,Variant = 0,SubType = 0,},
				--{Type = 903,Variant = 0,SubType = 0,},
				--l local room = Game():GetRoom() print(room:IsPositionInRoom(room:GetGridPosition(20),0))
				--l local room = Game():GetRoom() print(room:GetGridWidth().." "..room:GetGridHeight())
				--l local room = Game():GetRoom() local gent = room:GetGridEntity(20) if gent == nil then local succ = room:SpawnGridEntity(20,GridEntityType.GRID_DECORATION,0,room:GetSpawnSeed(),0) if succ then grid = room:GetGridEntity(20) end end if gent then print(gent.CollisionClass) end
			},
			water = {
				{Type = 62,Variant = 3,SubType = 0,},
			},
		},
	},
	info_data = nil,
	other_info = {		--处理某些不应该生成，但是却应该被转化的怪物。
		monsters = {
			normal = {
			},
			flyable = {
				{Type = 66,Variant = 10,SubType = 0,},
				{Type = 951,Variant = 42,SubType = 0,},
				--{Type = 951,Variant = 41,SubType = 0,},
				{Type = 951,Variant = 1,SubType = {0,1,2,3,4,},},
				{Type = 819,Variant = 1,true_life = 50,},
				{Type = 96,Variant = 0,true_life = 30,},
				{Type = 808,Variant = 0,SubType = 1,}
			},
		},
		sins = {
			normal = {
				{Type = 51,Variant = 30,},
				{Type = 51,Variant = 31,},
			},
		},
		boss = {
			normal = {
				{Type = 904,Variant = 1,SubType = 0,},
				{Type = 405,Variant = 1,SubType = {0,1,2,},},
			},
			flyable = {
				{Type = 79,Variant = 12,SubType = 0,},
				{Type = 951,Variant = 3,SubType = 0,},
				{Type = 83,Variant = 0,SubType = 0,},
				{Type = 45,Variant = 0,SubType = {0,1,2,3,},},
			},
			special = {
			},
		},
	},
	morph_dirs = {
		normal = {"normal","jumpable","hideable","flyable",},
		onwall = {"onwall","jumpable","hideable","flyable",},
		jumpable = {"jumpable","hideable","flyable",},
		hideable = {"jumpable","hideable","flyable",},
		flyable = {"onwall","onwall","jumpable","hideable","flyable",},
		water = {"water","onwall","jumpable","hideable","flyable",},
		spike = {"spike",},
		unbreakable = {"unbreakable",},
		special = {"special",},
	},
	level_map = {
		[9] = 4,
		[11] = 5,
		[12] = 6,
		[13] = 6,
	},
	ff_info = {
		original_info = {
			monsters = {
				normal = {
					{Type = 10,Variant = 160,level = 1,},		--大头痴汉
					{Type = 11,Variant = 0,SubType = 770,level = 1,},	--不知道谁的写法
					{Type = 12,Variant = 333,level = 1,},		--三眼脑袋
					{Type = 15,Variant = 450,level = 1,mul = {1,2,3,4,},},		--小肉块
					{Type = 16,Variant = 960,level = 4,},		--facade
					{Type = 21,Variant = 114,level = 5,},		--海黄瓜
					{Type = 21,Variant = 450,level = 3,},		--retch
					{Type = 21,Variant = 666,level = 1,},		--造雨者
					{Type = 21,Variant = 666,SubType = 1,level = 4,},		--毒雨者
					{Type = 21,Variant = 750,level = 4,},		--毒虫
					{Type = 21,Variant = 960,level = 2,},		--滚滚
					{Type = 21,Variant = 960,SubType = 1,level = 3,},		--毒滚滚
					{Type = 21,Variant = 960,SubType = 2,level = 2,},		--骨滚滚
					{Type = 21,Variant = 961,level = 2,},		--硫磺火骑士
					{Type = 22,Variant = 666,level = 2,},		--吐泡泡
					{Type = 23,Variant = 960,level = 2,},		--骨块冲锋者
					{Type = 23,Variant = 961,level = 3,mul = {1,2,3,},},		--熔岩冲锋者
					{Type = 23,Variant = 1700,level = 4,},		--血迹冲锋者
					{Type = 27,Variant = 0,SubType = 250,level = 2,},		--中宿主
					{Type = 27,Variant = 0,SubType = 710,level = 4,},		--毒性宿主
					{Type = 27,Variant = 0,SubType = 711,level = 2,},		--沙蜘蛛宿主
					{Type = 27,Variant = 0,SubType = 712,level = 2,},		--硫磺火宿主
					{Type = 27,Variant = 1,SubType = 251,level = 2,},		--硫磺火宿主
					{Type = 29,Variant = 962,SubType = {0,1,},level = 2,},		--翻滚脑袋
					{Type = 30,Variant = 960,level = 2,},		--沙蜘蛛袋子
					{Type = 41,Variant = 114,level = 3,},		--精神眼骑士
					{Type = 41,Variant = 450,level = 4,},		--腐脏骑士
					{Type = 41,Variant = 750,level = 4,},		--肉虫骑士
					{Type = 57,Variant = 114,level = 4,},		--肉块团
					{Type = 58,Variant = 960,level = 4,},		--会变身的小家伙
					{Type = 85,Variant = 333,level = 5,},		--黄金蜘蛛
					{Type = 85,Variant = 960,level = 1,},		--射击蜘蛛
					{Type = 85,Variant = 961,level = 1,},		--分叉蜘蛛
					--{Type = 85,Variant = 962,level = 1,},		--沙蜘蛛
					{Type = 85,Variant = 963,level = 2,},		--三分蜘蛛
					{Type = 85,Variant = 964,level = 2,},		--放屁虫
					{Type = 85,Variant = 965,level = 3,mul = {1,2,},},		--毒屁虫
					{Type = 85,Variant = 966,level = 3,mul = {1,2,},},		--美屁虫
					{Type = 87,Variant = 710,level = 4,},		--吐根+肺者
					{Type = 88,Variant = 960,level = 2,},		--行走沙蜘蛛巢
					{Type = 88,Variant = 961,level = 3,},		--大行走沙蜘蛛巢
					{Type = 108,Variant = 112,level = 5,mul = {1,2,3,},},		--真视之眼的眼睛
					{Type = 108,Variant = 113,level = 5,},		--冲锋妖
					{Type = 108,Variant = 115,level = 3,},		--石油人
					{Type = 108,Variant = 116,level = 3,},		--巨块
					{Type = 108,Variant = 117,level = 4,},		--肿瘤人
					{Type = 112,Variant = 0,level = 4,},		--暴血人
					{Type = 112,Variant = 1,level = 5,},		--阴影人
					{Type = 114,Variant = 2,level = 1,},		--恶臭者
					{Type = 114,Variant = 5,SubType = {0,1,},level = 2,},		--溺死人
					{Type = 114,Variant = 7,level = 3,},		--精神骨架
					{Type = 114,Variant = 8,level = 2,},		--石山
					{Type = 114,Variant = 8,SubType = 1,level = 2,},		--焰山
					--{Type = 114,Variant = 9,level = 2,},		--青蛙		--似乎没做？
					{Type = 114,Variant = 12,level = 4,},		--bladder
					{Type = 114,Variant = 13,level = 4,},		--心跳
					{Type = 114,Variant = 15,level = 2,},		--小型哥布林
					{Type = 114,Variant = 16,level = 2,},		--怒意
					{Type = 114,Variant = 17,level = 2,},		--Gabber
					{Type = 114,Variant = 19,level = 2,},		--投弹者
					{Type = 114,Variant = 20,level = 3,},		--骨缝
					{Type = 114,Variant = 20,SubType = 1,level = 3,ignore_place = true,mul = {1,2,},},		--骨缝 藏匿版本
					{Type = 114,Variant = 21,level = 5,},		--牧师
					{Type = 114,Variant = 22,level = 4,},		--腐害
					{Type = 114,Variant = 25,level = 1,},		--小便者
					{Type = 114,Variant = 28,level = 3,},		--Unshornz
					{Type = 114,Variant = 33,SubType = {0,1,2,},level = 3,},		--烂肉块
					{Type = 114,Variant = 34,level = 2,},		--胖怒意		--有bug
					{Type = 114,Variant = 36,level = 2,},		--壳中人
					{Type = 114,Variant = 37,level = 5,},		--瘤身
					{Type = 114,Variant = 38,level = 3,},		--头骨鬼
					{Type = 114,Variant = 40,level = 5,},		--超级肉骨团
					{Type = 114,Variant = 43,SubType = {0,1,2,},level = 3,},		--解构骨者
					{Type = 114,Variant = 46,level = 4,},		--Flailer
					{Type = 114,Variant = 50,level = 5,},		--鲸落
					{Type = 114,Variant = 50,SubType = 1,level = 5,},		--鲸落的内脏
					{Type = 114,Variant = 52,level = 3,},		--扎小人
					{Type = 114,Variant = 53,level = 2,},		--吸收炮
					{Type = 114,Variant = 54,level = 4,},		--烂尸
					{Type = 114,Variant = 56,level = 2,},		--猪猪
					{Type = 114,Variant = 57,level = 3,},		--海胆
					{Type = 114,Variant = 59,level = 3,},		--钉牙
					{Type = 114,Variant = 1008,level = 5,},		--影之宿主
					{Type = 114,Variant = 1009,level = 3,},		--反向头先生
					{Type = 114,Variant = 1009,SubType = 1,level = 2,},		--反向头先生的身体
					{Type = 114,Variant = 1010,level = 3,},		--精神眼先生
					{Type = 114,Variant = 1010,SubType = {1,2,},level = 2,},		--精神眼先生的头和身体
					{Type = 120,Variant = 223,level = 4,},		--喉结
					--{Type = 120,Variant = 224,level = 3,},		--Cuffs		--有bug
					{Type = 120,Variant = 228,SubType = {0,1,},level = 1,},		--水人
					{Type = 120,Variant = 229,level = 2,special = function(pos) local mul = math.random(3) - 1 for i = 1,mul do local q = Isaac.Spawn(120,229,1,pos,Vector(0,0),nil) local d2 = q:GetData() d2.has_been_checked_by_Danger = true q.SpawnerType = 10001 end end,},		--骨人
					{Type = 120,Variant = 229,SubType = 1,level = 2,},		--骨人的身体
					{Type = 120,Variant = 230,SubType = {0,1,},level = 4,},		--脑王
					{Type = 120,Variant = 230,SubType = {2,3,},level = 4,},		--脑王
					{Type = 120,Variant = 230,SubType = {4,5,6,7,8,},level = 4,},		--脑王
					{Type = 120,Variant = 230,SubType = {9,10,11,12,},level = 4,},		--脑王
					--120.231
					{Type = 120,Variant = 232,level = 4,},		--拘束双子
					{Type = 120,Variant = 233,level = 2,},		--海葵
					{Type = 120,Variant = 234,level = 4,},		--巨齿蜘蛛
					{Type = 120,Variant = 235,SubType = {0,1,},level = 4,mul = {1,2,3,4,},},		--齿蜘蛛
					--120.236
					{Type = 124,Variant = 0,level = 3,},		--重压
					{Type = 130,Variant = 10,level = 4,},		--血壁
					{Type = 130,Variant = 50,SubType = {0,1,2,3,4,},level = 3,mul = {1,2,},},		--福袋人
					--150.0/1/4/5/6/7/9/13/17/18/19/20/21/24/25/26/27/28/29/30/31!/33/35
					--150.450/451/452/453!/454/455!/456!/457/458
					{Type = 150,Variant = 8,level = 4,},		--神经元
					{Type = 150,Variant = 10,SubType = {0,1,},level = 2,ignore_place = true,mul = {1,2,3,},},		--空降蜘蛛
					{Type = 150,Variant = 10,SubType = {2,3,},level = 2,ignore_place = true,mul = {1,2,3,},},		--空降蜘蛛
					{Type = 150,Variant = 10,SubType = {4,5,},level = 2,ignore_place = true,mul = {1,2,3,},},		--空降蜘蛛
					{Type = 150,Variant = 12,level = 3,},		--脑外骑士
					{Type = 150,Variant = 14,level = 4,},		--巨虫		--!
					{Type = 150,Variant = 16,level = 3,},		--油滴
					{Type = 150,Variant = 23,level = 5,},		--Psyeg
					{Type = 153,Variant = 0,level = 2,},		--枪头
					{Type = 153,Variant = 10,level = 2,},		--骨枪头
					{Type = 160,Variant = 0,level = 2,},		--模仿粪人
					{Type = 160,Variant = 10,level = 1,},		--粪台
					{Type = 160,Variant = 40,SubType = {0,1,},level = 2,},		--腐体
					{Type = 160,Variant = 41,SubType = {0,1,},level = 2,},		--灰腐体
					{Type = 160,Variant = 50,SubType = {0,1,2,3,4,},level = 2,},		--侏儒
					{Type = 160,Variant = 51,SubType = {0,1,},level = 2,mul = {1,2,3,}},		--褐侏儒
					{Type = 160,Variant = 52,level = 3,mul = {1,2,3,}},		--骨血侏儒
					{Type = 160,Variant = 53,level = 3,mul = {1,2,3,}},		--骨血侏儒身体
					{Type = 160,Variant = 70,level = 4,},		--神经行者
					{Type = 160,Variant = 80,SubType = {0,1000,},level = 2,},		--居民
					{Type = 160,Variant = 80,SubType = {169,2,213,224,},level = 2,},		--居民
					{Type = 160,Variant = 80,SubType = {3,316,330,},level = 2,},		--居民
					{Type = 160,Variant = 80,SubType = {6,68,8,},level = 2,},		--居民
					{Type = 160,Variant = 80,SubType = {496,475,},level = 2,},		--居民		--!!!
					{Type = 160,Variant = 82,SubType = {0,999,},level = 2,},		--死民
					{Type = 160,Variant = 82,SubType = {38,42,56,},level = 2,},		--死民
					{Type = 160,Variant = 82,SubType = {58,145,282,},level = 2,},		--死民
					{Type = 160,Variant = 82,SubType = {288,289,294,},level = 2,},		--死民
					{Type = 160,Variant = 82,SubType = {1001,1002,},level = 2,},		--死民
					{Type = 160,Variant = 83,level = 2,},		--死民身体
					{Type = 160,Variant = 85,SubType = {0,1000,},level = 5,keep_health = true,},		--坏民
					{Type = 160,Variant = 85,SubType = {167,329,331,},level = 5,keep_health = true,},		--坏民
					{Type = 160,Variant = 85,SubType = {369,395,452,},level = 5,keep_health = true,},		--坏民
					{Type = 160,Variant = 90,level = 2,},		--爆炸蘑菇
					--160.130
					{Type = 160,Variant = 140,level = 3,},		--大型石油冲锋者
					{Type = 160,Variant = 150,level = 2,},		--水滴
					{Type = 160,Variant = 151,level = 2,},		--中水滴
					{Type = 160,Variant = 152,level = 1,},		--火滴
					{Type = 160,Variant = 153,level = 2,},		--熔滴
					{Type = 160,Variant = 154,level = 2,},		--中熔滴
					{Type = 160,Variant = 160,level = 2,},		--化石
					--160.161
					{Type = 160,Variant = 162,level = 2,},		--连击腐肉宿主
					{Type = 160,Variant = 170,level = 3,},		--大眼
					{Type = 160,Variant = 170,SubType = 1,level = 4,},		--爆炸大眼
					{Type = 160,Variant = 171,level = 3,},		--眼疮
					--160.172
					{Type = 160,Variant = 210,level = 3,},		--魔法学徒
					{Type = 160,Variant = 220,level = 4,},		--毒性骑士
					{Type = 160,Variant = 230,level = 3,},		--鬼上身
					{Type = 160,Variant = 280,level = 1,},		--焰头
					{Type = 160,Variant = 281,level = 1,},		--跟随焰头
					{Type = 160,Variant = 300,level = 4,},		--极饿者
					{Type = 160,Variant = 310,level = 1,},		--火车轮
					{Type = 160,Variant = 311,level = 1,},		--可爱火车轮
					{Type = 160,Variant = 330,level = 4,},		--骨脑战士
					{Type = 160,Variant = 360,level = 2,},		--柠檬人
					{Type = 160,Variant = 360,SubType = 1,level = 3,},		--吐根柠檬人
					{Type = 160,Variant = 361,level = 2,},		--柠檬人的身体
					{Type = 160,Variant = 361,SubType = 1,level = 3,},		--吐根柠檬人的身体
					--160.370/371
					{Type = 160,Variant = 380,SubType = {0,1,},level = 2,},		--螃蟹
					{Type = 160,Variant = 410,level = 2,},		--泡泡蜘蛛
					{Type = 160,Variant = 430,level = 1,},		--煤炭人
					{Type = 160,Variant = 431,level = 1,},		--煤炭人2
					--160.440/441/442/443		--!
					{Type = 160,Variant = 500,level = 1,},		--召唤粪
					{Type = 160,Variant = 501,level = 1,},		--召唤粪的召唤物
					{Type = 160,Variant = 505,level = 5,},		--腐化召唤粪
					{Type = 160,Variant = 530,level = 3,},		--石油力量
					{Type = 160,Variant = 550,level = 1,},		--十字自爆者
					{Type = 160,Variant = 570,level = 1,special = function(pos) local room = Game():GetRoom() local mul = math.random(3) - 1 for i = 1,mul do local pos = room:GetRandomPosition(20) local q = Isaac.Spawn(44,980,0,pos,Vector(0,0),nil) end end,},		--下水道的藏匿者
					{Type = 160,Variant = 580,level = 2,},		--造碑者
					--160.600		--似乎没做？
					{Type = 160,Variant = 630,level = 2,},		--充气脑袋
					{Type = 160,Variant = 631,level = 2,},		--充屁脑袋
					{Type = 160,Variant = 650,level = 3,},		--毒性炮台
					{Type = 160,Variant = 671,level = 3,},		--奴隶
					{Type = 160,Variant = 690,level = 3,keep_health = true,},		--鱼撒
					{Type = 160,Variant = 730,level = 2,},		--胆小宿主
					{Type = 160,Variant = 750,level = 2,special = function(pos)local mul = math.random(3) for i = 1,mul do local t_pos = pos + auxi.MakeVector(math.random(360)) * math.random(10) local q = Isaac.Spawn(160,750,0,t_pos,Vector(0,0),nil) local d2 = q:GetData() d2.has_been_checked_by_Danger = true q.SpawnerType = 10001 end end,},		--小蘑菇
					{Type = 160,Variant = 760,level = 2,},		--飞头蛮
					{Type = 160,Variant = 760,SubType = {1,2,},level = 2,},		--飞头蛮
					{Type = 160,Variant = 761,level = 3,},		--白头蛮
					{Type = 160,Variant = 761,SubType = {1,2,},level = 3,},		--白头蛮
					{Type = 160,Variant = 769,level = 3,},		--白头蛮
					{Type = 160,Variant = 769,SubType = {1,2,},level = 3,},		--白头蛮
					{Type = 160,Variant = 770,level = 1,},		--掷头者
					{Type = 160,Variant = 771,level = 1,},		--掷出头
					{Type = 160,Variant = 772,level = 1,},		--掷红头者
					{Type = 160,Variant = 773,level = 1,},		--掷出红头
					{Type = 160,Variant = 780,level = 1,},		--毒性起爆者
					{Type = 160,Variant = 800,level = 4,},		--喷血者
					--{Type = 160,Variant = 801,level = 4,},		--喷血块		--二者必须封印其中之一
					{Type = 160,Variant = 820,level = 1,},		--肉身
					{Type = 160,Variant = 820,SubType = 2,level = 1,},		--肉身的手
					{Type = 160,Variant = 821,level = 2,},		--白肉身
					{Type = 160,Variant = 821,SubType = {1,2,},level = 2,},		--白肉身的身体与手
					{Type = 160,Variant = 822,level = 5,},		--黑肉身
					{Type = 160,Variant = 822,SubType = 2,level = 4,},		--黑肉身的手
					{Type = 160,Variant = 830,level = 1,},		--Pester
					{Type = 160,Variant = 840,level = 2,},		--蘑菇人
					{Type = 160,Variant = 850,level = 3,},		--伸头宿主
					{Type = 160,Variant = 860,level = 3,},		--小宿主
					{Type = 160,Variant = 861,level = 3,},		--小血宿主
					{Type = 160,Variant = 862,level = 3,},		--小胆小宿主
					{Type = 160,Variant = 890,level = 2,},		--骨骨博士
					{Type = 160,Variant = 900,level = 3,only_spawn = true,},		--内窥眼
					{Type = 160,Variant = 901,level = 3,},		--内窥眼的启迪者
					{Type = 160,Variant = 910,level = 3,},		--飞首油怪
					{Type = 160,Variant = 911,level = 3,only_spawn = true,},		--飞首油怪的头
					{Type = 160,Variant = 920,SubType = {0,1,},level = 4,},		--层叠哥布林
					{Type = 160,Variant = 920,SubType = {2,3,},level = 4,},		--层叠哥布林
					{Type = 160,Variant = 940,level = 5,},		--杀生魔
					{Type = 160,Variant = 960,level = 5,},		--追踪者
					{Type = 160,Variant = 990,level = 2,},		--蜘蛛虫
					{Type = 160,Variant = 1040,level = 2,},		--长腿南希
					{Type = 160,Variant = 1050,level = 1,},		--网袋
					{Type = 160,Variant = 1070,level = 4,},		--抓抓怪
					{Type = 160,Variant = 1100,level = 3,},		--第六眼
					{Type = 160,Variant = 1150,level = 3,},		--单鸟
					{Type = 160,Variant = 1170,level = 3,},		--公牛
					{Type = 160,Variant = 1180,level = 2,},		--吹泡泡
					{Type = 160,Variant = 1210,level = 2,},		--巨以撒
					{Type = 160,Variant = 1230,level = 2,},		--Matte
					{Type = 160,Variant = 1250,SubType = {0,1,},level = 1,},		--铁桶僵尸
					{Type = 160,Variant = 1270,SubType = {0,1,},level = 1,},		--齿轮人与他的身体
					{Type = 160,Variant = 1290,level = 1,},		--哭哭小便仔
					{Type = 160,Variant = 1300,level = 3,},		--笑面人
					{Type = 160,Variant = 1310,level = 2,},		--蘑菇人
					{Type = 160,Variant = 1715,level = 4,},		--baba
					{Type = 160,Variant = 1716,level = 2,},		--枪手
					{Type = 160,Variant = 1717,level = 3,},		--太空人
					{Type = 160,Variant = 1718,level = 3,},		--萝卜
					{Type = 160,Variant = 2000,level = 2,special = function(pos) local mul = math.random(2) - 1 for i = 1,mul do local q = Isaac.Spawn(160,2001,0,pos,Vector(0,0),nil) local d2 = q:GetData() d2.has_been_checked_by_Danger = true q.SpawnerType = 10001 end end,},		--超大蘑菇
					{Type = 160,Variant = 2002,level = 2,},		--辣滚滚
					{Type = 160,Variant = 2003,level = 2,},		--辣滴
					{Type = 160,Variant = 2100,level = 2,},		--哭哭
					{Type = 160,Variant = 2101,level = 2,},		--血哭哭
					{Type = 160,Variant = 2102,level = 3,},		--白哭哭
					{Type = 170,Variant = 100,SubType = 1,level = 2,},		--刺身
					{Type = 170,Variant = 40,SubType = {0,1,2,3,4,5,},level = 3,mul = {1,2,3,4,},},		--油滴
					{Type = 170,Variant = 50,level = 3,},		--熔油
					{Type = 170,Variant = 60,level = 3,},		--吐油者
					{Type = 170,Variant = 70,level = 2,},		--环虫脑袋
					{Type = 170,Variant = 80,level = 2,},		--凤凰
					{Type = 170,Variant = 80,SubType = 2,level = 2,},		--凤凰
					{Type = 180,Variant = 0,SubType = 100,level = 1,},		--枪牢的召唤物
					{Type = 180,Variant = 93,level = 4,},		--窥见的衍生物
					{Type = 180,Variant = 102,SubType = {0,1,2,3,4,},level = 3,},		--午餐的衍生物衍生物
					{Type = 180,Variant = 161,level = 2,},		--水头的召唤物
					{Type = 180,Variant = 235,level = 3,},		--传送无头人
					{Type = 205,Variant = 450,level = 4,},		--宿主召唤师
					{Type = 205,Variant = 450,SubType = 1,level = 4,},		--红宿主召唤师
					{Type = 205,Variant = 451,level = 4,},		--牙召唤师
					{Type = 206,Variant = 450,level = 3,},		--怪蜘蛛
					{Type = 207,Variant = 450,level = 2,},		--小怪蜘蛛
					{Type = 207,Variant = 960,level = 3,},		--骨怪蜘蛛
					{Type = 207,Variant = 961,SubType = 1,level = 4,},		--肉怪蜘蛛
					{Type = 208,Variant = 750,level = 4,},		--肉胖
					{Type = 208,Variant = 960,level = 3,},		--油胖
					{Type = 208,Variant = 961,level = 2,},		--溺死胖
					{Type = 208,Variant = 962,level = 4,},		--生殖胖
					{Type = 208,Variant = 963,level = 1,},		--煤炭胖
					{Type = 227,Variant = 666,level = 3,},		--骨躯
					{Type = 227,Variant = 667,level = 3,},		--骨头先生
					{Type = 227,Variant = 750,level = 3,},		--据骨者
					{Type = 227,Variant = 960,level = 3,},		--空洞骑士
					{Type = 227,Variant = 961,level = 1,},		--引线
					{Type = 231,Variant = 0,SubType = 1980,level = 4,},		--触手（没有影子）
					{Type = 284,Variant = 710,level = 1,},		--血口
					{Type = 310,Variant = 450,SubType = {0,1,2,3,},level = 1,},		--畸瘤召唤师
					{Type = 369,Variant = 10,level = 1,},		--垃圾袋人
					{Type = 369,Variant = 10,SubType = 2,level = 1,},		--粪袋人
					{Type = 369,Variant = 11,level = 1,},		--管人
					{Type = 369,Variant = 12,level = 1,},		--生宿
					{Type = 369,Variant = 13,level = 1,},		--自行射击者
					{Type = 450,Variant = 0,level = 3,},		--启迪者
					{Type = 450,Variant = 4,level = 4,},		--肉头
					{Type = 450,Variant = 5,level = 2,},		--螺丝钉
					{Type = 450,Variant = 6,level = 4,},		--椰子
					{Type = 450,Variant = 7,level = 2,},		--采火人
					{Type = 450,Variant = 8,level = 3,},		--油生者
					{Type = 450,Variant = 9,level = 1,},		--鱼人
					{Type = 450,Variant = 9,SubType = 1,level = 1,},		--鱼人
					{Type = 450,Variant = 9,SubType = 2,level = 1,},		--鱼人
					{Type = 450,Variant = 10,level = 2,},		--猫鱼
					{Type = 450,Variant = 12,level = 4,},		--鲍勃
					{Type = 450,Variant = 14,level = 4,},		--烘焙者
					{Type = 450,Variant = 1510,level = 3,},		--监视者
					{Type = 450,Variant = 16,level = 4,},		--腐与骨
					{Type = 450,Variant = 18,level = 3,},		--怪木乃伊
					{Type = 450,Variant = 19,level = 3,},		--活罐
					{Type = 450,Variant = 22,level = 1,},		--尿人
					{Type = 450,Variant = 25,{0,100,120,200,250,300,},level = 3,},		--扩增者
					{Type = 450,Variant = 28,level = 2,},		--海豚
					{Type = 450,Variant = 32,level = 2,},		--头角
					{Type = 450,Variant = 34,level = 1,},		--饱粪人
					{Type = 450,Variant = 35,level = 3,},		--铁处女
					{Type = 450,Variant = 36,level = 4,},		--废山
					{Type = 450,Variant = 37,level = 3,},		--压制者
					{Type = 450,Variant = 39,level = 4,},		--吸泪者
					{Type = 450,Variant = 40,level = 2,},		--巨爆
					{Type = 450,Variant = 41,level = 4,},		--肉牙钉
					{Type = 450,Variant = 43,level = 1,},		--块肉块
					{Type = 450,Variant = 43,SubType = 1,level = 1,},		--燃烧块肉块
					{Type = 451,Variant = 10,level = 2,},		--方盒
					{Type = 451,Variant = 20,level = 4,},		--巨柱
					{Type = 451,Variant = 30,level = 2,},		--魔菇
					{Type = 451,Variant = 40,level = 5,},		--大火块
					{Type = 451,Variant = 41,level = 5,},		--大火块2
					{Type = 451,Variant = 42,level = 5,},		--大火块3
					{Type = 451,Variant = 50,level = 3,},		--诺斯克
					--481
					{Type = 666,Variant = 0,level = 2,},		--粪堆
					{Type = 666,Variant = 1,level = 2,},		--粪堆
					{Type = 666,Variant = 2,level = 2,},		--粪堆
					{Type = 666,Variant = 10,level = 2,},		--载粪者
					{Type = 666,Variant = 11,level = 2,},		--粪头
					{Type = 666,Variant = 30,level = 5,},		--颂歌教皇
					{Type = 666,Variant = 50,level = 2,},		--屁人
					{Type = 666,Variant = 70,level = 2,},		--蜘蛛袋
					{Type = 666,Variant = 90,level = 2,},		--油罐
					{Type = 666,Variant = 120,level = 3,},		--油宿主
					{Type = 666,Variant = 140,level = 4,},		--肉人
					{Type = 666,Variant = 141,level = 4,},		--无皮肉人
					{Type = 666,Variant = 150,level = 2,},		--跳怪
					{Type = 666,Variant = 150,SubType = 1,level = 2,},		--注水跳怪
					{Type = 666,Variant = 152,level = 2,},		--滚滚跳怪
					{Type = 666,Variant = 180,level = 2,},		--蜂巢人
					{Type = 750,Variant = 80,level = 2,},		--蜘蛛袋人
					{Type = 750,Variant = 100,level = 3,},		--吐吸魔人
					{Type = 750,Variant = 110,level = 1,},		--蜡烛人
					{Type = 750,Variant = 151,level = 4,},		--缠婴2
					--750.160
					{Type = 750,Variant = 170,level = 4,},		--腐先生
					{Type = 750,Variant = 171,level = 4,},		--腐先生的底座
					{Type = 750,Variant = 172,level = 4,},		--蜘蛛哥布林
					{Type = 750,Variant = 180,level = 4,},		--畸瘤聚合物
					{Type = 750,Variant = 181,level = 4,},		--畸瘤聚合物2
					{Type = 750,Variant = 182,level = 4,},		--畸瘤聚合物3
					{Type = 750,Variant = 190,level = 3,},		--孤独骑士
					{Type = 750,Variant = 220,SubType = {0,1,2,3,},level = 4,},		--鳄鱼
					{Type = 750,Variant = 230,level = 3,},		--红术师
					{Type = 750,Variant = 240,level = 3,},		--骨肉回力标
					{Type = 750,Variant = 250,level = 3,},		--虫结
					--750.260/261/..
					{Type = 750,Variant = 280,level = 4,},		--超级枪手
					{Type = 812,Variant = 0,SubType = 114,level = 2,},		--漂浮溺死胖胖头
					{Type = 817,Variant = 140,level = 1,},		--黑球召唤师
					{Type = 817,Variant = 170,level = 1,},		--水蜘蛛召唤师
					---815.960
					{Type = 889,Variant = 750,level = 4,},		--裂骨者
				},
				onwall = {
					{Type = 160,Variant = 30,SubType = {0,1,},level = 1,},		--飞肉块
					{Type = 160,Variant = 31,SubType = {0,1,},level = 3,},		--飞油
					{Type = 160,Variant = 32,SubType = {0,1,},level = 3,},		--飞宿主
					{Type = 160,Variant = 33,SubType = {0,1,},level = 2,},		--飞腐肉
					{Type = 160,Variant = 34,SubType = {0,1,},level = 5,},		--飞魔肉
					{Type = 160,Variant = 35,SubType = {0,1,},level = 1,},		--飞烤肉
					{Type = 240,Variant = 114,level = 3,},		--口球蜘蛛
					{Type = 240,Variant = 115,level = 3,},		--枪管蜘蛛
					{Type = 240,Variant = 450,level = 3,},		--导向蜘蛛
					{Type = 240,Variant = 700,level = 3,},		--火焰蜘蛛
					{Type = 240,Variant = 701,level = 3,},		--网蜘蛛
					{Type = 240,Variant = 710,level = 3,},		--吐根蜘蛛
					{Type = 240,Variant = 711,level = 3,},		--魔蜘蛛
				},
				jumpable = {
					{Type = 29,Variant = 1,SubType = 5,level = 3,},		--炸弹跳跳蜘蛛
					{Type = 29,Variant = 1,SubType = 170,level = 3,},		--石油跳跳蜘蛛
					{Type = 29,Variant = 960,level = 3,},		--牙状跳跳蜘蛛
					{Type = 29,Variant = 961,level = 3,},		--连击跳跳蜘蛛
					{Type = 114,Variant = 44,level = 1,mul = {3,4,5,6,7,},},		--军跳蛛
					{Type = 114,Variant = 45,level = 1,mul = {3,4,5,6,7,},},		--环跳蛛
					{Type = 114,Variant = 51,level = 2,},		--珍珠贝
					{Type = 151,Variant = 0,level = 1,},		--挤压者
					{Type = 151,Variant = 1,level = 1,},		--小挤压者
					{Type = 151,Variant = 4,level = 3,},		--血挤压者
					{Type = 151,Variant = 5,level = 1,},		--火挤压者
					{Type = 151,Variant = 6,level = 3,},		--毒挤压者
					{Type = 151,Variant = 7,level = 2,},		--大挤压者
					{Type = 151,Variant = 8,level = 5,},		--恶魔挤压者
					{Type = 151,Variant = 9,level = 4,},		--蛆虫挤压者
					{Type = 151,Variant = 10,level = 4,},		--屁王挤压者
					{Type = 151,Variant = 1,SubType = 1,level = 1,ignore_place = true,mul = {1,2,3,},},		--小挤压者 藏匿版本
					{Type = 151,Variant = 4,SubType = 1,level = 3,ignore_place = true,mul = {1,2,3,},},		--血挤压者 藏匿版本
					{Type = 151,Variant = 5,SubType = 1,level = 1,ignore_place = true,mul = {1,2,3,},},		--火挤压者 藏匿版本
					{Type = 151,Variant = 6,SubType = 1,level = 3,ignore_place = true,mul = {1,2,3,},},		--毒挤压者 藏匿版本
					{Type = 151,Variant = 7,SubType = 1,level = 2,ignore_place = true,mul = {1,2,3,},},		--大挤压者 藏匿版本
					{Type = 151,Variant = 8,SubType = 1,level = 5,ignore_place = true,mul = {1,2,3,},},		--恶魔挤压者 藏匿版本
					{Type = 151,Variant = 9,SubType = 1,level = 4,ignore_place = true,mul = {1,2,3,},},		--蛆虫挤压者 藏匿版本
					{Type = 151,Variant = 10,SubType = 1,level = 4,ignore_place = true,mul = {1,2,3,},},		--屁王挤压者 藏匿版本
					{Type = 160,Variant = 682,SubType = 1,level = 4,},		--血胖蜘蛛
					{Type = 160,Variant = 2001,level = 2,},		--超大蘑菇的小鬼
					{Type = 170,Variant = 120,level = 2,},		--跳行蛛
					{Type = 180,Variant = 221,level = 4,},		--腐立德先生的眼睛
					{Type = 215,Variant = 710,level = 1,},		--饱蜘蛛
					{Type = 215,Variant = 711,level = 2,},		--炸弹蜘蛛
					{Type = 215,Variant = 712,level = 4,},		--血迹蜘蛛
					{Type = 215,Variant = 713,level = 1,},		--袋蜘蛛
					{Type = 215,Variant = 714,level = 2,},		--吐根蜘蛛
					{Type = 215,Variant = 715,level = 4,},		--疯狂蜘蛛
					{Type = 215,Variant = 2305,level = 1,},		--穴居蜘蛛
					{Type = 666,Variant = 60,level = 1,},		--跳蛛
					{Type = 666,Variant = 80,level = 2,},		--高跳蛛
					{Type = 750,Variant = 140,level = 2,},		--骨挤压者
				},
				hideable = {
					{Type = 114,Variant = 18,level = 2,},		--钟乳石
					{Type = 114,Variant = 24,level = 3,},		--传送娃娃
					{Type = 114,Variant = 27,level = 3,},		--妖术娃娃
					{Type = 114,Variant = 31,level = 3,},		--震动
					{Type = 114,Variant = 32,level = 3,},		--晃动
					{Type = 114,Variant = 39,level = 4,},		--跳跳宿主
					{Type = 114,Variant = 42,level = 3,},		--Slimer
					{Type = 150,Variant = 16,SubType = {1,2,3,},level = 3,ignore_place = true,mul = {1,2,3,},},		--藏匿版本
					{Type = 150,Variant = 16,SubType = {4,5,6,},level = 3,ignore_place = true,mul = {1,2,3,},},		--藏匿版本
					{Type = 150,Variant = 16,SubType = {7,8,9,},level = 3,ignore_place = true,mul = {1,2,3,},},		--藏匿版本
					{Type = 150,Variant = 16,SubType = {10,11,12,},level = 3,ignore_place = true,mul = {1,2,3,},},		--藏匿版本
					{Type = 150,Variant = 16,SubType = {13,18,19},level = 3,ignore_place = true,mul = {1,2,3,},},		--藏匿版本
					{Type = 160,Variant = 240,level = 2,},		--鱼人
					{Type = 160,Variant = 240,SubType = 1,level = 2,ignore_place = true,mul = {1,2,3,},},		--鱼人 藏匿版本
					{Type = 160,Variant = 241,level = 2,},		--闪光鱼人
					{Type = 160,Variant = 670,level = 3,special = function(pos) local mul = math.random(3) - 1 for i = 1,mul do local q = Isaac.Spawn(160,671,0,pos,Vector(0,0),nil) local d2 = q:GetData() d2.has_been_checked_by_Danger = true q.SpawnerType = 10001 end end,},		--女王
					{Type = 160,Variant = 980,level = 3,},		--弗兰肯
					{Type = 160,Variant = 1010,level = 4,},		--胚胎朋友
					{Type = 160,Variant = 1020,level = 4,},		--爆头
					{Type = 160,Variant = 1080,level = 1,},		--小冥冥
					{Type = 160,Variant = 1090,level = 3,},		--杀手
					{Type = 160,Variant = 1240,level = 2,},		--巨绦虫
					{Type = 160,Variant = 1320,level = 2,},		--雨男2
					{Type = 170,Variant = 90,level = 2,},		--怪骨
					{Type = 244,Variant = 960,level = 2,},		--骨绦虫
					--244.960.10
					{Type = 450,Variant = 20,level = 3,},		--异眼
					{Type = 450,Variant = 13,level = 2,},		--降鬼
					{Type = 666,Variant = 100,level = 2,},		--引虫
					{Type = 666,Variant = 101,level = 2,},		--吸虫 
					{Type = 829,Variant = 450,level = 3,},		--爆炸地鼠
				},
				flyable = {
					{Type = 13,Variant = 333,level = 1,},		--拇指苍蝇
					--13.0.250
					{Type = 18,Variant = 114,level = 2,},		--俄罗斯套苍蝇
					{Type = 25,Variant = 450,level = 4,},		--吐毒胖苍蝇
					{Type = 25,Variant = 451,level = 1,},		--注水胖苍蝇
					{Type = 25,Variant = 452,level = 5,},		--黄金胖苍蝇		--超模！
					{Type = 25,Variant = 920,level = 3,},		--精神胖苍蝇
					{Type = 25,Variant = 960,level = 2,},		--骨胖苍蝇
					{Type = 25,Variant = 961,level = 5,},		--黄金胖苍蝇2		--超模！
					{Type = 25,Variant = 962,level = 1,},		--蜜蜂胖苍蝇
					{Type = 25,Variant = 963,level = 1,},		--干瘪胖苍蝇
					{Type = 61,Variant = 450,level = 1,},		--注水吸食者
					{Type = 61,Variant = 960,level = 1,},		--烘烤吸食者
					{Type = 61,Variant = 961,level = 2,},		--大型烘烤吸食者
					{Type = 108,Variant = 111,level = 5,},		--真视之眼
					{Type = 114,Variant = 0,level = 3,},		--小型瘤
					{Type = 114,Variant = 1,level = 2,},		--湿物
					{Type = 114,Variant = 3,level = 1,},		--小型雨男
					{Type = 114,Variant = 4,level = 1,},		--招光者
					{Type = 114,Variant = 10,level = 2,},		--挖土机
					{Type = 114,Variant = 11,level = 2,},		--新月
					{Type = 114,Variant = 14,level = 2,},		--浮灵
					--{Type = 114,Variant = 23,level = 2,},		--小骨鬼
					{Type = 114,Variant = 26,level = 1,},		--Brood
					{Type = 114,Variant = 29,level = 3,},		--死首
					--{Type = 114,Variant = 30,level = 2,},		--小天使鬼
					{Type = 114,Variant = 35,level = 2,},		--胖怒意的小鬼
					{Type = 114,Variant = 41,level = 3,},		--枪手
					{Type = 114,Variant = 46,SubType = 1,level = 4,},		--Flailer的头
					--{Type = 114,Variant = 47,level = 1,},		--mite		--似乎没做？
					{Type = 114,Variant = 48,level = 5,},		--铃音
					{Type = 114,Variant = 49,level = 2,},		--烈焰骨头
					{Type = 114,Variant = 55,level = 4,},		--斜向冲锋
					{Type = 120,Variant = 224,level = 3,},		--Empath
					{Type = 120,Variant = 226,level = 3,},		--六向蝇
					{Type = 120,Variant = 227,level = 3,},		--菊花蝇
					{Type = 120,Variant = 232,SubType = 1,level = 4,},		--拘束双子的小鬼
					{Type = 130,Variant = 20,level = 4,},		--Myiasis		--.1
					{Type = 130,Variant = 30,level = 2,mul = {1,2,3,},},		--回血苍蝇
					{Type = 130,Variant = 40,SubType = {0,1,},level = 3,},		--鸦鸦
					{Type = 130,Variant = 70,level = 3,},		--沙袋
					{Type = 130,Variant = 80,level = 3,},		--灾夜
					--130.81	
					{Type = 140,Variant = 0,level = 1,},		--蜜蜂眼
					{Type = 150,Variant = 2,level = 2,},		--孵化蝇巢
					{Type = 150,Variant = 11,level = 4,},		--飞镰刀
					{Type = 150,Variant = 15,level = 2,},		--孢子
					{Type = 152,Variant = 0,SubType = {0,1,},level = 2,},		--方阵苍蝇
					{Type = 154,Variant = 0,level = 2,special = function(pos) local room = Game():GetRoom() local mul = math.random(5) + 2 for i = 1,mul do local pos = room:FindFreePickupSpawnPosition(room:GetRandomPosition(20),10,true) local q = Isaac.Spawn(5,0,4,pos,Vector(0,0),nil) end end},		--小偷
					{Type = 155,Variant = 0,level = 2,},		--波虫
					{Type = 155,Variant = 1,level = 2,},		--波虫2
					{Type = 155,Variant = 2,level = 5,},		--魔波虫
					{Type = 155,Variant = 3,level = 4,},		--菊花波虫
					{Type = 155,Variant = 4,level = 2,},		--暴鲤波虫
					{Type = 156,Variant = 0,level = 4,},		--环化增生
					{Type = 156,Variant = 69,level = 4,},		--巨噬
					{Type = 156,Variant = 666,level = 5,only_spawn = true,mul = {1,2,3,},ignore_place = true,},		--羊头
					{Type = 160,Variant = 100,level = 3,},		--油妖
					{Type = 160,Variant = 101,level = 3,},		--黑头油妖
					{Type = 160,Variant = 110,level = 4,},		--血妖
					{Type = 160,Variant = 180,level = 1,},		--蜜蜂
					{Type = 160,Variant = 190,level = 3,only_spawn = true,ignore_place = true,},		--乔
					--160.190.1
					{Type = 160,Variant = 200,level = 5,},		--魔导者
					{Type = 160,Variant = 231,level = 3,},		--鬼上身的鬼
					{Type = 160,Variant = 250,level = 2,},		--双生淹死鬼
					{Type = 160,Variant = 250,SubType = {1,2,},level = 2,},		--双生淹死鬼的分身
					{Type = 160,Variant = 260,level = 2,},		--吐酸头
					{Type = 160,Variant = 270,level = 3,},		--屁股鬼
					{Type = 160,Variant = 271,level = 1,},		--可爱屁股鬼
					{Type = 160,Variant = 272,level = 4,},		--吐根屁股鬼
					{Type = 160,Variant = 290,level = 4,},		--织首者
					{Type = 160,Variant = 320,SubType = {0,7000,},level = 2,},		--快蝙蝠
					{Type = 160,Variant = 340,level = 5,},		--魔操者
					{Type = 160,Variant = 341,level = 5,},		--魔导弹
					{Type = 160,Variant = 350,level = 3,},		--发烟恶鬼
					{Type = 160,Variant = 351,level = 3,},		--发烟恶鬼的子弹
					{Type = 160,Variant = 390,level = 4,},		--肉翔者
					{Type = 160,Variant = 400,level = 2,},		--蜂巢
					{Type = 160,Variant = 400,SubType = 200,level = 2,},		--蜂巢2
					{Type = 160,Variant = 401,level = 1,only_spawn = function(ent) if ent.ParentNPC and ent.ParentNPC.Type == 160 then return true end end,},		--工蜂
					{Type = 160,Variant = 402,level = 1,},		--蜂针
					{Type = 160,Variant = 420,level = 3,},		--妖脑灵
					{Type = 160,Variant = 450,level = 5,},		--庇护苍蝇
					{Type = 160,Variant = 451,level = 2,},		--石苍蝇
					{Type = 160,Variant = 460,level = 5,},		--天使胖苍蝇
					{Type = 160,Variant = 470,level = 4,},		--肉条
					{Type = 160,Variant = 480,level = 3,},		--腐蛆之心
					--160.490
					{Type = 160,Variant = 510,level = 4,},		--眼妖
					{Type = 160,Variant = 520,level = 4,},		--双子宝
					{Type = 160,Variant = 521,level = 4,},		--精神双子宝
					{Type = 160,Variant = 540,level = 3,special = function(pos) local mul = math.random(8) for i = 1,mul do local q = Isaac.Spawn(160,540,1,pos,Vector(0,0),nil) local d2 = q:GetData() d2.has_been_checked_by_Danger = true q.SpawnerType = 10001 end end,},		--连接虫
					{Type = 160,Variant = 541,level = 3,special = function(pos) local mul = math.random(8) for i = 1,mul do local q = Isaac.Spawn(160,540,1,pos,Vector(0,0),nil) local d2 = q:GetData() d2.has_been_checked_by_Danger = true q.SpawnerType = 10001 end end,},		--连接虫2
					{Type = 160,Variant = 560,level = 1,special = function(pos) local room = Game():GetRoom() local grididx = room:GetGridIndex(pos) room:SpawnGridEntity(grididx,GridEntityType.GRID_POOP,math.random(7) - 1,room:GetSpawnSeed(),0) end,},		--食粪虫
					{Type = 160,Variant = 561,level = 2,special = function(pos) local room = Game():GetRoom() local grididx = room:GetGridIndex(pos) room:SpawnGridEntity(grididx,GridEntityType.GRID_POOP,math.random(7) - 1,room:GetSpawnSeed(),0) end,},		--食粪虫2
					{Type = 160,Variant = 590,level = 1,},		--击出蜜蜂
					{Type = 160,Variant = 610,level = 1,},		--冲锋蜜蜂
					{Type = 160,Variant = 620,level = 4,},		--散弹吸食者
					{Type = 160,Variant = 640,level = 2,},		--电击水母
					{Type = 160,Variant = 641,level = 2,only_spawn = function(ent) if ent.ParentNPC and ent.ParentNPC.Type == 160 then return true end end,mul = {2,3,4,5,},},		--电击水母的召唤物
					{Type = 160,Variant = 660,level = 3,},		--镰刀行者
					{Type = 160,Variant = 661,level = 3,},		--夜叉行者
					{Type = 160,Variant = 666,level = 3,},		--祝你好死
					{Type = 160,Variant = 680,level = 2,},		--化石胖苍蝇
					{Type = 160,Variant = 681,level = 1,},		--胖蜜蜂
					{Type = 160,Variant = 682,level = 4,},		--血胖苍蝇
					{Type = 160,Variant = 683,level = 2,},		--葡萄苍蝇
					{Type = 160,Variant = 683,SubType = 1,level = 2,},		--小葡萄苍蝇
					{Type = 160,Variant = 700,level = 2,},		--冲锋大苍蝇
					{Type = 160,Variant = 701,level = 3,},		--针刺大苍蝇
					{Type = 160,Variant = 710,level = 2,},		--鬼灵
					{Type = 160,Variant = 711,level = 4,},		--魔灵
					{Type = 160,Variant = 711,SubType = 1,level = 4,mul = {7,8,9,10,11,12,13,14,},ignore_place = true,special_work = function(ent,id) ent:GetData().chargedelay = id * 10 end,},		--魔灵
					{Type = 160,Variant = 720,level = 5,},		--狱天使
					--{Type = 160,Variant = 740,level = 4,},		--链接块
					{Type = 160,Variant = 790,level = 1,},		--麻烦妖
					{Type = 160,Variant = 810,level = 1,},		--召唤蜂
					{Type = 160,Variant = 870,level = 5,},		--点睛
					{Type = 160,Variant = 870,SubType = 1,level = 5,},		--点睛
					{Type = 160,Variant = 880,level = 4,},		--吐眼
					{Type = 160,Variant = 888,level = 3,},		--苍蝇环环
					{Type = 160,Variant = 930,level = 4,},		--敌胎		--有bug
					{Type = 160,Variant = 941,level = 5,},		--魔眼
					{Type = 160,Variant = 950,level = 5,mul = {2,3,4,5,},},		--粘合怪
					{Type = 160,Variant = 950,SubType = 1,level = 5,},		--粘合怪
					{Type = 160,Variant = 951,SubType = {0,1,},level = 5,},		--魔洞
					{Type = 160,Variant = 970,level = 4,},		--大宝宝召唤者
					{Type = 160,Variant = 971,level = 4,},		--大宝宝
					{Type = 160,Variant = 1110,level = 1,},		--造屁者
					{Type = 160,Variant = 1120,level = 1,},		--科技人
					{Type = 160,Variant = 1140,level = 3,},		--三分魔法师
					{Type = 160,Variant = 1160,level = 3,},		--一换六神将
					{Type = 160,Variant = 1220,level = 3,},		--对弈
					{Type = 160,Variant = 1260,level = 2,},		--快乐宝宝
					{Type = 160,Variant = 1280,level = 2,},		--撞蜂
					{Type = 160,Variant = 1710,level = 4,},		--喷洒
					{Type = 170,Variant = 0,level = 3,},		--骨妖
					{Type = 170,Variant = 10,level = 3,},		--悬骨怪
					{Type = 170,Variant = 11,level = 5,},		--腐化悬骨怪
					{Type = 170,Variant = 30,level = 3,},		--闪电苍蝇
					{Type = 170,Variant = 110,level = 3,},		--火爆
					{Type = 180,Variant = 21,level = 2,},		--突击队的召唤物
					{Type = 180,Variant = 212,level = 2,},		--线人的头
					{Type = 180,Variant = 241,level = 2,},		--水鬼的召唤物
					{Type = 180,Variant = 242,SubType = {0,1,},level = 2,mul = {2,3,4,},ignore_place = true,},		--水鬼的召唤物
					--212.450
					{Type = 212,Variant = 451,mul = {1,2,},ignore_place = true,level = 3,},		--骨头
					{Type = 214,Variant = 710,level = 3,},		--吐根苍蝇
					{Type = 214,Variant = 711,level = 2,},		--炸弹苍蝇
					{Type = 214,Variant = 712,level = 4,},		--血迹苍蝇
					{Type = 214,Variant = 713,level = 2,},		--袋苍蝇
					{Type = 214,Variant = 714,level = 4,},		--疯狂苍蝇
					{Type = 214,Variant = 715,level = 1,},		--贴贴苍蝇
					{Type = 218,Variant = 750,level = 2,mul = {2,3,},ignore_place = true,},		--游行者
					{Type = 234,Variant = 960,level = 1,},		--骨蝠
					{Type = 258,Variant = 960,level = 2,},		--溺死胖蝙蝠
					{Type = 258,Variant = 961,level = 2,},		--骨胖蝙蝠
					{Type = 310,Variant = 1,SubType = 2302,level = 4,},		--畸瘤小体
					{Type = 369,Variant = 14,level = 1,},		--妖女
					{Type = 450,Variant = 1,level = 3,},		--招恶师
					{Type = 450,Variant = 2,level = 1,},		--冥火蝇
					{Type = 450,Variant = 3,level = 5,},		--四翼天使
					{Type = 450,Variant = 11,level = 3,},		--怪水母
					{Type = 450,Variant = 15,level = 3,},		--秘术师
					{Type = 450,Variant = 1500,level = 3,},		--钥匙怪
					{Type = 450,Variant = 16,SubType = 1,level = 4,},		--腐与骨的头
					{Type = 450,Variant = 17,level = 3,},		--大胖胖
					{Type = 450,Variant = 21,level = 2,},		--外星人
					{Type = 450,Variant = 23,level = 1,only_spawn = function(ent) if ent.SpawnerEntity and ent.SpawnerEntity.Type == 160 then return true end end,},		--针蜂
					{Type = 450,Variant = 24,level = 1,},		--双针蜂
					{Type = 450,Variant = 26,SubType = {0,1,2,3,4,},level = 2,},		--骨牙
					{Type = 450,Variant = 27,level = 2,},		--河豚
					{Type = 450,Variant = 29,level = 3,},		--魔术师
					{Type = 450,Variant = 30,level = 3,},		--魔书
					{Type = 450,Variant = 31,level = 4,},		--死蜂
					{Type = 450,Variant = 33,level = 1,mul = {1,2,3,},ignore_place = true,},		--浮光灵
					{Type = 450,Variant = 38,level = 3,},		--练习恶魔
					{Type = 450,Variant = 42,level = 1,},		--浮光
					{Type = 450,Variant = 44,level = 2,},		--屁胖蝇
					{Type = 450,Variant = 45,level = 2,},		--海绵
					{Type = 451,Variant = 0,level = 4,},		--异蜂
					{Type = 610,Variant = 0,level = 3,},		--吊人？
					{Type = 666,Variant = 20,level = 3,},		--蝇生
					{Type = 666,Variant = 40,level = 2,},		--烂蝙蝠
					{Type = 666,Variant = 110,level = 2,},		--蘑菇怪
					{Type = 666,Variant = 130,level = 3,},		--怪壳
					{Type = 666,Variant = 200,level = 3,},		--脑壳
					{Type = 666,Variant = 210,level = 2,mul = {1,2,3,},only_spawn = true,ignore_place = true,},		--矿头
					{Type = 709,Variant = 0,level = 2,mul = {1,2,3,},SubType = {0,1,2,3,},only_spawn = true,ignore_place = true,},		--行走幽灵
					{Type = 709,Variant = 1,level = 2,mul = {1,2,3,},SubType = {0,1,2,3,},only_spawn = true,ignore_place = true,},		--行走幽灵2
					{Type = 750,Variant = 20,level = 4,},		--吼击
					{Type = 750,Variant = 40,level = 3,},		--起爆骨
					{Type = 750,Variant = 50,level = 4,},		--究极大苍蝇
					{Type = 750,Variant = 90,level = 3,},		--大噬
					{Type = 750,Variant = 150,level = 4,},		--缠婴
					{Type = 750,Variant = 200,level = 4,},		--吼蝇怪
					{Type = 750,Variant = 201,level = 4,mul = {3,4,5,6,7,},},		--吼蝇
					{Type = 750,Variant = 210,SubType = {0,1,2,3,4,99,},level = 2,},		--鬼滴
					{Type = 880,Variant = 450,level = 3,},		--裂头割肉者
				},
				special = {
				},
				water = {
					{Type = 160,Variant = 60,level = 2,},		--蛙蛙
					{Type = 160,Variant = 120,level = 2,},		--骨沟
					{Type = 750,Variant = 30,level = 3,},		--未知骨
				},
				unbreakable = {
					{Type = 42,Variant = 960,level = 2,},		--湿石
					{Type = 42,Variant = 961,level = 3,},		--再石
					--42.962		--未知作用
					{Type = 42,Variant = 963,level = 3,SubType = {0,1,2,3,},},		--连击石
					{Type = 42,Variant = 964,level = 2,},		--焰火雕像
					--44.960/961/962/980等		--占用地面，无实际用途
					{Type = 108,Variant = 110,level = 4,},		--血管
					{Type = 108,Variant = 114,level = 4,},		--开合脑
					{Type = 108,Variant = 118,level = 4,SubType = {120,150,200,250,},},		--shaggoth之眼
					{Type = 114,Variant = 6,level = 3,mul = {3,4,5,6,},},		--小石头
					{Type = 114,Variant = 58,level = 3,},		--压死人
					{Type = 120,Variant = 222,level = 4,},		--激光监控
					{Type = 130,Variant = 60,level = 1,},		--玻璃眼
					{Type = 151,Variant = 2,level = 2,},		--石挤压者
					{Type = 151,Variant = 3,level = 2,},		--疯狂石挤压者
					{Type = 160,Variant = 1200,level = 2,},		--巨首
					{Type = 915,Variant = 1,SubType = {768,776,784,792,744,752,760,},},		--特殊踢物
				},
				spike = {
					{Type = 150,Variant = 32,level = 3,},		--齿轮
				},
			},
			sins = {
				normal = {
					{Type = 159,Variant = 0,level = 5,},		--超力
					{Type = 450,Variant = 46,level = 2,},		--隐者
				},
			},
			boss = {
				normal = {
					{Type = 19,Variant = 0,SubType = 3,mul = {3,4,5,},is_multi = true,},		--贪吃蛇
					{Type = 19,Variant = 1,SubType = 4,mul = {3,4,5,},is_multi = true,},		--空心虫
					{Type = 20,Variant = 0,SubType = 3,level = 1,},		--戳戳
					{Type = 69,Variant = 0,SubType = 1,level = 3,},		--洛基
					{Type = 62,Variant = 0,SubType = 2,is_multi = true,},	--pin
					{Type = 71,Variant = 0,SubType = 2,},		--蜂巢
					{Type = 72,Variant = 0,SubType = 2,},		--蜂巢
					{Type = 73,Variant = 0,SubType = 2,},		--蜂巢
					{Type = 100,Variant = 0,SubType = 3,},		--毒蜘蛛
					{Type = 97,Variant = 0,SubType = 2,},		--肾脏
					{Type = 180,Variant = 0,level = 1,},		--枪牢
					{Type = 180,Variant = 50,level = 4,},		--太阳		--不动衍生物了
					{Type = 180,Variant = 70,level = 4,},		--巴斯克
					{Type = 180,Variant = 90,level = 4,},		--窥见
					{Type = 180,Variant = 91,level = 4,},		--窥见2
					{Type = 180,Variant = 100,level = 3,},		--午餐		--不动部分衍生物了
					{Type = 180,Variant = 111,level = 3,},		--污染2
					{Type = 180,Variant = 121,level = 1,},		--招核2
					{Type = 180,Variant = 160,level = 2,},		--水头
					{Type = 180,Variant = 180,SubType = {0,1,2,3,4,5,},level = 3,special = function(pos) 
						local room = Game():GetRoom() 
						local mul = math.random(3) - 1 
						for i = 1,mul do local pos = room:GetRandomPosition(20) local q = Isaac.Spawn(44,1820,0,pos,Vector(0,0),nil) end 
						local mul = math.random(3) - 1 
						for i = 1,mul do local rnd = math.random(5) - 1 local pos = room:GetRandomPosition(20) local q = Isaac.Spawn(44,1810,rnd,pos,Vector(0,0),nil) end 
					end},		--沙皇		--不动衍生物了
					{Type = 180,Variant = 200,level = 3,},		--巨胖
					{Type = 180,Variant = 210,level = 2,},		--线人
					{Type = 180,Variant = 210,SubType = 1,level = 2,},		--线人
					{Type = 180,Variant = 220,level = 4,},		--腐立德先生
					{Type = 180,Variant = 230,level = 3,},		--传送区域
					{Type = 180,Variant = 231,level = 3,},		--传送戳戳
					{Type = 180,Variant = 232,level = 3,mul = {2,3,4,},is_multi = true,},		--传送larry
					{Type = 180,Variant = 233,level = 3,special = function(pos) local q = Isaac.Spawn(180,234,0,pos,Vector(0,0),nil) local d2 = q:GetData() d2.has_been_checked_by_Danger = true q.SpawnerType = 10001 end,},		--传送双子
					{Type = 180,Variant = 234,level = 3,special = function(pos) local q = Isaac.Spawn(180,233,0,pos,Vector(0,0),nil) local d2 = q:GetData() d2.has_been_checked_by_Danger = true q.SpawnerType = 10001 end,},		--传送双子
				},
				onwall = {
				},
				jumpable = {
					{Type = 180,Variant = 40,level = 2,},		--水之戳
				},
				hideable = {
					{Type = 150,Variant = 16,SubType = 14,level = 3,},		--藏匿版本 pin
					{Type = 150,Variant = 16,SubType = 15,level = 3,},		--藏匿版本 菊花虫
					{Type = 150,Variant = 16,SubType = 16,level = 3,},		--藏匿版本 骨虫
					{Type = 150,Variant = 16,SubType = 17,level = 3,},		--藏匿版本 掘地虫
					{Type = 180,Variant = 30,level = 1,},		--小火恩
				},
				flyable = {
					--{Type = 114,Variant = 1000,level = 5,},		--小脑鼠
					{Type = 114,Variant = 1001,level = 5,},		--？
					--{Type = 114,Variant = 1003,level = 5,},		--iwanna的初音未来
					--124.1000
					{Type = 180,Variant = 10,level = 2,},		--贝蒂
					{Type = 180,Variant = 10,SubType = {1,2,},level = 2,},		--贝蒂
					{Type = 180,Variant = 20,level = 1,},		--突击队
					{Type = 180,Variant = 60,level = 3,special = function(pos) for i = 61,63 do local q = Isaac.Spawn(180,i,0,pos,Vector(0,0),nil) local d2 = q:GetData() d2.has_been_checked_by_Danger = true q.SpawnerType = 10001 end end,},		--分尸的衍生物
					{Type = 180,Variant = 80,level = 3,is_multi = true,only_spawn = true,},		--虫王
					{Type = 180,Variant = 110,level = 3,},		--污染
					{Type = 180,Variant = 120,level = 1,},		--招核		--不动衍生物了
					{Type = 180,Variant = 170,level = 3,myspecial = function(ent) local n_entity = Isaac.GetRoomEntities() local ns = auxi.getothers(n_entity,1000,1960,nil) for u,v in pairs(ns) do if v.Parent and (auxi.check_for_the_same(v.Parent,ent) or (v.Parent.Type == 1000 and v.Parent.Variant == 1960)) then v:Remove() end end end,},		--黄昏
					{Type = 180,Variant = 190,level = 1,},		--毒术士
					{Type = 180,Variant = 240,level = 2,},		--水鬼
					{Type = 180,Variant = 1000,SubType = {0,1,},level = 5,},		--蓝头
					{Type = 180,Variant = 1010,level = 5,},		--恶魔公爵
					{Type = 666,Variant = 160,SubType = {0,1,},level = 1,},		--蜂后
					{Type = 666,Variant = 190,level = 2,},		--蜂怪
					{Type = 750,Variant = 60,level = 4,},		--掘墓人
					
					{Type = 67,Variant = 1,SubType = 3,},
					{Type = 908,Variant = 0,SubType = 1,level = 1,},		--金大可爱
					{Type = 45,Variant = 10,SubType = 96,should_delay = true,special_morph = {Variant = 0,},center_pos = true,special = function(pos) 
						local room = Game():GetRoom()
						local n_entity = Isaac.GetRoomEntities()
						for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do 
							if room:IsDoorSlotAllowed(slot) then
								local pos = room:GetDoorSlotPosition(slot)
								local should_spawn = true
								for u,v in pairs(n_entity) do
									if v.Type == 45 and (v.Position - pos):Length() < 60 then
										should_spawn = false
										break
									end
								end
								if should_spawn then
									local q = Isaac.Spawn(45,0,0,pos,Vector(0,0),nil) 
									local d2 = q:GetData() 
									d2.has_been_checked_by_Danger = true
									d2.fixed_position = pos
								end
							end
						end
					end,hard = true,},
				},
				special = {
				},
				water = {
				},
			},
		},
		other_info = {
			monsters = {
				normal = {
					{Type = 150,Variant = 20,level = 3,},		--脑袋
					{Type = 160,Variant = 901,SubType = 1,level = 3,},		--内窥眼的未启迪者
					{Type = 160,Variant = 1001,level = 2,},		--杰克先生
					{Type = 160,Variant = 1712,level = 4,},		--？
					{Type = 160,Variant = 1711,level = 5,},		--以撒本体
					--什么垃圾彩蛋，不做了
					{Type = 180,Variant = 61,level = 3,},		--分尸的衍生物
					{Type = 180,Variant = 62,level = 3,},		--分尸的衍生物
					{Type = 180,Variant = 63,level = 3,},		--分尸的衍生物
					{Type = 180,Variant = 71,level = 4,},		--巴斯克的召唤物
					{Type = 180,Variant = 191,level = 2,},		--毒术士的召唤物
					{Type = 180,Variant = 211,level = 2,},		--线人的召唤物
				},
				onwall = {
				},
				jumpable = {
				},
				hideable = {
				},
				flyable = {
					{Type = 114,Variant = 1005,level = 4,},		--尿罐子
					{Type = 160,Variant = 461,level = 5,},		--天使胖苍蝇的永恒苍蝇
					{Type = 160,Variant = 581,level = 2,},		--造碑者的墓碑
					{Type = 160,Variant = 1000,level = 2,},		--奇异球体
					{Type = 180,Variant = 1011,level = 5,},		--恶魔公爵的衍生物		--这玩意没贴图？
				},
				special = {
				},
				water = {
				},
				unbreakable = {
				},
				spike = {
				},
			},
			sins = {
			},
			boss = {
				normal = {
				},
				onwall = {
				},
				jumpable = {
				},
				hideable = {
				},
				flyable = {
					{Type = 180,Variant = 250,level = 2,},		--三魂		--算法太离谱了
					{Type = 45,Variant = 0,SubType = 96,},
				},
				special = {
				},
				water = {
				},
			},
		},
	},
}

function item.get_now_level()
	if Game():IsGreedMode() then
		local stag = Game():GetLevel():GetStage()
		local ret = stag
		if ret >= 7 then ret = 6 end
		return ret
	else
		local level = Game():GetLevel()
		local stag = level:GetStage()
		local ret = item.level_map[stag] or math.ceil(stag/2)
		if level:IsAscent() then ret = 5 end
		return ret
	end
end

function item.get_safe_level(level)
	level = level or item.get_now_level()
	if level > 6 then level = 6 end
	if level < 0 then level = 0 end
	return level
end

local function check_multiple(stb)
	local ret = {}
	if type(stb) == "table" then
		for u,v in pairs(stb) do
			table.insert(ret,#ret + 1,v)
		end
	else
		ret[1] = stb
	end
	return ret
end

local function get_multiple(stb)
	local ret = 0
	if type(stb) == "table" then
		if #stb > 0 then
			ret = stb[math.random(#stb)]
		end
	elseif stb ~= nil then 
		ret = stb 
	end
	return ret
end

local function form_info_name(tp)
	if type(tp) == "table" then
		local ret = {}
		local ret_1 = ""
		local ret_2 = ""
		local ret_3 = ""
		local Typeinfo = check_multiple(tp.Type or 0)
		for u,v in pairs(Typeinfo) do
			ret_1 = tostring(v) .. "_"
			local Variantinfo = check_multiple(tp.Variant or 0)
			for u2,v2 in pairs(Variantinfo) do
				ret_2 = ret_1 .. tostring(v2) .. "_"
				local SubTypeinfo = check_multiple(tp.SubType or 0)
				for u3,v3 in pairs(SubTypeinfo) do
					ret_3 = ret_2 .. tostring(v3)
					table.insert(ret,#ret + 1,{name = ret_3,Type = v,Variant = v2,SubType = v3,})
				end
			end
		end
		return ret
	else
		local ret = nil
		if tp.Type ~= nil and tp.Variant ~= nil and tp.SubType ~= nil then
			ret = tostring(tp.Type) .. "_" .. tostring(tp.Variant) .. "_" .. tostring(tp.SubType)
		end
		return ret
	end
end

function item.make_data()
	item.info_data = {}
	if FiendFolio then
		for	u1,v1 in pairs(item.ff_info.original_info) do
			for u2,v2 in pairs(v1) do
				for u3,v3 in pairs(v2) do
					table.insert(item.original_info[u1][u2],#item.original_info[u1][u2] + 1,v3)
				end
			end
		end
		for	u1,v1 in pairs(item.ff_info.other_info) do
			for u2,v2 in pairs(v1) do
				for u3,v3 in pairs(v2) do
					table.insert(item.other_info[u1][u2],#item.other_info[u1][u2] + 1,v3)
				end
			end
		end
	end
	for	u1,v1 in pairs(item.original_info) do
		for u2,v2 in pairs(v1) do
			for u3,v3 in pairs(v2) do
				local name_info = form_info_name(v3)
				if type(name_info) == "table" then
					for u4,v4 in pairs(name_info) do
						item.info_data[v4.name] = {base = v4,i1 = u1,i2 = u2,data = v3,}
					end
				end
			end
		end
	end
	for	u1,v1 in pairs(item.other_info) do
		for u2,v2 in pairs(v1) do
			for u3,v3 in pairs(v2) do
				local name_info = form_info_name(v3)
				if type(name_info) == "table" then
					for u4,v4 in pairs(name_info) do
						item.info_data[v4.name] = {base = v4,i1 = u1,i2 = u2,data = v3,is_other = true,}
					end
				end
			end
		end
	end
end

function item.check_data(ent)
	if item.info_data == nil then item.make_data() end
	local name = form_info_name(ent)
	if name ~= nil then
		if type(name) == "table" then
			for u,v in pairs(name) do if item.info_data[v.name] then return item.info_data[v.name] end end
		else
			return item.info_data[name]
		end
	end
end

function item.get_morph_dir(tp)
	local ret = {}
	if type(tp) == "string" then
		ret = item.morph_dirs[tp] or ret
	end
	return ret
end

function item.spawn_it_now(ent,info,should_protect,specialwork)
	local mul = get_multiple(info.data.mul) or 1
	local room = Game():GetRoom() 
	if mul == 0 then mul = 1 end
	local pos = ent.Position or room:GetRandomPosition(20) 
	local tg_mxhp = ent.MaxHitPoints
	local should_transmit = nil
	local should_remakeroom = nil
	if info.data.pre_special_work then info.data.pre_special_work() end
	for i = 1,mul do
		if info.data.ignore_place then 
			pos = room:GetRandomPosition(20) 
		end
		local tp = ent.Type
		local vr = ent.Variant
		local st = ent.SubType
		if info.data.special_morph then
			local mpif = info.data.special_morph
			tp = mpif.Type or tp
			vr = mpif.Variant or vr
			st = mpif.SubType or st
		end
		--print(tp.." "..vr.." "..st)
		local q = Isaac.Spawn(tp,vr,st,pos,Vector(0,0),nil):ToNPC()
		if ent.GetChampionColorIdx then q:Morph(tp,vr,st,ent:GetChampionColorIdx()) end
		if tg_mxhp then
			q.MaxHitPoints = tg_mxhp
			q.HitPoints = q.MaxHitPoints
		end
		if should_protect then q:AddEntityFlags(EntityFlag.FLAG_AMBUSH) end
		if specialwork then specialwork(q) end
		if info.data.special_work then info.data.special_work(q) end
	end
	if info.data.special then
		info.data.special(pos)
	end
end

function item.spawn_by_info(ent,info,should_protect,specialwork)
	if info == nil then return end
	if info.is_other then return end
	if info.data.should_delay then
		delay_buffer.addeffe(function(params)
			item.spawn_it_now(ent,info,should_protect,specialwork)
		end,{},5)
	else
		item.spawn_it_now(ent,info,should_protect,specialwork)
	end
end

local function change_mutable_enemy(ent)
	if ent.Type == 81 then ent.SpawnerType = 81 return end
	ent.SpawnerType = 10001
end

function item.check_and_add_ent(ent,lev)
	local name_info = item.check_data(ent)
	if name_info then
		local dir = item.get_morph_dir(name_info.i2)
		if #dir > 0 then
			local stag = {}
			local tot_wei = 0
			local sel = nil
			for u,v in pairs(dir) do
				if item.original_info[name_info.i1][v] and #(item.original_info[name_info.i1][v]) > 0 then
					for uu,vv in pairs(item.original_info[name_info.i1][v]) do
						if (vv.level or 1000) <= lev then
							table.insert(stag,#stag + 1,{wei = 1,sel = vv,})
							tot_wei = tot_wei + 1
						end
					end
				end
			end
			if #stag > 0 then
				tot_wei = math.random(tot_wei)
				for u,v in pairs(stag) do
					tot_wei = tot_wei - v.wei
					if tot_wei <= 0 then
						sel = v.sel
						break
					end
				end
				if sel then
					item.spawn_by_info({
						Type = get_multiple(sel.Type),
						Variant = get_multiple(sel.Variant),
						SubType = get_multiple(sel.SubType),
						Position = ent.Position,
					},{data = sel,},nil,function(ent) ent:GetData().checked_by_crisis_option_list_5 = true change_mutable_enemy(ent) end)
				end
			end
		end
	end
end

function item.check_and_morph_ent(ent,should_protect,params)
	params = params or {}
	local name_info = item.check_data(ent)
	if name_info and not auxi.check_if_any(name_info.data.only_spawn,ent) then
		local dir = item.get_morph_dir(name_info.i2)
		if #dir > 0 then
			local stag = {}
			local tot_wei = 0
			local sel = nil
			for u,v in pairs(dir) do
				if item.original_info[name_info.i1][v] and #(item.original_info[name_info.i1][v]) > 0 then
					table.insert(stag,#stag + 1,{wei = #item.original_info[name_info.i1][v],sel = item.original_info[name_info.i1][v],})
					tot_wei = tot_wei + #item.original_info[name_info.i1][v]
				end
			end
			tot_wei = math.random(tot_wei)
			for u,v in pairs(stag) do
				tot_wei = tot_wei - v.wei
				if tot_wei <= 0 then
					sel = v.sel
					break
				end
			end
			if sel then
				--print("morph:" .. ent.Type .. " " ..ent.Variant .. " " .. ent.SubType)
				if name_info.data.is_multi and ent.ParentNPC ~= nil and ent.ChildNPC ~= nil then return {should_kill = true,} end
				local target_info = sel[math.random(#sel)]
				--if get_multiple(target_info.Type) == 42 then print(ent.Type.." "..ent.Variant.." "..ent.SubType) end
				local mul = get_multiple(target_info.mul) or 1
				if mul == 0 then mul = 1 end
				local pos = ent.Position
				local tg_mxhp = ent.MaxHitPoints
				if params.ignore_hard then
					if target_info.fill_in or target_info.should_remakeroom or target_info.should_transmit or target_info.hard then target_info = {Type = 20,Variant = 0,SubType = {0,1,2,},is_multi = true,} end
				end
				if name_info.data.true_life then tg_mxhp = name_info.data.true_life end
				if target_info.pre_special_work then target_info.pre_special_work() end
				local signon = nil
				for i = 1,mul do
					if target_info.ignore_place then 
						local room = Game():GetRoom() 
						pos = room:GetRandomPosition(20) 
					end
					local tp = get_multiple(target_info.Type)
					local vr = get_multiple(target_info.Variant)
					local st = get_multiple(target_info.SubType)
					if target_info.special_morph then
						local mpif = target_info.special_morph
						tp = mpif.Type or tp
						vr = mpif.Variant or vr
						st = mpif.SubType or st
					end
					local q = Isaac.Spawn(tp,vr,st,pos,ent.Velocity,nil):ToNPC()
					if ent:IsChampion() then
						local champColor = ent:GetChampionColorIdx()
						q:MakeChampion(q.InitSeed, -1)
					end
					if target_info.keep_health ~= true then
						local alpha = params.health_alpha or 0.2
						q.MaxHitPoints = tg_mxhp * (1 - alpha) / mul + q.MaxHitPoints * alpha
						q.HitPoints = q.MaxHitPoints
					end
					if should_protect then q:AddEntityFlags(EntityFlag.FLAG_AMBUSH) end
					local d2 = q:GetData()
					d2.Crisis_option_4_checked = true
					d2.has_been_checked_by_Danger = true
					d2.Danger_morphed = true
					if params.special_work then params.special_work(q,i) end
					if target_info.special_work then target_info.special_work(q,i) end
					if signon == nil then signon = q end
				end
				if target_info.special then
					target_info.special(pos)
				end
				if name_info.data.myspecial then
					name_info.data.myspecial(ent)
				end
				return {should_kill = true,should_transmit = target_info.should_transmit,should_remakeroom = target_info.should_remakeroom,fill_in = target_info.fill_in,should_set_clear = target_info.should_set_clear,
				should_set_pit = target_info.should_set_pit,signon = signon,}
			end
		end
	end
	return nil
end

function item.check_and_keep_ent(ent,should_protect,params)
	local name_info = item.check_data(ent)
	if name_info and not auxi.check_if_any(name_info.data.only_spawn,ent) then
		local dir = item.get_morph_dir(name_info.i2)
		if #dir > 0 then
			local stag = {}
			local tot_wei = 0
			local sel = nil
			for u,v in pairs(dir) do
				if item.original_info[name_info.i1][v] and #(item.original_info[name_info.i1][v]) > 0 then
					table.insert(stag,#stag + 1,{wei = #item.original_info[name_info.i1][v],sel = item.original_info[name_info.i1][v],})
					tot_wei = tot_wei + #item.original_info[name_info.i1][v]
				end
			end
			tot_wei = math.random(tot_wei)
			for u,v in pairs(stag) do
				tot_wei = tot_wei - v.wei
				if tot_wei <= 0 then
					sel = v.sel
					break
				end
			end
			if sel then
				--print("morph:" .. ent.Type .. " " ..ent.Variant .. " " .. ent.SubType)
				if name_info.data.is_multi and ent.ParentNPC ~= nil then return {should_kill = true,} end
				local target_info = name_info
				local mul = get_multiple(target_info.mul) or 1
				if mul == 0 then mul = 1 end
				local pos = ent.Position
				local tg_mxhp = ent.MaxHitPoints
				local should_transmit = nil
				local should_remakeroom = nil
				if name_info.data.true_life then tg_mxhp = name_info.data.true_life end
				if target_info.pre_special_work then target_info.pre_special_work() end
				if target_info.should_remakeroom then should_remakeroom = true end
				if target_info.should_transmit then should_transmit = true end
				for i = 1,mul do
					if target_info.ignore_place then 
						local room = Game():GetRoom() 
						pos = room:GetRandomPosition(20) 
					end
					local q = Isaac.Spawn(get_multiple(target_info.Type),get_multiple(target_info.Variant),get_multiple(target_info.SubType),pos,ent.Velocity,nil):ToNPC()
					if ent:IsChampion() then
						local champColor = ent:GetChampionColorIdx()
						q:MakeChampion(q.InitSeed,-1)
					end
					--q.MaxHitPoints = tg_mxhp * 0.8 / mul + q.MaxHitPoints * 0.2
					--q.HitPoints = q.MaxHitPoints
					if should_protect then q:AddEntityFlags(EntityFlag.FLAG_AMBUSH) end
					local d2 = q:GetData()
					d2.Crisis_option_4_checked = true
					if target_info.special_work then target_info.special_work(q) end
				end
				if target_info.special then
					target_info.special(pos)
				end
				if name_info.data.myspecial then
					name_info.data.myspecial(ent)
				end
				return {should_kill = true,should_transmit = should_transmit,should_remakeroom = should_remakeroom,}
			end
		end
	end
	return nil
end

return item