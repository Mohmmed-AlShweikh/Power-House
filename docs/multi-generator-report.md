# Multi-generator implementation and validation

Status: implementation pushed for review; rollout requires manual Firebase setup and migration. One original requirement is not fulfilled: complete legacy bulk-list continuity before backfill. The client fails closed rather than relaxing tenant isolation. See the explicit limitation below.

## Previous tasks completed first

| Task | Branch / commit | Cause and fix | Scope |
| --- | --- | --- | --- |
| Keyboard forms | redesign/visual-identity / 0f9819b | Opener-context insets and unconstrained/non-scrollable form Columns; shared route-local keyboard viewport + focus revelation and scrollable dialogs | admin_screen, consumer profile_tab/bills_tab, portal_keyboard, keyboard tests, evidence/goldens only; no services/models/rules/schema changes |
| Tab swipes | fix/tab-swipe / 36042c1 | Six-page swipe controller and five-item navigation differed during movement/RTL; one index + lazy retained IndexedStack, no page swipe recognizer | admin_screen only in app code, navigation tests/evidence/goldens; no services/models/rules/schema changes |

feature/multi-generator was created from fix/tab-swipe. The already-pushed splash and keyboard changes were merged so this branch includes all previous fixes. main was not modified and no PR/release/deployment was created.

## Implemented

- Native Firebase phone OTP entry and onboarding; legacy ID/email-password login remains. Android uses the existing native Firebase app options, in the same project, rather than its old web app ID. Pending/rejected profiles stay authenticated and are gated to a status screen, with live profile/generator updates. Automatic privileged account seeding is retired; super-admin provisioning is manual.
- Atomic pending owner+generator registration. Public generator IDs are random, not owner Auth UIDs. The default namespace is reserved for trusted migration. Owner phone stays in the private user record.
- Approved+active public directory with only name/sector/status/subscriptionStatus; UI search, sector filter, selection, empty/loading/error states and stale-selection/live-sector handling. Consumer enrollment stores immutable generator membership and waits for that owner's approval.
- Super-admin generator management: pending-first list, approve, reject with required reason, suspend, reactivate, subscription switch; atomic private generator/owner/public projection updates. Existing legacy owner-request actions also use generator review and require a rejection reason.
- Tenant-scoped users/requests, bills, receipts, complaints/replies, alerts, consumption, derived history/stats/activity, identity/phone billing lookup, generator switching/price/schedule and local alert listeners. The invoice, usage and invoice alert are one atomic batch. Async derived data does not reuse the previous tenant's retained values while loading.
- Rules authorize by Firebase UID + protected users document, enforce immutable self membership/roles/status/subscriptions, verified-phone pending enrollment, atomic owner binding, consumer-own data/receipt field restrictions, owner-only same-tenant review, private recipient-scoped notifications, super-admin privilege and allowlisted directory writes. Typed payloads/timestamps prevent malformed member records from breaking owner feeds. A super-admin has no implicit default membership.
- Offline default-dry-run migration/export tooling, typed full backup, planned default generator/public projection, missing tenant/weekly-usage backfill, project confirmation, concurrency preconditions, 400-write batches, idempotence and ambiguity blockers. It was not run on production.

## Main changed files

| Area | Files |
| --- | --- |
| Models | generator_model.dart; user_model.dart, bill_model.dart, complaint_model.dart, alert_model.dart |
| State/data | auth_provider.dart, data_provider.dart, tenant_provider.dart, enrollment_provider.dart |
| Services | tenant_store.dart, phone_auth_service.dart, firebase_service.dart, notification_service.dart |
| Navigation | config/router.dart, config/auth_redirect.dart |
| UI | phone_enrollment_screen.dart, account_status_screen.dart, generator_requests_screen.dart, portal_reason_dialog.dart; login/super-admin/admin/consumer-shell integration; inherited shared keyboard/splash fixes |
| Security/config | firestore.rules, firestore.indexes.json, firebase.json, firebase.emulator.json |
| Tests/tooling | multi_generator_test.dart, multi_enrollment_widget_test.dart, support/multi_auth_fixture.dart; obsolete counter test replaced by real mocked startup smoke test; tools/rules-tests; tools/migrate_to_multi_generator, tools/test_migration.py |
| Dependencies | fake_cloud_firestore dev dependency + lockfile additions only; runtime dependencies unchanged |

Full file list and diff stat are in validation/multi-generator-files.txt and multi-generator-diff-stat.txt, relative to fix/tab-swipe (including merged prior UI/native fixes).

## Final validation

- 98 Flutter unit/widget/golden tests pass, including all existing redesign/auth/navigation tests and the merged 13 keyboard cases. Final comparison ran without updating references. Functional changes intentionally refreshed login/owner-management/phone-billing and shifted error-stack goldens; comparison tolerances remain unchanged.
- 19 actual Firestore Emulator rules tests pass on local demo-generator-portal; 5 offline migration tests pass. No real Auth sign-in, SMS, production database operation, migration or rules/index deployment occurred.
- Full analyzer: 0 errors, 17 inherited warnings, 20 infos. Compared to the branch base, no new diagnostics; the old unused auth import and obsolete counter-test const note disappeared.
- Debug Android APK builds and its signature verifies. It was not installed/run on a physical device or emulator, and no APK was published. Real SMS/Play Integrity/Apple/web phone-auth behavior was not verified; primary implementation target is native Android.
- Demo-login method and legacy email/password sign-in method match their base bodies; demo mode remains deliberately present. Runtime dependencies are unchanged. Evidence is in validation/multi-generator-*.

## Assumptions, limits and manual work

**Unfulfilled pre-backfill compatibility requirement:** absent generatorId maps to default for individual documents/config, but Firestore cannot query missing fields. Strict tenant-filtered bulk lists cannot include arbitrary unbackfilled legacy records. A trusted server read proxy would be required to meet that guarantee without backfill; no such Cloud Function/proxy was added. This branch instead requires the documented backfill before rollout, and reports the limitation rather than opening global client reads. Do not roll it out to the live database before migration.

Assumptions: one generator per new owner; existing global data belongs to default; legacy owners keep shared default membership, with a supplied/deterministically selected primary owner for notifications; consumer name is collected with the verified phone. Generator subscription controls owner billing access; the old owner-user subscription field is not an extra billing gate. Consumer subscription remains connection control. Public directory never contains owner phone/id/UID or rejection reason. Existing Auth UIDs are preserved, not silently linked/merged with new phone UIDs.

Manual: enable Phone Auth/SMS regions, native Android signing fingerprints and applicable Blaze/SMS billing; test with Firebase test numbers/staging; create the trusted super-admin Auth user + matching lowercase users/{UID} record; review legacy privileged roles; stop old global-query clients/writes in maintenance, export/backup, inspect the dry-run and apply backfill, then deploy reviewed rules/indexes and app. See migration.md for exact commands. Switching the old web Firebase app options to native Android options may require a one-time sign-in after upgrade; steady-state startup still waits on the branded loader.

No Cloud Functions were introduced for normal post-migration operations. Real Firebase phone SMS billing is unavoidable for the requested provider; Firebase test numbers avoid real SMS. Existing demo/mock fallbacks, synthetic daily usage, kWh-label issue, Base64 receipt limits and legacy password-reset behavior remain in findings.md. Client notification fan-out remains best-effort; no new offline-push backend is claimed.
