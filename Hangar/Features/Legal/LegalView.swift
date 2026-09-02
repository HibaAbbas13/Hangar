import SwiftUI

struct LegalView: View {
    @Environment(\.fdTheme) private var theme
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    let document: LegalDocument

    var body: some View {
        FDScreen {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    
                    FDIconButton(systemImage: "chevron.left", label: "Back") { dismiss() }
                    FDPageHeader(eyebrow: document.eyebrow, title: document.title, horizontalPadding: 0)
                    Text(document.intro)
                        .font(FDFont.ui(15))
                        .foregroundStyle(theme.fog)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(document.sections) { section in
                        MetalCard {
                            VStack(alignment: .leading, spacing: 10) {
                                FDSectionLabel(text: section.heading)
                                Text(section.body)
                                    .font(FDFont.ui(14))
                                    .foregroundStyle(theme.bone.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if let url = URL(string: document.url) {
                        FDGhostButton(title: "Open the web copy", systemImage: "safari") {
                            openURL(url)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct LegalLinkRow: View {
    @Environment(\.fdTheme) private var theme
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.brass)
                .frame(width: 22)
            Text(title)
                .font(FDFont.ui(15, weight: .medium))
                .foregroundStyle(theme.bone)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.fog)
        }
        .contentShape(Rectangle())
    }
}
