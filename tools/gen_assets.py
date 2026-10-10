#!/usr/bin/env python3
"""Generates every art and sound asset of the game from code.

Run from the project root:  python3 tools/gen_assets.py
Needs: rsvg-convert (librsvg), Pillow, numpy.
"""
import math, os, subprocess, wave, struct, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = lambda *p: os.path.join(ROOT, "assets", *p)
STORE = lambda *p: os.path.join(ROOT, "store", *p)

GEMS = [  # name, base colour, cut
    ("ruby",       "#e2334c", "square"),
    ("sapphire",   "#2f6ff0", "kite"),
    ("emerald",    "#17a866", "octagon"),
    ("amethyst",   "#9a4fe6", "hexagon"),
    ("topaz",      "#f28a22", "round"),
    ("citrine",    "#f4c62e", "star"),
    ("pearl",      "#ece8f2", "pearl"),
    ("rosequartz", "#f25fae", "heart"),
    ("aquamarine", "#3fd6dc", "drop"),
    ("peridot",    "#a6dc3a", "triangle"),
]


def svg_to_png(svg, path, w, h=None):
    h = h or w
    subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), "-o", path], input=svg.encode(), check=True)


def shade(hexc, f):
    n = int(hexc[1:], 16)
    r, g, b = n >> 16, (n >> 8) & 255, n & 255
    t = 0 if f < 0 else 255
    p = abs(f)
    return "#%02x%02x%02x" % tuple(round((t - c) * p + c) for c in (r, g, b))


def outline(cut):
    P = []
    def poly(n, rot, rx=1, ry=1):
        for i in range(n):
            a = rot + i * 2 * math.pi / n
            P.append((math.cos(a) * rx, math.sin(a) * ry))
    if cut == "square":
        P += [(-.78, -.9), (.78, -.9), (.9, -.78), (.9, .78), (.78, .9), (-.78, .9), (-.9, .78), (-.9, -.78)]
    elif cut == "kite":
        P += [(0, .98), (-.95, -.25), (-.55, -.82), (.55, -.82), (.95, -.25)]
    elif cut == "octagon":
        P += [(-.5, -.95), (.5, -.95), (.82, -.62), (.82, .62), (.5, .95), (-.5, .95), (-.82, .62), (-.82, -.62)]
    elif cut == "hexagon":
        poly(6, 0, .97, .9)
    elif cut == "round":
        poly(12, math.pi / 12, .95, .95)
    elif cut == "star":
        for i in range(8):
            a = -math.pi / 2 + i * math.pi / 4
            r = .48 if i % 2 else 1
            P.append((math.cos(a) * r, math.sin(a) * r))
    elif cut == "triangle":
        P += [(0, -.95), (.98, .82), (-.98, .82)]
    elif cut == "heart":
        for i in range(24):
            t = i / 24 * 2 * math.pi
            P.append((16 * math.sin(t) ** 3 / 17,
                      -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) / 17 - .08))
    elif cut == "drop":
        for i in range(20):
            t = i / 20 * 2 * math.pi
            P.append((math.sin(t) * math.sin(t / 2) * .95, -math.cos(t) * .95))
    return P


def pts(P):
    return " ".join("%.2f,%.2f" % p for p in P)


def gem_svg(name, base, cut, size=128):
    c = size / 2
    R = size * 0.42
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">',
           "<defs>",
           f'<radialGradient id="sh" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#000" stop-opacity="0.45"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>',
           f'<linearGradient id="body" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{shade(base, .45)}"/><stop offset="0.45" stop-color="{base}"/><stop offset="1" stop-color="{shade(base, -.55)}"/></linearGradient>',
           f'<linearGradient id="tbl" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{shade(base, .6)}"/><stop offset="1" stop-color="{shade(base, .05)}"/></linearGradient>',
           f'<radialGradient id="pearl" cx="0.32" cy="0.28" r="0.75"><stop offset="0" stop-color="#ffffff"/><stop offset="0.45" stop-color="{base}"/><stop offset="0.85" stop-color="#a9a1b8"/><stop offset="1" stop-color="#7d7590"/></radialGradient>',
           f'<linearGradient id="iri" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#ffbee6" stop-opacity="0.22"/><stop offset="0.5" stop-color="#aae6ff" stop-opacity="0.12"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>',
           "</defs>"]
    out.append(f'<ellipse cx="{c + size*.03:.1f}" cy="{c + R*.95:.1f}" rx="{R*1.05:.1f}" ry="{R*.38:.1f}" fill="url(#sh)"/>')
    if cut == "pearl":
        out.append(f'<circle cx="{c}" cy="{c}" r="{R*.88:.1f}" fill="url(#pearl)"/>')
        out.append(f'<circle cx="{c}" cy="{c}" r="{R*.88:.1f}" fill="url(#iri)"/>')
        out.append(f'<ellipse cx="{c - R*.32:.1f}" cy="{c - R*.38:.1f}" rx="{R*.16:.1f}" ry="{R*.1:.1f}" fill="#fff" fill-opacity="0.9" transform="rotate(-34 {c - R*.32:.1f} {c - R*.38:.1f})"/>')
    else:
        P = [(c + x * R, c + y * R) for x, y in outline(cut)]
        T = [(c + x * R * .52, c + y * R * .52 - R * .04) for x, y in outline(cut)]
        sw = max(1, size * .02)
        out.append(f'<polygon points="{pts(P)}" fill="url(#body)" stroke="{shade(base, -.6)}" stroke-width="{sw:.2f}" stroke-linejoin="round"/>')
        step = 3 if len(P) > 12 else 1
        for i in range(0, len(P), step):
            j = (i + step) % len(P)
            mx, my = (P[i][0] + P[j][0]) / 2 - c, (P[i][1] + P[j][1]) / 2 - c
            light = (-mx - my) / (R * 2)
            fill, op = ("#fff", .08 + light * .35) if light > 0 else ("#000", .06 - light * .35)
            out.append(f'<polygon points="{pts([P[i], P[j], T[j], T[i]])}" fill="{fill}" fill-opacity="{op:.3f}" stroke="#fff" stroke-opacity="0.18" stroke-width="{max(.6, size*.008):.2f}"/>')
        out.append(f'<polygon points="{pts(T)}" fill="url(#tbl)" stroke="#fff" stroke-opacity="0.35" stroke-width="{max(.6, size*.008):.2f}"/>')
        out.append(f'<ellipse cx="{c - R*.28:.1f}" cy="{c - R*.34:.1f}" rx="{R*.14:.1f}" ry="{R*.06:.1f}" fill="#fff" fill-opacity="0.85" transform="rotate(-40 {c - R*.28:.1f} {c - R*.34:.1f})"/>')
    out.append("</svg>")
    return "\n".join(out)


