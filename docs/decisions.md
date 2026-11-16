# Decisions

1. Branch from ad494a9 on `feature/spark-email-phase1` into `feature/free-tier-billing`, per the latest user update; not from the historical dual-login branch. Stage 2 already implemented: verify only, no auth rewrite.
2. Integer agorot for new money and integer thousandths for meter units. This permits 0.001-unit precision without binary floating-point; decimal inputs beyond precision are rejected, not silently rounded. Price is agorot per whole unit. Raw product retains integer numerator/denominator for sub-agora precision; apply minimum before whole-shekel rounding.
3. Stage 3 adds future-bill settings in a separate owner-only document. Existing manual bills and Phase-1 full-invoice payments remain unchanged until stage 5. No legacy-account migration.
4. Stage tags belong to this feature branch. Push only this branch and its explicitly named stage tags, never main or unrelated tags.
