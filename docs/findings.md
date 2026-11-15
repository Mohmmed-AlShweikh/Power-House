# Existing findings — unchanged by the visual redesign

Source review only. These are separate follow-up tasks, not permission to change functionality. No production account creation, credential use or Firestore writes were performed during the audit. Do not copy embedded credentials into this document.

| Finding | Source / evidence | Consequence and follow-up |
| --- | --- | --- |
| Client seeds a privileged account using embedded credentials | `lib/providers/auth_provider.dart`, `_seedSuperAdmin` | Privileged account provisioning is shipped in the client. Review separately; credentials deliberately not reproduced here. |
| Demo auth exists | `AuthNotifier.demoLogin`, `demoModeProvider`, router demo branch | Router can treat demo state as logged in; actual current LoginScreen calls normal login and does not expose demo buttons. Review reachable release paths separately; do not assume README codes currently work. |
| Admin password reset writes a password field to Firestore | `AuthNotifier.adminResetPassword` | Does not update Firebase Auth credentials; sensitive plaintext would be stored if invoked. Rules expose users publicly. Do not exercise this operation. |
| Broad rules / role escalation risk | `firestore.rules` users create/update permit own document without field restrictions; public users read; authenticated broad bills/consumption/complaints access | Users can potentially set privileged role/status fields, and access is not scoped to generator ownership. Requires dedicated security review; no rule edits here. |
| No generator tenancy in core data queries | `data_provider.dart` subscribers/pending users/all bills/complaints; `system/generator` singleton; notification broadcasts | Current model is global, while product description describes independent generator owners. Branding does not imply tenant isolation. Separate architecture task. |
| Role string inconsistency | Registration stores `user`; `notifyAllUsersGeneratorState` queries `consumer` | Registered consumers may not receive generator alerts. Preserve behaviour in this phase. |
| Receipt storage is Base64 in bill documents | `FirebaseService.uploadReceipt`, `uploadReceiptForUser`; upload UI reads gallery bytes directly | Document-size and bandwidth risks; ImageService compression exists but is not used in this upload path. No storage/data-flow changes here. |
| Legacy upload fallback fabricates a bill | `FirebaseService.uploadReceiptForUser` | Hardcoded July 2024 amount/usage if no pending bill found. Current receipt sheet calls uploadReceipt instead. Keep dormant paths unchanged. |
| Daily usage is synthesized | `data_provider.dart`, `_buildDailyUsagePoints` | Uses factors around daily average rather than measured daily samples. Do not label redesigned chart as real-time metering or alter values. |
| Errors can resemble valid data | Permission-denied fallback in data provider; Home/overview loading defaults to generator on; mock subscriber/bill/complaint UIs on errors | Can mislead users. Preserve branching and data flow during visual-only work; separate logic fix. |
| Bill jump does not highlight/scroll | Admin `_jumpToBillsTab` writes highlightedBillProvider; bills UI always passes isHighlighted:false | Existing navigation selects bills but highlighted provider is not consumed in bill list. Do not fix during redesign. |
| Local saving variable resets on rebuild | Consumer/admin profile StatefulBuilder declares saving inside builder | Busy protection may not persist. Separate behavioural fix. |
| Dormant affordances and placeholder actions | SetupScreen decorative camera; profile security/help methods not linked; add-subscriber sheet helpers not linked; dormant security tiles only show snackbars | Do not activate or add features during visual implementation. Document current reachability. |
| Notifications swallow exceptions; local init is platform-limited | NotificationService catch blocks; LocalNotificationService init catch | Delivery and platform failures may be invisible. No service changes. |
| Existing test is stale | `test/widget_test.dart` expects a counter and pumps app without ProviderScope | Source does not match router/provider app; baseline test execution is pending Flutter availability. Do not report existing tests as passing. |
| Android release currently uses debug signing | `android/app/build.gradle.kts` | Suitable only for development distribution, not a production Play signing setup. Outside this phase. |
| README auth description differs from current implementation | README says Phone Auth; current login/register use synthetic email + password | Preserve actual flow; documentation/product correction is a separate decision. |

## Current validation limits

Flutter 3.41.9 / Dart 3.11.5 is now installed outside the checkout, matching SDK-pinned dependencies in the unchanged lockfile. The original counter test was executed on an archived pre-redesign source snapshot and fails with `No ProviderScope found`, followed by its stale counter expectation. It still fails after the redesign; it has not been altered. Baseline analysis has 0 errors, 20 warnings and 261 infos; see the Step 3 admin report for current checks. Android has no installed emulator, exposed KVM or visible attached USB device here; native launcher/splash validation remains unverified and must not be replaced by browser simulations.

## Pilot review: misleading admin consumption label

The original `work` branch (`caa6d10f132a79fa36bcd44bcf95885d0cc5340d`) labels an admin statistic `كWh هذا الشهر`, but its value is `(stats.unpaidCount + stats.paidCount)` followed by `فاتورة`. This is application code, not a golden-only label. At the earlier pilot checkpoint, the golden fixture supplied 12 unpaid + 24 paid bills, so the expression displayed `36 فاتورة`. The current fixture is consistent with its loaded bills; the incorrect application mapping is unchanged. The visual redesign deliberately preserves this expression and label; a separate logic correction requires authorization outside this phase.

## Unchanged numeric input handling

ID inputs use `FilteringTextInputFormatter.digitsOnly` / ASCII digit validation; numeric price/amount parsing uses `int.tryParse` or `double.tryParse`. Arabic-Indic numeric input is not normalized by these original paths. This is an input/validation concern for a separate functional phase; numeric values and validators were not changed for the redesign.

## Multi-generator branch follow-up (historical findings remain above)

This branch deliberately leaves `AuthNotifier.demoLogin`, demo profiles and `demoModeProvider` intact. The bypass is still present and is not suitable as a production authentication mechanism; the actual Firestore rules authorize Firebase UID + private users document, not demo state. See `validation/multi-generator-scope.json` for the unchanged method-body check.

Changes required by the new functional/security scope: client-side privileged super-admin seeding was removed; protected user fields and tenant boundaries are enforced by rewritten rules; AuthState.copyWith now clears nullable membership on sign-out; pending/rejected users remain authenticated on a gated status screen. The old email/password login method remains unchanged. These supersede the historical seed/null-clearing/permissive-rules findings on this branch.

Remaining limits: missing-field legacy bulk queries require the manual backfill documented in migration.md; old clients using global queries must be retired in the coordinated rollout. Legacy Auth email/password UIDs are not automatically linked to new phone Auth UIDs. Review existing privileged roles before deploying stricter rules, because the previous rules allowed self-edits; migration does not infer/revoke historical role abuse. Existing demo/mock error fallbacks, synthetic daily chart data, the kWh/bill-count label issue, Base64 Firestore receipt storage and the legacy Firestore-only password-reset behavior were not redesigned as part of tenant isolation. The source-only subscriber-add helpers do not provision phone Auth users; real enrollment now goes through verified OTP and pending approval. Client notification fan-out remains best-effort; the super-admin's generator-request list is the real-time request inbox and pending owners do not enumerate administrator user profiles.

Android Phone Auth requires native Android Firebase app options/signing configuration. The old Dart AppConfig contains a web app ID; this branch uses the existing matching google-services.json on Android (same project, no project change). Real SMS testing, signing fingerprints, billing/SMS quotas, account linking and deployment are manual; no real SMS or production data access occurred here.
