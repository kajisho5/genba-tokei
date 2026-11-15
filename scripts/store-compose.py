#!/usr/bin/env python3
"""App Store 用の素材を仕上げる（Pillow と ffmpeg を使う）。

  python3 scripts/store-compose.py <capture フォルダ> <出力フォルダ>

入力（appstore-capture ワークフローの artifact）:
  APP_IPHONE_67/1..4.png, APP_IPAD_PRO_3GEN_129/1..4.png, APP_WATCH_ULTRA/1.png, video-iphone.mov, video-ipad.mov
出力:
  screenshots/<表示種別>/N.png  … 見出し入りの説明画像（Watch はそのまま）
  previews/<表示種別>/1.mp4     … App プレビュー（iPhone 886x1920 / iPad 1200x1600、30fps、29 秒、字幕入り、無音の音声トラック付き）
"""
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT_BOLD = os.environ.get("STORE_FONT_BOLD", "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc")
FONT_REG = os.environ.get("STORE_FONT_REG", "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc")
WHITE = (245, 247, 250)
AMBER = (255, 176, 32)
SUB = (138, 145, 156)

# 画面写真の順（capture の 1..4）と見出し
CAPTIONS = [
    ("1/100秒まで、全員が同じ時刻。", "時計だけの大きな画面"),
    ("ネットの時刻で自動補正", "ずれと誤差を ±ミリ秒で表示"),
    ("本番までカウントダウン", "残り5分で黄、1分で赤、0秒でお知らせ"),
    ("ラップ付きストップウォッチ", "Dynamic Island・小窓・Apple Watch にも"),
]
# 動画の字幕（開始秒, 終了秒, 文字）— アプリの自動ツアー（-tour）の切り替えに合わせる
VIDEO_CAPTIONS = [
    (0, 6.5, "時計だけの大きな画面"),
    (6.5, 12.5, "ネットの時刻で自動補正"),
    (12.5, 18.5, "本番までカウントダウン"),
    (18.5, 24.5, "ラップ付きストップウォッチ"),
    (24.5, 29, "1/100秒まで、全員が同じ時刻。"),
]


def font(path, size):
    # .ttc の 0 番目は日本語（JP）
    return ImageFont.truetype(path, size, index=0)


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius, fill=255)
    out = Image.new("RGBA", img.size)
    out.paste(img, (0, 0), mask)
    return out


def compose(shot_path, out_path, title, sub, *, shot_width_ratio, title_size, sub_size, top):
    shot = Image.open(shot_path).convert("RGB")
    W, H = shot.size
    canvas = Image.new("RGB", (W, H), (11, 13, 16))
    # 上に向かって少し明るいグラデーション
    grad = Image.new("L", (1, H))
    for y in range(H):
        grad.putpixel((0, y), max(0, 40 - int(40 * y / (H * 0.6))))
    canvas.paste(Image.new("RGB", (W, H), (40, 34, 20)), (0, 0), grad.resize((W, H)))
    d = ImageDraw.Draw(canvas)
    # 幅の 90% に収まるまで見出しを縮める
    ts = title_size
    ft = font(FONT_BOLD, ts)
    while d.textlength(title, font=ft) > W * 0.9 and ts > 40:
        ts -= 2
        ft = font(FONT_BOLD, ts)
    fs = font(FONT_REG, sub_size)
    d.text((W / 2, top + (title_size - ts) / 2), title, font=ft, fill=WHITE, anchor="mt")
    d.text((W / 2, top + title_size * 1.45), sub, font=fs, fill=AMBER, anchor="mt")

    sw = int(W * shot_width_ratio)
    sh = int(shot.height * sw / shot.width)
    small = shot.resize((sw, sh), Image.LANCZOS)
    radius = int(sw * 0.07)
    y = int(top + title_size * 1.45 + sub_size * 2.2)
    x = (W - sw) // 2
    # 影
    shadow = Image.new("L", (sw + 120, sh + 120), 0)
    ImageDraw.Draw(shadow).rounded_rectangle([60, 70, sw + 60, sh + 70], radius, fill=150)
    canvas.paste((0, 0, 0), (x - 60, y - 60), shadow.filter(ImageFilter.GaussianBlur(40)))
    # 枠
    frame = Image.new("RGB", (sw + 24, sh + 24), (31, 35, 41))
    canvas.paste(rounded(frame, radius + 12), (x - 12, y - 12), rounded(frame, radius + 12))
    r = rounded(small, radius)
    canvas.paste(r, (x, y), r)
    canvas.save(out_path, optimize=True)


def screenshots(src, dst):
    for display, kw in [
        ("APP_IPHONE_67", dict(shot_width_ratio=0.80, title_size=92, sub_size=50, top=150)),
        ("APP_IPAD_PRO_3GEN_129", dict(shot_width_ratio=0.80, title_size=104, sub_size=56, top=150)),
    ]:
        os.makedirs(os.path.join(dst, "screenshots", display), exist_ok=True)
        for i, (title, sub) in enumerate(CAPTIONS, start=1):
            compose(os.path.join(src, display, f"{i}.png"), os.path.join(dst, "screenshots", display, f"{i}.png"), title, sub, **kw)
            print(f"screenshots/{display}/{i}.png")
    # Watch は画面そのまま（小さいので文字を入れない）
    wdir = os.path.join(dst, "screenshots", "APP_WATCH_ULTRA")
    os.makedirs(wdir, exist_ok=True)
    shutil.copy(os.path.join(src, "APP_WATCH_ULTRA", "1.png"), os.path.join(wdir, "1.png"))


def preview(src_video, out_path, w, h, caption_size):
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    draws = []
    for start, end, text in VIDEO_CAPTIONS:
        draws.append(
            f"drawtext=fontfile={FONT_BOLD}:text='{text}':fontsize={caption_size}:fontcolor=0xF5F7FA:"
            f"box=1:boxcolor=0x0B0D10@0.85:boxborderw={caption_size // 2}:x=(w-text_w)/2:y=h*0.80:"
            f"enable='between(t,{start},{end})'"
        )
    vf = (f"fps=30,scale={w}:{h}:force_original_aspect_ratio=decrease,"
          f"pad={w}:{h}:(ow-iw)/2:(oh-ih)/2:color=0x0B0D10,setsar=1," + ",".join(draws))
    subprocess.run([
        "ffmpeg", "-loglevel", "error", "-y",
        "-ss", "1.5", "-t", "29", "-i", src_video,
        "-f", "lavfi", "-t", "29", "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
        "-vf", vf, "-map", "0:v", "-map", "1:a",
        "-c:v", "libx264", "-profile:v", "high", "-level", "4.0", "-pix_fmt", "yuv420p",
        "-b:v", "10M", "-maxrate", "12M", "-bufsize", "20M",
        "-c:a", "aac", "-b:a", "256k", "-shortest", "-movflags", "+faststart", out_path,
    ], check=True)
    print(out_path)


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]
    screenshots(src, dst)
    preview(os.path.join(src, "video-iphone.mov"), os.path.join(dst, "previews", "APP_IPHONE_67", "1.mp4"), 886, 1920, 44)
    preview(os.path.join(src, "video-ipad.mov"), os.path.join(dst, "previews", "APP_IPAD_PRO_3GEN_129", "1.mp4"), 1200, 1600, 46)


if __name__ == "__main__":
    main()
