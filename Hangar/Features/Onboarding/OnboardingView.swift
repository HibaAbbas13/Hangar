import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var app: AppController
    @Environment(\.fdTheme) private var theme
    @State private var page = 0
    @StateObject private var motion = MotionParallax()

    private let pages: [(title: String, body: String)] = [
        ("One press, one request",
         "Every button here holds a webhook you own — a deploy hook, a rollback, a workflow. Press it and the request goes straight from this iPhone to your endpoint."),
        ("Without opening the app",
         "Put those buttons on your Lock Screen, in a home screen widget, or behind Siri. Two seconds from pocket to rollback."),
        ("You see what happened",
         "Every press is logged with its status code, how long it took, and what came back — including the ones that fail.")
    ]

    @ViewBuilder
    private func scene(for index: Int) -> some View {
        switch index {
        case 0: LoopScene(reduceMotion: app.reducedMotion)
        case 1: SurfacesScene(reduceMotion: app.reducedMotion)
        default: LogScene(reduceMotion: app.reducedMotion)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("HANGAR")
                    .font(FDFont.micro(11))
                    .tracking(4)
                    .foregroundStyle(theme.brass)
                Spacer()
                Button("Sample hangar") {
                    app.skipToSampleHangar()
                }
                .font(FDFont.ui(13, weight: .medium))
                .foregroundStyle(theme.brass)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(spacing: 28) {
                        Spacer()
                        scene(for: index)
                            .fdParallax(pitch: motion.pitch, roll: motion.roll, enabled: !app.reducedMotion)
                        VStack(spacing: 12) {
                            Text(pages[index].title)
                                .font(FDFont.display(34))
                                .foregroundStyle(theme.bone)
                                .multilineTextAlignment(.center)
                            Text(pages[index].body)
                                .font(FDFont.ui(16))
                                .foregroundStyle(theme.fog)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 340)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? theme.brass : theme.hairline)
                        .frame(width: index == page ? 22 : 8, height: 4)
                }
            }
            .padding(.bottom, 22)
            .animation(FDMotion.snappy, value: page)

            VStack(spacing: 12) {
                FDPrimaryButton(title: page == pages.count - 1 ? "Take the controls" : "Continue") {
                    if page < pages.count - 1 {
                        withAnimation(FDMotion.card) { page += 1 }
                    } else {
                        app.completeOnboarding()
                    }
                }
                if page == pages.count - 1 {
                    FDGhostButton(title: "Load sample hangar") {
                        app.skipToSampleHangar()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .onAppear { if !app.reducedMotion { motion.start() } }
        .onDisappear { motion.stop() }
    }
}
