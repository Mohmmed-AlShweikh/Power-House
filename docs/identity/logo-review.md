# Step 1 — symbol revision 02 (not approved)

The original house/circuit symbol is not approved. Step 2 remains blocked on the owner's explicit choice; no new ThemeData, screen edits, application icons or platform splash changes have been made.

## Three different symbols

### A — المولد أولًا

كتلة مولد كهربائي ممتلئة تتصدر الرمز، وصاعقة مفرّغة تؤكد الطاقة.
ثلاثة بيوت خلفه تظهر المستفيدين دون أن تنافس مصدر التغذية.

### B — قلب التشغيل

قرص طاقة كبير بعلامة تشغيل سميكة يصبح مركز العلامة.
كتل الحي خلفه ثانوية؛ الشكل الدائري يختلف جذريًا عن جسم المولد.

### C — وصلة الكهرباء

قابس كهربائي ممتلئ يتقدم بيتين كتليين، فيربط الخدمة بالكهرباء مباشرة.
الشكل الرأسي بسنّين واضحين يجعل الاتصال هو البطل بدل أسقف البيوت.

## Compare before selecting

- [Full comparison screenshot](logo-alternatives.png): each symbol at 192px, 96px, 48px and 24px; true black and true white monochrome at 96/48/24; unchanged bilingual wordmark and candidate icon with each.
- [Main logo and icon proof](logo-and-icon.png): candidate A is used only to demonstrate correct asset loading. It has **not** been selected.
- [Updated component/palette/chart screenshot](theme-preview.png).
- Individual vectors in `assets/brand/alternatives/`: `{a-generator,b-power,c-plug}-{primary,black,white,lockup,icon}.svg`.

Only the mark is replaced in each candidate lockup. Arabic and Latin wordmark paths and transforms are copied verbatim from the original `lockup-primary.svg`; the generator checks structural equality. The original master files remain intact until a choice is made.

## Small-size construction rule

Use filled shapes, not outline houses. The 96-unit symbol canvas uses an 8-unit minimum structural band/cutout grid: 4px at 48px and 2px at 24px. The power ring and its stem, plug prongs and generator vent cutouts use this grid. Curves and diagonal corner tips naturally taper; they are not separate fine-line details. No windows or tiny connecting wires. Minimum display is 24px; 48px preferred in primary UI. Monochrome relies on transparent cutouts rather than a white paint patch, so reversed art works on arbitrary backgrounds.

The comparison screenshot is rendered at deviceScaleFactor 1. Open at 100% to judge actual 48/24px samples; chat may rescale the full sheet. Check final Android launcher masks on the chosen candidate later, not before approval.

## Asset-loading correction

The preview now embeds actual SVG bytes for its main logo and icon as data URIs, recorded with `data-asset-src` pointing to the repository source. They no longer depend on the directory from which a preview is hosted. The browser checked `complete && naturalWidth > 0` for all 36 comparison images and all 4 theme-preview images. The separate `logo-and-icon.png` is a browser capture, not a manually assembled substitute. Existing local font references were also loaded before capture.

## Complete semantic colours

Text/container pairs; order below is explicitly foreground then background. Ratios use WCAG linearized sRGB luminance, not a visual estimate. Success and generator-on intentionally share a semantic family; each has its own named role. Stopped uses neutral status, not danger.

| Role | Light foreground / background | Text contrast | Dark foreground / background | Text contrast |
| --- | --- | ---: | --- | ---: |
| Success / النجاح | `#246B4C` / `#E9F3ED` | 5.64:1 | `#A0D9B8` / `#234338` | 6.79:1 |
| Danger / الخطر | `#AA3F36` / `#FBEDEA` | 5.30:1 | `#FFB8AD` / `#4C302F` | 7.18:1 |
| Warning / التحذير | `#8C581B` / `#FFF2DC` | 5.38:1 | `#F1CC8A` / `#493B26` | 7.10:1 |
| Generator on / المولد يعمل | `#246B4C` / `#E9F3ED` | 5.64:1 | `#A0D9B8` / `#234338` | 6.79:1 |
| Generator off / المولد متوقف | `#53696D` / `#EDF1EF` | 5.11:1 | `#B3C5C3` / `#263D40` | 6.41:1 |

The theme preview displays the same labels, code values and ratios. All `code` elements use `direction:ltr`, `unicode-bidi:isolate` and inline-block. [Machine-readable evidence](review-contrast.json).

## Chart revision

Every sample column now has a numeric value; simple 0/50/100/150 axis and kWh unit remain visible. These are static demonstration values, never substituted into app data. Secondary columns are opaque, `#598D85` on white (3.77:1) and `#6EAEA3` on dark canvas `#13262A` (6.16:1); primary columns retain their action/accent colours. The browser confirmed effective backgrounds and opacity 1, rather than trusting CSS declarations alone. Numeric labels use full-strength text colours. Month labels and plot share explicit LTR chronological order within RTL presentation.

## Validation / scope

All proposal SVGs parse successfully; all three wordmarks match the existing paths; screenshot image loading, font loading, effective chart fills/opacity, numeric column labels and code direction were checked in Chromium. Source-only UI design changes: docs/identity, docs/brand.md and assets/brand/alternatives only. No application source, providers, services, models, routing, Firebase rules, pubspec, native icons or splash changed. No Flutter run/analyze/test claim is made for this static revision. Nothing pushed or published.

Rebuild vectors with `python3 docs/identity/generate_alternatives.py`, then review HTML with `python3 docs/identity/build_review.py`. Image data URIs make the logo sheets independent of image hosting paths; fonts still load from the bundled assets relative to the repository.
