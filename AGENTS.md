# 联机工具箱 2.0 前端（Multiplayer Toolkits 2.0 FrontEnd）

## 项目概览

《文明6》（Sid Meier's Civilization VI）**前端（FrontEnd）模组**，作者 号码菌Synora。融合「联机工具箱 1.67」与 MPH（Multiplayer Helper）的前端功能并加以优化，主要面向多人联机准备房间体验。模组校验 / BP 功能改编自 MPH（MIT 协议 © 2024 BetterBalancedGame），部分功能参考联机工具箱 1.67 与乔尔定制mod。

- **不是常规软件工程**：没有 pyproject.toml / package.json 等构建配置，没有测试框架，没有 CI/CD。
- 技术栈：Firaxis 模组体系 = `.modinfo` 清单 + 前端 Configuration 数据库 SQL/XML + UI 替换 Lua/XML + DDS 贴图。
- 部署方式：整个目录放在 `D:\文档\My Games\Sid Meier's Civilization VI\Mods\` 下即被游戏加载（本目录即模组本体）。`Core/`、`Tools/` 目前为空目录（预留）。
- 版本管理：git，提交信息格式为「条目X.Y：……」「条目X.Y修复：……」。

### Mod 清单

- Mod id：`00000000-7369-4685-ab5f-bf77bc22b54e`（规约：GUID 前 8 位为 0）
- `<Version>21</Version>` 是模组版本一致性校验指纹，**结构性更新必须递增**
- `AffectsSavedGames=0`，`CompatibleVersions=1.2,2.0`
- 前端功能全部走 FrontEndActions；InGameActions 注册游戏内功能（条目5 起逐条移植 1.67）与通用文本。

## 目录结构与功能模块

功能按 `计划.md` 中的「条目」编号组织（条目1/2/3.x/4.x），代码与提交信息均用条目号追溯。

| 路径 | 内容 |
|------|------|
| `MultiplayerToolkits.modinfo` | 模组清单：全部 action 注册、LoadOrder 分层、`<Files>` 文件登记 |
| `计划.md` | 前端设计计划与开发规范（本文件大部分规约的出处，改动规约时需同步更新） |
| `FrontEnd/Config/Config_Base.xml` | 条目2：联机常用游戏设置预设（无蛮族开/回合60秒/允许重复文明领袖/「禁用领袖池」参数） |
| `FrontEnd/Config/Config_Disaster.sql` | 条目2：灾害强度下限 0→-1（完全无灾害），LoadOrder 99999 强制后置 |
| `FrontEnd/UI/Options/Options.xml` | 条目1：整文件同名覆盖原版，唯一改动 LAN 玩家名 MaxLength 22→45 |
| `FrontEnd/UI/StagingRoom/StagingRoom.lua`（~6300行） | 条目3 核心：同名覆盖原版准备房间脚本。房间20人上限、快捷开关AI（3.2）、快捷分队（3.3）、房主权限提升改他人队伍/领袖（3.4）、更新公告面板（3.5）、广告轮播（3.6）、ping 常驻显示（3.7，内联覆盖原版 UpdateNetConnectionIcon）、移除玩家入槽位下拉框（3.8，NUM_COLUMNS 5→4、g_slotTypeData 新增 kickOption 哨兵项，改动列数/槽位类型时先读分区注释）、mod 版本校验（4.1）、非官方模组清单（4.2）、序列化与数据读写内联分区（4.3预备，ModGroup 组名承载）、玩家标记管理（4.4，纯本地档案+隐身开关）、图标查看器（4.5）、贴图查看器（4.6，4.5/4.6 融合为单面板双页签）、进房自动更新已启用非官方工坊mod（4.7）、房间内玩家标记显示（4.8）。末尾按条目分区 `do...end` 包裹（寄存器上限约束，新增分区必须沿用） |
| `FrontEnd/UI/StagingRoom/StagingRoom.xml` | 条目3：同名覆盖原版准备房间布局（StatusLabel 已改 TruncateWidth=180 截断，超宽省略） |
| `FrontEnd/UI/AdvancedSetup/AdvancedSetup.lua` | 单人高级设置替换：minPlayers 2→1，允许移除全部 AI、1 人开局 |
| `Shared/` | 双环境共享代码与数据。`MPT_Serialize.lua` 序列化；`MPT_DataStorage.lua` 统一多表本地读写（条目4.3重构：对外 `MPT_Storage_LoadAll/GetTable/SaveTables` 三 API，所有数据序列化后承载于单一 ModGroup 组名、组内按表名分键，写多表自动读回合并、调用方零 merge）。**前端实际承载 = StagingRoom.lua 末尾「条目4.3预备」内联副本**（因引擎 include 缺陷，见技能库 empty-context.md），两副本改动必须双向同步。子目录 `PlayerMark/` 为玩家标记双环境共享数据，当前仅前端消费 |
| `FrontEnd/Text/` | 通用本地化文本（每语言一个文件：`FrontEnd_zh_Hans_CN.sql` / `FrontEnd_en_US.sql`） |
| `FrontEnd/Changelog/` | 条目3.5 更新公告：`MPT_Changelog` 数据表 + 专属文本 |
| `FrontEnd/Ads/` | 条目3.6 广告轮播：`MPT_Ads` 数据表 + 专属文本 + DDS 贴图 |
| `FrontEnd/ModCheck/` | 条目4.1 模组校验：`MPT_ModCheck` 注册表（mod 自我登记 modId）+ 专属文本 |
| `FrontEnd/ModList/` | 条目4.2 非官方模组清单：专属文本（数据走运行时 Modding API，无数据表） |
| `Shared/PlayerMark/` | 条目4.4/4.8 玩家标记：专属文本 + 条目4.8 数据表 `TPT_PlayerData`（`PlayerMark_Data.sql`）+ 3 张标记图片 DDS |
| `FrontEnd/IconViewer/` | 条目4.5 图标查看器：`MPT_IconCollection` 数据表（移植 EasyIconViewer 5056 图标）+ 专属文本 |
| `FrontEnd/TextureViewer/` | 条目4.6 贴图查看器：`MPT_TextureCollection` 数据表（移植 TextureViewer 5017 行）+ 专属文本 |
| `InGame/RevealMapCorners/` | 条目5 显示地图角落（移植 1.67 RMC）：建两个极地真实地图钉 + DequeuePopup 弹掉编辑弹窗，撑开引擎小地图世界矩形；副作用：留两个可见 pin |
| `InGame/GreatPersonNames/` | 条目6 伟人名字更新（移植 1.67 GPN）：魔女环境检测后写入纪念伟人名字，LoadOrder 5000000 压后覆盖，非魔女环境保护原版 |
| `InGame/EndGameMenu/` | 条目7 战败后观战按钮（移植 1.67 EGM 并修复反复弹出 bug）：整文件同名覆盖 + 通配 include 注入 |
| `InGame/WorldTracker/` | 条目8 WorldTracker 快捷操作面板：空 Context + ChangeParent 挂载，展开区「投降」「重新开始」「玩家标记」「设置」四按钮 + 投票区；「重新开始」响应未配置 TODO |
| `InGame/SurrenderVote/` | 条目8续 团队投降投票（Gameplay 侧）：AddGameplayScripts 注册，EXECUTE_SCRIPT 收 UI 指令，票数 ≥ 半数 → 该队城市全部叛变自由城；每时代每队一次 |
| `InGame/TopPanelExt/` | 条目9 顶部面板扩展（移植 1.67 TPE）：ReplaceUIScript 覆盖，追加食物/生产力/人口/奢侈品统计按钮与 Tooltip、战略资源 Tooltip 追加队友清单 |
| `InGame/DealRestriction/` | 条目10 交易限制与外交限制（移植 1.67 DDV 整模块）：交易四模式/无友谊默认开/和解三模式；`MPT_TradeRules.lua` 统一解析器；SQL 经 ActionCriteria（ConfigurationValueMatches）条件执行；参数定义与 DealView 导入门控 `Disable_MPH` |
| `InGame/PlayerMark/` | 条目11 游戏内玩家标记面板（移植条目4.4 到 InGame）：include Shared/MPT_DataStorage.lua 与前端同一份存档互通；QuickPanel 按钮打开 |
| `InGame/ForcedEndTurn/` | 条目12 强制结束回合按钮（移植 1.67 FEB）：ActionPanel 右下角 50×50 按钮左键强制结束回合（ACTION_ENDTURN REASON="UserForced"），右键保留 LuaEvents.ForcedEndTurn 触发点（NHK 未移植，预留）；显隐默认隐藏，由设置面板经 LuaEvents.MPT_Settings_Toggle 广播控制 |
| `InGame/SettingsPanel/` | 条目12 游戏内设置面板（移植 1.67 Settings 简化版，独立目录）：当前仅 FEB 开关；参数表 MPT_Settings（ParameterId 保留 1.67 key ForcedEndButton_Show，避免与 1.67 TPT_Settings 建表冲突），入口为 QuickPanel 展开区「设置」按钮（LuaEvents.MPT_SettingsPanel_Toggle——条目12修复：开关入口与参数广播 MPT_Settings_Toggle 拆分独立事件名，原共用导致点复选框广播时面板自关闭）；存档走条目4.3 统一多表存储（复合组 [MPT_DS][MPT_PlayerInfo]，表名 = 参数 ParameterId，与玩家标记/隐身同组互不覆盖）；点击复选框不落盘（仅关闭时保存，防 StorageCreateCleanGroup 批量禁用 mod 卡顿）；命名规范 MPT 前缀（条目12优化：事件/函数/控件/文本 tag 全部 TPT→MPT，与 1.67 广播互不联动）；不自动弹出（条目12修复：删 1.67 首次引导弹窗，入口仅 QuickPanel 按钮） |
| `InGame/AutoUpdate/` | 条目13 游戏内自动更新（移植 1.67 Update/AutoUpdate 纯逻辑部分）：空 Context + 同名 Lua 自动执行（无 UI 控件），进游戏即对本局已启用的非官方创意工坊 mod 触发更新检查（复用条目4.7 优化）+ 按 MPT_MOD_ID（GUID）定位本 mod 条目，EnsureEnabled 匹配 Handle 确保启用（本地 mod 无订阅 ID，1.67 按 SubscriptionId 匹配不适用）；退出到主菜单（ExitToMainMenu）取该条目 SubscriptionId 触发本 mod 工坊更新（发布后自动生效，无订阅 ID 跳过，不依赖硬编码订阅 ID 常量） |
| `InGame/TechCivicProgress/` | 条目14 真实科文进度（移植 1.67 TCP）：科技树/市政树/选择器显示真实研究进度（Tooltip 进度+提升后预估+可凭提升完成、[icon_You] 标记、modifier 附加加速、BLOCKED 回合修正）。`TechAndCivicSupport.lua` 同名覆盖原版共享脚本（被 7 个 context include，修改集中数据层：GetResearchData/GetCivicData 追加 Estimates/Enough + Name 图标，Chooser 显示自动生效）；`TechTree_MPT.lua`/`CivicsTree_MPT.lua` include 探测官方最高版本（Exp2→Exp1→Base，官方联盟研究图标与 IsSearchable 自动获得）后覆盖 GetCurrentData/PopulateNode。默认启用无开关；LoadOrder 100000 压过 1.67 |
| `InGame/TeamVisibleResources/` | 条目15 队友资源可见性显示（移植 1.67 STR）：`WorldViewIconsManager_MPT.lua` ReplaceUIScript 覆盖 WorldViewIconsManager 上下文（LoadOrder 100000 + ImportFiles 100010）——同队队友已通过科技/市政解锁而本地未解锁的资源，在地图已探索迷雾格显示迷雾图标（include 原版后覆盖 Initialize/GetNonEmptyAt/OnResearchCompleted/OnCivicCompleted/OnShutdown；原版仅 Base 版本无 DLC 变体，无需版本探测）；外部刷新接口 LuaEvents.MPT_WorldViewIcon_Rebuild；优化点（观察者 nil 防御/扫描函数合并/O(1) 映射/读档即同步/监听卸载/GovernorAppointed Exp1 守卫）见文件头横幅，无文本无 XML；目录名用描述性命名（非 1.67 缩写 STR，对齐 InGame 命名规范） |
| `InGame/DisableMapPins/` | 条目16 禁用地图钉（移植 1.67 RMP）：高级选项金色开关「禁用地图钉」（`CPL_NO_PINS`，ParameterId/文本 tag 均沿用 1.67 原名，与 1.67 同装共用同一开关），勾选后进局隐藏小地图「地图钉列表」按钮（`DisableMapPins.xml` 空 Context + 同名 Lua 自动执行，`MPT_OnLoadScreenClose` + nil 防御）+ 空壳替换原版 MapPinListPanel 脚本与布局（联机卡顿元凶，`MapPinListPanel_MPT.lua` ReplaceUIScript 100000 压过 1.67 的 2010 + `MapPinListPanel.xml` 双保险，文件名必须保持原名才能按名覆盖）；三个 InGame action 均由 `No_Map_Pins` criteria 门控（不勾选零改动），参数 FE UpdateDatabase(10) 无条件注册 + 文本 FE UpdateText(100) 仅前端注册；1.67 NT 进局通知不移植 |
| `InGame/InstantFoundCity/` | 条目17 建立城市免确认（移植 1.67 RCT）：`UnitPanel_MPT.lua` ReplaceUIScript 覆盖 UnitPanel 上下文（LoadOrder 100000 压过 1.67 的 11000 + ImportFiles 100010；无条件常开同 1.67，无开关无文本无 XML）——点击「建立城市」直接坐城不弹确认框（含地貌移除提示）。文件内重建原版 include 链（BSM unitpanel_spec 优先→XP2→XP1→Base，命中全局 Initialize 即 break）后重定义 OnUnitActionClicked_FoundCity（原版回调闭包点击时才解析全局名，函数名保持原名不可 MPT 化）；优化：自建 Lens hash 修复 m_HexColoringWaterAvail 原版 local 跨 include 不可见致 nil（坐城后水高亮层不关/镜头不回默认）、删 popupString 死代码、原版弹窗逻辑修改留痕保留，详见文件头横幅 |
| `InGame/CityBannerRefresh/` | 条目18 城市横幅刷新（移植 1.67 PCF/皮皮凯）：`CityBannerManager_MPT.lua` 文件名前缀走原版 CityBannerManager.lua 末尾通配 `include("CityBannerManager_", true)` 钩子进同上下文（同条目7 机制，仅 ImportFiles 1010 无 LuaContext）——①市民变动后单城 RefreshBanner（原版不订阅 CityWorkerChanged 的横幅产出滞后修复）②城界扩张/人口增长/地块产出变化后下发 MANAGE 公民指令重排市民到最优地块。刷新机制重写：单订阅调度器（1.67 每定时器一条 GameCoreEventPublishComplete 订阅→仅 1 条驱动任务表 O(1) 增删）+ 真实时钟 UI.GetElapsedTime（1.67 发布周期计数冒充秒数失真）+ 全 local 零全局污染 + MPT_ 前缀去重键 + 重排后兜底刷新 + nil 防御；保留 1.67 语义（回合开始 1 秒冷却/回合结束清任务/2-4 秒去抖），详见文件头横幅。条目18修复：cfunction 直接赋 ifunction 标注变量被引擎类型检查拒绝（Type check failed → chunk 中止通配 include 全体未加载），改 Lua 闭包包装 + MPT_Banner: 前缀调试 print 留痕（条目18清理：实测确认后已全部移除）。条目18调优：刷新延时 2 秒→0.1 秒近实时、重排 4/2 秒→0.5 秒统一合并窗口（MPT_REFRESH_DELAY/MPT_REARRANGE_DELAY 常量） |
| `InGame/NotificationClear/` | 条目19 清理通知按钮（移植 1.67 NOC）：`NotificationPanel_MPT.lua` 文件名前缀走原版通配 include 钩子进 NotificationPanel 上下文（仅 ImportFiles 1010），链式覆写 OnDefaultAddNotification/ReleaseNotificationEntry——通知栏垃圾桶按钮一键清理全部可手动关闭通知。按钮复用 ItemInstance 模板懒创建、先于首条通知分配+永不释放→天然恒居栈最底部（用户询问的 SortChildren 无必要，O(nlogn) 纯开销）。优化：精确存活集+计数（替代 1.67 环形缓冲 100 回绕丢 ID/IM 内部字段直读+>1 魔数）、MouseOutArea 重复注册删除、设置广播 nil 守卫（1.67 崩脚）、Clear 先快照防遍历中改表、零全局污染；开关在条目12 MPT_Settings 表加行（ParameterId 沿用 1.67 原 key NotificationPanel_QuickClear，勾选=禁用反向语义），初始状态经面板 ApplyAll 广播送达。条目19修复：通知清空后按钮单独残留——五处漏减堵漏（原版 ClearNotifications ipairs 遍历中 table.remove 跳号+DestroyInstances 整批销毁为主犯，包裹 ClearNotifications/OnNotificationRefreshRequested/OnStartObserverMode 三原版全局统一清账与按钮引用失效重建；OnUnitKilledInCombat 原版笔误兜底失效、跨玩家残留→MPT_Reconcile 对账逐 ID NotificationManager.Find 剪除自愈；BASE 提前返回孤儿 ID→GetNotificationEntry 查册；显隐口径改「有 UI 实例资格（IsIconDisplayable 且非回合阻塞）」存活数，计数 Reconcile 重算单一事实） |
| `InGame/SmartTurnTimer/` | 条目20 智能回合计时器（移植 1.67 CC/Timer TimerPro + NHK/UI/TurnTime_HotKey 热键与按钮，1.67 两 Context 合并单文件）：空 Context `SmartTurnTimer.xml`（仅聊天框旁 P++/P-- 两按钮，默认 Hidden，Lua ChangeParent 到 ChatPanelContainer——LoadScreenClose 后执行防 WorldTracker 未加载）+ 同名 `SmartTurnTimer.lua` 自动执行（AddUserInterfaces 900 + ImportFiles 900，同条目12/13 机制）+ `SmartTurnTimer_InputActions.xml`（GameInfo.InputActions+InputActionDefaultGestures，]/[ 键位，前后端各注册一次——FE 按键绑定界面显示/IG 运行时取用）。房主回合末按「半数真人结束回合用时」PID 自动平衡 TURN_TIMER_TIME 并 BroadcastGameConfig 广播全房（Kp0.5/Ki0.08/Kd0.25/限幅±10/目标18s/下限30s/衰减0.98 原值保留）；宣战+20s/掉线+30s/对城邦+8s 自动加时；议会投票固定 120s；聊天指令 p+/p+++/p-（仅房主监听公共频道）；首回合多人强制 STANDARD。条目20扩展：工作模式 Game 配置参数 MPT_TIMER_MODE（`Config_SmartTimer.xml` 仅 FE 注册——Configuration 参数须前端注册开局建库继承，IG 重复注册主键冲突；GameOptions 组 SortIndex=21 紧随原版计时器类型、ChangeableAfterGameStart=1 可开局后改广播全房）。条目20扩展2 拆分两设置：①MPT_TIMER_CHAT 启用聊天指令（bool 默认 1，SortIndex=22）——p+/p+++/p- 与按钮/热键总开关，原 BASIC 模式语义由「任意模式+此开关」组合表达（1.67 固定曲线不含聊天的约束随拆分取消）；②MPT_TIMER_MODE 三值下拉（删 BASIC，FIXED 改名 TIERED 阶段计时器）：OFF 全关（指令即使开也不生效）/SMART PID 完整/TIERED 平滑线性曲线——`SmartTurnTimer_Tiers.sql`（仅 IG UpdateDatabase(10)）建 MPT_TimerTiers 表（Turn 回合数/Time 秒数，主键 Turn，默认节点=用户示例 (30,30)/(50,80)/(70,180)，自定义曲线改 VALUES 行即可），Lua GetTierNodes 懒加载缓存+行值守卫、TieredTimeForTurn 相邻节点线性插值（首节点前保持首值/末节点后保持末值/表空兜底 60），TIERED 回合末按 CurrentTurn+1 取曲线值+p+/p-- 的下一回合效果在曲线值上 ±5/15 落实+p+++ 恢复 STANDARD、开局即 STANDARD+首回合取曲线回合 1 值；lua 门控改 MPT_Timer_ChatEnabled()（布尔开且模式非 OFF），TurnEnd 分发 SMART/TIERED/OFF，宣战/掉线/投票/半数采样仍仅 SMART；初版 MPT_Settings 布尔行 TOOLS_COMMAND 已回退（并存会打架），语义回归 1.67 全局配置（全房统一跟随房主），按钮显隐经 GameConfigChanged 刷新。优化（文件头横幅留痕）：零全局污染（1.67 十余全局全 local）、DB.MakeHash 替代魔法数 2133509568、四处真人全遍历合并 CountHumans、PID 控制量单次计算+修正量懒算、TURN_TIMER_TIME 非 number 兜底 60 等 nil 防御、冷却 os.time→UI.GetElapsedTime 闭包（条目18修复同款）、IsAnyMultiplayer 联机门控、TurnTimerUpdated 单订阅、文本按实际值修正 1.67「-20s」bug；15 秒滴答音与 NHK 强制结束回合不移植（FEB 已有）；与 1.67 同装双方计时器互相拉扯（用户确认不管控），勿同开 |
| `InGame/ExtendedPolicyCards/` | 条目21 政策卡收益显示（移植 1.67 BRS/ 内打包的 EPC = Extended Policy Cards by Aristos）：政府/政策卡界面每张政策卡底部显示真实收益条 + tooltip 追加效果。数据层 `MPT_RealModifierAnalysis.lua`（Infixo RMA 引擎 v7.0 整携，MPT_ 改名防 1.67 同装撞名）空 Context + 同名 xml 自动执行（同条目5/12/13 机制），`ExposedMembers.RMA` 供跨上下文调用；唯一 BRS 硬依赖（第 1 行 print 读 BRS_VERSION 全局参数，nil 连接崩 chunk）已删即完全独立。表现层 `GovernmentScreen_MPT.lua` ReplaceUIScript 100000 + `GovernmentScreen.xml` 同名覆盖布局（三方 diff 验证 = 当前 2.0 原版 + ARISTOS 两块补丁无漂移；原版无通配 include 钩子、DLC 无完整变体，只能整文件覆盖；压过 1.67 EPC_IMPORT_FILES 12001，条目15/17 模式）；调用点 RMA nil 防御。无条件常开同 1.67。1.67 BRS/ 其余 21 文件（报告界面 9 页 + 主框架、RLL、F8 热键、图标包、文本包）经零引用验证剔除（用户问「哪些代码多余」的裁决，详见计划.md 条目21）。条目21优化：政策卡收益类型 31→89 全覆盖——政策卡实际使用 90 种 EffectType（sqlite 枚举），引擎原 31 种其余全红字 Unknown；新增 MPT 文本行通道（MPT_LineHandlers 58 种 + CalculateModifierEffect/DecodeModifier 两 hook + 行缓存 + modifiers 懒索引替代全表扫描），文本行走静态参数驱动短行（原版 LOC tag + 功能文本 SQL zh/en），hook② 使 MPT 类型不再误标 Unknown，原产量计算零改动；战争疲劳实名 EFFECT_ADJUST_WAR_WEARINESS 等参数形态核实记录见计划.md 条目21优化。条目21修复：RMA 第 1836 行类型标注位写保留字 function（local pHandler:function）被引擎 Lua 方言解析期拒绝致整个 chunk 未加载（条目18 cfunction/ifunction 运行期坑的解析期同族，块配平类自检查不出；两条语法坑已沉淀 civ6 技能库失败案例库第七批 47/48）；去标注修复并连带去除泛型 for 循环变量标注（原版零先例）。条目21修复：GovernmentScreen 政策卡链路三层防御（不动原版布局逻辑）——RealizePolicyCard 的 RMA 调用 pcall 化（异常不中断实例填充循环，MPT_GovScreen: 留痕）、EffectContainer/Effect nil 防御（GovernmentScreen.xml 同名覆盖未生效/被改时回退原版行为）、EnsureRowContentsFit/OverlapProperly 实例缺失防御 + 定位 print + OnRowAnimCallback 隐藏态跳过（1514 踩空崩实证于开局未开界面时，根因=动画帧回调触发时实例数组存在空洞）。条目21用户裁决：显示类型 58→20 收敛（新增 MPT_KnownEffects 静默机制）——仅保留资源数量/产出加成/伟人点/对象生产力 20 种（9 种对象生产力+战略资源+城邦商路金+外交支持三型+每城免费资源+伟人点+影响力点+联盟点+建造者次数），其余 38 种静默化（不显示不红字，hook② 按 MPT_KnownEffects 同样跳过原链；MPT_GetModifierLine 用 type=="function" 防 false 值被调用）；显示行去除回合描述（/每回合）；图标按 IconViewer_Data.sql 核对 [ICON_Favor]→[ICON_FAVOR]；电力静默；文本 SQL 收敛 12 短语×2；luaparser 剥标注解析通过。条目21用户裁决·实际计算：生产族 9 种走 MPT_ImpactHandlers 产量通道（BuildQueue hash 反查四表匹配当前生产对象含文明替代/时代区间→城市生产力×Amount% 跨城求和显示真实产量）；资源积累/每城资源/建筑支持/城邦商路/伟人点总计五类动态实时计算（MPT_DynamicHandlers 不进缓存，RefreshBaseData 失效；资源=Amount×IsResourceExtractableAt 提取地块数含被区域奇观覆盖；伟人点=Amount×至下一位招募回合数上限剩余缺口，池 API Game.GetGreatPeople():GetTimeline()+GetPointsTotal/PerTurn）；无收益时整行不显示；pMatch:function 保留字标注复发由 luaparser 自检当场抓出。条目21修复：生产族迁 Impact 通道时漏删 LineHandlers 旧静态行 9 种——hook② 因 LineHandlers 命中短路实际计算（一直显示旧静态文案）且旧 handler 的 GameInfo[sTable] 动态键访问返回 userdata 撞 :table 标注类型检查崩（pcall 防御按设计接住）；删旧注册收敛 LineHandlers 19→10 + MPT_GetGameInfoName 及自有代码 4 处引擎接口对象去 :table 标注（Players[id]/GameInfo 行对象有原版先例保留）；教训：迁移式重构须 grep 验证旧注册清零。条目21修复：战略资源不显示——GovernmentScreen 传 EPC 占位 ePlayerID=0，动态计算类按 0 号玩家算，多人下本地玩家非 0 号位则计数 0 整行静默；MPT_GetModifierLine 动态计算统一 Game.GetLocalPlayer() + handler pcall 化 + 资源 handler 诊断 print |。条目21修复：MPT_GetModifierLine 重构误将 return sLine 包进 if not bDynamic 块致动态行全部静默丢弃（诊断 print 实证数值正确），缓存写与返回分离修复。条目21用户裁决：卡面 Effect 不换行——CalculateModifierEffect 第 1 返回值改单行串（MPT 多行收益以 LOC_MPT_EPC_SEPARATOR 串接），第 5 返回值 [NEWLINE] 分行版供 tooltip（卡面 SetText 用第 1、Draggable/Effect tooltip 用第 5）；伟人点数静态化（仅 +n [GPP 图标]，原「总计=Amount×至下一位回合数」删除——卡为唯一点数来源时恒等于剩余缺口、与卡强度无关致 +1/+2 卡同数字，池 API 经 GreatPeoplePopup 核实无误弃用纯因显示语义；DynamicHandlers 5→4，TO_NEXT tag 废弃）；资源诊断 print 显示正常后删除；卡面串接接缝前段以 [ICON_..] 结尾时省略分隔符仅补空格（图标天然分隔，MPT_JoinCardSeg）；Req 主体数计算（MPT_GetModifierLine 第 3 参 = DecodeModifier 第 6 返回值 Req 过滤后主体数，免费资源/伟人点行 ×主体数、0 主体整行不显示——航天承包商宇航中心 Req 实证 7 城无宇航中心也 +21 旧算法废弃，GPP 重登记动态类 DynamicHandlers 5）；伟人点图标改 GreatPersonClasses.IconString（[ICON_GreatArtist] 短形式文本内联 token，ICON_GREAT_PERSON_CLASS_* 无字体字形渲染原文）；影响力/联盟/建造者次数三类显示删除（KnownEffects 静默，LineHandlers 7/SQL 10 短语）；资源行 icon 前数字后紧贴对齐原版产量串 GetYieldString（段间空格，MPT_JoinCardSeg 新增后段 [ICON_ 开头→空格规则）；决议返还（+50% 世界议会）显示删除（静默）；同 icon 同布局纯图标数值行合并（handler 第二返回值 tMerge 元数据随行缓存、收集结构化条目、串接前按 icon|layout 累加，交响曲两条 +4→+8，LineHandlers 6/SQL 9 短语）；忠诚度显示删除（EFFECT_ADJUST_CITY_IDENTITY_PER_TURN 原走引擎 LOYALTY 伪产量 [ICON_PressureUp] 通道，KnownEffects 静默）；效率：商路/建筑支持两动态 handler 全城遍历加按玩家缓存（MPT_GetCSTradeCount/MPT_GetBuildingCityCount，RefreshBaseData 失效）、hook② 零产量共享表 MPT_ZeroImpact 替代每主体 YieldTableNew 分配 |
| `InGame/BetterTradeScreen/` | 条目22 商路界面增强（移植 1.67 BTS/ = Better Trade Screen Lite，Astog 原作 + TeamPVPTools/DeepLogic 魔改）：商路总览（三页签/分组/七级排序/筛选/真实收益/精确剩余回合 Tracker/旅游业绩）+ 商路目的地选择面板（候选列表/排序/筛选/透镜/上次商路预选）+ 商人传送面板 + `TradeSupport.lua` 共享库（收益缓存/Tracker/排序）。原版四文件 Base 单版本无 DLC 变体 → 整文件覆盖：三 UI 上下文 `*_MPT.lua` ReplaceUIScript 100000 + 三 XML 与 `TradeSupport.lua`（被两面板按名 include，文件名必须原名）ImportFiles 100010，压过 1.67 BTS_IMPORT_FILES(11011)。**核心修复「商路目标面板收益不及时刷新」**：1.67 每回合只建一次收益缓存、同时回合内政策/建筑/贸易站/宣战议和全不反映 → 两面板 Open() 即 CacheEmpty + 政策变更补清缓存 + 新增 BuildingChanged/DistrictAddedToMap/TradeRouteAddedToMap（yield 类）与 DiplomacyDeclareWar/MakePeace/TradeRouteCapacityChanged/CityAddedToMap（validity 类，强制重建候选表）失效事件（均经原版 UI 验证存在）。优化：原版 2.0 弹窗互斥三事件回迁（CloseIfPopups/ReOpen/WorldInput_MakeTradeRouteDestination + IsInGame 守卫 + LaunchBar_CheckPopupsOpen）；1.67 bug 修复（上次商路预选未定义全局 DestinationCityID、DeepLogic m_PlotRevealed 永不清空、单数产量函数非缓存分支未定义标识符、Tracker 持久化 key 笔误 Rotues）。裁剪（同 1.67）：商人自动化整体剔除（1.67 v1.34 已禁用，底层死代码/取消自动化按钮/复选框控件不携带）、对方收益列不恢复（1.67 v1.33 裁剪）。设置：4 子选项收编条目12 MPT_Settings 表（ParameterId 沿用 1.67 原 key BTS_*，默认值同 BTS；MPT_Settings_Toggle 广播订阅取代 GameConfiguration BTS_* 与 BTS_SettingsUpdate；1.67 独立 BTS 设置面板不移植），与 1.67 同装设置互不相通。文本仅 IG 注册（同条目21）。详见计划.md 条目22 |
| `InGame/BetterCityStates/` | 条目23 城邦界面增强（移植 1.67 BCS/UI/ 两文件 + 并入观察者 mod Better Spectator Mod 的城邦面板补丁）：城邦面板任务行（CuiQuestGrid）/单城邦视图默认「影响力」页/加成弹出区永久隐藏/宣战时使者排名条染红（1.67 BCS 四处魔改原样）+ MPT_IsSpectator 观察者判定（读 BSM 的 SPEC_NUM/SPEC_ID_k 游戏属性，未装 BSM 恒 false 行为同原版）→ GetCityStatesMetNum/ViewList 的 isHasMet 放宽「或观察者」+ OnLocalPlayerTurnBegin 面板隐藏也刷新 + Initialize 去 CAPABILITY_CITY_STATES_VIEW 门控 + GetData/AddInfluenceRow 的 CPL_ANONYMOUS 联赛匿名——单文件直接兼容，替代 1.67 的 ModInUse_BSM criteria 双版本切换机制。`CityStates_MPT.lua` = 原版 Base+XP1+XP2 三文件压平合并体（1.67 TPT 版原样）ReplaceUIScript 100000 + `CityStates.xml` ImportFiles 100010（同条目15/17/21/22 模式），压过 1.67 两套注册（1000/1010 与 11000/11100）与 BSM 裸 ImportFiles(9999)（其同名遮蔽被 ReplaceUIScript 换上下文入口无效化）；diff 核实不采纳 BSM 三处无效/回归改动（-1 门控注释=无效补丁/OnInputHandler 去动画回调=丢使节簿记/GetData 重排丢 m_kLastCityStates[iPlayer] nil 保护=回归 bug），无文本（BCS 全原版 LOC tag），详见计划.md 条目23 |
| `InGame/DiplomacyRibbonExt/` | 条目24 外交丝带扩展（移植 1.67 DPR/ = Diplomacy Ribbon 扩展/Hide Stats Evolved）+ BSM 观察者兼容：`DiplomacyRibbon_MPT.lua` = 1.67 DPR 完整独立 fork（2007 行，样式基准）+ Better Spectator Mod（工坊 1916397407）观察者逻辑并入（点头像切 POV 三键名 BSM 生态协议原样保留 `UIEvents.UIDoObserverPlayer`/`OBSERVER_ID_<n>`/`DiplomacyRibbon_Click`、观察者丝带显示全部玩家四象限排序、六视图 SpecControl_1..6 + 20 秒轮播、非观战局零侵入）+ 条目14 `MPT_EngineBoost` 引擎精确科文预估（ScienceBoostMeter/CultureBoostMeter，DPR 按目标玩家附加加速 + TCP 定点链，`MPT_GetBoostValue` 兜底回退原公式）；`DiplomacyRibbon.xml` StatStack 分组重构（用户裁决：Group_Stock/Group_Rate/Group_TechCivis/Group_Observer 四组容器组级 SetHide 替代 DPR 约 40 行逐 Label 隐藏与 BSM HideSpecInfo 逐控件隐藏；子控件不带 Hidden="1"——父组隐藏即整组不可见，子控件自身标记会致组显示后仍不可见）；`WorldRankings_MPT.lua` = 原版 Base+Exp2 合并单文件（用户裁决：隐藏其他玩家情报数据——支配页军力评分恒 -1、两处次要决胜摘要移除；不隐藏胜利进度）；参数/热键沿用 1.67 原 key（SETTINGS_DIPLOMACYRIBBON_TPT 三档 / HotKey_DPR_*「;」「'」，同装幂等共享）+ 条目12 MPT_Settings 两行（玩家名/文明名，MPT_Settings_Toggle + TPT_Settings_Toggle 双通道）；两上下文 ReplaceUIScript 100000 + ImportFiles 100010，压过 1.67 DPR 101-121 与 BSM 9999（其 worldtracker/CityBanner/gameplay 脚本不受影响），详见计划.md 条目24 |
| `InGame/`（其余） | 后续 InGame 功能每功能一个自包含子目录（条目12+ 随 1.67 对应缩写目录逐一移植，进度见 计划.md） |

## 加载机制（.modinfo）

LoadOrder 分层规约（注释写死在 modinfo 顶部）：**1-99 配置 | 100-999 文本 | 1000-9999 UI替换 | 10000+ 覆盖型替换 | 99999+ 强制后置**。

- 配置/文本/数据表：`UpdateDatabase` / `UpdateText`，写入前端 Configuration 数据库。
- 同名覆盖：`ImportFiles` 导入与原版同路径文件名的 Lua/XML 实现覆盖；`ReplaceUIScript`（LoadOrder 100000）+ `ImportFiles`（100010）双注册替换整个 Lua Context。
- 条件注册：`ActionCriteria`（条目10 首次引入）——`ModInUse inverse` 按其他 mod 是否启用门控（Disable_MPH），`ConfigurationValueMatches` 按 GameConfiguration 值条件执行 SQL（仅 InGame 侧，游戏开局建库时求值）。
- **新文件必须同时登记进对应 action 和 modinfo 末尾的 `<Files>` 列表**，否则不会被打包加载。
- 功能专属文本仅前端注册（各功能文件夹自己的 UpdateText）；通用文本（FrontEnd/Text/）同时注册进游戏内上下文。

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

通用引擎经验已迁移至 civ6 技能库（`C:/Users/24296/.kimi-code/skills/civ6/`），改动前先查阅：

- **前端环境限制**（空 Context 前端不执行 Lua / include 本 mod 文件在进程首个前端生命周期后静默失效 → 前端代码一律内联进 StagingRoom.lua）：`patterns/references/empty-context.md`「FrontEnd 环境限制」
- **存档读写管线 / ModGroup 组名存储 / 每帧滴答源（AlphaAnim）/ 联机广播流量纪律 / 大 Lua 寄存器上限（do...end 包裹）/ local 声明顺序**：`lua/references/lua-advanced-patterns.md`
- **UI 渲染坑**（SetColor/SetTexture/DDS/auto 宽延伸/ScrollPanel Line 裁剪）：`ui/references/ui-debugging.md`
- **PopupDialog 空 Context 不实例化 → 自研弹窗、AddUserInterfaces 默认 isHidden**：`ui/references/popup-panel-detail.md`
- **小地图矩形只认引擎数据（地图钉）**：`ui/references/ui-advanced-patterns.md`
- **静默失败案例库**（含本 mod 实测第六批 42-46）：`debug/references/workshop-verified-failures.md`
- **LoadOrder 分层 / 广播限窗口 / ActionCriteria 求值时机 / 文本预加载**：`patterns/references/`、`mod/references/criteria-patterns.md`、`text/references/workshop-text-patterns.md`

> 本 mod 专属协议（MPT_ModCheck 三通道 `MPT_MC_LIST/HOSTV/VERS`、沉淀门/超时算法、`MPT_MC_*` 键名）不迁移，保留在 StagingRoom.lua 条目4.1 分区内；改动该分区前先读其头部注释。

## 构建、测试与验证

没有自动化构建与测试。验证流程（DoD）见 civ6 技能 Phase 5：清空 Logs 目录 → 启动游戏加载 mod → 检查 `Database.log` / `Lua.log` / `Modding.log` 无错误 → 进准备房间确认功能实际生效。关键行为（如 SetValue 长度上限、Line 控件裁剪）靠游戏内实测验证后再定稿，实测用临时代码用完即移除。

## modinfo 规约

Mod id GUID 前 8 位为 0；`<Name>/<Description>/<Teaser>/<Authors>/<SpecialThanks>` 全部使用本地化文本多语言（Description 多用 `[NEWLINE]` 排版）；每个 action 配注释。通用规范详见 civ6-mod 子技能。

## 参考路径

- 游戏本体：`D:\Game\Steam\steamapps\common\Sid Meier's Civilization VI`（原版 UI 在 `Base\Assets\UI\`）
- 工坊 mod：`D:\Game\Steam\steamapps\workshop\content\289070`（联机工具箱1.67 = 3693899014）
- 参考实现：`D:\文档\My Games\Sid Meier's Civilization VI\Mods\乔尔定制mod\UI\StagingRoom.lua`
