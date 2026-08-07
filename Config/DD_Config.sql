-- ============================================================================
-- 联机工具箱2.0：灾害强度下限 0 -> -1（完全无灾害）
-- 参考联机工具箱1.67 DD/DD_Config.sql（原作者 moxiangshuwanfeng）。
-- 机制：RealismRange 是「灾害强度」参数的取值域（DLC Expansion2_Config.xml 定义
--       Realism 参数 Domain=RealismRange，原版 MinimumValue=0 MaximumValue=4）。
--       将下限改为 -1 后，建房界面滑块可拉到 -1 档，游戏核心对该档不生成任何灾害。
--       改的是前端 Configuration 数据库，因此必须挂在 FrontEndActions。
-- ============================================================================
UPDATE DomainRanges SET MinimumValue = -1 WHERE Domain = 'RealismRange';
