"""Generate Google Play Store listing assets from assetis/LOGO.png."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
LOGO_PATH = ROOT / "assetis" / "LOGO.png"
OUT_DIR = ROOT / "assetis" / "play_store"
SCREEN_DIR = OUT_DIR / "screenshots"

BG = (8, 8, 8)
YELLOW = (255, 204, 0)
WHITE = (255, 255, 255)
MUTED = (160, 160, 160)
CARD = (18, 18, 18)
CARD_BORDER = (40, 40, 40)


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path(r"C:\Windows\Fonts\arialbd.ttf") if bold else Path(r"C:\Windows\Fonts\arial.ttf"),
        Path(r"C:\Windows\Fonts\segoeuib.ttf") if bold else Path(r"C:\Windows\Fonts\segoeui.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def draw_stripes(draw: ImageDraw.ImageDraw, size: tuple[int, int], alpha: int = 18) -> None:
    w, h = size
    spacing = 28
    stripe = (*YELLOW, alpha)
    for x in range(-h, w + h, spacing):
        draw.line([(x, 0), (x + h, h)], fill=stripe, width=2)


def resize_logo_cover(logo: Image.Image, size: int) -> Image.Image:
    """Scale logo to fill a square (cover), centered crop."""
    fitted = logo.copy()
    fitted.thumbnail((size, size), Image.Resampling.LANCZOS)
    if fitted.width < size or fitted.height < size:
        scale = max(size / fitted.width, size / fitted.height)
        fitted = logo.resize(
            (max(1, int(logo.width * scale)), max(1, int(logo.height * scale))),
            Image.Resampling.LANCZOS,
        )
    left = (fitted.width - size) // 2
    top = (fitted.height - size) // 2
    return fitted.crop((left, top, left + size, top + size))


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask


def paste_logo_badge(
    base: Image.Image,
    logo: Image.Image,
    box: tuple[int, int, int, int],
    *,
    radius: int = 28,
    glow: bool = True,
) -> None:
    x0, y0, x1, y1 = box
    size = min(x1 - x0, y1 - y0)
    ox = x0 + (x1 - x0 - size) // 2
    oy = y0 + (y1 - y0 - size) // 2

    icon = resize_logo_cover(logo, size)
    mask = rounded_mask(size, radius)
    icon.putalpha(mask)

    if glow:
        glow_layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
        glow_draw = ImageDraw.Draw(glow_layer)
        pad = max(10, size // 18)
        glow_draw.rounded_rectangle(
            (ox - pad, oy - pad, ox + size + pad, oy + size + pad),
            radius=radius + 8,
            fill=(*YELLOW, 55),
        )
        glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=max(12, size // 16)))
        if base.mode != "RGBA":
            base_rgba = base.convert("RGBA")
            base_rgba.alpha_composite(glow_layer)
            base.paste(base_rgba.convert("RGB"), (0, 0))
        else:
            base.alpha_composite(glow_layer)

    if base.mode != "RGBA":
        base.paste(icon, (ox, oy), icon)
    else:
        base.alpha_composite(icon, (ox, oy))


def paste_logo_rgba(base: Image.Image, logo: Image.Image, box: tuple[int, int, int, int]) -> None:
    paste_logo_badge(base, logo, box, radius=min(16, (box[2] - box[0]) // 8), glow=False)


def text_size(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont) -> tuple[int, int]:
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def draw_centered_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    y: int,
    width: int,
    font: ImageFont.ImageFont,
    fill: tuple[int, int, int],
) -> None:
    tw, _ = text_size(draw, text, font)
    draw.text(((width - tw) // 2, y), text, font=font, fill=fill)


def make_feature_graphic(logo: Image.Image) -> Image.Image:
    w, h = 1024, 500
    img = Image.new("RGB", (w, h), BG)
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw_stripes(draw, (w, h), alpha=28)

    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse((620, -40, 1020, 360), fill=(*YELLOW, 22))
    overlay = Image.alpha_composite(overlay, glow)
    img = Image.alpha_composite(img.convert("RGBA"), overlay)

    # Large rounded app-icon badge on the left.
    paste_logo_badge(img, logo, (48, 78, 400, 430), radius=36, glow=True)
    img = img.convert("RGB")

    draw = ImageDraw.Draw(img)
    title_font = load_font(54, bold=True)
    sub_font = load_font(28)
    tag_font = load_font(20, bold=True)
    small_font = load_font(18)

    draw.text((440, 130), "TRUCKFIX", font=title_font, fill=WHITE)
    draw.text((440, 200), "Emergency breakdown", font=sub_font, fill=WHITE)
    draw.text((440, 238), "assistance on demand", font=sub_font, fill=WHITE)

    draw.rounded_rectangle((440, 300, 670, 340), radius=8, fill=YELLOW)
    draw.text((462, 308), "FLEET  |  MECHANIC", font=tag_font, fill=BG)

    draw.text((440, 365), "Connect instantly with certified mechanics", font=small_font, fill=MUTED)
    draw.text((440, 392), "Track jobs  •  Chat  •  Pay securely", font=small_font, fill=MUTED)

    bar = Image.new("RGB", (w, 6), YELLOW)
    img.paste(bar, (0, h - 6))
    return img


def make_icon_512(logo: Image.Image) -> Image.Image:
    size = 512
    pad = 24
    inner = size - pad * 2
    img = Image.new("RGB", (size, size), BG)
    icon = resize_logo_cover(logo, inner)
    mask = rounded_mask(inner, radius=96)
    icon.putalpha(mask)
    img_rgba = img.convert("RGBA")
    img_rgba.paste(icon, (pad, pad), icon)
    return img_rgba.convert("RGB")


def phone_frame(content: Image.Image) -> Image.Image:
    """Wrap 1080x1920 content in a subtle device-style frame for store shots."""
    return content


def draw_phone_status_bar(draw: ImageDraw.ImageDraw, width: int) -> None:
    draw.rectangle((0, 0, width, 72), fill=BG)
    draw.text((40, 24), "9:41", font=load_font(22, bold=True), fill=WHITE)


def make_splash_screenshot(logo: Image.Image) -> Image.Image:
    w, h = 1080, 1920
    img = Image.new("RGB", (w, h), BG)
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw_stripes(draw, (w, h), alpha=24)
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((240, -80, 840, 520), fill=(*YELLOW, 18))
    overlay = Image.alpha_composite(overlay, glow)
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")

    paste_logo_badge(img, logo, (290, 520, 790, 920), radius=56, glow=True)

    draw = ImageDraw.Draw(img)
    draw_centered_text(
        draw,
        "Emergency breakdown assistance.",
        980,
        w,
        load_font(34),
        WHITE,
    )
    draw_centered_text(
        draw,
        "Connect instantly with certified mechanics.",
        1030,
        w,
        load_font(34),
        WHITE,
    )

    btn_w, btn_h = 920, 96
    bx = (w - btn_w) // 2
    by = 1480
    draw.rounded_rectangle((bx, by, bx + btn_w, by + btn_h), radius=18, fill=YELLOW)
    draw_centered_text(draw, "GET STARTED", by + 28, w, load_font(30, bold=True), BG)

    draw_centered_text(draw, "Already registered? Login", 1620, w, load_font(28), WHITE)
    return img


def make_jobs_screenshot(logo: Image.Image) -> Image.Image:
    w, h = 1080, 1920
    img = Image.new("RGB", (w, h), BG)
    draw = ImageDraw.Draw(img)
    draw_phone_status_bar(draw, w)

    draw.text((40, 110), "Open Jobs", font=load_font(44, bold=True), fill=WHITE)
    draw.text((40, 170), "Nearby breakdown requests", font=load_font(24), fill=MUTED)

    cards = [
        ("Engine won't start", "2.4 mi  •  Urgent", "Kenworth T680", "$120–180"),
        ("Brake system fault", "5.1 mi  •  Today", "Freightliner", "$200–350"),
        ("Coolant leak", "8.3 mi  •  Tomorrow", "Volvo VNL", "$90–150"),
    ]
    y = 250
    for title, meta, truck, pay in cards:
        draw.rounded_rectangle((40, y, w - 40, y + 200), radius=20, fill=CARD, outline=CARD_BORDER, width=2)
        draw.rounded_rectangle((64, y + 24, 140, y + 100), radius=14, fill=YELLOW)
        paste_logo_rgba(img, logo, (64, y + 24, 140, y + 100))
        draw.text((164, y + 30), title, font=load_font(30, bold=True), fill=WHITE)
        draw.text((164, y + 72), meta, font=load_font(22), fill=MUTED)
        draw.text((164, y + 108), truck, font=load_font(22), fill=YELLOW)
        draw.text((164, y + 148), pay, font=load_font(26, bold=True), fill=WHITE)
        y += 230

    draw.rounded_rectangle((40, h - 150, w - 40, h - 60), radius=28, fill=YELLOW)
    draw_centered_text(draw, "View job details & send quote", h - 118, w, load_font(26, bold=True), BG)
    return img


def make_track_screenshot(logo: Image.Image) -> Image.Image:
    w, h = 1080, 1920
    img = Image.new("RGB", (w, h), BG)
    draw = ImageDraw.Draw(img)
    draw_phone_status_bar(draw, w)

    draw.text((40, 110), "Track Job", font=load_font(44, bold=True), fill=WHITE)
    draw.text((40, 170), "Live mechanic progress", font=load_font(24), fill=MUTED)

    map_top = 240
    map_h = 520
    draw.rounded_rectangle((40, map_top, w - 40, map_top + map_h), radius=24, fill=(14, 14, 14), outline=CARD_BORDER, width=2)
    for i in range(6):
        y = map_top + 60 + i * 70
        draw.line([(80, y), (w - 80, y)], fill=(30, 30, 30), width=2)
    for i in range(5):
        x = 120 + i * 170
        draw.line([(x, map_top + 40), (x, map_top + map_h - 40)], fill=(30, 30, 30), width=2)
    draw.ellipse((w // 2 - 18, map_top + map_h // 2 - 18, w // 2 + 18, map_top + map_h // 2 + 18), fill=YELLOW)
    draw.ellipse((w // 2 + 120, map_top + map_h // 2 - 80, w // 2 + 156, map_top + map_h // 2 - 44), fill=WHITE)

    steps = ["Journey", "Arrived", "Work", "Done"]
    sx = 90
    sy = 820
    for i, label in enumerate(steps):
        cx = sx + i * 230
        color = YELLOW if i <= 2 else MUTED
        draw.ellipse((cx, sy, cx + 44, sy + 44), fill=color if i <= 2 else CARD, outline=color, width=3)
        draw.text((cx + 8, sy + 10), str(i + 1), font=load_font(22, bold=True), fill=BG if i <= 2 else MUTED)
        draw.text((cx - 10, sy + 58), label, font=load_font(22, bold=True), fill=WHITE if i <= 2 else MUTED)
        if i < len(steps) - 1:
            draw.line([(cx + 50, sy + 22), (cx + 180, sy + 22)], fill=YELLOW if i < 2 else CARD_BORDER, width=4)

    draw.rounded_rectangle((40, 980, w - 40, 1180), radius=20, fill=CARD, outline=CARD_BORDER, width=2)
    paste_logo_rgba(img, logo, (64, 1004, 160, 1100))
    draw.text((180, 1010), "Mike's Mobile Repair", font=load_font(30, bold=True), fill=WHITE)
    draw.text((180, 1054), "ETA 12 min  •  4.9 ★", font=load_font(24), fill=YELLOW)
    draw.text((180, 1094), "Brake system fault — Freightliner", font=load_font(22), fill=MUTED)

    draw.rounded_rectangle((40, 1220, w - 40, 1320), radius=18, fill=YELLOW)
    draw_centered_text(draw, "Message mechanic", 1258, w, load_font(28, bold=True), BG)

    draw.rounded_rectangle((40, 1360, (w - 50) // 2, 1460), radius=18, fill=CARD, outline=YELLOW, width=2)
    draw_centered_text(draw, "Call", 1398, (w - 50) // 2 + 40, load_font(26, bold=True), YELLOW)
    draw.rounded_rectangle(((w + 50) // 2, 1360, w - 40, 1460), radius=18, fill=CARD, outline=YELLOW, width=2)
    draw_centered_text(draw, "Navigate", 1398, w, load_font(26, bold=True), YELLOW)
    return img


def make_login_screenshot(logo: Image.Image) -> Image.Image:
    w, h = 1080, 1920
    img = Image.new("RGB", (w, h), BG)
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw_stripes(ImageDraw.Draw(overlay), (w, h), alpha=16)
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")

    paste_logo_badge(img, logo, (340, 360, 740, 560), radius=40, glow=True)

    draw = ImageDraw.Draw(img)
    draw_centered_text(draw, "Welcome back", 640, w, load_font(40, bold=True), WHITE)
    draw_centered_text(draw, "Sign in to your TruckFix account", 700, w, load_font(26), MUTED)

    for i, (label, placeholder) in enumerate([("Email", "you@company.com"), ("Password", "••••••••")]):
        y = 820 + i * 170
        draw.text((80, y), label, font=load_font(24, bold=True), fill=WHITE)
        draw.rounded_rectangle((80, y + 40, w - 80, y + 120), radius=16, fill=CARD, outline=CARD_BORDER, width=2)
        draw.text((110, y + 64), placeholder, font=load_font(26), fill=MUTED)

    draw.rounded_rectangle((80, 1180, w - 80, 1270), radius=18, fill=YELLOW)
    draw_centered_text(draw, "SIGN IN", 1210, w, load_font(30, bold=True), BG)

    draw_centered_text(draw, "Forgot password?", 1340, w, load_font(26), YELLOW)
    return img


def main() -> None:
    if not LOGO_PATH.exists():
        raise SystemExit(f"Missing logo: {LOGO_PATH}")

    logo = Image.open(LOGO_PATH).convert("RGBA")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    SCREEN_DIR.mkdir(parents=True, exist_ok=True)

    assets = {
        OUT_DIR / "feature_graphic.png": make_feature_graphic(logo),
        OUT_DIR / "icon_512.png": make_icon_512(logo),
        SCREEN_DIR / "01_splash.png": make_splash_screenshot(logo),
        SCREEN_DIR / "02_open_jobs.png": make_jobs_screenshot(logo),
        SCREEN_DIR / "03_track_job.png": make_track_screenshot(logo),
        SCREEN_DIR / "04_login.png": make_login_screenshot(logo),
    }

    for path, image in assets.items():
        if path.name == "feature_graphic.png":
            image.save(path, "PNG", optimize=True)
        else:
            image.save(path, "PNG", optimize=True)
        print(f"Wrote {path} ({image.size[0]}x{image.size[1]})")


if __name__ == "__main__":
    main()
