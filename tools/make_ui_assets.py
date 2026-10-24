"""Writes the heart icons (SVG) and the game theme (assets/ui/game_theme.tres).

    python tools/fetch_kenney_ui.py     # once: downloads the Kenney textures, fonts and sounds
    python tools/make_ui_assets.py

The theme is a normal Godot Theme resource built from Kenney's 9-slice textures; edit it in the
editor afterwards if you like. Colour language: blue = information, yellow = achievement,
red = game over, green = go.
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
UI = os.path.join(ROOT, 'assets', 'ui')
K = 'res://assets/ui/kenney/'
os.makedirs(UI, exist_ok=True)

HEART = 'M32 58 C10 40 4 29 4 20 C4 11 11 5 19 5 C25 5 30 8 32 13 C34 8 39 5 45 5 C53 5 60 11 60 20 C60 29 54 40 32 58 Z'
HEART_LEFT = 'M32 58 C10 40 4 29 4 20 C4 11 11 5 19 5 C25 5 30 8 32 13 L32 58 Z'
GRADIENT = ('<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff8579"/>'
            '<stop offset="1" stop-color="#cf2229"/></linearGradient></defs>')
icons = {
    'heart_full.svg': f'''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">{GRADIENT}
<path d="{HEART}" fill="url(#g)" stroke="#2b0a0c" stroke-width="3" stroke-linejoin="round"/>
<path d="M13 19 C13 14 17 11 22 11" stroke="#ffe0dc" stroke-width="3.5" fill="none" stroke-linecap="round"/>
</svg>''',
    'heart_half.svg': f'''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">{GRADIENT}
<path d="{HEART}" fill="#2a3150" fill-opacity="0.85"/>
<path d="{HEART_LEFT}" fill="url(#g)"/>
<path d="M13 19 C13 14 17 11 22 11" stroke="#ffe0dc" stroke-width="3.5" fill="none" stroke-linecap="round"/>
<path d="{HEART}" fill="none" stroke="#2b0a0c" stroke-width="3" stroke-linejoin="round"/>
</svg>''',
    'heart_empty.svg': f'''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<path d="{HEART}" fill="#2a3150" fill-opacity="0.85" stroke="#2b0a0c" stroke-width="3" stroke-linejoin="round"/>
</svg>''',
}
for name, svg in icons.items():
    with open(os.path.join(UI, name), 'w', encoding='utf-8') as f:
        f.write(svg)
for stale in ('heart.svg', 'star.svg', 'crosshair.svg'):
    for path in (os.path.join(UI, stale), os.path.join(UI, stale + '.import')):
        if os.path.exists(path):
            os.remove(path)

textures = {}


def tex(path):
    if path not in textures:
        textures[path] = 'tex_%d' % len(textures)
    return textures[path]


def style(name, texture, margins, content, modulate=None):
    add(f'[sub_resource type="StyleBoxTexture" id="{name}"]')
    add(f'texture = ExtResource("{tex(texture)}")')
    left, top, right, bottom = margins
    add(f'texture_margin_left = {left}')
    add(f'texture_margin_top = {top}')
    add(f'texture_margin_right = {right}')
    add(f'texture_margin_bottom = {bottom}')
    cl, ct, cr, cb = content
    add(f'content_margin_left = {cl}')
    add(f'content_margin_top = {ct}')
    add(f'content_margin_right = {cr}')
    add(f'content_margin_bottom = {cb}')
    if modulate:
        add(f'modulate_color = Color{modulate}')
    add('')


# Sub resources are collected first so the header can list every texture they use.
body = []
add = body.append

# --- styles -----------------------------------------------------------------------------------
style('Panel', K + 'panels/panel_glass_screws.png', (12, 12, 12, 12), (26, 22, 26, 22))
style('HudPanel', K + 'panels/panel_glass.png', (12, 12, 12, 12), (18, 10, 18, 10))
for color in ('blue', 'yellow', 'red', 'green'):
    # Header band is 34 px tall: content starts at the top so a title label can sit in the band.
    style('Card_' + color, K + f'cards/{color}_card.png', (10, 34, 10, 12), (26, 0, 26, 24))
for color in ('blue', 'green', 'red', 'yellow'):
    style('Btn_' + color, K + f'buttons/{color}_button_rectangle_depth_gradient.png', (10, 10, 10, 12), (30, 10, 30, 16))
    style('BtnHover_' + color, K + f'buttons/{color}_button_rectangle_depth_gloss.png', (10, 10, 10, 12), (30, 10, 30, 16))
    style('BtnDown_' + color, K + f'buttons/{color}_button_rectangle_gradient.png', (10, 10, 10, 10), (30, 16, 30, 10))
style('BtnDisabled', K + 'buttons/grey_button_rectangle_depth_flat.png', (10, 10, 10, 12), (30, 10, 30, 16))
# The track sprite is white, so it is tinted darker to stay visible on the silver cards.

def flat_bar(name, bg, border):
    # A slider bar is as tall as its style's minimum height, so the height comes from content margins.
    add(f'[sub_resource type="StyleBoxFlat" id="{name}"]')
    add(f'bg_color = Color{bg}')
    for side in ('left', 'top', 'right', 'bottom'):
        add(f'border_width_{side} = 2')
    add(f'border_color = Color{border}')
    for corner in ('top_left', 'top_right', 'bottom_right', 'bottom_left'):
        add(f'corner_radius_{corner} = 8')
    add('content_margin_top = 8')
    add('content_margin_bottom = 8')
    add('')


flat_bar('SliderTrack', '(0.36, 0.43, 0.62, 1)', '(0.2, 0.25, 0.42, 1)')
flat_bar('SliderFill', '(0.13, 0.64, 0.88, 1)', '(0.05, 0.4, 0.62, 1)')

add('[sub_resource type="StyleBoxFlat" id="Focus"]')
add('bg_color = Color(1, 1, 1, 0)')
for side in ('left', 'top', 'right', 'bottom'):
    add(f'border_width_{side} = 3')
add('border_color = Color(1, 0.86, 0.35, 1)')
for corner in ('top_left', 'top_right', 'bottom_right', 'bottom_left'):
    add(f'corner_radius_{corner} = 10')
add('expand_margin_left = 3')
add('expand_margin_top = 3')
add('expand_margin_right = 3')
add('expand_margin_bottom = 3')
add('')
add('[sub_resource type="StyleBoxLine" id="Line"]')
add('color = Color(0.5, 0.56, 0.72, 0.8)')
add('thickness = 2')
add('')

NAVY = '(0.10, 0.14, 0.28, 1)'
add('[resource]')
add('default_font = SubResource("Font_Body")')
add('default_font_size = 24')
add('')
add(f'Label/colors/font_color = Color{NAVY}')
add('Label/colors/font_outline_color = Color(0, 0, 0, 0)')
add('Label/constants/outline_size = 0')
add('Label/font_sizes/font_size = 24')
add('Label/fonts/font = SubResource("Font_Body")')
add('')


def label_variation(name, font, size, color, outline_color, outline):
    add(f'{name}/base_type = &"Label"')
    add(f'{name}/colors/font_color = Color{color}')
    add(f'{name}/colors/font_outline_color = Color{outline_color}')
    add(f'{name}/constants/outline_size = {outline}')
    add(f'{name}/font_sizes/font_size = {size}')
    add(f'{name}/fonts/font = SubResource("{font}")')
    add('')


label_variation('TitleLabel', 'Font_Future', 62, '(1, 0.83, 0.3, 1)', '(0.25, 0.1, 0.02, 1)', 12)
label_variation('HeaderLabel', 'Font_Future', 26, '(1, 1, 1, 1)', '(0.04, 0.2, 0.32, 1)', 5)
label_variation('FloatLabel', 'Font_Bold', 28, '(1, 1, 1, 1)', '(0.03, 0.06, 0.15, 1)', 6)
label_variation('SubtitleLabel', 'Font_Bold', 36, '(0.88, 0.95, 1, 1)', '(0.03, 0.06, 0.15, 1)', 7)
label_variation('StatLabel', 'Font_Bold', 30, NAVY, '(0, 0, 0, 0)', 0)
label_variation('HintLabel', 'Font_Body', 22, '(0.30, 0.36, 0.52, 1)', '(0, 0, 0, 0)', 0)
label_variation('NumberLabel', 'Font_FutureNarrow', 34, NAVY, '(0, 0, 0, 0)', 0)

add('Button/colors/font_color = Color(1, 1, 1, 1)')
add('Button/colors/font_hover_color = Color(1, 1, 0.85, 1)')
add('Button/colors/font_pressed_color = Color(0.9, 0.95, 1, 1)')
add('Button/colors/font_focus_color = Color(1, 1, 1, 1)')
add('Button/colors/font_disabled_color = Color(0.75, 0.78, 0.85, 1)')
add('Button/colors/font_outline_color = Color(0.04, 0.18, 0.3, 1)')
add('Button/constants/outline_size = 5')
add('Button/font_sizes/font_size = 26')
add('Button/fonts/font = SubResource("Font_Future")')
add('Button/styles/normal = SubResource("Btn_blue")')
add('Button/styles/hover = SubResource("BtnHover_blue")')
add('Button/styles/pressed = SubResource("BtnDown_blue")')
add('Button/styles/disabled = SubResource("BtnDisabled")')
add('Button/styles/focus = SubResource("Focus")')
add('')
for color in ('green', 'red', 'yellow'):
    variation = color.capitalize() + 'Button'
    add(f'{variation}/base_type = &"Button"')
    add(f'{variation}/styles/normal = SubResource("Btn_{color}")')
    add(f'{variation}/styles/hover = SubResource("BtnHover_{color}")')
    add(f'{variation}/styles/pressed = SubResource("BtnDown_{color}")')
    add('')

add('PanelContainer/styles/panel = SubResource("Panel")')
add('Panel/styles/panel = SubResource("Panel")')
add('HudPanel/base_type = &"PanelContainer"')
add('HudPanel/styles/panel = SubResource("HudPanel")')
for color in ('blue', 'yellow', 'red', 'green'):
    add(f'Card{color.capitalize()}/base_type = &"PanelContainer"')
    add(f'Card{color.capitalize()}/styles/panel = SubResource("Card_{color}")')
add('')
add('HSlider/styles/slider = SubResource("SliderTrack")')
add('HSlider/styles/grabber_area = SubResource("SliderFill")')
add('HSlider/styles/grabber_area_highlight = SubResource("SliderFill")')
add(f'HSlider/icons/grabber = ExtResource("{tex(K + "sliders/grabber.png")}")')
add(f'HSlider/icons/grabber_highlight = ExtResource("{tex(K + "sliders/grabber.png")}")')
add('HSlider/constants/grabber_offset = 0')
add('')
add('HSeparator/styles/separator = SubResource("Line")')
add('VSeparator/styles/separator = SubResource("Line")')
add('HSeparator/constants/separation = 14')
add('VBoxContainer/constants/separation = 12')
add('HBoxContainer/constants/separation = 12')
add('GridContainer/constants/h_separation = 28')
add('GridContainer/constants/v_separation = 8')

header = []
header.append(f'[gd_resource type="Theme" load_steps={len(textures) + 12} format=3]')
header.append('')
header.append('[ext_resource type="FontFile" path="res://assets/fonts/Rajdhani-SemiBold.ttf" id="1_body"]')
header.append('[ext_resource type="FontFile" path="res://assets/fonts/Rajdhani-Bold.ttf" id="2_bold"]')
header.append('[ext_resource type="FontFile" path="res://assets/fonts/KenneyFuture.ttf" id="3_future"]')
header.append('[ext_resource type="FontFile" path="res://assets/fonts/KenneyFutureNarrow.ttf" id="5_narrow"]')
header.append('[ext_resource type="FontFile" path="res://assets/fonts/NotoSansEthiopic-Variable.ttf" id="4_geez"]')
for path, tid in textures.items():
    header.append(f'[ext_resource type="Texture2D" path="{path}" id="{tid}"]')
header.append('')
for fid, base in (('Body', '1_body'), ('Bold', '2_bold'), ('Future', '3_future'), ('FutureNarrow', '5_narrow')):
    header.append(f'[sub_resource type="FontVariation" id="Font_{fid}"]')
    header.append(f'base_font = ExtResource("{base}")')
    header.append('fallbacks = [ExtResource("4_geez")]')
    header.append('')

with open(os.path.join(UI, 'game_theme.tres'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(header + body) + '\n')
print('wrote hearts and game_theme.tres with %d Kenney textures' % len(textures))
