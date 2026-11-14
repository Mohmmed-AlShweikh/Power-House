# A — revision 03, awaiting artwork approval

The owner chose concept A conditionally and asked to review its refinement before Step 2. This revision stays entirely within proposal assets and documentation.

## Visual changes

- Two distinct houses instead of three identical repeated peaks. Overhanging triangular roof silhouettes, visible wall height, doorway cutouts and unequal heights distinguish the buildings. An 8-unit blank band separates their bases from the generator.
- Generator remains the coloured foreground mass. A side exhaust with a right-angle outlet and two broad ventilation apertures distinguish it from a battery. The electricity cutout and two lower feet remain.
- No gradients, thin connecting wires, extra windows or decorative outlines.
- Original Arabic and Latin wordmark paths and transforms are copied exactly; generator script asserts equality against the original lockup.

## Deliverables and checks

- [Full review sheet](a-refined.png): primary, black and white, each at 192px, 48px and 24px, plus unchanged wordmark and candidate icon.
- [Logo and app-icon screenshot](a-refined-lockup-icon.png).
- `assets/brand/a-refined/`: primary/black/white/reversed marks, lockup and icon as SVG.
- Primary structural bands, door/vent cutouts and exhaust are based on an 8-unit feature on the 96-unit canvas: 4px at 48px, 2px at 24px. Diagonal roof tips and rounded corners naturally taper. Minimum intended mark display is 24px.
- Browser capture at deviceScaleFactor 1 confirmed all 11 images loaded, and all three 48px and all three 24px samples have their actual stated CSS width/height. Bundled fonts loaded before capture. Full sheet inspected visually. Images embedded as data URIs to avoid hosting-path image failures.
- Six SVG documents parsed and wordmark geometry equality checked. No Flutter application test/build claims are made from this static review.

Regenerate with `python3 docs/identity/refine-generator.py`, serve the repository locally, and capture `docs/identity/a-refined.html` at a 1440px viewport. Earlier proposals and installed native resources are unchanged until approval.

## Owner's clarified implementation boundaries — next steps only

1. Arabic light and Arabic dark only. Preserve fixed `ar` and forced RTL. Do not add English UI, translations, l10n files or a language switch. Preserve the bilingual logo wordmark specifically requested unchanged.
2. The only permitted **new** app dependency is `flutter_svg`, if needed. Existing icon/splash generators may be reused; no new generator or logic/network/storage/auth/state dependency.
3. After identity approval, replace the old `assets/logo.jpg` branding source and update the existing `flutter_icons` and `flutter_native_splash` configurations. Produce Android adaptive and iOS launcher resources from the approved artwork. Splash colours must use the new light/dark identity where platform tooling supports it; validate Android 12 separately. Do not install these proposal icons now.
4. Restyle the `main.dart` ErrorWidget through theme presentation, preserving exception text and error behaviour. This is a specifically authorized presentation edit outside screen files, and must be listed explicitly in the final scope report.
5. Update the local notification small-icon resource and accent-colour presentation only. Preserve notification initialization, permissions, channel identifiers/behaviour, content, listeners, delivery, IDs and all service logic. If a service line must reference the new visual resource/colour, report that exact presentation-only exception explicitly.
6. Shorter theme animation duration is authorized as appearance only; do not change auth, service or business timing.
7. Wait for approval of this refined A before implementing the design system (Step 2). No push or publication is authorized by this artwork review.
