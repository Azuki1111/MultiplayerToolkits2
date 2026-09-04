#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""联机工具箱2.0 广告表同步脚本（条目3.6 扩展）。

扫描 FrontEnd/Ads/*.dds，按文件名后缀配对（大小写敏感）：
    Xxx_AD.dds       -> MPT_Ads.TextureName  （广告主图，400x300 标准）
    Xxx_ToolTip.dds  -> MPT_Ads.ToolTipImage （悬停纯图片提示，可缺省；缺省写 ''）
即 Demo_AD.dds 与 Demo_ToolTip.dds 自动配为一组。

功能：
  1. Ads_Data.sql：为「表中尚不存在」的 Xxx_AD.dds 追加一条独立的
     INSERT OR REPLACE 语句（不改动文件里已有的任何行；TextureName 已存在的
     条目一律跳过，保护手工修改）。新行 StartDate/EndDate/ToolTipTag/Url 留空。
  2. MultiplayerToolkits.modinfo：把 FrontEnd/Ads/ 下全部 dds 幂等登记进
     FE_Import_Ads action 与末尾 <Files> 清单（缺哪条补哪条，已有则不动）。

用法（在任意目录均可，路径相对本脚本定位）：
    python Tools/MPT_AdsSync.py

注意：脚本只做增量，不删除、不覆盖；运行后如需日期/文本/链接等请手工编辑
Ads_Data.sql（后缀不匹配 _AD/_ToolTip 的贴图不写表，仅登记 modinfo）。
"""

import re
import sys
from pathlib import Path

MOD_ROOT = Path(__file__).resolve().parent.parent
ADS_DIR = MOD_ROOT / "FrontEnd" / "Ads"
SQL_PATH = ADS_DIR / "Ads_Data.sql"
MODINFO_PATH = MOD_ROOT / "MultiplayerToolkits.modinfo"

AD_SUFFIX = "_AD"        # 主图后缀
TIP_SUFFIX = "_ToolTip"  # 悬停图后缀

# 新行的固定列序（与 Ads_Data.sql 建表列序一致）
COLUMNS = ["TextureName", "StartDate", "EndDate", "ToolTipTag", "ToolTipImage", "Url"]
INSERT_RE = re.compile(r"INSERT\s+OR\s+REPLACE\s+INTO\s+MPT_Ads\s*\(([^)]*)\)\s*VALUES", re.IGNORECASE)
VALUES_RE = re.compile(r"'((?:[^']|'')*)'")


def read_text(path):
    with open(path, "r", encoding="utf-8", newline="") as f:
        return f.read()


def write_text(path, text):
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)


def eol_of(text):
    return "\r\n" if "\r\n" in text else "\n"


def sql_quote(s):
    return "'" + s.replace("'", "''") + "'"


def scan_dds():
    """扫描 FrontEnd/Ads/*.dds，按后缀分拣。

    返回 (ad_map, tip_map, strays)：
      ad_map  = {主图基名: dds 文件名}（Xxx_AD.dds）
      tip_map = {悬停图基名: dds 文件名}（Xxx_ToolTip.dds）
      strays  = 两个后缀都不匹配的 dds 文件名列表
    """
    ad_map, tip_map, strays = {}, {}, []
    for p in sorted(ADS_DIR.glob("*.dds")):
        stem = p.stem
        if stem.endswith(AD_SUFFIX) and stem[: -len(AD_SUFFIX)]:
            ad_map[stem[: -len(AD_SUFFIX)]] = p.name
        elif stem.endswith(TIP_SUFFIX) and stem[: -len(TIP_SUFFIX)]:
            tip_map[stem[: -len(TIP_SUFFIX)]] = p.name
        else:
            strays.append(p.name)
    return ad_map, tip_map, strays


def existing_texture_names(text):
    """解析 Ads_Data.sql 中全部 INSERT 语句已写入的 TextureName 集合。"""
    names = set()
    for m in INSERT_RE.finditer(text):
        cols = [c.strip() for c in m.group(1).split(",")]
        if "TextureName" not in cols:
            print("[警告] INSERT 语句列清单无 TextureName，跳过该语句解析：%s" % m.group(0)[:60])
            continue
        name_idx = cols.index("TextureName")
        for line in text[m.end():].splitlines():
            stripped = line.strip()
            if stripped.startswith("--") or not stripped:
                continue
            if not stripped.startswith("("):
                break  # 本语句结束
            values = [v.replace("''", "'") for v in VALUES_RE.findall(stripped)]
            if len(values) != len(cols):
                print("[错误] 元组列数(%d)与列清单(%d)不一致，停止解析：%s" % (len(values), len(cols), stripped[:80]))
                sys.exit(1)
            names.add(values[name_idx])
    return names


def append_rows(text, rows):
    """把 [(TextureName, ToolTipImage), ...] 作为独立 INSERT 语句追加到文件末尾。"""
    eol = eol_of(text)
    lines = [
        "-- ↓ MPT_AdsSync.py 自动追加（_AD/_ToolTip 配对；日期/文本/链接默认空，可手工修改后无需再跑本脚本写入这些行）",
        "INSERT OR REPLACE INTO MPT_Ads (TextureName, StartDate, EndDate, ToolTipTag, ToolTipImage, Url) VALUES",
    ]
    for i, (tex, tip) in enumerate(rows):
        values = [tex, "", "", "", tip, ""]
        tuple_str = "(" + ", ".join(sql_quote(v) for v in values) + ")"
        lines.append(tuple_str + (";" if i == len(rows) - 1 else ","))
    return text.rstrip("\r\n") + eol + eol + eol.join(lines) + eol


def update_modinfo(dds_names):
    """把 dds 幂等登记进 FE_Import_Ads action 与 <Files> 清单，返回补登记的文件列表。"""
    text = read_text(MODINFO_PATH)
    eol = eol_of(text)
    lines = text.split(eol)
    added = []

    def block_span(open_marker, close_marker):
        open_idx = next(i for i, l in enumerate(lines) if open_marker in l)
        close_idx = next(i for i in range(open_idx + 1, len(lines)) if close_marker in lines[i])
        return open_idx, close_idx

    def insert_before(close_idx, path):
        entry = "<File>%s</File>" % path
        if any(entry in l for l in lines):
            return
        indent = "\t\t\t"
        for i in range(close_idx - 1, 0, -1):
            m = re.match(r"^(\s*)<File>", lines[i])
            if m:
                indent = m.group(1)
                break
        lines.insert(close_idx, indent + entry)
        added.append("action  %s" % path)

    # 1) FE_Import_Ads action 内登记
    open_idx, close_idx = block_span('<ImportFiles id="FE_Import_Ads">', "</ImportFiles>")
    for name in dds_names:
        insert_before(close_idx, "FrontEnd/Ads/" + name)

    # 2) 末尾 <Files> 清单登记（锚在清单内最后一条 FrontEnd/Ads/ 行之后，保持广告文件聚堆）
    files_open = next(i for i, l in enumerate(lines) if re.match(r"^\s*<Files>\s*$", l))
    files_close = next(i for i in range(files_open + 1, len(lines)) if "</Files>" in lines[i])
    anchor = max((i for i in range(files_open + 1, files_close) if "FrontEnd/Ads/" in lines[i]), default=files_open)
    for name in dds_names:
        entry = "<File>FrontEnd/Ads/%s</File>" % name
        if any(entry in l for l in lines[files_open:files_close]):
            continue
        indent = "\t\t"
        m = re.match(r"^(\s*)<File>", lines[anchor])
        if m:
            indent = m.group(1)
        lines.insert(anchor + 1, indent + entry)
        anchor += 1
        added.append("Files   %s" % name)

    if added:
        write_text(MODINFO_PATH, eol.join(lines))
    return added


def main():
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass

    if not ADS_DIR.is_dir():
        print("[错误] 找不到广告目录：%s" % ADS_DIR)
        sys.exit(1)

    ad_map, tip_map, strays = scan_dds()
    print("扫描到主图 %d 张、悬停图 %d 张、未匹配后缀 %d 张" % (len(ad_map), len(tip_map), len(strays)))

    # 1) SQL：只写表中尚不存在的主图行
    sql_text = read_text(SQL_PATH)
    existing = existing_texture_names(sql_text)
    new_rows, skipped = [], []
    for base in sorted(ad_map):
        ad_name = ad_map[base]
        if ad_name in existing:
            skipped.append(ad_name)
        else:
            new_rows.append((ad_name, tip_map.get(base, "")))
    if new_rows:
        write_text(SQL_PATH, append_rows(sql_text, new_rows))
        for tex, tip in new_rows:
            print("新增行  %-28s ToolTipImage=%s" % (tex, tip if tip else "（无配对悬停图）"))
    for name in skipped:
        print("跳过    %-28s （表中已存在，不覆盖手工修改）" % name)

    # 2) modinfo：全部 dds 幂等登记
    all_dds = sorted(set(ad_map.values()) | set(tip_map.values()) | set(strays))
    added = update_modinfo(all_dds)
    for line in added:
        print("登记    %s" % line)

    # 3) 提示信息
    orphan_tips = sorted(set(tip_map) - set(ad_map))
    for base in orphan_tips:
        print("[提示] 悬停图 %s 无同名 _AD 主图，未写表（仅为登记 modinfo）" % tip_map[base])
    for name in strays:
        print("[提示] %s 不匹配 _AD/_ToolTip 后缀规则，未写表（仅为登记 modinfo）" % name)
    if not (new_rows or added):
        print("已是最新，无需改动。")


if __name__ == "__main__":
    main()
