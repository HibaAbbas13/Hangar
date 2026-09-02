import SwiftUI

struct PermissionDialog: ViewModifier {
    @ObservedObject private var permissions = PermissionService.shared

    func body(content: Content) -> some View {
        content.alert(
            permissions.pending?.title ?? "",
            isPresented: Binding(
                get: { permissions.pending != nil },
                set: { if !$0 { permissions.dismiss() } }
            ),
            presenting: permissions.pending
        ) { permission in
            Button(permission.settingsLabel) { permissions.openSettings() }
            Button("Not now", role: .cancel) { permissions.dismiss() }
        } message: { permission in
            Text(permission.message)
        }
    }
}

extension View {
    func permissionDialog() -> some View {
        modifier(PermissionDialog())
    }
}

struct PermissionRow: View {
    @Environment(\.fdTheme) private var theme
    let permission: PermissionService.Permission
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(permission.rowTitle)
                        .font(FDFont.ui(15, weight: .medium))
                        .foregroundStyle(theme.bone)
                    Text(permission.rowDetail)
                        .font(FDFont.ui(12))
                        .foregroundStyle(theme.fog)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                FDBadge(
                    text: permission.isGranted ? "Allowed" : "Off",
                    tone: permission.isGranted ? .moss : .rust
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
