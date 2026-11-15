# Task 3: keyboard-safe modal forms

Branch: `redesign/visual-identity`; base `171a4f8`.

Cause: consumer profile edit and the two subscriber-add form builders read keyboard insets from the opener page context, so the modal does not necessarily rebuild when the keyboard opens. The add forms had non-scrollable Columns. Other forms used inconsistent inset/scroll nesting; the password dialog did not enable AlertDialog scrolling.

`showPortalFormSheet` now reads `viewInsets` inside the modal route, uses scroll-controlled presentation, safe areas, a 95%-of-available-height cap and SingleChildScrollView. Old per-form keyboard padding is removed to avoid double insets. `PortalFocusReveal` listens for keyboard metrics and focus changes, then scrolls the whole TextField decoration into view after layout, rather than only the editable text/caret. This matters for the bottom 16px of a field. Existing local content padding is retained.

Dialogs retain Material's own keyboard viewInsets/height handling (adding another inset would double it), use scrollable AlertDialogs and share the focus revealer. Titles/actions remain reachable by scrolling; dialog action rows remain outside the scrollable content. No validators, callbacks, submissions, data flows or destination changes.

| Existing form | Treatment |
| --- | --- |
| Consumer edit name/address/phone | shared route-local sheet viewport |
| Submit complaint | shared viewport; entire five-line field revealed |
| Both subscriber-add builders (currently unused) | shared viewport makes existing Columns scrollable; not activated |
| Edit subscriber ampere | shared focus dialog, existing scrollable AlertDialog |
| Generator price/schedule | shared sheet viewport |
| Add bill identity/consumption | shared sheet viewport |
| Actual and fallback complaint replies | shared focus dialog |
| Admin profile edit | shared sheet viewport |
| Password change (source-only security sheet) | scrollable AlertDialog + shared focus dialog; not activated |
| Receipt upload/re-upload | shared viewport; no notes/TextField exists in the current source, none added |
| Time-picker keyboard input | standard Flutter dialog keyboard handling retained |

13 widget tests simulate keyboard insets in light/dark, portrait 430×800 and landscape 800×500. They check all consumer edit fields, complaint, admin ampere/add-bill/reply/profile/price, a long eight-field form, a three-password-field dialog and receipt layout. They verify the focused TextField's entire rectangle stays above the keyboard, and titles/actions can be scrolled into the available viewport. Source-only forms use the tested common layout; no previously dormant feature was exposed just for testing. Firebase is faked; no account or database writes occur.

All 37 redesign tests pass as part of the full run: 50 passed, one failure is the unchanged pre-existing `Counter increments smoke test` (No ProviderScope / obsolete counter expectations). Full analyzer before/after: 0 errors, 18 inherited warnings, 21 infos, with no new issues after ignoring shifted line numbers. Two bills-error goldens were refreshed only because the intentionally displayed original stack trace now names source line 1192 instead of 1191; the 42 changed pixels are that line number. No comparison tolerance was added.

Assumption: “title and actions reachable” allows scrolling a tall sheet within the keyboard-free viewport, rather than introducing a new pinned header/footer design. All actions retain their original callbacks and enabled conditions. No emulator/physical keyboard/device validation was available; checks are Flutter widget tests.
