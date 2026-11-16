# Free-tier Phase 1

Base: fix/auto-load-and-dual-login (307ce49). Branch: feature/spark-email-phase1.

Scope correction: clean Firebase project, test accounts only. No legacy migration code, production operations or data deletion. Replace old auth completely. Phase 2 (reports, audit, backups, offline indicators, dated subscriptions, notification changes and general UI review) is explicitly deferred.

Stages:
1. Real email/password registration, verified email gate and email reset; contact-only phone/ID. Delete OTP/ID login and demo bypass. Document manual Firebase setup.
2. Compact payment declaration (amount/date/reference/method), owner approve/reject transaction and duplicate approval prevention. No new images, Storage, Functions or billing.
3. Owner/consumer pending/rejected/suspended status and reasons; tenant security and emulator coverage. Keep existing automatic data loading and identity.
4. Unit/widget/emulator checks, Android build, push this branch only, STOP for phone testing.

Verified real email is required by Firestore rules, not only the router. Role/status/generatorId/subscription remain protected. Signed-out legacy test accounts are outside this clean-project scope; no password/OTP migration fallback is shipped.

## Implemented behavior

- Registration/login use real email + password. Verification is required before onboarding and data access. The verification screen supports resend (60-second client cooldown), refresh after opening the mail link, and sign-out. Password reset uses the built-in Firebase email action handler with generic account-existence wording.
- Phone and optional national ID are private profile/contact strings, not authentication methods. Old OTP/ID routes, SDK calls, synthetic email creation, demo auth methods/flags and image-picker dependencies were removed. No legacy migration screen or tool was added. Old test-only accounts using removed methods are not supported in this clean-project phase.
- Owners register pending generators. Super-admin reviews pending/rejected/suspended owners with reasons. Verified consumers pick only approved, active generators and remain pending until the owner approves. Rejected consumer requests stay in the owner's request inbox for reconsideration; suspended subscribers remain visible for reactivation. Rejection/suspension reasons are displayed to the account holder.
- A bill accepts one full-balance payment declaration: integer minor-currency amount, calendar payment date, reference (1–80 characters) and method (`cash`, `bank`, `wallet`, `other`). Date-only values are stored at UTC midnight to preserve the chosen calendar date across device timezones. No payment gateway or bank verification is implied.
- Submission and review use online Firestore transactions. A repeated identical submission/decision is idempotent. In a concurrent review race the late request may receive a permission-denied/already-processed error; exactly one decision and feedback record remain. Rejection requires a reason; a correction increments the declaration version. An old review dialog cannot approve a new version. A paid bill cannot be resubmitted or reversed by the review action. Existing in-app payment-result feedback is written once in the same review transaction; notification transport was not redesigned.
- Rules enforce verified real email, bounded fields, fixed membership/role/approval restrictions, tenant-scoped reads/writes, valid payment fields and version, reviewer UID and legal state transitions. The private old ID lookup collection has no new read/write permission. No credentials are stored in Firestore.
- Existing automatic loading/retry and native splash behavior are retained. Existing Arabic identity, RTL and light/dark themes are used for the new forms.

## Every manual Firebase step (not executed here)

1. **Choose a clean test project on Spark.** Confirm the Firebase console shows Spark, leave billing disabled and do not attach a billing account/card. This phase assumes no production users. No existing project/account/data was deleted by this work.
2. **Authentication → Sign-in method:** enable **Email/Password**. Disable **Phone** and other unused providers. Email-link sign-in is not used. Keep account-enumeration protection enabled where available; login/reset errors remain generic.
3. **Authentication → Templates:** configure the application/sender display name and review verification/password-reset templates. The default Firebase hosted email action handler works without custom hosting or Cloud Functions. Use an inbox you can actually open, check spam, and return to the app to press “تحققت من البريد”. Actual mail delivery was not tested by local emulators.
4. **Android configuration:** register the exact application ID `com.example.power_share`, obtain your project's `google-services.json` and place it locally in `android/app/`. Do not commit it or local `android/gradle.properties`. Keep Google Services package/project values consistent. For non-Android targets, review `lib/config/app_config.dart` for the same project; Android initializes from its native app configuration. No SMS SHA/Play Integrity flow is required by the new email login.
5. **Create Firestore if needed and deploy the matching rules/indexes to the test project manually.** Repository `firebase.json` references `firestore.rules` and `firestore.indexes.json`. Example command, for the operator only:

   ```bash
   firebase deploy --only firestore:rules,firestore:indexes --project YOUR_TEST_PROJECT_ID
   ```

   Do not deploy emulator configuration. No new composite indexes were introduced for payment records. Old rules requiring a verified phone are incompatible with this branch; use this branch's rules before testing registration.
