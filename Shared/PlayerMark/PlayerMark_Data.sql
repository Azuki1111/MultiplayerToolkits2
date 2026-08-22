-- ============================================================================
-- 联机工具箱2.0 玩家标记数据表（条目4.8：房间内玩家标记显示，移植联机工具箱1.67 Update/PlayerData.sql）
-- 规范：本文件为条目4.8 玩家标记 SQL 数据（前端配置库 TPT_PlayerData），仅 FrontEnd 上下文注册。
--       数据自 1.67 PlayerData.sql 移植：全部类型（Admin/Normal/Honor/Ban）有效行，
--       去掉被注释行 / 过期行（Ban End_Date 已过，当前日期 2026-08） / 测试占位行（SteamID 111-666）。
--       重复 SteamID 行（Honor/Ban 覆盖 Normal）保留 1.67 插入顺序，语义与原作一致（INSERT OR REPLACE 后者覆盖前者）。
--       显示逻辑见 StagingRoom.lua 条目4.8 分区；ToolTipType 定义见 StagingRoom.xml ContextDefaults。
-- ============================================================================
CREATE TABLE IF NOT EXISTS TPT_PlayerData (
	SteamID TEXT NOT NULL,
	Name TEXT,
	Type TEXT NOT NULL,
	Icon TEXT,
	Desc TEXT,
	ToolTipType TEXT,
	Start_Date DATE,
	End_Date DATE,
	PRIMARY KEY(SteamID)
);
------------------------------------------------------------------------  管理员  ------------------------------------------------------------------------
INSERT OR REPLACE INTO TPT_PlayerData
		(SteamID,				Name,			Type,	Icon,													Desc,																	ToolTipType)
VALUES
		("76561198147378701",	"号码菌",		"Admin",	"[Icon_Host][COLOR_LIGHTBLUE]管理员",					"[ENDCOLOR][size_16]      [ICON_LIFESPAN][NEWLINE][Size_38][NEWLINE][Size_0][ICON_ICON_TECH_LASERS][NEWLINE][Size_20][ICON_ICON_ETHNICITY_ASIAN_UNIT_GIANT_DEATH_ROBOT_PORTRAIT]",	"Bermuda_Triangle"),
		("76561199120750841",	"千川白浪",		"Admin",	"[COLOR:ResCultureLabelCS]世界歧路[ENDCOLOR][ICON_GreatEngineer]主创",	"[ENDCOLOR][size_16]      [ICON_LIFESPAN][NEWLINE][Size_38][NEWLINE][Size_0][ICON_ICON_TECH_LASERS][NEWLINE][Size_20][ICON_ICON_ETHNICITY_ASIAN_UNIT_GIANT_DEATH_ROBOT_PORTRAIT]",	"Bermuda_Triangle");

-----------------------------------------------------------------------  玩家标记（图片 Tooltip）  -----------------------------------------------------------------------
INSERT OR REPLACE INTO TPT_PlayerData
		(SteamID,				Name,			Type,	Icon,												ToolTipType)
VALUES
		("76561199106342760",	"安德",			"Normal",	"[COLOR:ResGoldLabelCS][size_20]  安德神",			"AnDe_Desc"),
		("76561198106599147",	"花名",			"Normal",	"[Color:255,192,203][size_20]   花 名",				"HuaMing_Desc"),
		("76561198413532325",	"晴天",			"Normal",	"[Color:255,141,141]初见py",							"QingTian_Desc");

-----------------------------------------------------------------------  玩家标记（Icon + Desc）  -----------------------------------------------------------------------
INSERT OR REPLACE INTO TPT_PlayerData
		(SteamID,				Name,						Type,	Icon,																		Desc)
