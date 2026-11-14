# بوابة المولدات — «وصلة الحي»

Status: Step 1. **A selected conditionally; its refined artwork awaits explicit approval.** Latest [revision 03 preview](identity/a-refined.png), [logo/icon close-up](identity/a-refined-lockup-icon.png) and [revision notes](identity/a-refined.md). The bilingual wordmark remains unchanged as requested. Step 2 has not started. Earlier [three alternatives](identity/logo-review.md) are retained as review history. Nothing in the running Flutter UI, routes, providers, services, models, permissions or Firebase has been changed.

## Concept

مولد كهربائي ممتلئ يتقدم بيتين بأسقف مثلثة وارتفاعين مختلفين: مصدر طاقة واحد يخدم الحي.
العادم الجانبي وفتحتا التهوية يميزان جسم المولد، وتؤكد الصاعقة المفرّغة ارتباطه بالكهرباء.
الأخضر البترولي والورق الفاتح يمنحان الخدمة هدوءًا وثباتًا، ويتركان أرقام الفواتير وحالة التشغيل في الصدارة.
الثقة تأتي من الوضوح والاتساق؛ لا أختام ولا رموز حكومية ولا ادعاء اعتماد رسمي.

## Review assets

- [Light + dark component preview](identity/theme-preview.png), with palette, Arabic/Latin/numeral typography, buttons, input, status chips, status panel, ledger row and chart sample.
- [Offline preview source](identity/theme-preview.html). Open locally; all fonts and images are relative local files, with no remote fetches. Buttons are static samples, not app functionality.
- `assets/brand/mark-{primary,reversed,mono}.svg` and `lockup-{primary,reversed,mono}.svg`.
- All wordmarks are actual outlined paths shaped from the bundled font, so Arabic joining and appearance do not depend on an SVG viewer's installed fonts. SVGs have accessible titles, viewBoxes, no scripts or external references.
- `icon-proposal.svg`, `icon-proposal-1024.png`: full square, opaque icon source suitable for an iOS icon export. The OS owns corner masking; no rounded corners baked in.
- `adaptive-foreground-proposal.svg` / `adaptive-foreground-proposal-432.png`: transparent Android foreground, artwork inside the central 64/108 region; proposed background `#173E43`. Verify Android masks at installation time.
- `splash-proposal.svg` / `splash-mark-proposal-288.png`: quiet background and centered mark. Platform resources and generators deliberately remain untouched until approval. Android 12 icon masking and launch-to-app handoff will be checked in the implementation steps.

## Colour tokens

| Role | Light | Dark |
| --- | --- | --- |
| Brand ink | `#173E43` | `#F3F7F4` |
| Primary/action | `#14756B` | `#8AD8C7` |
| On primary | `#FFFFFF` | `#113C35` |
| Canvas | `#F4F6F3` | `#13262A` |
| Surface | `#FFFFFF` | `#1B3337` |
| Main text | `#233D42` | `#ECF3EF` |
| Secondary text | `#53696D` | `#B3C5C3` |
| Subtle divider | `#CCD8D4` | `#3F5A5C` |
| Interactive outline | `#53696D` | `#708B89` |
| Success text / container | `#246B4C` / `#E9F3ED` | `#A0D9B8` / `#234338` |
| Pending/warning text / container | `#8C581B` / `#FFF2DC` | `#F1CC8A` / `#493B26` |
| Error text / container | `#AA3F36` / `#FBEDEA` | `#FFB8AD` / `#4C302F` |

Use neutral text for monetary totals; reserve semantic colours for status. Generator stopped uses neutral text + explicit power-off icon and wording, rather than treating all downtime as an error. Never use translucent white as small secondary text on coloured fills. Subtle dividers are decorative grouping only; field boundaries and focus use stronger outlines.

Twelve specified text/background pairs were calculated from linearized sRGB WCAG luminance; all exceed 4.5:1 (minimum 5.30:1 in this set). See [contrast.json](identity/contrast.json). This validates these exact pairs, not the entire unimplemented app. Disabled controls, overlaid states, non-text contrast and final screens still require Step 4 checks.

## Typography and local font assets

Noto Sans Arabic, regular 400, semibold 600, bold 700. It has readable Arabic counters and clear Latin/digit shapes. Static TTFs in `assets/fonts/` are instantiated from the Google Fonts upstream variable font. Noto Sans Regular is bundled as local fallback for the shekel glyph, which the chosen Noto Sans Arabic file lacks. No Google Fonts runtime dependency or network font request.

Sources: Google Fonts `ofl/notosansarabic/NotoSansArabic[wdth,wght].ttf` and `ofl/notosans/NotoSans[wdth,wght].ttf` on `github.com/google/fonts`; SIL Open Font Licenses are retained beside the files. `pubspec.yaml` font declarations are deferred until identity approval; the static preview already loads the actual bundled files.

