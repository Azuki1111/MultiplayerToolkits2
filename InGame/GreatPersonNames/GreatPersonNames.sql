-- ============================================================================
-- 条目6：伟人名字更新（移植联机工具箱 1.67 GPN/GreatPersonNames.sql）
-- 机制：魔女环境检测——仅当 LocalizedText 中已存在魔女 mod 改写的伟人标记
-- （LOC_GREAT_PERSON_INDIVIDUAL_IMHOTEPI_NAME = '号码菌'）时才把比赛纪念伟人
-- 名字写入 zh_Hans_CN，非魔女环境不生效（保护原版伟人名字）。
-- LoadOrder 5000000 压后执行，确保在魔女 mod 之后覆盖。
-- ============================================================================
-----------------------------------------------------------------------  魔女环境下伟人修改  -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS TeamPVPGPN
(
    Tag  TEXT NOT NULL PRIMARY KEY,
    Text TEXT
);
INSERT OR
REPLACE INTO TeamPVPGPN(Tag, Text)
VALUES
-- 能见度
('LOC_GREAT_PERSON_INDIVIDUAL_MARY_KATHERINE_GODDARD_NAME', '766'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_MARY_KATHERINE_GODDARD_CHAPTER_HISTORY_PARA_1',
 '金牌成就[NEWLINE][NEWLINE]都说高处不胜寒，我766 便是这顶峰之巅——唯有真正的高手，才有资格见我一面。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_MARY_KATHERINE_GODDARD_CHAPTER_HISTORY_PARA_2',
 '身为顶尖能见度大商，我自带 “3力” 的强力增益，一旦入手，便能为你注入碾压级实力。要知道，能转到我的你，早已手握充裕资金与顶尖产能，实力早已远超他人。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_MARY_KATHERINE_GODDARD_CHAPTER_HISTORY_PARA_3',
 '此刻的你，就是对局里最靓的仔，胜负走向全由你定，快带着我，彻底杀死这场比赛！——炼金杯S2冠军766'),

-- 古典生产四段帆船，远程船加生产力海统
('LOC_GREAT_PERSON_INDIVIDUAL_THEMISTOCLES_NAME', '疾风与她皆为过客'),
('LOC_GREAT_PERSON_INDIVIDUAL_THEMISTOCLES_NAME_COLOR', '[COLOR:ResGoldLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_THEMISTOCLES_CHAPTER_HISTORY_PARA_1',
 '金牌成就[NEWLINE][NEWLINE]他的舰队，是战场上的隐刃。当世界的纷争从大陆蔓延至风暴与海洋，他便是那个按下终极静音键的人。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_THEMISTOCLES_CHAPTER_HISTORY_PARA_2',
 '当他麾下的舰队如风暴般掠过平原，你所能做的不是抵抗，而是思考——是臣服于这阵疾风，还是被它彻底撕碎。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_THEMISTOCLES_CHAPTER_HISTORY_PARA_3',
 '——炼金杯S2冠军疾风与她皆为过客'),

('LOC_GREAT_PERSON_INDIVIDUAL_JAMES_WATT_NAME', '疾风与她皆为过客'),
('LOC_GREAT_PERSON_INDIVIDUAL_JAMES_WATT_NAME_COLOR', '[COLOR:ResGoldLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_JAMES_WATT_CHAPTER_HISTORY_PARA_1',
 '金牌成就[NEWLINE][NEWLINE]炼金杯S2、S3双冠加冕！疾风与她皆为过客绝境封神，决赛bo3马戏团队对战城邦队先失一局，苏格兰前排57胸甲直击大哥位印度，一击定乾坤扳平比分；生死局前排波斯捞鱼土澳接连折戟，关键FK再锁印度拉开帝国分数，横扫夺冠！双冠耀世，选手卓绝，以硬实力铸就传奇！'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_JAMES_WATT_CHAPTER_HISTORY_PARA_2',
 '——炼金杯S3冠军疾风与她皆为过客'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_JAMES_WATT_CHAPTER_HISTORY_PARA_3',
 ' '),

-- 文艺复兴大军，生成射石炮
('LOC_GREAT_PERSON_INDIVIDUAL_GUSTAVUS_ADOLPHUS_NAME', '无敌'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_GUSTAVUS_ADOLPHUS_CHAPTER_HISTORY_PARA_1',
 '金牌成就[NEWLINE][NEWLINE]凡吾军旗所指，敌寇闻 “无敌” 二字便心胆俱裂，从无一场败绩。吾不仅是冲锋陷阵的先锋，更以肩扛团队防线，护兄弟们在后排安稳发育'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_GUSTAVUS_ADOLPHUS_CHAPTER_HISTORY_PARA_2',
 '—— 此身 “无敌”，既是名号，更是文艺复兴战场上无人能撼的铁血战魂！'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_GUSTAVUS_ADOLPHUS_CHAPTER_HISTORY_PARA_3',
 '——炼金杯S2冠军无敌'),

