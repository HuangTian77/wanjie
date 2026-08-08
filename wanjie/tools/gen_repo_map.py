#!/usr/bin/env python3
"""GDScript 符号地图生成器（Aider repo map 思想）：扫描项目 .gd 提取类/信号/公开函数，
输出 docs/REPO_MAP.md 作为 AI 上下文加速器。用法: python wanjie/tools/gen_repo_map.py
"""
import os, re, glob

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # 项目根
WANJIE = os.path.join(ROOT, 'wanjie')
OUT = os.path.join(ROOT, 'docs', 'REPO_MAP.md')
SCAN_DIRS = ['scripts', 'resources/data', 'autoload', 'test', 'tools']
SKIP = {'addons', 'temp_scripts'}

CLASS_RE = re.compile(r'^class_name\s+(\w+)')
EXTENDS_RE = re.compile(r'^extends\s+(\w+)')
SIGNAL_RE = re.compile(r'^signal\s+(\w+)')
FUNC_RE = re.compile(r'^(?:static\s+)?func\s+(\w+)\s*\(')
CONST_RE = re.compile(r'^const\s+([A-Z_][A-Z0-9_]*)\s*=')

def scan():
    tree = {}  # dir -> {file -> [lines]}
    files = []
    for d in SCAN_DIRS:
        for f in glob.glob(os.path.join(WANJIE, d, '**', '*.gd'), recursive=True):
            rel = os.path.relpath(f, WANJIE).replace('\\', '/')
            if any(rel.startswith(s + '/') for s in SKIP):
                continue
            files.append((rel, f))
    for rel, f in sorted(files):
        try:
            lines = open(f, encoding='utf-8').read().split('\n')
        except OSError:
            continue
        entries = []
        class_name = None
        for i, ln in enumerate(lines, 1):
            m = CLASS_RE.match(ln)
            if m:
                class_name = m.group(1)
                entries.append('class_name **%s**' % class_name)
                continue
            m = SIGNAL_RE.match(ln)
            if m:
                entries.append('signal `%s`' % m.group(1))
                continue
            m = FUNC_RE.match(ln)
            if m:
                name = m.group(1)
                if not name.startswith('_') or name == '_ready' or name == '_process' or name == '_initialize':
                    entries.append('func `%s` (L%d)' % (name, i))
                continue
            m = CONST_RE.match(ln)
            if m:
                entries.append('const `%s`' % m.group(1))
        if entries:
            tree.setdefault(os.path.dirname(rel), []).append((rel, class_name, entries))
    return tree

def main():
    tree = scan()
    lines = []
    lines.append('# 项目符号地图（REPO_MAP）— GDScript 类/信号/函数索引')
    lines.append('')
    lines.append('> 自动生成：`python wanjie/tools/gen_repo_map.py`（Aider repo map 思想，AI 上下文加速）。')
    lines.append('> 统计：%d 个文件。改代码前先在此定位目标符号，再定向读取。' % sum(len(v) for v in tree.values()))
    lines.append('')
    for d in sorted(tree):
        lines.append('## %s/' % d)
        lines.append('')
        for rel, class_name, entries in tree[d]:
            tag = ('`%s`' % class_name) if class_name else os.path.basename(rel)
            lines.append('### %s (%s)' % (rel, tag))
            lines.append('')
            for e in entries:
                lines.append('- %s' % e)
            lines.append('')
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines))
    print('REPO_MAP generated: %s (%d files)' % (OUT, sum(len(v) for v in tree.values())))

if __name__ == '__main__':
    main()
