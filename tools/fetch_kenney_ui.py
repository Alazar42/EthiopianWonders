"""Downloads Kenney's UI packs (CC0, https://kenney.nl) and copies the pieces the game uses into
assets/ui/kenney and assets/audio. Safe to re-run.

    python tools/fetch_kenney_ui.py

Packs used: UI Pack: Adventure (panels, buttons, ribbons), UI Pack (star icon and click sounds)
and UI Pack: Sci-fi (cursors). The zips are unpacked into a temporary folder and only plain image
and sound files are copied. Nothing from the archives is executed.
"""
import os
import shutil
import tempfile
import urllib.request
import zipfile

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
PACKS = {
    'adventure': 'https://kenney.nl/media/pages/assets/ui-pack-adventure/9a877376bc-1723597274/kenney_ui-pack-adventure.zip',
    'ui': 'https://kenney.nl/media/pages/assets/ui-pack/f651646eab-1718203990/kenney_ui-pack.zip',
    'scifi': 'https://kenney.nl/media/pages/assets/ui-pack-sci-fi/b67c2acd31-1724181109/kenney_ui-pack-space-expansion.zip',
}

# (pack, path inside the zip, destination under assets/ui/kenney). Adventure sprites use the 2x set.
SPRITES = [
    ('adventure', 'PNG/Double/panel_brown.png', 'adventure/panel_brown.png'),
    ('adventure', 'PNG/Double/panel_brown_corners_a.png', 'adventure/panel_brown_corners.png'),
    ('adventure', 'PNG/Double/panel_brown_dark.png', 'adventure/panel_brown_dark.png'),
    ('adventure', 'PNG/Double/panel_grey.png', 'adventure/panel_grey.png'),
    ('adventure', 'PNG/Double/button_brown.png', 'adventure/button_brown.png'),
    ('adventure', 'PNG/Double/button_grey.png', 'adventure/button_grey.png'),
    ('adventure', 'PNG/Double/button_red.png', 'adventure/button_red.png'),
    ('adventure', 'PNG/Double/banner_hanging.png', 'adventure/banner_hanging.png'),
    ('adventure', 'PNG/Double/banner_classic_curtain.png', 'adventure/banner_curtain.png'),
    ('adventure', 'PNG/Double/banner_modern.png', 'adventure/banner_modern.png'),
    ('ui', 'PNG/Yellow/Default/star.png', 'icons/star.png'),
    ('scifi', 'PNG/Blue/Double/crosshair_color_a.png', 'cursors/crosshair.png'),
    ('scifi', 'PNG/Extra/Double/cursor_d.png', 'cursors/arrow.png'),
]
SOUNDS = [('click-a.ogg', 'kenney_click.ogg'), ('tap-a.ogg', 'kenney_tap.ogg'), ('switch-a.ogg', 'kenney_switch.ogg')]
OBSOLETE = ['buttons', 'cards', 'panels', 'sliders']


def main():
    work = tempfile.mkdtemp(prefix='kenney_')
    roots = {}
    for key, url in PACKS.items():
        path = os.path.join(work, key + '.zip')
        print('downloading', url)
        urllib.request.urlretrieve(url, path)
        target = os.path.join(work, key)
        with zipfile.ZipFile(path) as z:
            z.extractall(target)
        roots[key] = target

    out_ui = os.path.join(ROOT, 'assets', 'ui', 'kenney')
    for old in OBSOLETE:
        shutil.rmtree(os.path.join(out_ui, old), ignore_errors=True)
    for pack, inner, dest in SPRITES:
        destination = os.path.join(out_ui, dest)
        os.makedirs(os.path.dirname(destination), exist_ok=True)
        shutil.copyfile(os.path.join(roots[pack], inner), destination)
    # The slider handle is the round brown button, scaled down to handle size.
    handle = Image.open(os.path.join(roots['adventure'], 'PNG/Double/round_brown.png')).convert('RGBA')
    os.makedirs(os.path.join(out_ui, 'sliders'), exist_ok=True)
    handle.resize((44, 44), Image.LANCZOS).save(os.path.join(out_ui, 'sliders', 'grabber.png'))
    for src, dest in SOUNDS:
        shutil.copyfile(os.path.join(roots['ui'], 'Sounds', src), os.path.join(ROOT, 'assets', 'audio', dest))
    shutil.copyfile(os.path.join(roots['adventure'], 'License.txt'), os.path.join(out_ui, 'License.txt'))
    shutil.rmtree(work, ignore_errors=True)
    print('copied %d sprites and %d sounds' % (len(SPRITES) + 1, len(SOUNDS)))


if __name__ == '__main__':
    main()
