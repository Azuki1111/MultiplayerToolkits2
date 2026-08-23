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
- 本 mod 前端功能全部走 FrontEndActions；InGameActions 注册游戏内功能（条目5 起逐条移植 1.67）与通用文本（`IG_Import_Storage` 存储双环境注册已移除，原因见踩坑记录 include 缺陷）。

## 目录结构与功能模块

功能按 `计划.md` 中的「条目」编号组织（条目1/2/3.x/4.x），代码与提交信息均用条目号追溯。

| 路径 | 内容 |
|------|------|
| `MultiplayerToolkits.modinfo` | 模组清单：全部 action 注册、LoadOrder 分层、`<Files>` 文件登记 |
| `计划.md` | 前端设计计划与开发规范（本文件大部分规约的出处，改动规约时需同步更新） |
| `FrontEnd/Config/Config_Base.xml` | 条目2：联机常用游戏设置预设（无蛮族开/回合60秒/允许重复文明领袖/新增「禁用领袖池」参数） |
| `FrontEnd/Config/Config_Disaster.sql` | 条目2：灾害强度下限 0→-1（完全无灾害），LoadOrder 99999 强制后置 |
| `FrontEnd/UI/Options/Options.xml` | 条目1：整文件同名覆盖原版，唯一改动 LAN 玩家名 MaxLength 22→45 |
| `FrontEnd/UI/StagingRoom/StagingRoom.lua`（~6300行） | 条目3 核心：同名覆盖原版准备房间脚本。房间20人上限、快捷开关AI（3.2，含「添加玩家」槽位按钮改版：点击直接添加 AI 玩家而非空缺槽位）、快捷分队（3.3）、房主权限提升改他人队伍/领袖（3.4）、更新公告面板（3.5）、广告轮播（3.6）、ping 常驻显示（3.7，分区内联覆盖原版 UpdateNetConnectionIcon：新增可选第三参数 pingLabel，传 nil 与原版行为一致，含 1.67 黑灯修复）、移除玩家入槽位下拉框（3.8，玩家条目行右侧 X 按钮、列表头「移除玩家」列、竖线 GridLine_5 一并移除，NUM_COLUMNS 5→4（RealizeGridSize 动态索引 GridLine_1..N，不符会索引 nil 中断主 chunk）；g_slotTypeData 新增 kickOption 哨兵项（slotStatus=-2），PopulateSlotTypePulldown 按 IsPlayerKickable 显隐仅房主可见，OnSlotType 命中转 OnKickButton 走原确认弹窗流程，观察者槽位经 AlternateSlotTypePulldown 保留踢出能力）、mod 版本校验（4.1）、非官方模组清单（4.2，侧滑面板显示房间非官方 mod 订阅状态/点击跳工坊）、序列化与数据读写内联分区（4.3预备，文件末尾，ModGroup 组名承载：隐形前缀 [size_0][color:0,0,0,0][MPT_DS][fileName][key][len]数据，干净组流程建组）、玩家标记管理（4.4，文件末尾 4.3 之后：纯本地玩家档案——好友/一般/黑名单标记+记事本，纯本地面板不读房间实况；数据经 4.3 内联 API 存 ModGroup 组名（[MPT_DS][MPT_PlayerInfo][Players]）；右侧内联编辑+保存/取消暂存语义，仅整档删除弹确认；ESC/点外/X 关闭，有未保存改动先弹确认；退房硬重置显示状态（OnHandleExitRequest 调 MPT_PlayerMark_ResetOnExit：丢弃未保存改动、硬关面板/添加弹窗/对话框，选中/搜索/过滤/排序回默认）；头部左侧隐身开关复选框（条目4.8续：勾选=隐藏自身 SQL 公共标记，默认开启，本地存档 MPT_PlayerInfo/Settings（{HiddenSqlMark}）+ 广播 PlayerConfigurations HiddenPkayerInfo，本机 ApplyStatusLabel 兜底同步配置键））、图标查看器（4.5，文件末尾 4.4 之后：移植 EasyIconViewer 3173843667——MPT_IconCollection 顶层 DB.ConfigurationQuery 预加载纯数据，首开面板一次性同步构建全部实例（同原作加载方式，顺带测宽供尺寸排序；逐帧分批构建实测更卡已弃用），搜索过滤/按尺寸排序重建走实例池，横向滚动同原作，点击复制剪贴板，ESC/点外/X/退房关闭）、贴图查看器（4.6，文件末尾 4.5 之后：移植 TextureViewer 本作者旧作——MPT_TextureCollection 顶层 DB.ConfigurationQuery 预加载纯数据（正常序+来源分组排序副本一次算好），首开面板懒构建+实例池复用，搜索过滤/按来源包分组开关，悬停格子自定义 Tooltip 预览（TTManager+本 XML 内 ToolTipType MPT_TextureViewerTooltip，前端可行有 1.67 先例），点击复制贴图名，ESC/点外/X/退房关闭；4.5/4.6 已融合为单面板双页签：页签仿 ClimateScreen TabLedge2+TabButton/TabButtonSelected，ViewerIconContent/ViewerTextureContent 两内容容器显隐切换，统一开关 MPT_Viewer_OpenTab/SelectTab/Close 在 4.6 分区末尾，左下角单入口按钮「查看器」打开并回到上次停留页签）、进房自动更新已启用非官方工坊mod（4.7，文件末尾 4.6 之后：移植 1.67 BSR UpdateAllMods 并优化——OnShow 新会话分支每进房只触发一次（替代 1.67 挂 RealizeGameSetup 重复触发），[modId]=SubscriptionId 单次映射 O(n)，会话幂等守卫+nil 防御，对本局已启用非官方工坊 mod 调 Modding.UpdateSubscription，静默执行仅 Lua.log 留痕，无本地化文本）、房间内玩家标记显示（4.8，文件末尾 4.7 之后：移植 1.67 玩家标记显示层——按前端配置库 TPT_PlayerData（Shared/PlayerMark/PlayerMark_Data.sql，全部类型有效行）登记 SteamID 在 PlayerListEntry 就绪文本（尚未就绪/已就绪/已连接态）上显示标记；本地标记优先（条目4.4 存档 [Id]=记录 哈希，显示 [ICON_x]+标签名、Tooltip 昵称+简要描述换行，不受隐身影响），SQL 标记含日期时效校验与隐身判定（HiddenPkayerInfo=="T" 隐藏 Admin/Normal/Honor 公共标记、Ban 始终显示），Tooltip 优先 ToolTipType（StagingRoom.xml ContextDefaults 内联移植 1.67 TPT_ToolTipType.xml：Bermuda_Triangle 拼图 + AnDe/HuaMing/QingTian_Desc 三张 DDS 图片，DDS 经 ImportFiles 入 VFS）否则 Desc/Name/Icon；数据顶层预加载构建 [SteamID]=记录 哈希表 O(1) 直查（替代 1.67 线性遍历），4.4 面板保存后 SaveToDisk 回调刷新缓存并重刷房间条目（UpdatePlayerEntry 逐个，添加/修改/删除标记后立即生效），刷新时清除残留 ToolTipType（Apply 内字符串 Tooltip 分支与提前 return 分支成对 SetToolTipType(nil)+SetToolTipString，无标记玩家不干预 tooltip 保留原版状态文本），隐身设置按钮后续条目另加）（条目4.8续已实现：玩家标记面板头部复选框「隐藏我的标记」，设置持久化 MPT_PlayerInfo/Settings 并广播） |
| `FrontEnd/UI/StagingRoom/StagingRoom.xml` | 条目3：同名覆盖原版准备房间布局（就绪文本 StatusLabel 已由原版 WrapWidth=120 换行改为 TruncateWidth=180 截断，超宽省略显示） |
| `FrontEnd/UI/AdvancedSetup/AdvancedSetup.lua` | 单人高级设置替换：minPlayers 2→1，允许移除全部 AI、1 人开局 |
| `Shared/` | 双环境共享代码与数据。`MPT_Serialize.lua` 序列化（移植 1.67 BSR，精简为纯数据表单遍递归，%q 转义纯 ASCII）；`MPT_DataStorage.lua` 极简本地数据读写工具：对外仅 `MPT_Storage_SaveData(fileName, key, data, callback)` / `MPT_Storage_LoadData(fileName, key, callback)` / `MPT_Storage_DeleteFile(fileName, callback)` 三个同步回调式全局 API，调用方自选命名空间段与键名段；**ModGroup 组名承载数据**（组名格式 `[size_0][color:0,0,0,0][MPT_DS][fileName][key][len]数据`，隐形前缀使数据组在前端 Mods 界面组列表不可见；len 校验完整性，单组名直存不切块），写前按前缀删旧组、建组走「干净组」流程（建组前批量禁用全部已启用 mod、建后恢复，官方 DisableAllMods 模式），幂等守卫置位在文件末尾（半加载可自愈）。**前端实际承载 = StagingRoom.lua 末尾「条目4.3预备」内联副本**（因引擎 include 缺陷，见踩坑记录），两副本改动必须双向同步。子目录 `PlayerMark/`（原 FrontEnd/PlayerMark/）为玩家标记双环境共享数据，当前仅前端消费 |
| `FrontEnd/Text/` | 通用本地化文本（每语言一个文件：`FrontEnd_zh_Hans_CN.sql` / `FrontEnd_en_US.sql`） |
| `FrontEnd/Changelog/` | 条目3.5 更新公告：`MPT_Changelog` 数据表 + 专属文本 |
| `FrontEnd/Ads/` | 条目3.6 广告轮播：`MPT_Ads` 数据表 + 专属文本 + DDS 贴图（A8R8G8B8 单 mip，经 ImportFiles 入 VFS） |
| `FrontEnd/ModCheck/` | 条目4.1 模组校验：`MPT_ModCheck` 注册表（mod 自我登记 modId）+ 专属文本 |
| `FrontEnd/ModList/` | 条目4.2 非官方模组清单：专属文本（按钮/面板/行状态 Tag；数据走运行时 Modding API，无数据表） |
| `Shared/PlayerMark/` | 条目4.4/4.8 玩家标记：专属文本（按钮/面板/弹窗/确认框 Tag；无数据表，数据走条目4.3 存储管线——ModGroup 组名 [MPT_DS][MPT_PlayerInfo][Players]）+ 条目4.8 数据表 `TPT_PlayerData`（`PlayerMark_Data.sql`，移植 1.67 全部类型有效行，去注释/过期/测试行）+ 3 张标记图片 DDS（AnDe/HuaMing/QingTian_Desc_Texture，经 ImportFiles 入 VFS 供 ToolTipType 用） |
| `FrontEnd/IconViewer/` | 条目4.5 图标查看器：`MPT_IconCollection` 数据表（移植 EasyIconViewer 5056 图标，表名改 MPT_ 前缀）+ 专属文本 |
| `FrontEnd/TextureViewer/` | 条目4.6 贴图查看器：`MPT_TextureCollection` 数据表（移植 TextureViewer 游戏本体+全部DLC UI 贴图 5017 行，表名改 MPT_ 前缀）+ 专属文本 |
| `InGame/RevealMapCorners/` | 条目5 显示地图角落（移植 1.67 RMC）：`RevealMapCorners.xml`（空 Context）+ `RevealMapCorners.lua`（LoadScreenClose 时 `LuaEvents.MapPinPopup_RequestMapPin` 建两个极地真实地图钉 + `UIManager:DequeuePopup` 弹掉编辑弹窗，撑开引擎小地图世界矩形使全球比例；原理见踩坑记录「小地图矩形只认引擎数据」；副作用：留两个可见 pin；AddUserInterfaces Context=InGame 注册） |
| `InGame/GreatPersonNames/` | 条目6 伟人名字更新（移植 1.67 GPN）：`GreatPersonNames.sql` 魔女环境检测（仅当 LocalizedText 已含魔女改写的伟人标记 IMHOTEPI='号码菌' 时）把炼金联赛纪念伟人名字写入 zh_Hans_CN，LoadOrder 5000000 压后覆盖，非魔女环境保护原版名字；UpdateText 注册（InGame） |
| `InGame/EndGameMenu/` | 条目7 战败后观战按钮（移植 1.67 EGM 并修复反复弹出 bug）：`EndGameMenu.xml` 整文件同名覆盖原版（Exp2 版）在 ButtonStack 追加「观看」按钮；`EndGameMenu_MPT.lua` 经原版 include("EndGameMenu_", true) 通配符注入 EndGameMenu 上下文（点击置本地屏蔽标志 + 完整 Close() 释放暂停/弹窗 + 替换 OnPlayerDefeat 拦截重入，修复 1.67 仅 SetHide 导致画面反复弹出）；ImportFiles 注册（LoadOrder 30000） |
| `InGame/WorldTracker/` | 条目8 WorldTracker 快捷操作面板（自定义功能，仿作弊面板 mod 挂载方式）：`MPT_QuickPanel.xml` 空 Context（标题「快捷操作」+ 展开区「投降」「重新开始」「玩家标记」三按钮 + 投票区 VoteArea）；`MPT_QuickPanel.lua` 同名自动执行，LoadGameViewStateDone 时 LookUpControl("/InGame/WorldTracker/PanelStack") + ChangeParent + AddChildAtIndex(1) 挂载，点击标题展开/收起（条目11 起展开高度 146、QuickSepBottom 144），每帧轮询投票状态刷新；「投降」= 团队投降投票（条目8续）；「重新开始」响应未配置 TODO；「玩家标记」= LuaEvents.MPT_PlayerMark_Toggle 开关条目11 游戏内玩家标记面板；AddUserInterfaces(Context=InGame, LoadOrder=900) + ImportFiles + UpdateText 注册 |
| `InGame/SurrenderVote/` | 条目8续 团队投降投票（Gameplay 侧）：`SurrenderVote_Gameplay.lua` 经 AddGameplayScripts 注册，`GameEvents.MPT_SurrenderVote.Add` 接收 UI 的 EXECUTE_SCRIPT（OnStart="MPT_SurrenderVote"，UI→房主，不用 Chat 指令）——房主分支校验（发起人同队存活/本时代未投过/投票者同队未投过）→ 记票 → 票数 ≥ 半数（agree>=total/2）→ 该队城市全部叛变自由城（CityManager.TransferCityToFreeCities，仿乔尔mod RegicideVictory 自定义战败范式，不销毁城市/单位、不做引擎判负，Game:SetProperty MPT_SURRENDER_TEAM_<team> 标记判负）；频率限制每时代每队一次（MPT_SURRENDER_VOTE_<era>_<team>），票数存 MPT_SURRENDER_VOTES_<team>="agree/total"、每投票者一键防重复；UpdateText 注册（InGame） |
| `InGame/TopPanelExt/` | 条目9 顶部面板扩展（移植 1.67 TPE）：`TopPanelExt.lua` 经 ReplaceUIScript（LuaContext=TopPanel, LoadOrder 100000）投递——基类探测 include TopPanel_Expansion2/1/TopPanel 后覆盖 RefreshYields/LateInitialize/RefreshResources；游戏内顶部面板追加 食物/生产力/人口/奢侈品 四个统计按钮与联动 Tooltip（逐城市明细经 LuaEvents.TopPanelToolTip_*_Refresh 事件驱动，`TopPanelExt_TT.lua` 渲染）；战略资源 Tooltip 追加队友战略资源清单；交易限制标志 isLuxuries/isStrategicsTradingAllowed 接线条目10 统一解析器 MPT_TradeRules.lua（条目9 移植时曾恒 true 占位，条目10 修复）与队伍/FFA 检测（IsFFA：全无队伍时显示所有玩家重复奢侈品）；`TopPanelExt_TT.xml` 经 AddUserInterfaces（Context=InGame）定义 TooltipType + 3 实例模板；ImportFiles（100010）双 Lua 入 VFS；UpdateText 注册（InGame）；优化：奢侈品类型查表 O(1)、战略资源表轻量化 {Index,Hash}、队友列表每刷新周期缓存、文本预加载缓存 + 带参数 tag 拆 PRE/SUF、取消 1.67 CanRefresh 冻结缺陷。条目9续 战略资源点击发送交易：`TopPanel.xml` 整文件同名覆盖 Base（唯一改动 ResourceInstance 模板保持 Label ResourceText 原版渲染，新增透明 BoxButton ResourceClick 覆盖层 Color 0,0,0,0 NoStateChange 无纹理，接收点击 + 同步 Tooltip，Container 高度固定 24 不变形；弹窗 MPT_TPE_SendPopup 内嵌同 Context 全屏居中），点击战略资源弹窗列出 我方持有量/各可接收队友空余（存储上限-持有量，同队已相遇非交战）/合计可发送量，确认后按空余降序向每队友分别发 DealManager PROPOSED 提案（AddItemOfType(RESOURCES,我方)+SetAmount 30回合+SendWorkingDeal，对方手动接受）；禁止交易模式（isStrategicsTradingAllowed==false）点击不动作 |
| `InGame/DealRestriction/` | 条目10 交易限制与外交限制（移植 1.67 DDV 整模块）：`Config_Deal.xml`（交易设置四模式 常规=仅禁城市/经典=禁金币+城市/独立=全禁仅放行奢侈品/自定义=8 禁止项+无代表团，ParameterDependencies 仅自定义可见）+ `Config_Friendship.xml`（无友谊默认开）+ `Config_MakePeace.xml`（和解三模式，默认不生效）；`MPT_TradeRules.lua` 统一解析器（`MPT_ResolveTradeRules()` 返回八键布尔表，预设优先于自定义布尔；TopPanel 与 DiplomacyDealView 两上下文各自 include 共用，替代 1.67 的 8 个松散全局变量）；`DiplomacyDealView_MPT.lua` 经原版 `include("DiplomacyDealView_", true)` 通配注入交易界面（Base/Exp2 均有），工厂生成 PopulateAvailable* 八类覆盖（被禁返回 1 防无法签同盟，Favor/Gold 不隐藏容器其余隐藏）；SQL/ 四执行文件经 **ActionCriteria**（本 mod 首个，ConfigurationValueMatches 按 GameConfiguration 值）条件执行（LoadOrder 20001/999999）；参数定义与 DealView 导入门控 `Disable_MPH`（ModInUse inverse MPH 619ac86e 防 Parameters 主键冲突），文本双环境注册不门控 |
| `InGame/PlayerMark/` | 条目11 游戏内玩家标记面板（自定义功能，移植条目4.4 PlayerMarkPanel 到 InGame）：`MPT_PlayerMark.xml` 整体复制 StagingRoom.xml 条目4.4 区块零尺寸改动（1024×parent 全高面板 + ModalBlocker 点外关闭 + 添加弹窗 + MakeInstance PopupDialog 确认框，EndGameMenu 同款）；`MPT_PlayerMark.lua` 复制 4.4 面板逻辑（存储层 include Shared/MPT_DataStorage.lua——游戏内 include mod VFS 文件可靠，Shared 独立文件本就是为游戏内消费方保留；与前端 4.4 同一份 [MPT_DS][MPT_PlayerInfo][Players] 存档双向互通）；打开经 QuickPanel 展开区「玩家标记」按钮 → LuaEvents.MPT_PlayerMark_Toggle；ESC 走 ContextPtr:SetInputHandler（EndGameMenu 同款，添加弹窗在时先关弹窗）；与前端差异：删 OnSlotNameClick 槽位热区联动、删 4.8 缓存刷新调用、删 ResetOnExit（退主菜单即销毁 UI 状态）、Open/Close 首尾带 ContextPtr:SetHide（AddUserInterfaces 上下文默认 isHidden=true）；AddUserInterfaces(900) + ImportFiles(900，含 Shared 两存储文件入 VFS) + UpdateText(100，与前端同一批 PlayerMark 文本) 注册 |
| `InGame/`（其余） | 后续 InGame 功能每功能一个自包含子目录（条目12+ 随 1.67 对应缩写目录逐一移植，进度见 计划.md） |

