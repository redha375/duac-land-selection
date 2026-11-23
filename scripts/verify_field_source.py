#!/usr/bin/env python3
"""Static checks for the blank-field HTML source bundled in Android."""
from pathlib import Path
import re
import subprocess
import tempfile

html_path = Path('android/app/src/main/assets/www/index.html')
html = html_path.read_text(encoding='utf-8')
if 'iM=[]' not in html:
    raise SystemExit('blank data seed iM=[] not found')
if html.count('iM=[]') != 1:
    raise SystemExit('expected exactly one empty initial parcel collection')
if 'el_taamir_field_records_v230' not in html:
    raise SystemExit('Android local-record adapter/store key not found')
if 'window.fetch = ' not in html:
    raise SystemExit('local actions fetch adapter not found')
modules = re.findall(r'<script\s+type=["\']module["\'][^>]*>(.*?)</script>', html, re.S | re.I)
if len(modules) != 1:
    raise SystemExit(f'expected one app module, found {len(modules)}')
with tempfile.NamedTemporaryFile('w', suffix='.mjs', encoding='utf-8') as f:
    f.write(modules[0])
    f.flush()
    subprocess.run(['node', '--check', f.name], check=True)
print(f'PASS: blank seed, local persistence adapter and module syntax ({html_path.stat().st_size} bytes)')
