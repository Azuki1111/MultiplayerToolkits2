-- ============================================================================
-- MPT_Serialize.lua
-- 联机工具箱 2.0 前端：数据表序列化/反序列化工具（条目4.3预备，黑名单等持久化地基）
--
-- 移植自联机工具箱1.67 BSR UI/StagingRoom.lua 的 serialize/deserialize，
-- 原版出自 metalua（MIT 协议）：
--   https://github.com/fab13n/metalua/blob/no-dll/src/lib/serialize.lua
--
-- 本版为精简优化重写。原 metalua 版是通用序列化器，含三套机制：
--   1. 共享引用槽位（两遍哈希遍历 + local _={} + _[n]=... 引用接回）；
--   2. 循环表占位补丁（nest_points/nest_patches 先 false 占位后补丁赋值）；
--   3. 函数字节码转储（string.dump + loadstring）。
-- 本 mod 只序列化纯数据表（字符串/数字/布尔/嵌套表），三套机制均为死重，
-- 故重写为单遍递归序列化。与原版差异：
--   - 不支持函数序列化（遇到 function/userdata/thread 报错，与原版 error 行为一致）；
--   - 检测到循环引用报错拦截（单遍递归遇环会无限递归；纯数据储存场景循环表本属非法）；
--   - 共享子表按值重复展开（还原后内容相等，但不再是同一张表）；
--   - 输出更紧凑（合法标识符键省略引号括号、无多余空格），按 2000 字符切组时组数更少；
--   - MPT_Deserialize 加守卫，数据损坏返回 nil 而非抛错。
--
-- 线格式兼容：输出仍是 return {...} 字面量，loadstring 可读 1.67 写入的旧数据。
-- 注意：数字经 tostring 转换，整数精确，浮点仅约 14 位有效数字（实际数据均为整数/字符串）。
--
-- 用法：
--   local s = MPT_Serialize({ name = "foo", level = 1 });	-- 形如 return{level=1,name="foo"}（键序不定）
--   local t = MPT_Deserialize(s) or {};						-- 还原；损坏数据返回 nil
-- ============================================================================

-- Lua 关键字表：字符串键为合法标识符时可省略引号括号输出 k=v，是关键字时回退 ["k"]=v
local g_mpt_luaKeywords = {
	["and"]=true, ["break"]=true, ["do"]=true, ["else"]=true, ["elseif"]=true,
	["end"]=true, ["false"]=true, ["for"]=true, ["function"]=true, ["goto"]=true,
	["if"]=true, ["in"]=true, ["local"]=true, ["nil"]=true, ["not"]=true,
	["or"]=true, ["repeat"]=true, ["return"]=true, ["then"]=true, ["true"]=true,
	["until"]=true, ["while"]=true,
};

-- ============================================================================
-- 内部：递归把值 x 转储为 Lua 字面量字符串片段，按序追加进 acc。
-- nest 为当前递归路径上的表集合（transient，离开该表即移除），用于检测循环引用。
-- 数组部分（整数键 1..#x）按位置输出，其余键按 [k]=v 或 k=v 输出。
-- ============================================================================
local function MPT_DumpValue(x, acc, nest)
	local t = type(x);
	if t == "number" then
		table.insert(acc, tostring(x));		-- 整数精确；浮点约 14 位有效数字
	elseif t == "boolean" then
		table.insert(acc, x and "true" or "false");
	elseif t == "string" then
		table.insert(acc, string.format("%q", x));
	elseif t == "table" then
		if nest[x] then
			error("MPT_Serialize: 不支持循环引用表");
		end
		nest[x] = true;
		table.insert(acc, "{");
		local first = true;
		for i = 1, #x do		-- 数组部分
			if first then first = false; else table.insert(acc, ","); end
			MPT_DumpValue(x[i], acc, nest);
		end
		for k, v in pairs(x) do		-- 哈希部分（跳过已按位置输出的数组键）
			if not (type(k) == "number" and k >= 1 and k <= #x and math.floor(k) == k) then
				if first then first = false; else table.insert(acc, ","); end
				if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") and not g_mpt_luaKeywords[k] then
					table.insert(acc, k);	-- 合法标识符键：k=v
				else
					table.insert(acc, "[");
					MPT_DumpValue(k, acc, nest);
					table.insert(acc, "]");
				end
				table.insert(acc, "=");
				MPT_DumpValue(v, acc, nest);
			end
		end
		nest[x] = nil;
		table.insert(acc, "}");
	elseif x == nil then
		table.insert(acc, "nil");
	else
		error("MPT_Serialize: 不支持序列化类型 " .. t);		-- function/userdata/thread
	end
end

-- ============================================================================
-- MPT_Serialize(x)：把纯数据值序列化为可 loadstring 读回的 Lua 源码字符串。
--   支持 nil/布尔/数字/字符串/表（可嵌套）；函数/userdata/线程报错；循环引用报错。
--   参数 x：任意纯数据值（通常为表）
--   返回 string：形如 "return{level=1,name="foo"}"（"return " 后必须留空格，
--   否则 return5/returntrue 这类纯数字/布尔顶层值会被词法分析成标识符）
-- ============================================================================
function MPT_Serialize(x)
	local acc = {};
	MPT_DumpValue(x, acc, {});
	return "return " .. table.concat(acc);
end

-- ============================================================================
-- MPT_Deserialize(s)：把 MPT_Serialize 的输出字符串读回为 Lua 值（含 1.67 旧数据）。
--   参数 s：MPT_Serialize 产出的字符串
--   返回：还原的 Lua 值；非字符串输入、语法损坏或执行失败时返回 nil（不抛错），
--   调用方可用 or {} 兜底（与 1.67 Read_tableString 的用法一致）
-- ============================================================================
function MPT_Deserialize(s)
	if type(s) ~= "string" then return nil; end
	local fn = loadstring(s);
	if fn == nil then return nil; end
	local ok, result = pcall(fn);
	if not ok then return nil; end
	return result;
end
