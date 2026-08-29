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
| `Shared/` | 双环境共享代码与数据。`MPT_Serialize.lua` 序列化；`MPT_DataStorage.lua` 极简本地数据读写（对外 `MPT_Storage_SaveData/LoadData/DeleteFile` 三个全局 API，ModGroup 组名承载）。**前端实际承载 = StagingRoom.lua 末尾「条目4.3预备」内联副本**（因引擎 include 缺陷，见技能库 empty-context.md），两副本改动必须双向同步。子目录 `PlayerMark/` 为玩家标记双环境共享数据，当前仅前端消费 |
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
| `InGame/WorldTracker/` | 条目8 WorldTracker 快捷操作面板：空 Context + ChangeParent 挂载，展开区「投降」「重新开始」「玩家标记」三按钮 + 投票区；「重新开始」响应未配置 TODO |
| `InGame/SurrenderVote/` | 条目8续 团队投降投票（Gameplay 侧）：AddGameplayScripts 注册，EXECUTE_SCRIPT 收 UI 指令，票数 ≥ 半数 → 该队城市全部叛变自由城；每时代每队一次 |
| `InGame/TopPanelExt/` | 条目9 顶部面板扩展（移植 1.67 TPE）：ReplaceUIScript 覆盖，追加食物/生产力/人口/奢侈品统计按钮与 Tooltip、战略资源 Tooltip 追加队友清单 |
| `InGame/DealRestriction/` | 条目10 交易限制与外交限制（移植 1.67 DDV 整模块）：交易四模式/无友谊默认开/和解三模式；`MPT_TradeRules.lua` 统一解析器；SQL 经 ActionCriteria（ConfigurationValueMatches）条件执行；参数定义与 DealView 导入门控 `Disable_MPH` |
| `InGame/PlayerMark/` | 条目11 游戏内玩家标记面板（移植条目4.4 到 InGame）：include Shared/MPT_DataStorage.lua 与前端同一份存档互通；QuickPanel 按钮打开 |
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
