# Phone round 2

1. Preparation blocker: prepare() reads meterAssignments/{round_subscriber} before creating it, but its read rule required resource.data membership even when the document did not exist. Firebase therefore rejected the existence check, leaving the already-written round preparing. Resume also rejected already-open rounds and finalized unconditionally, allowing a concurrent cancel/resume race. Fix owner-only missing-document reads, idempotent preparation/finalization, explicit required settings and safe soft cancellation; preserve reader isolation and invoices.

2. Reader emptiness: assigning during preparation updated only the subscriber, while existing round assignments were skipped by prepare(), retaining the old reader. Reader queries intentionally show only open rounds but the empty copy conflated no round, preparing and no assignment. Reconcile reader assignment on resume and on assignment during preparation; explain exact empty state and keep the reader-only route guard.

Item 2 verification: targeted repository tests cover manual+linked preparation, assignment before opening, during preparation and after opening/reassignment. Existing role redirect tests and rules isolation tests remain mandatory in the final regression. Owner entry rows now identify the assigned reader; opening is blocked if a subscriber lacks any reader.

3. Verification: account creation already awaited verification sending, but failures could disappear during the router transition and no lifecycle observer refreshed verification on return. Keep send failures with the shared email throttle, show them on waiting, refresh on resume, and use a plain Activity-launched mail intent. Remove empty task affinity; external browser/mail Back behavior still depends on Android and must be phone-tested. Firebase default sender delivery cannot be guaranteed; customize Authentication → Templates sender/name and check Spam, without enabling billing.

4. Login already set busy immediately, but password keyboard submission/autofill grouping were missing. Submit only on button or keyboard action (never automatically while typing), retain generic errors/throttle, and use the existing disabled spinner button for all auth submits.

5. Password controls used bare obscured TextFields with no reveal action. All real password inputs now share one default-hidden control, RTL suffix eye, Arabic show/hide labels and an unchanged controller/selection across toggles.

6. Modal spacing came from independent caller padding and nested scroll views; profile actions immediately followed the ID input. PortalSheet now centrally owns max height, keyboard/safe-area bottom margin and scrolling; existing title/actions remain reachable inside the scroll area. All modal sheets use this wrapper; dialog forms retain AlertDialog's inset-aware layout and focus reveal. Converted profile/help/complaints, bell log, owner more/subscriber forms, payment, reader/invite, reading/expense and billing forms.

7. Numeric fields inherited ambient RTL and had no single digit/selection policy. A shared numeric-aware field now uses LTR digits/right alignment and a one-to-one Arabic digit/decimal formatter that preserves selection/composition. Formatting phone prefixes stays on submit, never while editing. Applied to phone/ID, reading, payment, price and generic numeric forms.

8. Rounding was a terse range label and the unsaved-generator UI defaulted minimum to zero. Explain each setting, initialize only new unsaved settings with 1.5 units/10 days/50, and show threshold-driven rounding examples without altering saved settings or historical bill snapshots.


## Commits and final verification

| Item | Commits |
| --- | --- |
| 1 | b1d9f90 |
| 2 | 9f9ab59 + c1bdea0 |
| 3 | 7097db2 |
| 4 | 340ecd7 |
| 5 | ee488f1 |
| 6 | f2f2cf3; final regression fixes bounded read-only draggable lists |
| 7 | 105d8a8 |
| 8 | 2b102df |

Each item was pushed to origin/fix/phone-test-round2. Final validation adds updated goldens and explicit lifecycle/keyboard/cursor regressions. Shared-sheet regression found read-only draggable lists needed bounded constraints rather than a second outer scroll; forms retain shared scrolling. Full results and required manual phone checks: [validation/phone-round2-results.md](validation/phone-round2-results.md). No other branches, paid services, production data, or unrelated behavior changed.
