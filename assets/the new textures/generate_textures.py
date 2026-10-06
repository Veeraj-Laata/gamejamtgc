#!/usr/bin/env python3
"""
PSX comic-noir subway texture pack generator (Godot 4)
=======================================================
Generates 11 seamless 512x512 PNG textures, intentionally flat, muted and
"boring" so a cel/toon shader, hard shadows, outlines and shader-driven
cyan/green accents carry the style.

Requires: numpy, Pillow      (pip install numpy pillow)

Usage:
    python generate_textures.py                  # writes ./textures/*.png
    python generate_textures.py --out my_dir     # custom output dir
    python generate_textures.py --seed 7         # different variation
    python generate_textures.py --block 4        # chunkier PS1 pixels (1, 2, 4)
    python generate_textures.py --only rubber rail_dark
    python generate_textures.py --preview        # contact sheet + 2x2 tiling sheet
    python generate_textures.py --check          # seam + hue validation report

Design rules baked in
  * Palette only: charcoal, cool grey, dirty blue-grey, off-white, very dark metal
    (+ a very desaturated brown-grey for rust).  No cyan, no green.
  * No baked lighting / gradients across the tile / bevels / specular highlights.
  * All noise is periodic, all drawn marks wrap around the edges -> seamless.
  * "PS1 breakup" = block pixelation + ordered (Bayer) dither + luma banding.
    Banding is applied to luminance only so hue never drifts toward cyan/green.
"""
import argparse
import os
import sys
import zipfile

import numpy as np
from PIL import Image, ImageDraw

S = 512  # texture size (must stay a multiple of 256 for the geometric layouts)

# --------------------------------------------------------------------------
# Palette (RGB 0-255).  Channel order is kept R <= G <= B for the cool tones
# so mixing them can never produce a green or cyan cast.
# --------------------------------------------------------------------------
def c(r, g, b):
    return np.array([r, g, b], dtype=np.float32)

CHARCOAL   = c(38, 40, 43)
COOL_GREY  = c(104, 109, 115)
BLUE_GREY  = c(76, 86, 96)
OFF_WHITE  = c(188, 190, 192)
DARK_METAL = c(24, 26, 29)
RUST_GREY  = c(78, 72, 68)      # desaturated brown-grey, rust only


# --------------------------------------------------------------------------
# Noise + masks (all periodic over S)
# --------------------------------------------------------------------------
def tnoise(rng, px, py=None):
    """Tileable value noise with px x py random cells, smoothstep-interpolated."""
    py = px if py is None else py
    px, py = int(max(1, min(px, S))), int(max(1, min(py, S)))
    g = rng.random((py, px)).astype(np.float32)
    xs = np.arange(S) * px / S
    ys = np.arange(S) * py / S
    x0, y0 = np.floor(xs).astype(int), np.floor(ys).astype(int)
    fx, fy = xs - x0, ys - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    x1, y1 = (x0 + 1) % px, (y0 + 1) % py
    a, b = g[np.ix_(y0, x0)], g[np.ix_(y0, x1)]
    cc, d = g[np.ix_(y1, x0)], g[np.ix_(y1, x1)]
    fx, fy = fx[None, :], fy[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (cc * (1 - fx) + d * fx) * fy


def fbm(rng, base, octaves=5, gain=0.5, aniso=(1, 1)):
    """Fractal tileable noise, normalised to 0..1."""
    total, amp, norm = 0, 1.0, 0.0
    for o in range(octaves):
        px, py = base * aniso[0] * 2 ** o, base * aniso[1] * 2 ** o
        if px > S and py > S:
            break
        total = total + amp * tnoise(rng, px, py)
        norm += amp
        amp *= gain
    v = total / norm
    return (v - v.min()) / max(1e-6, (v.max() - v.min()))


def sstep(v, lo, hi):
    t = np.clip((v - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def ramp(v, stops):
    pos = [p for p, _ in stops]
    cols = np.array([col for _, col in stops], dtype=np.float32)
    return np.stack([np.interp(v, pos, cols[:, i]) for i in range(3)], -1).astype(np.float32)


def mix(a, b, t):
    t = np.asarray(t, dtype=np.float32)[..., None]
    return a * (1 - t) + b * t


def yx():
    return np.mgrid[0:S, 0:S]


def grid_mask(px, py, width, off=0):
    y, x = yx()
    return (((x - off) % px) < width) | (((y - off) % py) < width)


def _wrapped(draw_fn):
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    for ox in (-S, 0, S):
        for oy in (-S, 0, S):
            draw_fn(d, ox, oy)
    return np.asarray(im, dtype=np.float32) / 255.0


def lines(rng, n, length, width=1, wobble=0.0, angle=(0, np.pi), segs=1, strength=(140, 255)):
    """Scratches / cracks as a 0..1 mask. Polylines wrap around tile edges."""
    paths = []
    for _ in range(n):
        x, y = rng.random(2) * S
        a = rng.uniform(*angle)
        L = rng.uniform(*length)
        pts = [(x, y)]
        for _ in range(segs):
            a += rng.normal(0, wobble)
            x += np.cos(a) * L / segs
            y += np.sin(a) * L / segs
            pts.append((x, y))
        paths.append((pts, int(rng.uniform(*strength))))

    def draw(d, ox, oy):
        for pts, v in paths:
            d.line([(px + ox, py + oy) for px, py in pts], fill=v, width=width)
    return _wrapped(draw)


def discs(points, r):
    def draw(d, ox, oy):
        for (px, py) in points:
            d.ellipse([px - r + ox, py - r + oy, px + r + ox, py + r + oy], fill=255)
    return _wrapped(draw)


def streaks(rng, px=28, strength=1.0):
    """Vertical water/grime drip streaks 0..1."""
    v = 0.6 * tnoise(rng, px, 2) + 0.4 * tnoise(rng, px * 2, 3)
    return sstep(v, 0.52, 0.82) * strength


def speckle(rng, density):
    return rng.random((S, S)) > (1 - density)


def add(img, delta):
    return img + np.asarray(delta, dtype=np.float32)[..., None]


def mul(img, factor):
    return img * np.asarray(factor, dtype=np.float32)[..., None]


# --------------------------------------------------------------------------
# PS1-ish finishing: block pixelation, ordered dither, luma-only banding
# --------------------------------------------------------------------------
BAYER4 = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]],
                   dtype=np.float32) / 16.0 - 0.5)


