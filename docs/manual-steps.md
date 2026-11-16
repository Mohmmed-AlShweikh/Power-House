# Manual Firebase steps (Windows PowerShell)

1. Use a clean TEST project on Spark. Do not enable billing, Storage, Functions or SMS. Free quotas are finite.
2. In Authentication → Sign-in method enable Email/Password; disable Phone and unused providers. Configure verification/reset email templates. Follow `docs/spark-phase1.md` for existing Phase-1 setup and manual super-admin bootstrap (same UID, no account migration).
3. Keep your local `android/app/google-services.json` and `android/gradle.properties` private and uncommitted.
4. Install Node.js and Firebase CLI on Windows: `npm install -g firebase-tools`. Sign in with `firebase login`.
5. To test rules locally, install Java 21, then run `npm ci --prefix tools/rules-tests` and `firebase emulators:exec --project demo-generator-portal --config firebase.auth-test.json --only auth,firestore "node --test tools/rules-tests/auth.test.mjs tools/rules-tests/rules.test.mjs"`. The demo project is local only.
6. After reviewing/testing this branch, deploy rules/indexes yourself to your TEST project: `firebase deploy --only firestore:rules,firestore:indexes --project YOUR_TEST_PROJECT_ID`. No deployment is run by this work.
7. Run `flutter pub get` and `flutter run -d YOUR_ANDROID_DEVICE_ID`. Real mail delivery and Android hardware must be tested on your device.