VALUES
		("76561198933798292",	"Rookie",					"Normal",	"[COLOR:ResGoldLabelCS][size_20]   沙 皇",									"[COLOR:ResGoldLabelCS][size_40]   沙 皇"),
		("76561198419573008",	"小北风",					"Normal",	"[COLOR:ResGoldLabelCS]爱要自在漂浮",										"[size_40]小北风"),
		("76561198100489219",	"sTon1",					"Normal",	"[ICON_RESOURCE_STONE][Color:255,215,0]石头神",								"[size_24]sTon1"),
		("76561199128594416",	"海芙约忒",					"Normal",	"[color:122,205,245][size_20]  海芙约忒",									"[color:95,216,251]大雨还在下，凌虚寒烟，碧水惊秋，水神泡芙[ICON_ICON_ETHNICITY_AFRICAN_UNIT_GREAT_ADMIRAL_PORTRAIT]"),
		("76561198847264780",	"leaf",						"Normal",	"[color:252,237,50][size_20]  海绵宝宝",										"[size_24]godleaf"),
		("76561198315901472",	"枫屿",						"Normal",	"[color:35,142,35][size_20]送高祖  枫 屿",									"[color:112,219,219][size_29]前排梁马军阀，后排灯塔祠堂[NEWLINE][ICON_ICON_BUILDING_GREAT_LIGHTHOUSE_FOW][ICON_ICON_BUILDING_TERRACOTTA_ARMY_FOW]看我马桶三连"),
		("76561199218437534",	"顾及",						"Normal",	"[ICON_Pillaged]",															NULL),
		("76561198255804454",	"罗马使用者",				"Normal",	"[ICON_SCIENCELARGE][COLOR_LIGHTBLUE]罗马使用者",							"[size_40][COLOR_LIGHTBLUE]帝国の余晖"),
		("76561199247468302",	"墨香",						"Normal",	"[ICON_Reports][COLOR:Happiness][size_18]墨香书挽风*",						"[COLOR:ResCultureLabelCS][size_29]              [Icon_Icon_Leader_Jadwiga]✿水逆退散✿[Icon_Icon_Leader_Catherine_De_Medici][newline]饿了就去吃喜欢的美食(*´◒`*)[newline]看腻了的照片就删掉ʕ´•ᴥ•`ʔ[newline]不开心的时候就睡一觉Zz(´-ω-`)[newline]遇见喜欢的人就表白Σ(〃°ω°〃)♥[newline]人生那么短暂哪有时间让你去犹豫"),
		("76561198406366362",	"红茶拿铁",					"Normal",	"[color:30,185,255] [icon_Science]红茶拿铁",								"[color:30,185,255][ICON_ICON_BUILDING_RESEARCH_LAB]偷个化学先"),
		("76561198404479942",	"谨言",						"Normal",	"[COLOR:ResGoldLabelCS]谨言",												"谨言"),
		("76561198283381092",	"雨(89)",					"Normal",	"[Icon_Host][Color:153,204,255]夜雨灬清晨",									"[COLOR:Red][size_24]萌新雨"),
		("76561199028289282",	"小羊",						"Normal",	"[Color:0,255,255][size_20]   羊  神",										"顶尖捞鱼"),
		("76561199027415352",	"菜猪",						"Normal",	"[COLOR:ResGoldLabelCS]菜猪宝宝[ICON_CULTURELARGE]",						"[COLOR:ResGoldLabelCS][Size_32]菜猪宝宝[ICON_ICON_NOTIFICATION_FILL_CIVIC_SLOT]"),
		("76561199136071905",	"无言",						"Normal",	"[COLOR:ResGoldLabelCS]前排要死后排睡觉",									"六言[ICON_ICON_CIVILIZATION_KUMASI]"),
		("76561198175919665",	"小B将",					"Normal",	"[COLOR:ResGoldLabelCS]地球最善の蒙古[ICON_ICON_UNIT_MONGOLIAN_KESHIG]",	"小B将"),
		("76561199355567131",	"海绵宝宝",					"Normal",	"[Icon_CapitalLarge][COLOR:ResGoldLabelCS]玩家标记",						"[COLOR:ResGoldLabelCS]萌新DUCK[ICON_ICON_DISTRICT_COMMERCIAL_HUB]"),
		("76561199235632871",	"BOOMJ",					"Normal",	"[ICON_DISTRICT_ACROPOLIS][color:255,110,199]抽象杯冠军",					"[size_40]《最抽象的选手》"),
		("76561198911409618",	"依雪千城",					"Normal",	"[Icon_ProductionLarge][Color:255,215,0]百锤校长",							"[size_3]            [ICON_ICON_GENERIC_GREAT_PERSON_INDIVIDUAL_SCIENTIST][size_20][NewLine][color:255,125,64][size_26]炼金术会所"),
		("76561198807503948",	"柴犬",						"Normal",	"[Icon_GoldLarge][COLOR:ResGoldLabelCS]21点圣手",							"前方队友挨3家打，后排偷逼爽完21点");

