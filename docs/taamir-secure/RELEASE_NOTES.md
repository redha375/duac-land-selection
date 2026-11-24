# El Taamir secure beta 3.3.0

- Preserved the existing blank Android field beta 2.3.0 tag and release.
- Added a separate authenticated web app under `/taamir-secure/`.
- Added server-enforced manager / agent / monitor permissions using Supabase RLS.
- New signups are inactive until an existing manager explicitly activates a role.
- Made the PDF bucket private; reads require an active team membership, uploads require manager/agent.
- Removed demo-role login and local client-side role defaults; team records are not cached in browser local storage.
- No project credentials, user email lists, APK or live Supabase configuration are included.

This release is source-only. A dedicated Supabase project must be created and the included SQL run by its owner. This repository has no Supabase credentials, so no live backend migration or real-account role test was performed. This is a web/PWA build, not an APK.
