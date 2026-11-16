"""Check the actual configured source against Android 12's 2/3 circle."""
from pathlib import Path
import json, math
from PIL import Image, ImageDraw, ImageChops
root = Path(__file__).resolve().parents[1]
source = root / 'assets/brand/approved-a/splash-android12-dark-1152.png'
image = Image.open(source).convert('RGBA')
assert image.size == (1152, 1152)
alpha = image.getchannel('A')
mask = Image.new('L', image.size)
ImageDraw.Draw(mask).ellipse((192, 192, 959, 959), fill=255)
clipped = ImageChops.multiply(alpha, mask)
assert ImageChops.difference(alpha, clipped).getbbox() is None
radius = max(math.hypot(i % 1152 + .5 - 576, i // 1152 + .5 - 576) for i, v in enumerate(alpha.tobytes()) if v)
assert radius < 384
panel = Image.new('RGBA', image.size, '#13262A')
panel.alpha_composite(image)
ImageDraw.Draw(panel).ellipse((192, 192, 959, 959), outline='#8AD8C7', width=2)
output = root / 'docs/validation'
panel.convert('RGB').save(output / 'continuous-splash-mask.png')
records = {'source': str(source.relative_to(root)), 'background_light_and_dark': '#13262A', 'safe_radius_px': 384, 'maximum_alpha_radius_px': radius, 'cropped_pixels': 0, 'logical_canvas_dp': 288, 'generated_images': {}}
for density, width in [('mdpi', 288), ('hdpi',432), ('xhdpi',576), ('xxhdpi',864), ('xxxhdpi',1152)]:
    for name in ['splash.png', 'android12splash.png']:
        file = root / f'android/app/src/main/res/drawable-{density}/{name}'
        assert Image.open(file).size == (width, width), str(file)
        records['generated_images'][str(file.relative_to(root))] = [width, width]
(output / 'continuous-splash-mask.json').write_text(json.dumps(records, indent=2) + '\n')
print(json.dumps(records, indent=2))
