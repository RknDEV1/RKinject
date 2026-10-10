import SwiftUI

// MARK: - Surfaces

extension View {
    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct KindIcon: View {
    let kind: PackageKind
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: kind.symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [kind.tint, kind.tint.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
    }
}

// MARK: - Toast

struct ToastHost: View {
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        VStack {
            if let t = toasts.current {
                HStack(spacing: 10) {
                    Image(systemName: t.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(t.isError ? Color.red : Color.green)
                    Text(t.message)
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 3)
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { toasts.current = nil }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(duration: 0.35), value: toasts.current?.id)
    }
}

// MARK: - Package status

struct StatusBadge: View {
    let state: PackageState

    var body: some View {
        if let info {
            Text(info.text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(info.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(info.color.opacity(0.14), in: Capsule())
        }
    }

    private var info: (text: String, color: Color)? {
        switch state {
        case .notInstalled: return nil
        case .downloading(let p): return (L("status.downloading", Int(p * 100)), .blue)
        case .installing: return (L("status.installing"), .blue)
        case .installed: return (L("status.installed"), .green)
        case .updateAvailable: return (L("status.update"), .orange)
        case .failed: return (L("status.failed"), .red)
        }
    }
}

struct InstallButton: View {
    let pkg: CatalogPackage
    @Environment(PackageManager.self) private var pm

    var body: some View {
        switch pm.state(for: pkg) {
        case .notInstalled:
            Button("action.install") { pm.install(pkg) }
                .buttonStyle(.borderedProminent).controlSize(.small)
        case .updateAvailable:
            Button("action.update") { pm.install(pkg) }
                .buttonStyle(.borderedProminent).controlSize(.small).tint(.orange)
        case .downloading(let p):
            ProgressView(value: p).progressViewStyle(.circular).frame(width: 28, height: 28)
        case .installing:
            ProgressView()
        case .installed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
        case .failed:
            Button("action.retry") { pm.install(pkg) }
                .buttonStyle(.borderedProminent).controlSize(.small).tint(.red)
        }
    }
}

struct PackageRow: View {
    let pkg: CatalogPackage
    @Environment(PackageManager.self) private var pm

    var body: some View {
        HStack(spacing: 12) {
            KindIcon(kind: pkg.kind)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(pkg.name).font(.headline).lineLimit(1)
                    StatusBadge(state: pm.state(for: pkg))
                }
                Text(pkg.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                Text("v\(pkg.version) · \(pkg.size.byteString)").font(.caption).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            InstallButton(pkg: pkg)
        }
        .padding(.vertical, 4)
    }
}
