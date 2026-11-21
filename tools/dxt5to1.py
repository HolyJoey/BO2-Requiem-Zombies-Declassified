#!/usr/bin/env python3
"""Lossless DXT5 -> DXT1 for opaque images (T6 .iwi v27 or .dds).

The DXT5 colour block is reused as-is (endpoints swapped / indices remapped
where DXT1 would otherwise switch to its 3-colour+transparent mode), the alpha
block is dropped. Refuses images whose alpha goes below --min-alpha.

  dxt5to1.py in out [--drop-top N] [--only-top] [--min-alpha 250]
"""
import argparse, struct, sys

def mip_sizes(w, h, bs):
    out = []
    while True:
        out.append(max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * bs)
        if w == 1 and h == 1:
            break
        w, h = max(1, w // 2), max(1, h // 2)
    return out

def min_alpha(block):
    a0, a1 = block[0], block[1]
    bits = int.from_bytes(block[2:8], 'little')
    pal = [a0, a1]
    if a0 > a1:
        pal += [((6 - i) * a0 + (i + 1) * a1) // 7 for i in range(6)]
    else:
        pal += [((4 - i) * a0 + (i + 1) * a1) // 5 for i in range(4)] + [0, 255]
    used = {(bits >> (3 * i)) & 7 for i in range(16)}
    return min(pal[u] for u in used)

def convert(data):
    out = bytearray(len(data) // 2)
    lo = 255
    for i in range(0, len(data), 16):
        lo = min(lo, min_alpha(data[i:i + 8]))
        c0, c1, idx = struct.unpack_from('<HHI', data, i + 8)
        if c0 < c1:
            c0, c1 = c1, c0
            idx ^= 0x55555555  # 0<->1, 2<->3
        elif c0 == c1:
            idx = 0
        struct.pack_into('<HHI', out, i // 2, c0, c1, idx)
    return bytes(out), lo

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src'); ap.add_argument('dst')
    ap.add_argument('--drop-top', type=int, default=0)
    ap.add_argument('--only-top', action='store_true')
    ap.add_argument('--min-alpha', type=int, default=250)
    ap.add_argument('--keep-dxt5', action='store_true', help='only drop mips, keep DXT5')
    a = ap.parse_args()
    d = open(a.src, 'rb').read()
    if d[:3] == b'IWi':
        assert d[3] == 0x1b, 'IWI version'
        assert d[4] == 0x0d, 'not DXT5'
        w, h = struct.unpack_from('<HH', d, 6)
        sizes = mip_sizes(w, h, 16)
        hdr = 64
        assert len(d) == hdr + sum(sizes), 'unexpected IWI size/mips'
        # stored smallest first, largest last
        mips, end = [], len(d)
        for s in sizes:
            mips.append(d[end - s:end]); end -= s
        mips = mips[a.drop_top:]
        if a.only_top:
            mips = mips[:1]
        conv, lo = [], 255
        for m in mips:
            if a.keep_dxt5:
                conv.append(m); continue
            c, l = convert(m); conv.append(c); lo = min(lo, l)
        if lo < a.min_alpha:
            sys.exit('%s: alpha goes down to %d, not opaque' % (a.src, lo))
        nw, nh = max(1, w >> a.drop_top), max(1, h >> a.drop_top)
        body = b''.join(reversed(conv))
        head = bytearray(d[:hdr])
        head[4] = 0x0d if a.keep_dxt5 else 0x0b
        struct.pack_into('<HH', head, 6, nw, nh)
        ends, e = [], hdr + len(body)
        for c in conv:
            ends.append(e); e -= len(c)
        # table = end offset of mips 0..7 (largest first); fewer mips -> repeat the last
        ends = (ends + [ends[-1]] * 8)[:8]
        struct.pack_into('<8I', head, 32, *ends)
        open(a.dst, 'wb').write(bytes(head) + body)
        print('%s: %dx%d DXT5 %d KB -> %dx%d DXT1 %d mips %d KB (min alpha %d)' % (
            a.src, w, h, len(d) // 1024, nw, nh, len(conv), (hdr + len(body)) // 1024, lo))
    elif d[:4] == b'DDS ':
        h, w = struct.unpack_from('<II', d, 12)
        nm = max(1, struct.unpack_from('<I', d, 28)[0])
        assert d[84:88] == b'DXT5', 'not DXT5'
        sizes = mip_sizes(w, h, 16)[:nm]
        assert len(d) == 128 + sum(sizes), 'unexpected DDS size'
        mips, p = [], 128
        for s in sizes:
            mips.append(d[p:p + s]); p += s
        if a.only_top:
            mips = mips[:1]
        conv, lo = [], 255
        for m in mips:
            c, l = convert(m); conv.append(c); lo = min(lo, l)
        if lo < a.min_alpha:
            sys.exit('%s: alpha goes down to %d, not opaque' % (a.src, lo))
        head = bytearray(d[:128])
        head[84:88] = b'DXT1'
        struct.pack_into('<I', head, 20, len(conv[0]))  # linear size
        struct.pack_into('<I', head, 28, len(conv) if len(conv) > 1 else 0)
        flags = struct.unpack_from('<I', head, 8)[0]
        caps = struct.unpack_from('<I', head, 108)[0]
        if len(conv) == 1:
            flags &= ~0x20000; caps &= ~0x400008
        struct.pack_into('<I', head, 8, flags)
        struct.pack_into('<I', head, 108, caps)
        open(a.dst, 'wb').write(bytes(head) + b''.join(conv))
        print('%s: %dx%d DXT5 %d mips %d KB -> DXT1 %d mips %d KB (min alpha %d)' % (
            a.src, w, h, nm, len(d) // 1024, len(conv), (128 + sum(map(len, conv))) // 1024, lo))
    else:
        sys.exit('unknown format')

if __name__ == '__main__':
    main()
