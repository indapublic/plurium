#!/usr/bin/env python3
"""Builds Plurium's app icons: violet for the release, orange for Plurium Dev
(test builds with plurium_dev_build = true).

Recolors Chromium's own icon sources (chrome/app/theme/chromium/mac:
Assets.xcassets and AppIcon.icon, left untouched) in a temp directory,
compiles them with Chromium's tools/mac/icons/compile_car.py and writes
Assets.car + app.icns (release) and Assets_dev.car + app_dev.icns (dev) next
to the sources. Run again after a rebase if upstream changes the icon. Needs
Pillow and Xcode 26+.

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

# Name tag: (hue shift from Chromium blue, saturation factor).
VARIANTS = {
    '': (55 / 360, 1.1),  # Release: violet.
    '_dev': (180 / 360, 1.15),  # Plurium Dev: orange.
}


def recolor_rgb(r, g, b, hue_shift, saturation):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    r, g, b = colorsys.hsv_to_rgb((h + hue_shift) % 1, min(1, s * saturation),
                                  v)
    return round(r * 255), round(g * 255), round(b * 255)


def recolor_png(path, hue_shift, saturation):
    rgba = Image.open(path).convert('RGBA')
    h, s, v = rgba.convert('RGB').convert('HSV').split()
    h = h.point(lambda x: (x + round(hue_shift * 256)) % 256)
    s = s.point(lambda x: min(255, round(x * saturation)))
    rgb = Image.merge('HSV', (h, s, v)).convert('RGB')
    rgb.putalpha(rgba.getchannel('A'))
    # Kept as RGBA: converting back to a palette would posterize the colors.
    rgb.save(path)


def recolor_hex(text, hue_shift, saturation):
    def replace(match):
        value = match.group(1)
        r, g, b = (int(value[i:i + 2], 16) for i in (0, 2, 4))
        return '#%02X%02X%02X' % recolor_rgb(r, g, b, hue_shift, saturation)

    return re.sub(r'#([0-9A-Fa-f]{6})\b', replace, text)


def build(src, theme, tag, hue_shift, saturation):
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        # compile_car.py takes Assets<tag>.xcassets and AppIcon<tag>.icon and
        # writes Assets<tag>.car and app<tag>.icns next to them.
        xcassets = tmp / f'Assets{tag}.xcassets'
        icon = tmp / f'AppIcon{tag}.icon'
        shutil.copytree(theme / 'Assets.xcassets', xcassets)
        shutil.copytree(theme / 'AppIcon.icon', icon)
        for png in tmp.rglob('*.png'):
            recolor_png(png, hue_shift, saturation)
        for svg in icon.rglob('*.svg'):
            svg.write_text(recolor_hex(svg.read_text(), hue_shift, saturation))

        subprocess.run([
            sys.executable,
            str(src / 'tools/mac/icons/compile_car.py'),
            str(xcassets)
        ],
                       check=True)

        # Legacy .icns (CFBundleIconFile). Recent actool versions emit it
        # along with the .car; otherwise build it from the bitmaps, in the
        # sizes Chromium uses.
        icns = tmp / f'app{tag}.icns'
        appicons = xcassets / 'AppIcon.appiconset'
        if not icns.exists():
            iconset = tmp / 'app.iconset'
            iconset.mkdir()
            for size in (16, 32, 128, 256, 512):
                shutil.copyfile(appicons / f'appicon_{size}.png',
                                iconset / f'icon_{size}x{size}.png')
            subprocess.run(
                ['iconutil', '-c', 'icns', '-o',
                 str(icns), str(iconset)],
                check=True)

        shutil.copyfile(tmp / f'Assets{tag}.car', theme / f'Assets{tag}.car')
        shutil.copyfile(icns, theme / f'app{tag}.icns')
        shutil.copyfile(
            appicons / 'appicon_256.png',
            pathlib.Path(tempfile.gettempdir()) / f'plurium-icon{tag}.png')
    print(f'Wrote {theme}/Assets{tag}.car and {theme}/app{tag}.icns')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--src', default='/Volumes/Workspace/chromium/src')
    src = pathlib.Path(parser.parse_args().src)
    theme = src / 'chrome/app/theme/chromium/mac'
    for tag, (hue_shift, saturation) in VARIANTS.items():
        build(src, theme, tag, hue_shift, saturation)


if __name__ == '__main__':
    main()
