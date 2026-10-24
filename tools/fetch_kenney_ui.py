"""Downloads Kenney's UI packs (CC0, https://kenney.nl) and copies the pieces the game uses into
assets/ui/kenney, assets/fonts and assets/audio. Safe to re-run.

    python tools/fetch_kenney_ui.py

The zips are unpacked into a temporary folder and only plain image, font and sound files are copied.
Nothing from the archives is executed.
"""
import os
import shutil
import tempfile
import urllib.request
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
PACKS = {
    'scifi': 'https://kenney.nl/media/pages/assets/ui-pack-sci-fi/b67c2acd31-1724181109/kenney_ui-pack-space-expansion.zip',
    'ui': 'https://kenney.nl/media/pages/assets/ui-pack/f651646eab-1718203990/kenney_ui-pack.zip',
}

# (pack, path inside the zip, destination under assets/ui/kenney)
SPRITES = []
for color in ('Blue', 'Green', 'Yellow', 'Red', 'Grey'):
    for name in ('button_rectangle_depth_gradient', 'button_rectangle_gradient', 'button_rectangle_depth_gloss',
                 'button_rectangle_depth_flat', 'button_rectangle_flat'):
        SPRITES.append(('ui', f'PNG/{color}/Default/{name}.png', f'buttons/{color.lower()}_{name}.png'))
for color in ('Blue', 'Yellow', 'Red', 'Green'):
    SPRITES.append(('scifi', f'PNG/{color}/Default/button_square_header_large_rectangle_screws.png', f'cards/{color.lower()}_card.png'))
SPRITES += [
    ('scifi', 'PNG/Extra/Default/panel_glass_screws.png', 'panels/panel_glass_screws.png'),
    ('scifi', 'PNG/Extra/Default/panel_glass.png', 'panels/panel_glass.png'),
    ('scifi', 'PNG/Extra/Default/button_rectangle_depth.png', 'panels/silver_button_depth.png'),
    ('scifi', 'PNG/Extra/Default/button_rectangle.png', 'panels/silver_button.png'),
    ('ui', 'PNG/Blue/Double/slide_horizontal_color_section.png', 'sliders/grabber.png'),
    ('ui', 'PNG/Yellow/Default/star.png', 'icons/star.png'),
    ('ui', 'PNG/Blue/Default/icon_cross.png', 'icons/cross.png'),
    ('scifi', 'PNG/Blue/Double/crosshair_color_a.png', 'cursors/crosshair.png'),
    ('scifi', 'PNG/Extra/Double/cursor_d.png', 'cursors/arrow.png'),
]
SOUNDS = [('click-a.ogg', 'kenney_click.ogg'), ('tap-a.ogg', 'kenney_tap.ogg'), ('switch-a.ogg', 'kenney_switch.ogg')]
FONTS = [('Font/Kenney Future.ttf', 'KenneyFuture.ttf'), ('Font/Kenney Future Narrow.ttf', 'KenneyFutureNarrow.ttf')]


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
    for pack, inner, dest in SPRITES:
        destination = os.path.join(out_ui, dest)
        os.makedirs(os.path.dirname(destination), exist_ok=True)
        shutil.copyfile(os.path.join(roots[pack], inner), destination)
    for src, dest in SOUNDS:
        shutil.copyfile(os.path.join(roots['ui'], 'Sounds', src), os.path.join(ROOT, 'assets', 'audio', dest))
    for src, dest in FONTS:
        shutil.copyfile(os.path.join(roots['scifi'], src), os.path.join(ROOT, 'assets', 'fonts', dest))
    shutil.copyfile(os.path.join(roots['ui'], 'License.txt'), os.path.join(out_ui, 'License.txt'))
    shutil.rmtree(work, ignore_errors=True)
    print('copied %d sprites, %d sounds, %d fonts' % (len(SPRITES), len(SOUNDS), len(FONTS)))


if __name__ == '__main__':
    main()
