#!/usr/bin/env python3
"""Rebuild a globe/lobby blur background (menu_*_map_blur.iwi) from the sharp map art.

The game shows only the centre quarter of these 2048x2048 textures, zoomed ~2.5x, so the
posterized original blurs looked blocky. This makes a clean Gaussian blur of the sharp
image and copies the original blur's colour, brightness and vignette from a heavily
smoothed copy of it, so only the blockiness changes. Output: DXT1, 2048x2048, no mips
(IWI v27), encoded with ImageMagick (cluster fit) plus a light dither against banding.

  make_blur.py SHARP.iwi OLD_BLUR.iwi OUT.iwi [--sigma 8]

Sigmas used for v2: moon 24, pentagon 16, temple 16, everything else 8.
Needs numpy, scipy, Pillow and ImageMagick (`magick`).
"""
import argparse, io, os, struct, subprocess, tempfile
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter


def load_iwi(path):
    """Top mip of a DXT1/DXT5 IWI v27 as float32 RGBA."""
    d = open(path, 'rb').read()
    assert d[:4] == b'IWi\x1b', 'not an IWI v27'
    fmt = d[4]
    assert fmt in (0x0b, 0x0d), 'only DXT1/DXT5'
    w, h = struct.unpack_from('<HH', d, 6)
    bs = 16 if fmt == 0x0d else 8
    top = ((w + 3) // 4) * ((h + 3) // 4) * bs
    data = d[len(d) - top:]  # mips are stored smallest first, largest last
    hdr = bytearray(128)
    hdr[0:4] = b'DDS '
    struct.pack_into('<IIIIIII', hdr, 4, 124, 0x1007, h, w, top, 0, 0)
    struct.pack_into('<II4s', hdr, 76, 32, 4, b'DXT5' if fmt == 0x0d else b'DXT1')
    struct.pack_into('<I', hdr, 108, 0x1000)
    im = Image.open(io.BytesIO(bytes(hdr) + data)).convert('RGBA')
    if im.size != (2048, 2048):
        im = im.resize((2048, 2048), Image.BILINEAR)
    return np.asarray(im).astype(np.float32)


def iwi_header_dxt1_2048():
    h = bytearray(64)
    h[0:4] = b'IWi\x1b'
    h[4] = 0x0b                      # DXT1
    h[5] = 0x02                      # no mips
    struct.pack_into('<HHH', h, 6, 2048, 2048, 1)
    struct.pack_into('<I', h, 32, 64 + 2048 * 2048 // 2)  # end of the only mip; rest of the table 0
    return h


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sharp'); ap.add_argument('old_blur'); ap.add_argument('out')
    ap.add_argument('--sigma', type=float, default=8.0)
    ap.add_argument('--seed', type=int, default=1)
    a = ap.parse_args()

    S = load_iwi(a.sharp)[..., :3]
    T = load_iwi(a.old_blur)[..., :3]
    G = np.stack([gaussian_filter(S[..., c], a.sigma) for c in range(3)], -1)

    grey = np.ptp(T.mean((0, 1))) < 2.5          # most originals are greyscale
    base = np.repeat((G @ np.array([0.299, 0.587, 0.114], np.float32))[..., None], 3, -1) if grey else G
    LS = 48                                       # tone/vignette transfer scale
    gain = np.stack([gaussian_filter(T[..., c], LS) / (gaussian_filter(base[..., c], LS) + 2.0)
                     for c in range(3)], -1)
    if grey:
        gain = np.repeat(gain.mean(-1, keepdims=True), 3, -1)
    out = base * np.clip(gain, 0, 6)
    rng = np.random.default_rng(a.seed)
    out = out + rng.uniform(-0.5, 0.5, out.shape[:2])[..., None] * 1.5
    out = np.clip(np.round(out), 0, 255).astype(np.uint8)

    with tempfile.TemporaryDirectory() as td:
        png, dds = os.path.join(td, 'b.png'), os.path.join(td, 'b.dds')
        Image.fromarray(out).save(png)
        subprocess.run(['magick', png, '-define', 'dds:compression=dxt1', '-define', 'dds:cluster-fit=true',
                        '-define', 'dds:mipmaps=0', '-define', 'dds:weight-by-alpha=false', dds], check=True)
        body = open(dds, 'rb').read()[128:]
    assert len(body) == 2048 * 2048 // 2
    open(a.out, 'wb').write(bytes(iwi_header_dxt1_2048()) + body)
    print('%s: %s, sigma %g' % (a.out, 'grey' if grey else 'colour', a.sigma))


if __name__ == '__main__':
    main()
