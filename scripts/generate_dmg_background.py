#!/usr/bin/env python3
import os
import math
import subprocess
from PIL import Image, ImageDraw, ImageFont, ImageFilter

WIDTH = 1320
HEIGHT = 880
SCALE = 2  # 660x440 points at 2x

def get_font(size, bold=False):
    candidates = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for p in candidates:
        if os.path.exists(p):
            try:
                idx = 1 if (bold and p.endswith(".ttc")) else 0
                return ImageFont.truetype(p, size, index=idx)
            except Exception:
                continue
    return ImageFont.load_default()

def draw_radial_glow(image, center, radius, color_rgb, max_alpha):
    cx, cy = center
    glow = Image.new("RGBA", (radius * 2, radius * 2), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    for r in range(radius, 0, -2):
        alpha = int(max_alpha * ((1.0 - (r / radius)) ** 2))
        draw.ellipse([radius - r, radius - r, radius + r, radius + r], fill=(color_rgb[0], color_rgb[1], color_rgb[2], alpha))
    image.alpha_composite(glow, (cx - radius, cy - radius))

def extract_real_app_icon():
    icon_out = "scripts/real_appicon.png"
    if os.path.exists(icon_out):
        return icon_out
    
    tmp_dir = "/tmp/val_icon_extract"
    os.makedirs(tmp_dir, exist_ok=True)
    try:
        subprocess.run([
            "/Applications/Xcode.app/Contents/Developer/usr/bin/actool",
            "Valentine/Assets.xcassets", "appicon.icon",
            "--compile", tmp_dir,
            "--output-format", "human-readable-text",
            "--output-partial-info-plist", f"{tmp_dir}/info.plist",
            "--app-icon", "appicon",
            "--accent-color", "AccentColor",
            "--target-device", "mac",
            "--minimum-deployment-target", "26.5",
            "--platform", "macosx"
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        icns_file = f"{tmp_dir}/appicon.icns"
        if os.path.exists(icns_file):
            subprocess.run(["sips", "-s", "format", "png", icns_file, "--out", icon_out],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    finally:
        subprocess.run(["rm", "-rf", tmp_dir])
    return icon_out if os.path.exists(icon_out) else None

def extract_applications_icon():
    target_path = "scripts/applications_icon.png"
    if os.path.exists(target_path):
        return target_path
    icns_path = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ApplicationsFolderIcon.icns"
    if os.path.exists(icns_path):
        subprocess.run(["sips", "-s", "format", "png", icns_path, "--out", target_path],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if os.path.exists(target_path):
            return target_path
    return None

def draw_sleek_arrow(image, start_x, end_x, y, start_color, end_color):
    arrow_img = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(arrow_img)
    
    length = end_x - start_x
    bar_height = 8
    
    # Outer glow along the shaft
    for offset in range(8, 0, -2):
        alpha = int(24 * (1.0 - offset / 8.0))
        for x in range(start_x, end_x):
            t = (x - start_x) / float(length)
            r = int(start_color[0] * (1 - t) + end_color[0] * t)
            g = int(start_color[1] * (1 - t) + end_color[1] * t)
            b = int(start_color[2] * (1 - t) + end_color[2] * t)
            draw.line([(x, y - bar_height // 2 - offset), (x, y + bar_height // 2 + offset)],
                      fill=(r, g, b, alpha))
            
    # Main stem
    for x in range(start_x, end_x):
        t = (x - start_x) / float(length)
        r = int(start_color[0] * (1 - t) + end_color[0] * t)
        g = int(start_color[1] * (1 - t) + end_color[1] * t)
        b = int(start_color[2] * (1 - t) + end_color[2] * t)
        draw.line([(x, y - bar_height // 2), (x, y + bar_height // 2)],
                  fill=(r, g, b, 255))
        
    # Arrow head
    head_len = 32
    head_w = 22
    tip = (end_x + head_len, y)
    top = (end_x, y - head_w)
    bottom = (end_x, y + head_w)
    
    # Arrow head glow
    for off in range(8, 0, -2):
        draw.polygon([(tip[0] + off, tip[1]), (top[0] - off, top[1] - off), (bottom[0] - off, bottom[1] + off)],
                     fill=(end_color[0], end_color[1], end_color[2], 30))
        
    draw.polygon([tip, top, bottom], fill=(end_color[0], end_color[1], end_color[2], 255))
    
    image.alpha_composite(arrow_img)

def render_light_liquid_glass_background(include_icons=False):
    base = Image.new("RGBA", (WIDTH, HEIGHT), (248, 250, 253, 255))
    
    # Luminous background gradient (frosted porcelain to soft lavender-ice)
    gradient = Image.new("RGBA", (WIDTH, HEIGHT))
    gdraw = ImageDraw.Draw(gradient)
    for y in range(HEIGHT):
        ratio = y / float(HEIGHT)
        r = int(252 * (1 - ratio) + 242 * ratio)
        g = int(252 * (1 - ratio) + 246 * ratio)
        b = int(255 * (1 - ratio) + 253 * ratio)
        gdraw.line([(0, y), (WIDTH, y)], fill=(r, g, b, 255))
    base.alpha_composite(gradient)
    
    # Soft, liquid chromatic refractions (Frosted Glass Underglow)
    draw_radial_glow(base, (WIDTH // 2, 85), 320, (254, 205, 211), 75)
    draw_radial_glow(base, (350, 430), 320, (253, 164, 175), 65)
    draw_radial_glow(base, (970, 430), 320, (186, 230, 253), 75)
    draw_radial_glow(base, (660, 430), 220, (233, 213, 255), 50)
    draw_radial_glow(base, (WIDTH // 2, 690), 240, (254, 205, 211), 60)
    
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay)
    
    # Subtle window border
    odraw.rounded_rectangle([18, 18, WIDTH - 19, HEIGHT - 19], radius=32,
                            outline=(0, 0, 0, 14), width=1)
    odraw.rounded_rectangle([19, 19, WIDTH - 20, HEIGHT - 20], radius=31,
                            outline=(255, 255, 255, 200), width=1)
    
    # ==========================================
    # 1. PARTE SUPERIOR: Ícono y Nombre de la App
    # ==========================================
    app_icon_file = extract_real_app_icon()
    if app_icon_file and os.path.exists(app_icon_file):
        app_img = Image.open(app_icon_file).convert("RGBA")
        top_size = (88, 88)
        top_icon = app_img.resize(top_size, Image.Resampling.LANCZOS)
        
        # Soft drop shadow
        shadow = Image.new("RGBA", (140, 140), (0, 0, 0, 0))
        sdraw = ImageDraw.Draw(shadow)
        sdraw.ellipse([15, 20, 125, 130], fill=(15, 23, 42, 40))
        shadow = shadow.filter(ImageFilter.GaussianBlur(12))
        overlay.alpha_composite(shadow, (WIDTH // 2 - 70, 26))
        
        overlay.alpha_composite(top_icon, (WIDTH // 2 - 44, 34))
    
    title_font = get_font(42, bold=True)
    tagline_font = get_font(18, bold=False)
    
    title_text = "Valentine"
    tagline_text = "The best local music player for macOS"
    
    tbbox = odraw.textbbox((0, 0), title_text, font=title_font)
    tw = tbbox[2] - tbbox[0]
    odraw.text(((WIDTH - tw) // 2, 132), title_text, font=title_font, fill=(15, 23, 42, 255))
    
    sbbox = odraw.textbbox((0, 0), tagline_text, font=tagline_font)
    sw = sbbox[2] - sbbox[0]
    odraw.text(((WIDTH - sw) // 2, 182), tagline_text, font=tagline_font, fill=(100, 116, 139, 255))
    
    # Glass divider line
    div_y = 216
    for x in range(320, WIDTH - 320):
        dist = abs(x - WIDTH // 2) / float((WIDTH - 640) // 2)
        alpha = int(40 * (1.0 - (dist ** 1.8)))
        if alpha > 0:
            odraw.line([(x, div_y), (x, div_y)], fill=(0, 0, 0, alpha))
            odraw.line([(x, div_y + 1), (x, div_y + 1)], fill=(255, 255, 255, int(alpha * 1.6)))
    
    # ==========================================
    # 2. ZONA INTERMEDIA: Dropzones de Vidrio Líquido
    # En puntos Finder (escala 1x):
    # Left:  X=175 pt, Y=215 pt -> En 2x: (350, 430)
    # Right: X=485 pt, Y=215 pt -> En 2x: (970, 430)
    #
    # Dimensiones de las tarjetas:
    # Ancho: 300 px (150 pt), Alto: 370 px (185 pt)
    # Y va de 250 px (125 pt) a 620 px (310 pt)
    # Centro de la tarjeta: Y = 435 px (217.5 pt)
    # La etiqueta de texto de Finder se dibuja a Y ≈ 285-300 pt (570-600 px)
    # Por tanto, el texto queda 100% DENTRO de la tarjeta con 20-30 px de margen.
    # ==========================================
    card_w, card_h = 300, 370
    card_y = 250
    left_x = 350 - (card_w // 2)   # 200
    right_x = 970 - (card_w // 2)  # 820
    
    def draw_glass_pedestal(x, y, w, h, accent_rgb):
        # 1. Multi-layered drop shadow for elevation
        card_shadow = Image.new("RGBA", (w + 60, h + 60), (0, 0, 0, 0))
        csdraw = ImageDraw.Draw(card_shadow)
        csdraw.rounded_rectangle([15, 20, w + 45, h + 48], radius=40, fill=(15, 23, 42, 16))
        card_shadow = card_shadow.filter(ImageFilter.GaussianBlur(18))
        overlay.alpha_composite(card_shadow, (x - 30, y - 12))
        
        # 2. Glass body (frosted milky translucent surface)
        odraw.rounded_rectangle([x, y, x + w, y + h], radius=36,
                                fill=(255, 255, 255, 205))
        
        # 3. Chromatic tint layer
        tint_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        tdraw = ImageDraw.Draw(tint_layer)
        tdraw.rounded_rectangle([0, 0, w, h], radius=36, fill=(accent_rgb[0], accent_rgb[1], accent_rgb[2], 14))
        overlay.alpha_composite(tint_layer, (x, y))
        
        # 4. Glass border
        odraw.rounded_rectangle([x, y, x + w, y + h], radius=36,
                                outline=(accent_rgb[0], accent_rgb[1], accent_rgb[2], 70), width=2)
        # Specular light highlight on top edge
        odraw.rounded_rectangle([x + 1, y + 1, x + w - 1, y + 6], radius=35,
                                outline=(255, 255, 255, 230), width=1)
    
    # Left Card (Valentine)
    draw_glass_pedestal(left_x, card_y, card_w, card_h, (244, 63, 94))
    
    # Right Card (Applications)
    draw_glass_pedestal(right_x, card_y, card_w, card_h, (59, 130, 246))
    
    # If preview mode, draw mock icons and text labels to verify alignment
    if include_icons:
        label_font = get_font(25, bold=True)
        if app_icon_file and os.path.exists(app_icon_file):
            slot_icon = app_img.resize((160, 160), Image.Resampling.LANCZOS)
            icon_shadow = Image.new("RGBA", (200, 200), (0, 0, 0, 0))
            isdraw = ImageDraw.Draw(icon_shadow)
            isdraw.ellipse([20, 28, 180, 188], fill=(15, 23, 42, 38))
            icon_shadow = icon_shadow.filter(ImageFilter.GaussianBlur(14))
            overlay.alpha_composite(icon_shadow, (350 - 100, 420 - 90))
            overlay.alpha_composite(slot_icon, (350 - 80, 420 - 80))
            
            v_label = "Valentine"
            vbbox = odraw.textbbox((0, 0), v_label, font=label_font)
            vw = vbbox[2] - vbbox[0]
            # Label position: completely inside the card
            odraw.text((350 - vw // 2, 570), v_label, font=label_font, fill=(15, 23, 42, 255))
            
        apps_icon_file = extract_applications_icon()
        if apps_icon_file and os.path.exists(apps_icon_file):
            apps_img = Image.open(apps_icon_file).convert("RGBA")
            apps_slot = apps_img.resize((160, 160), Image.Resampling.LANCZOS)
            icon_shadow2 = Image.new("RGBA", (200, 200), (0, 0, 0, 0))
            isdraw2 = ImageDraw.Draw(icon_shadow2)
            isdraw2.ellipse([20, 28, 180, 188], fill=(15, 23, 42, 38))
            icon_shadow2 = icon_shadow2.filter(ImageFilter.GaussianBlur(14))
            overlay.alpha_composite(icon_shadow2, (970 - 100, 420 - 90))
            overlay.alpha_composite(apps_slot, (970 - 80, 420 - 80))
            
            a_label = "Applications"
            abbox = odraw.textbbox((0, 0), a_label, font=label_font)
            aw = abbox[2] - abbox[0]
            # Label position: completely inside the card
            odraw.text((970 - aw // 2, 570), a_label, font=label_font, fill=(15, 23, 42, 255))
    
    # ==========================================
    # 3. PARTE INFERIOR: "Drag here to install"
    # ==========================================
    inst_font = get_font(25, bold=True)
    inst_text = "Drag here to install"
    ibbox = odraw.textbbox((0, 0), inst_text, font=inst_font)
    iw = ibbox[2] - ibbox[0]
    
    pill_w = iw + 56
    pill_h = 48
    pill_x = (WIDTH - pill_w) // 2
    pill_y = 665
    
    # Soft glowing shadow behind the glass pill
    pill_shadow = Image.new("RGBA", (pill_w + 40, pill_h + 40), (0, 0, 0, 0))
    psdraw = ImageDraw.Draw(pill_shadow)
    psdraw.rounded_rectangle([12, 16, pill_w + 28, pill_h + 24], radius=24, fill=(244, 63, 94, 45))
    pill_shadow = pill_shadow.filter(ImageFilter.GaussianBlur(12))
    overlay.alpha_composite(pill_shadow, (pill_x - 15, pill_y - 12))
    
    # Liquid Glass Pill Body
    odraw.rounded_rectangle([pill_x, pill_y, pill_x + pill_w, pill_y + pill_h], radius=24,
                            fill=(255, 255, 255, 230))
    odraw.rounded_rectangle([pill_x, pill_y, pill_x + pill_w, pill_y + pill_h], radius=24,
                            outline=(225, 29, 72, 90), width=2)
    odraw.rounded_rectangle([pill_x + 1, pill_y + 1, pill_x + pill_w - 1, pill_y + 4], radius=23,
                            outline=(255, 255, 255, 240), width=1)
    
    odraw.text((pill_x + 28, pill_y + 10), inst_text, font=inst_font, fill=(225, 29, 72, 255))
    
    # Subtitle under "Drag here to install"
    helper_font = get_font(18, bold=False)
    helper_text = "Drop Valentine into Applications to complete installation"
    hbbox = odraw.textbbox((0, 0), helper_text, font=helper_font)
    hw = hbbox[2] - hbbox[0]
    odraw.text(((WIDTH - hw) // 2, 730), helper_text, font=helper_font, fill=(100, 116, 139, 255))
    
    base.alpha_composite(overlay)
    
    # Radiant directional arrow (liquid gradient rose to blue)
    draw_sleek_arrow(base, 510, 770, 420, (244, 63, 94), (59, 130, 246))
    
    return base

def main():
    os.makedirs("preview", exist_ok=True)
    
    # 1. Generate clean 2x background (1320x880) in Light Liquid Glass
    bg_2x = render_light_liquid_glass_background(include_icons=False)
    bg_2x_path = "preview/dmg_background@2x.png"
    bg_2x.save(bg_2x_path, "PNG", optimize=True)
    print(f"Generated: {bg_2x_path}")
    
    # 2. Generate clean 1x background (660x440)
    bg_1x = bg_2x.resize((660, 440), Image.Resampling.LANCZOS)
    bg_1x_path = "preview/dmg_background.png"
    bg_1x.save(bg_1x_path, "PNG", optimize=True)
    print(f"Generated: {bg_1x_path}")
    
    # 3. Generate multi-resolution TIFF for Finder (Retina + Standard)
    tiff_path = "preview/dmg_background.tiff"
    cmd = ["tiffutil", "-cathidpicheck", bg_1x_path, bg_2x_path, "-out", tiff_path]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0:
        print(f"Generated multi-resolution Retina TIFF: {tiff_path}")
    else:
        print(f"Warning: tiffutil failed: {res.stderr}")
        
    # 4. Generate visual preview for developers with mock icons
    preview_img = render_light_liquid_glass_background(include_icons=True)
    preview_path = "preview/dmg_background_preview.png"
    preview_img.save(preview_path, "PNG", optimize=True)
    print(f"Generated preview: {preview_path}")

if __name__ == "__main__":
    main()
