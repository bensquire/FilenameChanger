---
title: Every Image Is as Small as It Can Be Without Showing It
impact: MEDIUM
impactDescription: Every byte of the icon ships in the app and the DMG; every byte of a screenshot loads with the README
tags: [quality, images, assets, size, png, icns]
paths: ["images/**", "icon/**", "README.md", "scripts/repack-icns.py"]
---

## Every Image Is as Small as It Can Be Without Showing It

**Impact: MEDIUM**

An image that is *presentation* — the README's `images/hero.png` and
`images/icon.png`, the app icon — is minified to the highest degree that
introduces no visible artefact. In order:

1. **The right container.** Screenshots with text, flat graphics and icons are
   PNG; a photograph would be WebP or JPEG.
2. **Lossless first.** `oxipng -o max --strip safe`. Identical pixels, smaller
   file.
3. **Then lossy, to the edge.** A palette PNG (`pngquant`; both README images
   are 8-bit colormap already) or `cwebp -q 90 -m 6`. Go lower until an
   artefact shows, then back up one step.
4. **Look.** Side by side with the original at 1:1, on the busiest region.

The icon has its own path, because `iconutil` re-encodes PNGs when it packs an
`.icns` and throws the optimisation away. `swift icon/makeicon.swift` draws the
iconset and `iconutil` packs it once; then `oxipng` shrinks the iconset, and
`scripts/repack-icns.py` rebuilds `icon/FilenameChanger.icns` directly from the
optimised PNGs, keeping the 16 and 32 px ARGB chunks from the packed file.
Check it decodes pixel-identical.

That second half has not been done for the current icon. On a copy, on 25
October 2026, `oxipng` took the iconset from 140,953 to 70,190 bytes, and the
repack took the icns from 141,465 to 70,997 bytes. The README images gain
nothing from `oxipng`.

Report the before and after sizes in the commit. The test fixtures are files
created in code, so there is no committed test image to optimise.

**Incorrect:**

```sh
iconutil -c icns icon/FilenameChanger.iconset   # after oxipng — re-encoded, the saving lost
```

**Correct:**

```sh
oxipng -o max --strip safe icon/FilenameChanger.iconset/*.png
python3 scripts/repack-icns.py icon/FilenameChanger.icns icon/FilenameChanger.iconset icon/FilenameChanger.icns
# icon/FilenameChanger.icns: 141465 -> 70997 bytes
```