-- 古典随机3ulk大科
('LOC_GREAT_PERSON_INDIVIDUAL_ARYABHATA_NAME', '闪光皮皮'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ARYABHATA_CHAPTER_HISTORY_PARA_1',
 '金牌成就[NEWLINE][NEWLINE]闪光皮皮，古典的神，“马戏团” 的缔造者与炼金杯桂冠得主，以 “军传马” 战术在赛场留下传奇，更保有各项比赛前 51 回合下城最多的纪录。其智慧打破科研与军事的壁垒。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ARYABHATA_CHAPTER_HISTORY_PARA_2',
 ' —— 既深谙骑马、军事传统、古典大军对马普切文明的核心价值，唯一坚持平左点地脉加速科技砍马的选手。用远古科文神地的优势推动团队胜利，正如古典时代将理论转化为征服力量的先驱，他将赛场谋略化作文明进阶的动力，让科技光芒既照亮古典的神，也指引征途。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ARYABHATA_CHAPTER_HISTORY_PARA_3', '——炼金杯S2冠军闪光皮皮'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ARYABHATA_CHAPTER_HISTORY_PARA_4', ' '),

-- 文艺的157.5奇观大工
('LOC_GREAT_PERSON_INDIVIDUAL_FILIPPO_BRUNELLESCHI_NAME', '爱慕诶'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_FILIPPO_BRUNELLESCHI_CHAPTER_HISTORY_PARA_1',
 '金牌成就[NEWLINE][NEWLINE]没人会记住亚军是怎么输的，他们只会记住冠军如何赢。即使在过去多个比赛中与冠军失之交臂，依然不能动摇我取胜的决心。ma在炼金杯中操刀各种工业和发教文明多次以碾压之姿击败对手并最终取得胜利。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_FILIPPO_BRUNELLESCHI_CHAPTER_HISTORY_PARA_2',
 '无论对手的实力如何，终将淹没在我的工业洪流之下。我的能力不是锦上添花，而是你碾压级国力的证明。接下来要做的就是运用你从远古开始积累的庞大生产力，让对手逐渐被淹没在钢铁洪流之中！ 得胜已是定局，何必急功近利？'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_FILIPPO_BRUNELLESCHI_CHAPTER_HISTORY_PARA_3',
 '——炼金杯S2冠军爱慕诶'),

-- 古典大作家屈原
('LOC_GREAT_PERSON_INDIVIDUAL_QU_YUAN_NAME', '十三'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_QU_YUAN_CHAPTER_HISTORY_PARA_1',
 '金牌成就[NEWLINE][NEWLINE]从见到人就宣战的超雄萌新再到比赛中的中流砥柱，十三选手似乎总是在追逐着文明6pvp的最高峰，他可以是队伍里燃烧自我的前排打手，也可以是后排的种地大哥，凭借着对于学商文明的优秀理解，他总能在比赛中慢慢取得优势，但命运却对他开了个玩笑：先是在巴巴里杯S3中卫冕冠军却因决赛缺席而无缘伟人，再到炼金杯S1中再次登临决赛却不敌小分队而无缘伟人，但他没有放弃，而是磨练属于自己的种地与打架节奏，终于在炼金杯S2中和队友一路高歌凯旋卫冕冠军，拿下伟人。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_QU_YUAN_CHAPTER_HISTORY_PARA_2',
 '希望拿到大作家"十三"的你也可以和我一样，永不妥协，拿回本该属于你的荣誉。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_QU_YUAN_CHAPTER_HISTORY_PARA_3', '——炼金杯S2冠军十三'),

-- 中世纪比赛mod大将军岳飞
('LOC_GREAT_PERSON_INDIVIDUAL_NW_GENERAL_MEDIEVAL_2_NAME', 'Lancer'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_NW_GENERAL_MEDIEVAL_2_CHAPTER_HISTORY_PARA_1',
 '金牌成就[NEWLINE][NEWLINE]吾名 Lancer，乃中世纪纵横疆场的无敌大军。铁枪饮血踏破三十城，赤甲染霜斩过万千首。放眼天下，所谓强敌不过笼中鸡仔。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_NW_GENERAL_MEDIEVAL_2_CHAPTER_HISTORY_PARA_2',
 '—— 叉并非糯而是养精蓄锐，冲并非莽而是蓄力一击。此刻，正是冲锋之时!'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_NW_GENERAL_MEDIEVAL_2_CHAPTER_HISTORY_PARA_3',
 '——炼金杯S2冠军Lancer'),

('LOC_GREAT_PERSON_INDIVIDUAL_IBN_KHALDUN_NAME', '请赐教'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_IBN_KHALDUN_CHAPTER_HISTORY_PARA_1',
 '金牌成就[NEWLINE][NEWLINE]在炼金杯S2中夺得亚军[NEWLINE][NEWLINE]最初，他顶着Warr1ors的id在CHS中崭露头角。CHS以战斗肉搏而出名，作为一个萌新，刚开始玩就面临这样高强度的战斗是一个很大的挑战。但是在蟑螂鹅霸、URD孜孜不倦的教诲和二次元男孩不间断的11陪练下，他的军操思路得到了很大的提升。很快，同属于萌新的Warr1ors和瞌睡玩家脱颖而出，但随着CHS的没落，他们只能转战魔女。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_IBN_KHALDUN_CHAPTER_HISTORY_PARA_2',
 '随后，巴巴里杯正在如火如荼的进行。随着S1的结束，他见证了一批伟人的诞生，心里想：“伟人的冠名对于C6玩家是莫大的荣誉”，还幻想着有一天能有属于自己的伟人。后来，他和一些常玩的朋友一起，参加了巴巴里杯群赛。一次偶然的机会，他和初代小分队进行了生涯中第一把真正意义上的比赛。很可惜，上来就被踩了移民，最终这场比赛也以失败告终。从此之后，他便经常在小分队群里开车，群友也会亲切的喊他一声“W神”。在炼金杯S1(超人杯)开始之前，小分队的比赛成员遇到一位贵人-香草巧克力。香草神的玩法是异于常人的。当大家在执着于马内弹射公式时，香草的梁马斯基泰让小分队的人眼前一亮，开始了一波斯基泰大学习。大家秉持着野车太炸，群车有少爷，大家一起玩的态度参加了炼金杯S1。S1的结果大家也知道了，小分队凭借着打中世纪和文艺复兴强力一波的思路最终获得了冠军。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_IBN_KHALDUN_CHAPTER_HISTORY_PARA_3',
 '炼金杯S2开始后，Warr1ors改名请赐教，以一个学徒的姿态和比赛中的各路高手过招，从中吸取经验和教训。在队伍的安排下，请赐教凭借出色的军操和卓越的补发育能力，成为了小分队的T0前排。在为期半年的赛程中，他对单军梁马谒见厅的玩法有了自己的理解，这个玩法正如伊本·赫勒敦一样全方位地提升数据。慢慢，请赐教就变成了一个电脑极快，军操思路优秀，打种能力强的合格前排。最终，他和队友披巾斩棘，在炼金杯S2中夺得亚军。回想玩文明6PVP的两年，我已经从菜鸡萌新蜕变成了一个不折不扣的高手。时光荏苒，队里的队友也是不得不面对生活，打文也是终不似少年游。我经常能听到别人说，小分队的队内氛围是最好的。我作为队内的一份子，自然也能感受得到，十分荣幸能加入这样的小分队，愿你也有自己的“小分队”。C6的故事告一段落，感谢相遇！'),

('LOC_GREAT_PERSON_INDIVIDUAL_IBN_FADLAN_NAME', '香草'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_IBN_FADLAN_CHAPTER_HISTORY_PARA_1', '金牌成就'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_IBN_FADLAN_CHAPTER_HISTORY_PARA_2', '在炼金杯S2中夺得亚军'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_IBN_FADLAN_CHAPTER_HISTORY_PARA_3',
 '此香草非彼香草，全扩英雄池的香草是无敌的。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_IBN_FADLAN_CHAPTER_HISTORY_PARA_4', ' '),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_IBN_FADLAN_CHAPTER_HISTORY_PARA_5', ' '),

('LOC_GREAT_PERSON_INDIVIDUAL_ALBERT_EINSTEIN_NAME', 'Next'),
('LOC_GREAT_PERSON_INDIVIDUAL_ALBERT_EINSTEIN_NAME_COLOR', '[COLOR:ResGoldLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ALBERT_EINSTEIN_CHAPTER_HISTORY_PARA_1', '金牌成就'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ALBERT_EINSTEIN_CHAPTER_HISTORY_PARA_2',
 '在炼金杯S3中夺得亚军'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ALBERT_EINSTEIN_CHAPTER_HISTORY_PARA_3',
 '作为团队的核心学商之一，Next往往在比赛中注重科技和生产力的培养。在战场中他能给对方持续不断的压力，最后再打出漂亮的现代战争终结对手。其最爱的第五结社解锁宇航中心让比赛更加精彩。面对对手顽强的抵抗，宇航中心发射的卫星里，大商人随便说道：是时候该用那一招了！于是Next便向对手发射出了数以万计的核弹。作为炼金杯s3发射核弹数量最多的选手，当游戏进行到工业时代时，对手就应该时刻注意自己的国土安全和他的铀战略数量。他的铀战略减少时，对手市中心毁灭的倒计时便随之开启。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ALBERT_EINSTEIN_CHAPTER_HISTORY_PARA_4', ' '),

('LOC_GREAT_PERSON_INDIVIDUAL_HORATIO_NELSON_NAME', '小时光'),
('LOC_GREAT_PERSON_INDIVIDUAL_HORATIO_NELSON_NAME_COLOR', '[COLOR:ResGoldLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_HORATIO_NELSON_CHAPTER_HISTORY_PARA_1', '金牌成就'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_HORATIO_NELSON_CHAPTER_HISTORY_PARA_2',
 '在炼金杯S3中夺得亚军'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_HORATIO_NELSON_CHAPTER_HISTORY_PARA_3',
 '小时光从萌新走到炼金杯的决赛赛场，这段路，是三千小时，恰如20岁的纳尔逊成为了上尉，用勤奋与努力去打破桎梏，在瞬息万变的海战中洞悉全局，以无畏的勇气和战术独当一面。在无尽的海洋之上终将传颂着属于小时光自己的故事，根据船上的大商人随便回忆，小时光在决赛的最后一句话是“感谢上帝，我已履行了我的责任”。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_HORATIO_NELSON_CHAPTER_HISTORY_PARA_4', ' '),

('LOC_GREAT_PERSON_INDIVIDUAL_EUCLID_NAME', 'Melody'),
('LOC_GREAT_PERSON_INDIVIDUAL_EUCLID_NAME_COLOR', '[COLOR:ResGoldLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_EUCLID_CHAPTER_HISTORY_PARA_1', '金牌成就'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_EUCLID_CHAPTER_HISTORY_PARA_2', '在炼金杯S3中夺得冠军'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_EUCLID_CHAPTER_HISTORY_PARA_3',
 '终于明白你已成回忆，曾经那个看见高手会畏惧的自己。无论是炼金杯S2的FMVP，还是S3的不败神话，连续两届的百分百胜率冠军，或许早已在无声中证明。从S2半决奥斯曼20黑暗能见度坦克一拳光速击碎后排，到S3半决文印度法西斯现坦穿线北伐；从S2决赛发酵前排的稳定压制，到S3决赛德国的屹立不倒。文明的不断转变，却影响不了夯实的种田和合格的军操。 '),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_EUCLID_CHAPTER_HISTORY_PARA_4',
 '或许双冠是马戏团王朝落下的帷幕，又或许是我和队友书写新传奇的开始。这只队伍有766这种开天辟地时期的元老，也有我这种东西末期入坑的新星；有顶尖军操的前排耗材，也有傲视群雄的后排大哥。这个队伍及其多元，却又相当包容；看似吵吵闹闹，却又异常和谐；每个人都可以休息替换，但每人都不可获缺。前排失利时，后方会传来一句“我很强壮”让人安心；后方胶着时，前方会有“我能单杀”喜讯告知；平时嬉闹时的互相指责，在面对劲敌时全部化为安慰鼓励。或许，凝聚力，才是我们常胜的秘诀。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_EUCLID_CHAPTER_HISTORY_PARA_5',
 '无论是lancer还是Melody,都只是一个代号，我的足迹，早已刻画在文明6的每一场胜利之中。 '),

