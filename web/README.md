# Hangar — public legal & support pages

Live at **https://hangar-legal.vercel.app**

Generated from the app's own copy. **Do not edit the HTML by hand** — it is
overwritten. Edit `Hangar/App/Data/LegalText.swift` (or the support/index
sections in the generator), then:

```bash
python3 scripts/build_legal_site.py   # regenerate
cd web && vercel deploy --prod        # republish
```

## Why these exist

App Store Connect requires a reachable **Privacy Policy URL** and **Support
URL** before an app can be submitted, and neither field accepts a `mailto:`.
The paywall also links to Terms and Privacy, which App Store Review
guideline 3.1.2 requires for auto-renewing subscriptions.

## The URLs

| Where | URL |
|---|---|
| Landing | https://hangar-legal.vercel.app |
| Privacy Policy | https://hangar-legal.vercel.app/privacy |
| Terms of Use | https://hangar-legal.vercel.app/terms |
| Support | https://hangar-legal.vercel.app/support |

`Constants.Legal` points at these through a single `siteRoot`. Change that one
line if the pages move to a custom domain.

## Deployment notes

- Its **own** Vercel project (`hangar-legal`, personal scope) — deliberately
  separate from `ar_shop`, which serves therango.co. Nothing here can affect
  the shop.
- `vercel.json` sets `cleanUrls`, so `/privacy` and `/privacy.html` both work.
- Only the `hangar-legal.vercel.app` alias is public. The per-deployment
  `…-hiba-abbas-projects-….vercel.app` URLs sit behind Vercel SSO and return a
  302 to a login page — **never give one of those to Apple or a judge.**
