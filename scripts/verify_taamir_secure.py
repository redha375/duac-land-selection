#!/usr/bin/env python3
"""Static guardrails for the El Taamir secure web beta."""
from pathlib import Path
import re, subprocess, tempfile

root = Path(__file__).resolve().parents[1]
app = root / 'docs/taamir-secure/index.html'
sql = root / 'docs/taamir-secure/supabase-secure.sql'
html = app.read_text(encoding='utf-8')
db = sql.read_text(encoding='utf-8').lower()
assert 'demoLogin' not in html and 'demoRole' not in html
assert not re.search(r"CURRENT_ROLE\s*=\s*localStorage", html)
assert 'duac_v3' not in html and 'persistLocal' not in html
assert "select('role,active')" in html
assert "rpc('set_member_access'" in html
assert 'createSignedUrl(path,300)' in html
assert "document.querySelectorAll('form button:not([type]), form button[type=submit]')" in html
assert "delete_manager" in db and "= ''manager''" in db
assert "from(key).upsert({id:record.id,data:record" in html
assert 'syncToSupa' not in html
assert not re.search(r"create\s+policy\s+['\"]?allow all", db)
assert "active boolean not null default false" in db
assert "coalesce((select public.current_app_role()),'') <> 'manager'" in db
assert "current_app_role()) in (''manager'',''agent'',''monitor'')" in db
assert "current_app_role()) in (''manager'',''agent'')" in db
assert "= ''manager''" in db  # manager-only SQL RLS deletion
assert 'public=false' in db and 'create_signed_url' not in db
assert 'revoke all on public.profiles from public, anon, authenticated' in db
assert "revoke all on public.%i from public, anon" in db
assert not re.search(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}', html + db)
assert not re.search(r"service_role\s*[:=]\s*['\"]?eyJ", html, re.I)
js = re.findall(r'<script(?:\s[^>]*)?>(.*?)</script>', html, re.S)[-1]
with tempfile.NamedTemporaryFile('w', suffix='.js', encoding='utf-8') as f:
    f.write(js); f.flush()
    subprocess.run(['node', '--check', f.name], check=True)
print('secure app static guardrails and JavaScript syntax: PASS')
