# Dual login — audit and implementation plan

Base: `fix/splash-and-owner-switch`; work only on `fix/auto-load-and-dual-login`.

## Current behavior found before coding

- ID login derives `<id>@powershare.app` and calls Firebase Email/Password. Phone entry signs in independently via OTP; no credential linking, no ID uniqueness index, and phone enrollment collects only name/sector/generator.
- The router waits for auth/profile/tenant but Firestore directory and some document providers do not watch auth readiness. A failed listener can remain failed across sign-in. Two list providers silently turn permission-denied into empty data. Direct alert listeners are outside the provider lifecycle.
- Forgot password displays an instruction to contact the owner; it does not reset Firebase Auth. The owner reset helper writes a plaintext password field to Firestore (this will be removed, never migrated/copied).
- Consumer password change uses current email/password; profile phone edits directly modify Firestore without verifying the new number. Owner profile has no shared credential management.

## Plan (recorded before implementation)

1. Centralize authenticated Firestore subscriptions: watch UID/profile/role/tenant readiness, recreate subscriptions when these change, retry only permission-denied/unavailable at most twice with short cancellable backoff. Audit all loading providers and direct listeners; remove silent permission swallowing.
2. Add shared password validation, throttling, generic auth errors and an injectable credential service. New IDs use `<id>@id.generatorportal.app`; retain legacy synthetic email sign-in for existing accounts/super-admin.
3. Phone-first registration links Email/Password to the current UID, then atomically writes the unique ID claim with the profile. ID-first accounts verify/link phone on the same UID. Require missing-method completion once after login for consumer/owner accounts; exempt super-admin and unchanged demo login.
4. Add OTP password recovery and shared account credential management for consumer/owner profiles, with explicit reauthentication, consistent ID claims and no password/OTP logging or Firestore storage.
5. Harden rules for private idIndex ownership, atomic index/profile changes, verified phone and recent auth; exercise emulator-only allow/deny cases. Auth and Firestore cannot share a transaction: document partial-failure recovery and server project limitations (especially synthetic-email changes).
6. Add unit/widget/fake-service and emulator tests, run the existing suite and analyzer, document manual enabling/deployment/migration steps. No production Firebase operations; never commit google-services.json or android/gradle.properties.

Implementation details, validation and limitations will be appended below.
