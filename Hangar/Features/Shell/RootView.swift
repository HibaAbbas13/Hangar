import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppController
    @Environment(\.fdTheme) private var theme

    var body: some View {
        ZStack {
            FDScreenBackground()
            switch app.session {
            case .launching:
                LaunchMark()
            case .needsFirebase:
                FirebaseMissingView()
            case .onboarding:
                OnboardingView()
            case .unauthenticated:
                AuthView()
            case .ready:
                MainShellView()
            }
        }
        .animation(FDMotion.slow, value: app.session)
        .tint(theme.brass)
        .permissionDialog()
    }
}

struct LaunchMark: View {
    @Environment(\.fdTheme) private var theme
    @State private var glow = false

    var body: some View {
        VStack(spacing: 16) {
            Text("HG")
                .font(FDFont.display(54, weight: .bold))
                .foregroundStyle(theme.brass)
                .shadow(color: theme.brass.opacity(glow ? 0.45 : 0.12), radius: glow ? 24 : 8)
            Text("HANGAR")
                .font(FDFont.micro(12))
                .tracking(6)
                .foregroundStyle(theme.fog)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

struct FirebaseMissingView: View {
    @Environment(\.fdTheme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            Text("Awaiting telemetry")
                .font(FDFont.display(28))
                .foregroundStyle(theme.bone)
            Text("Drop your Firebase GoogleService-Info.plist into Hangar/Resources, enable Apple Sign-In, Firestore, and Functions, then rebuild.")
                .font(FDFont.ui(15))
                .foregroundStyle(theme.fog)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}