ICONS = {  # 64x64 white glyphs
    "pause": '<rect x="16" y="12" width="11" height="40" rx="3"/><rect x="37" y="12" width="11" height="40" rx="3"/>',
    "play": '<path d="M20 12 L52 32 L20 52 Z" stroke-linejoin="round"/>',
    "sound_on": '<path d="M10 24h10l14-11v38L20 40H10z"/><path d="M41 22c4 3 4 17 0 20M47 15c9 7 9 27 0 34" fill="none" stroke="#fff" stroke-width="4.5" stroke-linecap="round"/>',
    "sound_off": '<path d="M10 24h10l14-11v38L20 40H10z"/><path d="M42 24l14 16M56 24L42 40" fill="none" stroke="#fff" stroke-width="4.5" stroke-linecap="round"/>',
    "music_on": '<path d="M24 14l26-6v34" fill="none" stroke="#fff" stroke-width="5" stroke-linejoin="round"/><path d="M24 14v34" stroke="#fff" stroke-width="5"/><ellipse cx="17" cy="48" rx="9" ry="7"/><ellipse cx="43" cy="42" rx="9" ry="7"/>',
    "music_off": '<path d="M24 14l26-6v34" fill="none" stroke="#fff" stroke-width="5" stroke-linejoin="round"/><path d="M24 14v34" stroke="#fff" stroke-width="5"/><ellipse cx="17" cy="48" rx="9" ry="7"/><ellipse cx="43" cy="42" rx="9" ry="7"/><path d="M8 8L56 56" stroke="#fff" stroke-width="5" stroke-linecap="round"/>',
    "trophy": '<path d="M18 8h28v14c0 10-6 17-14 17s-14-7-14-17z"/><path d="M18 13H9c0 9 4 14 11 15M46 13h9c0 9-4 14-11 15" fill="none" stroke="#fff" stroke-width="4"/><rect x="28" y="38" width="8" height="9"/><rect x="18" y="47" width="28" height="8" rx="2"/>',
    "home": '<path d="M8 31L32 10l24 21" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/><path d="M15 29v25h12V40h10v14h12V29L32 15z"/>',
    "video": '<rect x="6" y="14" width="52" height="36" rx="7"/><path d="M27 23l13 9-13 9z" fill="#1b1408"/>',
    "shuffle": '<path d="M8 20h12c12 0 14 24 26 24h8M8 44h12c5 0 8-4 10-8M38 26c2-3 5-6 8-6h8" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round"/><path d="M50 12l8 8-8 8zM50 36l8 8-8 8z"/>',
    "calendar": '<rect x="8" y="12" width="48" height="44" rx="6" fill="none" stroke="#fff" stroke-width="5"/><rect x="8" y="12" width="48" height="12" rx="4"/><rect x="18" y="5" width="6" height="14" rx="2"/><rect x="40" y="5" width="6" height="14" rx="2"/><rect x="18" y="31" width="9" height="8" rx="1.5"/><rect x="31" y="31" width="9" height="8" rx="1.5"/><rect x="18" y="42" width="9" height="8" rx="1.5"/>',
    "rotate": '<rect x="20" y="6" width="24" height="42" rx="5" fill="none" stroke="#fff" stroke-width="4"/><rect x="28" y="40" width="8" height="3" rx="1.5"/><path d="M10 40c0 8 6 14 14 16" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round"/><path d="M20 50l6 7-9 2z"/>',
    "crown": '<path d="M8 46L12 18l13 13 7-17 7 17 13-13 4 28z"/><rect x="8" y="49" width="48" height="7" rx="2"/>',
    "back": '<path d="M40 10L18 32l22 22" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>',
    "info": '<circle cx="32" cy="32" r="25" fill="none" stroke="#fff" stroke-width="5"/><circle cx="32" cy="19" r="4"/><rect x="28.5" y="27" width="7" height="22" rx="3"/>',
    "map": '<path d="M6 14l16-6 20 6 16-6v42l-16 6-20-6-16 6z" fill="none" stroke="#fff" stroke-width="5" stroke-linejoin="round"/><path d="M22 8v42M42 14v42" stroke="#fff" stroke-width="4"/>',
    "tasks": '<rect x="10" y="6" width="44" height="52" rx="6" fill="none" stroke="#fff" stroke-width="5"/><path d="M18 22l5 5 9-10M18 40l5 5 9-10" fill="none" stroke="#fff" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/><rect x="36" y="22" width="12" height="4" rx="2"/><rect x="36" y="40" width="12" height="4" rx="2"/>',
    "star": '<path d="M32 4l8.5 17.5 19.5 2.8-14 13.6 3.3 19.3L32 48l-17.3 9.2L18 37.9 4 24.3l19.5-2.8z"/>',
    "lock": '<rect x="12" y="28" width="40" height="30" rx="6"/><path d="M20 28v-8a12 12 0 0 1 24 0v8" fill="none" stroke="#fff" stroke-width="6"/>',
    "crystal": '<path d="M20 8h24l12 16-24 34L8 24z"/><path d="M8 24h48M20 8l12 16 12-16M32 24v34" fill="none" stroke="#000" stroke-opacity="0.25" stroke-width="3"/>',
    "hint": '<path d="M32 6a18 18 0 0 0-10 33v7h20v-7A18 18 0 0 0 32 6z"/><rect x="23" y="49" width="18" height="5" rx="2"/><rect x="26" y="56" width="12" height="4" rx="2"/>',
    "strikes": '<circle cx="32" cy="32" r="24" fill="none" stroke="#fff" stroke-width="5"/><circle cx="32" cy="32" r="13" fill="none" stroke="#fff" stroke-width="5"/><circle cx="32" cy="32" r="4"/>',
    "gift": '<rect x="8" y="26" width="48" height="32" rx="4"/><rect x="5" y="17" width="54" height="11" rx="3"/><rect x="28" y="17" width="8" height="41" fill="#000" fill-opacity="0.3"/><path d="M32 17c-6-12-20-8-14 0M32 17c6-12 20-8 14 0" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round"/>',
    "medal": '<path d="M20 4h10l6 16H26zM34 4h10l-6 16h-10z"/><circle cx="32" cy="40" r="18"/><circle cx="32" cy="40" r="11" fill="none" stroke="#000" stroke-opacity="0.3" stroke-width="4"/>',
    "puzzle": '<path d="M8 20h14a6 6 0 1 1 12 0h14v14a6 6 0 1 0 0 12v14H34a6 6 0 1 0-12 0H8V46a6 6 0 1 1 0-12z"/>',
    "duel": '<circle cx="20" cy="18" r="9"/><circle cx="44" cy="18" r="9"/><path d="M4 56c0-12 7-20 16-20s16 8 16 20zM28 56c0-12 7-20 16-20s16 8 16 20z"/>',
    "hand": '<path d="M26 6a5 5 0 0 1 10 0v22l3-1a5 5 0 0 1 6 3l1 2a5 5 0 0 1 6 3v10c0 10-7 17-17 17h-4c-7 0-12-4-15-10l-7-13a5 5 0 0 1 8-6l9 9z"/>',
    "link": '<rect x="6" y="20" width="30" height="24" rx="12" fill="none" stroke="#fff" stroke-width="7"/><rect x="28" y="20" width="30" height="24" rx="12" fill="none" stroke="#fff" stroke-width="7"/>',
    "restart": '<path d="M48 22A19 19 0 1 0 51 36" fill="none" stroke="#fff" stroke-width="5.5" stroke-linecap="round"/><path d="M42 10l12 2-2 12z"/>',
}


def gear_path(teeth=8, r_out=28, r_in=21, hole=9, c=32):
    pts_ = []
    for i in range(teeth * 4):
        a = i * 2 * math.pi / (teeth * 4) - math.pi / 2
        r = r_out if i % 4 in (1, 2) else r_in
        pts_.append((c + math.cos(a) * r, c + math.sin(a) * r))
    d = "M" + " L".join("%.2f %.2f" % p for p in pts_) + " Z"
    d += f" M{c + hole} {c} A{hole} {hole} 0 1 0 {c - hole} {c} A{hole} {hole} 0 1 0 {c + hole} {c} Z"
    return f'<path fill-rule="evenodd" d="{d}"/>'


# bright "toy" palette for the board tiles, same order as GEMS
TOY = ["#ff4d5e", "#3d8bff", "#22c97a", "#a35cff", "#ff9a2e", "#ffcf33", "#dfe5f0", "#ff6fb5", "#2fd6e0", "#9be03a"]


