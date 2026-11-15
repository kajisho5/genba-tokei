#!/usr/bin/env python3
"""App Store のプロダクトページ用の横長画像（ヘッダ・検索結果）を作る（Pillow）。

  python3 scripts/store-banners.py <出力フォルダ>

出力：header-3840x1646.png / .mp4（ヘッダ）、search-1920x1280.png / .mp4（検索結果）
動画は 12 秒・30fps。時計が 1/100 秒まで動き、下の一文が 3 秒ごとに切り替わる（先頭と最後がつながって繰り返せる）
大事な文字は中央 60% の範囲に収める（端は端末によって切れることがあるため）。
App Store Connect の API に該当する登録先が無いため、Web の「アップロード」から手で入れる。
"""
import os
import subprocess
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


FEATURES = ["時計だけの大きな画面", "Dynamic Island に 1/100秒", "小窓で他のアプリの上に", "Apple Watch でも同じ時刻"]


def background(W, H):
    img = Image.new("RGB", (W, H), BG)
    # 中央にぼんやりした琥珀色の光
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse([W * 0.25, H * 0.05, W * 0.75, H * 0.95], fill=60)
    glow = glow.filter(ImageFilter.GaussianBlur(H * 0.25))
    img.paste(Image.new("RGB", (W, H), (70, 50, 12)), (0, 0), glow)
    return img


def banner(W, H, out, img=None, main="12:34:56", frac=".78", feature=None, feature_alpha=1.0):
    img = img.copy() if img is not None else background(W, H)
    d = ImageDraw.Draw(img)

    s = H / 1280  # 基準：高さ 1280
    # 時刻（数字＋琥珀色の 1/100 秒）。幅が揺れないよう、桁の位置は「88:88:88.88」で決める
    fm, ff = f(BOLD, int(300 * s)), f(BOLD, int(190 * s))
    wm, wf = d.textlength("88:88:88", font=fm), d.textlength(".88", font=ff)
    x0 = (W - wm - wf) / 2
    base = H * 0.52
    # 1 文字ずつ等間隔に置く（数字の幅の違いで揺れないように）
    digit_w = d.textlength("8", font=fm)
    colon_w = d.textlength(":", font=fm)
    x = x0
    for ch in main:
        w = colon_w if ch == ":" else digit_w
        d.text((x + w / 2, base), ch, font=fm, fill=WHITE, anchor="ms")
        x += w
    fd = d.textlength("8", font=ff)
    dot_w = d.textlength(".", font=ff)
    for ch in frac:
        w = dot_w if ch == "." else fd
        d.text((x + w / 2, base), ch, font=ff, fill=AMBER, anchor="ms")
        x += w

    # 補正状態のバッジ（時刻の上）
    badge = "NTP補正 ±12ms"
    fb = f(REG, int(44 * s))
    bw = d.textlength(badge, font=fb) + 70 * s
    bx, by = (W - bw) / 2, base - 300 * s - 120 * s
    d.rounded_rectangle([bx, by, bx + bw, by + 74 * s], radius=37 * s, fill=(15, 36, 23), outline=(30, 90, 51), width=max(2, int(3 * s)))
    d.ellipse([bx + 26 * s, by + 27 * s, bx + 46 * s, by + 47 * s], fill=GREEN)
    d.text((bx + 60 * s, by + 37 * s), badge, font=fb, fill=(127, 212, 154), anchor="lm")

    # 見出し（動画では特長の一文が入れ替わる）とアプリ名（時刻の下）
    if feature is None:
        d.text((W / 2, base + 110 * s), "1/100秒まで、全員が同じ時刻。", font=f(BOLD, int(92 * s)), fill=WHITE, anchor="mt")
    else:
        a = max(0.0, min(1.0, feature_alpha))
        col = tuple(int(BG[i] + (WHITE[i] - BG[i]) * a) for i in range(3))
        d.text((W / 2, base + 110 * s), feature, font=f(BOLD, int(92 * s)), fill=col, anchor="mt")
    name_font = f(BOLD, int(58 * s))
    name = "現場時計"
    nw = d.textlength(name, font=name_font)
    nx = (W - nw - 40 * s) / 2
    ny = base + 270 * s
    d.ellipse([nx, ny + 16 * s, nx + 26 * s, ny + 42 * s], fill=AMBER)
    d.text((nx + 40 * s, ny), name, font=name_font, fill=SUB, anchor="lt")
    if out:
        img.save(out, optimize=True)
        print(out, img.size)
    return img


def video(W, H, out, seconds=12, fps=30):
    """時計が動く動画。生の画素を ffmpeg に流して H.264（mp4）にする"""
    bg = background(W, H)
    proc = subprocess.Popen([
        "ffmpeg", "-loglevel", "error", "-y",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(fps), "-i", "-",
        "-f", "lavfi", "-t", str(seconds), "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
        "-map", "0:v", "-map", "1:a", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16", "-preset", "slow",
        "-c:a", "aac", "-b:a", "128k", "-shortest", "-movflags", "+faststart", out,
    ], stdin=subprocess.PIPE)
    start = 12 * 3600 + 34 * 60 + 50.0
    seg = seconds / len(FEATURES)
    for i in range(seconds * fps):
        t = i / fps
        now = start + t
        cs = int(now * 100) % 100
        hh, mm, ss = int(now // 3600), int(now // 60) % 60, int(now) % 60
        k = int(t // seg)
        within = t - k * seg
        alpha = min(1.0, within / 0.35, (seg - within) / 0.35)
        frame = banner(W, H, None, img=bg, main=f"{hh:02d}:{mm:02d}:{ss:02d}", frac=f".{cs:02d}",
                       feature=FEATURES[k], feature_alpha=alpha)
        proc.stdin.write(frame.tobytes())
    proc.stdin.close()
    if proc.wait() != 0:
        sys.exit("ffmpeg に失敗")
    print(out, (W, H), f"{seconds}s {fps}fps")


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    banner(3840, 1646, os.path.join(out, "header-3840x1646.png"))
    banner(1920, 1280, os.path.join(out, "search-1920x1280.png"))
    if "--no-video" not in sys.argv:
        video(3840, 1646, os.path.join(out, "header-3840x1646.mp4"))
        video(1920, 1280, os.path.join(out, "search-1920x1280.mp4"))


if __name__ == "__main__":
    main()
