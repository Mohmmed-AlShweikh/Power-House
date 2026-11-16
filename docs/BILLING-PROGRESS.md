# Free-tier billing progress

Branch `feature/free-tier-billing`, base `feature/spark-email-phase1` / ad494a9. Main is untouched.

| Stage | State | Reference |
|---|---|---|
| 1 short audit | Complete | stage-1, docs/billing-audit.md |
| 2 email/security | Previously complete, regression verified only | inherited ad494a9; stage-2 marks verification, no reimplementation |
| 3 settings/calculation | Complete | stage-3, docs/billing-stage3.md |
| 4 reader role/invites | Not implemented yet | no reader permissions added |
| 5 rounds/partial payments/statement | Not implemented yet | payments remain full-invoice only |
| 6 bulk publication/share | Not implemented yet | no new sends |
| 7 finance/summaries | Not implemented yet | no expense or summary collections |
| 8 final full-product sweep | Pending later stages | stage-3-specific screenshots/build are validation, not completion of stage 8 |

Assumptions and numeric precision: docs/decisions.md. Windows setup: docs/manual-steps.md. No migration, production calls, paid backend or billing activation. No existing test was removed or weakened; existing golden baselines were refreshed for the new menu/unit labels and diagnostics line shifts.