('LOC_GREAT_PERSON_INDIVIDUAL_AMINA_NAME', '蟹霆锋'),
('LOC_GREAT_PERSON_INDIVIDUAL_AMINA_NAME_COLOR', '[COLOR:ResGoldLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ANA_NZINGA_CHAPTER_HISTORY_PARA_1', '金牌成就'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ANA_NZINGA_CHAPTER_HISTORY_PARA_2', '在炼金杯S3中夺得冠军'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ANA_NZINGA_CHAPTER_HISTORY_PARA_3',
 '狂热为刃，绝境封神——蟹霆锋与印度文明的翻盘传奇。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ANA_NZINGA_CHAPTER_HISTORY_PARA_4',
 '《文明6》赛事的淘汰赛阶段，蟹霆锋用两场教科书级的超神发挥，书写了绝境翻盘的传奇。而这一切的背后，是他对印度文明深入骨髓的狂热——这份痴迷让他吃透了“达摩”机制的宜居度优势、“政事论”的闪击潜力，更让武印度与文印度在他手中成为逆转战局的利刃。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ANA_NZINGA_CHAPTER_HISTORY_PARA_5',
 '八强赛对阵鱼粉队，马戏团前期深陷劣势，队友全线被动。绝境之下，武印度后排横空出世，成为扭转战局的关键。蟹霆锋精准把控伟人机制，成功斩获766级核心伟人，瞬间激活文明战力。此后他开启狂暴收割模式：先斩鱼粉队“大哥”核心阵地，再力克挪威精锐，继而瓦解文印度的文化压制，一路势如破竹。坦克、直升机、现代坦克的兵种迭代无缝衔接，凭借碾压级的战力优势，在队友大劣势的绝境中独挽狂澜，硬生生将胜利收入囊中。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ANA_NZINGA_CHAPTER_HISTORY_PARA_6',
 '半决赛对阵神龙队的两场对决，堪称“地狱绘图”下的极限博弈。蟹霆锋依靠文印度特性降低埃塞俄比亚宜居，埃塞面临-6宜居度对+6宜居度的悬殊差距——对方城市产能拉满、发展稳健，而己方则因宜居劣势陷入产能停滞、战力下滑的困境。面对神龙队联合荷兰构建的分数优势，蟹霆锋果断联动挪威FORLIN1130形成合击成功FK荷兰，反超分数。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ANA_NZINGA_CHAPTER_HISTORY_PARA_7',
 '两场关键战役，蟹霆锋用精准的战略布局、极致的兵种协同与绝境中的抗压能力，诠释了《文明6》的竞技魅力，也让“超神翻盘”的传奇永远定格在赛事高光时刻。'),

('LOC_GREAT_PERSON_INDIVIDUAL_MURASAKI_SHIKIBU_NAME', 'niina'),
('LOC_GREAT_PERSON_INDIVIDUAL_MURASAKI_SHIKIBU_NAME_COLOR', '[COLOR:ResGoldLabelCS]'),
('LOC_GREATWORK_MURASAKI_1_NAME', '叉子王'),
('LOC_GREATWORK_MURASAKI_2_NAME', '阴天有雨'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_MURASAKI_SHIKIBU_CHAPTER_HISTORY_PARA_1', '金牌成就'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_MURASAKI_SHIKIBU_CHAPTER_HISTORY_PARA_1', '金牌成就'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_MURASAKI_SHIKIBU_CHAPTER_HISTORY_PARA_1', '金牌成就'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_MURASAKI_SHIKIBU_CHAPTER_HISTORY_PARA_2',
 '在炼金杯S3中夺得冠军'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_MURASAKI_SHIKIBU_CHAPTER_HISTORY_PARA_3',
 '萌新时期以Re、quiem的ID在各大群车历练，加入巴巴里群之后幸得一众高手指点后得到成长。在炼金杯S3八强赛中对战撅撅队操刀巴比伦，在中线协防被狗棒骚扰的西班牙，上线配合蟹霆锋和蛐蛐坦克一拳击碎武印度最后的防线。在对战神龙队的半决赛第一场中操刀苏格兰，凭借32T112锤的发育领先，在41T升级出雇佣兵马镫追猎出发逼迫武印度放弃发育全城出战象防守，而后凭借科文领先，步兵机枪将武印度的步兵工业炮消耗殆尽，随后升级大量坦克直升机北上守护蛐蛐，最后依靠第五结社，核弹洗地武印度，配合大优的蟹霆锋一举拿下比赛。决赛第一场不慎被狗棒一分，拼尽全力发射叉子未能守住。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_MURASAKI_SHIKIBU_CHAPTER_HISTORY_PARA_4',
 '酷爱剧院文明， 爱法金法瑞典绝症哥。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_MURASAKI_SHIKIBU_CHAPTER_HISTORY_PARA_5',
 '马戏团中坚力量，一切为了团队。'),

