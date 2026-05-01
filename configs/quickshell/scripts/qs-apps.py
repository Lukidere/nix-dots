#!/usr/bin/env python3
import os, json, glob

CATEGORY_MAP = {
    'Network': 'Internet', 'WebBrowser': 'Internet', 'Email': 'Internet',
    'InstantMessaging': 'Internet', 'Chat': 'Internet', 'Feed': 'Internet',
    'Development': 'Dev', 'IDE': 'Dev', 'Debugger': 'Dev', 'Building': 'Dev',
    'TextEditor': 'Dev', 'WebDevelopment': 'Dev', 'Profiling': 'Dev',
    'Audio': 'Media', 'Video': 'Media', 'Music': 'Media', 'Player': 'Media',
    'Recorder': 'Media', 'TV': 'Media', 'AudioVideo': 'Media',
    'Game': 'Games', 'Games': 'Games', 'ArcadeGame': 'Games',
    'BoardGame': 'Games', 'CardGame': 'Games', 'LogicGame': 'Games',
    'System': 'System', 'Settings': 'System', 'Monitor': 'System',
    'Utility': 'System', 'FileManager': 'System', 'TerminalEmulator': 'System',
    'PackageManager': 'System',
    'Office': 'Office', 'WordProcessor': 'Office', 'Spreadsheet': 'Office',
    'Presentation': 'Office', 'Calendar': 'Office', 'ProjectManagement': 'Office',
}

DIRS = [
    '/run/current-system/sw/share/applications',
    '/usr/share/applications',
    '/usr/local/share/applications',
    os.path.expanduser('~/.local/share/applications'),
    os.path.expanduser('~/.nix-profile/share/applications'),
    '/var/lib/flatpak/exports/share/applications',
    os.path.expanduser('~/.local/share/flatpak/exports/share/applications'),
]

for d in glob.glob('/etc/profiles/per-user/*/share/applications'):
    DIRS.append(d)

# Icon resolution
ICON_DIRS = [
    '/run/current-system/sw/share/icons/hicolor',
    os.path.expanduser('~/.local/share/icons/hicolor'),
    '/usr/share/icons/hicolor',
]
PIXMAP_DIRS = [
    '/run/current-system/sw/share/pixmaps',
    '/usr/share/pixmaps',
]
PREFERRED_SIZES = ['48x48', '64x64', '128x128', '32x32', '256x256', '24x24', 'scalable']
ICON_EXTS = ['.png', '.svg', '.xpm']

_icon_cache = {}

def resolve_icon(name):
    if not name:
        return ''
    if '/' in name and os.path.isfile(name):
        return name
    if name in _icon_cache:
        return _icon_cache[name]

    # Search hicolor theme directories
    for icon_dir in ICON_DIRS:
        for size in PREFERRED_SIZES:
            for category in ['apps', 'mimetypes', 'status', 'devices', 'actions']:
                for ext in ICON_EXTS:
                    path = os.path.join(icon_dir, size, category, name + ext)
                    if os.path.isfile(path):
                        _icon_cache[name] = path
                        return path

    # Search pixmaps
    for pdir in PIXMAP_DIRS:
        for ext in ICON_EXTS:
            path = os.path.join(pdir, name + ext)
            if os.path.isfile(path):
                _icon_cache[name] = path
                return path

    _icon_cache[name] = ''
    return ''


apps = []
seen = set()

for d in DIRS:
    if not os.path.isdir(d):
        continue
    for path in glob.glob(os.path.join(d, '*.desktop')):
        try:
            data = {}
            with open(path, encoding='utf-8', errors='replace') as f:
                in_section = False
                for line in f:
                    line = line.strip()
                    if line == '[Desktop Entry]':
                        in_section = True
                    elif line.startswith('['):
                        in_section = False
                    elif in_section and '=' in line:
                        k, _, v = line.partition('=')
                        data[k.strip()] = v.strip()

            if data.get('Type') != 'Application':
                continue
            if data.get('NoDisplay', '').lower() == 'true':
                continue
            if data.get('Hidden', '').lower() == 'true':
                continue

            name = data.get('Name', '')
            if not name:
                continue
            desktop_id = os.path.basename(path)
            if desktop_id in seen:
                continue
            seen.add(desktop_id)

            raw_cats = [c.strip() for c in data.get('Categories', '').split(';') if c.strip()]
            mapped = list({CATEGORY_MAP[c] for c in raw_cats if c in CATEGORY_MAP})

            icon_name = data.get('Icon', '')
            icon_path = resolve_icon(icon_name)

            apps.append({
                'n': name,
                'g': data.get('GenericName', ''),
                'i': icon_path,
                'e': data.get('Exec', ''),
                'd': desktop_id,
                'c': mapped,
            })
        except Exception:
            pass

apps.sort(key=lambda a: a['n'].lower())
print(json.dumps(apps))
