# Phone round 1 — fixes (base stage-8 / 1443adb)

1. **Address save / black screen:** readiness helpers watched the entire AuthState; the live profile update invalidated the generator-access stream, causing a transient loading redirect and disposal of an open sheet. Both profile editors then popped using the parent page context, with a save flag reinitialized on every StatefulBuilder rebuild. Save/submit audit: profile, tariff/schedule, subscriber/bill/complaint forms, receipt review, enrollment/auth, super-admin approvals, reader, settings, round/payment/expense forms. Modal completions must target the still-current modal; page saves return only when there is a previous page. Existing feature forms already collect data in a modal then save from the owning page; no additional pop is needed.

2. **First theme tap:** missing saved preference resolves to `system`, but toggle treated system as light even when the OS was displaying dark. The asynchronous preference load could also overwrite a tap made during startup. Resolve from visible brightness and ignore stale preference loads after a user choice.

3. **Contact fields / registration:** both profile forms deliberately made phone read-only and routed contact edits through password re-authentication; readers had no profile entry. Registration treated phone as optional. ID uniqueness is NOT enforced (no active idIndex writes), so no uniqueness feature is added. Share validation/Arabic-digit normalization, require Palestinian mobile for new owner/consumer enrollment, allow own contact-only updates without credential changes, and gently prompt existing empty profiles.

4. **Auth layout:** CredentialScreen reused PortalPage's fixed identity header and top-aligned full-width list. There was no centered/max-width auth group and keyboard resizing inherited page layout. Add a bounded centered scrollable auth frame using existing identity tokens, retaining a scroll/reveal path with the keyboard open.

5. **Reset / verification experience:** reset success was only a notice below the original form; neither flow offered an email-app intent or visible resend countdown. Preserve Firebase's free secure email links and generic account-existence wording, add an in-app waiting/confirmation state with clear steps, a visible 60-second resend timer and safe Android mail opening. Verification still refreshes Firebase user/token/profile before routing.

6. **Reading-round layout / actions:** the header used a wrapping button row and every subscriber always displayed both link and repair controls, without persisted knowledge of an interrupted projection. Replace it with one primary action plus an explained add menu; use compact subscriber menus and explicit account/reader chips. Track pending linking until invoice/payment projection completes, so repair is shown only for a known interrupted link. Round cards show date, status, count/progress and the next action. Editing subscriber identity/contact labels never changes prior readings, amounts or approvals.

## Commits / verification

| Item | Commit |
|---|---|
| 1 save navigation | f9038ef |
| 2 theme | 5777945 |
| 3 contacts / rules | 3e858db |
| 4 centered auth | 30ffa84 |
| 5 reset / verification | 5546d39 |
| 6 round UI + final regression/goldens | This report's commit |

Final: 185 Flutter tests passed, 34 local Authentication/Firestore emulator tests passed, APK built. Analyzer has no errors or new diagnostics against stage-8; existing diagnostics remain (see JSON/logs). No test removed or weakened. The regression sweep also caught and fixed an eager Firebase dependency in login cooldown initialization and normalized-phone lookup compatibility; existing startup and tenant lookup assertions still pass. UI goldens were refreshed for changed auth/profile/round/finance screens, not silently ignored. Evidence and complete changed-file manifest: `docs/validation/phone-round1-*`.

### Manual Firebase / phone check

Use your TEST project only. Enable Email/Password, keep Phone/SMS/Storage/Functions/billing disabled as previously documented. Deploy this branch's stricter self-profile rules and the round publication index before phone testing:

```powershell
git fetch origin
git switch fix/phone-test-round1
git pull --ff-only
flutter pub get
firebase deploy --only firestore:rules,firestore:indexes --project YOUR_TEST_PROJECT_ID
flutter build apk --debug
flutter run -d YOUR_ANDROID_DEVICE_ID
```

No real Firebase operations or data deletion were performed here. Existing missing-contact accounts stay usable; new owner/consumer enrollment needs a normalized mobile. Valid legacy +970/+972 contacts remain compatible with owner approval. IDs remain non-unique private profile data. Link pending metadata is owner-only and clears only after projection completes; no amounts, readings or approvals are edited by the new subscriber edit action. Publication state checks read at most one unpublished invoice per closed round.

On a phone: save/dismiss profile during slow connection; first theme toggle with OS dark/system; enter Arabic digits for phone/ID in each role; check keyboard on login/register/reset; open/reset/verify email, wait/resend, return and refresh; use round add menu/subscriber actions and resume a genuinely interrupted link. Android mail-app resolution, actual email delivery/verification links and the original black-screen symptom on physical hardware were not verified here. The unavailable-mail path was tested with a mocked native channel; Android native code compiles. Optional App Links/Hosting is only a future decision in `docs/decisions.md`, not implemented/deployed.