('LOC_GREAT_PERSON_INDIVIDUAL_LEIF_ERIKSON_NAME', 'Forlin1130'),
('LOC_GREAT_PERSON_INDIVIDUAL_LEIF_ERIKSON_NAME_COLOR', '[COLOR:ResGoldLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_LEIF_ERIKSON_CHAPTER_HISTORY_PARA_1', '金牌成就'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_LEIF_ERIKSON_CHAPTER_HISTORY_PARA_2',
 '在炼金杯S3中夺得冠军'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_LEIF_ERIKSON_CHAPTER_HISTORY_PARA_3',
 '我是Forlin，文明赛场上的海洋主宰者，当其他海统仍在海岸线徘徊时，我的舰队已如维京长船穿透迷雾，将海域化为进攻的棋盘，撕裂敌人的防线。海战不仅是力量的碰撞，更是节奏的碾压——每一回合的移动计算、每一次夹击角度的微调，都让敌人在溃败时才惊觉已陷入天罗地网。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_LEIF_ERIKSON_CHAPTER_HISTORY_PARA_4',
 '选择我，便是选择一场永不搁浅的征服。你的港口将诞生无畏的劫掠者，你的航标将插遍每一片海域。有我在，胜利不再依赖运气，而是彻底掌控海洋的必然结局。'),

('LOC_GREAT_PERSON_INDIVIDUAL_ZHOU_DAGUAN_NAME', '凉拌大象'),
('LOC_GREAT_PERSON_INDIVIDUAL_ZHOU_DAGUAN_NAME_COLOR', '[COLOR:ResGoldLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ZHOU_DAGUAN_CHAPTER_HISTORY_PARA_1', '金牌成就'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ZHOU_DAGUAN_CHAPTER_HISTORY_PARA_2', '在炼金杯S3中夺得冠军'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ZHOU_DAGUAN_CHAPTER_HISTORY_PARA_3',
 '大象作为一种常见的食材，其做法也是丰富多样，清蒸、红烧、白灼、拔丝，哪怕是预制大象都别有一番风味。而我最为偏爱的还是“凉拌大象”。“凉拌大象”作为一道家喻户晓的美食，让我们来一起学习是如何制作的吧！首先食材方面我推荐从马戏团中获取大象。在一位身着朴实衣装的奥特曼的压迫下，其中的大象大都是被驯服的象，长期的劳作使其肉质较为紧实且鲜美。马戏团的主场文明也正是大象培育基地，蟹老板丰富的大象培育经验也可以充分保证每一头大象的质量。制作方面与常见的凉拌并无过多区别，但为了保证口感，推荐先将大象放入冰箱冷藏。将大象放进冰箱只需三步……'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_ZHOU_DAGUAN_CHAPTER_HISTORY_PARA_4',
 '如若你在争夺银行大商过程中不幸拿到了我，就请像大象一样向心仪的城邦尽情狂奔吧，五t也好，十t也罢，城邦就在那里。虽然巴巴里杯充满遗憾，但炼金杯冠军也就在那里。虽然可能会被无数次踢回，但劲爆大象部落永不认输。'),

('LOC_GREAT_PERSON_INDIVIDUAL_DIMITRIE_CANTEMIR_NAME', '乐华杜晚向'),
('LOC_GREAT_PERSON_INDIVIDUAL_DIMITRIE_CANTEMIR_NAME_COLOR', '[COLOR:ResProductionLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_DIMITRIE_CANTEMIR_CHAPTER_HISTORY_PARA_1', '友谊需要人与人之间心理的接近，而游戏，恰恰提供了最佳土壤。对乐华杜晚向而言，文明六便是他的伊甸乐土。初入PVP，他经过妙妙屋群友funny、快车等人带领，初步理解了与PVE不同的节奏与博弈；又在沐雨meng群车上与至尊狗、沉默、dk交流，确定主玩海洋文明的定位。受孤独邀请，他与温如、颜玉书等临时组队参加随机文明5V5娱乐赛，意外闯入决赛，并以荷兰的核弹为漫长鏖战画下句点。那份紧张、协作与胜负的真实感，点燃了他对文明赛事的热情。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_DIMITRIE_CANTEMIR_CHAPTER_HISTORY_PARA_2', '24年夏，巴巴里杯S3战火再起。他被队长Amberrr邀请，与艾瑞莉娅、originalight、鹿栖于林等好友一同参赛。那时他们水平不高、经验寥寥，却因此拥有一种难得的纯粹：像初学者跃入水面前的深呼吸，紧张、兴奋虽笨拙而真诚。他们跌跌撞撞结束了小组赛，虽定格十六强，却在一次次失败与重整中磨出了默契与实力。中途他又被老朋友至尊狗、随便复活，最终止步季军。尽管未能参与决赛伟人角逐，但他也意识到：伟人头衔并非遥不可及。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_DIMITRIE_CANTEMIR_CHAPTER_HISTORY_PARA_3', '25年底，炼金杯高峰联赛S3再度点燃烽火。A哥组织铃木入间、炮姐、艾尔、dio一众新朋友组队体验比赛，却撞上巴巴里杯与前两届炼金杯推高圈内水平的浪潮。积分赛虽成功出线，但过程艰辛，友谊小船在这股巨浪中几近散架。于是芝芝姐与艾尔发动人脉，请来r136、轨迹两位超级高手助阵，A哥也请来S1伟人烂泥，轨迹又带来bbg高手喜多郁代。寄托蛆化神龙的愿景，神龙队正式出征。虽然队员们原本互不熟悉，但r神轨迹谦逊低调的风度，烂泥喜多风趣自然的性格，很快捏合了原本陌生的队伍。淘汰赛中众人各有发挥：r神苏格兰前线古典中世纪压制、坦克突破；轨迹高卢一抵二稳固中线，还控工程师援乐华日本海上一打二；烂泥凯撒深入敌阵却屹立不倒；喜多蒙古铁骑灵活穿插；艾尔祖鲁稳步推进，与r神埃塞合围歼灭敌军。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_DIMITRIE_CANTEMIR_CHAPTER_HISTORY_PARA_4', '半决赛对卫冕冠军马戏团，神龙队尽力仍未撕开防线。两场苦战后落入季军赛，无缘决赛。对乐华而言，这结果苦涩——那种"明明拼尽全力却仍差一步"的无奈久久回荡。但回望旅程，他又难掩满足：与高手并肩、在高压中成长，这些经历本身便是一笔沉甸甸的财富。季军赛开局不利，那些曾被认为"不够好"的队友完成了真正的蜕变。铃木入间操刀格鲁吉亚配合队友进取斯基泰，一雪前耻；艾瑞莉娅忽必烈骑士与怯薛歹千里袭后，完成包围歼灭，迫使对手投降。他们用自己的蜕变回应了所有质疑，也为神龙队添上了鳞片与光芒。回望炼金杯，仿佛翻开一本被汗水与欢笑浸染的日记。每一页都写着同一个主题——朋友。这段旅程没有冠军，没有神话，却有信任、有逆境中的援手、有复盘的坚持、有失败后仍愿并肩的勇气。战火终会熄灭，但友情的光不会。朋友或许不能改变命运，但他们能让命运不再孤单。得友如许，何其幸焉。谨以此纪念网络对岸每个善意的朋友。'),

