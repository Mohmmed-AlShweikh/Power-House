# Free-tier billing progress

Branch `feature/free-tier-billing`, base `feature/spark-email-phase1` / ad494a9. Main is untouched.

| Stage | State | Reference |
|---|---|---|
| 1 short audit | Complete | stage-1, docs/billing-audit.md |
| 2 email/security | Previously complete, regression verified only | inherited ad494a9; stage-2 marks verification, no reimplementation |
| 3 settings/calculation | Complete | stage-3, docs/billing-stage3.md |
| 4 reader role/invites | Complete | stage-4; sanitized current-round access, revocable one-use invites |
| 5 rounds/partial payments/statement | Complete | stage-5; separate cycle ledger, Phase-1 invoices unchanged |
| 6 bulk publication/share | Complete | stage-6; resumable publication and explicit Android sharing |
| 7 finance/summaries | Complete | stage-7; exact summaries, soft-deleted expenses, reversal and repair |
| 8 final full-product sweep | Complete | stage-8; docs/FINAL-REPORT.md and full regression/build evidence |

Assumptions and numeric precision: docs/decisions.md. Windows setup: docs/manual-steps.md. No migration, production calls, paid backend or billing activation. No existing test was removed or weakened; existing golden baselines were refreshed for the new menu/unit labels and diagnostics line shifts.
