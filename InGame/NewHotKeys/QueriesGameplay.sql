-- ============================================================================
-- 条目27：更多快捷键（NHK）引擎绑定层——移植 1.65 NHK/SQL/QueriesGameplay.sql（4 行）
--   + CHS-PVP（工坊 3037861572）Core/Main/QueriesGameplay.sql（12 行），去重合并为 12 行。
-- 作用：把游戏库 UnitOperations / UnitCommands 表中原本 HotkeyId 为 NULL（无快捷键）的
--   单位操作/命令指向 InputActions 已注册的动作，引擎 ActionPanel/WorldInput 自动把
--   按键翻译成单位命令，多数动作无需 Lua。
-- WHERE HotkeyId IS NULL 保护保留（两源同款）：不覆盖原版已有绑定与玩家自定义；
--   与 1.65 同装时其同名 SQL 先后竞争，因共享 4 动作键位一致（1.65 键位基准）结果无差异。
-- 升级行含 CHS 超集：UNITCOMMAND_UPGRADE + UNITCOMMAND_ACTIVATE_GREAT_PERSON 同键。
-- 注册：InGameActions UpdateDatabase(10)，criteria=MPT_NEW_HOTKEYS 门控（开关关闭不绑定）
-- ============================================================================

-- 复用原版「驻扎至痊愈」H 键（FortifyUntilHeal 动作）让船只原地修理也走 H（CHS）
UPDATE "UnitOperations" SET "HotkeyId" = "FortifyUntilHeal" WHERE "HotkeyId" IS NULL AND "OperationType" = "UNITOPERATION_REST_REPAIR";
-- 掠夺/海岸突袭/修理 = Shift+P（1.65 = CHS 同款）
UPDATE "UnitOperations" SET "HotkeyId" = "ExtraHotkeysPillageOrRepair" WHERE "HotkeyId" IS NULL AND ("OperationType" = "UNITOPERATION_PILLAGE" OR "OperationType" = "UNITOPERATION_COASTAL_RAID" OR "OperationType" = "UNITOPERATION_REPAIR");
-- 破坏/修复道路/建立贸易路线 = Ctrl+Shift+P（CHS）
UPDATE "UnitOperations" SET "HotkeyId" = "ExtraHotkeysPillageRoadOrRepair" WHERE "HotkeyId" IS NULL AND ("OperationType" = "UNITOPERATION_PILLAGE_ROUTE" OR "OperationType" = "UNITOPERATION_REPAIR_ROUTE" OR "OperationType" = "UNITOPERATION_MAKE_TRADE_ROUTE");
-- 传送进城/重新基地 = Shift+R（CHS）
UPDATE "UnitOperations" SET "HotkeyId" = "ExtraHotkeysTeleportToCity" WHERE "HotkeyId" IS NULL AND ("OperationType" = "UNITOPERATION_TELEPORT_TO_CITY" OR "OperationType" = "UNITOPERATION_REBASE");
-- 掠夺贸易路线 = Ctrl+Shift+R（CHS）
UPDATE "UnitCommands" SET "HotkeyId" = "ExtraHotkeysPlunderTradeRoute" WHERE "HotkeyId" IS NULL AND "CommandType" = "UNITCOMMAND_PLUNDER_TRADE_ROUTE";
-- 升级/激活伟人 = Shift+E（1.65 键位；含 CHS 超集 ACTIVATE_GREAT_PERSON）
UPDATE "UnitCommands" SET "HotkeyId" = "ExtraHotkeysUpgrade" WHERE "HotkeyId" IS NULL AND ("CommandType" = "UNITCOMMAND_UPGRADE" OR "CommandType" = "UNITCOMMAND_ACTIVATE_GREAT_PERSON");
-- 晋升 = Shift+G（1.65 键位；Lua 侧 NewUnitOperation 先清当前命令为晋升清路）
UPDATE "UnitCommands" SET "HotkeyId" = "ExtraHotkeysPromote" WHERE "HotkeyId" IS NULL AND "CommandType" = "UNITCOMMAND_PROMOTE";
-- 组建军团 = Shift+C（CHS 原键 Shift+F 让位强制结束回合，本 mod 改键）
UPDATE "UnitCommands" SET "HotkeyId" = "ExtraHotkeysFormCorps" WHERE "HotkeyId" IS NULL AND "CommandType" = "UNITCOMMAND_FORM_CORPS";
-- 组建集团军 = Ctrl+Shift+F（CHS）
UPDATE "UnitCommands" SET "HotkeyId" = "ExtraHotkeysFormArmy" WHERE "HotkeyId" IS NULL AND "CommandType" = "UNITCOMMAND_FORM_ARMY";
-- 编队/解编 = Ctrl+Shift+E（CHS 原键 Shift+E 与升级冲突，本 mod 改键）
UPDATE "UnitCommands" SET "HotkeyId" = "ExtraHotkeysEnterFormation" WHERE "HotkeyId" IS NULL AND ("CommandType" = "UNITCOMMAND_ENTER_FORMATION" OR "CommandType" = "UNITCOMMAND_EXIT_FORMATION");
-- 取消命令 = Shift+S（1.65 键位；CHS 用 Shift+C，本 mod 该键已让给组建军团）
UPDATE "UnitCommands" SET "HotkeyId" = "ExtraHotkeysUnitCancel" WHERE "HotkeyId" IS NULL AND "CommandType" = "UNITCOMMAND_CANCEL";
-- 唤醒 = Ctrl+Shift+W（CHS 原键 Shift+W 与随机晋升冲突，本 mod 改键）
UPDATE "UnitCommands" SET "HotkeyId" = "ExtraHotkeysUnitWake" WHERE "HotkeyId" IS NULL AND "CommandType" = "UNITCOMMAND_WAKE";