def tile_svg(base, cut, size=128):
    """A glossy, bevelled toy tile in `base` colour with the gem's silhouette embossed on it."""
    c = size / 2
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}"><defs>',
           f'<linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{shade(base, .3)}"/>'
           f'<stop offset="0.55" stop-color="{base}"/><stop offset="1" stop-color="{shade(base, -.3)}"/></linearGradient>',
           f'<linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{shade(base, .75)}"/>'
           f'<stop offset="1" stop-color="{shade(base, .35)}"/></linearGradient>',
           '</defs>']
    out.append(f'<rect x="7" y="11" width="114" height="112" rx="24" fill="#000" fill-opacity="0.32"/>')
    out.append(f'<rect x="6" y="5" width="116" height="112" rx="24" fill="{shade(base, -.38)}"/>')
    out.append(f'<rect x="6" y="5" width="116" height="104" rx="24" fill="url(#b)"/>')
    out.append(f'<rect x="10" y="9" width="108" height="96" rx="20" fill="none" stroke="#fff" stroke-opacity="0.35" stroke-width="3"/>')
    out.append(f'<rect x="16" y="12" width="96" height="34" rx="15" fill="#fff" fill-opacity="0.26"/>')
    R = 32
    if cut == "pearl":
        out.append(f'<circle cx="{c}" cy="{c - 2}" r="{R * .82}" fill="url(#g)" stroke="{shade(base, -.45)}" stroke-width="3"/>')
    else:
        P = [(c + x * R, c - 2 + y * R) for x, y in outline(cut)]
        out.append(f'<polygon points="{pts(P)}" fill="url(#g)" stroke="{shade(base, -.45)}" stroke-width="3" stroke-linejoin="round"/>')
    out.append(f'<ellipse cx="{c - 12}" cy="{c - 16}" rx="8" ry="4.5" fill="#fff" fill-opacity="0.85" transform="rotate(-35 {c - 12} {c - 16})"/>')
    out.append("</svg>")
    return "\n".join(out)


# Bright mode block palettes (6 colours each): soft, juicy, never neon. The board cycles
# through them on big combos and new boards, together with the background.
BLOCK_PALETTES = [
    ["#ef5f67", "#f59e45", "#f6c94e", "#5cc87a", "#4b9cf0", "#a477e0"],  # candy
    ["#f0857a", "#f2b65a", "#5ccfb0", "#36b5d8", "#4a7fd6", "#8f7ae6"],  # ocean
    ["#e0507f", "#f07f6a", "#f2c14e", "#8bc34a", "#5b8def", "#b05fd6"],  # berry
    ["#e86a5a", "#e9a03b", "#d9c64a", "#4fb36a", "#3f9fb0", "#7d6fd0"],  # forest
    ["#ff6b8b", "#ffa463", "#ffd966", "#6ed9a9", "#60a5fa", "#c084fc"],  # night
]
BLOCK_SYMBOL = ["square", "round", "star", "octagon", "kite", "hexagon"]


def block_svg(base, cut, size=128):
    """A chunky bevelled block: light top face, darker lower edge, glossy corner, faint emboss."""
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}"><defs>',
           f'<linearGradient id="f" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{shade(base, .18)}"/>'
           f'<stop offset="1" stop-color="{shade(base, -.06)}"/></linearGradient></defs>',
           f'<rect x="6" y="10" width="116" height="114" rx="16" fill="#000" fill-opacity="0.22"/>',
           f'<rect x="6" y="6" width="116" height="114" rx="16" fill="{shade(base, -.32)}"/>',
           f'<rect x="6" y="6" width="116" height="104" rx="16" fill="url(#f)"/>',
           f'<polygon points="6,22 22,6 106,6 122,22 106,26 22,26" fill="#fff" fill-opacity="0.28"/>',
           f'<rect x="18" y="18" width="92" height="80" rx="10" fill="{shade(base, .08)}"/>',
           f'<rect x="18" y="18" width="92" height="80" rx="10" fill="none" stroke="{shade(base, -.18)}" stroke-opacity="0.35" stroke-width="3"/>',
           f'<circle cx="30" cy="30" r="6" fill="#fff" fill-opacity="0.75"/>']
    P = [(64 + x * 22, 58 + y * 22) for x, y in outline(cut)]
    out.append(f'<polygon points="{pts(P)}" fill="{shade(base, -.25)}" fill-opacity="0.22" stroke="#fff" stroke-opacity="0.2" stroke-width="2" stroke-linejoin="round"/>')
    out.append("</svg>")
    return "\n".join(out)


# Bright mode looks: the first glossy tile style, with big bold silhouettes chosen to be as
# different from each other as possible. Look 0 is the original palette, then five more.
BRIGHT_SHAPES = ["heart", "kite", "triangle", "star", "round", "square"]
BRIGHT_LOOKS = [["#ff4d5e", "#3d8bff", "#22c97a", "#ffcf33", "#ff9a2e", "#a35cff"]] + [
    [p[0], p[4], p[3], p[2], p[1], p[5]] for p in BLOCK_PALETTES] + [
    ["#f4a6b8", "#5c84c9", "#8fe3cf", "#f0d58a", "#c7d7ea", "#b8a6f2"],   # 6 winter (season)
    ["#c8283c", "#2e8f8f", "#7ccf3a", "#e8e0c8", "#f07b1d", "#7b3fb5"],   # 7 halloween (season)
    ["#d64a5a", "#3f6fd6", "#2fa36b", "#e6b93c", "#c88a4a", "#9aa3b5"],   # 8 gold (7-day streak)
]


def bright_tile_svg(base, cut, size=128):
    """Glossy toy tile like the first look, with a large white silhouette outlined in the
    tile's dark shade so the shape reads at a glance even without colour."""
    c = size / 2
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}"><defs>',
           f'<linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{shade(base, .3)}"/>'
           f'<stop offset="0.55" stop-color="{base}"/><stop offset="1" stop-color="{shade(base, -.3)}"/></linearGradient>',
           '<linearGradient id="w" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/>'
           f'<stop offset="1" stop-color="{shade(base, .78)}"/></linearGradient></defs>',
           '<rect x="7" y="11" width="114" height="112" rx="24" fill="#000" fill-opacity="0.32"/>',
           f'<rect x="6" y="5" width="116" height="112" rx="24" fill="{shade(base, -.38)}"/>',
           '<rect x="6" y="5" width="116" height="104" rx="24" fill="url(#b)"/>',
           '<rect x="10" y="9" width="108" height="96" rx="20" fill="none" stroke="#fff" stroke-opacity="0.35" stroke-width="3"/>',
           '<rect x="16" y="12" width="96" height="30" rx="14" fill="#fff" fill-opacity="0.22"/>']
    R = 38
    dark = shade(base, -.5)
    if cut == "round":
        out.append(f'<circle cx="{c}" cy="{c - 2}" r="{R * .8}" fill="url(#w)" stroke="{dark}" stroke-width="5"/>')
    else:
        P = [(c + x * R, c - 2 + y * R) for x, y in outline(cut)]
        out.append(f'<polygon points="{pts(P)}" fill="url(#w)" stroke="{dark}" stroke-width="5" stroke-linejoin="round"/>')
    out.append("</svg>")
    return "\n".join(out)


def make_specials():
    """Joker tile (rainbow with a white star) and the crate overlay drawn on boxes."""
    j = ('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><defs>'
         '<linearGradient id="r" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ff5d7a"/>'
         '<stop offset="0.3" stop-color="#ffc94d"/><stop offset="0.55" stop-color="#4fd18b"/>'
         '<stop offset="0.8" stop-color="#4b9cf0"/><stop offset="1" stop-color="#a477e0"/></linearGradient></defs>'
         '<rect x="7" y="11" width="114" height="112" rx="24" fill="#000" fill-opacity="0.32"/>'
         '<rect x="6" y="5" width="116" height="112" rx="24" fill="#3a2a6a"/>'
         '<rect x="6" y="5" width="116" height="104" rx="24" fill="url(#r)"/>'
         '<rect x="10" y="9" width="108" height="96" rx="20" fill="none" stroke="#fff" stroke-opacity="0.5" stroke-width="3"/>'
         '<rect x="16" y="12" width="96" height="30" rx="14" fill="#fff" fill-opacity="0.25"/>')
    P = [(64 + x * 40, 58 + y * 40) for x, y in outline("star")]
    j += f'<polygon points="{pts(P)}" fill="#fff" stroke="#3a2a6a" stroke-width="5" stroke-linejoin="round"/></svg>'
    svg_to_png(j, A("tiles", "joker.png"), 128)
    box = ('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">'
           '<rect x="8" y="8" width="112" height="106" rx="14" fill="none" stroke="#8a5a2b" stroke-width="14"/>'
           '<rect x="8" y="8" width="112" height="106" rx="14" fill="none" stroke="#c98a4a" stroke-width="8"/>'
           '<path d="M16 16L112 106M112 16L16 106" stroke="#8a5a2b" stroke-width="12" stroke-linecap="round"/>'
           '<path d="M16 16L112 106M112 16L16 106" stroke="#d99c5a" stroke-width="6" stroke-linecap="round"/>'
           + "".join(f'<circle cx="{x}" cy="{y}" r="4" fill="#5b3a1a"/>' for x, y in ((14, 14), (114, 14), (14, 108), (114, 108)))
           + '</svg>')
    svg_to_png(box, A("tiles", "box.png"), 128)


