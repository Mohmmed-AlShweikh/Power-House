> Historical document. For the clean-project email-only Phase 1, follow [spark-phase1.md](spark-phase1.md). Do not run legacy account/data migration for this phase.

# Dual login — audit and implementation plan

Base: `fix/splash-and-owner-switch`; work only on `fix/auto-load-and-dual-login`.

## Current behavior found before coding

- ID login derives `<id>@powershare.app` and calls Firebase Email/Password. Phone entry signs in independently via OTP; no credential linking, no ID uniqueness index, and phone enrollment collects only name/sector/generator.
- The router waits for auth/profile/tenant but Firestore directory and some document providers do not watch auth readiness. A failed listener can remain failed across sign-in. Two list providers silently turn permission-denied into empty data. Direct alert listeners are outside the provider lifecycle.
- Forgot password displays an instruction to contact the owner; it does not reset Firebase Auth. The owner reset helper writes a plaintext password field to Firestore (this will be removed, never migrated/copied).
- Consumer password change uses current email/password; profile phone edits directly modify Firestore without verifying the new number. Owner profile has no shared credential management.

## Plan (recorded before implementation)

1. Centralize authenticated Firestore subscriptions: watch UID/profile/role/tenant readiness, recreate subscriptions when these change, retry only permission-denied/unavailable at most twice with short cancellable backoff. Audit all loading providers and direct listeners; remove silent permission swallowing.
2. Add shared password validation, throttling, generic auth errors and an injectable credential service. Use the existing canonical synthetic email namespace for new and existing IDs (the final compatibility decision is below).
3. Phone-first registration links Email/Password to the current UID, then atomically writes the unique ID claim with the profile. ID-first accounts verify/link phone on the same UID. Require missing-method completion once after login for consumer/owner accounts; exempt super-admin and unchanged demo login.
4. Add OTP password recovery and shared account credential management for consumer/owner profiles, with explicit reauthentication, consistent ID claims and no password/OTP logging or Firestore storage.
5. Harden rules for private idIndex ownership, atomic index/profile changes, verified phone and recent auth; exercise emulator-only allow/deny cases. Auth and Firestore cannot share a transaction: document partial-failure recovery and server project limitations (especially synthetic-email changes).
6. Add unit/widget/fake-service and emulator tests, run the existing suite and analyzer, document manual enabling/deployment/migration steps. No production Firebase operations; never commit google-services.json or android/gradle.properties.

The original pre-code plan is recorded in commit `8e98449`; implementation details and validation follow.

## Implemented design and final decisions

**Canonical ID email is `<id>@powershare.app`, the application's existing namespace.** A second-domain option was rejected after auditing compatibility: two synthetic namespaces could create two Auth accounts for the same national ID. New registrations and existing ID accounts now share one namespace/UID. These addresses are login identifiers, not mailboxes; no recovery emails are sent to them. IDs are 9–10 ASCII digits, stored as strings (including leading zeros).

- Phone-first: verified OTP → same registration flow collects ID/password/confirmation → link Email/Password to that exact UID → create pending tenant profile **and** `idIndex/{id}` in the same Firestore batch (and generator for owners).
- ID-first: create Email/Password UID → verify/link phone on that UID → existing generator/consumer registration. Interrupted email-only registration resumes phone completion after the next login, without creating a new UID.
- Returning consumers/owners missing a method or `credentialVersion: 1` go to one-time completion before the normal pending/home destination. Existing methods are retained; no automatic merging of different UIDs. Super-admin and the existing demo-login implementation are exempt from completion. Already-linked users do not need OTP on every ID/password login: the two methods are alternatives, not mandatory two-factor login.
- Completion also detects an Auth alias/phone ahead of its Firestore profile and lets the authenticated user repair the same UID. Canonical email is the suggested ID when resuming a partial ID change.
- Profiles expose shared “إعدادات الدخول”: consumer via “تعديل البيانات” → “الهاتف والهوية وكلمة المرور”; owner directly from profile. Ordinary edit sheets retain name/address editing; phone is read-only there. Credential changes require current-password or registered-phone OTP reauthentication; changing the phone additionally verifies the new number. Each service operation and the identity/phone rules enforce recent authentication (5 minutes); `requires-recent-login` is handled in Arabic.
- Forgot password: ID + registered phone → phone OTP sign-in → read **only that UID's own server profile** and compare ID + verified registered phone → generic mismatch error and sign-out → new-password step with live rules → Firebase Auth update/link → sign-out → login success notice. Identity is checked again at submission, not just trusted from UI state. Unknown phones may create an empty Auth account because Firebase phone sign-in itself does that; mismatch does not create a Firestore profile or delete any account/data.
- Password validation is shared: >=8 characters, at least one Unicode letter and ASCII digit, not ID/phone, confirmation equal. Passwords/OTPs are never written to Firestore, preferences or logs. The legacy owner plaintext-reset helper now returns self-service recovery guidance and cannot write a password. Existing historical plaintext fields, if any, are **not deleted** by this work.
- Session-wide client throttling: >=60 seconds between OTP sends, 5 failed attempts trigger a 60-second pause, plus Firebase's own limits. Generic login/duplicate/recovery errors do not enumerate IDs/accounts. Expired/invalid OTP, too many requests, network and recent-login failures have Arabic messages.
- Android instant verification and manual OTP both dispatch by the intended operation (sign-in/link/reauth/change), retain UID when linking, and cancel callbacks when the form is disposed. A link callback never falls back to signing into somebody else's account if the credential belongs to another UID.

