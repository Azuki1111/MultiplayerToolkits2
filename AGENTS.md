# 联机工具箱 2.0 前端（Multiplayer Toolkits 2.0 FrontEnd）

## 项目概览

《文明6》（Sid Meier's Civilization VI）**前端（FrontEnd）模组**，作者 号码菌Synora。融合「联机工具箱 1.67」与 MPH（Multiplayer Helper）的前端功能并加以优化，主要面向多人联机准备房间体验。模组校验 / BP 功能改编自 MPH（MIT 协议 © 2024 BetterBalancedGame），部分功能参考联机工具箱 1.67 与乔尔定制mod。

- **不是常规软件工程**：没有 pyproject.toml / package.json 等构建配置，没有测试框架，没有 CI/CD。
- 技术栈：Firaxis 模组体系 = `.modinfo` 清单 + 前端 Configuration 数据库 SQL/XML + UI 替换 Lua/XML + DDS 贴图。
- 部署方式：整个目录放在 `D:\文档\My Games\Sid Meier's Civilization VI\Mods\` 下即被游戏加载（本目录即模组本体）。`Core/`、`Tools/` 目前为空目录（预留）。
- 版本管理：git，提交信息格式为「条目X.Y：……」「条目X.Y修复：……」。

### Mod 清单

- Mod id：`00000000-7369-4685-ab5f-bf77bc22b54e`（规约：GUID 前 8 位为 0）
- `<Version>11</Version>` 是模组版本一致性校验指纹，**结构性更新必须递增**
- `AffectsSavedGames=0`，`CompatibleVersions=1.2,2.0`
- 本 mod 前端功能全部走 FrontEndActions；InGameActions 仅注册同一份通用文本文件（`IG_Import_Storage` 存储双环境注册已移除，原因见踩坑记录 include 缺陷）。

## 目录结构与功能模块

功能按 `计划.md` 中的「条目」编号组织（条目1/2/3.x/4.x），代码与提交信息均用条目号追溯。

| 路径 | 内容 |
|------|------|
| `MultiplayerToolkits.modinfo` | 模组清单：全部 action 注册、LoadOrder 分层、`<Files>` 文件登记 |
| `计划.md` | 前端设计计划与开发规范（本文件大部分规约的出处，改动规约时需同步更新） |
| `Config/Config_Base.xml` | 条目2：联机常用游戏设置预设（无蛮族开/回合60秒/允许重复文明领袖/新增「禁用领袖池」参数） |
| `Config/Config_Disaster.sql` | 条目2：灾害强度下限 0→-1（完全无灾害），LoadOrder 99999 强制后置 |
| `UI/Options/Options.xml` | 条目1：整文件同名覆盖原版，唯一改动 LAN 玩家名 MaxLength 22→45 |
| `UI/StagingRoom/StagingRoom.lua`（~5500行） | 条目3 核心：同名覆盖原版准备房间脚本。房间20人上限、快捷开关AI（3.2）、快捷分队（3.3）、房主权限提升改他人队伍/领袖（3.4）、更新公告面板（3.5）、广告轮播（3.6）、ping 常驻显示（3.7，分区内联覆盖原版 UpdateNetConnectionIcon：新增可选第三参数 pingLabel，传 nil 与原版行为一致，含 1.67 黑灯修复）、mod 版本校验（4.1）、非官方模组清单（4.2，侧滑面板显示房间非官方 mod 订阅状态/点击跳工坊）、序列化与数据读写内联分区（4.3预备，文件末尾）、玩家标记管理（4.4，文件末尾 4.3 之后：纯本地玩家档案——好友/一般/黑名单标记+记事本，纯本地面板不读房间实况；数据经 4.3 内联 API 存 MPT_PlayerInfo.Civ6Cfg，键 Players；右侧内联编辑+保存/取消暂存语义，仅整档删除弹确认；ESC/点外/X 关闭，有未保存改动先弹确认） |
| `UI/StagingRoom/StagingRoom.xml` | 条目3：同名覆盖原版准备房间布局 |
| `UI/AdvancedSetup/AdvancedSetup.lua` | 单人高级设置替换：minPlayers 2→1，允许移除全部 AI、1 人开局 |
| `Storage/` | 条目4.3预备：序列化与数据读写的**独立文件副本**（保留给未来游戏内消费方；当前未在任何 action 注册、不被游戏加载）。`MPT_Serialize.lua` 序列化（移植 1.67 BSR，精简为纯数据表单遍递归，%q 转义纯 ASCII）；`MPT_DataStorage.lua` 极简本地数据读写工具：对外仅 `MPT_Storage_SaveData(fileName, key, data, callback)` / `MPT_Storage_LoadData(fileName, key, callback)` / `MPT_Storage_DeleteFile(fileName, callback)` 三个异步回调式全局 API，调用方自选 .Civ6Cfg 文件名与键名；内建 FIFO 作业队列（任时刻一作业在途，防并发查询互顶），写前清旧块、切块 128000、恒 SINGLE_PLAYER 落盘 Saves\Single，LoadData 每次都真实读盘；幂等守卫置位在文件末尾（半加载可自愈）。**前端实际承载 = StagingRoom.lua 末尾「条目4.3预备」内联副本**（因引擎 include 缺陷，见踩坑记录），两副本改动必须双向同步 |
| `FrontEnd/Text/` | 通用本地化文本（每语言一个文件：`FrontEnd_zh_Hans_CN.sql` / `FrontEnd_en_US.sql`） |
| `FrontEnd/Changelog/` | 条目3.5 更新公告：`MPT_Changelog` 数据表 + 专属文本 |
| `FrontEnd/Ads/` | 条目3.6 广告轮播：`MPT_Ads` 数据表 + 专属文本 + DDS 贴图（A8R8G8B8 单 mip，经 ImportFiles 入 VFS） |
| `FrontEnd/ModCheck/` | 条目4.1 模组校验：`MPT_ModCheck` 注册表（mod 自我登记 modId）+ 专属文本 |
| `FrontEnd/ModList/` | 条目4.2 非官方模组清单：专属文本（按钮/面板/行状态 Tag；数据走运行时 Modding API，无数据表） |
| `FrontEnd/PlayerMark/` | 条目4.4 玩家标记管理：专属文本（按钮/面板/弹窗/确认框 Tag；无数据表，数据走条目4.3 存储管线，专属文件 MPT_PlayerInfo.Civ6Cfg 键 Players） |

## 加载机制（.modinfo）

LoadOrder 分层规约（注释写死在 modinfo 顶部）：**1-99 配置 | 100-999 文本 | 1000-9999 UI替换 | 10000+ 覆盖型替换 | 99999+ 强制后置**。

- 配置/文本/数据表：`UpdateDatabase` / `UpdateText`，写入前端 Configuration 数据库。
- 同名覆盖：`ImportFiles` 导入与原版同路径文件名的 Lua/XML 实现覆盖；`ReplaceUIScript`（LoadOrder 100000，压过 MPH 的 9999）+ `ImportFiles`（100010）双注册替换整个 Lua Context。
- **新文件必须同时登记进对应 action 和 modinfo 末尾的 `<Files>` 列表**，否则不会被打包加载。
- 功能专属文本仅前端注册（各功能文件夹自己的 UpdateText）；通用文本（FrontEnd/Text/）同时注册进游戏内上下文。

## 开发规范（源自 计划.md，务必遵守）

- **流程**：按 计划.md 条目顺序依次实现，每完成一条立即停止等待用户确认；git 管理，每完成一次修改任务后提交。
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

- **MPT_ModCheck 校验协议**（StagingRoom.lua 条目4.1 区）：房主经 `PlayerConfigurations value` + `BroadcastPlayerInfo` 三通道（`MPT_MC_LIST` / `MPT_MC_HOSTV` / `MPT_MC_VERS`）广播 modId 清单与 Version 指纹；第三方 mod 用 `CREATE TABLE IF NOT EXISTS MPT_ModCheck` + `INSERT OR REPLACE` 自我登记即可接入，加载顺序无关。
- 校验发布/回报必须限定准备房间可见窗口，否则隐藏期 BroadcastPlayerInfo 会触发槽位漂移风暴（详见 git 历史条目4.1修复）。
- Lua 状态跨房间存续：新会话必须调用 `MPT_ResetModCheckSession()` 重置校验生命周期。
- 声明点之前引用的 `local` 会解析为全局（g_mpt_checkSkipped 等曾因误用 local 失效），新增全局状态注意声明顺序。
- UI 实测坑：ScrollPanel 内 Line 控件顶部两行高区域被裁剪不渲染（改用细 Box）；SetColor 对 Label 无效（用 `[color:R,G,B,A]` 文本标签）；SetTexture 对轮播贴图静默无效（改 Button 内嵌 Image 子控件）；DDS 需 A8R8G8B8 单 mip。
- **存储管线实测定论**（条目4.3预备 Phase0/1/2 三轮冒烟，MPT_DataStorage.lua 头部注释有全表）：
  - **前端无法新建 UI Context**：AddUserInterfaces + 空 Context 实测 Lua 根本不执行（日志零输出），前端功能必须依附既有界面上下文（存储模块现由 StagingRoom 内联承载，见下条）；前端各 Context 脚本在启动时即执行并注册事件（JoiningRoom 事件在进房前触发为证）。
  - **【重大】前端 include() 本 mod 的 Lua 文件只在进程首个前端生命周期内真正执行**：经 ImportFiles 注册的 mod Lua 文件，首次前端启动时 include 正常；**开一局游戏退回主菜单后，前端重建的新 Lua 状态下 include 静默不执行**——`pcall(include)` 返回成功与一个 table，但文件体零执行、无任何报错/日志，全局 API 全缺。单变量实验证明与 InGame 双环境注册无关（禁用后故障依旧），系引擎缺陷。ReplaceUIScript 投递的 StagingRoom.lua 每次前端重建都可靠重执行 → **前端消费本 mod 自己的 Lua 一律内联进 StagingRoom.lua，勿用 include**；引擎自身加载的脚本（Test.LUA）在新状态下仍正常重执行。条目3.7 原同名覆盖文件 `Scripts/NetConnectionIconLogic.lua` 亦已内联进 StagingRoom.lua 条目3.7 分区（文件与 action 注册已移除），前端不再依赖任何本 mod 经 ImportFiles 注册的 include 文件。另实测：StagingRoom Lua 状态跨房间存续（反复建房退房不重跑顶层脚本），只有前端整体重建才换状态。
  - `Network.LoadGame` 是**重置语义**（不在存档里的 GameConfiguration 键被清掉）→ LoadData 会把 GameConfiguration 替换为该文件快照，调用方须选安全时机；联机准备房间内 LoadGame 实测不踢人、不影响房间配置。
  - 存档文件夹由保存时 `Type` 决定（Saves\Single / Saves\Multi）；文件列表菜单按**当前环境**枚举（主菜单列 Single、联机房间列 Multi）→ 本模块保存恒用 `SaveTypes.SINGLE_PLAYER`，读写同目录。
  - 前端 `Events.SaveComplete`/`Events.LoadComplete` 均触发（eResult=0, eFileType=1）；GameConfiguration 单值 512000 字符完整往返（未触顶），高频（5秒级）写读+反复落盘可靠。
  - `UI.QuerySaveGameList` 直查可用（无弹窗）：结果经 **`LuaEvents.FileListQueryResults`** 回调（引擎触发），**必须按自身 requestID 认领**（启动期 MainMenu 自己也在查 MOST_RECENT_ONLY，不过滤会误收其 GAME_STATE 结果导致判断落空，实测踩过），用完 `UI.CloseFileListQuery`；完整签名 5 参 `UI.QuerySaveGameList(location, gameType, options, fileType, directoryPath)`，directoryPath 恒传 `""` 用默认目录（LoadSaveMenu_Shared.lua:1060 / MainMenu.lua:1547-1616）；并发查询会互相顶掉 → 本模块以 FIFO 队列保证任时刻只有一个读写作业在途。
  - **任意路径读写配置档（实测成立）**：`Network.SaveGame` 带 `Path` 字段（官方仅 WORLDBUILDER_MAP 用）对 GAME_CONFIGURATION 生效；`Network.LoadGame` 用构造表 `{Name,Path,Location,Type,FileType}` 可从任意路径读回（哨兵键校验一致）；`SaveLocationOptions.DIRECTORIES` + directoryPath 可枚举任意目录（文件与子目录混列，子目录条目有 IsDirectory）；`UI.GetSaveLocationPath` 返回存档目录磁盘真实路径。本模块仍存 Saves\Single 标准目录。
  - WorldBuilder 地图存取即同一管线（`SaveTypes.WORLDBUILDER_MAP` + DIRECTORIES + `UI.GetVolumes()`），但地图二进制需 WB 会话，不能承载通用数据。
  - **客机读写实测通过**：非房主玩家在他人房间内 SaveData/LoadData 全流程正常（5 秒间隔×5 轮延时读写，时间戳链路逐轮传递完整），联机房间内客机 SaveGame/LoadGame 不受限。
- **前端 UI 计时/周期任务**：`ContextPtr:SetUpdateHandler` 是 Civ5 API，Civ6 不存在（调用即主 chunk 报错「function expected instead of nil」+ Error loading file）；`Events.MultiplayerPingTimesChanged` 在客机房间实测不触发，不能当滴答源；正确做法 = XML 放 `AlphaAnim Size="1,1" AlphaStart="0" AlphaEnd="0"`（不可见、隐藏也持续 tick，原版 CountdownTimerAnim 同款）+ `RegisterAnimCallback` 拿每帧回调再按需门控。

## 参考路径

- 游戏本体：`D:\Game\Steam\steamapps\common\Sid Meier's Civilization VI`（原版 UI 在 `Base\Assets\UI\`）
- 工坊 mod：`D:\Game\Steam\steamapps\workshop\content\289070`（联机工具箱1.67 = 3693899014）
- 参考实现：`D:\文档\My Games\Sid Meier's Civilization VI\Mods\乔尔定制mod\UI\StagingRoom.lua`
