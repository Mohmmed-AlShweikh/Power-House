# Pilot revision — approval checkpoint before Step 3

Only consumer home and admin overview have been redesigned. Step 3 has not started. The four PNGs are full-size actual Flutter golden renders at 430 × 1280, not HTML approximations or Android screenshots. Data providers are faked in tests only. No Firebase initialization or writes occur in these tests.

## Structure and destinations

Generator status is the first, strongest section. Only two headline metrics remain; operational/subscription details use flat ledger rows. Alert and activity rows share leading icon, title, secondary text and trailing value; alerts also retain read/unread status. Warm light canvas, token spacing, restrained borders and a separated bell replace the former dense header. The active generator switch uses blue track/thumb tokens, never success green.

The recommended navigation is alternative 1 (raised tiles). Admin has five items in RTL order: نظرة عامة، المشتركون، الفواتير، الشكاوى، المزيد. Existing TabController indices remain 0 overview / 1 requests / 2 subscribers / 3 bills / 4 complaints / 5 profile. Bottom items map to 0/2/3/4; More exposes requests (1), profile (5), the existing settings sheet, the existing theme toggle and the existing logout callback. Settings sheet content/save callback are unchanged. Consumer keeps its original four destinations and existing profile logout/theme controls; only the header duplicates were removed. Other destination content is not redesigned; padding reserves space for the floating bar.

## Navigation options

1. Raised tiles inside one floating rounded bar. Height, filled tile and bold label distinguish the active destination; closest to the requested reference spirit, recommended.
2. Independent islands with no enclosing bar. A stronger outline and a short underline identify selection; a quieter modular structure.
3. Focus window: the selected destination expands and places its label beside its icon. Inactive labels stay below their icons; selection changes geometry and outline as well as color.

All three are real Flutter widgets shown side by side for consumer/admin and light/dark. All labels stay visible. Tests verify RTL order, 80dp maximum total height, every target at least 48 × 48dp including at 320dp width, and selected semantics. No blur, heavy shaders or gradients. Pilot scroll tests reach the last record above the floating bar; nonpilot tabs reserve bottom space without restyling.

## Number and amount direction

`PortalNumber` wraps Latin/numeric/currency runs in Unicode LRI/PDI, within Arabic RTL Text, and preserves the original semantic label. Shared metrics, footnotes, ledger values, record values/subtitles and generator price/schedule/duration use it. Tests verify price, ₪3408, units, counts and time without parsing or changing values. The scope is the pilots/shared components; other screens await Step 3.

The misleading `كWh هذا الشهر` / `36 فاتورة` is original app code. Fixture counts 12 + 24 expose it; no arithmetic or field mapping was corrected. See findings.md.

## Text-size evidence

Runtime audits merge each rendered Text style with DefaultTextStyle, including the scrolled pilots and admin More sheet, and assert >=12sp. JSON files contain the actual strings and sizes. Scope is these pilots and More, not the unreviewed Step 3 screens. Legacy profile content is tested only for destination reachability.

| Render | Text observations | Minimum sp | Maximum sp |
| --- | ---: | ---: | ---: |
| admin_dark | 72 | 12 | 28 |
| admin_light | 72 | 12 | 28 |
| consumer_dark | 60 | 12 | 28 |
| consumer_light | 60 | 12 | 28 |

## Original baseline proof

Original local branch `work` resolves to `caa6d10f132a79fa36bcd44bcf95885d0cc5340d`. Its lib/test/pubspec/assets were extracted with `git archive work` to `/tmp/portal-original-proof`, then analyzed and tested with the same Flutter 3.41.9 SDK and unchanged dependency lockfile. This is the original local branch, not a claim to have fetched current remote main.

Original analyzer: **0 errors, 20 warnings, 261 infos (281 issues)**. Complete output: [original-analyzer.txt](validation/original-analyzer.txt). Original failing test: **`test/widget_test.dart` — `Counter increments smoke test`**; it pumps the app without ProviderScope (`Bad state: No ProviderScope found`) and retains a stale counter expectation. Complete output: [original-counter-test.txt](validation/original-counter-test.txt). That test and business sources were not edited.