('LOC_GREATWORK_CANTEMIR_1_NAME', '鹿栖于林'),
('LOC_GREATWORK_CANTEMIR_2_NAME', '艾瑞莉娅'),
('LOC_GREATWORK_CANTEMIR_3_NAME', '风息公园'),


('LOC_GREAT_PERSON_INDIVIDUAL_JOHANN_SEBASTIAN_BACH_NAME', '千川白浪'),
('LOC_GREAT_PERSON_INDIVIDUAL_JOHANN_SEBASTIAN_BACH_NAME_COLOR', '[COLOR:ResGoldLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_JOHANN_SEBASTIAN_BACH_CHAPTER_HISTORY_PARA_1', '金牌成就'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_JOHANN_SEBASTIAN_BACH_CHAPTER_HISTORY_PARA_2',
 '作为炼金系列模组的主创Modder，创作了众多魔女环境下的好评如潮的模组。他在未来又能创作出哪些模组？让我们拭目以待。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_JOHANN_SEBASTIAN_BACH_CHAPTER_HISTORY_PARA_3', ''),
('LOC_GREATWORK_BACH_1_NAME', '世界歧路'),
('LOC_GREATWORK_BACH_2_NAME', '枯木逢春'),

('LOC_GREAT_PERSON_INDIVIDUAL_NAPOLEON_BONAPARTE_NAME', '柯柯（STH）'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_NAPOLEON_BONAPARTE_CHAPTER_HISTORY_PARA_1', '金牌成就'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_NAPOLEON_BONAPARTE_CHAPTER_HISTORY_PARA_2',
 '2026S1武猪杯Solo赛中夺得亚军'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_NAPOLEON_BONAPARTE_CHAPTER_HISTORY_PARA_3',
 '淘汰赛：洞察对手因缺乏战略部署与远古弹射而导致的武备空虚，果断以军传马绕过前线城，拆掉敌方二分，随后游龙抢下移民，锁定胜局。[NEWLINE][NEWLINE]12强赛：使用捞鱼对阵宗教文明，虽错失军团大军，仍硬扛双星胸甲战力吸血鬼，凭借反坦克与机关枪的科技优势，以及议会提供的战略压制，最终劝降对手。3强赛：二分直取地图中线，压制沿海祖鲁的铺城空间，并以弩手海成功抵御双星特色单位的反扑，赢得关键对局。决赛：两度随机到捞鱼，发育空间被压缩殆尽，遗憾负于伟人forlin，斩获亚军。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_NAPOLEON_BONAPARTE_CHAPTER_HISTORY_PARA_4',
 ''),

-- 文艺复兴大商 乔凡尼·德·美第奇
('LOC_GREAT_PERSON_INDIVIDUAL_GIOVANNI_DE_MEDICI_NAME', 'Next'),
('LOC_GREAT_PERSON_INDIVIDUAL_GIOVANNI_DE_MEDICI_NAME_COLOR', '[COLOR:ResGoldLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_GIOVANNI_DE_MEDICI_CHAPTER_HISTORY_PARA_1', '金牌成就[NEWLINE][NEWLINE]铅云垂翼，万籁收声。战场的空气骤然拧紧，仿佛有一只看不见的手扼住了天地的咽喉。旌旗不再翻卷，而是像死去的羽翼般贴着旗杆战栗；马匹不安地刨着蹄下的焦土，发出压抑的低嘶——那不是恐惧，是整个空间在预感某种至高的秩序即将君临。气压一格格沉降，压得人骨缝发酸，连硝烟都被迫贴紧地面，匍匐如灰色的亡魂。当第一缕冷厉的风切开战场死寂的刹那，所有人都明白：这不是天气的暴怒，这是一个人的领域正在张开。他未曾现身，而风暴已成。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_GIOVANNI_DE_MEDICI_CHAPTER_HISTORY_PARA_2', '人称"行走的战术条例"的NEXT，披着炼金杯S4冠军与FMVP的双重荣光。其临阵搏杀之能，堪称艺术——微操繁密如绣花，攻势凌厉似雷霆。每一支军团的调动皆是精密咬合的齿轮，退可据险死守令敌寸步难进，进能分进合击将敌阵撕作齑粉，战场嗅觉敏锐到令人胆寒，仿佛总能提前三回合嗅到硝烟里的杀机。而他也总能从贫瘠中榨出盛世。最可怕的，是他那深不见底的大后期经验——当别人还在为胜利曙光挣扎时，他早已编织好必死的棋局。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_GIOVANNI_DE_MEDICI_CHAPTER_HISTORY_PARA_3', '如此伟人立于殿堂，足以让整个文明史为之屏息。——炼金杯S4冠军与FMVP NEXT'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_GIOVANNI_DE_MEDICI_CHAPTER_HISTORY_PARA_4', ' '),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_GIOVANNI_DE_MEDICI_CHAPTER_HISTORY_PARA_5', ' '),

