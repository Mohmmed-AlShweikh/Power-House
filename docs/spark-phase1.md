# Free-tier Phase 1

Base: fix/auto-load-and-dual-login (307ce49). Branch: feature/spark-email-phase1.

Scope correction: clean Firebase project, test accounts only. No legacy migration code, production operations or data deletion. Replace old auth completely. Phase 2 (reports, audit, backups, offline indicators, dated subscriptions, notification changes and general UI review) is explicitly deferred.

Stages:
1. Real email/password registration, verified email gate and email reset; contact-only phone/ID. Delete OTP/ID login and demo bypass. Document manual Firebase setup.
2. Compact payment declaration (amount/date/reference/method), owner approve/reject transaction and duplicate approval prevention. No new images, Storage, Functions or billing.
3. Owner/consumer pending/rejected/suspended status and reasons; tenant security and emulator coverage. Keep existing automatic data loading and identity.
4. Unit/widget/emulator checks, Android build, push this branch only, STOP for phone testing.

Verified real email is required by Firestore rules, not only the router. Role/status/generatorId/subscription remain protected. Signed-out legacy test accounts are outside this clean-project scope; no password/OTP migration fallback is shipped.
