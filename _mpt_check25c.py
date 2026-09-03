# -*- coding: utf-8 -*-
# 条目25 用户裁决回归 自检脚本（用后即删）
import xml.etree.ElementTree as ET
import re, io, os

base = os.path.dirname(os.path.abspath(__file__))
ok = True

try:
    ET.parse(os.path.join(base, 'MultiplayerToolkits.modinfo'))
    print('XML OK : MultiplayerToolkits.modinfo')
except Exception as e:
    ok = False; print('XML FAIL:', e)

# modinfo 残留检查：EraBanner 应零登记，BuilderCharges 应登记
mi = io.open(os.path.join(base, 'MultiplayerToolkits.modinfo'), encoding='utf-8').read()
assert 'EraBanner' not in mi, 'EraBanner 仍有残留登记'
assert 'UnitFlagManager_BuilderCharges.lua' in mi, 'BCT 文件未登记'
print('MODINFO OK : EraBanner 清零 / BCT 已登记')

try:
    from luaparser import ast
    for f in ['InGame/GreatGeneralEraReminder/UnitFlagManager_MPT.lua',
              'InGame/GreatGeneralEraReminder/UnitFlagManager_BuilderCharges.lua']:
        src = io.open(os.path.join(base, f), encoding='utf-8').read()
        src2 = re.sub(r'(?m)^\s*--.*$', '', src)
        src2 = re.sub(r'(\w)\s*:\s*(table|number|string|boolean|ifunction|cfunction|function)\b', r'\1', src2)
        try:
            ast.parse(src2)
            print('LUA OK :', f)
        except Exception as e:
            ok = False; print('LUA FAIL:', f, e)
except ImportError:
    print('LUA SKIP: luaparser not installed')

print('ALL PASS' if ok else 'HAS FAILURES')
