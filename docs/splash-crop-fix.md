# Android splash crop fix

Visual-only change on `redesign/visual-identity`. The previous Android 12 configuration reused the adaptive launcher foreground in light mode and the tightly bounded reversed mark in dark mode. Their bounds were not guaranteed to fit the Android 12 circular mask.

## Assets and configuration

Dedicated transparent 1152×1152 assets now contain the approved A mark in a 648×648 design box (56.25% of the canvas), optically shifted upward 24px. The existing SVG's internal whitespace is preserved. Light uses the approved white mark over the brand teal `#14756B`; dark uses the approved reversed mark over the dark brand canvas `#13262A`. No icon-background color is set, so the no-background Android 12 safe circle is 768px in diameter (2/3 of the canvas).

For pre-Android-12, dedicated 768×768 transparent assets preserve the same mark at 384×384 with generous padding and explicit center gravity. Existing warm light/dark backgrounds are retained. Android-specific overrides leave iOS splash assets unchanged. Adaptive app icons, notification icons, application sources, dependencies, schema/rules and behavior are unchanged.

Assumption: “dark brand background” means the approved dark canvas, rather than using the light mint action color as a background. This preserves the identity's dark variant.

## Regeneration and proof

`tool/render_splash_assets.py` renders existing approved SVG geometry without changing it, explicitly preserving its negative-space luminance masks. It requires build-time Pillow and CairoSVG, not app dependencies. Then run `dart run flutter_native_splash:create`.

The actual generator command used was `dart --suppress-analytics run flutter_native_splash:create`; the extra Dart flag avoids writing analytics metadata to the read-only home directory. Output is in `validation/splash-generate.txt`.

[Mask proof](validation/splash-mask.png) shows light (left) and dark (right), each under a centered 768px circular mask with its perimeter drawn for reference. `validation/splash-mask.json` records zero lost alpha pixels for both source images. The maximum alpha radius is approximately 374.4px, below the allowed 384px. Every generated Android 12 image across five densities and both modes also has zero alpha pixels outside its scaled safe circle; see `validation/splash-resources.json`. All Android resource XML parses, and pre-12 centered gravity is verified.

This is a deterministic asset/mask check, not an emulator or physical-device screenshot. No Android device/emulator was available for a runtime check here. No public release or PR is created.

`flutter build apk --debug --no-pub` succeeded after regeneration. The SDK XML-version tooling warning is recorded in `validation/splash-build.txt`; it did not prevent compilation.