-- 中世纪大作家 李白
('LOC_GREAT_PERSON_INDIVIDUAL_LI_BAI_NAME', '厂长'),
('LOC_GREAT_PERSON_INDIVIDUAL_LI_BAI_NAME_COLOR', '[COLOR:ResGoldLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_LI_BAI_CHAPTER_HISTORY_PARA_1', '金牌成就[NEWLINE][NEWLINE]诗仙李白，我国浪漫主义和理想主义的巅峰，有人奉之以神明，有人弃之如敝屣。敬仰与鄙夷，皆因世人从他的作品和人生里看见了理想中的自己，或心怀向往，或自惭形秽。正如我们本届冠军选手——厂长，决赛赛点局被困在半岛的克里，恰似被困在盛唐的诗仙。盛唐给了李白登临天下的见识与经历，让他能够恣意挥洒自己的才华，但盛唐又困住了他的洒脱，让他在虚无的仕途中沉浮挣扎。后排给了厂长克里畅快裸种的环境，但半岛阻碍了他移民的步伐，裸种环境必须拯救队友的责任也给了他压力，以及观众们挑剔的口诛笔伐。但厂长没有沉沦在环境给他编织的框架里，用最高的数据和最高的军力展现自己的实力，每回合41点石油消耗，正如他如蜡炬般燃烧的心神，没有向世人证明的虚荣，只有守护队友拿下胜利的渴望。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_LI_BAI_CHAPTER_HISTORY_PARA_2', '然而环境是困不住炽烈的性格的，谪仙挥毫时的针砭导致朝堂的不满，厂长平日的嬉笑怒骂也引来怨怼与仇寇，那口无遮拦的放肆言语背后，是为喧嚣浮尘所不容的赤子之心。他会在参赛遇到不公时硬刚赛事组，只为还社区环境的朗朗乾坤；他会因对方的违规行为做抗争，但却最尊重裁判的判罚；他会不停抱怨对方的掉线重载，但愿意为了比赛的公平进行彻夜不停尝试修档；他会批评不满游戏环境的不平衡，但也会认真思考建议和参与测试；他会在队伍队友受到中伤时挺身对线，但是也不放弃机会杯酒泯恩仇。他有时会让人讨厌和难过，但沉淀过后，你很难放弃对他的喜爱。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_LI_BAI_CHAPTER_HISTORY_PARA_3', '谪仙人终会回归天上，文明人也终会离开这片厮杀奋战、喜怒哀乐的游乐场。大作家不足以定义这二位的灵魂，希望以后的魔女玩家在招募他们的时候，能想起自己游玩文明6pvp的理想与初衷，像他们一样，在这个小众游戏的宝藏长河中，留下属于自己风格的极致色彩。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_LI_BAI_CHAPTER_HISTORY_PARA_4', ' '),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_LI_BAI_CHAPTER_HISTORY_PARA_5', ' '),

-- 现代大军 图帕克·阿马鲁
('LOC_GREAT_PERSON_INDIVIDUAL_TUPAC_AMARU_NAME', '听我说先别急'),
('LOC_GREAT_PERSON_INDIVIDUAL_TUPAC_AMARU_NAME_COLOR', '[COLOR:ResGoldLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_TUPAC_AMARU_CHAPTER_HISTORY_PARA_1', '金牌成就[NEWLINE][NEWLINE]听我说先别急选手走了很远的路走到这里，12进8阶段，他执掌阿兹特克，秋风扫落叶般毁灭对手，打醒了敌队的黄梁美梦；决赛第一把烂地抗压一打二直至现代遗憾落败，但正如同当年图帕克·阿马鲁一般，在绝境中积蓄力量、后发制人，南北马普切抗住敌方后排大哥压力等来海小眉选手的核弹一锤定音。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_TUPAC_AMARU_CHAPTER_HISTORY_PARA_2', '这一幕跟曦曦兮兮飘何其相似：一样是马普切，一样是南美洲反抗殖民者，一样是艰险环境中的等待。这是解放的鼓点，也是队伍的传承，或许最后一把孙子看着爷爷的首都妄想登上汗位，但请你再念一次我的ID：听我说先别急。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_TUPAC_AMARU_CHAPTER_HISTORY_PARA_3', ' '),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_TUPAC_AMARU_CHAPTER_HISTORY_PARA_4', ' '),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_TUPAC_AMARU_CHAPTER_HISTORY_PARA_5', ' '),

-- 文艺复兴海军上将 弗朗西斯·德瑞克
('LOC_GREAT_PERSON_INDIVIDUAL_FRANCIS_DRAKE_NAME', '宇佐美瑞希'),
('LOC_GREAT_PERSON_INDIVIDUAL_FRANCIS_DRAKE_NAME_COLOR', '[COLOR:ResGoldLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_FRANCIS_DRAKE_CHAPTER_HISTORY_PARA_1', '金牌成就[NEWLINE][NEWLINE]想在一个美好的晚上，和你一起打开一把文明6漫步于海岸边。时光荏苒，岁月如梭，在我的文明生涯中，认识了许多亦师亦友的伙伴。航海之路，结伴大于独行，捞鱼亦是如此，需要的是团队的付出。愿你我身上永伴良人，不再孤单。依旧宇佐美瑞希，依旧友利奈绪，依旧假屋合奏，依旧来两笼小笼包，依旧黄金海军船坞海军上将包龙王！'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_FRANCIS_DRAKE_CHAPTER_HISTORY_PARA_2', ' '),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_FRANCIS_DRAKE_CHAPTER_HISTORY_PARA_3', ' '),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_FRANCIS_DRAKE_CHAPTER_HISTORY_PARA_4', ' '),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_FRANCIS_DRAKE_CHAPTER_HISTORY_PARA_5', ' '),

-- 工业时代大工程师 古斯塔夫·埃菲尔
('LOC_GREAT_PERSON_INDIVIDUAL_GUSTAVE_EIFFEL_NAME', '星晨'),
('LOC_GREAT_PERSON_INDIVIDUAL_GUSTAVE_EIFFEL_NAME_COLOR', '[COLOR:ResGoldLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_GUSTAVE_EIFFEL_CHAPTER_HISTORY_PARA_1', '金牌成就[NEWLINE][NEWLINE]不要被那张极具迷惑性的可爱头像所欺骗，在深蓝海域中，星晨是令所有沿海文明战栗的梦魇。他完美诠释了什么是"最萌的脸，最狠的手"。作为炼金杯赛场上著名的"两栖掠夺者"，他的海军打法以凶残著称，不仅追求海权的绝对掌控，更擅长在惊涛骇浪中寻找对手防线的裂痕。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_GUSTAVE_EIFFEL_CHAPTER_HISTORY_PARA_2', '当他的帆船或私掠船集群在迷雾中现身时，那可爱的头像便成了死神的邀请函。然而，真正的恐怖并非来自于海上的炮火，而是他那令人窒息的海陆转换节奏。在某次关键的海战决胜时刻，星晨只是平静地操作着屏幕，在摧毁对方最后一支主力舰后，他轻描淡写地说道："既然海上已经没有对手，那就去岸上打个招呼吧。"'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_GUSTAVE_EIFFEL_CHAPTER_HISTORY_PARA_3', ' '),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_GUSTAVE_EIFFEL_CHAPTER_HISTORY_PARA_4', ' '),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_GUSTAVE_EIFFEL_CHAPTER_HISTORY_PARA_5', ' '),