## Data and security

`users/{uid}` adds `idNumber` (string) and `credentialVersion: 1` after both methods are established. Role/status/generatorId/subscription remain server-rule protected. `idIndex/{nationalId}` contains **only** `{uid}`. No phone-by-ID, ID-by-phone or public profile lookup is added. Index reads are limited to its owner/the authenticated account's own identity and super-admin; collection listing is super-admin only. An absent claim can be checked only by the corresponding authenticated canonical email.

Profile/index creation or ID swap is atomic in Firestore. Swaps release the old claim in the same transaction; claims cannot be reassigned, even by a super-admin client. Rules verify canonical Auth email, verified Auth phone, recent authentication, index/profile linkage, allowed fields and unchanged membership. Plaintext password writes are denied even to super-admin clients. Trusted Admin SDK migration bypasses client rules and must perform its own duplicate checks.

Firebase Auth and Firestore **cannot** share an atomic commit. If an ID alias changes but the Firestore transaction fails, the service attempts to restore the previous Auth alias. If that fails (e.g. network), phone sign-in and completion repair the same UID. No UID is deleted or silently merged. Stop and resolve conflicting old UIDs administratively; never transfer another UID's index claim from a client.

## Manual rollout/migration — not executed

1. Back up **both** Firebase Auth and all Firestore collections before deploying. Keep backups outside this public repository. Auth export: `firebase auth:export PRIVATE_BACKUP/auth.json --project YOUR_PROJECT`. For Firestore use the console's managed export to a private backup bucket if available, or a trusted Admin SDK read/export appropriate to your plan. Backups/password hashes are sensitive; never commit them.
2. Audit legacy `users` IDs as strings and their canonical Auth emails/UIDs. Resolve duplicate national IDs and independently-created phone/email UIDs with the account owners before rollout. **Backfill private `idIndex/{id} = {uid}` for existing valid IDs before enabling new registrations**, using a trusted Admin SDK batch together with the matching existing profile. Abort on any conflicting claim; do not overwrite/move somebody else's claim. No production migration or account deletion is included/executed here.
3. Retain existing Auth emails, UIDs, generator assignments, role/status and approval. Do not set `credentialVersion: 1` merely because a profile contains a phone: inspect linked Auth providers/verified Auth phone. Leave the version missing for one-time completion on the next legitimate login. Phone-only users without a recorded ID supply it during completion; an unregistered/missing ID cannot be recovered through the ID+phone screen until completion.
4. Firebase Console → Authentication → Sign-in method: enable **Email/Password and Phone**. Keep Android app/SHA signing registrations, phone regions and SMS quotas correct. Do not configure synthetic email addresses for email-reset mail. No new Firestore composite index is needed (ID access is a document lookup; existing directory/scoped queries are retained).
5. Deploy reviewed `firestore.rules` to the intended project manually, then distribute the matching app after backup/backfill. Example (manual only): `firebase deploy --only firestore:rules --project YOUR_PROJECT`. Never use the emulator configuration as a production deployment configuration. No Cloud Functions/Blaze dependency was added.
6. **ID edits need project-policy verification:** synthetic addresses have no inbox, so the app uses Firebase's direct `updateEmail` after recent reauthentication. Projects that enforce verify-before-update / email-enumeration protection may reject this API. Do not weaken that protection merely for this app; those projects require a trusted Admin SDK backend for the ID-alias update. That backend is **not included** here. The client reports failure and preserves/repairs the same UID; no security bypass is attempted.
7. If historical plaintext `password` fields exist, review their cleanup separately after backup and explicit authorization. This task blocks new writes but intentionally does not delete existing data.

## Verification and limits

- Flutter unit/widget suites cover shared password/throttle errors, same UID linking and ID login, duplicate claims, atomic swaps and rollback, recent-auth refusal, mismatch sign-out, successful password reset, one-time completion/partial-update repair, both themes' recovery/completion/ID-first UI, existing navigation/splash/keyboard/goldens and automatic read recovery.
- Local emulator command: `python tool/run_dual_login_emulators.py`. It hardcodes project `demo-generator-portal`, local Auth 9099 / Firestore 8089 and suppresses the CLI's automatic fake SMS echo. REST Auth checks prove phone-first and ID-first UID retention, collision refusal and password reset; Firestore allow/deny tests cover index/profile atomicity, privacy, duplicates, stale auth, verified phone and plaintext denial. No production fallback.
- Android/SMS delivery, Play Integrity/instant-verification behavior on real hardware, real disk cache/network races and this production project's direct-email-update policy cannot be verified without a device/production access. Emulator Auth API tests do not replace native Android testing. No production Firebase data, deployment, main branch, PR or APK release was touched.


## Final local results

139 Flutter tests passed (including all pre-existing suites), 27 Auth/Firestore emulator tests passed, and Android debug APK build succeeded. Analyzer: **0 errors, 17 pre-existing warnings, 19 pre-existing infos**, no new diagnostics; compared with base `2425204` by severity/message/file/code, ignoring shifted line numbers. Full changed-file manifest: `docs/validation/dual-login-files.txt`. Related login/profile/recovery goldens were updated; stack-trace line-number changes in existing error goldens were also regenerated. Evidence: `docs/validation/dual-login-*`.

No new package dependencies, translations, Firestore indexes, deployment or main-branch changes. Neither `google-services.json` nor `android/gradle.properties` is changed or staged.