-----------------------------------------------------------------------  玩家标记（仅 Desc，Icon 走默认 UPDATE）  -----------------------------------------------------------------------
INSERT OR REPLACE INTO TPT_PlayerData
		(SteamID,				Name,								Type,	Desc)
VALUES
		("76561199158886392",	"浅樱陌语",							"Normal",	"适才相戏耳"),
		("76561199440457866",	"酌一杯南烛",							"Normal",	"一杯南烛酒"),
		("76561199079300536",	"Vanadium",							"Normal",	"CCB [ICON_GreatEngineer] 大工程师"),
		("76561198679823594",	"[ENDCOLOR][COLOR:ResGoldLabelCS]煎包[ENDCOLOR]",	"Normal",	"[ENDCOLOR][COLOR:ResGoldLabelCS]包...[ENDCOLOR]"),
		("76561199089944797",	"苦力怕",								"Normal",	"[color:255,145,227]啊啊啊苦力怕你是一个香香软软的小蛋糕"),
		("76561198090033513",	"红隼",									"Normal",	"谋玛雅40t200锤的传说"),
		("76561199225618632",	"素月墨羽/八域巡天使",					"Normal",	"奉剑正中央！"),
		("76561199519934139",	"手提玉剑斥千军，昔日锦鲤化金龙",		"Normal",	"马踏祁连山河动，兵起玄黄奈何天"),
		("76561199155440739",	"小情绪反反复复不婷",					"Normal",	"小情绪"),
		("76561199061699058",	"奶龙",									"Normal",	"奶龙"),
		("76561199024266950",	"辉洛",									"Normal",	"白皮恶霸"),
		("76561199159430892",	"小鱼快变强",							"Normal",	"[D.T.P] Knight"),
		("76561199216035192",	"清羽",									"Normal",	"牛马萌新"),
		("76561199206377175",	"韬光养晦",								"Normal",	"韬光养晦"),
		("76561198816054351",	"果冻",									"Normal",	"果冻"),
		("76561199518143843",	"烟水",									"Normal",	"烟火车牛马"),
		("76561199226874133",	"才玩10小时",							"Normal",	"寒酥"),
		("76561198302318532",	"烤肉冠军7",							"Normal",	"烤肉冠军"),
		("76561198321978362",	"感悟心理学完颜慧德",					"Normal",	"感悟心理学治疗师"),
		("76561199030479827",	"麻辣酱~",								"Normal",	"不会打架，别来打我！"),
		("76561198415854005",	"30t败走堪培拉",						"Normal",	"在皇家海军船坞服刑的袋鼠"),
		("76561199384411130",	"大拳萌香",								"Normal",	"大拳"),
		("76561199390266898",	"温迪",									"Normal",	"好想要求求了"),
		("76561198290144463",	"天天",									"Normal",	"天天"),
		("76561198329823789",	"雨村玲玲子是绝世寡狗",					"Normal",	"你看这条人，他好像个狗哦~"),
		("76561198929307244",	"白月光",								"Normal",	"歪嘴龙王一本"),
		("76561198407086813",	"冬眠",									"Normal",	"冬眠"),
		("76561198837666138",	"441",									"Normal",	"[ICON_ICON_CIVIC_MOBILIZATION]"),
		("76561199181310844",	"是只猪不是蜘蛛",						"Normal",	"i本既不黑也不白"),
		("76561198811341582",	"我无法对和纱说谎",						"Normal",	"黄油仙人"),
		("76561198093064225",	"超凶,会咬人!",							"Normal",	"真的是假的!"),
		("76561198327128522",	"wanBiceps",							"Normal",	"wanBiceps"),
		("76561198929311502",	"Vida",									"Normal",	"Mi Vida"),
		("76561198354992117",	"摸鱼的老杨",							"Normal",	"就在这立法典"),
		("76561199018385951",	"维尼",									"Normal",	"TeamPVP新万神殿已上架创意工坊，欢迎大佬订阅"),
		("76561198822641984",	"火玄",									"Normal",	"[ENDCOLOR][size_16]      [ICON_ARMY][NEWLINE][Size_42][NEWLINE][Size_20][ICON_ICON_ETHNICITY_ASIAN_UNIT_GIANT_DEATH_ROBOT_PORTRAIT]"),
		("76561198403277407",	"焰小夜",								"Normal",	"焰小夜"),
		("76561198139826388",	"forlin1130",							"Normal",	"[ICON_ICON_RESOURCE_WHALES][size_24]爱林[ICON_ICON_RESOURCE_COSMETICS][ICON_ICON_RESOURCE_COSMETICS]"),
		("76561198309611074",	"Magical",								"Normal",	"概念神代言人"),
		("76561198371554029",	"Imry02",								"Normal",	"Code:002"),
		("76561199213872953",	"小树林里的一夜",						"Normal",	"金牌厨师长"),
		("76561199141287462",	"此时之王非朕莫属",						"Normal",	"糕手古月"),
		("76561199433767421",	"不对小菊姐姐说谎",						"Normal",	"糕手萌新"),
		("76561198424583208",	"saber5211314",							"Normal",	"为什么要欺负可爱的苏苏"),
		("76561199288128084",	"针眼画师",								"Normal",	"小朱"),
		("76561198400127376",	"游戏之迷",								"Normal",	"什么文明都可以发酵"),
		("76561198809882660",	"Doubility",							"Normal",	" Σ(っ °Д °;)っ!!"),
		("76561199312702213",	"老超",									"Normal",	"[size_48][COLOR:ResGoldLabelCS]老超"),
		("76561199083867874",	"春日幻",								"Normal",	"发酵仔"),
		("76561198352190550",	"唐浪尘丶Triumph",						"Normal",	"嘤嘤嘤"),
		("76561198988544628",	"SSS",									"Normal",	"极致发育"),
		("76561199057762168",	"雌小猫好想被哥哥带避孕套顶到喷水",	"Normal",	"文明交际花~"),
		("76561198365253715",	"诺咿",									"Normal",	"[size_48]bilibili 诺咿a"),
		("76561199037457125",	"白色星空",								"Normal",	"[ICON_ICON_LEADER_LUDWIG]"),
		("76561199249204091",	"很可拷的小伙",							"Normal",	"我爱[icon_amenities]"),
		("76561199096403971",	"被窝秋裤",								"Normal",	"萌新导师"),
		("76561199435806376",	"天才美少女kkz",						"Normal",	"努努"),
		("76561199369391459",	"苝之梦",								"Normal",	"活不过一乔的梦梦"),
		("76561199114267670",	"honor",								"Normal",	"吸血鬼"),
		("76561198861778674",	"123丶kza",								"Normal",	"123丶kza"),
		("76561198231107016",	"诗槐远",								"Normal",	"槐南一梦"),
		("76561198308807554",	"抚泓 猎",								"Normal",	"[ICON_ICON_GREAT_PERSON_CLASS_PROPHET][NEWLINE][size_24]   猎门!"),
		("76561198333214466",	"Don''t eat cute cats",					"Normal",	"[ICON_ICON_LEADER_ELEANOR_FRANCE]"),
		("76561198972883036",	"铃铛",									"Normal",	"铃铛是个大笨蛋!"),
		("76561198385536824",	"Pyun",									"Normal",	"[ICON_ICON_LEADER_BARBAROSSA]"),
		("76561198113873022",	"贾文和真乱舞",							"Normal",	"[size_36]糕受!"),
		("76561198365905771",	"福西蛇喷手",							"Normal",	"2[ICON_Food]3[ICON_Production]5[ICON_Culture]"),
		("76561198866141956",	"小丑皮",								"Normal",	"[Icon_RESOURCE_CATTLE]指点大王[Icon_RESOURCE_HORSES]"),
		("76561199248713211",	"天亮亮兮战争",							"Normal",	"文明艺术家"),
		("76561198095083789",	"小裨将",								"Normal",	"[ICON_ICON_LEADER_VICTORIA_ALT]海底捞"),
		("76561199485108991",	"一周骗她久次",							"Normal",	"[size_24]下饭"),
		("76561198408502756",	"地烂就去睡觉了",						"Normal",	"长城YYDS"),
		("76561198799623036",	"苏小白",								"Normal",	"苏小白"),
		("76561198317624505",	"牛奶",									"Normal",	"[Icon_resource_cattle]"),
		("76561199074490787",	"入夜雪",								"Normal",	"入夜雪"),
		("76561199094524422",	"脑花花",								"Normal",	"[size_24][COLOR:ResGoldLabelCS]脑花花"),
		("76561198328986084",	"琥珀",									"Normal",	"世界第一可爱萌新"),
		("76561199426397928",	"红早",									"Normal",	"[ICON_ICON_GREAT_PERSON_CLASS_ARTIST][newline][size_24]大艺术家"),
		("76561199172305820",	"孤雏饮红茶",							"Normal",	"乐理车毕业生"),
		("76561198821529734",	"Wilgose",								"Normal",	"[ICON_ICON_UNIT_SCOUT_FOW][size_24]尾狗"),
		("76561198141029065",	"小零",									"Normal",	"笨蛋小零TAT"),
		("76561198127666611",	"Big Boss",								"Normal",	"总指挥“解放者”"),
		("76561198409730393",	"worfdog",								"Normal",	"保护我方最好的怯战蜥蜴"),
		("76561198330599085",	"我家的猫会后空翻哦",					"Normal",	"乐吃乐不饱"),
		("76561198980069344",	"炼铜术士mir",							"Normal",	"可爱の术士喵"),
		("76561198978644238",	"界马超超级莽",							"Normal",	"三板斧忠实信徒");