def make_tiles():
    for look, pal in enumerate(BRIGHT_LOOKS):
        for i, col in enumerate(pal):
            svg_to_png(bright_tile_svg(col, BRIGHT_SHAPES[i]), A("tiles", f"look_{look}_{i}.png"), 128)
    for t, pal in enumerate(BLOCK_PALETTES):
        for i, col in enumerate(pal):
            svg_to_png(block_svg(col, BLOCK_SYMBOL[i]), A("tiles", f"block_{t}_{i}.png"), 128)
    for i, (name, _base, cut) in enumerate(GEMS):
        svg_to_png(tile_svg(TOY[i], cut), A("tiles", f"tile_{i}.png"), 128)
    # empty slot: a soft rounded hollow
    slot = ('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96">'
            '<rect x="6" y="6" width="84" height="84" rx="18" fill="#000" fill-opacity="0.28"/>'
            '<rect x="6" y="6" width="84" height="84" rx="18" fill="none" stroke="#fff" stroke-opacity="0.08" stroke-width="3"/>'
            '<rect x="10" y="10" width="76" height="14" rx="7" fill="#000" fill-opacity="0.18"/></svg>')
    svg_to_png(slot, A("ui", "slot_tile.png"), 96)


def make_previews():
    """Small board previews for the mode cards, built from the game's own gem art."""
    w, h, c = 360, 220, 40
    rnd = random.Random(11)
    # classic: faceted gems on velvet
    velvet = Image.open(A("ui", "velvet.png")).convert("RGBA")
    pv = Image.new("RGBA", (w, h))
    for yy in range(0, h, 256):
        for xx in range(0, w, 256):
            pv.paste(velvet, (xx, yy))
    pv.alpha_composite(Image.open(A("ui", "vignette.png")).resize((w, h)))
    for gy in range(5):
        for gx in range(9):
            if rnd.random() < 0.78:
                g = Image.open(A("gems", f"gem_{rnd.randrange(10)}.png")).convert("RGBA").resize((c - 2, c - 2), Image.LANCZOS)
                pv.alpha_composite(g, (3 + gx * c, 12 + gy * c))
    pv.save(A("ui", "preview_classic.png"))
    # bright: glossy tiles on a blue gradient
    y = np.linspace(0, 1, h)[:, None]
    top, bot = np.array([61, 99, 224]), np.array([27, 44, 140])
    grad = (top * (1 - y) + bot * y)[:, None, :].repeat(w, 1).reshape(h, w, 3)
    pb = Image.fromarray(np.dstack([grad, np.full((h, w), 255)]).astype(np.uint8), "RGBA")
    slot = Image.open(A("ui", "slot_tile.png")).convert("RGBA").resize((c, c), Image.LANCZOS)
    for gy in range(5):
        for gx in range(9):
            pb.alpha_composite(slot, (0 + gx * c, 10 + gy * c))
            if rnd.random() < 0.7:
                t = Image.open(A("tiles", f"look_0_{rnd.randrange(6)}.png")).convert("RGBA").resize((c - 2, c - 2), Image.LANCZOS)
                pb.alpha_composite(t, (1 + gx * c, 11 + gy * c))
    pb.save(A("ui", "preview_bright.png"))


def make_icons():
    ICONS["settings"] = gear_path()
    # settings controls: a pill switch (on/off) and a round slider knob
    sw = ('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="36" viewBox="0 0 64 36">'
          '<rect x="2" y="3" width="60" height="30" rx="15" fill="{bg}" stroke="#d2ab55" stroke-width="2"/>'
          '<circle cx="{cx}" cy="18" r="11" fill="{knob}"/></svg>')
    svg_to_png(sw.format(bg="#d2ab55", cx=47, knob="#1b1408"), A("ui", "switch_on.png"), 64, 36)
    svg_to_png(sw.format(bg="#0b2224", cx=17, knob="#8ea6a1"), A("ui", "switch_off.png"), 64, 36)
    knob = ('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">'
            '<circle cx="16" cy="16" r="13" fill="#f7e2a8" stroke="#8a6a2a" stroke-width="2"/></svg>')
    svg_to_png(knob, A("ui", "knob.png"), 32)
    for name, body in ICONS.items():
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="#fff">{body}</svg>'
        svg_to_png(svg, A("ui", f"icon_{name}.png"), 64)


def make_textures():
    rng = np.random.default_rng(7)
    # velvet cloth: seamless fine noise over deep bottle green
    n = rng.normal(0, 6.5, (256, 256))
    n = (n + np.roll(n, 1, 0) * .5 + np.roll(n, 1, 1) * .5) / 2
    base = np.array([18, 50, 52], float)
    img = np.clip(base[None, None, :] + n[..., None] * np.array([.8, 1, 1]), 0, 255).astype(np.uint8)
    Image.fromarray(img).save(A("ui", "velvet.png"))
    # vignette (alpha only)
    s = 512
    y, x = np.mgrid[0:s, 0:s] / (s - 1) * 2 - 1
    d = np.clip(np.sqrt(x * x + y * y) / 1.35, 0, 1)
    a = (d ** 2.2 * 190).astype(np.uint8)
    v = np.zeros((s, s, 4), np.uint8); v[..., 3] = a
    Image.fromarray(v).save(A("ui", "vignette.png"))
    # pressed slot
    s = 96
    y, x = np.mgrid[0:s, 0:s] - (s - 1) / 2
    r = np.sqrt(x * x + (y + 3) ** 2) / (s * .44)
    alpha = np.where(r < 1, (0.36 - 0.2 * r) * 255, 0)
    rim = np.clip(1 - abs(np.sqrt(x * x + y * y) / (s * .44) - 1) * 14, 0, 1) * (y > 0) * 22
    sl = np.zeros((s, s, 4), np.uint8)
    sl[..., :3] = np.where(rim[..., None] > 0, 255, 0)
    sl[..., 3] = np.clip(alpha + rim, 0, 255)
    slot_img = Image.fromarray(sl).filter(ImageFilter.GaussianBlur(1.2))
    rr = s * .44 * (0.3 / 0.42)  # gold ring at 0.3 cell radius (the texture spans 0.84 cell)
    ImageDraw.Draw(slot_img).ellipse([s / 2 - rr, s / 2 - rr, s / 2 + rr, s / 2 + rr], outline=(210, 171, 85, 70), width=3)
    slot_img.save(A("ui", "slot.png"))
    # soft round glow, tinted in code (gem halos, ambient light)
    s = 128
    y, x = np.mgrid[0:s, 0:s] - (s - 1) / 2
    d = np.clip(np.sqrt(x * x + y * y) / (s / 2), 0, 1)
    gl = np.zeros((s, s, 4), np.uint8)
    gl[..., :3] = 255
    gl[..., 3] = ((1 - d) ** 2.4 * 255).astype(np.uint8)
    Image.fromarray(gl).save(A("fx", "glow.png"))
    # sparkle for knock-out particles
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'
           '<defs><radialGradient id="g"><stop offset="0" stop-color="#fff" stop-opacity="0.9"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient></defs>'
           '<circle cx="32" cy="32" r="22" fill="url(#g)"/>'
           '<path d="M32 2 C34 26 38 30 62 32 C38 34 34 38 32 62 C30 38 26 34 2 32 C26 30 30 26 32 2Z" fill="#fff"/></svg>')
    svg_to_png(svg, A("fx", "sparkle.png"), 64)