| Token | Size / weight | Line height | Use |
| --- | --- | --- | --- |
| Display | 32 / 600 | 1.5 | Primary monetary/consumption total |
| Heading | 28 / 600 | 1.5 | Screen title or generator state |
| Section | 22 / 600 | 1.5 | Major grouping |
| Title | 18 / 600 | 1.5 | Record/status heading |
| Body | 16 / 400 | 1.65 | Forms and prose |
| Label | 14 / 600 | 1.5 | Buttons and field labels |
| Caption | 12 / 400 or 600 | 1.6 | Dates, units, metadata; never below 12sp |

The application is **Arabic-only**, with its existing fixed `ar` locale and forced RTL preserved. Required presentation variants are Arabic light and Arabic dark only. No English UI mode, translations or l10n files will be introduced. The existing `Generator Portal` line remains in the logo because the owner explicitly requested that the wordmark stay unchanged. Do not stretch or track Arabic letters. Technical colour codes in review documentation remain isolated for correct reading; they are not a separate application locale requirement. Preserve existing numeric values and locale semantics.

## Geometry, iconography and motion

- Spacing scale: 4, 8, 12, 16, 24, 32, 48dp. Phone page gutter 20dp (16dp on narrow layouts), group gap 24dp, record padding 16dp. Use directional spacing.
- Radius: 8dp status tags, 12dp inputs/buttons, 16dp panels, 24dp modal top corners. Avatars may remain circles. No decorative blobs or giant curved headers.
- Most content has 0 elevation and a 1dp divider/outline. Use elevation only for navigation/dialog/sheet separation. Cards represent meaningful groups, not every line of information.
- Outline Material icons, consistent 24dp grid and approximately 2dp visual stroke; filled variants for selected navigation only. Always visible labels on destinations. Use actual vector icons instead of Unicode symbols shown in this static style sample.
- All interactive targets at least 48×48dp; inputs and primary buttons 56dp in Flutter, 52dp minimum button sample here. Strong keyboard focus, explicit accessible labels; selected/disabled/busy appearances consistent.
- Motion 120–180ms fades and small state transitions; no bounce, elastic zoom or repeated decorative animation. Respect platform reduced-motion. Do not alter service delays, auth timing or business state.

## Layout direction for the next steps (not implemented)

1. Home: restrained identity header, dominant generator-state panel with existing runtime/schedule, one ledger-like monthly summary, compact secondary metrics, alert list with dividers.
2. Administration: preserve all six existing controller destinations. On phones use a clearly labelled compact 3×2 destination panel rather than a clipped strip of tabs; on wide screens a rail can expose the same six items. Bind to the same TabController so swipe/index jumps stay consistent. User approval is of presentation, not extra destinations.
3. Bills: neutral invoice rows; amount and period get priority, status gets icon + text. Existing receipt selection/upload/review flows keep identical callbacks and branching.
4. Consumption: straight columns/bars for discrete values, consistent labels/units, no invented samples or smooth curves suggesting measurements between points. Daily/weekly/monthly source values and all calculations remain unchanged.
5. Forms: grouped labels, quiet surface, visible focus, inline existing error copy, scroll-safe sheets. Profile uses grouped rows; no colourful card for every setting.
6. Notifications/requests/complaints: shared record anatomy (title, metadata, body, status, existing actions); keep each existing empty/loading/error branch, including known mock fallbacks, until a separate logic task.

Logo clear space is at least 12 units of the 96-unit mark. Mark minimum 24dp; use full lockup at least 200dp wide, otherwise mark plus live themed text. Use reversed art on dark ink, mono for single-colour reproduction. Do not rotate, add glow/shadow/gradient, distort or enclose in a seal. The proposal is custom geometry, not a trademark clearance claim.

## Approval boundary and validation

Steps 0–1 only. Application source, dependency declarations/lockfile, platform icons/splash, routes and all backend files remain untouched. Approval of the identity is required before implementing ThemeData/components in Step 2. This gate is explicitly requested in the task, not an environment publishing requirement.

The preview is a static browser-rendered design artifact, not a running Flutter screen and not a golden test. Flutter analysis, existing test execution, faked-provider goldens, app screenshots, APK and Android runtime validation belong to subsequent steps; none are claimed here. No GitHub push or environment publication performed.

Regenerate vector assets from repository root with Python tooling `fontTools` and `uharfbuzz`: `python3 docs/identity/generate_brand.py`. These are asset-generation tools, not application dependencies. Raster sources exported using Inkscape. PNG preview captured from locally served HTML in Chromium using a 1440×1600 viewport and full-page capture (1440×1656); no remote resources or live user data. Local `file:` navigation was blocked by browser policy, so an internal loopback HTTP server was used for this static export.

Checks completed: parsed all ten SVGs, verified outlined wordmarks/no script nodes, verified three PNG export dimensions and opaque icon background, checked Arabic/Latin/digit coverage plus the bundled currency fallback, checked 12 contrast pairs, loaded all local preview fonts in Chromium, and visually inspected the full preview and Arabic wordmark. These are proposal-asset checks only.
