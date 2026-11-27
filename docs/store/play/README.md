# Google Play listing

The store listing of `app.setding` (ADR-0067) in the layout of fastlane
supply. The screenshots are rendered on demand, see the
[store README](../README.md#screenshots).

| File | Content | Made by |
|---|---|---|
| `icon-512.png` | App icon 512×512, opaque and full-bleed (Play masks the corners) | `make branding` |
| `feature-1024x500.png` | Feature graphic, the dark logo without text (fits every language) | `make branding` |
| `<locale>/title.txt`, `short_description.txt` (≤ 80), `full_description.txt` (≤ 4000) | Listing texts in `de-DE`, `en-US`, `fr-FR`, `it-IT`, `es-ES` and `pt-PT`, based on the website's home page; the four other languages are translations of `en-US` | by hand |
| `<locale>/images/phoneScreenshots/`, `tenInchScreenshots/` | Phone and tablet screenshots (git-ignored) | `make screenshots ONLY="^store "` |

The answers for the Play Console's forms (app access, content rating, target
audience, data safety, app signing) are in [`console.md`](console.md).

Play's rules for the texts: no superlatives ("best", "#1"), no names of other
apps, no keyword lists, no prices or calls to rate the app.
