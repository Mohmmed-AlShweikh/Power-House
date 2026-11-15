# Firestore rules validation

Rules tests were run against a local Firestore Emulator with project ID `demo-generator-portal`, on loopback port 8089. The test runner refuses to run without the loopback emulator environment variable. No production Auth, Firestore, rules deployment or real SMS is used.

```sh
npm ci --prefix tools/rules-tests
JAVA_HOME=/path/to/jdk21 FIREBASE_EMULATORS_PATH=/local/emulator-cache tools/rules-tests/node_modules/.bin/firebase emulators:exec --project demo-generator-portal --config firebase.emulator.json --only firestore 'node --test tools/rules-tests/rules.test.mjs'
```

Cases in `tools/rules-tests/rules.test.mjs`:

1. Anonymous user/doc reads denied; authenticated profile-less users may query the public directory only.
2. Directory cannot contain owner phone/UID/private fields, even through a super-admin client; projection must match generator metadata.
3. Self role/status/generatorId/subscription changes and deletion denied; name/contact updates allowed.
4. Owner enrollment requires verified phone claims, atomic pending user+generator binding and matching UID; self-approval denied.
5. Unverified phone and other-owner impersonation denied.
6. Consumer enrollment requires approved+active generator/directory, pending user and inactive consumer subscription.
7. Consumers can read only their own tenant-bound profile/bills/consumption; a foreign generator record with the same recipient UID is also denied.
8. Owner queries require tenant+consumer role filters; unscoped reads/cross-tenant reviews, reassignment and bill updates denied.
9. Consumer receipt upload cannot alter amount, mark paid, reassign UID/tenant, replace an in-review receipt or invent an invoice.
10. Billing cannot name a user belonging to another tenant even when its payload generatorId matches the caller.
11. Complaints/replies are tenant-bound and preserve immutable identity.
12. Suspension immediately blocks owner/member operational reads while own status/profile remains readable.
13. Pending users cannot read operational data or toggle a generator.
14. Alerts/read flags bind both recipient and tenant; complaint notification may target only that generator's owner.
15. Legacy system/generator is reserved to default membership; other tenants cannot read/write it.
16. Super-admin review+public projection batches and privileged cross-tenant reads work.

The emulator runs the actual rules; fake_cloud_firestore tests separately verify repository/provider behavior and do not substitute for rules testing. Privileged Admin SDK/console operations bypass client rules and must remain trusted. Account provisioning and production rule/index deployment remain manual.