All 20 original warnings, with original line numbers:

```text
warning • Unused import: '../services/firebase_service.dart' • lib/providers/auth_provider.dart:7:8 • unused_import
warning • The value of the field '_generatorOn' isn't used • lib/views/screens/admin/admin_screen.dart:30:8 • unused_field
warning • Unnecessary cast • lib/views/screens/admin/admin_screen.dart:55:22 • unnecessary_cast
warning • The declaration '_showAddSheet' isn't referenced • lib/views/screens/admin/admin_screen.dart:1019:8 • unused_element
warning • The declaration '_showAddSheet' isn't referenced • lib/views/screens/admin/admin_screen.dart:1385:8 • unused_element
warning • The value of the field '_highlightedBillId' isn't used • lib/views/screens/admin/admin_screen.dart:1515:11 • unused_field
warning • The receiver can't be 'null' because of short-circuiting, so the null-aware operator '?.' can't be used • lib/views/screens/admin/admin_screen.dart:3184:46 • invalid_null_aware_operator
warning • The '!' will have no effect because the receiver can't be null • lib/views/screens/admin/admin_screen.dart:3185:45 • unnecessary_non_null_assertion
warning • Dead code • lib/views/screens/admin/admin_screen.dart:3373:27 • dead_code
warning • The declaration '_PRow' isn't referenced • lib/views/screens/admin/admin_screen.dart:3824:7 • unused_element
warning • The declaration '_MockAlerts' isn't referenced • lib/views/screens/consumer/alerts_tab.dart:264:7 • unused_element
warning • The declaration '_MockBills' isn't referenced • lib/views/screens/consumer/bills_tab.dart:530:7 • unused_element
warning • Unnecessary cast • lib/views/screens/consumer/consumer_shell.dart:46:22 • unnecessary_cast
warning • Dead code • lib/views/screens/consumer/profile_tab.dart:235:27 • dead_code
warning • The declaration '_showSecuritySheet' isn't referenced • lib/views/screens/consumer/profile_tab.dart:272:8 • unused_element
warning • The declaration '_showHelpSheet' isn't referenced • lib/views/screens/consumer/profile_tab.dart:282:8 • unused_element
warning • The receiver can't be 'null' because of short-circuiting, so the null-aware operator '?.' can't be used • lib/views/screens/consumer/profile_tab.dart:381:31 • invalid_null_aware_operator
warning • The value of the local variable 'theme' isn't used • lib/views/screens/register_screen.dart:133:11 • unused_local_variable
warning • The value of the local variable 'theme' isn't used • lib/views/screens/super_admin/super_admin_screen.dart:21:11 • unused_local_variable
warning • The receiver can't be null, so the null-aware operator '?.' is unnecessary • lib/views/screens/super_admin/super_admin_screen.dart:187:49 • invalid_null_aware_operator
```

## Scope and remaining limits

Production changes are restricted to `lib/theme/` and `lib/views/`. No providers, services, models, routes, Firebase schema/rules, auth, permissions, pubspec or dependency lock changes in this revision. Additional changed files are requested tests, documentation and PNG evidence. Diff statistics are saved in validation/pilot-diff-stat.txt.

Native launcher/splash validation remains pending: this environment has no installed Android emulator, exposed KVM or attached Android device. Goldens do not prove native Android icon/splash behavior. No Step 3 changes, publishing or remote push were performed.

## Final verification

All **11 redesign tests pass**, including golden comparisons without updating references, bidi isolation, all 12 alternative bars, 320dp targets, RTL, text size, destinations and scroll clearance. Full current analysis: **0 errors, 20 pre-existing warnings, 218 infos (238 issues)**. Scoped analysis of theme, new shared widgets, consumer home and redesign tests: **No issues found**. Legacy admin/shell warnings remain in the full report with shifted line numbers. The unchanged counter smoke test still fails on current code, matching the original failure. Logs are in validation/. `git diff --check` passes.
