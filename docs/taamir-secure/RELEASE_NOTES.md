# El Taamir secure beta 3.4.0

- Kept the blank Android field beta 2.3.0 tag and release unchanged.
- Restricted user/role administration to one explicitly bootstrapped owner identity in Supabase; data managers cannot promote themselves or manage accounts.
- Added an owner-only Supabase Edge Function to send user invitations without exposing the service-role key in the browser.
- Added an invitation panel; invited users start as inactive monitors and require owner role assignment and activation after accepting.
- Preserved server-enforced manager / agent / monitor data permissions, private PDF storage, and no client-side authorization role.
- Added a guarded owner-bootstrap SQL template, secure setup/deployment instructions, and static checks for the owner and invite authorization paths.

This is a source-only web/PWA update, not an APK. The dedicated Supabase migration and Edge Function must be deployed by the project owner; no live project configuration or real-account invitation was performed or tested.
