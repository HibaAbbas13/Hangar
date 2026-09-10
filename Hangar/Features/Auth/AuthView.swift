import SwiftUI

struct AuthView: View {
    @Environment(\.fdTheme) private var theme
    @StateObject private var controller = AuthController()

    var body: some View {
        NavigationStack {
            content
        }
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("HANGAR")
                        .font(FDFont.micro(11))
                        .tracking(5)
                        .foregroundStyle(theme.brass)
                    Text(controller.isRegistering ? "Create your account" : "Sign in")
                        .font(FDFont.display(34))
                        .foregroundStyle(theme.bone)
                    Text("Use email on the Simulator. Apple Sign-In needs a physical iPhone.")
                        .font(FDFont.ui(15))
                        .foregroundStyle(theme.fog)
                }
                .padding(.top, 36)

                if controller.isRegistering {
                    FDField(title: "Name", text: $controller.displayName, placeholder: "Ada Lovelace")
                }
                FDField(
                    title: "Email",
                    text: $controller.email,
                    placeholder: "you@hangar.dev",
                    keyboard: .emailAddress,
                    autocapitalization: .never
                )
                FDField(
                    title: "Passcode",
                    text: $controller.password,
                    placeholder: "at least 6 characters",
                    isSecure: true,
                    autocapitalization: .never
                )

                if let error = controller.errorMessage {
                    Text(error)
                        .font(FDFont.ui(13))
                        .foregroundStyle(theme.rust)
                        .fixedSize(horizontal: false, vertical: true)
                }

                FDPrimaryButton(
                    title: controller.isRegistering ? "Create account" : "Enter",
                    isLoading: controller.isWorking
                ) {
                    Task { await controller.submitEmail() }
                }

                if !controller.isRegistering {
                    Button {
                        controller.openReset()
                    } label: {
                        Text("Forgot your passcode?")
                            .font(FDFont.ui(14, weight: .medium))
                            .foregroundStyle(theme.brass)
                            .frame(maxWidth: .infinity)
                    }
                }

                FDGhostButton(title: "Look around first", systemImage: "square.stack.3d.up") {
                    Task { await controller.enterSampleHangar() }
                }
                .disabled(controller.isWorking)

                Button {
                    withAnimation(FDMotion.snappy) {
                        controller.isRegistering.toggle()
                        controller.errorMessage = nil
                    }
                } label: {
                    Text(controller.isRegistering ? "Already have an account? Sign in" : "New here? Create an account")
                        .font(FDFont.ui(14, weight: .medium))
                        .foregroundStyle(theme.brass)
                        .frame(maxWidth: .infinity)
                }

                HStack {
                    FDHairline()
                    Text("DEVICE")
                        .font(FDFont.micro(10))
                        .foregroundStyle(theme.fog)
                    FDHairline()
                }

                Button {
                    Task { await controller.signInApple() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "apple.logo")
                        Text("Continue with Apple")
                            .font(FDFont.ui(16, weight: .semibold))
                    }
                    .foregroundStyle(theme.bone)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(theme.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.hairline, lineWidth: 1)
                    )
                }
                .buttonStyle(FDPressStyle(depth: 3))
                .disabled(controller.isWorking)

                legalFootnote
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $controller.showResetSheet) {
            ResetPasswordSheet(controller: controller)
        }
        .onAppear {
            guard UserDefaults.standard.bool(forKey: Constants.Demo.autoHangarFlag) else { return }
            Task { await controller.enterSampleHangar() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background { FDScreenBackground() }
    }

    private var legalFootnote: some View {
        VStack(spacing: 8) {
            Text("By continuing you agree to the Terms of Use and Privacy Policy.")
                .font(FDFont.ui(12))
                .foregroundStyle(theme.fog)
                .multilineTextAlignment(.center)
            HStack(spacing: 18) {
                NavigationLink { LegalView(document: LegalText.terms) } label: {
                    Text("Terms of Use")
                        .font(FDFont.ui(12, weight: .semibold))
                        .foregroundStyle(theme.brass)
                }
                NavigationLink { LegalView(document: LegalText.privacy) } label: {
                    Text("Privacy Policy")
                        .font(FDFont.ui(12, weight: .semibold))
                        .foregroundStyle(theme.brass)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

struct ResetPasswordSheet: View {
    @Environment(\.fdTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var controller: AuthController

    var body: some View {
        FDScreen {
            VStack(alignment: .leading, spacing: 18) {
                Text(controller.resetSent ? "Check your inbox" : "Reset your passcode")
                    .font(FDFont.display(26))
                    .foregroundStyle(theme.bone)

                if controller.resetSent {
                    Text("If a hangar exists for \(controller.resetEmail), a reset link is on its way. The link expires in an hour.")
                        .font(FDFont.ui(15))
                        .foregroundStyle(theme.fog)
                        .fixedSize(horizontal: false, vertical: true)
                    FDPrimaryButton(title: "Back to sign in") { dismiss() }
                } else {
                    Text("We will email a link that lets you set a new passcode.")
                        .font(FDFont.ui(15))
                        .foregroundStyle(theme.fog)
                    FDField(
                        title: "Email",
                        text: $controller.resetEmail,
                        placeholder: "you@hangar.dev",
                        keyboard: .emailAddress,
                        autocapitalization: .never
                    )
                    if let error = controller.resetError {
                        Text(error)
                            .font(FDFont.ui(13))
                            .foregroundStyle(theme.rust)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    FDPrimaryButton(title: "Send reset link", isLoading: controller.isSendingReset) {
                        Task { await controller.sendPasswordReset() }
                    }
                    FDGhostButton(title: "Cancel") { dismiss() }
                }
                Spacer()
            }
            .padding(24)
        }
        .presentationDetents([.medium])
    }
}