-- 中世纪大科学家 奥马尔·海亚姆
('LOC_GREAT_PERSON_INDIVIDUAL_OMAR_KHAYYAM_NAME', '海小眉在我心中'),
('LOC_GREAT_PERSON_INDIVIDUAL_OMAR_KHAYYAM_NAME_COLOR', '[COLOR:ResGoldLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_OMAR_KHAYYAM_CHAPTER_HISTORY_PARA_1', '金牌成就[NEWLINE][NEWLINE]我于2020年的夏天入坑文明6，刚才开始玩的时候正如游戏中的远古时代，我在标速凶残的环境下茹毛饮血。当时的三板斧还是狗棒，弓棒和弓马，90t小马铁剑黑暗对砍，60t场上铺满弓棒都是常态。之后我了解到了国人基数最大的MOD——魔女MOD，由于在标速环境下练就的基本功，我在魔女环境下如鱼得水，也结交了许多一起玩得来的朋友。再后来我转战各种MOD，不断了解各种MOD的玩法以及各个MOD重叠的机制，同时也在各类比赛中都取得了不俗的成绩，唯独在魔女MOD收获甚微。我被人吹捧崇敬，也被人质疑暗讽，但我从未遗失对于登顶的坚定信念。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_OMAR_KHAYYAM_CHAPTER_HISTORY_PARA_2', '黑暗的工业时代来临，我结合我在各大MOD经验，完善我的打法，我坚信一定能够迎来完美的胜利。炼金杯S4机会来了，各路高手云集，名单上几乎没有一位现役高手缺席。很多人对我的印象可能是个发教高手，但是我在团队中是查缺补漏的全能螺丝钉，我永远会在团队需要时补上最关键的位置。精准的区域规划和铺城节奏，是产能溢出核弹洗地的根基；尽在把握的奇观争夺和特色的梁4玩法，是法西斯海量现代轰鸣声中的燃料。比赛中多次力挽狂澜：吃8个远古单位现代仍能规模步兵机枪反推的玛雅；法西斯军校产能火力全开的印度都是我的杰作。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_OMAR_KHAYYAM_CHAPTER_HISTORY_PARA_3', '让我最为得意的是决赛赛点局的林肯，神地7城商开，完美的工业规划，66t步兵70t工业化的数据压制，p51机械化无人机火箭炮的厚重。中期被ban工业的针对并没有影响我的节奏，榨干工业文明最后一丝产能，几十枚核弹洗地，最后取得飞天大科奠定胜局，看似惊险实则尽在掌握。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_OMAR_KHAYYAM_CHAPTER_HISTORY_PARA_4', '我坚信科技文化相辅相成，科技发达思想先进的帝国少了浪漫的诗人也只是一具理性的空壳，再美丽的花园城市也需要科技的武装。而得到我的帝国中传唱的诗歌如《鲁拜集》一般浪漫，制定的天文历法如雅拉里历一般精准，战士们如突厥人一般骁勇善战。这样的帝国如何能不让对手胆寒呢？'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_OMAR_KHAYYAM_CHAPTER_HISTORY_PARA_5', ' '),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_OMAR_KHAYYAM_CHAPTER_HISTORY_PARA_6', ' '),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_OMAR_KHAYYAM_CHAPTER_HISTORY_PARA_7', ' '),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_OMAR_KHAYYAM_CHAPTER_HISTORY_PARA_8', ' '),

-- 原子能时代海军上将 切斯特·尼米兹
('LOC_GREAT_PERSON_INDIVIDUAL_CHESTER_NIMITZ_NAME', '白夜'),
('LOC_GREAT_PERSON_INDIVIDUAL_CHESTER_NIMITZ_NAME_COLOR', '[COLOR:ResProductionLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_CHESTER_NIMITZ_CHAPTER_HISTORY_PARA_1', '不受赐福的捞鱼仔啊，来到王座，何事之有？"黄金"艾尔的利刃，马戏团的孪生子forlin1130与疾风与她皆为过客，123爱喝茶将军，司法官solarian，"粉皮恶霸"超凶，一群不知服从的叛徒，你们全是一丘之貉。为野心之火摆弄的掠夺者啊，在你们那愚昧的墓志铭上，刻上我"末代鱼王"白夜之名！'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_CHESTER_NIMITZ_CHAPTER_HISTORY_PARA_2', '曾经白夜不叫白夜，名唤忤逆，提到白夜，就不得不提到那个男人，是他一直鞭策白夜，并且作为白夜的负重，提出"印刷谁急谁带"的战略构思，他就是白夜群的上一任群主安德大帝，至今我们不知道安德手里有什么白夜的把柄，但是安德在任期间，白夜一直任劳任怨。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_CHESTER_NIMITZ_CHAPTER_HISTORY_PARA_3', '直到有一天，安德大帝宣布禅让位置于白夜，经过魔鬼训练的白夜终于展露头角，初来谁也不认识他的大名，只知道他作为安德二世，直到他不受拘束的横帆行遍每一处海洋，这个世界终于承认白夜的名讳，旗帜所到之处四海皆臣。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_CHESTER_NIMITZ_CHAPTER_HISTORY_PARA_4', '白夜的巅峰时期可以与任何捞鱼一战，然而失去了配重的白夜，终究耐不住时间的摧残，白夜不如之前那样锐利，但是他藏起羽毛变得沉稳，直到最后，白夜拿到季军，希望终有一天白夜能够再次扬帆。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_CHESTER_NIMITZ_CHAPTER_HISTORY_PARA_5', ' '),

-- 工业时代大科学家 查尔斯·达尔文
('LOC_GREAT_PERSON_INDIVIDUAL_CHARLES_DARWIN_NAME', '左旋废储'),
('LOC_GREAT_PERSON_INDIVIDUAL_CHARLES_DARWIN_NAME_COLOR', '[COLOR:ResFaithLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_CHARLES_DARWIN_CHAPTER_HISTORY_PARA_1', '赠素月（小令）[NEWLINE]魔女诗人竹离馆[NEWLINE]【题序】闻友人素月近来高中，甚是欣喜。忆先前之事，合此情此景，兴致盎然，有感而发，欣然命笔，盖成此词。[NEWLINE][NEWLINE]六月初，红日耀芳树。岸柳荷花水菖蒲，鸣蝉飞燕夏蟾蜍。生气满塘铺。[NEWLINE]志行笃，披荆斩棘路。今戴紫绶奏锣鼓，明冠桂环荣同部。鸿志踏云途。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_CHARLES_DARWIN_CHAPTER_HISTORY_PARA_2', ' '),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_CHARLES_DARWIN_CHAPTER_HISTORY_PARA_3', ' '),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_CHARLES_DARWIN_CHAPTER_HISTORY_PARA_4', ' '),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_CHARLES_DARWIN_CHAPTER_HISTORY_PARA_5', ' '),