## 加载机制（.modinfo）

LoadOrder 分层规约（注释写死在 modinfo 顶部）：**1-99 配置 | 100-999 文本 | 1000-9999 UI替换 | 10000+ 覆盖型替换 | 99999+ 强制后置**。

- 配置/文本/数据表：`UpdateDatabase` / `UpdateText`，写入前端 Configuration 数据库。
- 同名覆盖：`ImportFiles` 导入与原版同路径文件名的 Lua/XML 实现覆盖；`ReplaceUIScript`（LoadOrder 100000，压过 MPH 的 9999）+ `ImportFiles`（100010）双注册替换整个 Lua Context。
- 条件注册：`ActionCriteria`（条目10 首次引入）——`ModInUse inverse` 按其他 mod 是否启用门控（Disable_MPH），`ConfigurationValueMatches` 按 GameConfiguration 值条件执行 SQL（仅 InGame 侧，游戏开局建库时求值）。
- **新文件必须同时登记进对应 action 和 modinfo 末尾的 `<Files>` 列表**，否则不会被打包加载。
- 功能专属文本仅前端注册（各功能文件夹自己的 UpdateText）；通用文本（FrontEnd/Text/）同时注册进游戏内上下文。

## 开发规范（源自 计划.md，务必遵守）

- **流程**：按 计划.md 条目顺序依次实现，每完成一条立即停止等待用户确认；git 管理，每完成一次修改任务后提交。
- **git 提交规则**：**每完成一次修改任务（含功能实现、修复、文档/规约同步）后必须主动提交 git，无需等待用户另行指示**（本条为长期授权）。提交信息格式为「条目X.Y：……」「条目X.Y修复：……」，与条目号可追溯；一次任务的相关文件（代码 + 计划.md/AGENTS.md 同步 + modinfo 版本递增）合并在同一次提交。
- **修改留痕**：所有对原版文件的改动用注释横幅标记旧代码与新代码，格式：

