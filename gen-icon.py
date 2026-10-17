# Generate app icon and tray icon for Desktop Aura.
from PIL import Image, ImageDraw
import os

size = 256
out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'assets')
os.makedirs(out_dir, exist_ok=True)

img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Vertical gradient background: blue -> purple (liquid-glass vibe)
top = (94, 140, 255)      # #5E8CFF
bottom = (155, 92, 255)   # #9B5CFF
for y in range(size):
    t = y / (size - 1)
    r = int(top[0] + (bottom[0] - top[0]) * t)
    g = int(top[1] + (bottom[1] - top[1]) * t)
    b = int(top[2] + (bottom[2] - top[2]) * t)
    draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

# Rounded-square mask
mask = Image.new('L', (size, size), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=56, fill=255)
img.putalpha(mask)

# Floating white card with soft shadow + up arrow
card = 100
cx0 = (size - card) // 2
cy0 = (size - card) // 2 - 12

# soft shadow under the card
draw.rounded_rectangle(
    [cx0 + 3, cy0 + 9, cx0 + card + 3, cy0 + card + 9],
    radius=26, fill=(20, 30, 80, 95)
)
# white card
draw.rounded_rectangle(
    [cx0, cy0, cx0 + card, cy0 + card],
    radius=26, fill=(255, 255, 255, 255)
)

# up arrow (chevron) inside the card
arrow = (94, 140, 255, 255)
cx = size // 2
draw.polygon(
    [(cx, cy0 + 20), (cx - 28, cy0 + 56), (cx + 28, cy0 + 56)],
    fill=arrow
)

# small dot under the arrow (the "icon" that floats up)
draw.ellipse(
    [cx - 14, cy0 + 66, cx + 14, cy0 + 94],
    fill=(155, 92, 255, 255)
)

icon_path = os.path.join(out_dir, 'icon.png')
img.save(icon_path)

# tray icon (32x32)
tray = img.resize((32, 32), Image.LANCZOS)
tray_path = os.path.join(out_dir, 'tray.png')
tray.save(tray_path)

print('icon.png  ->', icon_path)
print('tray.png  ->', tray_path)
