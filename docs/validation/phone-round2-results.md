# Phone round 2 validation — 2026-11-22

- Branch: fix/phone-test-round2; base fix/phone-test-round1 at c1ff261.
- flutter analyze: 0 errors, 12 existing warnings + 18 existing infos. Exact diagnostic multiset equals c1ff261's saved analyzer output after stripping locations; no new diagnostics.
- Full Flutter suite, once after implementation: **192 passed**, including updated light/dark goldens. No tests removed or weakened.
- Local demo Auth/Firestore emulators: **35 passed**; production Firebase untouched. Covers missing assignment get/create, atomic preparation cancellation, reader/tenant isolation and existing billing/auth rules.
- Additional affected coverage: resume-triggered verification/profile refresh; no auto-submit while typing, keyboard submit shows busy/disabled fields; password eye selection; numeric middle/delete/paste selection; tall forms/focused fields above simulated keyboard.
- APK: flutter build apk --debug --no-pub: successful (one final build). Existing Android SDK XML tool-version warning, not a build failure.
- APK path: build/app/outputs/flutter-apk/app-debug.apk (176273731 bytes).
- APK SHA-256: `7e40a515c38adb1e8846c9e433fdf5831465fb01f16c4c932ce7852c0d3abf71`.
- Build output is local, not committed to Git. No google-services.json or android/gradle.properties changes committed.

## Manual checks
Deploy this branch's firestore.rules before testing interrupted preparation (`firebase deploy --only firestore:rules` in your own configured project). Existing indexes are unchanged. We did not deploy rules or operate on production data.
Customize Authentication → Templates → Email verification (sender display name and template; use a verified sender/domain only if you already control it). Check Spam; free default-sender delivery is not guaranteed. No paid service/billing is needed or enabled by these changes.
On Android: open mail, verify, Back/app switcher, process survival and automatic continuation; actual email arrival; password-manager autofill/keyboard submission; eye/cursor with your keyboard; short-screen sheet padding. Tests simulate lifecycle/insets, not a physical phone.