```lua
-- ============================================================================
-- 修改房间最大人数 12 -> 20
-- g_currentMaxPlayers = math.min(MapConfiguration.GetMaxMajorPlayers(), 12);
g_currentMaxPlayers = math.min(MapConfiguration.GetMaxMajorPlayers(), 20);
-- ----------------------------------------------------------------------------
```

- 新功能函数必须带注释与用法说明；同一类函数集中放在规范的区域（StagingRoom.lua 末尾按条目分区，如「条目3.2 快捷开关AI」「条目4.1 版本校验」各成一节）。
- **本地化一律用 SQL**（`INSERT OR REPLACE INTO LocalizedText`），通用文本集中放 `FrontEnd/Text/` 每语言一个文件、同语言多行 VALUES；功能专属文本随功能文件夹存放。
- **本地化文本预加载缓存（StagingRoom.lua）**：本 mod 新增文本在 Lua 中使用时，按条目分区头后集中预加载为 `local XxxStr = Locale.Lookup("LOC_...")` 缓存，运行时直接引用变量、不再内联 `Locale.Lookup("LOC_...")`。**带参数文本不用 `Locale.Lookup(tag, args)`**，改为「无参数纯文本 tag + Lua `..` 拼接」（如 4.1 明细行 `info.Name .. ModCheckDetailMismatchPrefixStr .. MPT_GetModTitle(m.ModId) .. ModCheckDetailMismatchSuffixStr`，把原 MISMATCH 拆成 PREFIX/SUFFIX 两个无参数 tag）。缓存块放在对应条目分区头之后、本分区函数定义之前（避免「声明点之前引用 local 解析为全局」，参照 3.7 分区）。不预加载：XML `String=`/`ToolTip=` 属性（XML 系统自动解析）、数据驱动的动态 key（`row.TextTag`、`adEntry.ToolTipTag`、`Modding` 的 Name/Description 等运行时才知道的 tag）。
- 代码风格遵循游戏官方 Lua 风格（Tab 缩进、`local x : number` 类型标注、行尾分号、函数头注释块）。
- 涉及深度设计疑问时使用 deep-probe 技能追问；文明6 mod 开发知识查 civ6 技能。

