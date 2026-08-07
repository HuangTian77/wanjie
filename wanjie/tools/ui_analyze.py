#!/usr/bin/env python3
"""UI 截图分析器：解码 PNG（纯 stdlib），统计主色/亮度/布局，支持改前改后对比。
用法:
  python tools/ui_analyze.py _ui_shots/main_hub.png
  python tools/ui_analyze.py _ui_shots/before.png _ui_shots/after.png
"""
import sys, zlib, struct, os
from collections import Counter

def decode_png(path):
    """返回 (width, height, [[(r,g,b),...] rows]) 支持 RGB8/RGBA8/调色板"""
    data = open(path, 'rb').read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', "not a png"
    pos, idat, w, h, bit, ctype, palette = 8, b'', 0, 0, 8, 0, None
    while pos < len(data):
        ln = struct.unpack('>I', data[pos:pos+4])[0]
        tag = data[pos+4:pos+8]
        chunk = data[pos+8:pos+8+ln]
        if tag == b'IHDR':
            w, h, bit, ctype = struct.unpack('>IIBB', chunk[:10])
        elif tag == b'PLTE':
            palette = [tuple(chunk[i:i+3]) for i in range(0, len(chunk), 3)]
        elif tag == b'IDAT':
            idat += chunk
        pos += 12 + ln
    raw = zlib.decompress(idat)
    bpp = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    stride = w * bpp
    rows, prev = [], bytearray(stride)
    p = 0
    for y in range(h):
        f = raw[p]; p += 1
        line = bytearray(raw[p:p+stride]); p += stride
        if f == 1:
            for i in range(bpp, stride): line[i] = (line[i] + line[i-bpp]) & 255
        elif f == 2:
            for i in range(stride): line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                a = line[i-bpp] if i >= bpp else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i-bpp] if i >= bpp else 0
                c = prev[i-bpp] if i >= bpp else 0
                b = prev[i]
                pa, pb, pc = abs(b-c), abs(a-c), abs(a+b-2*c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        prev = line
        rows.append(line)
    # 转像素
    px_rows = []
    for line in rows:
        row = []
        for x in range(w):
            o = x * bpp
            if ctype == 2:
                row.append((line[o], line[o+1], line[o+2]))
            elif ctype == 6:
                row.append((line[o], line[o+1], line[o+2]))
            elif ctype == 0:
                row.append((line[o], line[o], line[o]))
            elif ctype == 3:
                idx = line[o]
                row.append(tuple(palette[idx]) if palette and idx < len(palette) else (0, 0, 0))
        px_rows.append(row)
    return w, h, px_rows

def analyze(name, path):
    w, h, rows = decode_png(path)
    n = w * h
    lum_sum, dark, bright = 0, 0, 0
    quant = Counter()
    for row in rows:
        for (r, g, b) in row:
            lum = 0.299*r + 0.587*g + 0.114*b
            lum_sum += lum
            if lum < 80: dark += 1
            if lum > 200: bright += 1
            quant[(r//16*16, g//16*16, b//16*16)] += 1
    avg = lum_sum / n
    print(f"--- {name} ({path}) ---")
    print(f"size: {w}x{h}")
    print(f"avg_lum: {avg:.1f}  dark%: {dark/n*100:.1f}  bright%: {bright/n*100:.1f}  (深色=UI偏暗, 亮色=内容/背景)")
    print("top_colors:")
    for c, cnt in quant.most_common(6):
        print(f"  #{c[0]:02x}{c[1]:02x}{c[2]:02x}  {cnt/n*100:.1f}%")
    return avg, dark/n, bright/n, quant

def diff(path_a, path_b):
    wa, ha, ra = decode_png(path_a)
    wb, hb, rb = decode_png(path_b)
    if (wa, ha) != (wb, hb):
        print(f"DIFF: 尺寸不同 {wa}x{ha} vs {wb}x{hb}，跳过像素对比")
        return
    tot, changed = 0, 0
    for y in range(ha):
        for x in range(wa):
            ca, cb = ra[y][x], rb[y][x]
            d = sum(abs(ca[i]-cb[i]) for i in range(3))
            tot += d
            if d > 30: changed += 1
    n = wa*ha
    print(f"DIFF: 平均色差={tot/n:.2f} (0=相同, >10=明显变化), 变化像素%={changed/n*100:.1f}")

def motion_curve(frames):
    """帧序列动画分析：相邻帧平均色差曲线 + 平滑度判定"""
    diffs = []
    prev = None
    for f in sorted(frames):
        w, h, rows = decode_png(f)
        if prev is not None:
            pw, ph, prows = prev
            if (w, h) == (pw, ph):
                tot = 0
                for y in range(h):
                    pa, ca = prows[y], rows[y]
                    for x in range(w):
                        tot += sum(abs(ca[x][i]-pa[x][i]) for i in range(3))
                diffs.append(tot / (w*h))
        prev = (w, h, rows)
    n = len(diffs)
    if n == 0:
        print("MOTION: 无帧间变化（动画未触发?）")
        return
    peak = max(diffs); avg = sum(diffs)/n
    print(f"MOTION: 帧数={n} 峰值={peak:.2f} 均值={avg:.2f}")
    print("MOTION_CURVE: " + " ".join(f"{d:.2f}" for d in diffs))
    if peak < 0.2:
        print("MOTION_VERDICT: NO_ANIMATION（无动画或未触发）")
    elif peak > 40:
        print("MOTION_VERDICT: JUMP（存在跳变帧，动画可能不平滑）")
    else:
        print("MOTION_VERDICT: SMOOTH（动画存在且平滑）")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(1)
    if sys.argv[1] == '--motion':
        import glob
        frames = glob.glob(sys.argv[2])
        frames.sort()
        if not frames:
            print("无匹配帧文件"); sys.exit(1)
        motion_curve(frames)
        sys.exit(0)
    if len(sys.argv) == 3 and os.path.exists(sys.argv[1]) and os.path.exists(sys.argv[2]):
        analyze(os.path.basename(sys.argv[1]), sys.argv[1])
        analyze(os.path.basename(sys.argv[2]), sys.argv[2])
        diff(sys.argv[1], sys.argv[2])
    else:
        analyze(os.path.basename(sys.argv[1]), sys.argv[1])
