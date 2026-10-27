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
Check it decodes pixel-identical to the optimised PNGs.

The iconset's lossy step is `pngquant --quality 80-100 --speed 1 --strip`,
then `oxipng`. The icon is flat colour with soft shadows, and the shadows are
where quantising shows: at 75–90 and below they dither into visible speckle
at 4×; at 80–100 the 128 and 64 px sizes come out pixel-identical and the
1024 px one changes 0.4% of its pixels by at most 10/255, which can't be
seen. For the batch-stack icon of 27 October 2026 that took the iconset from
128,199 to 40,182 bytes and the icns from 128,659 to 40,897. The 16 and 32 px
sizes then decode exactly as a plain `iconutil` pack does. The README images
are palette PNGs already and gain nothing from `oxipng`.

Report the before and after sizes in the commit. The test fixtures are files
created in code, so there is no committed test image to optimise.

**Incorrect:**

```sh
iconutil -c icns icon/FilenameChanger.iconset   # after oxipng — re-encoded, the saving lost
```

**Correct:**

```sh
for f in icon/FilenameChanger.iconset/*.png; do
    pngquant --quality 80-100 --speed 1 --strip --skip-if-larger --force --output "$f" "$f"
done
oxipng -o max --strip safe icon/FilenameChanger.iconset/*.png
python3 scripts/repack-icns.py icon/FilenameChanger.icns icon/FilenameChanger.iconset icon/FilenameChanger.icns
# icon/FilenameChanger.icns: 128659 -> 40897 bytes
```
