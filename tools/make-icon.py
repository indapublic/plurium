#!/usr/bin/env python3
"""Builds the violet app icon of Plurium (the profile-tabs build).

Recolors Chromium's own icon sources (chrome/app/theme/chromium/mac:
Assets.xcassets and AppIcon.icon, left untouched) in a temp directory,
compiles them with Chromium's tools/mac/icons/compile_car.py and writes
Assets.car and app.icns next to the sources. Run again after a rebase if
upstream changes the icon. Needs Pillow and Xcode 26+.

Usage: python3 make-icon.py [--src /Volumes/Workspace/chromium/src]
"""

import argparse
import colorsys
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

HUE_SHIFT = 55 / 360  # Chromium blue -> violet.
SATURATION = 1.1


def recolor_rgb(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    r, g, b = colorsys.hsv_to_rgb((h + HUE_SHIFT) % 1, min(1, s * SATURATION),
                                  v)
    return round(r * 255), round(g * 255), round(b * 255)


def recolor_png(path):
    rgba = Image.open(path).convert('RGBA')
    h, s, v = rgba.convert('RGB').convert('HSV').split()
    h = h.point(lambda x: (x + round(HUE_SHIFT * 256)) % 256)
    s = s.point(lambda x: min(255, round(x * SATURATION)))
    rgb = Image.merge('HSV', (h, s, v)).convert('RGB')
    rgb.putalpha(rgba.getchannel('A'))
    # Kept as RGBA: converting back to a palette would posterize the colors.
    rgb.save(path)


def recolor_hex(text):
    def replace(match):
        value = match.group(1)
        r, g, b = (int(value[i:i + 2], 16) for i in (0, 2, 4))
        return '#%02X%02X%02X' % recolor_rgb(r, g, b)

    return re.sub(r'#([0-9A-Fa-f]{6})\b', replace, text)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--src', default='/Volumes/Workspace/chromium/src')
    src = pathlib.Path(parser.parse_args().src)
    theme = src / 'chrome/app/theme/chromium/mac'

    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        shutil.copytree(theme / 'Assets.xcassets', tmp / 'Assets.xcassets')
        shutil.copytree(theme / 'AppIcon.icon', tmp / 'AppIcon.icon')
        for png in tmp.rglob('*.png'):
            recolor_png(png)
        for svg in (tmp / 'AppIcon.icon').rglob('*.svg'):
            svg.write_text(recolor_hex(svg.read_text()))

        subprocess.run([
            sys.executable,
            str(src / 'tools/mac/icons/compile_car.py'),
            str(tmp / 'Assets.xcassets')
        ],
                       check=True)

        # Legacy .icns (CFBundleIconFile). Recent actool versions emit it
        # along with Assets.car; otherwise build it from the bitmaps, in the
        # sizes Chromium uses.
        appicons = tmp / 'Assets.xcassets/AppIcon.appiconset'
        if not (tmp / 'app.icns').exists():
            iconset = tmp / 'app.iconset'
            iconset.mkdir()
            for size in (16, 32, 128, 256, 512):
                shutil.copyfile(appicons / f'appicon_{size}.png',
                                iconset / f'icon_{size}x{size}.png')
            subprocess.run([
                'iconutil', '-c', 'icns', '-o',
                str(tmp / 'app.icns'),
                str(iconset)
            ],
                           check=True)

        shutil.copyfile(tmp / 'Assets.car', theme / 'Assets.car')
        shutil.copyfile(tmp / 'app.icns', theme / 'app.icns')
        shutil.copyfile(appicons / 'appicon_256.png',
                        pathlib.Path(tempfile.gettempdir()) / 'plurium-icon-preview.png')
    print(f'Wrote {theme}/Assets.car and {theme}/app.icns')


if __name__ == '__main__':
    main()