6. **Bootstrap the super-admin manually; no client seeding exists.** Register a real email account and verify it. Before submitting an ordinary owner/consumer application, copy its UID from Authentication and create `users/{UID}` in the console with exactly: `role: "super_admin"`, `status: "approved"`, `subscriptionStatus: "active"`, `name` (your name), `email` (same verified address), `phone: ""`, `idNumber: ""`, `credentialVersion: 2`, `ampereLimit: 0`, `createdAt` as a current epoch-millisecond number. Omit `generatorId` for this role. Refresh/reopen the app. Do not distribute that account's password or allow clients to assign this role.
7. **Device test:** create a separate owner using email/password, verify its email, submit the generator name/sector. Approve it from super-admin. Create a separate consumer, verify email, choose that generator and have its owner approve it. Keep roles on separate accounts. No console edits are needed for normal owner/consumer approvals.
8. **Payment test:** issue a bill, submit its full amount/date/reference/method as the consumer, review as owner, reject with reason and resubmit, then approve. Repeated approval must leave one final decision/feedback record. Exercise owner/consumer rejection and suspension; the account holder must see the reason and lose operational access while blocked.
9. **Build/run locally:** `flutter pub get`, `flutter run -d YOUR_ANDROID_DEVICE` or `flutter build apk --debug`. A debug build does not deploy Firebase rules or enable providers. No APK release/store publication is performed by pushing this branch.
10. **Watch free quotas in the console.** Spark/Auth email quotas, Firestore daily reads/writes and storage limits are finite. Exhaustion may block service; unlimited free operation is not promised. The app does not enable billing, Storage, Functions, paid hosting or SMS. No plan upgrade is needed by the implemented flow.

## Local validation and phone checklist

- Cloud Linux: `PORTAL_TEST_TARGET=test ./tool/test_visual.sh` (fixed clock for golden comparisons). Ordinary `flutter test` includes time-dependent golden files, so use the provided clock wrapper for the complete screenshot suite.
- Local Auth/Firestore emulators: `python tool/run_spark_emulators.py` in the provided cloud toolchain. It hardcodes local ports and project `demo-generator-portal`, rejects production endpoints and suppresses test action-link echo. Portable equivalent after `npm ci --prefix tools/rules-tests`:

  ```bash
  npx --prefix tools/rules-tests firebase emulators:exec --project demo-generator-portal --config firebase.auth-test.json --only auth,firestore "node --test tools/rules-tests/auth.test.mjs tools/rules-tests/rules.test.mjs"
  ```

- On a phone, check real verification/reset mail links, reopening an existing verified session, password errors, switching accounts, keyboard reachability, payment date/reference/method, two concurrent review windows, and denial of cross-generator data. Android hardware/email deliverability are not proven by emulator or widget tests.

## Explicitly deferred — Phase 2 not started

No reports/CSV/PDF export, general audit log, backup/restore/migration tools, offline-sync indicators, owner subscription dates, notification redesign or general UI review. Existing historical migration/dual-login documents in the repository do not describe this clean-project setup. Use this document as the current setup authority.

## Validation results

137 Flutter tests passed, including email auth, compact payments, keyboard reachability and existing golden/navigation tests. All 17 local Auth/Firestore emulator tests passed, including concurrent review (one decision and one feedback record). Android debug APK built successfully. Analyzer: 0 errors, 14 existing warnings and 18 existing infos; comparison by diagnostic message/file/code against base `307ce49` found no new diagnostics. See `docs/validation/spark-phase1-validation.json` and adjacent logs. No Android device/emulator hardware test or real email delivery test was possible here. No Firebase deployment or production operation was performed.
