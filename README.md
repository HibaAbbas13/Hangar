# Hangar

App Store name: **Hangar: Deploy Control**. iOS DevOps control surface. SwiftUI + Firebase + RevenueCat.

Bundle ID: `com.dev.flightdeck` (registered in App Store Connect — do not change)

## Architecture

`UI → Controller → Repository → Service → Model`

- `Hangar/Features` — screens and controls
- `Hangar/Controllers` — view state
- `Hangar/Repositories` — Firestore reads/writes
- `Hangar/Services` — Auth, Functions proxy, RevenueCat, Live Activities
- `Hangar/Models` — domain records
- `Hangar/App/Data` — `Constants.swift`, `AppEnum.swift`
- `Shared` — widgets, App Intents, Live Activity attributes

## Firestore

```
/users/{userId}
  tier, createdAt, displayName, email, themePreference, executionMode
  /decks/{deckId}
    name, provider, isActive, iconName, lastStatus, lastTriggeredAt
    /buttons/{buttonId}
      label, webhookUrl (AES-GCM blob), iconName, method, lastTriggered
    /members/{memberId}
    /profiles/{profileId}
  /activity/{eventId}
  /sharedDecks/{deckId}
  /invites/{code}
/inviteCodes/{code}
```

Free: 1 deck, 3 buttons. Premium: unlimited decks, Live Activities, Siri macros, team sync, execution profiles.

Firebase project: `flightdeck-3f201` (number `125330343129`). Place the iOS plist at `Hangar/Resources/GoogleService-Info.plist` (gitignored — copy from the `.example`).

## Remaining setup

1. Enable Authentication: Sign in with Apple, Email/Password.
2. Create Firestore (production mode) if it is not already on.
3. Blaze / pay as you go is required for outbound webhook Cloud Functions.
4. Copy `Config/Secrets.xcconfig.example` to `Config/Secrets.xcconfig` and set the RevenueCat public SDK key (`appl_…`). Never commit `Secrets.xcconfig`. In RevenueCat, entitlement id must be `hangar_pro`, with App Store products `com.dev.hangar.supporter` (monthly) and `com.dev.hangar.groundcrew` (annual) attached, and that offering marked **Current**.
5. In App Store Connect, finish both subscriptions until status is **Ready to Submit** (localization + price + review screenshot on each subscription, plus subscription-group localization). RevenueCat will keep showing **Missing Metadata** until Apple reaches that state.
6. Add a **7-day free trial** introductory offer on each subscription (Subscription Prices → Introductory Offers). The paywall reads it automatically.
7. Optional for Shipaton: generate **Subscription Offer Codes** in ASC, or give judges the in-app code `HANGAR-JUDGE` (paywall → Redeem code).
8. In Apple Developer: enable Sign in with Apple, App Groups `group.com.dev.flightdeck`, and Push (Live Activities) for both `com.dev.flightdeck` and `com.dev.flightdeck.widgets`.
9. Deploy backend:

```bash
cd firebase/functions && npm install && npm run build
cd ../..
firebase deploy --only firestore:rules,firestore:indexes,functions
```

10. Generate and open the Xcode project:

```bash
xcodegen generate
open Hangar.xcodeproj
```

Select your Development Team and run on a device for Sign in with Apple, widgets, and Live Activities.

## Before submitting to the App Store

Account, legal, and review surfaces ship in the app:

- **Profile** — Account tab → account row. Callsign, tier, stats, legal links, delete account.
- **Delete account** — Profile → Danger zone. Purges Firestore (decks, buttons, members, profiles, activity, invites, shared-deck memberships) then the Auth record; re-prompts for the passcode, or re-runs Sign in with Apple, when Firebase asks for a recent login.
- **Forgot passcode** — sign-in screen, sends a Firebase reset email. Unknown addresses get the same confirmation, so the form does not reveal who has an account.
- **Privacy Policy / Terms of Use** — bundled in `LegalText.swift`, linked from the sign-in screen, the paywall, Settings, and Profile.
- **Ratings** — `ReviewService` asks for a review after 5 successful triggers, once per version with a 120-day cooldown. Account → About → Rate Hangar opens the write-review page.

Still to do by hand:

1. Set the real values in `Constants.Legal`: `appStoreId`, `privacyURL`, `termsURL`, `supportEmail`. The write-review link and both "Open the web copy" buttons depend on them.
2. Host the same two documents at those URLs and enter them in App Store Connect (the privacy URL is required; the terms URL fills the EULA field).
3. Fill the App Privacy questionnaire to match the policy: email, user content (decks/buttons/webhooks), purchase history, and diagnostics — all linked to identity, none used for tracking.
4. Deploy the updated Firestore rules — account deletion needs the new `members` delete rule:

```bash
firebase deploy --only firestore:rules
```

Webhook secrets are encrypted at rest **only when Cloud Functions are deployed** — `ButtonRepository.saveWithSecret` calls `upsertButton`, which encrypts and writes the document server-side. If that call fails the app falls back to storing the URL in plain text so it stays usable, and marks the record `isEncrypted: false`. Deploy the functions before shipping, or the privacy policy's encryption paragraph describes a path you are not running.

Webhook URLs are encrypted at rest by Cloud Functions (`WEBHOOK_CRYPTO_KEY` env, or a project-derived key). Widgets and Siri fire `triggerDeckButtonHttp` with the Firebase ID token stored in the App Group.
# Hangar