# ---------------- sound ----------------
SR = 44100


def write_wav(path, x):
    x = np.clip(x, -1, 1)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32000).astype("<i2").tobytes())


def liven(x, room=0.22, width=0.5, drive=1.4):
    """Make a dry synth effect sound alive: a detuned double for width, a short room tail and
    a touch of saturation, then normalise to the original peak."""
    x = np.asarray(x, float)
    peak = np.max(np.abs(x)) + 1e-9
    d1, d2 = int(.009 * SR), int(.017 * SR)
    idx = np.arange(len(x))
    y = x.copy()
    y[d1:] += width * .6 * np.interp(idx[: len(x) - d1] * 1.006, idx, x)
    y[d2:] += width * .4 * np.interp(idx[: len(x) - d2] * .994, idx, x)
    rng = np.random.default_rng(len(x))
    n_ir = int(.45 * SR)
    ir = rng.normal(0, 1, n_ir) * np.exp(-np.arange(n_ir) / (.11 * SR))
    ir[: int(.004 * SR)] = 0  # pre-delay
    wet = np.convolve(y, ir)[: len(y) + int(.35 * SR)] * room / np.sqrt(n_ir) * 6
    y = np.pad(y, (0, len(wet) - len(y))) + wet
    y = np.tanh(y * drive) / np.tanh(drive)
    return y / (np.max(np.abs(y)) + 1e-9) * peak


def write_sfx(path, x):
    write_wav(path, liven(x))


def env(n, attack=0.004, decay=0.25):
    t = np.arange(n) / SR
    return np.minimum(t / attack, 1) * np.exp(-t / decay)


def bell(freq, dur, decay=.35, vol=.5):
    n = int(SR * dur); t = np.arange(n) / SR
    x = sum(a * np.sin(2 * np.pi * freq * m * t) * np.exp(-t / (decay / m ** .6))
            for m, a in ((1, 1), (2.76, .45), (5.4, .22), (8.93, .1)))
    return x * env(n, .002, 10) * vol


def make_sounds():
    rng = np.random.default_rng(3)
    # knock-outs: crystal chime, brighter and fuller with more gems
    for k, notes in ((2, (1046.5, 1318.5)), (3, (1046.5, 1318.5, 1568)), (4, (1046.5, 1318.5, 1568, 2093))):
        n = int(SR * 1.0); x = np.zeros(n)
        for i, f in enumerate(notes):
            o = int(i * .045 * SR); b = bell(f, 1.0 - i * .045, .3, .32)
            x[o:o + len(b)] += b[:n - o]
        click = rng.normal(0, 1, int(SR * .02)) * env(int(SR * .02), .0005, .004) * .35
        x[:len(click)] += click
        write_sfx(A("audio", f"knock{k}.wav"), x * .8)
    # miss: dull thud on cloth
    n = int(SR * .22); t = np.arange(n) / SR
    thud = np.sin(2 * np.pi * (110 - 50 * t / .22) * t) * env(n, .002, .06)
    noise = rng.normal(0, 1, n) * env(n, .001, .02) * .25
    write_sfx(A("audio", "miss.wav"), (thud * .8 + noise) * .9)
    # tick for the last seconds
    n = int(SR * .06)
    write_sfx(A("audio", "tick.wav"), bell(2400, .06, .015, .35)[:n])
    # ui click
    write_sfx(A("audio", "click.wav"), bell(1800, .08, .02, .3))
    # start: rising arpeggio
    n = int(SR * .9); x = np.zeros(n)
    for i, f in enumerate((523.25, 659.25, 783.99, 1046.5)):
        o = int(i * .08 * SR); b = bell(f, .9 - i * .08, .25, .3); x[o:o + len(b)] += b
    write_sfx(A("audio", "start.wav"), x)
    # game over: falling three notes
    n = int(SR * 1.3); x = np.zeros(n)
    for i, f in enumerate((783.99, 659.25, 523.25)):
        o = int(i * .16 * SR); b = bell(f, 1.3 - i * .16, .45, .32); x[o:o + len(b)] += b
    write_sfx(A("audio", "over.wav"), x)
    # bonus time
    write_sfx(A("audio", "bonus.wav"), bell(1568, .5, .2, .3) + np.pad(bell(2093, .42, .2, .25), (int(.08 * SR), 0))[:int(SR * .5)])
    make_combo_sounds(rng)
    make_voices()
    make_bright_sounds(rng)
    make_music()


def arpeggio(notes, step, tail, decay=.3, vol=.28):
    n = int(SR * (step * len(notes) + tail)); x = np.zeros(n)
    for i, f in enumerate(notes):
        o = int(i * step * SR); b = bell(f, n / SR - i * step, decay, vol); x[o:o + len(b)] += b[:n - o]
    return x


def shimmer(rng, dur, vol=.12):
    """Glittery noise: many tiny high bells at random times."""
    n = int(SR * dur); x = np.zeros(n)
    for _ in range(int(dur * 40)):
        o = rng.integers(0, int(n * .8)); f = rng.uniform(2500, 6000)
        b = bell(f, .25, .05, vol * rng.uniform(.4, 1)); x[o:o + len(b)] += b[:n - o]
    return x * np.linspace(1, .2, n)


def make_combo_sounds(rng):
    # combo tier up: quick rising fifth
    write_sfx(A("audio", "combo_up.wav"), arpeggio((1174.7, 1760, 2349.3), .05, .45, .2, .26))
    # combo lost: soft falling pair
    write_sfx(A("audio", "combo_break.wav"), arpeggio((880, 659.25), .09, .35, .15, .18))
    # precise combo: major arpeggio with glitter
    x = arpeggio((783.99, 987.77, 1174.7, 1567.98), .07, 1.0, .35, .26)
    x[:len(shimmer(rng, 1.0))] += shimmer(rng, 1.0)[:len(x)]
    write_sfx(A("audio", "precise.wav"), x * .85)
    # perfect combo: two-octave fanfare, low thump, long glitter
    n = int(SR * 1.8)
    x = np.zeros(n)
    a = arpeggio((523.25, 659.25, 783.99, 1046.5, 1318.5, 1567.98, 2093), .055, 1.2, .45, .24); x[:len(a)] += a[:n]
    t = np.arange(int(SR * .35)) / SR
    x[:len(t)] += np.sin(2 * np.pi * (90 - 40 * t) * t) * np.exp(-t / .12) * .6
    g = shimmer(rng, 1.8, .14); x[:len(g)] += g
    write_sfx(A("audio", "perfect.wav"), np.tanh(x * 1.2) * .8)


def pluck(freq, dur, vol=.3, bright=1.0):
    n = int(SR * dur); t = np.arange(n) / SR
    x = (np.sin(2 * np.pi * freq * t) + .5 * bright * np.sin(4 * np.pi * freq * t) + .25 * bright * np.sin(6 * np.pi * freq * t))
    return x * np.exp(-t / (dur * .35)) * np.minimum(t / .003, 1) * vol


def pop(freq, dur=.16, vol=.5):
    """Bubbly pop: a quick downward pitch sweep with a soft click."""
    n = int(SR * dur); t = np.arange(n) / SR
    f = freq * (1.6 - .6 * np.minimum(t / (dur * .5), 1))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t / (dur * .28)) * np.minimum(t / .002, 1) * vol


