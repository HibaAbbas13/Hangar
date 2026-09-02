import Foundation

struct ProviderTemplate: Identifiable, Hashable {
    var id: String { "\(provider.rawValue)-\(label)" }
    var provider: ServiceProvider
    var label: String
    var iconName: String
    var method: HTTPMethod
    var sampleURL: String
    var headers: [String: String]
    var body: String
    var requiresConfirmation: Bool
    var detail: String
}

enum ProviderCatalog {
    static let all: [ProviderTemplate] = [
        ProviderTemplate(
            provider: .vercel,
            label: "Redeploy production",
            iconName: ButtonIcon.rocket.rawValue,
            method: .POST,
            sampleURL: "https://api.vercel.com/v1/integrations/deploy/prj_YOUR_PROJECT/YOUR_HOOK",
            headers: [:],
            body: "",
            requiresConfirmation: false,
            detail: "Paste a Vercel Deploy Hook. Hangar proxies the POST so the hook never sits in a widget."
        ),
        ProviderTemplate(
            provider: .vercel,
            label: "Trigger production rollback",
            iconName: ButtonIcon.rollback.rawValue,
            method: .POST,
            sampleURL: "https://api.vercel.com/v1/integrations/deploy/prj_YOUR_PROJECT/YOUR_HOOK",
            headers: [:],
            body: "",
            requiresConfirmation: true,
            detail: "Bind this to your rollback hook. Confirmation is on by default."
        ),
        ProviderTemplate(
            provider: .github,
            label: "Dispatch workflow",
            iconName: ButtonIcon.branch.rawValue,
            method: .POST,
            sampleURL: "https://api.github.com/repos/OWNER/REPO/dispatches",
            headers: [
                "Accept": "application/vnd.github+json",
                "Authorization": "Bearer YOUR_GITHUB_TOKEN"
            ],
            body: """
            {"event_type":"flightdeck","client_payload":{"source":"ios"}}
            """,
            requiresConfirmation: false,
            detail: "repository_dispatch. Keep the PAT on the encrypted secret, not in the widget."
        ),
        ProviderTemplate(
            provider: .netlify,
            label: "Build hook",
            iconName: ButtonIcon.bolt.rawValue,
            method: .POST,
            sampleURL: "https://api.netlify.com/build_hooks/YOUR_BUILD_HOOK",
            headers: [:],
            body: "",
            requiresConfirmation: false,
            detail: "Netlify build hooks are POST-only. No body required."
        ),
        ProviderTemplate(
            provider: .netlify,
            label: "Lock deploys",
            iconName: ButtonIcon.shield.rawValue,
            method: .POST,
            sampleURL: "https://api.netlify.com/api/v1/deploys/DEPLOY_ID/lock",
            headers: ["Authorization": "Bearer YOUR_NETLIFY_TOKEN"],
            body: "",
            requiresConfirmation: true,
            detail: "Locks the current production deploy."
        ),
        ProviderTemplate(
            provider: .supabase,
            label: "Invoke edge function",
            iconName: ButtonIcon.database.rawValue,
            method: .POST,
            sampleURL: "https://YOUR_PROJECT.functions.supabase.co/deploy-guard",
            headers: [
                "Authorization": "Bearer YOUR_ANON_OR_SERVICE_KEY",
                "Content-Type": "application/json"
            ],
            body: """
            {"action":"status"}
            """,
            requiresConfirmation: false,
            detail: "Call a Supabase Edge Function that already holds service credentials."
        ),
        ProviderTemplate(
            provider: .custom,
            label: "Emergency webhook",
            iconName: ButtonIcon.skull.rawValue,
            method: .POST,
            sampleURL: "https://example.com/hooks/emergency",
            headers: ["Content-Type": "application/json"],
            body: """
            {"source":"flightdeck","severity":"high"}
            """,
            requiresConfirmation: true,
            detail: "Any HTTPS endpoint. Headers and body are encrypted at rest."
        )
    ]

    static func templates(for provider: ServiceProvider) -> [ProviderTemplate] {
        all.filter { $0.provider == provider }
    }
}