def finish(img, block=2, levels=22, dither=0.7):
    img = np.clip(img, 0, 255).astype(np.float32)
    n = S // block
    if block > 1:
        img = img.reshape(n, block, n, block, 3).mean(axis=(1, 3))
    lum = img @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    step = 255.0 / (levels - 1)
    bay = np.tile(BAYER4, (n // 4, n // 4))
    lq = np.round((lum + bay * step * dither) / step) * step
    out = img + (lq - lum)[..., None]          # keep original chroma -> no hue drift
    out = np.clip(np.round(out), 0, 255).astype(np.uint8)
    if block > 1:
        out = np.repeat(np.repeat(out, block, 0), block, 1)
    return Image.fromarray(out, "RGB")


# --------------------------------------------------------------------------
# Shared building blocks
# --------------------------------------------------------------------------
def tile_geometry(rng, tw, th, bond, grout):
    y, x = yx()
    rows, cols = S // th, S // tw
    row = y // th
    xs = (x + ((row % 2) * (tw // 2) if bond else 0)) % S
    col = xs // tw
    lx, ly = xs % tw, y % th
    grout_mask = (lx < grout) | (ly < grout)
    d = np.minimum.reduce([lx - grout, tw - 1 - lx, ly - grout, th - 1 - ly])
    tone = rng.random((rows, cols)).astype(np.float32)[row, col]
    return grout_mask, d, tone


def scratch_pass(rng, img, light=0, dark=0, light_amt=10, dark_amt=14, length=(30, 160)):
    if dark:
        img = add(img, -lines(rng, dark, length) * dark_amt)
    if light:
        img = add(img, lines(rng, light, length) * light_amt)
    return img


# --------------------------------------------------------------------------
# Textures
# --------------------------------------------------------------------------
def concrete_dark(rng):
    base = fbm(rng, 3, 6, 0.55)
    img = ramp(base, [(0, c(30, 32, 35)), (0.5, c(42, 45, 49)), (1, c(58, 63, 69))])
    img = mix(img, BLUE_GREY * 0.62, sstep(fbm(rng, 2, 3), 0.5, 0.9) * 0.35)
    img = add(img, (rng.random((S, S)) - 0.5) * 10)
    img = mul(img, 1 - 0.30 * streaks(rng, 24))
    img = mul(img, np.where(speckle(rng, 0.006), 0.6, 1.0))
    img = mul(img, 1 - 0.18 * grid_mask(256, 256, 2))                 # formwork seams
    ties = [(128, 128), (384, 128), (128, 384), (384, 384)]
    img = mul(img, 1 - 0.30 * discs(ties, 5))                          # tie holes
    return scratch_pass(rng, img, light=10, dark=6, light_amt=8, dark_amt=10)


def concrete_worn(rng):
    base = fbm(rng, 4, 6, 0.55)
    img = ramp(base, [(0, c(66, 71, 77)), (0.5, c(84, 89, 95)), (1, c(104, 109, 115))])
    img = mix(img, c(60, 67, 76), sstep(fbm(rng, 3, 4), 0.55, 0.85) * 0.5)   # stains
    img = mix(img, COOL_GREY * 1.08, sstep(fbm(rng, 5, 4), 0.62, 0.9) * 0.35)  # worn patches
    img = add(img, (rng.random((S, S)) - 0.5) * 12)
    img = add(img, np.where(speckle(rng, 0.012), 14, 0))                # light flecks
    img = mul(img, 1 - 0.15 * streaks(rng, 20))
    img = mul(img, 1 - 0.12 * grid_mask(256, 256, 2))
    return scratch_pass(rng, img, light=22, dark=16, light_amt=9, dark_amt=14)


def concrete_damaged(rng):
    base = fbm(rng, 4, 6, 0.55)
    img = ramp(base, [(0, c(58, 63, 69)), (0.5, c(76, 81, 87)), (1, c(94, 99, 105))])
    img = mix(img, c(54, 60, 68), sstep(fbm(rng, 3, 4), 0.5, 0.85) * 0.5)
    img = add(img, (rng.random((S, S)) - 0.5) * 12)
    # spalled patches with exposed aggregate
    sp = fbm(rng, 3, 6, 0.6) + 0.07 * fbm(rng, 18, 3)
    sp = (sp - sp.min()) / (sp.max() - sp.min())
    inside = sstep(sp, 0.66, 0.675)
    ring = sstep(sp, 0.63, 0.65) - inside
    deep = ramp(fbm(rng, 24, 3), [(0, c(30, 32, 35)), (1, c(64, 68, 73))])
    deep = add(deep, (rng.random((S, S)) - 0.5) * 34)
    img = mix(img, deep, inside)
    img = add(img, ring * 7)
    # cracks
    cr = lines(rng, 4, (160, 320), width=2, wobble=0.30, segs=16)
    cr = np.maximum(cr, lines(rng, 12, (40, 130), width=1, wobble=0.40, segs=8))
    img = mul(img, 1 - 0.55 * cr)
    img = mul(img, 1 - 0.30 * streaks(rng, 22))
    img = mul(img, np.where(speckle(rng, 0.008), 0.55, 1.0))
    return scratch_pass(rng, img, light=10, dark=10, light_amt=8, dark_amt=12)


def old_tile(rng):
    """Subway wall tile, running-bond brick pattern (64x32 px tiles)."""
    g, d, tone = tile_geometry(rng, 64, 32, bond=True, grout=4)
    glaze = fbm(rng, 6, 4)
    t = ramp(0.6 * tone + 0.4 * glaze, [(0, c(120, 125, 131)), (1, c(172, 175, 179))])
    t = mix(t, BLUE_GREY * 1.3, sstep(fbm(rng, 3, 4), 0.55, 0.9) * 0.3)     # aged stain
    t = add(t, (rng.random((S, S)) - 0.5) * 8)
    grout = ramp(fbm(rng, 40, 3), [(0, c(40, 43, 47)), (1, c(62, 66, 71))])
    img = np.where(g[..., None], grout, t)
    chip = (d < 3) & (~g) & (rng.random((S, S)) > 0.72)
    img = mul(img, np.where(chip, 0.75, 1.0))
    img = mul(img, 1 - 0.22 * streaks(rng, 24))
    img = mul(img, np.where(~g, 1 - 0.40 * lines(rng, 14, (14, 40), wobble=0.3, segs=4), 1.0))
    return scratch_pass(rng, img, light=8, dark=6, light_amt=8, dark_amt=10)


def dirty_tile(rng):
    """Square 64px floor/wall tile in a straight grid, heavily grimed, some broken."""
    g, d, tone = tile_geometry(rng, 64, 64, bond=False, grout=4)
    glaze = fbm(rng, 5, 4)
    t = ramp(0.55 * tone + 0.45 * glaze, [(0, c(70, 78, 87)), (1, c(128, 133, 139))])
    t = mix(t, CHARCOAL * 1.2, sstep(fbm(rng, 3, 5), 0.5, 0.88) * 0.55)        # heavy grime
    t = add(t, (rng.random((S, S)) - 0.5) * 12)
    grout = ramp(fbm(rng, 40, 3), [(0, c(26, 28, 31)), (1, c(46, 49, 53))])
    broken = (tone < 0.08) & (~g)                                                 # missing tiles
    under = ramp(fbm(rng, 16, 4), [(0, c(30, 32, 35)), (1, c(56, 60, 66))])
    under = add(under, (rng.random((S, S)) - 0.5) * 22)
    img = np.where(g[..., None], grout, t)
    img = np.where(broken[..., None], under, img)
    img = mul(img, np.where((d < 3) & (~g) & (rng.random((S, S)) > 0.6), 0.7, 1.0))
    img = mul(img, 1 - 0.40 * streaks(rng, 22))
    img = mul(img, 1 - 0.30 * sstep(fbm(rng, 4, 4), 0.7, 0.92))                   # grease smudges
    img = mul(img, np.where(~g, 1 - 0.50 * lines(rng, 10, (50, 140), wobble=0.2, segs=6), 1.0))
    return scratch_pass(rng, img, light=14, dark=10, light_amt=9, dark_amt=12)


def rusty_metal(rng):
    base = ramp(fbm(rng, 4, 4), [(0, c(34, 37, 41)), (1, c(56, 60, 66))])
    rm = fbm(rng, 3, 6, 0.6) + 0.12 * fbm(rng, 24, 3)
    rm = (rm - rm.min()) / (rm.max() - rm.min())
    rust = sstep(rm, 0.50, 0.62)
    rust_col = ramp(fbm(rng, 10, 4), [(0, c(56, 52, 50)), (0.5, c(78, 72, 68)), (1, c(96, 90, 85))])
    img = mix(base, rust_col, rust)
    img = add(img, (rng.random((S, S)) - 0.5) * 12)
    img = mul(img, np.where(speckle(rng, 0.01) & (rust > 0.5), 0.7, 1.0))      # pitting
    img = mix(img, RUST_GREY * 0.9, streaks(rng, 22) * 0.30)
    img = mul(img, 1 - 0.45 * grid_mask(256, 256, 4))                           # plate seams
    rivets = [(x, y) for y in (10, 266) for x in range(16, S, 32)] + \
             [(x, y) for x in (10, 266) for y in range(16, S, 32)]
    img = add(img, discs(rivets, 3) * 14)
    return scratch_pass(rng, img, light=14, dark=8, light_amt=10, dark_amt=10)


def dark_metal(rng):
    brush = fbm(rng, 6, 4, 0.55, aniso=(1, 40))
    img = ramp(brush, [(0, c(22, 24, 27)), (0.5, c(30, 33, 37)), (1, c(42, 46, 51))])
    img = mix(img, BLUE_GREY * 0.45, sstep(fbm(rng, 3, 3), 0.55, 0.9) * 0.25)
    img = add(img, (rng.random((S, S)) - 0.5) * 7)
    img = mul(img, 1 - 0.40 * grid_mask(256, 256, 4))
    bolts = [(x, y) for x in (24, 280) for y in (24, 280, 152, 408)] + \
            [(x, y) for x in (152, 408) for y in (24, 280)]
    img = add(img, discs(bolts, 5) * 11)
    img = mul(img, 1 - 0.30 * discs(bolts, 2))
    img = mul(img, 1 - 0.18 * streaks(rng, 20))
    img = scratch_pass(rng, img, light=24, dark=8, light_amt=12, dark_amt=8, length=(40, 220))
    return img


def rail_dark(rng):
    """Horizontal rail strip: U runs along the rail. Worn band at y~160-224."""
    y, _ = yx()
    brush = fbm(rng, 3, 4, 0.55, aniso=(1, 24))
    img = ramp(brush, [(0, c(22, 24, 27)), (0.5, c(32, 35, 39)), (1, c(46, 50, 55))])
    band = sstep(1 - np.abs((y - 192) / 38.0), 0.0, 0.6)
    img = mix(img, c(82, 87, 93), band * (0.25 + 0.35 * brush))               # wheel-worn band
    img = mix(img, c(54, 49, 46), sstep(fbm(rng, 4, 5), 0.55, 0.85) * (1 - band) * 0.55)  # oxidation
    img = mul(img, 1 - 0.30 * sstep(fbm(rng, 3, 4), 0.68, 0.9))              # grease
    img = add(img, (rng.random((S, S)) - 0.5) * 9)
    grit = (y > 400) & speckle(rng, 0.08)                                      # ballast grit
    img = add(img, np.where(grit, (rng.random((S, S)) - 0.4) * 40, 0))
    sc = lines(rng, 36, (200, 480), angle=(-0.015, 0.015), strength=(100, 255))
    img = add(img, sc * band * 14)
    img = add(img, lines(rng, 10, (40, 160)) * 6)
    return img


def rubber(rng):
    """Studded rubber flooring, staggered 32px stud grid."""
    y, x = yx()
    row = y // 32
    lx = (x + (row % 2) * 16) % 32 - 16
    ly = y % 32 - 16
    stud = (lx * lx + ly * ly) < 10 * 10
    img = ramp(fbm(rng, 6, 4), [(0, c(28, 29, 31)), (1, c(42, 44, 47))])
    img = add(img, np.where(stud, 7, -6))                                     # stud/gap contrast
    img = add(img, (rng.random((S, S)) - 0.5) * 12)                            # pebble grain
    img = mix(img, BLUE_GREY * 0.5, sstep(fbm(rng, 3, 3), 0.6, 0.9) * 0.25)
    img = add(img, lines(rng, 30, (10, 50)) * 14 * stud)                       # scuffs on stud tops
    img = mul(img, 1 - 0.55 * lines(rng, 5, (60, 160), wobble=0.3, segs=8))   # cracks
    img = mul(img, 1 - 0.25 * sstep(fbm(rng, 4, 4), 0.65, 0.9))               # grime
    return img


def faded_sign_paint(rng):
    """Enamel sign panel: faded blue-grey paint, off-white inset frame, flaking. No text."""
    y, x = yx()
    paint = ramp(fbm(rng, 3, 4), [(0, c(66, 76, 87)), (0.5, c(80, 91, 102)), (1, c(100, 110, 120))])
    frame = ((x >= 24) & (x < 32)) | ((x >= S - 32) & (x < S - 24)) | \
            ((y >= 24) & (y < 32)) | ((y >= S - 32) & (y < S - 24))
    img = np.where(frame[..., None], OFF_WHITE * 0.82, paint)
    img = mix(img, c(150, 153, 157), sstep(fbm(rng, 2, 3), 0.55, 0.9) * 0.45)    # sun fade
    fm = fbm(rng, 6, 5) + 0.12 * fbm(rng, 40, 2)
    fm = (fm - fm.min()) / (fm.max() - fm.min())
    flake = sstep(fm, 0.66, 0.70)
    under = ramp(fbm(rng, 12, 4), [(0, c(30, 32, 35)), (1, c(54, 58, 63))])
    under = mix(under, RUST_GREY * 0.7, sstep(fbm(rng, 5, 3), 0.6, 0.9) * 0.45)
    img = mix(img, under, flake)
    img = add(img, (rng.random((S, S)) - 0.5) * 8)
    img = mul(img, np.where(speckle(rng, 0.005), 0.55, 1.0))
    img = mul(img, 1 - 0.30 * streaks(rng, 20))
    return scratch_pass(rng, img, light=10, dark=14, light_amt=10, dark_amt=14)


def warning_stripe(rng):
    """45-degree off-white / near-black hazard stripes, chipped and grimy."""
    y, x = yx()
    warp = (tnoise(rng, 8, 8) - 0.5) * 10
    stripe = (np.floor((x + y + warp) / 64).astype(int) % 2) == 1
    light = ramp(fbm(rng, 4, 4), [(0, c(150, 153, 156)), (1, c(184, 186, 189))])
    dark = ramp(fbm(rng, 4, 4), [(0, c(26, 28, 31)), (1, c(42, 45, 49))])
    img = np.where(stripe[..., None], light, dark)
    fm = fbm(rng, 6, 5) + 0.10 * fbm(rng, 36, 2)
    fm = (fm - fm.min()) / (fm.max() - fm.min())
    flake = sstep(fm, 0.62, 0.67) * stripe
    img = mix(img, ramp(fbm(rng, 14, 3), [(0, c(40, 43, 47)), (1, c(70, 74, 79))]), flake)
    img = mul(img, 1 - 0.40 * sstep(fbm(rng, 3, 5), 0.5, 0.88))                  # grime
    img = mul(img, 1 - 0.25 * streaks(rng, 22))
    img = add(img, (rng.random((S, S)) - 0.5) * 9)
    img = mul(img, np.where(speckle(rng, 0.006), 0.6, 1.0))
    return scratch_pass(rng, img, light=10, dark=18, light_amt=16, dark_amt=16)


TEXTURES = {
    "concrete_dark": concrete_dark,
    "concrete_worn": concrete_worn,
    "concrete_damaged": concrete_damaged,
    "old_tile": old_tile,
    "dirty_tile": dirty_tile,
    "rusty_metal": rusty_metal,
    "dark_metal": dark_metal,
    "rail_dark": rail_dark,
    "rubber": rubber,
    "faded_sign_paint": faded_sign_paint,
    "warning_stripe": warning_stripe,
}


# --------------------------------------------------------------------------
# Validation + previews
# --------------------------------------------------------------------------
def seam_ratio(arr, block=2):
    """Wrap-seam difference / difference at ordinary block boundaries (~1.0 = invisible seam)."""
    a = arr.astype(np.float32)
    idx = np.arange(block - 1, S - 1, block)          # last px of each block -> first px of next
    inner = (np.abs(a[:, idx] - a[:, idx + 1]).mean() + np.abs(a[idx] - a[idx + 1]).mean()) / 2
    wrap = (np.abs(a[:, -1] - a[:, 0]).mean() + np.abs(a[-1] - a[0]).mean()) / 2
    return wrap / max(inner, 1e-6)


def hue_report(arr):
    a = arr.astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(-1), a.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1)
    green = ((g - np.maximum(r, b)) >= 3).mean()
    cyan = (((g >= b - 3) & (r < g - 12)) & (sat > 0.10)).mean()
    return sat.max(), green, cyan


def make_previews(images, outdir, preview_dir):
    names = list(images)
    cols, th = 4, 256
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * th, rows * (th + 16)), (14, 14, 16))
    tiled = Image.new("RGB", (cols * th, rows * (th + 16)), (14, 14, 16))
    d1, d2 = ImageDraw.Draw(sheet), ImageDraw.Draw(tiled)
    for i, n in enumerate(names):
        im = images[n]
        x, y = (i % cols) * th, (i // cols) * (th + 16)
        sheet.paste(im.resize((th, th), Image.NEAREST), (x, y + 16))
        t = Image.new("RGB", (S * 2, S * 2))
        for ox in (0, S):
            for oy in (0, S):
                t.paste(im, (ox, oy))
        tiled.paste(t.resize((th, th), Image.NEAREST), (x, y + 16))
        d1.text((x + 4, y + 2), n, fill=(200, 200, 200))
        d2.text((x + 4, y + 2), n + " (2x2 tiled)", fill=(200, 200, 200))
    os.makedirs(preview_dir, exist_ok=True)
    sheet.save(os.path.join(preview_dir, "contact_sheet.png"))
    tiled.save(os.path.join(preview_dir, "tiling_check_2x2.png"))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="textures")
    ap.add_argument("--seed", type=int, default=1337)
    ap.add_argument("--block", type=int, default=2, choices=[1, 2, 4],
                    help="PS1 pixel block size (1=none, 2=256px look, 4=128px look)")
    ap.add_argument("--only", nargs="*", help="generate only these textures")
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--zip", help="also write a zip of the textures to this path")
    args = ap.parse_args()

    names = args.only or list(TEXTURES)
    bad = [n for n in names if n not in TEXTURES]
    if bad:
        sys.exit("unknown texture(s): " + ", ".join(bad))
    os.makedirs(args.out, exist_ok=True)

    images = {}
    for i, name in enumerate(names):
        rng = np.random.default_rng(args.seed * 1000 + list(TEXTURES).index(name))
        img = finish(TEXTURES[name](rng), block=args.block)
        img.save(os.path.join(args.out, name + ".png"))
        images[name] = img
        line = f"wrote {name}.png"
        if args.check:
            arr = np.asarray(img)
            sat, green, cyan = hue_report(arr)
            line += f"   seam={seam_ratio(arr, args.block):.2f}  max_sat={sat:.2f}  green={green:.4%}  cyan={cyan:.4%}"
        print(line)

    if args.preview:
        make_previews(images, args.out, os.path.join(args.out, "..", "preview"))
        print("wrote preview sheets")
    if args.zip:
        with zipfile.ZipFile(args.zip, "w", zipfile.ZIP_DEFLATED) as z:
            for n in names:
                z.write(os.path.join(args.out, n + ".png"), "textures/" + n + ".png")
        print("wrote", args.zip)


if __name__ == "__main__":
    main()