def marimba(freq, dur=.5, vol=.4):
    """Glassy marimba: fundamental plus a bright 4th partial, fast decay, soft mallet click."""
    n = int(SR * dur); t = np.arange(n) / SR
    x = (np.sin(2 * np.pi * freq * t) * np.exp(-t / .25) + .35 * np.sin(2 * np.pi * freq * 3.98 * t) * np.exp(-t / .06)
         + .15 * np.sin(2 * np.pi * freq * 9.1 * t) * np.exp(-t / .02))
    return x * np.minimum(t / .002, 1) * vol


def fm_ding(freq, dur=.45, vol=.4, index=3.0, ratio=3.5):
    """Clean arcade 'ding': a small FM bell with a bright attack that mellows quickly."""
    n = int(SR * dur); t = np.arange(n) / SR
    mod = index * np.exp(-t / .06) * np.sin(2 * np.pi * freq * ratio * t)
    x = np.sin(2 * np.pi * freq * t + mod) * np.exp(-t / (dur * .35))
    x += .25 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t / (dur * .15))
    return x * np.minimum(t / .0015, 1) * vol


def whoosh(dur, f0, f1, vol=.25, seed=5):
    """Rising filtered-noise sweep."""
    n = int(SR * dur); t = np.arange(n) / SR
    noise = np.random.default_rng(seed).normal(0, 1, n)
    out = np.zeros(n); y1 = y2 = 0.0
    fc = f0 * (f1 / f0) ** (t / dur)
    for i in range(n):  # simple resonant band-pass that follows fc
        g = 2 * np.sin(np.pi * fc[i] / SR)
        y1 += g * (noise[i] - y1 - .6 * y2)
        y2 += g * y1
        out[i] = y1
    env_ = np.sin(np.pi * np.minimum(t / dur, 1)) ** 1.5
    return out / (np.max(np.abs(out)) + 1e-9) * env_ * vol


def _mix(*parts):
    n = max(len(p) for p, _ in parts)
    x = np.zeros(n)
    for p, off in parts:
        o = int(off * SR)
        x[o:o + len(p)] += p[:max(0, n - o)]
    return x


def make_bright_sounds(rng):
    """Bright mode: arcade-style dings that climb with the combo (the game plays the knock at
    rising pitches), whooshes and chord hits for combo steps, and bells."""
    for k in (2, 3, 4):
        x = _mix((fm_ding(880, .45, .42), 0), (fm_ding(1760, .3, .12, 1.5), .005))
        if k >= 3:
            x = _mix((x, 0), (fm_ding(1318.5, .4, .2), .03))
        if k >= 4:
            x = _mix((x, 0), (fm_ding(2637, .35, .12), .05), (shimmer(rng, .4, .06), .02))
        write_sfx(A("audio", f"b_knock{k}.wav"), x)
    n = int(SR * .25); t = np.arange(n) / SR
    write_sfx(A("audio", "b_miss.wav"), np.sin(2 * np.pi * (180 - 60 * t / .25) * t) * np.exp(-t / .07) * .5)
    write_sfx(A("audio", "b_combo_up.wav"), _mix((whoosh(.28, 400, 4000, .2), 0),
        (fm_ding(1046.5, .3, .3), .18), (fm_ding(1568, .3, .3), .23), (fm_ding(2093, .45, .32), .28)))
    cb = marimba(392, .4, .25)
    m2 = np.pad(marimba(330, .3, .2), (int(.08 * SR), 0))
    cb[:min(len(cb), len(m2))] += m2[:min(len(cb), len(m2))]
    write_sfx(A("audio", "b_combo_break.wav"), cb)
    chord = _mix((fm_ding(1046.5, .9, .3), 0), (fm_ding(1318.5, .9, .26), 0), (fm_ding(1568, .9, .26), 0))
    write_sfx(A("audio", "b_precise.wav"), _mix((whoosh(.35, 300, 5000, .25, 7), 0), (_kick() * .6, .33), (chord, .33),
        (shimmer(rng, .9, .1), .35)))
    arp = [(fm_ding(f, .6, .26), .32 + i * .05) for i, f in enumerate((523, 659, 784, 1047, 1319, 1568, 2093, 2637))]
    big = _mix((whoosh(.36, 250, 6000, .28, 9), 0), (_kick(), .34), (_snare(rng) * .5, .34), *arp,
               (shimmer(rng, 1.6, .12), .4))
    write_sfx(A("audio", "b_perfect.wav"), np.tanh(big * 1.2) * .8)
    write_sfx(A("audio", "b_start.wav"), arpeggio((784, 988, 1175, 1568), .06, .5, .2, .24))
    write_sfx(A("audio", "b_bonus.wav"), arpeggio((1568, 2093), .06, .35, .12, .22))
    write_sfx(A("audio", "b_over.wav"), arpeggio((784, 659, 523, 392), .12, .9, .3, .25))
    write_sfx(A("audio", "b_tick.wav"), marimba(1760, .08, .25))
    # new events
    st = bell(1760, .6, .25, .35)
    s2 = np.pad(bell(2637, .5, .2, .2), (int(.05 * SR), 0))
    st[:min(len(st), len(s2))] += s2[:min(len(st), len(s2))]
    write_sfx(A("audio", "b_star.wav"), st)
    write_sfx(A("audio", "b_hint.wav"), arpeggio((1318.5, 1760), .08, .4, .2, .2))
    x = arpeggio((523, 784, 1047, 1568, 2093), .07, 1.0, .35, .24); g = shimmer(rng, 1.2, .1)
    x = np.pad(x, (0, max(0, len(g) - len(x)))); x[:len(g)] += g
    write_sfx(A("audio", "b_level.wav"), x)
    n = int(SR * 1.8); t = np.arange(n) / SR
    sweep = np.sin(2 * np.pi * np.cumsum(300 + 1800 * (t / 1.8) ** 1.5) / SR) * np.exp(-t / .9) * .15
    x = sweep.copy()
    a = arpeggio((1047, 1319, 1568, 2093, 2637, 3136), .09, 1.2, .5, .22); x[:min(n, len(a))] += a[:min(n, len(a))]
    g = shimmer(rng, 1.8, .14); x[:len(g)] += g
    write_sfx(A("audio", "b_clear.wav"), np.tanh(x * 1.3) * .8)
    make_bright_music()


def _kick():
    n = int(SR * .22); t = np.arange(n) / SR
    return np.sin(2 * np.pi * (55 + 90 * np.exp(-t / .03)) * t) * np.exp(-t / .09)


def _snare(rng):
    n = int(SR * .16); t = np.arange(n) / SR
    return (rng.normal(0, 1, n) * .6 + np.sin(2 * np.pi * 190 * t) * .5) * np.exp(-t / .05)


def _hat(rng):
    n = int(SR * .05); t = np.arange(n) / SR
    x = rng.normal(0, 1, n); x = x - np.convolve(x, np.ones(4) / 4, "same")
    return x * np.exp(-t / .012) * .5


def _lead(freq, dur, vol=.12):
    """Soft square-ish lead: odd harmonics, quick attack, gentle vibrato."""
    n = int(SR * dur); t = np.arange(n) / SR
    vib = 1 + .004 * np.sin(2 * np.pi * 5.5 * t)
    ph = 2 * np.pi * freq * vib * t
    x = np.sin(ph) + np.sin(3 * ph) / 3 + np.sin(5 * ph) / 6
    env_ = np.minimum(t / .01, 1) * np.exp(-t / (dur * .9))
    return x * env_ * vol