## modinfo 规约

- Mod id GUID 前 8 位为 0。
- `<Name>/<Description>/<Teaser>/<Authors>/<SpecialThanks>` 等全部使用本地化文本多语言；Description 多用 `[NEWLINE]` 排版。
- 每个 action 配注释，简要概括该文件的修改内容和作用。

## 构建、测试与验证

没有自动化构建与测试。验证流程（DoD）：**文件写完 ≠ 完成**。

1. 清空日志目录 `C:\Users\%USERNAME%\AppData\Local\Firaxis Games\Sid Meier's Civilization VI\Logs`。
2. 启动游戏并加载 mod。
3. 检查 `Database.log` / `Lua.log` / `Modding.log` 无错误，并进入准备房间确认功能实际生效。
4. 关键行为（如 SetValue 长度上限、Line 控件裁剪）靠游戏内实测验证后再定稿，实测用临时代码用完即移除。

## 关键实现细节（踩坑记录，改动前先读）

- **MPT_ModCheck 校验协议**（StagingRoom.lua 条目4.1 区）：房主经 `PlayerConfigurations value` + `BroadcastPlayerInfo` 三通道（`MPT_MC_LIST` / `MPT_MC_HOSTV` / `MPT_MC_VERS`）广播 modId 清单与 Version 指纹；第三方 mod 用 `CREATE TABLE IF NOT EXISTS MPT_ModCheck` + `INSERT OR REPLACE` 自我登记即可接入，加载顺序无关（ModId 大小写须与 `GameConfiguration.GetEnabledMods()` 的 Id 完全一致）。条目4.1修复批次新增：进房 3 秒沉淀门后才读 SQL 清单/首发首报；客机回报经统一通道 `MPT_RequestReport` 按 `playerID%4` 秒抖动摊平、VERS 值未变不广播；「未回报」超时按 `max(清单发布时刻, 该玩家进房 JoinTime)` 起算（迟到进房/换槽有自己的 10 秒窗口）；校验通过/失败迁移时房主回调 `CheckGameAutoStart`（倒计时自动恢复/压停），`MPT_PublishCheckList` 末尾也直调一次（倒计时中重新校验立即压停）；本机 mod 下载终态（`OnModStatusUpdated` 非 DOWNLOADING 且为本机）静默 3 秒后房主重发清单/客机重报；发布即复位「放弃验证」（放弃仅对当轮 rev 有效）；断线重连/换槽致本机状态条目新建时经统一通道兜底补报（rev 未变时正常路径不重报）。
- 校验发布/回报必须限定准备房间可见窗口，否则隐藏期 BroadcastPlayerInfo 会触发槽位漂移风暴（详见 git 历史条目4.1修复）。
- Lua 状态跨房间存续：新会话必须调用 `MPT_ResetModCheckSession()` 重置校验生命周期。
- 声明点之前引用的 `local` 会解析为全局（g_mpt_checkSkipped 等曾因误用 local 失效），新增全局状态注意声明顺序。
- UI 实测坑：ScrollPanel 内 Line 控件顶部两行高区域被裁剪不渲染（改用细 Box）；SetColor 对 Label 无效（用 `[color:R,G,B,A]` 文本标签）；SetTexture 对轮播贴图静默无效（改 Button 内嵌 Image 子控件）；DDS 需 A8R8G8B8 单 mip；auto 宽 Container 内子控件 `Size="parent"` 宽度会在 Stack 末位实例上误解析延伸到屏幕右缘（点击层吞掉大片区域，须 Lua 显式 `SetSizeX` 跟随文本宽，条目9续 ResourceClick 踩过）。
- **存储管线实测定论**（条目4.3预备 Phase0/1/2 三轮冒烟；**Civ6Cfg 方案已弃用移除**——存储已切换 ModGroup 组名，以下实测结论作为引擎行为知识留存）：
  - **前端无法新建 UI Context**：AddUserInterfaces + 空 Context 实测 Lua 根本不执行（日志零输出），前端功能必须依附既有界面上下文（存储模块现由 StagingRoom 内联承载，见下条）；前端各 Context 脚本在启动时即执行并注册事件（JoiningRoom 事件在进房前触发为证）。
  - **【重大】前端 include() 本 mod 的 Lua 文件只在进程首个前端生命周期内真正执行**：经 ImportFiles 注册的 mod Lua 文件，首次前端启动时 include 正常；**开一局游戏退回主菜单后，前端重建的新 Lua 状态下 include 静默不执行**——`pcall(include)` 返回成功与一个 table，但文件体零执行、无任何报错/日志，全局 API 全缺。单变量实验证明与 InGame 双环境注册无关（禁用后故障依旧），系引擎缺陷。ReplaceUIScript 投递的 StagingRoom.lua 每次前端重建都可靠重执行 → **前端消费本 mod 自己的 Lua 一律内联进 StagingRoom.lua，勿用 include**；引擎自身加载的脚本（Test.LUA）在新状态下仍正常重执行。条目3.7 原同名覆盖文件 `Scripts/NetConnectionIconLogic.lua` 亦已内联进 StagingRoom.lua 条目3.7 分区（文件与 action 注册已移除），前端不再依赖任何本 mod 经 ImportFiles 注册的 include 文件。另实测：StagingRoom Lua 状态跨房间存续（反复建房退房不重跑顶层脚本），只有前端整体重建才换状态。
  - `Network.LoadGame` 是**重置语义**（不在存档里的 GameConfiguration 键被清掉）→ LoadData 会把 GameConfiguration 替换为该文件快照。**GAME_CONFIGURATION 存档实测还含房间槽位身份（「名字@网络ID」）与 Players:* 配置**：房间内裸 LoadGame 会把旧快照盖回槽位（条目4.4 换槽后原槽位显示旧房客的 bug 根因）→ **LoadData 已内置快照/恢复链**（先 SaveGame 当前实况成临时档 `MPT_RestoreSnapshot`，读数据档取键后立即 LoadGame 临时档恢复并删除），准备房间内可安全调用；临时档崩溃残留无害（下次覆盖/删除）。
  - **`.Civ6Cfg` 文件名长度上限 = Windows MAX_PATH(260) − 存档目录完整路径长度 − 9**（`.Civ6Cfg` 8 字符 + 终止符）：本机目录路径 56 字符，实测文件名 195 字符写读正常、196 起 `SaveGame` 失败（`SaveComplete` 回调 eResult 非 0）；不超限时落盘文件名与请求完全一致、无截断。上限随机器存档路径长度变化，调用方文件名应远低于此（建议 <100 字符）。
  - 存档文件夹由保存时 `Type` 决定（Saves\Single / Saves\Multi）；文件列表菜单按**当前环境**枚举（主菜单列 Single、联机房间列 Multi）→ 本模块保存恒用 `SaveTypes.SINGLE_PLAYER`，读写同目录。
  - 前端 `Events.SaveComplete`/`Events.LoadComplete` 均触发（eResult=0, eFileType=1）；GameConfiguration 单值 512000 字符完整往返（未触顶），高频（5秒级）写读+反复落盘可靠。
  - `UI.QuerySaveGameList` 直查可用（无弹窗）：结果经 **`LuaEvents.FileListQueryResults`** 回调（引擎触发），**必须按自身 requestID 认领**（启动期 MainMenu 自己也在查 MOST_RECENT_ONLY，不过滤会误收其 GAME_STATE 结果导致判断落空，实测踩过），用完 `UI.CloseFileListQuery`；完整签名 5 参 `UI.QuerySaveGameList(location, gameType, options, fileType, directoryPath)`，directoryPath 恒传 `""` 用默认目录（LoadSaveMenu_Shared.lua:1060 / MainMenu.lua:1547-1616）；并发查询会互相顶掉 → 本模块以 FIFO 队列保证任时刻只有一个读写作业在途。
  - **任意路径读写配置档（实测成立）**：`Network.SaveGame` 带 `Path` 字段（官方仅 WORLDBUILDER_MAP 用）对 GAME_CONFIGURATION 生效；`Network.LoadGame` 用构造表 `{Name,Path,Location,Type,FileType}` 可从任意路径读回（哨兵键校验一致）；`SaveLocationOptions.DIRECTORIES` + directoryPath 可枚举任意目录（文件与子目录混列，子目录条目有 IsDirectory）；`UI.GetSaveLocationPath` 返回存档目录磁盘真实路径。本模块仍存 Saves\Single 标准目录。
  - WorldBuilder 地图存取即同一管线（`SaveTypes.WORLDBUILDER_MAP` + DIRECTORIES + `UI.GetVolumes()`），但地图二进制需 WB 会话，不能承载通用数据。
  - **客机读写实测通过**：非房主玩家在他人房间内 SaveData/LoadData 全流程正常（5 秒间隔×5 轮延时读写，时间戳链路逐轮传递完整），联机房间内客机 SaveGame/LoadGame 不受限。
  - **ModGroup 组名存储实测定论**（条目4.4 存储回归探路，MPT_GRTEST 三轮实测）：`Modding.CreateModGroup(name, group)` 组名长度上限 **>67108864（64MB）未触顶**（16384~67108864 翻倍阶梯全过，SQLite TEXT 无可用上限；数十 MB 档读写有明显卡顿但无卡死）；读回 `Modding.GetModGroups()` 与请求名**逐字符相等**无截断；引号/反斜杠/方括号混合组名（模拟 %q 序列化产物）2000 长往返完整；**创建即落库** Mods.sqlite `ModGroups` 表（列：ModGroupRowId/Name/CanDelete/Selected/SortIndex，Lua 侧 Handle 即 ModGroupRowId）；**跨进程冷启动读回验证通过**（重启游戏后新进程 `GetModGroups()` 读回上轮遗留组，长度与内容逐字符相等）。1.67 的 2000 字符切块是保守设计而非引擎限制，迁移时切块大小可大幅放宽。**本方案已实装为条目4.3预备存储管线**：组名格式 `[size_0][color:0,0,0,0][MPT_DS][fileName][key][len]数据`（隐形前缀使数据组在前端 Mods 界面组列表不可见），单组名直存不切块，写前按前缀删旧组，建组走「干净组」流程（建组前批量禁用全部已启用 mod、建后恢复，官方 DisableAllMods 模式：GetInstalledMods 条目 .Enabled 筛选、DisableMod/EnableMod 表参数批量操作）。
