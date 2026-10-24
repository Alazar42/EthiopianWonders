"""Writes the heart icons (SVG) and the game theme (assets/ui/game_theme.tres).

    python tools/fetch_kenney_ui.py     # once: Kenney's Adventure UI sprites and sounds
    python tools/fetch_fonts.py         # once: Cinzel and Nunito
    python tools/make_ui_assets.py

The theme is a normal Godot Theme resource built from Kenney's Adventure 9-slice textures
(parchment panels, wood-framed buttons); edit it in the editor afterwards if you like.
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
<path d="{HEART}" fill="#5a4636" fill-opacity="0.55"/>
<path d="{HEART_LEFT}" fill="url(#g)"/>
<path d="M13 19 C13 14 17 11 22 11" stroke="#ffe0dc" stroke-width="3.5" fill="none" stroke-linecap="round"/>
<path d="{HEART}" fill="none" stroke="#2b0a0c" stroke-width="3" stroke-linejoin="round"/>
</svg>''',
    'heart_empty.svg': f'''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<path d="{HEART}" fill="#5a4636" fill-opacity="0.55" stroke="#2b0a0c" stroke-width="3" stroke-linejoin="round"/>
</svg>''',
}
for name, svg in icons.items():
    with open(os.path.join(UI, name), 'w', encoding='utf-8') as f:
        f.write(svg)

textures = {}


def tex(path):
    if path not in textures:
        textures[path] = 'tex_%d' % len(textures)
    return textures[path]


body = []
add = body.append


def style(name, texture, margins, content, modulate=None):
    add(f'[sub_resource type="StyleBoxTexture" id="{name}"]')
    add(f'texture = ExtResource("{tex(texture)}")')
    for side, value in zip(('left', 'top', 'right', 'bottom'), margins):
        add(f'texture_margin_{side} = {value}')
    for side, value in zip(('left', 'top', 'right', 'bottom'), content):
        add(f'content_margin_{side} = {value}')
    if modulate:
        add(f'modulate_color = Color{modulate}')
    add('')


def flat_bar(name, bg, border):
    # A slider bar is as tall as its style's minimum height, so the height comes from content margins.
    add(f'[sub_resource type="StyleBoxFlat" id="{name}"]')
    add(f'bg_color = Color{bg}')
    for side in ('left', 'top', 'right', 'bottom'):
        add(f'border_width_{side} = 3')
    add(f'border_color = Color{border}')
    for corner in ('top_left', 'top_right', 'bottom_right', 'bottom_left'):
        add(f'corner_radius_{corner} = 9')
    add('content_margin_top = 9')
    add('content_margin_bottom = 9')
    add('')


PANEL = K + 'adventure/panel_brown.png'
style('Panel', PANEL, (24, 24, 24, 24), (32, 28, 32, 28))
style('HudPanel', PANEL, (24, 24, 24, 24), (24, 14, 24, 14))
style('Card', K + 'adventure/panel_brown_corners.png', (30, 30, 30, 30), (38, 30, 38, 34))
for name, sprite in (('brown', 'button_brown'), ('grey', 'button_grey'), ('red', 'button_red')):
    path = K + f'adventure/{sprite}.png'
    style('Btn_' + name, path, (16, 16, 16, 16), (32, 12, 32, 16))
    style('BtnHover_' + name, path, (16, 16, 16, 16), (32, 12, 32, 16), '(1.14, 1.1, 1.0, 1)')
    style('BtnDown_' + name, path, (16, 16, 16, 16), (32, 16, 32, 12), '(0.8, 0.78, 0.76, 1)')
    style('BtnDisabled_' + name, path, (16, 16, 16, 16), (32, 12, 32, 16), '(0.62, 0.62, 0.62, 0.85)')

style('Ribbon', K + 'adventure/button_red.png', (16, 16, 16, 16), (24, 4, 24, 8))
flat_bar('SliderTrack', '(0.43, 0.29, 0.15, 1)', '(0.25, 0.15, 0.07, 1)')
flat_bar('SliderFill', '(0.95, 0.64, 0.2, 1)', '(0.6, 0.33, 0.08, 1)')

add('[sub_resource type="StyleBoxFlat" id="Focus"]')
add('bg_color = Color(1, 1, 1, 0)')
for side in ('left', 'top', 'right', 'bottom'):
    add(f'border_width_{side} = 3')
add('border_color = Color(1, 0.8, 0.25, 1)')
for corner in ('top_left', 'top_right', 'bottom_right', 'bottom_left'):
    add(f'corner_radius_{corner} = 12')
for side in ('left', 'top', 'right', 'bottom'):
    add(f'expand_margin_{side} = 3')
add('')
add('[sub_resource type="StyleBoxLine" id="Line"]')
add('color = Color(0.45, 0.3, 0.15, 0.55)')
add('thickness = 3')
add('')

BROWN = '(0.28, 0.17, 0.08, 1)'
add('[resource]')
add('default_font = SubResource("Font_Body")')
add('default_font_size = 24')
add('')
add(f'Label/colors/font_color = Color{BROWN}')
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


label_variation('TitleLabel', 'Font_Title', 78, '(1, 0.93, 0.74, 1)', '(0.32, 0.17, 0.06, 1)', 14)
label_variation('HeaderLabel', 'Font_Button', 28, '(1, 1, 1, 1)', '(0.45, 0.1, 0.1, 1)', 6)
add('HeaderLabel/styles/normal = SubResource("Ribbon")')
add('')
label_variation('FloatLabel', 'Font_Bold', 28, '(1, 1, 1, 1)', '(0.06, 0.04, 0.03, 1)', 7)
label_variation('StatLabel', 'Font_Bold', 30, BROWN, '(0, 0, 0, 0)', 0)
label_variation('HintLabel', 'Font_Body', 22, '(0.5, 0.35, 0.2, 1)', '(0, 0, 0, 0)', 0)
label_variation('NumberLabel', 'Font_Button', 32, BROWN, '(0, 0, 0, 0)', 0)

add(f'Button/colors/font_color = Color{BROWN}')
add('Button/colors/font_hover_color = Color(0.42, 0.2, 0.04, 1)')
add('Button/colors/font_pressed_color = Color(0.2, 0.11, 0.04, 1)')
add('Button/colors/font_focus_color = Color(0.28, 0.17, 0.08, 1)')
add('Button/colors/font_disabled_color = Color(0.45, 0.4, 0.35, 1)')
add('Button/colors/font_outline_color = Color(0, 0, 0, 0)')
add('Button/constants/outline_size = 0')
add('Button/font_sizes/font_size = 28')
add('Button/fonts/font = SubResource("Font_Button")')
add('Button/styles/normal = SubResource("Btn_brown")')
add('Button/styles/hover = SubResource("BtnHover_brown")')
add('Button/styles/pressed = SubResource("BtnDown_brown")')
add('Button/styles/disabled = SubResource("BtnDisabled_brown")')
add('Button/styles/focus = SubResource("Focus")')
add('')
add('GreyButton/base_type = &"Button"')
add('GreyButton/styles/normal = SubResource("Btn_grey")')
add('GreyButton/styles/hover = SubResource("BtnHover_grey")')
add('GreyButton/styles/pressed = SubResource("BtnDown_grey")')
add('GreyButton/styles/disabled = SubResource("BtnDisabled_grey")')
add('')
add('RedButton/base_type = &"Button"')
add('RedButton/colors/font_color = Color(1, 1, 1, 1)')
add('RedButton/colors/font_hover_color = Color(1, 0.95, 0.8, 1)')
add('RedButton/colors/font_pressed_color = Color(0.95, 0.85, 0.85, 1)')
add('RedButton/colors/font_focus_color = Color(1, 1, 1, 1)')
add('RedButton/colors/font_outline_color = Color(0.45, 0.1, 0.1, 1)')
add('RedButton/constants/outline_size = 6')
add('RedButton/styles/normal = SubResource("Btn_red")')
add('RedButton/styles/hover = SubResource("BtnHover_red")')
add('RedButton/styles/pressed = SubResource("BtnDown_red")')
add('RedButton/styles/disabled = SubResource("BtnDisabled_red")')
add('')
add('PanelContainer/styles/panel = SubResource("Panel")')
add('HudPanel/base_type = &"PanelContainer"')
add('HudPanel/styles/panel = SubResource("HudPanel")')
add('CardPanel/base_type = &"PanelContainer"')
add('CardPanel/styles/panel = SubResource("Card")')
add('')
add('HSlider/styles/slider = SubResource("SliderTrack")')
add('HSlider/styles/grabber_area = SubResource("SliderFill")')
add('HSlider/styles/grabber_area_highlight = SubResource("SliderFill")')
add(f'HSlider/icons/grabber = ExtResource("{tex(K + "sliders/grabber.png")}")')
add(f'HSlider/icons/grabber_highlight = ExtResource("{tex(K + "sliders/grabber.png")}")')
add('')
add('HSeparator/styles/separator = SubResource("Line")')
add('HSeparator/constants/separation = 16')
add('VBoxContainer/constants/separation = 12')
add('HBoxContainer/constants/separation = 12')
add('GridContainer/constants/h_separation = 28')
add('GridContainer/constants/v_separation = 8')

WGHT = 2003265652  # the 'wght' axis tag
header = [f'[gd_resource type="Theme" load_steps={len(textures) + 14} format=3]', '',
          '[ext_resource type="FontFile" path="res://assets/fonts/Nunito-Variable.ttf" id="1_nunito"]',
          '[ext_resource type="FontFile" path="res://assets/fonts/Cinzel-Variable.ttf" id="2_cinzel"]']
for path, tid in textures.items():
    header.append(f'[ext_resource type="Texture2D" path="{path}" id="{tid}"]')
header.append('')
for fid, base, weight in (('Body', '1_nunito', 600), ('Bold', '1_nunito', 800),
                          ('Title', '2_cinzel', 800), ('Button', '2_cinzel', 700)):
    header.append(f'[sub_resource type="FontVariation" id="Font_{fid}"]')
    header.append(f'base_font = ExtResource("{base}")')
    header.append(f'variation_opentype = {{{WGHT}: {weight}}}')
    header.append('')

with open(os.path.join(UI, 'game_theme.tres'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(header + body) + '\n')
print('wrote hearts and game_theme.tres with %d Kenney textures' % len(textures))
