# Continuous startup and generator owner subscriptions

Branch: `fix/splash-and-owner-switch`, based on `feature/multi-generator` (`32d89f1`).

## Causes and changes

Previously native startup was allowed to finish before Firebase restored the user and loaded the profile/generator. The router then rendered a separate Flutter loading view with its own spinner and layout. Signing in immediately redirected through that view again while profile lookup completed.

- Preserve the native splash before Firebase and notification initialization. Remove it exactly once, after a destination frame exists and auth/profile/tenant access have settled. Initialization errors explicitly release it and render the existing themed error presentation.
- Read the Firestore SDK's local profile cache for the exact authenticated UID first. Never persist or reuse a role across UIDs. Cache misses wait for the normal lookup; live profile and generator snapshots continue validation and revocation. The cache is a routing hint, never authorization: existing Firestore rules remain authoritative.
- Keep the existing login/OTP form for a bounded 800 ms while its result resolves. Fast successful sign-in lands directly on the role's destination; slow resolution uses the fallback. Cold starts always remain behind the preserved native splash.
- Native light/dark/pre-12 and Flutter fallback all use `#13262A` and the same approved transparent 1152 px mark canvas, displayed at 288 dp. No fallback indicator for its first 800 ms; subsequently a small 48 × 2 dp line appears without moving the logo. Regenerated Android and iOS splash resources; moved the existing splash package from dev to runtime dependencies for its preserve/remove API (no version change).

The former primary super-admin body only showed pending owner users, so approval removed an owner from that view. The generator management view already streamed all generators but had no search/filter, no owner name and changed subscriptions immediately without confirmation.

- The primary “أصحاب المولدات” body now uses the complete generator management list, including pending/approved/rejected/suspended entries. The original management route remains reachable. Each record shows generator name, sector, private owner name, review state, explicit subscription state and switch; search by generator name/sector and status filter are included.
- Confirm or cancel subscription changes. A transaction updates only the private generator subscription and its four-field public directory projection, preserving approval/rejection/suspension and its reason. Review/approval now also uses a transaction to avoid stale directory projections during simultaneous subscription changes.
- Existing tenant-access and approved+active directory streams already enforce owner access and live picker visibility. Tests now prove the management switch drives those existing streams, including the mounted consumer picker in both themes. No console operation is required for registered owner approval.
- Owner names are read from private `users/{ownerUid}.name`, never copied to the directory. Assumption: valid registrations follow the existing one-owner/one-generator linked data model; old incomplete/unmigrated accounts still require the documented multi-generator migration. If the recorded name is the generator name, the UI displays the recorded value rather than inventing a personal name.
- Demo-login implementation, Firestore schema/rules, sign-in methods and existing destinations are unchanged. Existing debug diagnostic/logout controls and demo presentation remain reachable.

## Validation

- 112 Flutter tests passed, including all existing suites and updated super-admin goldens.
- New checks: native release is destination-dependent and idempotent; cold startup waits through profile AND generator resolution; fast sign-in skips Flutter loading for all three roles; fixed centered logo and 800 ms indicator delay; slow-login grace/fallback without re-preserving native splash; UID-bound cache lookup; confirmed/cancelled subscription writes; transaction preserves review state; public projection contains no owner data; live mounted picker removal/restoration in light/dark; search/status filter; inactive owner access gate; non-super-admin mutation refusal.
- 19 Firestore emulator rule tests passed with project `demo-generator-portal`. No production Firebase reads/writes, rule deployment or migration.
- Analyzer: 0 errors, the same 17 pre-existing warnings and 20 infos as the base branch, no new diagnostics (compared by severity/message/file/code, ignoring shifted line numbers). Logs: `docs/validation/splash-owner-*`.
- `flutter build apk --debug --no-pub` succeeded; existing Android SDK XML version warning remains.
- Reproducible asset proof: `PYTHONPATH=/workspace/toolchains/splash-python python tool/validate_continuous_splash.py`. `docs/validation/continuous-splash-mask.png` / `.json`: zero cropped alpha pixels, maximum alpha radius 374.412 px < 384 px safe radius; Android density outputs validated at 288/432/576/864/1152 px.

## Limits

No Android device/emulator is available. OS splash retention/exit animations, OEM mask/centering behavior, perceived transition smoothness, real Firebase disk-cache latency and SMS login have not been verified on hardware. The mask proof is an asset/render check, not a device screenshot. Fake Firestore verifies data/routing behavior but does not simulate native persistent disk-cache or real network timing. iOS resources were regenerated but no iOS build/device test was possible. This branch does not publish or upload an APK/release.
