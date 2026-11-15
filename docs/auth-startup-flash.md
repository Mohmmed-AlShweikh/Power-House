# Auth startup flash

Branch: `fix/auth-startup-flash`, based on `b886ccf41cf4eeb7fd4ebbaebf2d476e27aa1882` from `redesign/visual-identity`.

## Diagnosis

GoRouter previously started at `/login`. The redirect returned null while `AuthState.loading` was true, leaving the login page visible. `main.dart` awaits Firebase and notification initialization, but does not wait for the auth provider's session/profile resolution. AuthNotifier awaits account seeding before attaching `authStateChanges`, then loads the user's Firestore profile before the role is known. This explains the transient login page for a persisted session. The existing eight-second loading timeout could also clear `loading` before the session was resolved.

Remote `main` was fetched and compared at `caa6d10f132a79fa36bcd44bcf95885d0cc5340d`. Its router and auth provider are byte-identical to the redesign base, including the initial `/login`, loading behavior, seed-before-listen ordering and timeout. The bug predates the visual redesign.

## Minimal fix

Start at `/splash`, with the approved A mark, native splash light/dark background tokens and accessible progress indicator. A `startupResolved` flag remains false until the first Firebase auth event and (when signed in) profile/approval check complete, or an explicit auth stream error occurs. The old loading timeout does not resolve that flag. After resolution, signed-out users go to login; valid signed-in users go straight to their existing role destination. A signed-in user awaiting their profile also stays on splash.

Form submission loading is distinct from startup, preserving registration/login forms while their existing submit handlers run. Existing role guards, demo handling, seed logic, sign-in methods, profile lookup, approval checks, Firestore schema/rules and all other destinations remain unchanged. No dependency changes. `currentUser` is not used to guess the destination: the Firebase auth event and verified profile/role are needed before rendering home.

## Validation

11 tests cover unresolved loading, timeout without resolution, signed out, missing/failed profile, all three roles, existing role restrictions and three GoRouter widget journeys asserting login is never built during cold restoration. No Firebase accounts, writes or network are used by these tests. The targeted analyzer has only the pre-existing unused FirebaseService import warning in auth_provider.dart. Device cold-start verification has not been performed here.

The native Android splash crop task remains separate and is not included in this functional branch.

All 37 existing redesign tests also pass, with unchanged golden references.
