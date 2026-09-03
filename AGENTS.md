# 联机工具箱 2.0 前端（Multiplayer Toolkits 2.0 FrontEnd）

## 项目概览

《文明6》（Sid Meier's Civilization VI）**前端（FrontEnd）模组**，作者 号码菌Synora。融合「联机工具箱 1.65」与 MPH（Multiplayer Helper）的前端功能并加以优化，主要面向多人联机准备房间体验。模组校验 / BP 功能改编自 MPH（MIT 协议 © 2024 BetterBalancedGame），部分功能参考联机工具箱 1.65 与乔尔定制mod。

- **不是常规软件工程**：没有构建配置、测试框架、CI/CD。
- 技术栈：Firaxis 模组体系 = `.modinfo` 清单 + 前端 Configuration 数据库 SQL/XML + UI 替换 Lua/XML + DDS 贴图。
- 部署方式：整个目录放在 `D:\文档\My Games\Sid Meier's Civilization VI\Mods\` 下即被游戏加载（本目录即模组本体）。`Core/`、`Tools/` 为预留空目录。
- 版本管理：git，提交信息格式为「条目X.Y：……」「条目X.Y修复：……」。

### Mod 清单

- Mod id：`00000000-7369-4685-ab5f-bf77bc22b54e`（规约：GUID 前 8 位为 0）
- `<Version>` 是模组版本一致性校验指纹，**结构性更新必须递增**（当前值见 modinfo，随条目提交同步递增）
- `AffectsSavedGames=0`，`CompatibleVersions=1.2,2.0`
- 前端功能全部走 FrontEndActions；InGameActions 注册游戏内功能（条目5 起逐条移植 1.65）与通用文本。

## 目录结构与功能模块

功能按 `计划.md` 的「条目」编号组织，代码与提交信息均用条目号追溯。**本表只留条目号、功能一句话与改动前必读的不变式；各条目详细设计与修复史 = 计划.md 对应条目段 + 各文件头修改留痕横幅 + git 提交信息**。

| 路径 | 内容 |
|------|------|
| `MultiplayerToolkits.modinfo` | 模组清单：全部 action 注册、LoadOrder 分层、`<Files>` 文件登记 |
| `计划.md` | 前端设计计划与开发规范——**各条目详细设计与修复史的出处**，改动规约时需同步更新 |
| `FrontEnd/Config/Config_Base.xml` | 条目2：联机常用游戏设置预设（无蛮族/回合60秒/允许重复文明领袖/「禁用领袖池」） |
| `FrontEnd/Config/Config_Disaster.sql` | 条目2：灾害强度下限 0→-1（完全无灾害），LoadOrder 99999 强制后置 |
| `FrontEnd/UI/Options/Options.xml` | 条目1：整文件同名覆盖原版，唯一改动 LAN 玩家名 MaxLength 22→45 |
| `FrontEnd/UI/StagingRoom/StagingRoom.lua`（~6300行） | 条目3 核心：同名覆盖原版准备房间脚本。末尾按条目分区（3.2 快捷开关AI / 3.3 快捷分队 / 3.4 房主权限提升改他人队伍领袖 / 3.5 更新公告 / 3.6 广告轮播 / 3.7 ping 常驻（内联覆盖原版 UpdateNetConnectionIcon）/ 3.8 移除玩家入槽位下拉框 / 4.1 mod 版本校验 / 4.2 非官方模组清单 / 4.3 序列化存储内联 / 4.4 玩家标记管理（条目4.9 房间玩家页签：左列双页签「存储标签/房间玩家」，房间页实时枚举当前在房真人 SS_TAKEN/SS_OBSERVER+IsHuman 排除自己，不存历史零存储——与游内条目11 快照版唯一差异；三落盘回调+Open+三事件订阅刷新） / 4.5+4.6 图标贴图查看器（单面板双页签）/ 4.7 进房自动更新工坊mod / 4.8 房间内标记显示）。**规约：分区一律 do...end 包裹（寄存器上限），新增分区必须沿用；3.8 改列数/槽位类型前先读分区注释（NUM_COLUMNS 5→4、g_slotTypeData kickOption 哨兵项）** |
| `FrontEnd/UI/StagingRoom/StagingRoom.xml` | 条目3：同名覆盖原版准备房间布局（StatusLabel TruncateWidth=180 截断） |
| `FrontEnd/UI/AdvancedSetup/AdvancedSetup.lua` | 单人高级设置替换：minPlayers 2→1、允许移除全部 AI、1 人开局 |
| `Shared/` | 双环境共享：`MPT_Serialize.lua` 序列化；`MPT_DataStorage.lua` 统一多表本地读写（`MPT_Storage_LoadAll/GetTable/SaveTables` 三 API，单一 ModGroup 组名承载、组内按表名分键、调用方零 merge）。**前端实际承载 = StagingRoom.lua 末尾「条目4.3预备」内联副本（引擎 include 缺陷，见技能库 empty-context.md），两副本改动必须双向同步**。`PlayerMark/` 为标记共享数据（当前仅前端消费） |
| `FrontEnd/Text/` | 通用本地化文本（每语言一个文件） |
| `FrontEnd/Changelog/`、`FrontEnd/Ads/` | 条目3.5 更新公告（`MPT_Changelog` 表）/ 条目3.6 广告轮播（`MPT_Ads` 表 + DDS），各带专属文本 |
| `FrontEnd/ModCheck/`、`FrontEnd/ModList/` | 条目4.1 模组校验（`MPT_ModCheck` 注册表，mod 自我登记 modId）/ 条目4.2 非官方模组清单（数据走运行时 Modding API），各带专属文本 |
| `Shared/PlayerMark/` | 条目4.4/4.8 玩家标记：专属文本 + `TPT_PlayerData` 数据表（`PlayerMark_Data.sql`）+ 3 张标记 DDS |
| `FrontEnd/IconViewer/`、`FrontEnd/TextureViewer/` | 条目4.5 图标查看器（`MPT_IconCollection` 5056 图标）/ 条目4.6 贴图查看器（`MPT_TextureCollection` 5017 行），各带专属文本 |
| `InGame/RevealMapCorners/` | 条目5 显示地图角落（1.65 RMC）：建两个极地真实地图钉撑开小地图世界矩形（小地图矩形只认引擎数据，UI 自制实例无效）；副作用留两个可见 pin |
| `InGame/GreatPersonNames/` | 条目6 伟人名字更新（1.65 GPN）：魔女环境检测后写入纪念名字，LoadOrder 5000000 压后覆盖，非魔女环境保护原版 |
| `InGame/EndGameMenu/` | 条目7 战败后观战按钮（1.65 EGM）：整文件同名覆盖 + 通配 include 注入；修复战败画面反复弹出（SetHide 致原版防重入守卫失效） |
| `InGame/WorldTracker/` | 条目8 快捷操作面板：空 Context + ChangeParent 挂 WorldTracker.PanelStack，展开区「投降」「重新开始」「玩家标记」「设置」+ 投票区；「重新开始」响应 TODO |
| `InGame/SurrenderVote/` | 条目8续 团队投降投票（Gameplay 侧）：AddGameplayScripts 注册，EXECUTE_SCRIPT 收 UI 指令，票数 ≥ 半数 → 该队城市全部叛变自由城（自定义战败：只写 Game:SetProperty，不动引擎判负）；每时代每队一次 |
| `InGame/TopPanelExt/` | 条目9 顶部面板扩展（1.65 TPE）：ReplaceUIScript 覆盖，追加食物/生产力/人口/奢侈品统计与战略资源队友清单 |
| `InGame/DealRestriction/` | 条目10 交易与外交限制（1.65 DDV 整模块）：交易四模式/无友谊默认开/和解三模式；`MPT_TradeRules.lua` 统一解析器（条目9/10 两上下文 include 共用）；SQL 经 ActionCriteria（ConfigurationValueMatches）条件执行 = 本 mod criteria 首例；参数与 DealView 导入门控 Disable_MPH（ModInUse inverse，防 MPH 同名 Parameters 主键冲突） |
| `InGame/PlayerMark/` | 条目11 游戏内玩家标记面板：include Shared/MPT_DataStorage.lua 与前端同一份存档互通；QuickPanel 按钮打开 |
| `InGame/ForcedEndTurn/` | 条目12 强制结束回合按钮（1.65 FEB）：ActionPanel 右下角按钮左键强制结束回合（ACTION_ENDTURN REASON="UserForced"），右键 LuaEvents.ForcedEndTurn 预留；显隐由设置面板 MPT_Settings_Toggle 广播控制 |
| `InGame/SettingsPanel/` | 条目12 游戏内设置面板：**全 mod 游戏内设置的统一收编点**（MPT_Settings 参数表；新设置 = 加行 + MPT_Settings_Toggle 广播，条目16/19/20/22/24/25 均此模式）。规约：ParameterId 沿用 1.65 原 key（同装幂等共享）；面板开关事件 MPT_SettingsPanel_Toggle 与参数广播 MPT_Settings_Toggle 必须分离（共用会自关闭）；点击复选框不落盘仅关闭时保存；存档走条目4.3 多表存储（表名 = ParameterId） |
| `InGame/AutoUpdate/` | 条目13 游戏内自动更新（1.65 Update）：空 Context 同名 Lua 自动执行；进局检查已启用的非官方工坊 mod 更新 + EnsureEnabled 保本 mod 启用；退主菜单按 SubscriptionId 触发本 mod 工坊更新 |
| `InGame/TechCivicProgress/` | 条目14 真实科文进度（1.65 TCP）：`TechAndCivicSupport.lua` 同名覆盖共享脚本（被 7 个 context include，只改数据层 GetResearchData/GetCivicData，Chooser 自动生效）+ 两树 MPT 版 include 探测官方最高版本（Exp2→Exp1→Base）后覆盖 GetCurrentData/PopulateNode。**`MPT_EngineBoost` 引擎精确科文预估定点链（反编译验证）供条目24 等 include 复用** |
| `InGame/TeamVisibleResources/` | 条目15 队友资源可见性（1.65 STR）：ReplaceUIScript+ImportFiles 双注册模式首例；迷雾格显示队友已解锁资源图标；外部刷新 LuaEvents.MPT_WorldViewIcon_Rebuild |
| `InGame/DisableMapPins/` | 条目16 禁用地图钉（1.65 RMP）：高级选项开关 `CPL_NO_PINS`（沿用 1.65 名）；空壳替换 MapPinListPanel（联机卡顿元凶，**同名覆盖文件名必须保持原名**）；三个 InGame action 由 criteria 门控（不勾选零改动） |
| `InGame/InstantFoundCity/` | 条目17 建立城市免确认（1.65 RCT）：ReplaceUIScript 覆盖 UnitPanel，文件内重建原版 include 链（BSM→XP2→XP1→Base，命中 Initialize 即 break）后重定义回调；**原版回调闭包点击时才解析全局名，函数名保持原名不可 MPT 化** |
| `InGame/CityBannerRefresh/` | 条目18 城市横幅刷新（1.65 PCF）：文件名前缀走原版通配 include 钩子进同上下文（仅 ImportFiles 无 LuaContext）；市民变动单城刷新 + 公民自动重排；**单订阅调度器 + UI.GetElapsedTime 真实时钟**（已沉淀技能库 lua-advanced-patterns.md） |
| `InGame/NotificationClear/` | 条目19 清理通知按钮（1.65 NOC）：通配 include 钩子链式覆写通知增删；按钮懒创建天然恒居栈底；**计数对账（Reconcile）单一事实**堵五处漏减；开关收编条目12 |
| `InGame/SmartTurnTimer/` | 条目20 智能回合计时器（1.65 TimerPro + NHK 热键按钮）：房主按半数真人回合末用时 PID 平衡 TURN_TIMER_TIME 广播全房 + 宣战/掉线/城邦自动加时 + 投票 120s + 聊天指令 p+/p+++/p-（仅房主监听）+ P++/P-- 按钮 + ]/[ 热键（InputActions 前后端各注册一次）。MPT_TIMER_MODE（OFF/SMART/TIERED）与 MPT_TIMER_CHAT 两 Game 参数**仅 FE 注册**；TIERED 曲线 = `SmartTurnTimer_Tiers.sql` 建表（**仅 IG UpdateDatabase**），改 VALUES 行即自定义曲线；首回合强制 STANDARD = 回合开始事件驱动幂等初始化（已沉淀技能库）；**与 1.65 计时器互相拉扯，勿同开** |
| `InGame/ExtendedPolicyCards/` | 条目21 政策卡收益显示（1.65 EPC，RMA 引擎 MPT_ 改名整携）：RMA 空 Context 自动执行（ExposedMembers.RMA 跨上下文调用）+ GovernmentScreen 整文件覆盖；MPT 文本行通道覆盖 90 种 EffectType（引擎原 31 种）；显示 20 种收敛（MPT_KnownEffects 静默）+ 生产族/资源五类实际计算；三层防御（RMA 调用 pcall 化/控件 nil 防御/动画帧实例空洞守卫）。**规约：迁移式重构必须 grep 验证旧注册清零；改动后 luaparser 剥标注自检 + 游戏 Lua.log 实测** |
| `InGame/BetterTradeScreen/` | 条目22 商路界面增强（1.65 BTS）：商路总览/目的地选择/商人传送三面板 + `TradeSupport.lua` 共享库（**文件名必须原名**，被两面板按名 include）；核心修复「收益不及时刷新」= Open() 即清缓存 + 回合内变更事件失效（政策/建筑/宣战议和等，事件名均经原版 UI 验证存在）；4 个 BTS 子选项不开放配置（条目22调整用户裁决，硬编码 1.65 BTS_Settings.sql 默认值：近似路径关/排序序号关/全部路径开/选中显示路径开，勿再找开关）；文本仅 IG 注册（消费侧注册先例） |
| `InGame/BetterCityStates/` | 条目23 城邦界面增强（1.65 BCS 四处魔改 + BSM 观察者补丁并入）：`CityStates_MPT.lua` = 原版 Base+XP1+XP2 压平合并体 ReplaceUIScript（压过 1.65 两套注册与 BSM 9999）；MPT_IsSpectator 读 BSM SPEC_NUM/SPEC_ID_k 属性单文件兼容（**BSM 观察者生态协议已沉淀技能库 patterns/workshop-cross-domain-patterns.md**；diff 核实不采纳 BSM 无效/回归改动） |
| `InGame/DiplomacyRibbonExt/` | 条目24 外交丝带扩展（1.65 DPR fork + BSM 观察者逻辑并入 + 条目14 精确科文仪表）：DiplomacyRibbon/WorldRankings 两上下文各 ReplaceUIScript+ImportFiles；**XML 组级显隐规约：分组容器必须用 Stack 嵌套 Stack（ForgeUI Container 不参与 Stack 布局），子控件一律不带 Hidden="1"**（父组隐藏即整组不可见，子控件自带标记会致组显示后仍不可见）；**动态 tooltip 性能规约 = 构建按数据身份去重复用实例栈 + CalculateSize/ReprocessAnchoring 收缩外框**（InstanceManager 回收仅隐藏不销毁）；观察者局五连修复（隐形热区遮挡点击/UTF-8 字节截断乱码等，已沉淀技能库案例 61/62；BSM GAP 延迟协议依赖 1.65 MPH 已剔除）；观察者局第二轮五连修复：①分数视图非队友军力被披露门槛隐藏——UpdateStatValues 16 处 Model 门槛加 bGodView 旁路（bspec_loc 即全知，观察者无外交渠道拿不到能见度等级）②产出视图毛产 Cities_Prod 与生产力总量同 API 恒等值重复行——移出视图只留毛粮，两行补 ToolTip ③核弹拆 [NEWLINE] 两行防 61px 截断、数字右置（icon 左数字右对齐全列行式）④Eras 组 StackPadding 3→8 防 Housing/Citizen 大图标互侵 + Spec_Cities 去空格紧凑⑤外交能见度加第四档「默认」（Model 3）=标准基础上军力恒显示；WorldRankings 情报摘要按外交能见度设置门控（条目24优化，用户裁决）——本地观察者全可见（原版行为）；标准=军力仅队友、科技/文化/信仰全公开；默认（Model 3）=全可见；团队=非队友按聚合最高能见度分级（科技/文化/信仰≥1、军力≥3）；公开=全可见；分数与决胜排序恒真实值（胜利进度不隐藏）。原 DPR 无条件隐藏三处全部还原（军力 GetScore 恒-1→真实 GetMilitaryStrengthWithoutTreasury、两处 SecondTiebreakSummary 拼接），改摘要串门控：MPT_IsIntelVisible 按决胜类型映射类目（CONQUEST→军力/TECHNOLOGY→科技/CULTURE→文化/RELIGIOUS→信仰，缺省=分数恒可见），隐藏=空串走消费端既有 ~= "" 检查自动跳行；本上下文与 DiplomacyRibbon 互为独立 Lua 状态，Model/能见度聚合自建（DPR RefreshAccessLevel 语义 GetVisibilityOn 自身+存活队友取最高、队友/自己恒4）；参数/热键沿用 1.65 原 key；条目24：领袖头像 Tooltip 换自定义 ToolTipType MPT_LeaderInfoTooltip（用户裁决，结构/样式参照 DiplomacyActionView 默认面板：DiplomacyCivHeaderLarge 头两行/FontFlair14 区头用原版 LOC_LOADING_FEATURES_ABILITIES/Line 分隔线/DawnText 描述/CircleRim40 圈图标行、能力行无图标顶格，金色 RowStats 属性行沿用 GetPreText）——UpdateIcon 包装（BASE_LeaderIcon_UpdateIcon）在 Portrait 原版字符串 Tooltip 之后挂类型+回调（类型优先），悬停按 playerID|相遇态 去重，未遇见/无本地玩家口径与原 GetToolTipString 一致，顺手修复 GetPreCT [ENDCOLORE] 笔；条目24：领袖富 Tooltip 二轮重构仿准备房间领袖详情面板（原版 AdvancedSetup.xml CivToolTip 实例族 + PlayerSetupLogic.lua PopulateLeaderTooltip L833-878 取证）——EnhancedToolTip 底板 + 居中区头（HeaderInstance 原样 DivHeader+FontFlair18 glow ShellHeader 大写名）+ 圈图标行三态（领袖能力 CircleBacking45 头像/文明能力 CircleBacking44+Darker-Lighter 徽记/特色内容 CircleCompass，标题 FontFlair14 ShellHeader Locale.ToUpper + 描述 DawnText，缩进 55px）；GetPreText 属性行（解锁科文/造价/战力）按用户裁决去除；首悬停尺寸偏小修复 = 尺寸收口移出去重（首帧新控件文本未布局实测偏小，悬停期间引擎反复回调以已布局控件实测自愈，去重仅免行重建），收尾两连 CalculateSize+ReprocessAnchoring 照搬原版 L876-877
| `InGame/BER/` + `InGame/BCT/` | 条目25 大将军时代提示（1.65 BER）+ 工人劳动力显示（1.65 BCT），目录/命名对齐 1.65 源结构（条目25规范）：`BER/UnitFlagManager_MPT.lua` 整文件替换（复用晋升徽标控件写时代名，防御 include 链 BuilderCharges_MPT→BarbarianClansMode→原版，压过 1.65 BER/BCT）+ `BCT/UnitFlagManager_BuilderCharges_MPT.lua`（工人劳动力徽标，MPT 名 ImportFiles 供链首环探测，与 1.65 同名文件不同名同装不双叠）。**规约（引擎墙，已沉淀技能库 ui/references/popup-panel-detail.md）：跨上下文注入旗标控件两路实验（AddUserInterfaces 迷你上下文 / LookUpControl 代理 + ChangeParent）均实测不生效已废止，唯一可行 = 整文件替换复用上下文内既有控件**；开关收编条目12（GreatGeneralEraReminder_Show，单通道 MPT_Settings_Toggle） |
| `InGame/NotificationDealRemind/` | 条目26 通知栏提醒扩展（1.65 NDR 交易提醒为基准主体 + 工坊 2459772036 他人招募伟人通知并入，单目录两功能）：两 lua 文件名前缀走原版 NotificationPanel_ 通配 include 钩子进同上下文（同条目19 机制，仅 ImportFiles 1010）——DealRemind 链式覆写 OnDefaultAddNotification（NOTIFICATION_DIPLOMACY_SESSION 通知自动展开 + 九种外交请求文本命中播提示音 3 秒冷却；相对 1.65 差异：零全局污染/匹配文本预加载查集合/冷却 os.time→UI.GetElapsedTime/GetNotificationEntry 查册 nil 守卫防面板未收下踩空/local 回调双通道订阅规避 1.65 具名回调 OnTPT_Settings_Toggle 同名互覆；开关 NotificationPanel_DealRemind 沿用 1.65 原 key 仅控提示音，MPT+TPT 双通道）+ GreatPerson 链式覆写 RegisterHandlers（原版 LateInitialize 运行时调用晚于通配注入，包裹必然生效；挂 NOTIFICATION_OTHER_PLAYER_RECRUITED_GREATPERSON handler，Activate 复用原版 OnClaimGreatPersonActivate；LoadGameViewStateDone 后才订阅 UnitAddedToMap 防读档既有伟人单位逐个弹源样保留；**通知类型/图标/文本原版全无，自带 GreatPersonRecruited_Data.xml（UpdateDatabase 10）+ GreatPersonRecruited_Icons.xml（UpdateIcons 10，ICON_ATLAS_NOTIFICATIONS[8]）+ 文本 SQL（tag 沿用源 mod 原名、仅 zh/en，Summary 占位符保留供引擎排版中文语序）**；源 mod 观察者踩空（Players[GetLocalPlayer()] 直接 GetDiplomacy）已补 nil 防御+观察者显示真名/不发通知；开关 NotificationPanel_GreatPersonRecruited 自造 key（源 mod 无设置体系）仅 MPT 单通道）；与 1.65 同装其 NDR/NOC 共载提示音双响、与源 mod 同装通知双份，均建议二选一；条目26修复：notificationEntry 误加 :table 标注被引擎赋值期类型检查拒绝（GetNotificationEntry 返回 hmake 'NotificationType' 引擎实例非纯表，Type check failed 中断包裹、展开与声音永不执行——条目21 引擎对象标注坑 hmake 实例类）去标注 + m_Instance nil 守卫 + 九文本查集合懒构建；条目26规范：删 TPT_Settings_Toggle 双通道订阅行单通道（同条目25规范裁决）；条目26扩展（用户裁决）：GPR handler.Add 包裹入栈即自动展开（BASE 全包裹链后查册+OnMouseEnterNotification 同 DealRemind 机制、无提示音、MPT_BASE_NotificationAdd 幂等守卫） |
| `InGame/NewHotKeys/` | 条目28 更多快捷键（移植 1.65 NHK 全模块 + CHS-PVP 3037861572 两个 Queries SQL 扩展单位热键去重合并）：①12 单位命令热键引擎双层（InputActions 注册 + UnitOperations/UnitCommands.HotkeyId UPDATE，WHERE IS NULL 不覆盖玩家绑定；升级含激活伟人超集）②地图钉四键 Shift+Y/A/D/M（CPL_NO_PINS 运行时联动条目16 + DMT_MapPinRemoved 广播保留）③随机晋升 Shift+W + 伟人自动招募 Shift+K（GPA_Icon 指示灯）④强制结束回合 Shift+F（自动模式 tick 节流高频重试 + 四角黑边挂 WorldInput，对接条目12 FEB 右键预留点 LuaEvents.ForcedEndTurn）⑤城市远程攻击 CSA 走原版通配 include 链 ImportFiles 1000（条目18 1010 之前）。**键位以 1.65 为准（用户裁决）**：掠夺 Shift+P/升级 Shift+E/晋升 Shift+G/取消 Shift+S；CHS 冲突改键 编队 Ctrl+Shift+E、唤醒 Ctrl+Shift+W、军团 Shift+C（原版键位零冲突已全量核验）。**同装让位 criteria**：NHK_MPT = MPT_NEW_HOTKEYS 开关（MPT 独立不与 1.65 共享，用户裁决）∧ ModInUse inverse 1.65（其 NHK 原版 Lua 继续服务防双触发）；NHK_MPT_MAP 再 ∧ DMT 让位；共享 4 动作同 ID 同键幂等收敛（条目24 先例）。Lua 消费 = 四 XML+同名 Lua 迷你上下文 AddUserInterfaces(900)+ImportFiles(900)（同条目12/20 机制）。优化：18 动作单文件注册（1.65 分散 4 XML+1 SQL）、CHS 内嵌中文转 LOC tag 补 en、零全局污染（1.65 泄漏 20 余全局全 local 化）、剔除 1.65 反作弊搭车代码（KillCheat 恶意 Modding.UpdateSubscription 循环）与死键位、惰性控件 nil 防御 + 挂载幂等守卫；引擎方言两坑（泛型 for 标注/返回值 ) :type 标注）即摘即扫；**条目28调整（用户裁决）：「更多快捷键」开关作用域收窄 = 仅单位侧（键位绑定 SQL + 随机晋升/晋升预清）；自动招募/强制结束/地图钉/城市远程攻击不受开关影响，仅 1.65/DMT 同装让位——新 criteria Disable_TPT/Disable_TPT_DMT，NHK_MPT_MAP 废止** |
| `InGame/BetterGreatPeople/` | 条目29 伟人界面增强（1.65 BGP = Infixo Better Great People + 号码菌「修改背景」补丁）：整文件替换原版 Popups/GreatPeoplePopup（ReplaceUIScript 100000 + ImportFiles 100010；**原版尾部通配 include("GreatPeoplePopup_", true) 必须保留**——XP1/XP2/巴比伦英雄模式覆盖文件经此钩子加载，仅重定义 GetPatronize*TT/IsReadOnly/AddCustomTabs/ResetGreatPeopleInstances）。基底 = 当前原版文件（保留类型标注；1.65 版基于旧版已剥标注，全量剥标注属非功能 diff 不采纳），功能补丁仅 5 处：个人名颜色包裹（_COLOR tag 探测，原版无走 GreatPeopleCS 同色；**XML 样式不改——原版 GreatPeopleLargeText 本就是 FontFlair14+SmallCaps20 同字体**）/ 底部延伸背景 WoodPaneling2/3 / 招募竞争列表每回合点数增速 AmountPerTurn / 往期招募倒序（1.65 用 StackGrowth Up，此处 XML 保持 Down 改 Lua 反序遍历等价可还原）/ 招募进度区加高+效果区收缩。**XML 纯插入不改原版行（新控件默认 Hidden），全部布局值由 Lua MPT_BGP_ApplyLayout/MPT_BGP_ApplyInstanceLayout 恒启用套用**；1.65 注释原版水平滚动条属不可运行时还原的纯装饰不采纳；巴比伦英雄页签下延伸背景宽度不随 ResizeHeroPaneling 刷新（纯装饰残留）。无开关恒启用（条目29修订用户裁决：默认增强即可，不收编条目12，原 MPT_Settings 行 BetterGreatPeople_Show 与双语文本已移除） |
| `InGame/`（其余） | 后续 InGame 功能每功能一个自包含子目录（条目12+ 随 1.65 对应缩写目录逐一移植，进度见 计划.md） |

## 加载机制（.modinfo）

LoadOrder 分层规约（注释写死在 modinfo 顶部）：**1-99 配置 | 100-999 文本 | 1000-9999 UI替换 | 10000+ 覆盖型替换 | 99999+ 强制后置**。

- 配置/文本/数据表：`UpdateDatabase` / `UpdateText`，写入前端 Configuration 数据库。
- 整 Context 替换：`ReplaceUIScript`（LoadOrder 100000）+ `ImportFiles`（100010）双注册（条目15/17/21/22/23/24/25 模式）。
- 同名覆盖/共享文件导入：仅 `ImportFiles` 导入与原版同路径文件名的 Lua/XML 实现覆盖（条目14/16/22/25；**文件名必须保持原名**）。
- 通配 include 钩子：原版文件末尾 `include("Xxx_", true)` 把文件名前缀 `Xxx_MPT.lua` 拉入同上下文——仅 ImportFiles(1010) 无 LuaContext（条目7/18/19 模式）。
- 空 Context + 同名 Lua 自动执行：AddUserInterfaces(900) + ImportFiles(900)（条目5/12/13/20/21 模式）；AddUserInterfaces 上下文默认隐藏，显隐自行控制。
- 条件注册：`ActionCriteria`——`ModInUse inverse` 按其他 mod 是否启用门控（Disable_MPH），`ConfigurationValueMatches` 按 GameConfiguration 值条件执行 SQL（**仅 InGame 侧、开局建库时求值**）。
- Configuration 参数仅 FrontEnd 注册（开局建库继承）；**IG 重复注册主键冲突**——IG 侧只建自有数据表（条目20 模式）。
- **新文件必须同时登记进对应 action 和 modinfo 末尾的 `<Files>` 列表**，否则不会被打包加载。

### 命名与共存规约（与 1.65 同装）

- InGame 目录用描述性命名（非 1.65 缩写）；自有代码标识符（事件/函数/控件/文本 tag）一律 MPT_ 前缀防撞名。
- 与 1.65 共享的开关/热键（参数 ParameterId、InputActions、对应文本 tag）沿用 1.65 原 key，同装幂等共享。
- 功能文本注册在消费侧：仅前端消费 → 仅 FE UpdateText；仅游戏内消费 → 仅 IG（条目21/22 先例）；通用文本（FrontEnd/Text/）双环境注册。

## 开发规范（源自 计划.md，务必遵守）

- **流程**：按 计划.md 条目顺序依次实现，每完成一条立即停止等待用户确认；git 管理，每完成一次修改任务后提交。
- **git 提交规则**：**每完成一次修改任务（含功能实现、修复、文档/规约同步）后必须主动提交 git，无需等待用户另行指示**（本条为长期授权）。提交信息格式为「条目X.Y：……」「条目X.Y修复：……」，与条目号可追溯；一次任务的相关文件（代码 + 计划.md/AGENTS.md 同步 + modinfo 版本递增）合并在同一次提交。
- **修改留痕**：所有对原版文件的改动用注释横幅标记旧代码与新代码（`-- ====` 起、旧代码整行注释保留、`-- ----` 止，格式示例见 StagingRoom.lua 顶部横幅区）。
- 新功能函数必须带注释与用法说明；同一类函数集中放在规范的区域（StagingRoom.lua 末尾按条目分区，如「条目3.2 快捷开关AI」「条目4.1 版本校验」各成一节）。
- **本地化一律用 SQL**（`INSERT OR REPLACE INTO LocalizedText`），通用文本集中放 `FrontEnd/Text/` 每语言一个文件；功能专属文本随功能文件夹存放。
- **本地化文本预加载缓存**：本 mod 新增文本在 Lua 中使用时，按条目分区头后集中预加载为 `local XxxStr = Locale.Lookup("LOC_...")` 缓存；带参数文本不用 `Locale.Lookup(tag, args)`，改为「无参数纯文本 tag + Lua `..` 拼接」。缓存块放在分区头之后、函数定义之前。
- 代码风格遵循游戏官方 Lua 风格（Tab 缩进、`local x : number` 类型标注、行尾分号、函数头注释块）。
- 涉及深度设计疑问时使用 deep-probe 技能追问；文明6 mod 开发知识查 civ6 技能。

## 关键实现细节（踩坑记录）

通用引擎经验已迁移至 civ6 技能库（`C:/Users/24296/.zcode/skills/civ6/`），改动前先查阅：

- **前端环境限制**（空 Context 前端不执行 Lua / include 本 mod 文件在进程首个前端生命周期后静默失效 → 前端代码一律内联进 StagingRoom.lua）：`patterns/references/empty-context.md`「FrontEnd 环境限制」
- **存档读写管线 / ModGroup 组名存储 / 每帧滴答源（AlphaAnim）/ 联机广播流量纪律 / 大 Lua 寄存器上限（do...end 包裹）/ local 声明顺序 / 单订阅调度器 / 回合开始事件驱动幂等初始化**：`lua/references/lua-advanced-patterns.md`
- **UI 渲染坑**（SetColor/SetTexture/DDS/auto 宽延伸/ScrollPanel Line 裁剪）：`ui/references/ui-debugging.md`
- **PopupDialog 空 Context 不实例化 → 自研弹窗；AddUserInterfaces 迷你上下文引擎墙（跨上下文注入唯一可行 = 整文件替换）**：`ui/references/popup-panel-detail.md`
- **小地图矩形只认引擎数据（地图钉）**：`ui/references/ui-advanced-patterns.md`
- **静默失败案例库**（十批 62 例；本 mod 实测：前端环境 42-46 / 标注语法 47-48 / 图集图标 49 / 初始化时序·显隐继承·注册 50-56 / 迷你上下文·Stack 内 Container·tooltip 每帧重建·UTF-16 grep 假象·UTF-8 截断乱码·热区遮挡 57-62）：`debug/references/workshop-verified-failures.md`
- **观察者 mod（BSM）生态兼容协议**（SPEC 属性判定 / 切 POV 三键名 / 观察者槽位特性 / GAP 延迟协议依赖）：`patterns/references/workshop-cross-domain-patterns.md`
- **LoadOrder 分层 / 广播限窗口 / ActionCriteria 求值时机 / 文本预加载**：`patterns/references/`、`mod/references/criteria-patterns.md`、`text/references/workshop-text-patterns.md`

> 本 mod 专属协议（MPT_ModCheck 三通道 `MPT_MC_LIST/HOSTV/VERS`、沉淀门/超时算法、`MPT_MC_*` 键名）不迁移，保留在 StagingRoom.lua 条目4.1 分区内；改动该分区前先读其头部注释。

## 构建、测试与验证

没有自动化构建与测试。验证流程（DoD）见 civ6 技能 Phase 5：清空 Logs 目录 → 启动游戏加载 mod → 检查 `Database.log` / `Lua.log` / `Modding.log` 无错误 → 进准备房间确认功能实际生效。关键行为（如 SetValue 长度上限、Line 控件裁剪）靠游戏内实测验证后再定稿，实测用临时代码用完即移除。

## modinfo 规约

Mod id GUID 前 8 位为 0；`<Name>/<Description>/<Teaser>/<Authors>/<SpecialThanks>` 全部使用本地化文本多语言（Description 多用 `[NEWLINE]` 排版）；每个 action 配注释。通用规范详见 civ6-mod 子技能。

## 参考路径

- 游戏本体：`D:\Game\Steam\steamapps\common\Sid Meier's Civilization VI`（原版 UI 在 `Base\Assets\UI\`）
- 工坊 mod：`D:\Game\Steam\steamapps\workshop\content\289070`（联机工具箱1.65 = 3693899014）
- 参考实现：`D:\文档\My Games\Sid Meier's Civilization VI\Mods\乔尔定制mod\UI\StagingRoom.lua`