----------------------------------------------------------------------  荣誉标记（杯赛冠军）  -----------------------------------------------------------------------
INSERT OR REPLACE INTO TPT_PlayerData
		(SteamID,				Name,					Type,	Icon,													Desc)
VALUES
		("76561198334532538",	"Emrys",				"Honor",	"[COLOR:ResGoldLabelCS]巴巴里杯s1冠军",						"i龟 龟鸡铁粉"),
		("76561198077371164",	"乐理乐不清",				"Honor",	"[COLOR:ResGoldLabelCS]巴巴里杯s1冠军",						"团队之光"),
		("76561198988981542",	"Solarian",				"Honor",	"[COLOR:ResGoldLabelCS]巴巴里杯s1冠军",						"龟鸡神粉丝，i龟集合！"),
		("76561198972616242",	"若影",					"Honor",	"[COLOR:ResGoldLabelCS]巴巴里杯s1冠军",						"i龟 顶着伟大龟鸡神名字上场龟族族长龟面"),
		("76561198894543602",	"轨迹",					"Honor",	"[COLOR:ResGoldLabelCS]巴巴里杯s2冠军",						"[ICON_ICON_BUILDING_STATUE_OF_ZEUS_FOW]"),
		("76561198099893319",	"Lych4",				"Honor",	"[COLOR:ResGoldLabelCS]巴巴里杯s2冠军",						"[ICON_ICON_BUILDING_GRANARY] [ICON_ICON_UNIT_GREAT_PROPHET_PORTRAIT]"),
		("76561198366422842",	"大师兄",				"Honor",	"[COLOR:ResGoldLabelCS]巴巴里杯s2冠军",						"某不知名摸鱼练习生"),
		("76561198334532538",	"emrys",				"Honor",	"[COLOR:ResGoldLabelCS]巴巴里杯s2冠军",						"[ICON_ICON_GENERIC_GREAT_PERSON_INDIVIDUAL_GENERAL][newline][size_24]奢侈猎人"),
		("76561198123728330",	"long",					"Honor",	"[COLOR:ResGoldLabelCS]巴巴里杯s2冠军",						"[ICON_ICON_ETHNICITY_ASIAN_UNIT_SCOUT_PORTRAIT][newline]吸条狗"),
		("76561198809367750",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S3冠军",						"[COLOR:ResGoldLabelCS]炼金杯S3冠军"),
		("76561199017022070",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S3冠军",						"[COLOR:ResGoldLabelCS]炼金杯S3冠军"),
		("76561199227296580",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S3冠军",						"[COLOR:ResGoldLabelCS]炼金杯S3冠军"),
		("76561199080450585",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S3冠军",						"[COLOR:ResGoldLabelCS]炼金杯S3冠军"),
		("76561198139826388",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S3冠军",						"[COLOR:ResGoldLabelCS]炼金杯S3冠军"),
		("76561199388829573",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S3冠军",						"[COLOR:ResGoldLabelCS]炼金杯S3冠军"),
		("76561198401767142",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S3冠军",						"[COLOR:ResGoldLabelCS]炼金杯S3冠军"),
		("76561198406573670",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S3冠军",						"[COLOR:ResGoldLabelCS]炼金杯S3冠军"),
		("76561199379240252",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S3冠军",						"[COLOR:ResGoldLabelCS]炼金杯S3冠军"),
		("76561198819736435",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S3冠军",						"[COLOR:ResGoldLabelCS]炼金杯S3冠军"),
		("76561198348818200",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S3冠军",						"[COLOR:ResGoldLabelCS]炼金杯S3冠军"),
		("76561199218437534",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S3冠军",						"[COLOR:ResGoldLabelCS]炼金杯S3冠军"),
		("76561198811962485",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S3冠军",						"[COLOR:ResGoldLabelCS]炼金杯S3冠军"),
		("76561198284507703",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S3冠军",						"[COLOR:ResGoldLabelCS]炼金杯S3冠军"),
		("76561198141029065",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S3冠军",						"[COLOR:ResGoldLabelCS]炼金杯S3冠军"),
		("76561199236242885",	"art",					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S1冠军",						"[COLOR:ResGoldLabelCS]炼金杯S1冠军"),
		("76561198365104282",	"懒懒",					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S1冠军",						"[COLOR:ResGoldLabelCS]炼金杯S1冠军"),
		("76561198886829668",	"香草",					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S1冠军",						"[COLOR:ResGoldLabelCS]炼金杯S1冠军"),
		("76561198404333056",	"ox",					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S1冠军",						"[COLOR:ResGoldLabelCS]炼金杯S1冠军"),
		("76561199033867220",	"奇迹",					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S1冠军",						"[COLOR:ResGoldLabelCS]炼金杯S1冠军"),
		("76561198340211145",	"pink",					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S1冠军",						"[COLOR:ResGoldLabelCS]炼金杯S1冠军"),
		("76561198838993653",	"w",					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S1冠军",						"[COLOR:ResGoldLabelCS]炼金杯S1冠军"),
		("76561199101190384",	"三堂",					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S1冠军",						"[COLOR:ResGoldLabelCS]炼金杯S1冠军"),
		("76561198404724675",	"瞌睡",					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S1冠军",						"[COLOR:ResGoldLabelCS]炼金杯S1冠军"),
		("76561198854833069",	"大结",					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S1冠军",						"[COLOR:ResGoldLabelCS]炼金杯S1冠军"),
		("76561199547502014",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S4 FMVP",						"[COLOR:ResGoldLabelCS]炼金杯S4表现最佳选手"),
		("76561199094524422",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S4冠军",						"[COLOR:ResGoldLabelCS]炼金杯S4冠军"),
		("76561199562503518",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S4冠军",						"[COLOR:ResGoldLabelCS]炼金杯S4冠军"),
		("76561199186261993",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S4冠军",						"[COLOR:ResGoldLabelCS]炼金杯S4冠军"),
		("76561199128951068",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S4冠军",						"[COLOR:ResGoldLabelCS]炼金杯S4冠军"),
		("76561198904767438",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S4冠军",						"[COLOR:ResGoldLabelCS]炼金杯S4冠军"),
		("76561198422405484",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S4冠军",						"[COLOR:ResGoldLabelCS]炼金杯S4冠军"),
		("76561198398761864",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S4冠军",						"[COLOR:ResGoldLabelCS]炼金杯S4冠军"),
		("76561198972333643",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S4冠军",						"[COLOR:ResGoldLabelCS]炼金杯S4冠军"),
		("76561198823382836",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S4冠军",						"[COLOR:ResGoldLabelCS]炼金杯S4冠军"),
		("76561198277506780",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S4冠军",						"[COLOR:ResGoldLabelCS]炼金杯S4冠军"),
		("76561199137485442",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S4冠军",						"[COLOR:ResGoldLabelCS]炼金杯S4冠军"),
		("76561198113873022",	NULL,					"Honor",	"[COLOR:ResGoldLabelCS]炼金杯S4冠军",						"[COLOR:ResGoldLabelCS]炼金杯S4冠军");

-----------------------------------------------------------------------  黑名单（仅保留 End_Date 未过期，2024 及以前跳车/拔线记录已移除）  -----------------------------------------------------------------------
INSERT OR REPLACE INTO TPT_PlayerData
		(SteamID,				Name,			Type,	End_Date,				Icon,											Desc)
VALUES
		("76561198377320002",	"兔兔酱吖",		"Ban",	"2034-05-11",			"[Icon_Exclamation][COLOR:Red]警告：作弊开挂",	"兔兔酱吖:[NEWLINE]多次在多人联机中开挂作弊，使用恶意伪装的模组，增强自己所选文明，用恶意UI界面侵害其他玩家电脑。请拒绝与此玩家进行联机游戏，不要自动下载可疑模组。[NEWLINE][NEWLINE]作弊案例1:使用同名的魔女基础mod修改数据，使武僧价格变成40信仰。[NEWLINE][NEWLINE]作弊案例2:使用同名的工人劳动力助手模组，修改德国、加拿大、德川家康的能力，建造区域和建筑加速5倍，搓兵加速50倍，出生绑定资源。"),
		("76561198883038713",	"兔兔酱吖",		"Ban",	"2034-05-11",			"[Icon_Exclamation][COLOR:Red]警告：作弊开挂",	"兔兔酱吖:[NEWLINE]多次在多人联机中开挂作弊，使用恶意伪装的模组，增强自己所选文明，用恶意UI界面侵害其他玩家电脑。请拒绝与此玩家进行联机游戏，不要自动下载可疑模组。[NEWLINE][NEWLINE]作弊案例1:使用同名的魔女基础mod修改数据，使武僧价格变成40信仰。[NEWLINE][NEWLINE]作弊案例2:使用同名的工人劳动力助手模组，修改德国、加拿大、德川家康的能力，建造区域和建筑加速5倍，搓兵加速50倍，出生绑定资源。"),
		("76561198342826922",	"bak",				"Ban",	"2035-12-12",			"[Icon_Exclamation][COLOR:Red]警告：作弊开挂",	"作弊案例:使用战略透视外挂后拍照发到魔女群"),
		("76561198355149136",	"黑叔叔启动",		"Ban",	"2035-12-12",			"[Icon_Exclamation][COLOR:Red]警告：作弊开挂",	"使用外挂被抓现行"),
		("76561198448709984",	"船长巴基",			"Ban",	"2035-12-12",			"[Icon_Exclamation][COLOR:Red]警告：作弊开挂",	"使用外挂被抓现行"),
		("76561199083299610",	"Eclipse",			"Ban",	"2035-12-12",			"[Icon_Exclamation][COLOR:Red]警告：作弊开挂",	"使用外挂被抓现行"),
		("76561199236705243",	"静电之王",			"Ban",	"2035-12-12",			"[Icon_Exclamation][COLOR:Red]警告：作弊开挂",	"使用外挂被抓现行"),
		("76561199654482778",	"浓液",				"Ban",	"2035-12-12",			"[Icon_Exclamation][COLOR:Red]警告：作弊开挂",	"使用外挂被抓现行"),
		("76561198317296254",	"韩老魔元婴版",		"Ban",	"2036-06-07",			"[Icon_Exclamation][COLOR:Red]警告：作弊开挂",	"在多人联机中开挂作弊，使用恶意伪装的模组，增强自己所选文明，用恶意UI界面侵害其他玩家电脑。请拒绝与此玩家进行联机游戏，不要自动下载可疑模组。[NEWLINE][NEWLINE]作弊案例:使用同名的PVP 万神殿模组，将自己购买建筑和单位的价格下降至0元。"),
		("76561199663195811",	"两眼一争文明战争",	"Ban",	"2035-12-12",			"[Icon_Exclamation][COLOR:Red]警告：作弊开挂",	"使用外挂删除其他玩家的开拓者");

-----------------------------------------------------------------------  默认图标  -----------------------------------------------------------------------
UPDATE TPT_PlayerData
SET Icon = "[Icon_Host][COLOR_LIGHTBLUE]管理员"
WHERE Type = "Admin" AND Icon IS NULL;

UPDATE TPT_PlayerData
SET Icon = "[Icon_CapitalLarge][COLOR:ResGoldLabelCS]玩家标记"
WHERE Type = "Normal" AND Icon IS NULL;

UPDATE TPT_PlayerData
SET Icon = "[Icon_Army][COLOR:ResGoldLabelCS]荣誉标记"
WHERE Type = "Honor" AND Icon IS NULL;

UPDATE TPT_PlayerData
SET Icon = "[Icon_Exclamation]不良记录"
WHERE Type = "Ban" AND Icon IS NULL;