def make_bright_music():
    """Bright mode loop: a light funky groove in A minor at 112 bpm, 8 bars. Kick, snare with
    ghost notes, swung hats, a syncopated bass and a pentatonic lead melody (original)."""
    rng = np.random.default_rng(33)
    bpm = 112; beat = 60 / bpm; bars = 8; step = beat / 4
    n = int(SR * beat * 4 * bars); x = np.zeros(n)
    def put(sig, at, vol=1.0):
        s0 = int(at * SR)
        if s0 >= n: return
        x[s0:s0 + len(sig)] += sig[:n - s0] * vol
    nA, nC, nD, nE, nG = 220.0, 261.63, 293.66, 329.63, 392.0
    chords = [(nA, nC, nE), (nD, 349.23, nA * 2), (nC, nE, nG), (nG, 246.94, nD)]  # Am Dm C G
    bass_roots = [55.0, 73.42, 65.41, 49.0]
    # sixteenth-note bass rhythm (1 = play), same each bar, syncopated
    bass_hits = [1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 0]
    # lead: (bar, step, semitone offset from A4, length in steps)
    def note(semi): return 440.0 * 2 ** (semi / 12)
    lead = [(0, 0, 0, 3), (0, 4, 3, 2), (0, 6, 5, 2), (0, 8, 7, 4), (0, 14, 5, 2),
            (1, 0, 3, 3), (1, 4, 0, 2), (1, 8, -2, 4), (1, 12, 0, 4),
            (2, 0, 7, 2), (2, 2, 10, 2), (2, 4, 12, 4), (2, 10, 10, 2), (2, 12, 7, 4),
            (3, 0, 5, 3), (3, 4, 3, 3), (3, 8, 2, 6),
            (4, 0, 0, 3), (4, 4, 3, 2), (4, 6, 5, 2), (4, 8, 7, 4), (4, 14, 10, 2),
            (5, 0, 12, 3), (5, 4, 10, 2), (5, 8, 7, 4), (5, 12, 5, 4),
            (6, 0, 3, 2), (6, 2, 5, 2), (6, 4, 7, 4), (6, 10, 5, 2), (6, 12, 3, 4),
            (7, 0, 0, 6), (7, 8, -5, 2), (7, 12, -2, 4)]
    for bar in range(bars):
        ci = bar % 4; t0 = bar * 4 * beat
        for b in range(4):
            put(_kick(), t0 + b * beat, .85 if b in (0, 2) else .55)
            if b in (1, 3):
                put(_snare(rng), t0 + b * beat, .45)
        for st in range(16):
            swing = step * .12 if st % 2 else 0.0
            put(_hat(rng), t0 + st * step + swing, .35 if st % 4 == 2 else .18)
            if st in (7, 15):
                put(_snare(rng), t0 + st * step, .12)  # ghost notes
            if bass_hits[st]:
                f = bass_roots[ci] * (2 if st in (6, 13) else 1)
                put(pluck(f * 2, step * 1.8, .34, .6), t0 + st * step)
        for f in chords[ci]:  # short chord stabs on the offbeats
            for st in (2, 10):
                put(pluck(f, step * 1.5, .06, .8), t0 + st * step)
    for bar, st, semi, length in lead:
        put(_lead(note(semi), step * length), bar * 4 * beat + st * step)
    x = np.tanh(x * 1.15) * .75
    write_wav(A("audio", "music_bright.wav"), x)


VOICE_LINES = {"great": "Great!", "super": "Super!", "amazing": "Amazing!", "incredible": "Incredible!",
               "perfect": "Perfect!", "clear": "Board clear!", "levelup": "Level up!"}


PIPER_SPEAKER = 512  # LibriTTS-R speaker: a lively mid-low male voice


def make_voices():
    """Announcer call-outs. With Piper (set PIPER_DIR to the folder holding the piper binary and
    voice.onnx, the en_US-libritts_r-medium voice, CC BY 4.0) they sound like a real person;
    otherwise espeak-ng is used. Light processing only: level, a little glue, a short room."""
    import shutil, tempfile
    piper_dir = os.environ.get("PIPER_DIR", "")
    piper = os.path.join(piper_dir, "piper", "piper") if piper_dir else ""
    use_piper = piper and os.path.exists(piper)
    if not use_piper and not shutil.which("espeak-ng"):
        print("no speech synthesiser found, keeping existing voice files")
        return
    for name, text in VOICE_LINES.items():
        with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
            if use_piper:
                subprocess.run([piper, "--model", os.path.join(piper_dir, "voice.onnx"), "--speaker", str(PIPER_SPEAKER),
                                "--length_scale", "0.85", "--noise_scale", "0.9", "--noise_w", "0.9", "--output_file", tmp.name],
                               input=text.encode(), check=True, capture_output=True)
            else:
                subprocess.run(["espeak-ng", "-v", "en-us+m3", "-s", "135", "-p", "62", "-w", tmp.name, text], check=True)
            with wave.open(tmp.name) as w:
                sr = w.getframerate()
                x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(float) / 32768
        x = np.interp(np.linspace(0, len(x) - 1, int(len(x) * SR / sr)), np.arange(len(x)), x)
        nz = np.nonzero(np.abs(x) > 0.01)[0]
        if len(nz):
            x = x[max(0, nz[0] - int(.01 * SR)): nz[-1] + int(.05 * SR)]  # trim silence
        x = np.tanh(x / (np.max(np.abs(x)) + 1e-9) * 1.6)
        y = liven(x, room=.12, width=.15, drive=1.1)
        write_wav(A("audio", f"voice_{name}.wav"), y / (np.max(np.abs(y)) + 1e-9) * .92)


def make_music():
    """A calm 32-second loop: soft pads over a slow plucked arpeggio, A minor."""
    bpm, beats = 75, 40
    beat = 60 / bpm
    n = int(SR * beat * beats); t = np.arange(n) / SR
    x = np.zeros(n)
    chords = [(220, 261.63, 329.63), (174.61, 220, 261.63), (130.81, 196, 261.63), (196, 246.94, 293.66)] * 3
    bar = beat * 4
    for ci in range(int(beats / 4)):
        ch = chords[ci % len(chords)]
        s, e = int(ci * bar * SR), int(min((ci + 1) * bar, beat * beats) * SR)
        seg = np.arange(e - s) / SR
        fade = np.minimum(1, np.minimum(seg / .8, (seg[-1] - seg + 1e-6) / .8))
        for f in ch:
            x[s:e] += (np.sin(2 * np.pi * f * seg) + .3 * np.sin(2 * np.pi * f * 2.003 * seg)) * fade * .045
        for k in range(8):
            f = ch[k % 3] * (2 if k >= 3 else 1) * (2 if k == 7 else 1)
            o = s + int(k * beat / 2 * SR)
            b = bell(f * 2, beat * 1.6, .35, .07)
            x[o:o + len(b)] += b[:max(0, n - o)]
    x = np.tanh(x * 1.4) * .7
    # seamless loop: crossfade tail into head
    cf = int(SR * .5)
    x[:cf] = x[:cf] * np.linspace(0, 1, cf) + x[-cf:] * np.linspace(1, 0, cf)
    write_wav(A("audio", "music.wav"), x[:-cf])


def font(path, size):
    return ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", path), size)


