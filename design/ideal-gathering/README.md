# Ideal Gathering — reference graphics

The raw graphics the v1.39.0 cosmic nebula port was measured against.

| File | Source |
|---|---|
| `ideal-gathering-logo.png` | `public/favicon-512.png` at commit `7b6a450` of [idealgathering-collab/ideal-gathering](https://github.com/idealgathering-collab/ideal-gathering) |
| `logo-192.png` | `public/favicon-192.png` at commit `7b6a450` |
| `og-image.jpg` | `public/og-image.jpg` at commit `4e65d25` |
| `hero-cafe.jpg` | `src/assets/hero-cafe.jpg` at commit `cb74a6a` (76070 bytes — exactly the size recorded for the deployed asset in its `.asset.json`) |

Notes:

- The binaries are recovered from the project's **git history** — the working
  tree only keeps Lovable `.asset.json` metadata (the image files themselves
  are stored in Lovable's R2 bucket and are not downloadable from the repo).
- The design **tokens** (colours, gradients, glows, glass recipes, animations)
  are ported 1:1 from `src/styles.css`; see
  `havato/includes/class-havato-themes.php` (the `nebula` theme) and section
  14 of `havato/assets/css/havato-app.css`.
- `havato/assets/img/nebula-skyline.jpg` (the app's cosmic backdrop plate) is
  a re-creation generated with the `og-image.jpg` and `hero-cafe.jpg` above
  as style references, because the deployed `landing-nebula-skyline.jpg` is
  only stored in Lovable's private bucket.