-- 现代大军 玛丽娜·拉斯科娃
('LOC_GREAT_PERSON_INDIVIDUAL_MARINA_RASKOVA_NAME', '芭娜娜'),
('LOC_GREAT_PERSON_INDIVIDUAL_MARINA_RASKOVA_NAME_COLOR', '[COLOR:ResFaithLabelCS]'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_MARINA_RASKOVA_CHAPTER_HISTORY_PARA_1', '当你在地脉工批版本对位发教文明时，一定会想着凭地脉的科技打一波跨时代碾压，亦或吸血鬼的高战力自爆速杀。可当你面对的是芭娜娜时，一切都变了。曾经的芭娜娜只会马里，是不折不扣的英雄勺。可在不停地求教与实践中，他成为了黑羽亲传老秦，蟹神亲传高棉，随便亲传西班牙，r神亲传武周和疯不觉亲传印度埃塞。"除了阿拉伯太弱都能玩！"深不见底的文明池让对手无法针对，当你把所有ban位都倾泻到他身上时，他只会掏出一个又一个不同的发教文明。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_MARINA_RASKOVA_CHAPTER_HISTORY_PARA_2', '曾经的芭娜娜只会种田，到前排一碰就碎，可他遇到了回首已无言，也称小霸王。军操的混乱在与小霸王的一次次solo中不断改善。从一开始的被碾压到勉强抵抗再到平分秋色，小霸王慷慨地传授着自己的经验，锤炼出芭娜娜清晰又周密的战略思维。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_MARINA_RASKOVA_CHAPTER_HISTORY_PARA_3', '曾经的芭娜娜打到后期就迷茫无助，作为队友的大科学家next与大商人随便无私地倾囊相授，让芭娜娜在后期能力迅速提升。当你遇见芭娜娜操作的发教文明时，不要试图猜测他的打法。随便亲传谒见厅发教，泥鳅水神亲传大蠊，海小眉亲传梁四，大使馆战斗毛……不同的局面中，他总能在众多选项中精准地找到最优解。'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_MARINA_RASKOVA_CHAPTER_HISTORY_PARA_4', '在漫长的赛程中最常听到的就是r神、奇迹和香草传来的捷报，给予全队信心与力量。据芭娜娜所说，自己现在的一切离不开上述所有选手，他打心底尊敬和佩服他们。最后，送给所有逆版本而行的发教玩家："你们是真正的勇士！"'),
('LOC_PEDIA_GREATPEOPLE_PAGE_GREAT_PERSON_INDIVIDUAL_MARINA_RASKOVA_CHAPTER_HISTORY_PARA_5', ' '),

('LOC_GREATWORK_RELIC_6_NAME', 'forlin落花剑'),
('LOC_GREATWORK_RELIC_8_NAME', '马戏团小丑复活币'),
('LOC_GREATWORK_RELIC_17_NAME', '鱼虾蟹真好吃'),

('LOC_GREATWORK_CERVANTES_1_NAME', '天long八部之跑玛传'),
('LOC_PEDIA_BUILDINGS_PAGE_BUILDING_MONUMENT_CHAPTER_HISTORY_PARA_1',
 '此处位列的是一群在千百位玩家中脱颖而出的佼佼者，其名唯上帝所知。[NEWLINE][NEWLINE]三月以来，在压力下成功晋级淘汰赛的选手名称将碑刻千秋！[NEWLINE][NEWLINE]三届以来，在炼金联赛的历程中每一位璀璨的群星碑刻千秋！[NEWLINE][NEWLINE]由此上溯到叁仟捌佰贰拾天来，从那时起，为了文明六游戏的发展，每一位为社区展现淋漓尽致的实力、提供教学帮助新手的玩家将独步千古！'),
('LOC_PEDIA_BUILDINGS_PAGE_BUILDING_MONUMENT_CHAPTER_HISTORY_PARA_2',
 'CIVILIZATION VI TEAMPVP的纪念碑刻下他们每一位的ID：'),
('LOC_PEDIA_BUILDINGS_PAGE_BUILDING_MONUMENT_CHAPTER_HISTORY_PARA_3',
 'Next、闪光皮皮、心雨晴、hjju、小风车、竹离馆、天捷、若辰_hoshi、大大怪、暴怒的城邦、星海、Amberrrr共12位队长；[NEWLINE][NEWLINE]城邦队[NEWLINE]atolla、卡霍基亚、ASR、徴羽、生哥、小时光、兮兮飘、秋水、随便、一头撞上南墙、芭娜娜、FlyTree、佛都；[NEWLINE][NEWLINE]马戏团队[NEWLINE] 疾风与她皆为过客、766、十三、forlin1130、Melody、凉拌大象、niina、初夏、蛐蛐、Yuan、爱慕诶、Hepheastus、蟹霆锋、墨、小零；[NEWLINE][NEWLINE]塘朗山跳水队[NEWLINE] 绿井青子、御坂13567、P•P•P、妹说就是零卡、之傲鸡鸭基韵、一阵枫吹过；[NEWLINE][NEWLINE]味真族队[NEWLINE] 果冻、Rookie、白夜、minut、凯旋、海小眉在我心中、听我说先别急、烟火、别人吵架爱插嘴、小刘、雷米；[NEWLINE][NEWLINE]撅撅队[NEWLINE] intpret、假屋和奏、云、神山小小识、懒懒的懒、七彩菠萝小熊猫、聪明的国王、三味线、春雪落纱、10080、和一位、月以流明、晚曦、八域巡天使；[NEWLINE][NEWLINE]模组队[NEWLINE] 生活真难、RANKPID、红隼、安诺、水云墨客、ask12、上善若水、柯乐、择日飞仙、蓝田日暖玉生烟、cat、明月、阴天有雨、晴父、Kuonz1；[NEWLINE][NEWLINE]I喵队[NEWLINE] 贝贝、小野、丹蒂莱恩、打渔的鱼丸、soulboy、mikasa、烂泥、捞鱼能喵喵开嘛、吞吞吐吐飞、sunmmer、一本、苦力怕、卡霍基亚、沧澜、Billy[NEWLINE][NEWLINE]鱼粉队[NEWLINE] 香草巧克力、风雪铸剑、幽灵幽灵哟、一球、咸鱼大狮、CC星晨、木偶鱼、柳木诗梦天下第一、曹子修、gghh、zzd、黑羽、和泉妃爱、一样；[NEWLINE][NEWLINE]无内鬼队[NEWLINE] joker、凡渊、执笔仗剑风萧萧、雨若落叶、361、星痕无记、Arosy、域魍、核动力战列舰、孤独伤色、不会取名字、。。。。。。。；[NEWLINE][NEWLINE]相父队[NEWLINE] 羊神、kestrel、修文刚、悲伤的大象、蹲坑行为艺术家、愤怒的城邦、蓝色色色猫猫虫、云梦、长名字；[NEWLINE][NEWLINE]星海队[NEWLINE] 权利归花儿、从从从从、满船清梦压星河、贾老师、江西舰、飘来飘去、某不科学的龙、不会打架11122、雪乃天下无敌、失踪人口、山外的秋、鳟鱼、A黑鱼、耶路撒冷、.；[NEWLINE][NEWLINE]神龙队[NEWLINE]李叹、艾尔的利刃、乐华杜晚向、艾瑞莉娅、R136A1、烂泥、鹿栖于林、轨迹yyyy、喜多郁代的蛋包饭、铃木入间、芝芝芒芒、DioDioDioDioDio、乐理乐不清。[NEWLINE][NEWLINE]（排名不分先后）'),
('LOC_PEDIA_BUILDINGS_PAGE_BUILDING_MONUMENT_CHAPTER_HISTORY_PARA_4',
 '炼金联赛的伟人将在上述名字之间诞生，敬2025年10月至2026年1月每一位晋级到炼金杯决赛的选手[NEWLINE][NEWLINE]2025年12月19日题');



INSERT OR
REPLACE INTO LocalizedText(Tag, Language, Text)
SELECT Tag,
       'zh_Hans_CN',
       Text
FROM TeamPVPGPN
WHERE EXISTS (SELECT 1
              FROM LocalizedText
              WHERE Tag = 'LOC_GREAT_PERSON_INDIVIDUAL_IMHOTEPI_NAME'
                AND Text = '号码菌');


