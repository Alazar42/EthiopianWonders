"""Downloads the game's fonts from Google Fonts (both SIL Open Font License) into assets/fonts.

    python tools/fetch_fonts.py

Cinzel (titles and buttons) is a classical engraved-capitals face that suits the adventure look;
Nunito (reading text) is a soft, very legible rounded sans. Both are variable fonts, so the theme
picks the weights it needs.
"""
import os
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
BASE = 'https://github.com/google/fonts/raw/main/ofl/'
FILES = {
    'cinzel/Cinzel%5Bwght%5D.ttf': 'Cinzel-Variable.ttf',
    'cinzel/OFL.txt': 'OFL-Cinzel.txt',
    'nunito/Nunito%5Bwght%5D.ttf': 'Nunito-Variable.ttf',
    'nunito/OFL.txt': 'OFL-Nunito.txt',
}

for source, name in FILES.items():
    destination = os.path.join(ROOT, 'assets', 'fonts', name)
    urllib.request.urlretrieve(BASE + source, destination)
    print('wrote', name, os.path.getsize(destination), 'bytes')
