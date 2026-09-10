# Hangar: Deploy Control

iPhone control surface for webhooks you already own. Redeploy, roll back, or ping production from a pad, a Home Screen widget, or Siri.

**App Store:** [Hangar: Deploy Control](https://apps.apple.com/app/id6806856067)  
**License:** MIT

SwiftUI + Firebase + RevenueCat. Free plan: 1 service and 3 commands, with widgets, Lock Screen, Siri, and Console. Hangar Pro (RevenueCat entitlement `hangar_pro`): unlimited pad, Flows, and team sync. Plans: Supporter `com.dev.hangar.supporter` (monthly) and Ground Crew `com.dev.hangar.groundcrew` (annual), both with a 7-day trial.

## Architecture

`UI → Controller → Repository → Service → Model`

- `Hangar/Features` — screens
- `Hangar/Controllers` — view state
- `Hangar/Repositories` — Firestore
- `Hangar/Services` — Auth, Functions, RevenueCat, Live Activities
- `Hangar/Models` — domain records
- `Hangar/App/Data` — `Constants.swift`, `AppEnum.swift`
- `Shared` — widgets, App Intents, Live Activity attributes
- `web/` — privacy, terms, support pages

## Run locally

```bash
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
cp Hangar/Resources/GoogleService-Info.plist.example Hangar/Resources/GoogleService-Info.plist
cp .firebaserc.example .firebaserc
```

Fill `Secrets.xcconfig` with your RevenueCat public SDK key (`appl_…`). Never commit that file. Copy the real iOS plist from the Firebase console over the example.

```bash
brew install xcodegen   # if needed
xcodegen generate
open Hangar.xcodeproj
```

Set your Development Team on the Hangar and HangarWidgets targets. Widgets, Live Activities, Siri, and Sign in with Apple need a device — they do not work in the Simulator.

Optional: `DEMO_EMAIL` / `DEMO_PASSWORD` in `Secrets.xcconfig` enable **Open sample hangar** and mark that email as Premium without a purchase. Leave them as `YOUR_DEMO_*` in the example so public clones do not ship an allowlist.

## Backend

```bash
cd firebase/functions && npm install && npm run build
cd ../..
firebase deploy --only firestore:rules,firestore:indexes,functions
```

Blaze is required for outbound webhook Cloud Functions. Webhook URLs, headers, and bodies are encrypted with AES-GCM in `upsertButton` when Functions are reachable. Widgets and Siri call `triggerDeckButtonHttp` with the Firebase ID token in the App Group.

In Apple Developer: Sign in with Apple, App Groups `group.com.dev.flightdeck`, Push (Live Activities) for `com.dev.flightdeck` and `com.dev.flightdeck.widgets`.

In RevenueCat: entitlement `hangar_pro`, both App Store products attached to the offering marked **Current**.

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