- **前端 UI 计时/周期任务**：`ContextPtr:SetUpdateHandler` 是 Civ5 API，Civ6 不存在（调用即主 chunk 报错「function expected instead of nil」+ Error loading file）；`Events.MultiplayerPingTimesChanged` 在客机房间实测不触发，不能当滴答源；正确做法 = XML 放 `AlphaAnim Size="1,1" AlphaStart="0" AlphaEnd="0"`（不可见、隐藏也持续 tick，原版 CountdownTimerAnim 同款）+ `RegisterAnimCallback` 拿每帧回调再按需门控。
- **StagingRoom.lua 寄存器上限**：Civ6 Lua 单函数（含主 chunk）寄存器有限，本文件各条目分区顶层 local 累积到 ~190+ 时编译报 `Function or expression requires too many registers (too complex)`（条目4.6 加入时实测触发）。对策：每个条目分区整体用块级 `do ... end` 包裹（4.3/4.4/4.5/4.6 均已包裹，块内 local 随块结束释放寄存器；块内全局函数/回调以 upvalue 捕获 local，功能不变）。**新增分区必须沿用 do...end 包裹**；分区 local 不得被分区外引用（包裹前已核查四个分区外部引用均为 0）。
- **小地图矩形只认引擎数据，不认 UI 控件**（条目5 实测定论）：小地图世界矩形由引擎 `UI.GetMinimapWorldRect()` 计算，仅纳入游戏世界数据（**地图钉坐标**等），**UI 控件不参与包围盒**。实测无效的自制方案：WorldAnchor + 全透明 Box、WorldAnchor + 带纹理 Image、`ChangeParent` 把根容器移到 `/InGame/WorldViewControls`（AddUserInterfaces 上下文被 `InGame.lua:348` 硬编码挂 `AdditionalUserInterfaces` 且 `isHidden=true` 加载，但即使移入世界层也不生效）。有效方案 = 真实地图钉数据：`PlayerConfigurations:GetMapPin(x,y)` 是 **create-or-get**（官方 `WorldInput.PlaceMapPin` 即靠它建 pin），`LuaEvents.MapPinPopup_RequestMapPin(x,y)` 建 pin 后会弹编辑弹窗，用 `UIManager:DequeuePopup` 立即弹掉（1.67 RMC 手法）。副作用：留下可见 pin（进存档/钉列表）。InGame.xml 被 Base/Expansion1/Expansion2 三份覆盖，覆盖它注入 LuaContext 风险大，非必要不采用。
- **Modding 组存储 API 与 Steam Overlay 游戏内可用**（条目11 用户实证）：`Modding.CreateModGroup`/`GetModGroups`/`DeleteModGroup`/`GetInstalledMods`/`DisableMod`/`EnableMod`/`GetCurrentModGroup`/`SetCurrentModGroup`（原版仅前端 Mods.lua 在用）与 `Steam.ActivateGameOverlayToUrl`（原版仅前端 Mods.lua/Lobby.lua 在用）在 InGame Lua 状态同样可调 → 条目4.3 ModGroup 组名存储管线游戏内直接 include Shared/MPT_DataStorage.lua 即可用，前后端同一份存档互通；游戏内面板带 Steam 主页按钮无需防御。另：AddUserInterfaces 上下文默认 isHidden=true，自家控件留在本上下文渲染时，Open/Close 必须带 `ContextPtr:SetHide`（条目11 MPT_PlayerMark 惯例；条目8 QuickPanel 因 ChangeParent 进 WorldTracker 不受此限）。
- **引擎内置 PopupDialog 模板在 AddUserInterfaces 空 Context 不实例化**（条目11 实测定论）：`<MakeInstance Name="PopupDialog" />` 只在标准官方 Context（FrontEnd 各屏 / InGame.xml 注册的 EndGameMenu、DiplomacyActionView 等）生效；自定义 AddUserInterfaces 空 Context 下实例化出的 PopupRoot 等控件**不进本上下文 Controls**，`PopupDialog:new(...)` 在构造函数 `SetSize→IsOpen→Controls.PopupRoot` 处 `attempt to index a nil value` 报错（条目11 首版踩中，Error loading file）。对策：自研确认/提示弹窗（仿 PlayerMarkEditPopup 的 DropShadow2+WindowFrameTitle 结构，纯自家控件，回调存全局变量由按钮触发），自定义上下文一律不复用 PopupDialog。

## 参考路径

- 游戏本体：`D:\Game\Steam\steamapps\common\Sid Meier's Civilization VI`（原版 UI 在 `Base\Assets\UI\`）
- 工坊 mod：`D:\Game\Steam\steamapps\workshop\content\289070`（联机工具箱1.67 = 3693899014）
- 参考实现：`D:\文档\My Games\Sid Meier's Civilization VI\Mods\乔尔定制mod\UI\StagingRoom.lua`
