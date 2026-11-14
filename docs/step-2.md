# Step 2 — design-system checkpoint

Stopped before Step 3, as requested. These are actual Flutter widget-test goldens, not HTML/mockup screenshots:

| Actual screen | Arabic light | Arabic dark |
| --- | --- | --- |
| ConsumerShell, home selected, including its navigation | [consumer_light](../screenshots/redesign/consumer_light.png) | [consumer_dark](../screenshots/redesign/consumer_dark.png) |
| AdminScreen, overview selected | [admin_light](../screenshots/redesign/admin_light.png) | [admin_dark](../screenshots/redesign/admin_dark.png) |

## Implemented

- `lib/theme/portal_tokens.dart`: approved colours, state palettes, Arabic-first type scale, local font family/fallback, spacing, dimensions, corners, outlines, chart colours, restrained motion.
- `lib/theme/portal_theme.dart`: Material 3 light/dark themes built from those tokens. No provider/state/persistence changes. The two reviewed surfaces scope the theme; unreviewed admin destinations explicitly retain their original theme until Step 3.
- Shared scaffold, identity bar, brand mark, navigation, panels, metrics, record rows, action button/input wrappers, semantic chips, generator panel, loading/empty/error presentation, and bar chart. New components and consumer home contain no literal hex colours or TextStyle constructors outside the theme layer.
- Consumer home: approved A identity, dominant blue generator state, warm neutral canvas, quiet monthly metrics, readable alerts, local fonts and retained actions. ConsumerShell uses the shared four-destination navigation while preserving its IndexedStack, index handling, listeners and destinations.
- Admin overview: same identity and status panel; labelled 3×2 navigation connected to the original six-entry TabController/TabBarView. Existing generator confirmation/settings callbacks, bill-jump index, provider reads and values are preserved. Existing helpers/dialogs and other tab bodies await Step 3.
- Chart rendering is explicitly wired into the existing UsageTab adapters because numeric labels on the **actual** chart were requested now: daily/monthly discrete columns show every value and a simple axis; weekly rows retain values. Period selection, source points, consumption calculations and all providers are unchanged. The rest of UsageTab styling is not migrated yet.
- Notification bell gets a themed icon/contrast-safe badge, 12sp label, tooltip and short fade; read/delete actions, sheet, state and data flow are unchanged. The sheet's full visual migration is pending Step 3.
- pubspec changes are font/asset declarations only. No dependencies added; `pubspec.lock` is unchanged. The old `assets/logo.jpg` source now contains approved A.

## Conditions completed before this checkpoint

Only approved A is retained in the brand assets, preview sources and documentation. Superseded SVGs, raster proofs, comparison pages and generation scripts were deleted, including the thin-line houses. Master SVGs, embedded preview header and app source image use A.

Working status is **blue**, distinct from the **teal** brand family and green success:

| Status | Light text / fill | Contrast | Dark text / fill | Contrast |
| --- | --- | ---: | --- | ---: |
| Working | `#2459A6` / `#EAF1FC` | 6.05:1 | `#B0C9FF` / `#233653` | 7.33:1 |
| Stopped | `#53696D` / `#EDF1EF` | 5.11:1 | `#B3C5C3` / `#263D40` | 6.41:1 |

Both alternative states are shown **side by side**, with text/icons/contrast figures, in each theme of the [identity preview](identity/theme-preview.png). Browser geometry and image loading were checked. This guide is a static component specimen; the four home PNGs above are Flutter goldens.

## Validation actually executed

| Check | Outcome |
| --- | --- |
| Frozen dependency resolution | Passed with Flutter **3.41.9**, Dart **3.11.5**. The older README version could not satisfy SDK-pinned test packages; matching the SDK avoided lockfile changes. |
| `flutter test --no-pub test/redesign` | **6 passed**: four home golden comparisons, visible chart values/axis, and colour contrast assertions. |
| Goldens | Rendered at 430×1100, DPR 1, Arabic/RTL, actual bundled Arabic/currency and Material icon fonts; logo images explicitly precached. |
| Firebase isolation | Auth notifier and data providers replaced by fixtures. No Firebase initialization/account creation/production reads/writes. Empty fixture uid exercises the existing listener early-return; the production listener is untouched. |
| Reachability | Both admin theme tests tap all six existing destinations and return to overview without exception. Same controller ordering and bill index 3. |
| Touch targets | Android tap-target guideline passed on both homes, both themes. |
| Contrast | All working/stopped/success/warning/danger text pairs >=4.5:1; secondary chart columns >=3:1 on both theme surfaces. |
| Scoped analysis | Theme, shared components/chart, consumer home and new tests: **No issues found**. |
| Full `flutter analyze --no-pub` | **0 errors, 20 warnings, 218 infos** (238 total); not clean. Archived pre-change baseline: 0 errors, 20 warnings, 261 infos (281 total). Remaining issues belong to preserved legacy code, including unreviewed screens/providers and deprecated style calls; not silently suppressed. |
| Existing `test/widget_test.dart` | **Fails before and after**: `No ProviderScope found`, then stale counter expectation. Confirmed against an archived pre-change tree with its original assets/package manifest. File unchanged; see findings. |
| Diff protection | Providers, services, models, route configuration, Firestore rules and lockfile have no changes. No translations/l10n/new locale. |

Golden fixtures retain the production screen's time-dependent greeting/current-month labels. These checkpoint baselines therefore include the capture month's text; future clock/month-boundary changes must be distinguished from visual regressions. No production time calculation was modified to make a test pass.

## Reproduce in this environment

```bash
cd /workspace/Power-House
export PATH=/workspace/toolchains/flutter/bin:$PATH
export PUB_CACHE=/workspace/toolchains/pub-cache
export XDG_CONFIG_HOME=/workspace/toolchains/config
export XDG_CACHE_HOME=/workspace/toolchains/cache
export ANALYZER_STATE_LOCATION_OVERRIDE=/workspace/toolchains/analyzer-state
export DART_SUPPRESS_ANALYTICS=true
flutter pub get --enforce-lockfile
flutter test --no-pub test/redesign
flutter analyze --no-pub lib/theme lib/views/widgets/portal_components.dart lib/views/widgets/portal_chart.dart lib/views/screens/consumer/home_tab.dart test/redesign
```

Use `--update-goldens` only for intentional reviewed appearance changes. Actual app code, not alternate reconstructed screen widgets, is mounted in the tests. Arabic only; the unchanged Latin brand wordmark is an explicitly approved logo asset, not a UI locale.

## Remaining work / real-device requirement

No Step 3 migration has begun on registration, login, setup, bills, profile, alerts, subscriber details, pending requests, complaints or super-admin. Existing global theme provider/builders are untouched so the checkpoint does not restyle the rest of the app. Shared components are ready for that work; legacy hardcoded styles outside the migrated scope remain until then. Therefore a repository-wide no-literals/no-ad-hoc-style claim would be false at this checkpoint.

Native icon/splash installation, ErrorWidget visual update, native notification small icon/accent, shortened root theme animation and complete dialog/sheet/state migration remain in the authorized implementation queue. No notification/service logic will change. No production branding/Play signing readiness is claimed.

**Step 4 Android launcher/splash validation requires an emulator or physical device.** There is currently no installed emulator, no exposed `/dev/kvm`, and no visible USB device in this environment. No emulator/device validation was performed, and browser mask previews do not count. This remains explicitly unverified; software-emulator feasibility or a real-device run must be established at that step. No APK/device-run claim is made here.

See [existing findings](findings.md) for the unchanged security/data/auth issues. No fixes to them are included. No GitHub push or environment publication performed.
