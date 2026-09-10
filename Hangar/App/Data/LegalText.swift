import Foundation

struct LegalDocument: Identifiable, Hashable {
    struct Section: Identifiable, Hashable {
        var id: String { heading }
        let heading: String
        let body: String
    }

    var id: String { title }
    let title: String
    let eyebrow: String
    let intro: String
    let url: String
    let sections: [Section]
}

enum LegalText {
    static let privacy = LegalDocument(
        title: "Privacy Policy",
        eyebrow: "Legal",
        intro: "Last updated \(Constants.Legal.lastUpdated). Hangar is a control surface for webhooks you already own. This policy explains what leaves your iPhone and what does not.",
        url: Constants.Legal.privacyURL,
        sections: [
            .init(
                heading: "What we collect",
                body: """
                • Account record — the email address and callsign you sign up with, or the email Apple relays when you use Sign in with Apple. Stored in Firebase Authentication.
                • Hangar contents — the services, commands, and flows you create, including the webhook URLs, HTTP methods, headers, and request bodies you enter.
                • Run log — the label, service, status code, duration, and any error message for each command you fire, so the Console can show a history.
                • Purchase state — RevenueCat tells us whether your premium entitlement is active. We never see your payment details; Apple handles the transaction.
                • Diagnostics — Firebase Analytics collects standard app usage events such as launches and crashes.
                """
            ),
            .init(
                heading: "What we do not collect",
                body: """
                We do not collect your contacts, photos, location, health data, or advertising identifiers. Hangar contains no third-party advertising or tracking SDKs, and we do not sell or share your data with data brokers.
                """
            ),
            .init(
                heading: "Webhook URLs and secrets",
                body: """
                Webhook URLs, headers and request bodies are the sensitive part of your hangar. When our backend is reachable they are encrypted with AES-GCM before they are stored, and decrypted only at the moment a command fires — anyone reading the raw database sees ciphertext.

                If the backend cannot be reached, the command is still saved so the app keeps working. In that case the URL is stored as you entered it, readable only by your own account under our access rules. The app shows whether a command is stored encrypted.

                When a command fires in on-device mode, the request goes straight from your iPhone to the endpoint you configured. We are not in the path and never see the response body — only the status code and duration recorded in your activity log.
                """
            ),
            .init(
                heading: "Where it is stored",
                body: """
                Data lives in Google Firebase (Authentication, Cloud Firestore, and Cloud Functions) under our project, and in RevenueCat for entitlement state. Both are processors acting on our instructions. A copy of your most recent run and your service layout is cached in an App Group container on your device so widgets, Siri, and Lock Screen controls work.
                """
            ),
            .init(
                heading: "How long we keep it",
                body: """
                Your hangar stays until you delete it. Deleting a service or command removes it and its stored secret. Deleting your account removes your profile, services, commands, flows, run log, invites, and authentication record. Backups and logs age out within 30 days.
                """
            ),
            .init(
                heading: "Your controls",
                body: """
                • Edit or remove any service, command, or flow at any time.
                • Delete your account from Hangar → Profile → Delete account. This is immediate and cannot be undone.
                • Request a copy of your data, or ask a question about this policy, by writing to \(Constants.Legal.supportEmail).

                Depending on where you live you may have additional rights under the GDPR or CCPA, including access, correction, portability, and erasure. Deleting your account satisfies an erasure request; email us for anything else.
                """
            ),
            .init(
                heading: "Children",
                body: """
                Hangar is a developer tool and is not directed to children under 13. We do not knowingly collect data from them. If you believe a child has created an account, email us and we will remove it.
                """
            ),
            .init(
                heading: "Changes and contact",
                body: """
                If this policy changes in a way that affects you, we will note it in the app before the change takes effect. Questions go to \(Constants.Legal.supportEmail).
                """
            )
        ]
    )

    static let terms = LegalDocument(
        title: "Terms of Use",
        eyebrow: "Legal",
        intro: "Last updated \(Constants.Legal.lastUpdated). Using Hangar means you agree to these terms.",
        url: Constants.Legal.termsURL,
        sections: [
            .init(
                heading: "The licence",
                body: """
                We grant you a personal, non-transferable, revocable licence to use Hangar on Apple devices you own or control, in line with the Apple Media Services Terms. You may not resell it, reverse engineer it, or strip out its notices.
                """
            ),
            .init(
                heading: "Your account",
                body: """
                Keep your credentials to yourself; you are responsible for what happens under your account. Tell us at \(Constants.Legal.supportEmail) if you think it has been compromised. We may suspend an account that is being used to abuse the service or break the law.
                """
            ),
            .init(
                heading: "You own the endpoints you fire",
                body: """
                Hangar fires HTTP requests you configure, at endpoints you supply. You confirm that you are authorised to call them and that doing so does not violate anyone else's terms or rights. You are responsible for what those requests do — a deploy, a rollback, and a wipe all look the same to us. Do not use Hangar to attack infrastructure you do not control, to send unlawful content, or to relay spam.
                """
            ),
            .init(
                heading: "Premium and billing",
                body: """
                The free plan includes one service and three commands, with widgets, Lock Screen access, Siri and the full run log included. Premium lifts those limits and adds flows and team sync.

                Premium is sold as an auto-renewing subscription through the App Store. Payment is charged to your Apple Account at confirmation. It renews automatically unless auto-renew is turned off at least 24 hours before the period ends, and your account is charged for renewal within 24 hours of the end of the current period. Manage or cancel in Settings → Apple Account → Subscriptions. Refunds are handled by Apple under their policy, not by us.
                """
            ),
            .init(
                heading: "Availability",
                body: """
                We do not promise uninterrupted service. Features that depend on Firebase, RevenueCat, Apple's push infrastructure, or your own endpoints can fail for reasons outside our control, and we may change or retire features between releases.
                """
            ),
            .init(
                heading: "No warranty, limited liability",
                body: """
                Hangar is provided "as is", without warranties of any kind to the fullest extent the law allows. We are not liable for indirect or consequential loss, or for damage caused by a command you fired — including failed, duplicated, or unintended deployments. Where liability cannot be excluded, it is capped at what you paid us in the twelve months before the claim.
                """
            ),
            .init(
                heading: "Ending it",
                body: """
                You may stop at any time by deleting your account in Hangar → Profile. We may end this licence if you breach these terms. On termination your licence stops and your data is deleted as described in the Privacy Policy.
                """
            ),
            .init(
                heading: "Apple",
                body: """
                Apple is not a party to these terms and has no obligation to provide support for Hangar. Apple and its subsidiaries are third-party beneficiaries and may enforce these terms against you.
                """
            ),
            .init(
                heading: "Contact",
                body: """
                Questions about these terms go to \(Constants.Legal.supportEmail).
                """
            )
        ]
    )
}
