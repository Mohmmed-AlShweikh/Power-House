# Automatic Firestore loading

## Root cause confirmed by code audit

`generatorDirectoryProvider` did not depend on Firebase auth at all. If it was first watched while Firebase/its Firestore credential channel was transitioning, the initial permission-denied left that StreamProvider failed; signing in did not recreate it. `consumptionProvider` watched only the database and read the tenant inside its mapper, so it did not reliably resubscribe when membership changed. `watchGenerator` and the other snapshot sources had no bounded listener recovery. `allBillsProvider` and `subscribersMapProvider` explicitly swallowed permission-denied as empty data, hiding a terminated subscription.

Most tenant queries already watched the profile indirectly through `scopedQuery`, but none watched generator eligibility. Re-approval/reactivation could therefore leave an earlier denied listener failed even though the account could now enter the screen. The two shell notification listeners bypassed providers, used the global database and listened only once after the first frame. This is an architectural diagnosis reproduced with controlled local readiness/error transitions, not a claim of inspecting production failures.

## Central fix

`lib/services/firestore_reads.dart` owns authenticated `autoSnapshots` and `retryFirestore`.

- Directory: requires a settled authenticated UID; deliberately does not require a profile (new consumers must pick a generator before creating theirs).
- Operational tenant data: requires authenticated UID, settled role/profile and approved/active membership plus available generator. Super-admin reads require the settled super-admin profile and retain their global scope.
- Generator access metadata: requires profile/UID but not generator availability, avoiding a circular wait and allowing suspended/pending account-status screens to work.
- Dependencies include auth/profile/role/tenant and generator access changes. A new eligible state opens a fresh listener automatically; old subscriptions/timers cancel when their provider is rebuilt/disposed.
- Permission-denied/unavailable: initial attempt plus at most **two** retries, after 200 and 500 ms. No interim AsyncError is emitted, so existing error/retry presentations appear only after exhaustion. Other failures (including missing indexes) are not retried. Writes are not blindly retried.
- Cache-miss profile lookup and recovery identity checks use a bounded **server-only** read; a cached missing document cannot accidentally classify a returning user as unregistered. UID-bound positive profile cache still accelerates routing, and live updates remain authoritative.
- Permission failures are no longer converted into empty bills/names. Shell notification subscriptions restart on auth/profile changes, cancel old listeners and use the injected Firestore and bounded retry. Background notification failure does not throw into the widget tree; the alerts UI provider surfaces its own exhausted error.

## Every Firestore-loading surface/provider audited

| Surface | Sources | Before | Applied |
|---|---|---|---|
| Phone login / registration / account status | AuthNotifier profile cache/server/live stream | Initial read or live listener could fail without recovery | Server-read retry, live retry, UID guards and completion readiness |
| Consumer generator picker | generatorDirectoryProvider | No auth dependency; first denial persisted until retry | Signed-UID gate, auto resubscription, bounded retry, live approved+active filter preserved |
| Consumer/owner generator hero, schedule, price | generatorProvider, currentGeneratorAccountProvider, watchGenerator, currentPriceProvider | No generator eligibility gate/recovery | Metadata and operational gates separated; both source streams retry |
| Consumer bills and receipt sheet | billsProvider(uid) | Profile-scoped query could run before eligibility | Central operational gate/retry |
| Owner bills, subscribers' bill history, overview stats | allBillsProvider, monthlyBillStatsProvider | Permission errors hidden as empty list | Removed swallowing; central gate/retry, derived stats inherit readiness |
| Consumer alerts, owner alerts, notification bell and sheets | alertsProvider(uid), shell live notification listeners | Provider had no retry; direct shell listeners never restarted | Central gate/retry; direct listeners restart/cancel and use injected DB |
| Owner subscribers and subscriber details | subscribersProvider, subscribersMapProvider | Names provider swallowed permission denial | Central gate/retry, role-constrained queries unchanged |
| Owner consumer requests | pendingUsersProvider | Could start before owner/tenant eligibility | Central gate/retry |
| Consumer complaints sheet/list | consumerComplaintsProvider(uid) | No listener recovery | Central gate/retry |
| Owner complaints and reply sheet | complaintsProvider | No listener recovery | Central gate/retry |
| Consumer usage/chart/history | consumptionProvider(uid), consumptionHistoryProvider | Consumption omitted reactive tenant/auth dependencies | Auth/tenant/availability gate/retry; history derives from gated bills |
| Overview activity/stats | recentActivitiesProvider, monthlyBillStatsProvider | Inherited stale/failed source state | Inherit fixed sources; existing settledValue clearing retained/tested |
| Super-admin pending count and owner directory | pendingGeneratorOwnersProvider, generatorRequestsProvider, ownerNameProvider | Directory/name sources lacked auth dependencies/recovery | Settled profile/role gate/retry; all statuses and private names preserved |
| Super-admin diagnostic dialog | Explicit authenticated one-shot users get | User-invoked diagnostic, not initial screen loading | Audited; not an automatic provider and unchanged |
| Receipt upload, mark/read alerts, approve/reject, scheduling and account mutations | FirebaseService, TenantStore, NotificationService explicit reads/transactions | Authenticated user actions, not startup list loaders | Audited; no retry of mutations; tenant authorization unchanged |
| Login forms, theme settings, OTP entry, form/empty/error widgets | No independent Firestore load | Not affected | No extra queries introduced |

## Local proof

`test/auto_load_test.dart` checks: delayed auth/profile availability, UID and tenant switching without invalidate/retry, permission-denied/unavailable recovery, final error after exactly three attempts, immediate failure for permanent errors and cancellation during backoff. Existing multi-generator/owner-switch tests retain live picker/subscription coverage. Tests run only with fakes or `demo-generator-portal` local emulators; no production reads/writes/deployment.
