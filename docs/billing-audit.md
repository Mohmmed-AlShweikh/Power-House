# Billing audit — stage 1

Base: ad494a9, verified-email Phase 1. Clean test Firebase only.

| Feature | Exists? | Action |
|---|---|---|
| Email verification/reset, tenant approval/rules | Yes | Stage 2 complete; regression tests only |
| Generator price | `generators/{gid}.pricePerKwh`, double | Add isolated versioned billing settings; old bills immutable |
| Bills | `bills`, integer whole-shekel `amount`, kwh, month/year; manual form | Stage 5 adds reading snapshots and integer-agorot totals |
| Payment declarations | Full-invoice record/version with transactional review | Keep unchanged until partial payments in stage 5 |
| Consumption | `consumption/{uid}` aggregate, derived from entered usage | Stage 5 reading rounds; no silent legacy migration |
| Worker/readings/rounds | Absent | Isolated feature modules and rules |
| Notifications | `alerts`, local device notifications | Stage 6 idempotent publication, no FCM credentials |
| Roles | consumer, generator owner, super admin | Stage 4 restricted meter reader |
| Finance/summaries/expenses | Absent | Stage 7 owner-only module |

The misleading “كWh هذا الشهر / 36 فاتورة” is app code, not just golden data: `_DashboardTab` in `admin_screen.dart` labels `stats.unpaidCount + stats.paidCount` (a BILL COUNT) as energy. Correct it to a bill-count label when integrating billing. Hard-coded kWh labels occur in consumer home/usage and the shared generator hero, while the manual bill form computes `(kwh * currentPrice).round()`. Stage 3 introduces the sole integer calculation core; stage 5 replaces this creation path with readings. Existing historical bills retain their stored values.

Touch points: owner More menu (add settings/readings/workers/finance), router allowlist, enrollment for invite codes, dedicated reader screen; consumer bills/statement and labels; bill creation/review only as explicitly required. Existing navigation, splash, keyboard handling, auth readiness and styling remain.

Quota risks: current allBills/users streams are unbounded. New modules must scope by generator/round and page where practical; client batching is resumable but not an atomic operation across unlimited subscribers. Spark quotas remain finite. No production operation or migration is authorized.

Validation: 137/137 Flutter tests and 17/17 Auth/Firestore emulator tests passed on the inherited Phase-1 implementation. Analyzer has the same 32 existing diagnostics (14 warnings, 18 infos), no errors. Stage 2 is verified, not reimplemented.
