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
| `InGame/SmartTurnTimer/` | 条目20 智能回合计时器（移植 1.67 CC/Timer TimerPro + NHK/UI/TurnTime_HotKey 热键与按钮，1.67 两 Context 合并单文件）：空 Context `SmartTurnTimer.xml`（仅聊天框旁 P++/P-- 两按钮，默认 Hidden，Lua ChangeParent 到 ChatPanelContainer——LoadScreenClose 后执行防 WorldTracker 未加载）+ 同名 `SmartTurnTimer.lua` 自动执行（AddUserInterfaces 900 + ImportFiles 900，同条目12/13 机制）+ `SmartTurnTimer_InputActions.xml`（GameInfo.InputActions+InputActionDefaultGestures，]/[ 键位，前后端各注册一次——FE 按键绑定界面显示/IG 运行时取用）。房主回合末按「半数真人结束回合用时」PID 自动平衡 TURN_TIMER_TIME 并 BroadcastGameConfig 广播全房（Kp0.5/Ki0.08/Kd0.25/限幅±10/目标18s/下限30s/衰减0.98 原值保留）；宣战+20s/掉线+30s/对城邦+8s 自动加时；议会投票固定 120s；聊天指令 p+/p+++/p-（仅房主监听公共频道）；首回合多人强制 STANDARD。开关：条目12 MPT_Settings 表加行（ParameterId 沿用 1.67 原 key TOOLS_COMMAND，默认 1=开启，每玩家本地开关——房主控自动平衡、非房主控自己按钮/热键，差异：1.67 全局 Game 参数+房主热键不受限），文件加载即订阅 MPT_Settings_Toggle（早于面板 ApplyAll 必达）。优化（文件头横幅留痕）：零全局污染（1.67 十余全局全 local）、DB.MakeHash 替代魔法数 2133509568、四处真人全遍历合并 CountHumans、PID 控制量单次计算+修正量懒算、TURN_TIMER_TIME 非 number 兜底 60 等 nil 防御、冷却 os.time→UI.GetElapsedTime 闭包（条目18修复同款）、IsAnyMultiplayer 联机门控、TurnTimerUpdated 单订阅、文本按实际值修正 1.67「-20s」bug；15 秒滴答音与 NHK 强制结束回合不移植（FEB 已有）；与 1.67 同装双方计时器互相拉扯（用户确认不管控），勿同开 |
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
