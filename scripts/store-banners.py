#!/usr/bin/env python3
"""App Store のプロダクトページ用の横長画像（ヘッダ・検索結果）を作る（Pillow）。

  python3 scripts/store-banners.py <出力フォルダ>

出力：header-3840x1646.png（ヘッダ）、search-1920x1280.png（検索結果）
大事な文字は中央 60% の範囲に収める（端は端末によって切れることがあるため）。
App Store Connect の API に該当する登録先が無いため、Web の「アップロード」から手で入れる。
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

BOLD = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"
REG = "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"
BG = (11, 13, 16)
WHITE = (245, 247, 250)
AMBER = (255, 176, 32)
SUB = (138, 145, 156)
GREEN = (48, 209, 88)


def f(path, size):
    return ImageFont.truetype(path, size, index=0)


def banner(W, H, out):
    img = Image.new("RGB", (W, H), BG)
    # 中央にぼんやりした琥珀色の光
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse([W * 0.25, H * 0.05, W * 0.75, H * 0.95], fill=60)
    glow = glow.filter(ImageFilter.GaussianBlur(H * 0.25))
    img.paste(Image.new("RGB", (W, H), (70, 50, 12)), (0, 0), glow)
    d = ImageDraw.Draw(img)

    s = H / 1280  # 基準：高さ 1280
    # 時刻（数字＋琥珀色の 1/100 秒）
    main, frac = "12:34:56", ".78"
    fm, ff = f(BOLD, int(300 * s)), f(BOLD, int(190 * s))
    wm, wf = d.textlength(main, font=fm), d.textlength(frac, font=ff)
    x0 = (W - wm - wf) / 2
    base = H * 0.52
    d.text((x0, base), main, font=fm, fill=WHITE, anchor="ls")
    d.text((x0 + wm, base), frac, font=ff, fill=AMBER, anchor="ls")

    # 補正状態のバッジ（時刻の上）
    badge = "NTP補正 ±12ms"
    fb = f(REG, int(44 * s))
    bw = d.textlength(badge, font=fb) + 70 * s
    bx, by = (W - bw) / 2, base - 300 * s - 120 * s
    d.rounded_rectangle([bx, by, bx + bw, by + 74 * s], radius=37 * s, fill=(15, 36, 23), outline=(30, 90, 51), width=max(2, int(3 * s)))
    d.ellipse([bx + 26 * s, by + 27 * s, bx + 46 * s, by + 47 * s], fill=GREEN)
    d.text((bx + 60 * s, by + 37 * s), badge, font=fb, fill=(127, 212, 154), anchor="lm")

    # 見出しとアプリ名（時刻の下）
    d.text((W / 2, base + 110 * s), "1/100秒まで、全員が同じ時刻。", font=f(BOLD, int(92 * s)), fill=WHITE, anchor="mt")
    name_font = f(BOLD, int(58 * s))
    name = "現場時計"
    nw = d.textlength(name, font=name_font)
    nx = (W - nw - 40 * s) / 2
    ny = base + 270 * s
    d.ellipse([nx, ny + 16 * s, nx + 26 * s, ny + 42 * s], fill=AMBER)
    d.text((nx + 40 * s, ny), name, font=name_font, fill=SUB, anchor="lt")
    img.save(out, optimize=True)
    print(out, img.size)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    banner(3840, 1646, os.path.join(out, "header-3840x1646.png"))
    banner(1920, 1280, os.path.join(out, "search-1920x1280.png"))


if __name__ == "__main__":
    main()
