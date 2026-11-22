# Final report — 2026-11-17

Branch: `feature/free-tier-billing`, based on completed stage 3 (`f08fd58`). Main untouched. Stages executed in requested priority order 4 → 5 → 7 → 6 → 8. No production Firebase calls/deployments, data deletion, billing, Functions, Storage, paid hosting or new dependencies. Auth stage 2 was retained and regression-tested, not rebuilt.

| Stage | Commit / tag | Delivered | Flutter / emulator |
|---|---|---|---|
| 4 | `9ac7f3f` / `stage-4` | Verified-email invited reader; one-use expiring/revocable codes, worker revocation; sanitized current-round assignments/readings; no money/private profiles/past-round access | 158 / 22 |
| 5 | `ea63d0b` / `stage-5` | Manual/linked billing subscribers, resumable rounds, exact frozen invoices, replacement meters, abnormal-jump confirmation, native offline reading queue, closing idempotence, documented corrections, partial payments/review/balances/statement | 161 / 25 |
| 7 | `020ddda` / `stage-7` | Finance summaries, month/round/custom periods, category costs with soft-delete history, payment reversal, locked generation repair; includes Phase-1 manual invoices | 163 / 27 |
| 6 | `febad92` / `stage-6` | Resumable two-write invoice publication + deterministic in-app alerts, explicit Android system sharing, manual sent markers | 165 / 28 |
| 8 | Report commit / `stage-8` | New-screen RTL/light/dark goldens, shared async/keyboard states, name-based subscriber/worker selection, preserved linked payment history, final rules/regression/build | 171 / 31 |

Analyzer: 0 errors; the original 14 warnings + 18 infos remain, no new diagnostics (compared by message/file/code against stage 3). Every previous passing test remains; none deleted or weakened. Android debug APK built at `build/app/outputs/flutter-apk/app-debug.apk`. Existing goldens updated only for the added navigation/labels and diagnostic line shifts. New captures (widget renders, not device photos): `docs/screenshots-billing/`. Validation logs/JSON and complete changed-file list: `docs/validation/billing-final-*` and `billing-stage*-*.txt`.

## Design / files

New isolated modules: `features/metering`, `rounds`, `finance`, `distribution`, shared form/async widgets. Minimal integration touches role parsing/router/access readiness, owner More menu, consumer bill shortcut, and legacy invoice/payment transactions for finance summaries. New collection matches and indexes are in `firestore.rules` / `firestore.indexes.json`. Android MainActivity adds only the user-triggered text-share channel. Existing splash/auth/OTP removal/identity/navigation behavior is retained. Money uses integer agorot; readings use integer thousandths; old invoice snapshots are immutable under normal payment actions.

## Decisions / known limits

- New cycle invoices support partial payments; old Phase-1 manual invoices retain their original full-invoice payment screen. The cycle statement/balances cover cycle invoices; finance includes both ledgers. No legacy-account migration or duplicate account creation.
- Closed-round reading correction is allowed before opening the next round, with before/after, actor/time/reason. Reverse a payment first if reducing the bill below paid money. Later-round cascades/refunds are not automatic.
- Up to 1000 subscribers per round; custom finance range ≤366 days; expense details ≤200 per selected period (summaries remain complete). Summary repair retains previous generations and expense history, so storage is finite and repairs consume quota. Cash excludes opening balances/bank reconciliation.
- Worker offline writes use Firestore's native persistent queue and pending-write metadata; reconnection was tested on the local SDK emulator. App-kill recovery, low-end performance, keyboard behavior on actual devices and cache visibility during offline revocation require phone verification. Revocation blocks server access; it cannot erase already cached data on a disconnected device.
- Share sheet is implemented for Android only. Opening it is not delivery; marking sent is an explicit owner action. No automatic WhatsApp/SMS, FCM server credentials or guaranteed notifications while the app is closed.
- Actual email delivery/action links, Android native splash mask on hardware, notifications and real sharing were not device-tested. No cloud device service was used. Owner-written client finance/history is not represented as tamper-proof audit accounting.

## Manual steps / quotas

Follow `docs/manual-steps.md`: clean Spark test project, enable Email/Password, disable Phone, configure templates and local Android config, manually bootstrap the verified super-admin, deploy matching rules/indexes, configure owner billing settings, invite workers/assign subscribers, and run the owner summary repair once. Exact Windows commands and phone test path are there. No configuration/deployment was performed on your real project.

Cost estimates: each financial operation reads/writes 4 affected summary docs normally, up to 7 when periods/rounds differ, plus its underlying records and one control read. A standard finance period reads one summary + control/cash; custom ranges read only daily summaries. Publication uses one bill read + one invoice write and at most one alert write per subscriber; retries read markers and skip duplicates. Repair scans history once and writes grouped summaries. These consume finite Spark quotas; they do not enable charges. See `docs/finance.md` / `docs/decisions.md`.
