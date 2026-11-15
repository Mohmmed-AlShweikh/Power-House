# Multi-generator migration — manual only, never executed here

Do not deploy this branch directly over an unmigrated live database. It intentionally fails closed instead of making global queries when tenant IDs are missing. Scalar legacy documents decode to `default` and generator state falls back to `system/generator`; tenant-filtered lists cannot discover an absent field. Firestore has no missing-field query, so the requested seamless zero-backfill bulk-list compatibility cannot safely be provided. Backfill is a deployment prerequisite for complete list/history continuity.

## Prepare and back up

1. Review `docs/multi-generator-design.md`, rules and the generated plan on a staging project first. Keep an app/rules rollback copy. Enable a maintenance window/stop client writes before export and migration to avoid records changing during backfill.
2. Use a trusted workstation/service account with minimum required Firestore access. Never embed credentials in the app or paste them in chat. Install optional tooling into a local virtual environment:
   ```sh
   python -m venv /secure/migration-venv
   /secure/migration-venv/bin/pip install -r tools/requirements-migration.txt
   ```
3. Make a full, typed JSON backup of all root collections and nested subcollections (read-only, explicit manual action):
   ```sh
   /secure/migration-venv/bin/python tools/migrate_to_multi_generator --export /secure/before-multi.json --project YOUR_PROJECT_ID
   sha256sum /secure/before-multi.json > /secure/before-multi.sha256
   ```
   The export contains private identities, phones and Base64 receipts. Store it encrypted/access-controlled outside Git. The command refuses to overwrite a backup. It preserves timestamps (including nanoseconds), bytes, references and geopoints. JSON backups can be large; use a trusted machine with sufficient disk/memory. Optionally also use a managed Firestore export if your project supports it; this implementation does not require billing/Functions.

## Offline plan (default)

```sh
python tools/migrate_to_multi_generator --backup /secure/before-multi.json --default-owner-uid EXISTING_OWNER_UID --name 'اسم المولد الحالي' --sector 'الحي الحالي' > /secure/plan.json
```

Without `--apply`, no Admin SDK, credential or network access occurs. `--dry-run` is accepted explicitly but is already the default. The planner:

- Creates generators/default from the operational fields of system/generator, retaining the original system document.
- Selects the supplied existing owner; if omitted, deterministically selects the first approved legacy owner (otherwise first legacy owner). All old owners still share default membership; the chosen owner is the notification recipient. Review this assumption before apply.
- Gives all non-super-admin users and bills/complaints/alerts/consumption documents lacking/null/empty generatorId the default ID. Explicit tenant IDs are preserved. Nested weeklyUsage records are backfilled too.
- Creates an allowlisted default directory projection. The default generator is approved only if its selected owner was approved. It never overwrites existing generator metadata/reactivates a suspended default generator. It blocks ambiguous records whose user already belongs to an explicit non-default tenant, and differing existing directory projections.
- Never deletes a document/collection or rewrites billing amounts/receipt images. Super-admin records are not assigned a generator.

Resolve every blocker, inspect the planned paths/counts, and retain the original backup. No plan or backup has been obtained from production by this task.

## Explicit apply and verification

```sh
/secure/migration-venv/bin/python tools/migrate_to_multi_generator --backup /secure/before-multi.json --project YOUR_PROJECT_ID --confirm-project YOUR_PROJECT_ID --default-owner-uid EXISTING_OWNER_UID --name 'اسم المولد الحالي' --sector 'الحي الحالي' --apply
```

All three project IDs (backup/project/confirmation) must match. Apply verifies every affected document against the backup before writing, uses create/update preconditions and batches of at most 400. A concurrent change aborts; no blind overwrite. Across batches this is resumable rather than globally atomic: if interrupted, export again, review a new dry-run and apply the remaining idempotent changes. Do not reuse a stale plan silently.

Verify counts, representative owner/consumer histories, directory fields, and tenant membership in staging and then your maintenance window. Deploy reviewed rules (`firebase deploy --only firestore:rules,firestore:indexes --project YOUR_PROJECT_ID`) and any prompted composite indexes, then roll out the app. The task does not execute deployment or migration. Never restore the old permissive rules as an automatic response to permission errors; investigate membership/indexes first. Rollback data restoration is a separate trusted/manual procedure using the saved export.

## Manual account/auth setup

Enable Firebase Phone Authentication and permitted SMS regions. Register Android SHA-1/SHA-256 for the signing keys (debug and eventual Play signing), keep the matching Firebase Android config, and use Firebase test phone numbers for staging validation. Real Firebase Phone Auth SMS requires enabling the applicable Blaze billing/SMS configuration and is billed/limited by Firebase. This is unavoidable for the requested Firebase phone-OTP flow, not a Cloud Functions dependency. Firebase test phone numbers avoid real SMS. Play Integrity/reCAPTCHA and quotas require console configuration; no real SMS was sent here. Android initialization now uses its native google-services.json app ID (the same existing project), rather than the old web app ID from AppConfig.

Create the super-admin Auth account manually (email/password can retain `ID@powershare.app` for the existing identity login), then create users/{AUTH_UID} with role `super_admin`, status `approved`, subscriptionStatus `active`, name and optional legacy idNumber. Do not give it generatorId. There is no client self-promotion or automatic privileged account seed in this branch. Existing email/password users retain that login; phone Auth accounts are not automatically linked to legacy email UIDs. Link them through a separately reviewed/manual process if required.

Additional rollout checks: review historical privileged user roles, ensure old global-query app versions are retired during maintenance, and verify two owners cannot see one another's users/bills/complaints/alerts. Missing legacy subscription fields default active. The old owner-user subscription field is not the billing gate; generator subscriptionStatus controls owner access, while consumer subscriptionStatus controls subscriber connection. A stale directory entry cannot authorize enrollment into an unavailable private generator. Normal administration updates both records atomically. `default` is reserved and cannot be claimed by new owner enrollment. Cross-project document references in a typed backup require manual review before apply.