def prism_diamond_svg(size):
    """A brilliant-cut diamond seen from the side, each facet a different hue (the 'bizarre' gem)."""
    c, R = size / 2, size * 0.46
    cy = c - R * 0.22
    P = lambda x, y: (c + x * R, cy + y * R)
    T = [P(-.62, -.42), P(-.24, -.42), P(.24, -.42), P(.62, -.42)]
    G = [P(-.97, -.1), P(-.5, -.1), P(0, -.1), P(.5, -.1), P(.97, -.1)]
    B = P(0, .95)
    M = [P(-.42, .42), P(.42, .42)]
    facets = [  # (points, hue)
        ([T[0], G[0], G[1]], "#7ee8fa"), ([T[0], T[1], G[1]], "#c9b6ff"), ([T[1], G[1], G[2]], "#ff9ed2"),
        ([T[1], T[2], G[2]], "#fff4c9"), ([T[2], G[2], G[3]], "#9ef0c0"), ([T[2], T[3], G[3]], "#ffd27a"),
        ([T[3], G[3], G[4]], "#8fb8ff"),
        ([G[0], G[1], M[0]], "#3aa0e8"), ([G[1], G[2], M[0]], "#9b5cf0"), ([M[0], G[2], B], "#e8508f"),
        ([G[2], G[3], M[1]], "#f0a53a"), ([G[3], G[4], M[1]], "#2fc28a"), ([M[1], G[2], B], "#4f7df5"),
        ([G[0], M[0], B], "#2370c8"), ([G[4], M[1], B], "#1d9a6c"),
    ]
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}"><defs>']
    for i, (_, hue) in enumerate(facets):
        out.append(f'<linearGradient id="f{i}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{shade(hue, .35)}"/>'
                   f'<stop offset="1" stop-color="{shade(hue, -.25)}"/></linearGradient>')
    out.append('<radialGradient id="glint"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>')
    out.append("</defs>")
    hull = [T[0], T[3], G[4], B, G[0]]
    out.append(f'<polygon points="{pts(hull)}" fill="#14243a" stroke="#0b1424" stroke-width="{size*.03:.1f}" stroke-linejoin="round"/>')
    for i, (poly, _) in enumerate(facets):
        out.append(f'<polygon points="{pts(poly)}" fill="url(#f{i})" stroke="#ffffff" stroke-opacity="0.55" stroke-width="{size*.006:.1f}" stroke-linejoin="round"/>')
    out.append(f'<polygon points="{pts(hull)}" fill="none" stroke="#0b1424" stroke-width="{size*.012:.1f}" stroke-linejoin="round"/>')
    # highlights on the crown
    out.append(f'<polygon points="{pts([T[1], T[2], P(.05, -.28), P(-.3, -.28)])}" fill="#fff" fill-opacity="0.45"/>')
    gx, gy = P(-.42, -.3)
    out.append(f'<circle cx="{gx:.1f}" cy="{gy:.1f}" r="{R*.16:.1f}" fill="url(#glint)" fill-opacity="0.9"/>')
    out.append("</svg>")
    return "\n".join(out)


def make_icon(ground):
    """Store icon 512x512 (opaque, the platform rounds corners) and the 256 px project icon."""
    S = 1024  # draw at 2x, downscale for clean edges
    ic = ground(S, S)
    # warm glow behind the strike point
    y, x = np.mgrid[0:S, 0:S]
    d = np.sqrt((x - S / 2) ** 2 + (y - S * .47) ** 2) / (S * .5)
    glow = np.zeros((S, S, 4), np.uint8)
    glow[..., 0], glow[..., 1], glow[..., 2] = 247, 214, 140
    glow[..., 3] = (np.clip(1 - d, 0, 1) ** 2.2 * 150).astype(np.uint8)
    ic.alpha_composite(Image.fromarray(glow))
    dr = ImageDraw.Draw(ic)
    cx, cy = S // 2, int(S * .47)
    # the cross strike: tapered golden beams
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        for w, a in ((34, 60), (18, 140), (8, 255)):
            dr.line([(cx, cy), (cx + dx * S * .44, cy + dy * S * .44)], fill=(247, 226, 168, a), width=w)
    # gem pairs at the ends of the cross
    gsz = 230
    for i, (x0, y0) in zip((0, 0, 2, 2), ((cx, 112), (cx, S - 128), (112, cy), (S - 112, cy))):
        g = Image.open(A("gems", f"gem_{i}.png")).convert("RGBA").resize((gsz, gsz), Image.LANCZOS)
        ic.alpha_composite(g, (int(x0 - gsz / 2), int(y0 - gsz / 2)))
    # the big prismatic diamond in the middle
    tmp = os.path.join(ROOT, "store", ".diamond.png")
    svg_to_png(prism_diamond_svg(560), tmp, 560)
    dia = Image.open(tmp).convert("RGBA"); os.remove(tmp)
    sh = Image.new("RGBA", dia.size, (0, 0, 0, 0)); sh.putalpha(dia.getchannel("A").point(lambda a: a * .55))
    sh = sh.filter(ImageFilter.GaussianBlur(18))
    ic.alpha_composite(sh, (cx - 280 + 10, cy - 280 + 26))
    ic.alpha_composite(dia, (cx - 280, cy - 280))
    # sparkles
    sp = Image.open(A("fx", "sparkle.png")).convert("RGBA")
    for (sx, sy, ss) in ((cx + 210, cy - 205, 120), (cx - 250, cy + 150, 80), (cx + 150, cy + 210, 64), (cx - 190, cy - 230, 56)):
        ic.alpha_composite(sp.resize((ss, ss), Image.LANCZOS), (sx - ss // 2, sy - ss // 2))
    out = ic.convert("RGB").resize((512, 512), Image.LANCZOS)
    out.save(STORE("icon_512.png"))
    out.resize((256, 256), Image.LANCZOS).save(os.path.join(ROOT, "icon.png"))


def make_branding():
    """App icon, Yandex store icon (512) and cover (800x470)."""
    os.makedirs(STORE(), exist_ok=True)
    gem = lambda i, s: Image.open(A("gems", f"gem_{i}.png")).convert("RGBA").resize((s, s), Image.LANCZOS)
    velvet = Image.open(A("ui", "velvet.png")).convert("RGBA")
    vign = Image.open(A("ui", "vignette.png"))

    def ground(w, h):
        g = Image.new("RGBA", (w, h))
        for yy in range(0, h, 256):
            for xx in range(0, w, 256):
                g.paste(velvet, (xx, yy))
        g.alpha_composite(vign.resize((w, h)))
        return g

    def beams(d, cx, cy, L, w):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            d.line([(cx, cy), (cx + dx * L, cy + dy * L)], fill=(247, 226, 168, 230), width=w)

    make_icon(ground)

    # cover 800x470
    w, h = 800, 470
    cv = ground(w, h)
    d = ImageDraw.Draw(cv)
    rnd = random.Random(5)
    for gx in range(9):
        for gy in range(5):
            if rnd.random() < .55:
                g = gem(rnd.randrange(10), 64)
                g.putalpha(g.getchannel("A").point(lambda a: a * .45))
                cv.alpha_composite(g, (12 + gx * 88, 18 + gy * 92))
    cv.alpha_composite(Image.new("RGBA", (w, 210), (10, 19, 21, 200)), (0, 130))
    base = cv
    # one cover per catalogue language: the title differs between them
    for lang, title, sub in (
        ("ru", "Алмазная братва", "Выбивай пары камней крестом на время"),
        ("en", "Bizarre Gems", "Knock out gem pairs with a cross strike"),
        ("tr", "Bizarre Gems", "Taş çiftlerini çapraz vuruşla kır"),
    ):
        cv = base.copy()
        d = ImageDraw.Draw(cv)
        size = 74
        while True:
            tf = font("RussoOne-Regular.ttf", size)
            tw = d.textlength(title, font=tf)
            if tw <= w - 70: break
            size -= 2
        d.text(((w - tw) / 2 + 3, 158 + 4), title, font=tf, fill=(0, 0, 0, 160))
        d.text(((w - tw) / 2, 158), title, font=tf, fill=(232, 196, 108, 255))
        sf = font("Manrope-Variable.ttf", 28)
        sf.set_variation_by_axes([650])
        d.text(((w - d.textlength(sub, font=sf)) / 2, 262), sub, font=sf, fill=(241, 232, 212, 255))
        cv.convert("RGB").save(STORE(f"cover_800x470_{lang}.png"))


def main():
    for d in ("gems", "tiles", "ui", "fx", "audio"):
        os.makedirs(A(d), exist_ok=True)
    for i, (name, base, cut) in enumerate(GEMS):
        svg_to_png(gem_svg(name, base, cut, 128), A("gems", f"gem_{i}.png"), 128)
    make_icons()
    make_textures()
    make_tiles()
    make_specials()
    make_previews()
    make_sounds()
    make_branding()
    print("assets written")


if __name__ == "__main__":
    main()
