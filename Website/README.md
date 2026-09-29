# Website — www.skyline-architect.com

A static site: plain HTML and one stylesheet, no build tools or scripts beyond the manual's
search box. Upload the folder as it is to any static host.

| Path | What | Edited by |
|------|------|-----------|
| `index.html` | Landing page | hand |
| `support.html`, `privacy.html` | Support page and privacy policy: the App Store Connect URLs (`Documentation/APP_STORE.md`) | hand |
| `assets/style.css` | Styles for every page (light and dark) | hand |
| `images/` | App icon and real game captures (from `Development/Screenshots/`) | hand |
| `manual/` | **The player's manual**, one page per chapter plus a contents page with search | **generated, do not edit** |

## The manual

The manual has one source, shared with the game: the Markdown chapters in
`Packages/SkylineKit/Sources/SkylineContent/Resources/Manual/`. The game shows them under
*Help ▸ Skyline Architect Manual*. After changing a chapter, regenerate the pages:

```sh
cd Packages/SkylineKit
swift run skyline-website ../../Website
```

A package test (`ManualTests.websiteManualIsUpToDate`) fails while `manual/` is out of date,
so CI catches a forgotten regeneration.

## Publishing

The site has no server-side parts. To publish it at www.skyline-architect.com:

- **GitHub Pages**: publish this folder with a Pages workflow (Pages serves only the root or
  `/docs` of a branch directly), and point the domain's DNS at GitHub Pages with a `CNAME`
  file containing `www.skyline-architect.com`.
- **Any other static host** (Netlify, Cloudflare Pages, S3): upload the folder's contents.

Nothing is published automatically yet; see DECISIONS.md D-058.
