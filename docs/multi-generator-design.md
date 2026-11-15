# Multi-generator design — audit before implementation

Base: fix/tab-swipe 36042c1; feature branch: feature/multi-generator. No production Firebase reads/writes, deployment, migration or authentication will be run from this workspace.

## Current state and complete data-path inventory

- AuthNotifier uses Firebase email/password identity aliases, client-side super-admin seeding, users/{uid} lookup/listener, unscoped owner registration and pending/rejected sign-out. Demo state/router bypass remains in source and must remain unchanged.
- Generator provider and FirebaseService toggle/price/schedule read/write system/generator.
- data_provider: bills(userId), allBills, alerts(userId), subscribers(all users then local role/status filter), pendingUsers(all users), pendingGeneratorOwners(all users), consumerComplaints(userId), complaints(all), subscribersMap(role in user/consumer), consumption/{uid}. Monthly stats, history and activities derive from these sources and inherit their scope.
- FirebaseService: subscriber creation/by-phone, subscriber update, bill status and Base64 upload, latest pending bill lookup/fallback creation, alert mark/delete queries, complaint create/resolve/reply, bill create, identity/email subscriber lookup, name get, atomic bill+consumption plus alert, profile update, user approve/reject.
- NotificationService: addAlert; global super-admin lookup, owner broadcasts for registration/complaints, consumer broadcast for generator status, approval/rejection/password alerts.
- AdminScreen and ConsumerShell each directly listen to alerts by userId. These need generator constraints too.
- SuperAdminScreen diagnostics directly enumerate users; this remains super-admin-only. Existing owner-request actions must manage generators as well as the owner user.
- No separate requests/usage collections exist: enrollment requests are users with status pending; usage is consumption/{uid}, including weeklyUsage entries. Bills also carry consumption history.
- Other UI calls the above services/providers; setup_screen has a source-only onboarding design, no separate database implementation.
- Existing rules publicly expose users, allow broad role/status writes and unscoped operational access. They require replacement.

## Final architecture

Keep existing root collections, add generators/{gid} and generatorDirectory/{gid}. generatorId is immutable tenant membership on users (except trusted super-admin), bills, complaints, alerts and consumption. The default ID is `default`; absence/null/empty legacy generatorId maps to default on decoding. Super-admin has no tenant.

A shared tenant query/repository layer uses server-side generatorId filters, with additional userId constraints for consumer data; no fetch-all-then-filter tenant isolation. Services derive the actor and tenant from authenticated users/{uid}, not from form input. Direct document mutations validate tenant/user binding; Firestore rules are the authoritative boundary. Add injectable Firestore/auth seams so tests use fakes/emulators only.

Phone OTP becomes the new enrollment and returning-phone-login entry. Existing identity/password sign-in remains for existing accounts/super-admin. A verified Firebase phone user without a profile stays authenticated and is sent to enrollment, never auto-granted a role. Owner enrollment atomically creates users/{uid} (generator_owner, pending) and generators/{random gid} (pending). Consumer enrollment reads only the approved+active public directory, then creates users/{uid} (user, pending, selected generatorId). Name is requested for consumer records; owner user name initially uses the generator name. Both wait/rejection screens stay subscribed to their own profile and generator status.

Super-admin management lists generator records, approves/rejects with a reason/suspends/reactivates/toggles subscription. A batch updates generator, owner approval where applicable, and an allowlisted public directory projection. Only super-admin can write the projection; picker queries approved AND active and displays name/sector only. No owner UID/phone/identity is copied to the directory.

Rules use users/{uid} get() for role/tenant, immutable-field allowlists, verified-phone enrollment, atomic owner membership binding, owner-only same-tenant consumer review, consumer-own receipts/complaints and owner-owned operational writes. Super-admin full access is retained. Normal tenant operations after backfill require no Cloud Functions. Strict bulk compatibility before backfill would require a trusted legacy-read proxy, which is not implemented; this is reported as a remaining requirement. Real phone SMS has its own Firebase billing requirement. Client-side privileged super-admin seeding is retired; provisioning is manual via trusted console/Admin SDK. Demo-login bypass is not changed.

## Legacy compatibility boundary

Individual documents without generatorId decode to default. For default only, generator configuration falls back to system/generator until generators/default exists. Existing document IDs and legacy collections are never deleted. An offline, default-dry-run migration plan backfills missing generatorId, validates explicit memberships, and creates the default generator/public projection.

Firestore cannot query missing fields: `where(generatorId == null)` does not select documents with an absent field, and rules are not post-query filters. Therefore strict owner tenant lists cannot simultaneously return arbitrary unbackfilled legacy documents. We choose fail-closed lists rather than relaxing isolation. Backfill must precede rollout of tenant-filtered owner lists; this is a concrete limitation of the requested zero-migration bulk-read compatibility, not an automatic migration. Legacy own-user/document gets and default configuration fallback continue to work. No production migration will run here.

## Validation plan

Fake Firestore unit tests: two generators, directory projection/filtering, enrollment, review transitions, member/operational queries, target-tenant validation, default decoding and batch scope. Router/widget tests: OTP/enrollment states, pending/rejected and approval routing, picker name/sector/search/empty/error, both themes/RTL. Firestore emulator tests if tooling can be installed: self-promotion, tenant reassignment, cross-tenant access, pending/suspended access, owner review, receipt restrictions, projection privacy and phone enrollment. Otherwise enumerate exact cases in docs/rules-test-cases.md. Migration tests use local JSON fixtures only. Analyze before/after, fix the obsolete counter test to a real mocked startup smoke test so the full test suite can pass.

Public generator IDs are random Firestore document IDs, not owner Auth UIDs. The atomic user↔generator membership validates ownership without exposing an owner identifier in directory paths.

## Final implementation notes

The feature branch was created from fix/tab-swipe, then merged the already-pushed redesign/visual-identity fixes so native splash and keyboard behavior do not regress. The parent branches were not rewritten and main was untouched. Generator-level subscriptionStatus is the owner billing gate; the old owner-user subscription field is not treated as an extra billing switch. Consumer subscriptionStatus remains the owner's connection-control field. Missing legacy subscription fields default active; explicit generator subscription must be active. `default` is reserved for trusted migration/super-admin provisioning; new phone owners cannot reserve it. New generator IDs are random and do not disclose owner Auth UIDs.

Invoices, usage and the associated invoice alert are now one atomic, tenant-bound batch. ID lookup also accepts an international phone number for OTP accounts, with server-side tenant+consumer-role filters. Loading derived histories/activity discard retained AsyncValue data during tenant changes, avoiding a transient previous-tenant display. Directory selection tolerates a sector disappearing during live subscription/status updates and rejects stale selections. Generator review cards keep state by generator ID.
