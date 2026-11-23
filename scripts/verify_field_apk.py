#!/usr/bin/env python3
"""Verify APK package/version and provenance against an exact source tree."""
import argparse
import hashlib
import json
import os
import subprocess
import zipfile
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--apk', required=True)
p.add_argument('--source', default='android/app/src/main/assets/www/index.html')
p.add_argument('--commit', required=True)
p.add_argument('--tag', required=True)
p.add_argument('--version', default='2.3.0-field-blank-beta')
a = p.parse_args()
apk = Path(a.apk)
source_hash = hashlib.sha256(Path(a.source).read_bytes()).hexdigest()
with zipfile.ZipFile(apk) as z:
    info = json.loads(z.read('assets/build-info.json'))
    embedded_html = z.read('assets/www/index.html')
assert info['applicationId'] == 'dz.medea.parcel.fieldbeta230', info
assert info['versionCode'] == 3, info
assert info['versionName'] == a.version, info
assert info['sourceCommit'] == a.commit, info
assert info['releaseTag'] == a.tag, info
assert info['sourceHtmlSha256'] == source_hash, (info['sourceHtmlSha256'], source_hash)
assert hashlib.sha256(embedded_html).hexdigest() == source_hash, 'APK HTML differs from source tree'
aapt = None
sdk = Path(os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT') or '/home/user/.android-sdk')
for candidate in [*sdk.glob('build-tools/*/aapt')]:
    if candidate.is_file():
        aapt = str(candidate)
        break
if aapt is None:
    raise SystemExit('Android SDK aapt tool not found')
badging = subprocess.check_output([aapt, 'dump', 'badging', str(apk)], text=True)
expected = f"package: name='dz.medea.parcel.fieldbeta230' versionCode='3' versionName='{a.version}'"
assert expected in badging, badging.splitlines()[0]
print(json.dumps({**info, 'apkSha256': hashlib.sha256(apk.read_bytes()).hexdigest()}, indent=2))
print('PASS: APK package, version, source HTML hash and embedded provenance match')
